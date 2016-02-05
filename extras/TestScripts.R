options(fftempdir = "s:/temp")

covariates <- data.frame(rowIds = c(1,1,1,2,2,3),
                         covariateIds = c(10,11,12,10,11,12),
                         covariateValues = c(1,1,1,1,1,1))

outcomes <- data.frame(rowIds = c(1,2,3),
                       y = c(1,0,0))

indexFolder <- "s:/temp/lucene"

covariates <- ff::as.ffdf(covariates)
outcomes <- ff::as.ffdf(outcomes)


buildKnn(outcomes = outcomes,
         covariates = covariates,
         indexFolder = indexFolder)
           

prediction <- predictKnn(covariates = ff::as.ffdf(covariates),
                         indexFolder = indexFolder,
                         k = 10,
                         weighted = TRUE)
