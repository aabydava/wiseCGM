% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/format_dexcom.R
\name{format_dexcom}
\alias{format_dexcom}
\title{Format DEXCOM data}
\usage{
format_dexcom(input.path, rds.out = NULL, output.file = TRUE)
}
\arguments{
\item{input.path}{The name of the file which the data are to be read from.}

\item{rds.out}{The name of the output file}

\item{output.file}{logical. If TRUE, will output a list containing the formatted DEXCOM data and meta data.}
}
\description{
Format DEXCOM data into an analyzable dataframe.
}
