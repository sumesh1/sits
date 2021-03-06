% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sits_conf_matrix.R
\name{sits_conf_matrix}
\alias{sits_conf_matrix}
\title{Accuracy assessment of classification based on a confusion matrix}
\usage{
sits_conf_matrix(data, conv.lst = NULL)
}
\arguments{
\item{data}{Set of classified samples whose labels are known.}

\item{conv.lst}{List with labels to be converted.
If NULL no conversion is done.}
}
\value{
A confusion matrix assessment produced by the caret package.
}
\description{
Evaluates the confusion matrix based on
"reference" and "predicted" values
provided in a sits tibble that has been classified.
This function takes two kinds of input:
(a) The output of the \code{\link[sits]{sits_classify}} function
(a tibble with a list of predicted values);
(b) The output of the \code{\link[sits]{sits_kfold_validate}} function
(a tibble with two columns - predicted and reference).
This function returns the Overall Accuracy, User's Accuracy,
Producer's Accuracy, error matrix (confusion matrix), and Kappa value.
}
\examples{
# read a tibble with 400 samples of Cerrado and 346 samples of Pasture
data(cerrado_2classes)
# perform a 2 fold validation of this sample file
pred_ref.tb <- sits_kfold_validate(cerrado_2classes, folds = 2,
               ml_method = sits_rfor(num_trees = 300))
# calculate and print the confusion matrix
conf.mx <- sits_conf_matrix(pred_ref.tb)
}
\author{
Rolf Simoes, \email{rolf.simoes@inpe.br}

Gilberto Camara, \email{gilberto.camara@inpe.br}
}
