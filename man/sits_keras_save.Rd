% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_keras.R
\name{sits_keras_save}
\alias{sits_keras_save}
\title{Save a Keras model for later processing in sits}
\usage{
sits_keras_save(
  model,
  hdffile = "./model_keras.h5",
  rdsfile = "./model_keras.rds"
)
}
\arguments{
\item{model}{An R Keras model.}

\item{hdffile}{An hdf5 file where the keras model is to be saved.}

\item{rdsfile}{A rds file where the R environment is to be saved.}
}
\description{
Takes a Keras model and saves it in two files.
One file is the keras model itself (saved as hdf5)
and the other is the R enviroment required for sits
to work with the model.
}
\author{
Gilberto Camara, \email{gilberto.camara@inpe.br}
}
