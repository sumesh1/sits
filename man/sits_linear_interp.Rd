% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_filters.R
\name{sits_linear_interp}
\alias{sits_linear_interp}
\title{Interpolation function of the time series in a sits tibble}
\usage{
sits_linear_interp(data = NULL, n = 23)
}
\arguments{
\item{data}{A tibble with time series data and metadata.}

\item{n}{Number of time series elements to be created
between start date and end date.}
}
\value{
A sits tibble with same samples and the new bands.
}
\description{
Computes the linearly interpolated bands for a given resolution
              using the R base function approx.
}
\examples{
# Retrieve a time series with values of NDVI
data(point_ndvi)
# find out how many time instances are there
n_times <- NROW(sits_time_series(point_ndvi))
# interpolate three times more points
point_int.tb <- sits_linear_interp(point_ndvi, n = 3*n_times)
# plot the result
plot(point_int.tb)
}
\author{
Rolf Simoes, \email{rolf.simoes@inpe.br}
}
