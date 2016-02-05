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

#' Build a K-nearest neighbor (KNN) classifier
#'
#' @description
#' \code{buildKnn} loads data from two ffdf objects, and inserts them into a KNN classifier.
#'
#' @param outcomes      A ffdf object containing the outcomes with predefined columns (see below).
#' @param covariates    A ffdf object containing the covariates with predefined columns (see below).
#' @param indexFolder   Path to a local folder where the KNN classifier index can be stored.
#' @param overwrite     Automatically overwrite if an index already exists?
#' @param checkSorting  Check if the data are sorted appropriately, and if not, sort.
#' @param checkRowIds   Check if all rowIds in the covariates appear in the outcomes.
#' @param quiet         If true, (warning) messages are surpressed.
#'
#' @details
#' These columns are expected in the outcome object:
#' \tabular{lll}{
#'   \verb{rowId}  	\tab(integer) \tab Row ID is used to link multiple covariates (x) to a single outcome (y) \cr
#'   \verb{y}    \tab(real) \tab The outcome variable \cr
#' }
#'
#' These columns are expected in the covariates object:
#' \tabular{lll}{
#'   \verb{rowId}  	\tab(integer) \tab Row ID is used to link multiple covariates (x) to a single outcome (y) \cr
#'   \verb{covariateId}    \tab(integer) \tab A numeric identifier of a covariate  \cr
#'   \verb{covariateValue}    \tab(real) \tab The value of the specified covariate \cr
#' }
#'
#' Note: If checkSorting is turned off, the covariate table should be sorted by rowId.
#'
#' @return
#' Nothing
#'
#' @export
buildKnn <- function(outcomes,
                     covariates,
                     indexFolder,
                     overWrite = TRUE,
                     checkSorting = TRUE,
                     checkRowIds = TRUE,
                     quiet = FALSE) {
  start <- Sys.time()
  if (checkSorting){
    if (!Cyclops::isSorted(covariates, c("rowId"))){
      if(!quiet) {
        writeLines("Sorting covariates by rowId")
      }
      rownames(covariates) <- NULL #Needs to be null or the ordering of ffdf will fail
      covariates <- covariates[ff::ffdforder(covariates[c("rowId")]),]
    }
  }
  if (checkRowIds){
    mapped <- ffbase::ffmatch(x = covariates$rowId, table = outcomes$rowId)
    if (ffbase::any.ff(ffbase::is.na.ff(mapped))){
      if(!quiet) {
        writeLines("Removing covariate values with rowIds that are not in outcomes")
      }
      rownames(covariates) <- NULL
      covariates <- covariates[ffbase::ffwhich(mapped, is.na(mapped) == FALSE),]
    }
  }
  knn <- rJava::new(rJava::J("org.ohdsi.bigKnn.LuceneKnn"), indexFolder)
  knn$openForWriting(overWrite);
  t <- (outcomes$y == 1)
  nonZeroOutcomeRowIds <- outcomes$rowId[ffbase::ffwhich(t, t == TRUE)]

  for (i in bit::chunk(nonZeroOutcomeRowIds, by = 100000)){
    knn$addNonZeroOutcomes(rJava::.jarray(nonZeroOutcomeRowIds[i]))
  }
  chunks <- bit::chunk(covariates, by = 100000)
  pb <- txtProgressBar(style = 3)
  for (i in 1:length(chunks)){
    knn$addCovariates(rJava::.jarray(covariates$rowId[chunks[[i]]]), 
                      rJava::.jarray(covariates$covariateId[chunks[[i]]]),
                      rJava::.jarray(covariates$covariateValue[chunks[[i]]]))
    setTxtProgressBar(pb, i/length(chunks))
  }
  knn$finalizeWriting()
  close(pb)
  delta <- Sys.time() - start
  writeLines(paste("Building KNN index took", signif(delta, 3), attr(delta, "units")))
}

