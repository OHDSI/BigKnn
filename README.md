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

To be able to use Windows authentication for SQL Server, you have to install the JDBC driver. Download the .exe from [Microsoft](http://www.microsoft.com/en-us/download/details.aspx?displaylang=en&id=11774) and run it, thereby extracting its contents to a folder. In the extracted folder you will find the file sqljdbc_4.0/enu/auth/x64/sqljdbc_auth.dll (64-bits) or sqljdbc_4.0/enu/auth/x86/sqljdbc_auth.dll (32-bits), which needs to be moved to location on the system path, for example to c:/windows/system32.

DatabaseConnector also depends on the OHDSI Cyclops and PatientLevelPrediction packages.


Getting Started
===============
Use the following commands in R to install the DatabaseConnector package:

  ```r
install.packages("devtools")
library(devtools)
install_github("ohdsi/SqlRender") 
install_github("ohdsi/DatabaseConnector") 
install_github("ohdsi/OhdsiRTools") 
install_github("ohdsi/Cyclops") 
install_github("ohdsi/PatientLevelPrediction") 
install_github("ohdsi/BigKnn") 
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
Under development. Use at your own risk.