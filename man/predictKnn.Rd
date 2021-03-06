% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/Classify.R
\name{predictKnn}
\alias{predictKnn}
\title{Predict using a K-nearest neighbor (KNN) classifier}
\usage{
predictKnn(
  cohorts,
  covariates,
  indexFolder,
  k = 1000,
  weighted = TRUE,
  threads = 1
)
}
\arguments{
\item{cohorts}{An Andromeda table containing the cohorts with predefined columns (see below).}

\item{covariates}{An Andromeda table containing the covariates with predefined columns (see below).}

\item{indexFolder}{Path to a local folder where the KNN classifier index can be stored.}

\item{k}{The number of nearest neighbors to use to predict the outcome.}

\item{weighted}{Should the prediction be weighted by the (inverse of the ) distance metric?}

\item{threads}{Number of parallel threads to used for the computation.}
}
\value{
A data.frame with two columns: \tabular{lll}{ \verb{rowId} \tab(integer) \tab Row ID is used to
link multiple covariates (x) to a single outcome (y) \cr \verb{prediction} \tab(real) \tab A number
between 0 and 1 representing the probability of the outcome \cr }
}
\description{
\code{predictKnn} uses a KNN classifier to generate predictions.
}
\details{
These columns are expected in the covariates object: \tabular{lll}{ \verb{rowId} \tab(integer) \tab
Row ID is used to link multiple covariates (x) to a single outcome (y) \cr \verb{covariateId}
\tab(integer) \tab A numeric identifier of a covariate \cr \verb{covariateValue} \tab(real) \tab
The value of the specified covariate \cr } This column is expected in the covariates object:
\tabular{lll}{ \verb{rowId} \tab(integer) \tab Row ID is used to link multiple covariates (x) to a
single outcome (y) \cr }
}
