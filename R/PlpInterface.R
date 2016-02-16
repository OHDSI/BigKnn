# Copyright 2016 Observational Health Data Sciences and Informatics
#
# This file is part of BigKnn
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Build a K-nearest neighbor (KNN) classifier from a plpData object
#'
#' @param plpData          An object of type \code{plpData}.
#' @param indexFolder      Path to a local folder where the KNN classifier index can be stored.
#' @param overwrite        Automatically overwrite if an index already exists?
#' @param removeDropouts   If TRUE subjects that do not have the full observation window (i.e. are
#'                         censored earlier) and do not have the outcome are removed prior to fitting
#'                         the model.
#' @param cohortId         The ID of the specific cohort for which to fit a model.
#' @param outcomeId        The ID of the specific outcome for which to fit a model.
#'
#' @export
buildKnnFromPlpData <- function(plpData,
                                indexFolder,
                                overwrite = TRUE,
                                removeDropouts = TRUE,
                                cohortId = NULL,
                                outcomeId = NULL) {
  if (is.null(cohortId) && length(plpData$metaData$cohortIds) != 1) {
    stop("No cohort ID specified, but multiple cohorts found")
  }
  if (is.null(outcomeId) && length(plpData$metaData$outcomeIds) != 1) {
    stop("No outcome ID specified, but multiple outcomes found")
  }
  if (!is.null(cohortId) && !(cohortId %in% plpData$metaData$cohortIds)) {
    stop("Cohort ID not found")
  }
  if (!is.null(outcomeId) && !(outcomeId %in% plpData$metaData$outcomeIds)) {
    stop("Outcome ID not found")
  }
  covariates <- plpData$covariates
  cohorts <- plpData$cohorts
  outcomes <- plpData$outcomes

  if (!is.null(cohortId) && length(plpData$metaData$cohortIds) > 1) {
    # Filter by cohort ID:
    t <- cohorts$cohortId == cohortId
    if (!ffbase::any.ff(t)) {
      stop(paste("No cohorts with cohort ID", cohortId))
    }
    cohorts <- cohorts[ffbase::ffwhich(t, t == TRUE), ]

    idx <- ffbase::ffmatch(x = covariates$rowId, table = cohorts$rowId)
    idx <- ffbase::ffwhich(idx, !is.na(idx))
    covariates <- covariates[idx, ]

    # No need to filter outcomes since we'll merge outcomes with cohorts later
  }

  if (!is.null(outcomeId) && length(plpData$metaData$outcomeIds) > 1) {
    # Filter by outcome ID:
    t <- outcomes$outcomeId == outcomeId
    if (!ffbase::any.ff(t)) {
      stop(paste("No outcomes with outcome ID", outcomeId))
    }
    outcomes <- outcomes[ffbase::ffwhich(t, t == TRUE), ]
  }

  if (!is.null(plpData$exclude) && nrow(plpData$exclude) != 0) {
    # Filter subjects with previous outcomes:
    if (!is.null(outcomeId)) {
      exclude <- plpData$exclude
      t <- exclude$outcomeId == outcomeId
      if (ffbase::any.ff(t)) {
        exclude <- exclude[ffbase::ffwhich(t, t == TRUE), ]

        t <- ffbase::ffmatch(x = cohorts$rowId, table = exclude$rowId, nomatch = 0L) > 0L
        if (ffbase::any.ff(t)) {
          cohorts <- cohorts[ffbase::ffwhich(t, t == FALSE), ]
        }

        t <- ffbase::ffmatch(x = covariates$rowId, table = exclude$rowId, nomatch = 0L) > 0L
        if (ffbase::any.ff(t)) {
          covariates <- covariates[ffbase::ffwhich(t, t == FALSE), ]
        }

        # No need to filter outcomes since we'll merge outcomes with cohorts later
      }
    }
  }
  # Merge outcomes with cohorts so we also have the subjects with 0 outcomes:
  outcomes$y <- ff::ff(1, length = nrow(outcomes), vmode = "double")
  outcomes <- merge(cohorts, outcomes, by = c("rowId"), all.x = TRUE)
  idx <- ffbase::is.na.ff(outcomes$y)
  idx <- ffbase::ffwhich(idx, idx == TRUE)
  outcomes$y <- ff::ffindexset(x = outcomes$y,
                               index = idx,
                               value = ff::ff(0, length = length(idx), vmode = "double"))

  if (removeDropouts) {
    # Select only subjects with observation spanning the full window, or with an outcome:
    fullWindowLength <- ffbase::max.ff(plpData$cohorts$time)
    t <- outcomes$y != 0 | outcomes$time == fullWindowLength
    outcomes <- outcomes[ffbase::ffwhich(t, t == TRUE), ]

    idx <- ffbase::ffmatch(x = covariates$rowId, table = outcomes$rowId)
    idx <- ffbase::ffwhich(idx, !is.na(idx))
    covariates <- covariates[idx, ]
  }

  buildKnn(outcomes = outcomes,
           covariates = covariates,
           indexFolder = indexFolder,
           overwrite = overwrite)

  invisible(indexFolder)
}

#' Create predictive probabilities using KNN.
#'
#' @details
#' Generates predictions for the population specified in plpData.
#'
#' @return
#' The value column in the result data.frame is: logistic: probabilities of the outcome, poisson:
#' Poisson rate (per day) of the outome, survival: hazard rate (per day) of the outcome.
#'
#' @param indexFolder   Path to a local folder where the KNN classifier index is be stored.
#' @param k             The number of nearest neighbors to use to predict the outcome.
#' @param weighted      Should the prediction be weigthed by the (inverse of the ) distance metric?
#' @param threads       Number of parallel threads to used for the computation.
#' @param plpData       An object of type \code{plpData} as generated using \code{getDbPlpData}.
#' @export
predictKnnUsingPlpData <- function(indexFolder, k = 1000, weighted = TRUE, threads = 10, plpData) {

  covariates <- plpData$covariates
  cohorts <- plpData$cohorts

  if (length(plpData$metaData$cohortIds) > 1) {
    stop("Currently not supporting multiple cohort IDs")
  }

  if (!is.null(plpData$exclude) && nrow(plpData$exclude) != 0) {
    if (length(plpData$metaData$outcomeIds) > 1) {
      stop("Currently not supporting multiple outcome IDs")
    }
    # Filter subjects with previous outcomes:
    exclude <- plpData$exclude
    t <- ffbase::ffmatch(x = cohorts$rowId, table = exclude$rowId, nomatch = 0L) > 0L
    if (ffbase::any.ff(t)) {
      cohorts <- cohorts[ffbase::ffwhich(t, t == FALSE), ]
    }
    t <- ffbase::ffmatch(x = covariates$rowId, table = exclude$rowId, nomatch = 0L) > 0L
    if (ffbase::any.ff(t)) {
      covariates <- covariates[ffbase::ffwhich(t, t == FALSE), ]
    }
  }
  prediction <- predictKnn(covariates = covariates,
                           cohorts = cohorts,
                           indexFolder = indexFolder,
                           k = k,
                           weighted = weighted,
                           threads = threads)
  return(prediction)
}



