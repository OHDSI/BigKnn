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

#' Predict using a K-nearest neighbor (KNN) classifier
#'
#' @description
#' \code{predictKnn} uses a KNN classifier to generate predictions.
#'
#' @param covariates     An Andromeda table containing the covariates with predefined columns (see below).
#' @param cohorts        An Andromeda table containing the cohorts with predefined columns (see below).
#' @param indexFolder    Path to a local folder where the KNN classifier index can be stored.
#' @param k              The number of nearest neighbors to use to predict the outcome.
#' @param weighted       Should the prediction be weighted by the (inverse of the ) distance metric?
#' @param threads        Number of parallel threads to used for the computation.
#'
#' @details
#' These columns are expected in the covariates object: \tabular{lll}{ \verb{rowId} \tab(integer) \tab
#' Row ID is used to link multiple covariates (x) to a single outcome (y) \cr \verb{covariateId}
#' \tab(integer) \tab A numeric identifier of a covariate \cr \verb{covariateValue} \tab(real) \tab
#' The value of the specified covariate \cr } This column is expected in the covariates object:
#' \tabular{lll}{ \verb{rowId} \tab(integer) \tab Row ID is used to link multiple covariates (x) to a
#' single outcome (y) \cr }
#'
#' @return
#' A data.frame with two columns: \tabular{lll}{ \verb{rowId} \tab(integer) \tab Row ID is used to
#' link multiple covariates (x) to a single outcome (y) \cr \verb{prediction} \tab(real) \tab A number
#' between 0 and 1 representing the probability of the outcome \cr }
#'
#' @export
predictKnn <- function(cohorts,
                       covariates,
                       indexFolder,
                       k = 1000,
                       weighted = TRUE,
                       threads = 1) {
  start <- Sys.time()

  knn <- rJava::new(rJava::J("org.ohdsi.bigKnn.LuceneKnn"), indexFolder)
  knn$setK(as.integer(k))
  knn$setWeighted(weighted)
  knn$initPrediction(as.integer(threads))
  
  predict <- function(batch) {
    knn$predict(as.double(as.character(batch$rowId[1])),
                      rJava::.jarray(as.double(as.character(batch$covariateId))),
                      rJava::.jarray(as.double(as.character(batch$covariateValue))))
  }
  
  Andromeda::groupApply(tbl = covariates, 
                        "rowId",
                        fun = predict,
                        progressBar = TRUE)
  
  prediction <- knn$getPredictions()
  prediction <- lapply(prediction, rJava::.jevalArray)
  prediction <- tibble(rowId = prediction[[1]], value = prediction[[2]])

  # Add any rows with no covariate values:
  toAdd <- cohorts %>% 
    filter(!.data$rowId %in% local(prediction$rowId)) %>%
    mutate(value = 0) %>%
    collect()
  
  prediction <- bind_rows(prediction, toAdd)
  
  delta <- Sys.time() - start
  writeLines(paste("Prediction took", signif(delta, 3), attr(delta, "units")))
  return(prediction)
}
