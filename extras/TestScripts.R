options(fftempdir = "s:/temp")

covariates <- data.frame(rowIds = c(1, 1, 1, 2, 2, 3),
                         covariateIds = c(10, 11, 12, 10, 11, 12),
                         covariateValues = c(1, 1, 1, 1, 1, 1))
cohorts <- data.frame(rowIds = c(1, 2, 3))

outcomes <- data.frame(rowIds = c(1, 2, 3), y = c(1, 0, 0))

indexFolder <- "s:/temp/lucene3"

covariates <- ff::as.ffdf(covariates)
outcomes <- ff::as.ffdf(outcomes)


buildKnn(outcomes = outcomes, covariates = covariates, indexFolder = indexFolder)


prediction <- predictKnn(covariates = ff::as.ffdf(covariates),
                         cohorts = ff::as.ffdf(cohorts),
                         indexFolder = indexFolder,
                         k = 10,
                         weighted = TRUE)


# Large example from PLP:
library(PatientLevelPrediction)
library(BigKnn)
options(fftempdir = "s:/temp")
indexFolder <- "s:/temp/lucene"

plpData <- loadPlpData("S:/Temp/PlpVignette/plpData")
parts <- splitData(plpData, c(0.75, 0.25))
savePlpData(parts[[1]], "s:/temp/PlpVignette/plpData_train")
savePlpData(parts[[2]], "s:/temp/PlpVignette/plpData_test")



plpData <- loadPlpData("S:/Temp/PlpVignette/plpData_train")



# Build an outcomes object for all subjects (not just those that have an outcome):
outcomes <- plpData$outcomes
outcomes$y <- ff::ff(1, length = nrow(plpData$outcomes), vmode = "double")
outcomes <- merge(plpData$cohorts, outcomes, by = c("rowId"), all.x = TRUE)
idx <- ffbase::is.na.ff(outcomes$y)
idx <- ffbase::ffwhich(idx, idx == TRUE)
outcomes$y <- ff::ffindexset(x = outcomes$y,
                             index = idx,
                             value = ff::ff(0, length = length(idx), vmode = "double"))

covariates <- plpData$covariates
rownames(covariates) <- NULL  #Needs to be null or the ordering of ffdf will fail
covariates <- covariates[ff::ffdforder(covariates[c("rowId")]), ]
ffbase::save.ffdf(covariates, dir = "s:/temp/covariates")
ffbase::save.ffdf(outcomes, dir = "s:/temp/outcomes")

ffbase::load.ffdf(dir = "s:/temp/covariates")
ffbase::load.ffdf(dir = "s:/temp/outcomes")

buildKnn(outcomes = outcomes,
         covariates = covariates,
         indexFolder = indexFolder,
         checkSorting = FALSE,
         checkRowIds = FALSE)


plpData <- loadPlpData("S:/Temp/PlpVignette/plpData_test")

# Build an outcomes object for all subjects (not just those that have an outcome):
outcomes <- plpData$outcomes
outcomes$y <- ff::ff(1, length = nrow(plpData$outcomes), vmode = "double")
outcomes <- merge(plpData$cohorts, outcomes, by = c("rowId"), all.x = TRUE)
idx <- ffbase::is.na.ff(outcomes$y)
idx <- ffbase::ffwhich(idx, idx == TRUE)
outcomes$y <- ff::ffindexset(x = outcomes$y,
                             index = idx,
                             value = ff::ff(0, length = length(idx), vmode = "double"))

covariates <- plpData$covariates
rownames(covariates) <- NULL  #Needs to be null or the ordering of ffdf will fail
covariates <- covariates[ff::ffdforder(covariates[c("rowId")]), ]

ffbase::save.ffdf(covariates, dir = "s:/temp/covariates2")
ffbase::save.ffdf(outcomes, dir = "s:/temp/outcomes2")

ffbase::load.ffdf(dir = "s:/temp/covariates2")
ffbase::load.ffdf(dir = "s:/temp/outcomes2")

prediction <- predictKnn(covariates = covariates,
                         indexFolder = indexFolder,
                         k = 1000,
                         weighted = TRUE,
                         checkSorting = FALSE)


# Example using plpData interface:
library(PatientLevelPrediction)
library(BigKnn)
options(fftempdir = "s:/temp")
indexFolder <- "s:/temp/lucene"
plpData <- loadPlpData("S:/Temp/PlpVignette/plpData_train")

buildKnnFromPlpData(plpData = plpData, indexFolder = indexFolder)

plpData <- loadPlpData("S:/Temp/PlpVignette/plpData_test")

prediction <- predictKnnUsingPlpData(indexFolder = indexFolder,
                                     k = 1000,
                                     weighted = TRUE,
                                     plpData,
                                     threads = 10)
attr(prediction, "modelType") <- "logistic"
computeAuc(prediction, plpData)
plotCalibration(prediction, plpData)
