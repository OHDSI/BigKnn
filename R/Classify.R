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

#' Predict using a K-nearest neighbor (KNN) classifier
#'
#' @description
#' \code{predictKnn} uses a KNN classifier to generate predictions.
#'
#' @param covariates    A ffdf object containing the covariates with predefined columns (see below).
#' @param indexFolder   Path to a local folder where the KNN classifier index can be stored.
#' @param k             The number of nearest neighbors to use to predict the outcome.
#' @param weighted      Should the prediction be weigthed by the (inverse of the ) distance metric?
#' @param checkSorting  Check if the data are sorted appropriately, and if not, sort.
#' @param quiet         If true, (warning) messages are surpressed.
#'
#' @details
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
#' A data.frame with two columns:
#' \tabular{lll}{
#'   \verb{rowId}  	\tab(integer) \tab Row ID is used to link multiple covariates (x) to a single outcome (y) \cr
#'   \verb{prediction}    \tab(real) \tab A number between 0 and 1 representing the probability of the outcome  \cr
#' }
#' 
#' @export
predictKnn <- function(covariates,
                       indexFolder, 
                       k = 1000,
                       weighted = TRUE,
                       checkSorting = TRUE,
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
  knn <- rJava::new(rJava::J("org.ohdsi.bigKnn.LuceneKnn"), indexFolder)
  knn$openForReading();
  knn$setK(as.integer(k))
  knn$setWeighted(weighted)
  result <- data.frame()
  chunks <- bit::chunk(covariates, by = 100000)
  pb <- txtProgressBar(style = 3)
  for (i in 1:length(chunks)){
    prediction <- knn$predict(rJava::.jarray(covariates$rowId[chunks[[i]]]), 
                              rJava::.jarray(covariates$covariateId[chunks[[i]]]),
                              rJava::.jarray(covariates$covariateValue[chunks[[i]]]))
    prediction <- lapply(prediction, rJava::.jevalArray)
    prediction <- data.frame(rowId = prediction[[1]], value = prediction[[2]])
    result <- rbind(result, prediction)
    setTxtProgressBar(pb, i/length(chunks))
  }
  prediction <- knn$finalizePredict()
  prediction <- lapply(prediction, rJava::.jevalArray)
  prediction <- data.frame(rowId = prediction[[1]], value = prediction[[2]])
  result <- rbind(result, prediction)
  close(pb)
  delta <- Sys.time() - start
  writeLines(paste("Prediction took", signif(delta, 3), attr(delta, "units")))
  return(result)
}
