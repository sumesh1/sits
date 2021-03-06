% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_classify_cube.R
\name{.sits_classify_interval}
\alias{.sits_classify_interval}
\title{Classify one interval of data}
\usage{
.sits_classify_interval(DT, ml_model, multicores)
}
\arguments{
\item{DT}{A data.table with distance values.}

\item{ml_model}{Machine learning model to be applied.}

\item{multicores}{Number of cores to process the time series.}
}
\value{
A data table with predicted values of probs
}
\description{
Classify one interval of data
}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}
}
\keyword{internal}
