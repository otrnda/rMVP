#' To perform GWAS with GLM and MLM model and get the P value of SNPs
#'
#' Build date: Aug 30, 2016
#' Last update: Aug 30, 2016
#' 
#' @author Lilin Yin and Xiaolei Liu
#' 
#' @param phe phenotype, n * 2 matrix
#' @param geno genotype, m * n, m is marker size, n is population size
#' @param K Kinship, Covariance matrix(n * n) for random effects; must be positive semi-definite
#' @param CV covariates
#' @param REML a list that contains ve and vg
#' @param priority speed or memory
#' @param cpu number of cpus used for parallel computation
#' @param bar 
#' @param vc.method the methods for estimating variance component("emma" or "gemma")
#' @param maxLine when the priority is 'memory', users can change this parameter to limit the memory
#' @param file.output whether to output files or not
#' @param memo a marker on output file name
#'
#' @return
#' results: a m * 2 matrix, the first column is the SNP effect, the second column is the P values
#' @export
#'
#' @examples
MVP.MLM <-
function(phe, geno, K=NULL, CV=NULL, REML=NULL, priority="speed", cpu=2, bar=TRUE,vc.method="EMMA",maxLine=1000, file.output=TRUE, memo="MVP"){
R.ver <- Sys.info()[['sysname']]
wind <- R.ver == 'Windows'
#taxa <- colnames(phe)[2]
#r.open <- !inherits(try(Revo.version,silent=TRUE),"try-error")
math.cpu <- try(getMKLthreads(), silent=TRUE)

n <- ncol(geno)
m <- nrow(geno)
if(priority=="speed") geno <- as.matrix(geno)

ys <- as.numeric(as.matrix(phe[,2]))
if (is.null(K)) {
    print("Calculating Kinship...")
    K <- MVP.K.VanRaden(M=geno, priority=priority, maxLine=maxLine);gc()
    if (file.output) {
        filebck <- paste0("MVP.", colnames(phe)[2], memo, ".kin.bin")
        filedes <- paste0("MVP.", colnames(phe)[2], memo, ".kin.desc")
        if (file.exists(filebck)) file.remove(filebck)
        if (file.exists(filedes)) file.remove(filedes)
        Kin.backed <- big.matrix(
            nrow = nrow(K),
            ncol = ncol(K),
            type = "double",
            backingfile = filebck,
            descriptorfile = filedes
        )
        Kin.backed[, ] <- K[, ]
        flush(Kin.backed)
        rm(list = c("Kin.backed"))
        gc()
    }
} else {
    # convert K to base:matrix
    K <- K[]
}

if(is.null(CV)){
    X0 <- matrix(1, n)
}else{
    X0 <- cbind(matrix(1, n), CV)
}

#number of fixed effects
nf <- ncol(X0) + 1
    if(is.null(REML)){
    print("Variance components...")   
        if(vc.method == "EMMA") REML <- MVP.EMMA.Vg.Ve(y=ys, X=X0, K=K)
        if(vc.method == "GEMMA") REML <- MVP.GEMMA.Vg.Ve(y=ys, X=X0, K=K)
    }

    q0 <- ncol(X0)
    iXX <- matrix(NA,q0+1,q0+1)
    Xt <- matrix(NA,n, q0+1)
 
    ves <- REML$ve
    vgs <- REML$vg
    lambda <- ves/vgs
    print("Eigen-Decomposition...")
    eig <- eigen(K, symmetric=TRUE); rm(K); gc()
    print("Eigen-Decomposition is Done!")
    
    U <- eig$vectors * matrix(sqrt(1/(eig$values + lambda)), n, length(eig$values), byrow=TRUE); rm(eig); gc()
    
    y <- matrix(ys)
    yt <- crossprod(U, y)
    X0t <- crossprod(U, X0)
    X0X0 <- crossprod(X0t)
    X0Y <- crossprod(X0t,yt)
    iX0X0 <- solve(X0X0)
    
    Xt[1:n,1:q0] <- X0t

    #parallel function for MLM model
    eff.mlm.parallel <- function(i){
        if(bar) print.f(i)
        # if(i%%1000==0){
            # print(paste("****************", i, "****************",sep=""))
        # }
        #if(cpu>1 & r.open) setMKLthreads(math.cpu)

        SNP <- geno[i, ]
        xst <- crossprod(U, SNP)
        Xt[1:n,q0+1] <- xst
        X0Xst <- crossprod(X0t,xst)
        XstX0 <- t(X0Xst)
        xstxst <- crossprod(xst)
        xsY <- crossprod(xst,yt)
        XY <- c(X0Y,xsY)
        #B22 <- xstxst - XstX0%*%iX0X0%*%X0Xst
        B22 <- xstxst - crossprod(X0Xst, iX0X0) %*% X0Xst
        invB22 <- 1/B22
        B21 <- tcrossprod(XstX0, iX0X0)
        NeginvB22B21 <- crossprod(-invB22,B21)
        B11 <- iX0X0 + as.numeric(invB22)*crossprod(B21,B21)
            
        iXX[1:q0,1:q0]=B11
        iXX[(q0+1),(q0+1)]=1/B22
        iXX[(q0+1),1:q0]=NeginvB22B21
        iXX[1:q0,(q0+1)]=NeginvB22B21
        beta <- crossprod(iXX,XY)
        stats <- beta[(q0+1)]/sqrt((iXX[(q0+1), (q0+1)]) * vgs)
        p <- 2 * pt(abs(stats), n-(q0+1), lower.tail=FALSE)
        effect<- beta[(q0+1)]
        return(list(effect = effect, p = p))
    }
    
    #Paralleled MLM
    if(cpu == 1){
        math.cpu <- try(getMKLthreads(), silent=TRUE)
            mkl.cpu <- ifelse((2^(n %/% 1000)) < math.cpu, 2^(n %/% 1000), math.cpu)
                try(setMKLthreads(mkl.cpu), silent=TRUE)
        print.f <- function(i){MVP.Bar(i=i, n=m, type="type1", fixed.points=TRUE)}
        results <- lapply(1:m, eff.mlm.parallel)
    try(setMKLthreads(math.cpu), silent=TRUE)
    }else{
        if(wind){
            print.f <- function(i){MVP.Bar(i=i, n=m, type="type1", fixed.points=TRUE)}
            cl <- makeCluster(getOption("cl.cores", cpu))
            clusterExport(cl, varlist=c("geno", "yt", "X0", "U", "vgs", "ves", "math.cpu"), envir=environment())
            Exp.packages <- clusterEvalQ(cl, c(library(bigmemory),library(rfunctions)))
            results <- parLapply(cl, 1:m, eff.mlm.parallel)
            stopCluster(cl)
        }else{
        tmpf.name <- tempfile()
        tmpf <- fifo(tmpf.name, open="w+b", blocking=TRUE)
        writeBin(0, tmpf)
        print.f <- function(i){MVP.Bar(n=m, type="type3", tmp.file=tmpf, fixed.points=TRUE)}
                R.ver <- Sys.info()[['sysname']]
                if(R.ver == 'Linux') {
                    math.cpu <- try(getMKLthreads(), silent=TRUE)
                    try(setMKLthreads(1), silent=TRUE)
                }
                results <- mclapply(1:m, eff.mlm.parallel, mc.cores=cpu)
                if(R.ver == 'Linux') {
                    try(setMKLthreads(math.cpu), silent=TRUE)
                #try(setMKLthreads(1), silent=TRUE)
                }
        close(tmpf); unlink(tmpf.name); cat('\n');
        }
    }
    if(is.list(results)) results <- matrix(unlist(results), m, byrow=TRUE)
    #print("****************MLM ACCOMPLISHED****************")
    return(results)
}#end of MVP.MLM function
