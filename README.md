BigKnn
======

[![Build Status](https://github.com/OHDSI/BigKnn/workflows/R-CMD-check/badge.svg)](https://github.com/OHDSI/BigKnn/actions?query=workflow%3AR-CMD-check)
[![codecov.io](https://codecov.io/github/OHDSI/BigKnn/coverage.svg?branch=master)](https://codecov.io/github/OHDSI/BigKnn?branch=master)

BigKnn is part of [HADES](https://ohdsi.github.io/Hades).

Introduction
============
An R package implementing a large scale k-nearest neighbor (KNN) classifier using the [Lucene](https://lucene.apache.org/) search engine.

Features
========
- Build KNN classifiers of arbitrary scale (up to millions of rows, millions of features)
- Fast classification performance due to use of highly optimized search engine (Lucene)
- Supports both weighted and unweighted KNN

Examples
========
```r
covariates <- data.frame(rowIds = c(1,1,1,2,2,3),
                         covariateIds = c(10,11,12,10,11,12),
                         covariateValues = c(1,1,1,1,1,1))

outcomes <- data.frame(rowIds = c(1,2,3),
                       y = c(1,0,0))
					   
dataForPrediction <- Andromeda::andromeda(covariates = covariates, 
                                          outcomes = outcomes)

indexFolder <- "s:/temp/lucene"

buildKnn(outcomes = dataForPrediction$outcomes,
         covariates = dataForPrediction$covariates,
         indexFolder = indexFolder)

prediction <- predictKnn(outcomes = dataForPrediction$outcomes,
                         covariates = dataForPrediction$covariates,
                         indexFolder = indexFolder,
                         k = 10,
                         weighted = TRUE)
```

Technology
============
BigKnn is an R package using the Java based [Lucene](https://lucene.apache.org/) search engine. The data for the KNN is stored in a folder on the local file system.

System Requirements
===================
Running the package requires R with the package rJava installed. Also requires Java 1.8 or higher.

Installation
=============

1. See the instructions [here](https://ohdsi.github.io/Hades/rSetup.html) for configuring your R environment, including Java.

2. Use the following commands in R to install the BigKnn package:

  ```r
  install.packages("remotes")
  remotes::install_github("ohdsi/BigKnn")
  ```

User Documentation
==================
Documentation can be found on the [package website](https://ohdsi.github.io/BigKnn).

PDF versions of the documentation are also available:
* Package manual: [BigKnn manual](https://raw.githubusercontent.com/OHDSI/BigKnn/master/extras/BigKnn.pdf) 

Support
=======
* Developer questions/comments/feedback: <a href="http://forums.ohdsi.org/c/developers">OHDSI Forum</a>
* We use the <a href="https://github.com/OHDSI/BigKnn/issues">GitHub issue tracker</a> for all bugs/issues/enhancements

Contributing
============
Read [here](https://ohdsi.github.io/Hades/contribute.html) how you can contribute to this package.

License
=======
BigKnn is licensed under Apache License 2.0. Lucene fall under its own Apache License 2.0.

Development
===========
BigKnn is being developed in R Studio and Eclipse

### Development status

Stable.
