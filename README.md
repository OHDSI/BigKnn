BigKnn
======

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

indexFolder <- "s:/temp/lucene"

buildKnn(outcomes = ff::as.ffdf(outcomes),
         covariates = ff::as.ffdf(covariates),
         indexFolder = indexFolder)

prediction <- predictKnn(covariates = ff::as.ffdf(covariates),
                         indexFolder = indexFolder,
                         k = 10,
                         weighted = TRUE)
```

Technology
============
BigKnn is an R package using the Java based [Lucene](https://lucene.apache.org/) search engine. The data for the KNN is stored in a folder on the local file system.

System Requirements
===================
Requires R. Also requires Java 1.7 or higher (Oracle Java is recommended) .

Dependencies
============
Please note that this package requires Java to be installed. If you don't have Java already intalled on your computed (on most computers it already is installed), go to [java.com](http://java.com) to get the latest version.

BigKnn also depends on the OHDSI Cyclops and OhdsiRTools packages.


Getting Started
===============
Use the following commands in R to install the BigKnn package:

```r
install.packages("drat")
drat::addRepo("OHDSI")
install.packages("BigKnn")
```

Getting Involved
=============
* Package manual: [BigKnn manual](https://raw.githubusercontent.com/OHDSI/BigKnn/master/extras/BigKnn.pdf) 
* Developer questions/comments/feedback: <a href="http://forums.ohdsi.org/c/developers">OHDSI Forum</a>
* We use the <a href="../../issues">GitHub issue tracker</a> for all bugs/issues/enhancements

License
=======
BigKnn is licensed under Apache License 2.0. Lucene fall under its own Apache License 2.0.

Development
===========
BigKnn is being developed in R Studio and Eclipse

###Development status
[![Build Status](https://travis-ci.org/OHDSI/BigKnn.svg?branch=master)](https://travis-ci.org/OHDSI/BigKnn)
[![codecov.io](https://codecov.io/github/OHDSI/BigKnn/coverage.svg?branch=master)](https://codecov.io/github/OHDSI/BigKnn?branch=master)

Under development. Use at your own risk.
