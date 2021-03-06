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


#' Calculate Kinship matrix by VanRaden method
#'
#' Build date: Dec 12, 2016
#' Last update: Dec 12, 2016
#' 
#' @param M Genotype, m * n, m is marker size, n is population size
#' @param weight vector, the weights for makers
#' @param priority speed or memory
#' @param memo add a character to the name of temporary files
#' @param SUM the scaled value to kinship matrix
#' @param maxLine when the priority is 'memory', users can change this parameter to limit the memory
#'
#' @return K, n * n matrix
#' @export
#'
#' @examples
#' genoPath <- system.file("extdata", "mvp.geno.desc", package = "rMVP")
#' genotype <- attach.big.matrix(genoPath)
#' print(dim(genotype))
#' K <- MVP.K.VanRaden(genotype)
MVP.K.VanRaden <-
function(M, weight=NULL, priority=c("speed", "memory"), memo=NULL, SUM=NULL, maxLine=1000){
    R.ver <- Sys.info()[['sysname']]
    wind <- R.ver == 'Windows'
    linux <- R.ver == 'Linux'
    mac <- (!linux) & (!wind)
    r.open <- !inherits(try(Revo.version,silent=TRUE),"try-error")

    if(r.open && mac){
        Sys.setenv("VECLIB_MAXIMUM_THREADS" = "1")
    }
    
    if(!is.null(weight)){
        if(sum(is.na(weight)) != 0) stop("'NA' is not allowed in weight")
    }
    if(is.null(dim(M))) M <- t(as.matrix(M))
    switch(
    match.arg(priority),
    "speed" = {
        if (!is.matrix(M)) M <- as.matrix(M)
        n <- ncol(M)
        m <- nrow(M)
        Pi <- 0.5 * rowMeans(M)
        M <- M - 2 * Pi
        if (is.null(SUM)) {
            SUM <- sum(Pi * (1 - Pi))
        }
        rm("Pi")
        gc()
        #check.r <- "checkpoint" %in% rownames(installed.packages())
        if (!is.null(weight)) M <- M * sqrt(as.vector(weight))
        K <- 0.5 * crossprod(M)/SUM
    },
    "memory" = {
        if (!is.big.matrix(M)) stop("Format of Genotype Data must be big.matrix")
        n <- ncol(M)
        m <- nrow(M)
        bac <- paste0("Z", memo, ".temp.bin")
        des <- paste0("Z", memo, ".temp.desc")
        if (file.exists(bac)) file.remove(bac)
        if (file.exists(des)) file.remove(des)
        #options(bigmemory.typecast.warning=FALSE)
        Z <- big.matrix(
            nrow = m,
            ncol = n,
            type = "double",
            backingfile = bac, 
            descriptorfile = des,
            init = 0.1
        )
        Pi <- NULL
        estimate.memory <- function(dat, integer=FALSE, raw=FALSE){
            cells.per.gb <- 2^27  # size of double() resulting in ~1GB of memory use by R 2.15
            dimz <- dat
            if(length(dimz) == 1) { dimz[2] <- 1 }
            if(length(dimz)>1 & length(dimz)<11 & is.numeric(dimz)) {
                total.size <- as.double(1)
                for(cc in 1:length(dimz)) { total.size <- as.double(total.size * as.double(dimz[cc])) }
                memory.estimate <- as.double(as.double(total.size)/cells.per.gb)
                memory.estimate <- memory.estimate
                if(integer) { memory.estimate <- memory.estimate/2 } else { if(raw) { memory.estimate <- memory.estimate/8 } }
                return(memory.estimate)
            } else {
                # guessing this is a vector
                if(!is.list(dimz) & is.vector(dimz)) {
                    LL <- length(dimz)
                    return(estimate.memory(LL, integer=integer, raw=raw))
                } else {
                    warning("tried to estimate memory for object which is neither a vector, pair of dimension sizes or a dataframe/matrix")
                }
            }
        }
        if((Sys.info()[['sysname']]) == 'Windows'){
            max.gb <- memory.limit()/1000
        }else{
            max.gb <- Inf
        }
        maxLines.gb <- estimate.memory(c(maxLine, n))
        if(maxLines.gb > max.gb) stop("Memory limited! Please reset the 'maxLine'")
        loop.index <- seq(0, m, maxLine)[-1]
        if(max(loop.index) < m) loop.index <- c(loop.index, m)
        loop.len <- length(loop.index)
        print("Z assignment...")
        for(cc in 1:loop.len){
            if(loop.len == 1){
                c1 <- 1
            }else{
                c1 <- ifelse(cc == loop.len, (loop.index[cc-1]) + 1, loop.index[cc]-maxLine + 1)
            }
            c2 <- loop.index[cc]
            means <-rowMeans(M[c1:c2, 1:n])
            if(!is.null(weight)){
                Z[c1:c2, 1:n] <- (M[c1:c2, 1:n]-means) * sqrt(weight[c1:c2])
            }else{
                Z[c1:c2, 1:n] <- M[c1:c2, 1:n]-means
            }
            Pi <- c(Pi, 0.5 * means);gc()
        }
        print("Assignment done!")
        if(is.null(SUM)){
            SUM <- sum(Pi * (1-Pi))
        }
        fl.suc <- flush(Z)
        if(!fl.suc){ stop("flush failed\n") } 
        RR <- describe(Z); rm(list=c("Z", "Pi", "means")); gc()
        Z <- attach.big.matrix(RR)
        K <- 0.5 * crossprod(Z[])/SUM
        rm(Z)
        gc()
        unlink(c(paste0("Z", memo, ".temp.bin"), paste0("Z", memo, ".temp.desc")), recursive = TRUE)
    }
    )
    #print("K Preparation is Done!")
    
    return(K)
}#end of MVP.k.VanRaden function
