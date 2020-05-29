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
#' Note: If checkSorting is turned off, the covariate table should be sorted by rowId.
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

  
  
  
  predictionThread <- function(rowIds, indexFolder, k, weighted){
    result <- Andromeda::groupApply(tempData$covariates %>% dplyr::filter(rowId %in% rowIds),
                                    predictionKnn,
                                    groupVariable = "rowId",
                                    indexFolder = indexFolder, 
                                    k = k, 
                                    weighted = weighted)
    result <- do.call(rbind, result)
    return(result)
  }
  
  predictionKnn <- function(batch, indexFolder, k, weighted) {
    knn <- rJava::new(rJava::J("org.ohdsi.bigKnn.LuceneKnn"), indexFolder)
    knn$openForReading()
    knn$setK(as.integer(k))
    knn$setWeighted(weighted)
    temp <- as.data.frame(batch)
    writeLines(paste0(temp[1,], collapse = '-'))
    prediction <- knn$predict(rJava::.jarray(as.double(as.character(temp$rowId))),
                                rJava::.jarray(as.double(as.character(temp$covariateId))),
                                rJava::.jarray(as.double(as.character(temp$covariateValue))))
    prediction <- lapply(prediction, rJava::.jevalArray)
    prediction <- data.frame(rowId = prediction[[1]], value = prediction[[2]])

    writeLines(paste0(prediction[1,], collapse = '-'  ))
    
    
    knn$close()
    return(prediction)
  }
  
  rowIds <- tempData$covariates %>% dplyr::distinct(rowId)
  rowIds <- as.data.frame(rowIds)$rowId

  cluster <- ParallelLogger::makeCluster(threads)
  ParallelLogger::clusterRequire(cluster, "BigKnn")
  #chunks <- bit::chunk(covariates, length.out = threads)
  chunks <- split(rowIds, ceiling(seq_along(rowIds)/100))
  results <- ParallelLogger::clusterApply(cluster = cluster,
                                          x = chunks,
                                          fun = predictionThread,
                                          indexFolder = indexFolder,
                                          k = k,
                                          weighted = weighted)
  ParallelLogger::stopCluster(cluster)
  results <- do.call(rbind, results)
  
  #lastRowIds <- vector(length = length(chunks)) # added during debug
  #results <- results[!(results$rowId %in% lastRowIds), ] # what is lastRowIds
  
  # Process rows at thread boundaries:
  #lastRowIds <- vector(length = length(chunks))
  #for (i in 1:length(chunks)) {
  # lastRowIds[i] <- covariates$rowId[chunks[[i]][2]]
  #}
  #results <- results[!(results$rowId %in% lastRowIds), ]
  #t <- ffbase::is.na.ff(ffbase::ffmatch(covariates$rowId, ff::as.ff(lastRowIds)))
  #covarSubset <- covariates[ffbase::ffwhich(t, t == FALSE), ]
  #knn <- rJava::new(rJava::J("org.ohdsi.bigKnn.LuceneKnn"), indexFolder)
  #knn$openForReading()
  #knn$setK(as.integer(k))
  #knn$setWeighted(weighted)
  #prediction <- knn$predict(rJava::.jarray(as.double(ff::as.data.frame.ffdf(covarSubset$rowId))),
  #                          rJava::.jarray(as.double(ff::as.data.frame.ffdf(covarSubset$covariateId))),
  #                          rJava::.jarray(as.double(ff::as.data.frame.ffdf(covarSubset$covariateValue))))
  #prediction <- lapply(prediction, rJava::.jevalArray)
  #prediction <- data.frame(rowId = prediction[[1]], value = prediction[[2]])
  #results <- rbind(results, prediction)
  
  #prediction <- knn$finalizePredict()
  #prediction <- lapply(prediction, rJava::.jevalArray)
  #prediction <- data.frame(rowId = prediction[[1]], value = prediction[[2]])
  #results <- rbind(results, prediction)
  
  # Add any rows with no covariate values:
  ##t <- ffbase::is.na.ff(ffbase::ffmatch(cohorts$rowId, ff::as.ff(results$rowId))) 
  t <- tempData$cohorts %>% filter(!rowId %in% !!results$rowId)
  
  #if (ffbase::any.ff(t)) {
  if(nrow(t)>0){
    #prediction <- data.frame(rowId = ff::as.ram(cohorts$rowId[ffbase::ffwhich(t, t == TRUE)]),
    prediction <- data.frame(rowId = as.data.frame(t)$rowId,
                             value = 0)
    results <- rbind(results, prediction)
  }
  
  delta <- Sys.time() - start
  writeLines(paste("Prediction took", signif(delta, 3), attr(delta, "units")))
  return(results)
}
