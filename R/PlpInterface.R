# Copyright 2020 Observational Health Data Sciences and Informatics
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
#' @param population       The population. 
#' @param indexFolder      Path to a local folder where the KNN classifier index can be stored.
#' @param overwrite        Automatically overwrite if an index already exists?
#' @param cohortId         The ID of the specific cohort for which to fit a model.
#' @param outcomeId        The ID of the specific outcome for which to fit a model.
#'
#' @export
buildKnnFromPlpData <- function(plpData,
                                population,
                                indexFolder,
                                overwrite = TRUE,
                                cohortId = NULL,
                                outcomeId = NULL) {

  population$y <- 1
  population$y[population$outcomeCount == 0] <- 0
  tempAndromeda <- Andromeda::andromeda(population = population)
  
  covariates <- plpData$covariateData$covariates %>%
    filter(.data$rowId %in% local(population$rowId))
  
  buildKnn(outcomes = tempAndromeda$population,
           covariates = covariates,
           indexFolder = indexFolder,
           overwrite = overwrite)
  
  close(tempAndromeda)

  invisible(indexFolder)
}

#' Create predictive probabilities using KNN.
#'
#' @details
#' Generates predictions for the population specified in plpData.
#'
#' @return
#' The value column in the result data.frame is: logistic: probabilities of the outcome, poisson:
#' Poisson rate (per day) of the outcome, survival: hazard rate (per day) of the outcome.
#'
#' @param plpData       An object of type \code{plpData} as generated using \code{getDbPlpData}.
#' @param population    The population to predict for.
#' @param indexFolder   Path to a local folder where the KNN classifier index is be stored.
#' @param k             The number of nearest neighbors to use to predict the outcome.
#' @param weighted      Should the prediction be weigthed by the (inverse of the ) distance metric?
#' @param threads       Number of parallel threads to used for the computation.

#' @export
predictKnnUsingPlpData <- function(plpData, population, indexFolder, k = 1000, weighted = TRUE, threads = 10) {

  tempAndromeda <- Andromeda::andromeda(population = population)
  
  covariates <- plpData$covariateData$covariates %>%
    filter(.data$rowId %in% local(population$rowId))
  
  prediction <- predictKnn(cohorts = tempAndromeda$population,
                           covariates = covariates,
                           indexFolder = indexFolder,
                           k = k,
                           weighted = weighted,
                           threads = threads)
  
  close(tempAndromeda)
  
  return(prediction)
}
