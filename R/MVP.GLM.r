# Data pre-processing module
# 
# Copyright (C) 2016-2018 by Xiaolei Lab
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
# http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


#' To perform GWAS with GLM and MLM model and get the P value of SNPs
#'
#' Build date: Aug 30, 2016
#' Last update: May 25, 2017
#'
#' @author Lilin Yin and Xiaolei Liu
#' 
#' @param phe phenotype, n * 2 matrix
#' @param geno Genotype in numeric format, pure 0, 1, 2 matrix; m * n, m is marker size, n is population size
#' @param CV Covariance, design matrix(n * x) for the fixed effects
#' @param cpu number of cpus used for parallel computation
#' @param priority 'memory' or 'speed'
#' @param memo a marker on output file name
#' @param bar whether to show the progress bar
#'
#' @return m * 2 matrix, the first column is the SNP effect, the second column is the P values
#' @export
#'
#' @examples
#' phePath <- system.file("extdata", "mvp.phe", package = "rMVP")
#' phenotype <- read.table(phePath, header=TRUE)
#' print(dim(phenotype))
#' genoPath <- system.file("extdata", "mvp.geno.desc", package = "rMVP")
#' genotype <- attach.big.matrix(genoPath)
#' print(dim(genotype))
#' glm <- MVP.GLM(phe=phenotype, geno=genotype)
#' str(glm)
MVP.GLM <-
function(phe, geno, CV=NULL, cpu=2, priority="speed", memo="MVP.GLM", bar=TRUE){
    R.ver <- Sys.info()[['sysname']]
    wind <- R.ver == 'Windows'
    taxa <- colnames(phe)[2]
    r.open <- !inherits(try(Revo.version,silent=TRUE),"try-error")
    math.cpu <- try(getMKLthreads(), silent=TRUE)
    
    n <- ncol(geno)
    m <- nrow(geno)
    
    if(priority=="speed") geno <- as.matrix(geno)
    
    ys <- as.numeric(as.matrix(phe[,2]))
    
    if(is.null(CV)){
        X0 <- matrix(1, n)
    }else{
        X0 <- cbind(matrix(1, n), CV)
    }
    
    q0 <- ncol(X0)
    iXX <- matrix(NA,q0+1,q0+1)
    Xt <- matrix(NA,n, q0+1)

    y <- matrix(ys)
    X0X0 <- crossprod(X0)

    X0Y <- crossprod(X0,y)

    YY <- crossprod(y)

    X0X0i <- solve(X0X0)

    #parallel function for GLM model
    eff.glm <- function(i){
        if(bar) print.f(i)
        # if(i%%1000==0){
            # print(paste("****************", i, "****************",sep=""))
        # }
        #if(cpu>1 & r.open){
        #setMKLthreads(math.cpu)
        #}

        SNP <- geno[i, ]
        #Process the edge (marker effects)
            sy <- crossprod(SNP,y)
            ss <- crossprod(SNP)
            xs <- crossprod(X0,SNP)
            
            B21 <- crossprod(xs, X0X0i)
            t2 <- B21 %*% xs
            B22 <- ss - t2
            invB22 <- 1/B22
            NeginvB22B21 <- crossprod(-invB22,B21)
            B21B21 <- crossprod(B21)
            iXX11 <- X0X0i + as.numeric(invB22) * B21B21
            
            #Derive inverse of LHS with partationed matrix
            iXX[1:q0,1:q0] <- iXX11
            iXX[(q0+1),(q0+1)] <- invB22
            iXX[(q0+1),1:q0] <- NeginvB22B21
            iXX[1:q0,(q0+1)] <- NeginvB22B21
            df <- n-q0-1
            rhs <- c(X0Y,sy)
            effect <- crossprod(iXX,rhs)
            ve <- (YY-crossprod(effect,rhs))/df
            effect <- effect[q0+1]
            t.value <- effect/sqrt(iXX[q0+1, q0+1] * ve)
            p <- 2 * pt(abs(t.value), df, lower.tail=FALSE)
        return(list(effect=effect, p=p))
    }
    
    if(cpu == 1){
            math.cpu <- try(getMKLthreads(), silent=TRUE)
            mkl.cpu <- ifelse((2^(n %/% 1000)) < math.cpu, 2^(n %/% 1000), math.cpu)
                try(setMKLthreads(mkl.cpu), silent=TRUE)
        print.f <- function(i){print_bar(i=i, n=m, type="type1", fixed.points=TRUE)}
        results <- lapply(1:m, eff.glm)
    try(setMKLthreads(math.cpu), silent=TRUE)
    }else{
            if(wind){
                print.f <- function(i){print_bar(i=i, n=m, type="type1", fixed.points=TRUE)}
                cl <- makeCluster(getOption("cl.cores", cpu))
                clusterExport(cl, varlist=c("geno", "ys", "X0"), envir=environment())
                Exp.packages <- clusterEvalQ(cl, c(library(bigmemory)))
                results <- parLapply(cl, 1:m, eff.glm)
                stopCluster(cl)
            }else{
        tmpf.name <- tempfile()
        tmpf <- fifo(tmpf.name, open="w+b", blocking=TRUE)
        writeBin(0, tmpf)
        print.f <- function(i){print_bar(n=m, type="type3", tmp.file=tmpf, fixed.points=TRUE)}
                R.ver <- Sys.info()[['sysname']]
                if(R.ver == 'Linux') {
                    math.cpu <- try(getMKLthreads(), silent=TRUE)
                    try(setMKLthreads(1), silent=TRUE)
                }
                results <- mclapply(1:m, eff.glm, mc.cores=cpu)
        close(tmpf); unlink(tmpf.name); cat('\n');
                if(R.ver == 'Linux') {
                    try(setMKLthreads(math.cpu), silent=TRUE)
                }
            }
    }
    if(is.list(results)) results <- matrix(unlist(results), m, byrow=TRUE)
    #print("****************GLM ACCOMPLISHED****************")
    return(results)
}#end of MVP.GLM function
