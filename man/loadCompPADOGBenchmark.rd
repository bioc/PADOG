\name{loadCompPADOGBenchmark}
\alias{loadCompPADOGBenchmark}
\title{Benchmark for gene set analysis methods}
\description{
This function loads datasets needed to benchmark gene set analysis methods from data packages KEGGdzPathwaysGEO and KEGGandMetacoreDzPathwaysGEO.
}
\usage{
loadCompPADOGBenchmark(dataset = NULL, collection = NULL,envir = parent.frame(),assign=TRUE)
}
\arguments{
  \item{dataset}{
A character vector specifying the dataset(s) to load. Dataset names must
correspond to datasets available in the collection(s) specified by
\code{collection}. If \code{NULL}, all datasets in the selected
collection(s) are loaded. 
Collection names, "KEGGdzPathwaysGEO", and "KEGGandMetacoreDzPathwaysGEO", or "all" for both collections (42 datasets) can also be used. 
}

\item{collection}{
A character string specifying the benchmark data collection to use.
Valid values are \code{"KEGGdzPathwaysGEO"},
\code{"KEGGandMetacoreDzPathwaysGEO"}, or \code{"all"}.
If \code{"all"}, datasets from both collections are available.
If \code{NULL}, the collection is inferred from \code{dataset}, when
possible.
}

\item{envir}{
The environment into which the requested dataset(s) are loaded.
Defaults to \code{parent.frame()}.
}

\item{assign}{
If TRUE the requested dataset(s) are loaded, if not, just the names of the datasets that could be loaded given the 
dataset  and collection arguments.
}

}

\details{
See cited documents for more details.
}


\value{
  Invisibly returns the names of the datasets (as ExpressionSet) successfully loaded into
  \code{envir} if assig is TRUE. 
  The key elements to extract from each dataset in order to perform gene set enrichment analysis and use the results in the benchmark are shown in the example below.
  
}

\references{
Adi L. Tarca, Sorin Draghici, Gaurav Bhatti, Roberto Romero, Down-weighting overlapping genes improves gene set analysis, BMC Bioinformatics, 13(136), 2012.  \cr
Adi L. Tarca, Gaurav Bhatti, Roberto Romero, A Comparison of Gene Set Analysis Methods in Terms of Sensitivity, Prioritization and Specificity, PLoS One. 8(11), 2013. \cr
Falcon, S., Morgan, M., and Gentleman, R. (2007), An Introduction to Bioconductor's ExpressionSet Class.
}

\author{Adi Laurentiu Tarca <atarca@med.wayne.edu>}

\seealso{\code{\link{compPADOG}}}

\examples{

## Load one dataset from the KEGGdzPathwaysGEO collection
loadCompPADOGBenchmark(dataset = "GSE1297",collection = "KEGGdzPathwaysGEO")

## Load one dataset from the KEGGandMetacoreDzPathwaysGEO collection
loadCompPADOGBenchmark(dataset = "GSE1145",collection = "KEGGandMetacoreDzPathwaysGEO")

x = get("GSE1297")
exp = experimentData(x)
dataset = exp@name #name of dataset
disease = notes(exp)$disease # name of the disease condition
dat.m = exprs(x) #name of log2 gene expression matrix ready for analysis
ano = pData(x) #data frame with Group information for differential abudnance analysis 
design = notes(exp)$design # variable specifying the design of the study (paired or not)
annotation = paste(x@annotation, ".db", sep = "") # microarray platform 
targetGeneSets = notes(exp)$targetGeneSets #ID of KEGG pathway assumed to be relevant for the disease in question
#name of the KEGG pathway for that ID
KEGGREST::keggGet(paste("path:hsa",targetGeneSets,sep=""))[[1]]$NAME
}

\keyword{nonparametric}% at least one, from doc/KEYWORDS
\keyword{methods}% __ONLY ONE__ keyword per line
