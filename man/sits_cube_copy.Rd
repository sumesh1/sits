% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_cube.R
\name{sits_cube_copy}
\alias{sits_cube_copy}
\title{Creates the contents of a data cube}
\usage{
sits_cube_copy(cube, name, dest_dir, bands = NULL, srcwin = NULL)
}
\arguments{
\item{cube}{Input data cube}

\item{name}{Output cube name}

\item{dest_dir}{Destination directory}

\item{bands}{Bands to include in output (optional)}

\item{srcwin}{subwindow defined as c(xoff, yoff, xsize, ysize)}
}
\value{
Output data cube
}
\description{
Copies the metadata and data of a cube to a different
directory. This function can be use to transfer data on the cloud
to a local machine
}
\examples{
data_dir <- system.file("extdata/raster/cbers", package = "sits")

cbers_022024 <- sits_cube(type = "RASTER",
                          name = "cbers_022024",
                          satellite = "CBERS-4",
                          sensor = "AWFI",
                          resolution = "64m",
                          data_dir = data_dir,
                          parse_info = c("X1", "X2","band", "date"))

cbers_022024_copy <- sits_cube_copy(cbers_022024, name = "cb_022024_cp",
                                    dest_dir = tempdir(),
                                    bands = "B13")
}
