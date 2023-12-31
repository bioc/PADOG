if(getRversion() >= "2.15.1")  utils::globalVariables(c("ini", "outi"))

compPADOG = function(datasets = NULL, existingMethods = c("GSA", "PADOG"), mymethods = NULL, 
                     gs.names = NULL, gslist = "KEGGRESTpathway", organism = "hsa", Nmin = 3, NI = 1000, parallel = TRUE, 
                     ncr = NULL, pkgs = NULL, expVars = NULL, dseed = NULL, plots = FALSE, verbose = FALSE) {
  
  if (is.null(datasets)) {
    files = data(package = "KEGGdzPathwaysGEO")$results[, "Item"]
  } else {
    files = datasets
    
  }
  
  data(list = files, package = "KEGGdzPathwaysGEO", envir=environment())
  
  getdataaslist = function(x) {
    x = get(x, envir=parent.frame())
    exp = experimentData(x)
    dataset = exp@name
    disease = notes(exp)$disease
    dat.m = exprs(x)
    ano = pData(x)
    design = notes(exp)$design
    annotation = paste(x@annotation, ".db", sep = "")
    targetGeneSets = notes(exp)$targetGeneSets
    list = list(dataset, disease, dat.m, ano, design, annotation, targetGeneSets)
    names(list) = c("dataset", "disease", "dat.m", "ano", "design", "annotation", 
                    "targetGeneSets")
    return(list)
  }
  
  
  
  
  padogF = function(set, mygslist, minsize) {
    list = getdataaslist(set)
    
    res = padog(esetm = list$dat.m, group = list$ano$Group, paired = list$design == 
                  "Paired", block = list$ano$Block, annotation = list$annotation, gslist = mygslist, 
                verbose = verbose, Nmin = minsize, NI = NI, plots = FALSE, parallel = parallel, 
                ncr = ncr, dseed = dseed)
    
    res$Dataset <- list$dataset
    
    res$Method <- "PADOG"
    res$Rank = sapply(1:nrow(res), function(n) {
      p = res$Ppadog
      s = res$padog0
      ifelse(is.na(p[n]), NA, (sum(p < (p[n]), na.rm=TRUE) + 
                                 sum(p == (p[n]) & s >= (s[n]), na.rm=TRUE)) / sum(! is.na(p), na.rm=TRUE) * 100 
      )
    }) 
    res$P = res$Ppadog
    res$FDR = p.adjust(res$P, "fdr")
    
    rownames(res) <- NULL
    rbind(res[res$ID %in% list$targetGeneSets, ])
  }
  
  
  gsaF = function(set, mygslist, minsize) {
    list = getdataaslist(set)
    
    group = list$ano$Group
    block = list$ano$Block
    esetm = list$dat.m
    if (!is.null(list$annotation)) 
    {
      # get rid of duplicates in the same way as is done for PADOG and assign probesets
      # to ENTREZ IDS get rid of duplicates by choosing the probe(set) with lowest
      # p-value; get ENTREZIDs for probes
      aT1 = filteranot(esetm = esetm, group = group, paired = (list$design == 
                                                                 "Paired"), block, list$annotation)
      aT1 <- aT1[aT1$ENTREZID %in% (unlist(mygslist)), ]
      # drop from esetm all duplicate genes and genes not in the genesets
      esetm = esetm[rownames(esetm) %in% aT1$ID, ]
      rownames(esetm) <- aT1$ENTREZID[match(rownames(esetm), aT1$ID)]
    }  
    
    KK = min(ncol(esetm), max(3, min(10, table(group))))
    
    # Run GSA maxmean
    if (list$design == "Not Paired") {
      yy = as.numeric(factor(group))
    } else {
      yy = as.numeric(factor(block))
      yy = yy * as.numeric(as.character(factor(group, labels=c(-1, 1)) ))
    }
    
    resgsa = GSA(x = esetm, y = yy, genesets = mygslist, genenames = rownames(esetm), 
                 method = "maxmean", resp.type = ifelse(list$design == "Not Paired", "Two class unpaired", 
                                                        "Two class paired"), censoring.status = NULL, random.seed = dseed, knn.neighbors = KK, 
                 s0 = NULL, s0.perc = NULL, minsize = minsize, maxsize = 1000, restand = TRUE, 
                 restand.basis = c("catalog", "data"), nperms = NI)
    
    res = data.frame(ID = names(gslist), P = 2 * apply(cbind(resgsa$pvalues.lo, 
                                                             resgsa$pvalues.hi), 1, min), Dataset = list$dataset, stringsAsFactors = FALSE)
    res$Method <- "GSA"
    res = res[order(res$P), ]
    res$Rank = sapply(res$P, function(p) ifelse(is.na(p), NA, mean(res$P <= p, na.rm=TRUE) * 100)) 
    res$FDR = p.adjust(res$P, "fdr")
    rownames(res) <- NULL
    res[res$ID %in% list$targetGeneSets, ]
  }
  
  defGSmethods = list(GSA = gsaF, PADOG = padogF)
  GSmethods = c(as.list(existingMethods), mymethods)
  names(GSmethods) = c(existingMethods, names(mymethods))
  defMeth = intersect(names(defGSmethods), names(GSmethods))
  GSmethods[defMeth] = defGSmethods[defMeth]
  GSMok = GSmethods
  GSMok = GSMok[!duplicated(names(GSMok))]
  refMethod = names(GSmethods)[1]
  
  
   # check GS
  if (length(gslist) == 1 && gslist == "KEGGRESTpathway") {
    stopifnot(nchar(organism) == 3)
    res <- keggLink("pathway", organism)
    a=data.frame(path=gsub(paste("path:",organism,sep=""),"",res),gns=gsub(paste(organism,":",sep=""),"",names(res)))
    gslist=tapply(a$gns,a$path,function(x){as.character(x)})
    gs.names=keggList("pathway", organism)[paste("path:",organism,names(gslist),sep="")]
    names(gs.names)<-names(gslist)
    stopifnot(length(gslist) >= 3)
    rm(res,a)
    }
  stopifnot(mode(gslist) == "list")
  stopifnot(length(gslist) >= 3)
  if (!is.null(gs.names)) {
    stopifnot(length(gslist) == length(gs.names))
  }
  
  
  aggFun = function(zdat) {
    zdat = lapply(zdat, `[`, c("ID", "Rank", "P", "FDR", "Dataset", "Method"))
    tmp = do.call(rbind, zdat)
    rownames(tmp) = NULL
    tmp
  }
  
  dfr = list()
  
  if ("PADOG" %in% names(GSMok)) {
    dfr[["PADOG"]] = aggFun(lapply(files, GSMok[["PADOG"]], mygslist = gslist, 
                                   minsize = Nmin))
    GSMok = GSMok[names(GSMok) != "PADOG"]
  }
  
  if (parallel && requireNamespace("doParallel", quietly = TRUE) && requireNamespace("parallel", 
                                                                                         quietly = TRUE)) {
    ncores = parallel::detectCores()
    if (!is.null(ncr)) 
      ncores = min(c(ncores, ncr))
    if (verbose) {
      clust = parallel::makeCluster(ncores, outfile="")
    } else {
      clust = parallel::makeCluster(ncores)
    }
    doParallel::registerDoParallel(clust)
    tryCatch({
      parRes <- foreach(outi = seq_along(GSMok), .combine = "c", .packages = pkgs, .export = expVars) %:% 
        foreach(ini = seq_along(files),  .combine = "c", .packages = pkgs, .export = expVars) %dopar% {
          inres = lapply(files[ini], GSMok[[outi]], mygslist = gslist, minsize = Nmin)
          if (verbose) {
            cat("Finish:", names(GSMok)[outi], " ------> ", files[ini], "\n")
          }
          inres
        }
      parRes = aggFun(parRes)
      parRes = split(parRes, parRes$Method)
      dfr[names(GSMok)] = parRes[names(GSMok)]
      rm(parRes)
    }, finally = parallel::stopCluster(clust))
  } else {
    if (parallel) message("Execute in serial! Packages 'doParallel' and 'parallel' 
                              needed for parallelization!")
    dfr[names(GSMok)] = lapply(GSMok, function(m) aggFun(lapply(files, m, mygslist = gslist, 
                                                                minsize = Nmin)))
  }
  
  
  shared = Reduce(merge, lapply(dfr, function(z) {
    z = z[complete.cases(z), ]
    z = z[, c("Dataset", "ID")]
    z = z[!duplicated(z), ]
    z
  }))
  
  dfs = list()
  dfs[names(GSmethods)] = lapply(names(GSmethods), function(m) {
    retn = dfr[[m]]
    stopifnot(!any(duplicated(retn[, c("Dataset", "ID")])))
    retn = merge(shared, retn, all.x = TRUE)
    retn[order(retn$Dataset, retn$ID), ]
  })
  rm(dfr)
  
  
  psList <- lapply(dfs, function(x) {
    x$P
  })
  fdrList <- lapply(dfs, function(x) {
    x$FDR
  })
  rankList <- lapply(dfs, function(x) {
    x$Rank
  })
  targetgsList <- lapply(dfs, function(x) {
    x$ID
  })
  dsList <- lapply(dfs, function(x) {
    x$Dataset
  })
  
  
  
  wi = function(x) {
    if (!all(x == rankList[[refMethod]])) {
      wilcox.test(x, rankList[[refMethod]], paired = TRUE, alternative = "less")$p.value
    } else {
      1
    }
  }
  
  wioright = function(x) {
    if (!all(x == rankList[[refMethod]])) {
      dset = data.frame(Method = gl(2, length(rankList[[refMethod]])), 
                        Y = c(rankList[[refMethod]], x), Dataset = factor(rep(dsList[[refMethod]], 2)), 
                        Path = factor(rep(targetgsList[[refMethod]], 2)))
      md = lme(Y ~ Method, random = ~1 | Path, data = dset)
      re = summary(md)$tTable[2, c(1, 5)]
      if (re[1] < 0) {
        c(re[1], re[2]/2)
      } else {
        c(re[1], 1 - re[2]/2)
      }
    } else {
      c(0, 1)
    }
  }
  
  
  if (length(unique(targetgsList[[refMethod]])) == 1) {
    repo = data.frame(matrix(NA, nrow=length(rankList), ncol=2))
  } else {
    repo = data.frame(t(sapply(rankList, wioright)))
  }
  names(repo) <- c("coef. LME", "p LME")
  repo$"p Wilcox." <- sapply(rankList, wi)
  
  l05 <- function(x) round(mean(x < 0.05) * 100, 2)
  geomean <- function(x) {
    x = ifelse(x == 0, 1e-16, x)
    exp(mean(log(x)))
  }
  
  repo$"% p.value<0.05" <- lapply(psList, l05)
  repo$"% q.value<0.05" <- lapply(fdrList, l05)
  repo$"p geomean" <- lapply(psList, geomean)
  repo$"p med" <- lapply(psList, median)
  
  repo$"rank mean" <- lapply(rankList, mean)
  repo$"rank med" <- lapply(rankList, median)
  repo$Method <- names(psList)
  
  nmets = length(psList)
  
  somecols = c("lightgrey", "lightblue", "orange", "red", "purple", "lightgreen")
  set.seed(1)
  if (nmets > 6) {
    somecols = c(somecols, sample(setdiff(colors(), somecols))[1:(nmets - 6)])
  }
  
  if (plots) {
    
    usrPar <- par(mfrow = c(1, 3))
    on.exit(par(usrPar))
    
    boxplot(psList, ylab = paste("p-value"), las = 3, col = somecols[1:nmets])
    boxplot(rankList, ylab = "Rank(%)", las = 3, col = somecols[1:nmets])
    
    mff2 = function(x) {
      x - rankList[[refMethod]]
    }
    newranks = lapply(rankList, mff2)
    newranks[refMethod] <- NULL
    
    if (length(newranks) == 1) {
      xlb = names(newranks)
    } else {
      xlb = NULL
    }
    boxplot(newranks, ylab = paste("Rank(%)-Rank ", refMethod, " (%)"), las = 3, 
            col = somecols[2:nmets], names = names(newranks), xlab = xlb)
    abline(h = 0)
    
  }
  
  out = repo[, c("Method", "p geomean", "p med", "% p.value<0.05", "% q.value<0.05", 
                 "rank mean", "rank med", "p Wilcox.", "p LME", "coef. LME")]
  list(summary = out, ranks = rankList, pvalues = psList, qvalues = fdrList)
  
}
