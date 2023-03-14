# Copyright 2021 Observational Health Data Sciences and Informatics
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

#' Build a K-nearest neighbor (KNN) classifier
#'
#' @description
#' \code{buildKnn} loads data from two Andromeda tables, and inserts them into a KNN classifier.
#'
#' @param outcomes       An Andromeda table containing the outcomes with predefined columns (see below).
#' @param covariates     An Andromeda table containing the covariates with predefined columns (see below).
#' @param indexFolder    Path to a local folder where the KNN classifier index can be stored.
#' @param overwrite      Automatically overwrite if an index already exists?
#'
#' @details
#' These columns are expected in the outcome object: \tabular{lll}{ \verb{rowId} \tab(integer) \tab
#' Row ID is used to link multiple covariates (x) to a single outcome (y) \cr \verb{y} \tab(real) \tab
#' The outcome variable \cr }
#' These columns are expected in the covariates object: \tabular{lll}{ \verb{rowId} \tab(integer) \tab
#' Row ID is used to link multiple covariates (x) to a single outcome (y) \cr \verb{covariateId}
#' \tab(integer) \tab A numeric identifier of a covariate \cr \verb{covariateValue} \tab(real) \tab
#' The value of the specified covariate \cr }
#'
#' @return
#' Nothing
#'
#' @export
buildKnn <- function(outcomes,
                     covariates,
                     indexFolder,
                     overwrite = TRUE) {
  if (!inherits(outcomes, "tbl_dbi") && !inherits(outcomes, "ArrowObject") && !inherits(outcomes, "arrow_dplyr_query")) {
    stop("Outcomes argument must be an Andromeda (or DBI) table")
  }
  if (!inherits(covariates, "tbl_dbi") && !inherits(covariates, "ArrowObject") && !inherits(covariates, "arrow_dplyr_query")) {
    stop("Covariates argument must be an Andromeda (or DBI) table")
  }

  start <- Sys.time()

  knn <- rJava::new(rJava::J("org.ohdsi.bigKnn.LuceneKnn"), indexFolder)
  knn$openForWriting(overwrite)

  addOutcomes <- function(batch) {
    knn$addNonZeroOutcomes(rJava::.jarray(as.double(batch$rowId)))
  }

  nonZeroOutcomeRows <- outcomes %>%
    filter(.data$y == 1)

  Andromeda::batchApply(nonZeroOutcomeRows, addOutcomes)

  addCovariatesToJava <- function(batch) {
    knn$addCovariates(
      as.double(as.character(batch$rowId[1])),
      rJava::.jarray(as.double(as.character(batch$covariateId))),
      rJava::.jarray(as.double(as.character(batch$covariateValue)))
    )
  }

  Andromeda::groupApply(
    tbl = covariates,
    groupVariable = "rowId",
    fun = addCovariatesToJava,
    progressBar = TRUE
  )

  knn$finalizeWriting()

  delta <- Sys.time() - start
  writeLines(paste("Building KNN index took", signif(delta, 3), attr(delta, "units")))
}
