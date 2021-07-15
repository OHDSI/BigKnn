library(testthat)

context("basics")

# Test init
indexFolder <- tempfile("indexFolder")

covariates <- data.frame(rowId = c(1, 1, 1, 2, 2, 3),
                         covariateId = c(10, 11, 12, 10, 11, 12),
                         covariateValue = c(1, 1, 1, 1, 1, 1))
cohorts <- data.frame(rowId = c(1, 2, 3))

outcomes <- data.frame(rowId = c(1, 2, 3), y = c(1, 0, 0))

predictionData <- Andromeda::andromeda(covariates = covariates, 
                                       outcomes = outcomes,
                                       cohorts = cohorts)


test_that("Build simple model", {
  buildKnn(outcomes = predictionData$outcomes, 
           covariates = predictionData$covariates, 
           indexFolder = indexFolder)
  
  expect_true(file.exists(indexFolder))
})

test_that("Simple prediction", {
  prediction <- predictKnn(cohorts = predictionData$cohorts, 
                           covariates = predictionData$covariates, 
                           indexFolder = indexFolder,
                           k = 1,
                           weighted = TRUE)
  prediction <- prediction[order(prediction$rowId), ]
  expect_equal(prediction$value, outcomes$y)
})

# Test cleanup
unlink(indexFolder)
Andromeda::close(predictionData)
