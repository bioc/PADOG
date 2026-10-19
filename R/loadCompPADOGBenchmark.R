
loadCompPADOGBenchmark <- function(dataset = NULL, collection = NULL,
                                   envir = parent.frame(),assign=TRUE) {
  collect <- list(
    KEGGdzPathwaysGEO = c(
      "GSE1297", "GSE14762", "GSE15471", "GSE16515", "GSE18842",
      "GSE19188", "GSE19728", "GSE20153", "GSE20291", "GSE21354",
      "GSE3467", "GSE3585", "GSE3678", "GSE4107", "GSE5281_EC",
      "GSE5281_HIP", "GSE5281_VCX", "GSE6956AA", "GSE6956C",
      "GSE781", "GSE8671", "GSE8762", "GSE9348", "GSE9476"
    ),
    KEGGandMetacoreDzPathwaysGEO = c(
      "GSE1145", "GSE11906", "GSE14924_CD4", "GSE14924_CD8",
      "GSE16759", "GSE19420", "GSE20164", "GSE22780", "GSE23878",
      "GSE24739_G0", "GSE24739_G1", "GSE30153", "GSE32676",
      "GSE38666_epithelia", "GSE38666_stroma", "GSE4183",
      "GSE42057", "GSE7305"
    )
  )
  
  ## At least one argument must be specified
  if (is.null(dataset) && is.null(collection)) {
    stop("Either 'dataset' or 'collection' must be specified.")
  }
  
  ## Check collection name
  if (!is.null(collection)) {
    valid_collections <- c(names(collect), "all")
    
    if (length(collection) != 1L ||
        !collection %in% valid_collections) {
      stop(
        "'collection' must be one of: ",
        paste(valid_collections, collapse = ", ")
      )
    }
  }
  
  ## All available datasets
  all_datasets <- unlist(collect, use.names = FALSE)
  
  ## Determine which datasets belong to the requested collection
  if (!is.null(collection)) {
    
    if (collection == "all") {
      collection_datasets <- all_datasets
    } else {
      collection_datasets <- collect[[collection]]
    }
    
    ## If no individual datasets were specified,
    ## load the entire requested collection
    if (is.null(dataset)) {
      dataset <- collection_datasets
    } else {
      
      ## If both dataset and collection are specified,
      ## verify that the datasets belong to that collection
      invalid <- setdiff(dataset, collection_datasets)
      
      if (length(invalid)) {
        stop(
          "Dataset(s) not found in collection '", collection, "': ",
          paste(invalid, collapse = ", ")
        )
      }
    }
  } else {
    
    ## Dataset specified without a collection:
    ## verify against all available datasets
    invalid <- setdiff(dataset, all_datasets)
    
    if (length(invalid)) {
      stop(
        "Unknown dataset(s): ",
        paste(invalid, collapse = ", ")
      )
    }
  }
  if(assign){

  for (f in dataset) {
    ## Identify the package containing this dataset
    pkg <- names(collect)[vapply(
      collect,
      function(x) f %in% x,
      logical(1)
    )]
    
    ## Check that the data package is installed
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop(
        "Package '", pkg, "' is required. Install it with ",
        "BiocManager::install('", pkg, "')."
      )
    }
    
    ## Load dataset from the installed package
    utils::data(
      list = f,
      package = pkg,
      envir = envir
    )
    
    
    
   }
  }
  invisible(dataset)
}


