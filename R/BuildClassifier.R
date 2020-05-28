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

#' Build a K-nearest neighbor (KNN) classifier
#'
#' @description
#' \code{buildKnn} loads data from two ffdf objects, and inserts them into a KNN classifier.
#'
#' @param population       -too add-
#' @param covariateData  -too add-
#' @param indexFolder    Path to a local folder where the KNN classifier index can be stored.
#' @param overwrite      Automatically overwrite if an index already exists?
#' @param checkSorting   Check if the data are sorted appropriately, and if not, sort.
#' @param quiet          If true, (warning) messages are suppressed.
#'
#' @details
#' These columns are expected in the outcome object: \tabular{lll}{ \verb{rowId} \tab(integer) \tab
#' Row ID is used to link multiple covariates (x) to a single outcome (y) \cr \verb{y} \tab(real) \tab
#' The outcome variable \cr }
#' These columns are expected in the covariates object: \tabular{lll}{ \verb{rowId} \tab(integer) \tab
#' Row ID is used to link multiple covariates (x) to a single outcome (y) \cr \verb{covariateId}
#' \tab(integer) \tab A numeric identifier of a covariate \cr \verb{covariateValue} \tab(real) \tab
#' The value of the specified covariate \cr }
#' Note: If checkSorting is turned off, the covariate table should be sorted by rowId.
#'
#' @return
#' Nothing
#'
#' @export
buildKnn <- function(population,
                     covariateData,
                     indexFolder,
                     overwrite = TRUE,
                     checkSorting = TRUE,
                     quiet = FALSE) {
  start <- Sys.time()
  
  
  tempData <- andromeda(covariates = covariateData$covariates,
                        population = population)
  
  if (checkSorting) {
    if (!quiet) {
      writeLines("Sorting covariates by rowId")
    }
    #rownames(covariates) <- NULL  #Needs to be null or the ordering of ffdf will fail
    tempData$covariatesSorted <- tempData$covariates %>% dplyr::arrange(desc(rowId))
    tempData$covariates <- NULL
    tempData$covariates <- tempData$covariatesSorted
    tempData$covariatesSorted <- NULL
    #covariates <- covariates[ff::ffdforder(covariates[c("rowId")]), ]
    
  }

  knn <- rJava::new(rJava::J("org.ohdsi.bigKnn.LuceneKnn"), indexFolder)
  knn$openForWriting(overwrite)
  #t <- (outcomes$y == 1)
    #outcomes$rowId[ffbase::ffwhich(t, t == TRUE)]
  #for (i in bit::chunk(nonZeroOutcomeRowIds, by = 1e+05)) {
  #  knn$addNonZeroOutcomes(rJava::.jarray(as.double(nonZeroOutcomeRowIds[i])))
  #}
  
  tempData$nonZeroOutcomeRowIds <- tempData$population %>% dplyr::filter(y == 1)
  
  addOutcomes <- function(batch) {
    #writeLines(paste0(as.double(as.character(as.data.frame(batch)$rowId))[1:10], collapse = '-'  ))
    nonzeros <- as.double(as.character(as.data.frame(batch)$rowId))
    knn$addNonZeroOutcomes(rJava::.jarray(as.double(nonzeros)))
  }
  Andromeda::batchApply(tempData$nonZeroOutcomeRowIds, addOutcomes)
  
  
  #chunks <- bit::chunk(covariates, by = 1e+05)
  pb <- txtProgressBar(style = 3)
  #for (i in 1:length(chunks)) {
  #  knn$addCovariates(rJava::.jarray(as.double(covariates$rowId[chunks[[i]]])),
  #                    rJava::.jarray(as.double(covariates$covariateId[chunks[[i]]])),
  #                    rJava::.jarray(as.double(covariates$covariateValue[chunks[[i]]])))
  #  setTxtProgressBar(pb, i/length(chunks))
  #}
  maxI <- ceiling(nrow(tempData$covariates)/100000)
  iout <- 1
  addCovariatesToJava <- function(batch, maxI) {
    cov <- as.data.frame(batch)
    knn$addCovariates(rJava::.jarray(as.double(as.character(cov$rowId))),
                      rJava::.jarray(as.double(as.character(cov$covariateId))),
                      rJava::.jarray(as.double(as.character(cov$covariateValue))))
    setTxtProgressBar(pb, iout/maxI)
    iout <<- iout+1
  }
  Andromeda::batchApply(tempData$covariates, addCovariatesToJava, maxI = maxI, batchSize = 1e+05)

  knn$finalizeWriting()
  close(pb)
  delta <- Sys.time() - start
  writeLines(paste("Building KNN index took", signif(delta, 3), attr(delta, "units")))
}

