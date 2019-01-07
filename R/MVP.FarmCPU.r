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


#' Perform GWAS using FarmCPU method
#'
#' Date build: Febuary 24, 2013
#' Last update: May 25, 2017
#' Requirement: Y, GD, and CV should have same taxa order. GD and GM should have the same order on SNPs
#' 
#' @author Xiaolei Liu and Zhiwu Zhang
#' 
#' @param phe phenotype, n by t matrix, n is sample size, t is number of phenotypes
#' @param geno genotype, m by n matrix, m is marker size, n is sample size. This is Pure Genotype Data Matrix(GD). THERE IS NO COLUMN FOR TAXA.
#' @param map SNP map information, m by 3 matrix, m is marker size, the three columns are SNP_ID, Chr, and Pos
#' @param CV covariates, n by c matrix, n is sample size, c is number of covariates
#' @param priority modes, two options: 'speed' or 'memory'
#' @param P start p values for all SNPs
#' @param method.sub method used in substitution process, five options: 'penalty', 'reward', 'mean', 'median', or 'onsite'
#' @param method.sub.final method used in substitution process, five options: 'penalty', 'reward', 'mean', 'median', or 'onsite'
#' @param method.bin method for selecting the most appropriate bins, two options: 'EMMA' or 'FaSTLMM'
#' @param bin.size bin sizes for all iterations, a vector, the bin size is always from large to small
#' @param bin.selection number of selected bins in each iteration, a vector
#' @param memo a marker on output file name
#' @param Prior prior information, four columns, which are SNP_ID, Chr, Pos, P-value
#' @param ncpus number of threads used for parallele computation
#' @param bar if TRUE, the progress bar will be drawn on the terminal
#' @param maxLoop maximum number of iterations
#' @param threshold.output only the GWAS results with p-values lower than threshold.output will be output
#' @param converge a number, 0 to 1, if selected pseudo QTNs in the last and the second last iterations have a certain probality (the probability is converge) of overlap, the loop will stop
#' @param iteration.output whether to output results of all iterations
#' @param p.threshold if all p values generated in the first iteration are bigger than p.threshold, FarmCPU stops
#' @param QTN.threshold in second and later iterations, only SNPs with lower p-values than QTN.threshold have chances to be selected as pseudo QTNs
#' @param bound maximum number of SNPs selected as pseudo QTNs in each iteration
#'
#' @return a m by 4 results matrix, m is marker size, the four columns are SNP_ID, Chr, Pos, and p-value
#' @export
#'
#' @examples
#' phePath <- system.file("extdata", "mvp.phe", package = "rMVP")
#' phenotype <- read.table(phePath, header=TRUE)
#' print(dim(phenotype))
#' genoPath <- system.file("extdata", "mvp.geno.desc", package = "rMVP")
#' genotype <- attach.big.matrix(genoPath)
#' print(dim(genotype))
#' mapPath <- system.file("extdata", "mvp.map", package = "rMVP")
#' map <- read.table("mvp.map" , head = TRUE)
#' farmcpu <- MVP.FarmCPU(phe=phenotype, geno=genotype, map=map, method.bin="static", ncpus=detectCores(logical = FALSE), maxLoop=3, P=NULL, method.sub="reward", method.sub.final="reward", bin.size=c(5e5,5e6,5e7), bin.selection=seq(10,100,10), Prior=NULL, p.threshold=NA, QTN.threshold=NULL, bound=NULL)
#' str(farmcpu)
`MVP.FarmCPU` <- function(phe, geno, map, CV=NULL, priority="speed", P=NULL, method.sub="reward", method.sub.final="reward", method.bin="EMMA", bin.size=c(5e5,5e6,5e7), bin.selection=seq(10,100,10), memo="MVP.FarmCPU", Prior=NULL, ncpus=2, bar=TRUE, maxLoop=10, threshold.output=.01, converge=1, iteration.output=FALSE, p.threshold=NA, QTN.threshold=NULL, bound=NULL){
    #print("--------------------- Welcome to FarmCPU ----------------------------")
    
    echo=TRUE
    nm=nrow(map)
    if(!is.null(CV)){
        CV=as.matrix(CV)
        npc=ncol(CV)
    }else{
        npc=0
    }
    
    if(is.null(QTN.threshold)){QTN.threshold = 0.01}
    if(!is.na(p.threshold)) QTN.threshold = max(p.threshold, QTN.threshold)
    
    name.of.trait=colnames(phe)[2]
    if(!is.null(memo)) name.of.trait=paste(memo,".",name.of.trait,sep="")
    theLoop=0
    theConverge=0
    seqQTN.save=c(0)
    seqQTN.pre=c(-1)
    isDone=FALSE
    name.of.trait2=name.of.trait
    
    while(!isDone) {
        theLoop=theLoop+1
        print(paste("Current loop: ",theLoop," out of maximum of ", maxLoop, sep=""))
            
        spacer="0"
        if(theLoop>9){
            spacer=""
        }
        if(iteration.output){
            name.of.trait2=paste("Iteration_",spacer,theLoop,".",name.of.trait,sep="")
        }
            
        #Step 2a: Set prior
        myPrior=FarmCPU.Prior(GM=map,P=P,Prior=Prior)

        #Step 2b: Set bins
        if(theLoop<=2){
            myBin=FarmCPU.BIN(Y=phe[,c(1,2)],GD=geno,GM=map,CV=CV,P=myPrior,method=method.bin,b=bin.size,s=bin.selection,theLoop=theLoop,bound=bound,ncpus=ncpus)
        }else{
            myBin=FarmCPU.BIN(Y=phe[,c(1,2)],GD=geno,GM=map,CV=theCV,P=myPrior,method=method.bin,b=bin.size,s=bin.selection,theLoop=theLoop,ncpus=ncpus)
        }
        
        #Step 2c: Remove bin dependency
        #Remove QTNs in LD
        seqQTN=myBin$seqQTN

        if(theLoop==2){
            if(!is.na(p.threshold)){
                if(min(myPrior,na.rm=TRUE)>p.threshold){
                    seqQTN=NULL
                    print("Top snps have little effect, set seqQTN to NULL!")
                    }
                }else{
                    if(min(myPrior,na.rm=TRUE)>0.01/nm){
                        seqQTN=NULL
                        print("Top snps have little effect, set seqQTN to NULL!")
                    }
                }
            }
            
            #when FarmCPU can not work, make a new QQ plot and manhatthan plot
            if(theLoop==2&&is.null(seqQTN)){
                #Report
                P=myGLM$P[,ncol(myGLM$P)]
                P[P==0] <- min(P[P!=0],na.rm=TRUE)*0.01
                results = cbind(myGLM$B, P)
                colnames(results) = c("effect","p")
                break
            }#force to exit for GLM model while seqQTN=NULL and h2=0

            if(!is.null(seqQTN.save)&&theLoop>1){
                if(seqQTN.save!=0 & seqQTN.save!=-1 & !is.null(seqQTN) ) seqQTN=union(seqQTN,seqQTN.save) #Force previous QTNs in the model
            }
            if(theLoop!=1){
                seqQTN.p=myPrior[seqQTN]
                if(theLoop==2){
                    index.p=seqQTN.p<QTN.threshold
                    #if(!is.na(p.threshold)){
                    #index.p=seqQTN.p<p.threshold
                    #}
                    seqQTN.p=seqQTN.p[index.p]
                    seqQTN=seqQTN[index.p]
                    seqQTN.p=seqQTN.p[!is.na(seqQTN)]
                    seqQTN=seqQTN[!is.na(seqQTN)]
                }else{
                    index.p=seqQTN.p<QTN.threshold
                    #if(!is.na(p.threshold)){
                    #index.p=seqQTN.p<p.threshold
                    #}
                    index.p[seqQTN%in%seqQTN.save]=TRUE
                    seqQTN.p=seqQTN.p[index.p]
                    seqQTN=seqQTN[index.p]
                    seqQTN.p=seqQTN.p[!is.na(seqQTN)]
                    seqQTN=seqQTN[!is.na(seqQTN)]
                }
            }

            myRemove=FarmCPU.Remove(GD=geno,GM=map,seqQTN=seqQTN,seqQTN.p=seqQTN.p,threshold=.7)
            
            #Recoding QTNs history
            seqQTN=myRemove$seqQTN
            theConverge=length(intersect(seqQTN,seqQTN.save))/length(union(seqQTN,seqQTN.save))
            circle=(length(union(seqQTN,seqQTN.pre))==length(intersect(seqQTN,seqQTN.pre)))
            
            #handler of initial status
            if(is.null(seqQTN.pre)){circle=FALSE
            }else{
                if(seqQTN.pre[1]==0) circle=FALSE
                if(seqQTN.pre[1]==-1) circle=FALSE
            }

            print("seqQTN")
            print(seqQTN)
            print("scanning...")
            if(theLoop==maxLoop){
                print(paste("Total number of possible QTNs in the model is: ", length(seqQTN),sep=""))
            }
            
            isDone=((theLoop>=maxLoop) | (theConverge>=converge) | circle )
            
            seqQTN.pre=seqQTN.save
            seqQTN.save=seqQTN
            
            #Step 3: Screen with bins
            rm(myBin)
            gc()
            
            theCV=CV
            
            if(!is.null(myRemove$bin)){
                if(length(myRemove$seqQTN) == 1){
                    #myRemove$bin = as.matrix(myRemove$bin)
                    myRemove$bin = t(myRemove$bin)
                }
                theCV=cbind(CV,myRemove$bin)
            }
            myGLM=FarmCPU.LM(y=phe[,2],GDP=geno,w=theCV,ncpus=ncpus,npc=npc,bar=bar)
            
            #Step 4: Background unit substitution
            if(!isDone){
                myGLM=FarmCPU.SUB(GM=map,GLM=myGLM,QTN=map[myRemove$seqQTN,],method=method.sub)
            }else{
                myGLM=FarmCPU.SUB(GM=map,GLM=myGLM,QTN=map[myRemove$seqQTN,],method=method.sub.final)
            }
            P=myGLM$P[,ncol(myGLM$P)]
            P[P==0] <- min(P[P!=0],na.rm=TRUE)*0.01
            results = cbind(myGLM$B, P)
            colnames(results) = c("effect","p")
        } #end of while loop
        #print("****************FarmCPU ACCOMPLISHED****************")
        return(results)
}#The MVP.FarmCPU function ends here


#' FarmCPU.FaSTLMM.LL
#' Evaluation of the maximum likelihood using FaST-LMM method
#'  
#' Last update: January 11, 2017
#' Requirement: pheno, snp.pool, and X0 must have same taxa order.
#' Requirement: No missing data
#'  
#' @author Qishan Wang, Feng Tian and Zhiwu Zhang (Modified by Xiaolei Liu)
#' 
#' @param pheno a two-column phenotype matrix
#' @param snp.pool matrix for pseudo QTNs
#' @param X0 covariates matrix
#' @param ncpus number of threads used for parallel computation
#'
#' @return
#' Output: beta - beta effect
#' Output: delta - delta value
#' Output: LL - log-likelihood
#' Output: vg - genetic variance
#' Output: ve - residual variance
#' 
#' @export
`FarmCPU.FaSTLMM.LL` <- function(pheno, snp.pool, X0=NULL, ncpus=2){
    y=pheno
    p=0
    deltaExpStart = -5
    deltaExpEnd = 5
    snp.pool=snp.pool[,]
    if(!is.null(snp.pool)&&var(snp.pool)==0){
        deltaExpStart = 100
        deltaExpEnd = deltaExpStart
    }
    if(is.null(X0)) {
        X0 = matrix(1, nrow(snp.pool), 1)
    }
    X=X0
    #########SVD of X
    K.X.svd <- svd(snp.pool)
    d=K.X.svd$d
    d=d[d>1e-08]
    d=d^2
    U1=K.X.svd$u
    U1=U1[,1:length(d)]
    #handler of single snp
    if(is.null(dim(U1))) U1=matrix(U1,ncol=1)
    n=nrow(U1)
    U1TX=crossprod(U1,X)
    U1TY=crossprod(U1,y)
    yU1TY <- y-U1%*%U1TY
    XU1TX<- X-U1%*%U1TX
    IU = -tcrossprod(U1)
    diag(IU) = rep(1,n) + diag(IU)
    IUX=crossprod(IU,X)
    IUY=crossprod(IU,y)
    #Iteration on the range of delta (-5 to 5 in glog scale)
    delta.range <- seq(deltaExpStart,deltaExpEnd,by=0.1)
    m <- length(delta.range)
    #for (m in seq(deltaExpStart,deltaExpEnd,by=0.1)){
    beta.optimize.parallel <- function(ii){
        #p=p+1
        delta <- exp(delta.range[ii])
        #----------------------------calculate beta-------------------------------------
        #######get beta1
        beta1=0
        for(i in 1:length(d)){
            one=matrix(U1TX[i,], nrow=1)
            beta=crossprod(one,(one/(d[i]+delta)))  #This is not real beta, confusing
            beta1= beta1+beta
        }
        
        #######get beta2
        beta2=0
        for(i in 1:nrow(U1)){
            one=matrix(IUX[i,], nrow=1)
            beta = crossprod(one)
            beta2= beta2+beta
        }
        beta2<-beta2/delta
        
        #######get beta3
        beta3=0
        for(i in 1:length(d)){
            one1=matrix(U1TX[i,], nrow=1)
            one2=matrix(U1TY[i,], nrow=1)
            beta=crossprod(one1,(one2/(d[i]+delta)))
            beta3= beta3+beta
        }
        
        ###########get beta4
        beta4=0
        for(i in 1:nrow(U1)){
            one1=matrix(IUX[i,], nrow=1)
            one2=matrix(IUY[i,], nrow=1)
            beta=crossprod(one1,one2)
            beta4= beta4+beta
        }
        beta4<-beta4/delta
        
        #######get final beta
        zw1 <- ginv(beta1+beta2)
        #zw1 <- try(solve(beta1+beta2))
        #if(inherits(zw1, "try-error")){
        #zw1 <- ginv(beta1+beta2)
        #}
        
        zw2=(beta3+beta4)
        beta=crossprod(zw1,zw2)
        
        #----------------------------calculate LL---------------------------------------
        ####part 1
        part11<-n*log(2*3.14)
        part12<-0
        for(i in 1:length(d)){
            part12_pre=log(d[i]+delta)
            part12= part12+part12_pre
        }
        part13<- (nrow(U1)-length(d))*log(delta)
        part1<- -1/2*(part11+part12+part13)
        
        ######  part2
        part21<-nrow(U1)
        ######part221
        
        part221=0
        for(i in 1:length(d)){
            one1=U1TX[i,]
            one2=U1TY[i,]
            part221_pre=(one2-one1%*%beta)^2/(d[i]+delta)
            part221 = part221+part221_pre
        }
        
        part222=0
        for(i in 1:n){
            one1=XU1TX[i,]
            one2=yU1TY[i,]
            part222_pre=((one2-one1%*%beta)^2)/delta
            part222= part222+part222_pre
        }
        part22<-n*log((1/n)*(part221+part222))
        part2<- -1/2*(part21+part22)
        
        ################# likihood
        LL<-part1+part2
        part1<-0
        part2<-0
        
        return(list(beta=beta,delta=delta,LL=LL))
    }
    #} # end of Iteration on the range of delta (-5 to 5 in glog scale)
    R.ver <- Sys.info()[['sysname']]
    if(R.ver == 'Linux') {
        math.cpu <- try(getMKLthreads(), silent=TRUE)
        try(setMKLthreads(1), silent=TRUE)
    }
    
    llresults <- mclapply(1:m, beta.optimize.parallel, mc.cores=ncpus)
    
    if(R.ver == 'Linux') {
        try(setMKLthreads(math.cpu), silent=TRUE)
    }
    
    for(i in 1:m){
        if(i == 1){
            beta.save = llresults[[i]]$beta
            delta.save = llresults[[i]]$delta
            LL.save = llresults[[i]]$LL
        }else{
            if(llresults[[i]]$LL > LL.save){
                beta.save = llresults[[i]]$beta
                delta.save = llresults[[i]]$delta
                LL.save = llresults[[i]]$LL
            }
        }
    }
    #--------------------update with the optimum------------------------------------
    beta=beta.save
    delta=delta.save
    LL=LL.save
    
    #--------------------calculating Va and Vem-------------------------------------
    #sigma_a1
    sigma_a1=0
    for(i in 1:length(d)){
        one1=matrix(U1TX[i,], ncol=1)
        one2=matrix(U1TY[i,], nrow=1)
        #sigma_a1_pre=(one2-one1%*%beta)^2/(d[i]+delta)
        sigma_a1_pre=(one2-crossprod(one1,beta))^2/(d[i]+delta)
        sigma_a1= sigma_a1+sigma_a1_pre
    }
    
    ### sigma_a2
    sigma_a2=0
    
    for(i in 1:nrow(U1)){
        one1=matrix(IUX[i,], ncol=1)
        one2=matrix(IUY[i,], nrow=1)
        #sigma_a2_pre<-(one2-one1%*%beta)^2
        sigma_a2_pre<-(one2-crossprod(one1,beta))^2
        sigma_a2= sigma_a2+sigma_a2_pre
    }
    
    sigma_a2<-sigma_a2/delta
    sigma_a<- 1/n*(sigma_a1+sigma_a2)
    sigma_e<-delta*sigma_a
    
    return(list(beta=beta, delta=delta, LL=LL, vg=sigma_a, ve=sigma_e))
}


#' FarmCPU.BIN
#'
#' Last update: March 28, 2017
#' Requirement: Y, GDP, and CV must have same taxa order. GDP and GM must have the same order on SNP
#' Requirement: P and GM are in the same order
#' Requirement: No missing data
#' 
#' @author Xiaolei Liu and Zhiwu Zhang
#' 
#' @param Y a n by 2 matrix, the fist column is taxa id and the second is trait
#' @param GDP genotype, m by n matrix, m is marker size, n is sample size. This is Pure Genotype Data Matrix(GD). THERE IS NO COLUMN FOR TAXA
#' @param GM SNP map information, m by 3 matrix, m is marker size, the three columns are SNP_ID, Chr, and Pos
#' @param CV covariates, n by c matrix, n is sample size, c is number of covariates
#' @param P start p values for all SNPs
#' @param method two options, 'static' or 'optimum'
#' @param b bin sizes for all iterations, a vector, the bin size is always from large to small
#' @param s number of selected bins in each iteration, a vector
#' @param theLoop iteration number
#' @param bound maximum number of SNPs selected as pseudo QTNs in each iteration
#' @param ncpus number of threads used for parallele computation
#'
#' @return
#' Output: seqQTN - an s by 1 vecter for index of QTNs on GM file
#'
#' @keywords internal
FarmCPU.BIN <-
    function(Y=NULL, GDP=NULL, GM=NULL, CV=NULL, P=NULL, method="EMMA", b=c(5e5,5e6,5e7), s=seq(10,100,10), theLoop=NULL, bound=NULL, ncpus=2){
        #print("FarmCPU.BIN Started")
        
        if(is.null(P)) return(list(bin=NULL,binmap=NULL,seqQTN=NULL))
        
        #Set upper bound for bin selection to squareroot of sample size
        n=nrow(Y)
        #bound=round(sqrt(n)/log10(n))
        if(is.null(bound)){
            bound=round(sqrt(n)/sqrt(log10(n)))
        }
        
        s[s>bound]=bound
        s=unique(s[s<=bound]) #keep the within bound
        
        optimumable=(length(b)*length(s)>1)
        if(!optimumable & method=="optimum"){
            method="static"
        }
        
        if(optimumable){
            s[s>bound]=bound
            #print("optimizing possible QTNs...")
            GP=cbind(GM,P,NA,NA,NA)
            mySpecify=FarmCPU.Specify(GI=GM, GP=GP, bin.size=b, inclosure.size=s)
            seqQTN=which(mySpecify$index==TRUE)
        }
        
        #Method of static
        if(method=="static"&optimumable){
            #print("Via static")
            if(theLoop==2){
                b=b[3]
            }else if(theLoop==3){
                b=b[2]
            }else{
                b=b[1]
            }
            s=bound
            s[s>bound]=bound
            print("Optimizing Pseudo QTNs...")
            GP=cbind(GM,P,NA,NA,NA)
            mySpecify=FarmCPU.Specify(GI=GM,GP=GP,bin.size=b,inclosure.size=s)
            seqQTN.save=which(mySpecify$index==TRUE)
        }
        
        #Method of optimum: FaST-LMM
        #============================Optimize by FaST-LMM============================================
        if(method=="FaST-LMM"&optimumable){
            #print("c(bin.size, bin.selection, -2LL, VG, VE)")
            print("Optimizing Pseudo QTNs...")
            count=0
            for (bin in b){
                for (inc in s){
                    count=count+1
                    GP=cbind(GM,P,NA,NA,NA)
                    mySpecify=FarmCPU.Specify(GI=GM,GP=GP,bin.size=bin,inclosure.size=inc)
                    seqQTN=which(mySpecify$index==TRUE)
                    GK=t(GDP[seqQTN,])
                    myBurger=FarmCPU.Burger(Y=Y[,1:2], CV=CV, GK=GK, ncpus=ncpus, method=method)
                    myREML=myBurger$REMLs
                    myVG=myBurger$vg #it is unused
                    myVE=myBurger$ve #it is unused
                    print(c(bin,inc,myREML,myVG,myVE))
                    #Recoding the optimum GK
                    if(count==1){
                        seqQTN.save=seqQTN
                        LL.save=myREML
                        bin.save=bin
                        inc.save=inc
                        vg.save=myVG  # for genetic variance
                        ve.save=myVE  # for residual variance
                    }else{
                        if(myREML<LL.save){
                            seqQTN.save=seqQTN
                            LL.save=myREML
                            bin.save=bin
                            inc.save=inc
                            vg.save=myVG  # for genetic variance
                            ve.save=myVE  # for residual variance
                        }
                    } #end of if(count==1)
                }#loop on bin number
            }#loop on bin size
            #seqQTN=seqQTN.save
        }
        
        #Method of optimum: EMMA
        #============================Optimize by EMMA============================================
        if(method=="EMMA"&optimumable){
            #print("c(bin.size, bin.selection, -2LL, VG, VE)")
            print("Optimizing Pseudo QTNs...")
            m <- length(b)*length(s)
            inc.index = rep(c(1:length(s)), length(b))
            
            seqQTN.optimize.parallel <- function(ii){
                bin.index = floor((ii-0.1)/length(s)) + 1
                bin = b[bin.index]
                inc = s[inc.index[ii]]
                GP=cbind(GM,P,NA,NA,NA)
                mySpecify=FarmCPU.Specify(GI=GM,GP=GP,bin.size=bin,inclosure.size=inc)
                seqQTN=which(mySpecify$index==TRUE)
                GK=t(GDP[seqQTN,])
                myBurger=FarmCPU.Burger(Y=Y[,1:2], CV=CV, GK=GK, ncpus=ncpus, method=method)
                myREML=myBurger$REMLs
                myVG=myBurger$vg #it is unused
                myVE=myBurger$ve #it is unused
                print(c(bin,inc,myREML,myVG,myVE))
                return(list(seqQTN=seqQTN,myREML=myREML))
            }
            
            R.ver <- Sys.info()[['sysname']]
            if(R.ver == 'Linux') {
                math.cpu <- try(getMKLthreads(), silent=TRUE)
                try(setMKLthreads(1), silent=TRUE)
            }
            
            llresults <- mclapply(1:m, seqQTN.optimize.parallel, mc.cores=ncpus)
            
            if(R.ver == 'Linux') {
                try(setMKLthreads(math.cpu), silent=TRUE)
            }
            
            for(i in 1:m){
                if(i == 1){
                    seqQTN.save = llresults[[i]]$seqQTN
                    myREML.save = llresults[[i]]$myREML
                }else{
                    if(llresults[[i]]$myREML < myREML.save){
                        seqQTN.save = llresults[[i]]$seqQTN
                        myREML.save = llresults[[i]]$myREML
                    }
                }
            }
        }
        
        #Method of optimum: GEMMA
        #can not be used to provide REML
        #============================Optimize by EMMA============================================
        if(method=="GEMMA"&optimumable){
            #print("c(bin.size, bin.selection, -2LL, VG, VE)")
            print("Optimizing Pseudo QTNs...")
            m <- length(b)*length(s)
            
            seqQTN.optimize.parallel <- function(ii){
                bin = floor((ii-0.1)/length(s)) + 1
                inc = rep(c(1:length(s)), length(b))
                GP=cbind(GM,P,NA,NA,NA)
                mySpecify=FarmCPU.Specify(GI=GM,GP=GP,bin.size=bin[ii],inclosure.size=inc[ii])
                seqQTN=which(mySpecify$index==TRUE)
                GK=t(GDP[seqQTN,])
                myBurger=FarmCPU.Burger(Y=Y[,1:2], CV=CV, GK=GK, ncpus=ncpus, method=method)
                myREML=myBurger$REMLs
                myVG=myBurger$vg #it is unused
                myVE=myBurger$ve #it is unused
                print(c(bin,inc,myREML,myVG,myVE))
                return(list(seqQTN=seqQTN,myREML=myREML))
            }
            
            llresults <- mclapply(1:m, seqQTN.optimize.parallel, mc.cores=ncpus)
            
            for(i in 1:m){
                if(i == 1){
                    seqQTN.save = llresults[[i]]$seqQTN
                    myREML.save = llresults[[i]]$myREML
                }else{
                    if(llresults[[i]]$myREML < myREML.save){
                        seqQTN.save = llresults[[i]]$seqQTN
                        myREML.save = llresults[[i]]$myREML
                    }
                }
            }
        }
        
        return(list(seqQTN=seqQTN.save))
    }#The function FarmCPU.BIN ends here


#' To get indicator (TURE or FALSE) for GI based on GP
#' 
#' Last update: January 26, 2017
#' Strategy
#' 1.set bins for all snps in GP
#' 2.keep the snp with smallest P value in each bin, record SNP ID
#' 3.Search GI for SNP with SNP ID from above
#' 4.return the position for SNP selected
#' 
#' @author Zhiwu Zhang
#' 
#' @param GI Data frame with three columns (SNP name, chr and base position)
#' @param GP Data frame with seven columns (SNP name, chr and base position, P, MAF, N, effect)
#' @param bin.size a value of @param b in 'FarmCPU.bin' function
#' @param inclosure.size a value of @param s in 'FarmCPU.bin' function
#' @param MaxBP maximum base pairs for each chromosome
#'
#' @return theIndex: a vector indicating if the SNPs in GI belong to QTN or not
FarmCPU.Specify <-
    function(GI=NULL, GP=NULL, bin.size=10000000, inclosure.size=NULL, MaxBP=1e10){
        #print("Specification in process...")
        if(is.null(GP))return (list(index=NULL,BP=NULL))
        
        #set inclosure bin in GP
        #Create SNP ID: position+CHR*MaxBP
        ID.GP=as.numeric(as.vector(GP[,3]))+as.numeric(as.vector(GP[,2]))*MaxBP
        
        #Creat bin ID
        bin.GP=floor(ID.GP/bin.size )
        
        #Create a table with bin ID, SNP ID and p value (set 2nd and 3rd NA temporately)
        binP=as.matrix(cbind(bin.GP,NA,NA,ID.GP,as.numeric(as.vector(GP[,4])))  )
        n=nrow(binP)
        
        #Sort the table by p value and then bin ID (e.g. sort p within bin ID)
        binP=binP[order(as.numeric(as.vector(binP[,5]))),]  #sort on P alue
        binP=binP[order(as.numeric(as.vector(binP[,1]))),]  #sort on bin
        
        #set indicator (use 2nd 3rd columns)
        binP[2:n,2]=binP[1:(n-1),1]
        binP[1,2]=0 #set the first
        binP[,3]= binP[,1]-binP[,2]
        
        #Se representives of bins
        ID.GP=binP[binP[,3]>0,]
        
        #Choose the most influencial bins as estimated QTNs
        #Handler of single row
        if(is.null(dim(ID.GP))) ID.GP=matrix(ID.GP,1,length(ID.GP))
        ID.GP=ID.GP[order(as.numeric(as.vector(ID.GP[,5]))),]  #sort on P alue
        
        #Handler of single row (again after reshape)
        if(is.null(dim(ID.GP))) ID.GP=matrix(ID.GP,1,length(ID.GP))
        
        index=!is.na(ID.GP[,4])
        ID.GP=ID.GP[index,4] #must have chr and bp information, keep SNP ID only
        
        if(!is.null(inclosure.size)   ) {
            if(!is.na(inclosure.size)){
                avaiable=min(inclosure.size,length(ID.GP))
                if(avaiable==0){
                    ID.GP=-1
                }else{
                    ID.GP=ID.GP[1:avaiable] #keep the top ones selected
                }
            }
        }
        
        #create index in GI
        theIndex=NULL
        if(!is.null(GI)){
            ID.GI=as.numeric(as.vector(GI[,3]))+as.numeric(as.vector(GI[,2]))*MaxBP
            theIndex=ID.GI %in% ID.GP
        }
        
        myList=list(index=theIndex,CB=ID.GP)
        return (list(index=theIndex,CB=ID.GP))
    } #end of FarmCPU.Specify


#' To quickly sovel LM with one variable substitute multiple times
#'
#' Start  date: March 1, 2013
#' Last update: March 6, 2013
#' Strategy:
#' 1. Separate constant covariates (w) and dynamic coveriates (x)
#' 2. Build non-x related only once
#' 3. Use apply to iterate x
#' 4. Derive dominance indicate d from additive indicate (x) mathmaticaly
#' 5. When d is not estimable, continue to test x
#' 
#' @author Xiaolei Liu and Zhiwu Zhang
#' 
#' @param y one column matrix, dependent variable
#' @param w covariates, n by c matrix, n is sample size, c is number of covariates
#' @param GDP genotype, m by n matrix, m is marker size, n is sample size. This is Pure Genotype Data Matrix(GD). THERE IS NO COLUMN FOR TAXA.
#' @param ncpus number of threads used for parallele computation
#' @param npc number of covariates without pseudo QTNs
#'
#' @return
#' Output: P - p-value of each SNP
#' Output: betapred - effects of pseudo QTNs
#' Output: B - effect of each SNP
#' 
#' @keywords internal
FarmCPU.LM <-
    function(y, w=NULL, GDP, ncpus=2, npc=0, bar=TRUE){
        #print("FarmCPU.LM started")
        if(is.null(y)) return(NULL)
        if(is.null(GDP)) return(NULL)
        #Constant section (non individual marker specific)
        #---------------------------------------------------------
        #Configration
        nd=20 #number of markes for checking A and D dependency
        N=length(y) #Total number of taxa, including missing ones
        
        if(!is.null(w)){
            w=as.matrix(w,nrow = N)
            nf=ncol(w)
            w=cbind(rep(1,N),w)
            q0=ncol(w)
        }else{
            w=rep(1,N)
            nf=0
            q0=1
        }
        
        print("number of covariates in current loop is:")
        print(nf)
        
        n=N
        if(nd>n)nd=n #handler of samples less than nd
        k=1 #number of genetic effect: 1 and 2 for A and AD respectively
        
        q1=(q0+1) # vecter index for the posistion of genetic effect (a)
        q2=(q0+1):(q0+2) # vecter index for the posistion of genetic effect (a and d)
        df=n-q0-k #residual df (this should be varied based on validating d)
        
        iXX=matrix(0,q0+k,q0+k) #Reserve the maximum size of inverse of LHS
        
        # ww=crossprodcpp(w)
        ww = crossprod(w)
        
        wy = crossprod(w,y)
        # yy=crossprodcpp(y)
        yy = crossprod(y)
        wwi = solve(ww)
        
        #Statistics on the reduced model without marker
        rhs=wy
        beta <- crossprod(wwi,rhs)
        
        if(npc!=0){
            betapc = beta[2:(npc+1)]
            betapred = beta[-c(1:(npc+1))]
        }else{
            betapc = NULL
            betapred = beta[-1]
        }
        
        m = nrow(GDP)
        
        eff.farmcpu.parallel <- function(i){
            if(bar) print.f(i)
            # if(i%%1000==0){
            # print(paste("****************", i, "****************",sep=""))
            # }
            x=GDP[i,]
            
            #Process the edge (marker effects)
            xy=crossprod(x,y)
            xx=crossprod(x)
            xw=crossprod(w,x)
            
            B21 <- crossprod(xw, wwi)
            t2 <- B21 %*% xw #I have problem of using crossprod and tcrossprod here
            B22 <- xx - t2
            invB22 = 1/B22
            NeginvB22B21 <- crossprod(-invB22,B21)
            iXX11 <- wwi + as.numeric(invB22) * crossprod(B21)
            
            #Derive inverse of LHS with partationed matrix
            iXX[1:q0,1:q0]=iXX11
            iXX[q1,q1]=invB22
            iXX[q1,1:q0]=NeginvB22B21
            iXX[1:q0,q1]=NeginvB22B21
            
            #statistics
            rhs=c(wy,xy) #the size varied automaticly by A/AD model and validated d
            beta <- crossprod(iXX,rhs)
            df=n-q0-1
            ve=(yy-crossprod(beta,rhs))/df #this is a scaler
            
            #using iXX in the same as above to derive se
            se=sqrt(as.vector(diag(iXX)*ve))
            tvalue=beta/se
            pvalue <- 2 * pt(abs(tvalue), df,lower.tail = FALSE)
            
            #Handler of dependency between  marker are covariate
            if(!is.na(abs(B22[1,1]))){
                if(abs(B22[1,1])<10e-8)pvalue[]=NA
            }
            B = beta[length(beta)]
            P = pvalue[-1]
            return(list(B=B, P=P))
        }
        print.f <- function(i){print_bar(i=i, n=m, type="type1", fixed.points=TRUE)}
        results <- lapply(1:m, eff.farmcpu.parallel)
        if(is.list(results)) results <- matrix(unlist(results), m, byrow=TRUE)
        return(list(P=results[,-1], betapred=betapred, B=results[,1]))
    } #end of FarmCPU.LM function


#' FarmCPU.Burger
#' 
#' Last update: Dec 21, 2016
#' To calculate likelihood, variances and ratio, revised by Xiaolei based on GAPIT.Burger function from GAPIT package
#'
#' @author Xiaolei Liu and Zhiwu Zhang
#' 
#' @param Y phenotype, n by t matrix, n is sample size, t is number of phenotypes
#' @param CV covariates, n by c matrix, n is sample size, c is number of covariates
#' @param GK Genotype data in numerical format, taxa goes to row and snp go to columns
#' @param ncpus number of threads used for parallele computation
#' @param method two options for estimating variance components, 'FaST-LMM' or 'EMMA'
#'
#' @return
#' Output: REMLs - maximum log likelihood
#' Output: vg - genetic variance
#' Output: ve - residual variance
#' Output: delta - exp(root)
#' 
#' @keywords internal
FarmCPU.Burger <-
    function(Y=NULL,CV=NULL,GK=NULL,ncpus=2, method="FaST-LMM"){
        if(!is.null(CV)){
            CV=as.matrix(CV)#change CV to a matrix when it is a vector
            theCV=as.matrix(cbind(matrix(1,nrow(CV),1),CV))
        }else{
            theCV=matrix(1,nrow(Y),1)
        }
        
        #handler of single column GK
        n=nrow(GK)
        m=ncol(GK)
        if(m>2){
            theGK=as.matrix(GK)#GK is pure genotype matrix
        }else{
            theGK=matrix(GK,n,1)
        }
        
        if(method=="FaST-LMM"){
            myFaSTREML=FarmCPU.FaSTLMM.LL(pheno=matrix(Y[,-1],nrow(Y),1), snp.pool=theGK, X0=theCV, ncpus=ncpus)
            REMLs=-2*myFaSTREML$LL
            delta=myFaSTREML$delta
            vg=myFaSTREML$vg
            ve=myFaSTREML$ve
        }
        
        if(method=="EMMA"){
            theGK <- t(theGK)
            K <- MVP.K.VanRaden(M=theGK, priority="speed")
            myEMMAREML <- MVP.EMMA.Vg.Ve(y=matrix(Y[,-1],nrow(Y),1), X=theCV, K=K)
            REMLs=-2*myEMMAREML$REML
            delta=myEMMAREML$delta
            vg=myEMMAREML$vg
            ve=myEMMAREML$ve
        }
        
        #print("FarmCPU.Burger succeed!")
        return (list(REMLs=REMLs, vg=vg, ve=ve, delta=delta))
    } #end of FarmCPU.Burger


#' FarmCPU.SUB
#'
#' Last update: Febuary 26, 2013
#' Requirement: P has row name of SNP. s<=t. covariates of QTNs are next to SNP
#'
#' @author Xiaolei Liu and Zhiwu Zhang
#' 
#' @param GM SNP map information, m by 3 matrix, m is marker size, the three columns are SNP_ID, Chr, and Pos
#' @param GLM FarmCPU.GLM object
#' @param QTN s by 3  matrix for SNP name, chromosome and BP
#' @param method options are "penalty", "reward","mean","median",and "onsite"
#'
#' @return 
#' Output: GLM$P - Updated p-values by substitution process
#' Output: GLM$B - Updated effects by substitution process
FarmCPU.SUB <-
    function(GM=NULL,GLM=NULL,QTN=NULL,method="mean"){
        if(is.null(GLM$P)) return(NULL)  #P is required
        if(is.null(QTN)) return(NULL)  #QTN is required
        #print("FarmCPU.SUB Started")
        #print(length(QTN))
        if(length(QTN)==3){
            QTN=QTN[1]
        }else{
            QTN=QTN[,1]
        }
        position=match(QTN, GM[,1], nomatch = 0)
        nqtn=length(position)
        if(is.numeric(GLM$P)){
            GLM$P = as.matrix(GLM$P)
        }
        GLM$B = as.matrix(GLM$B)
        index=(ncol(GLM$P)-nqtn):(ncol(GLM$P)-1)
        spot=ncol(GLM$P)
        if(ncol(GLM$P)!=1){
            if(length(index)>1){
                if(method=="penalty") P.QTN=apply(GLM$P[,index],2,max,na.rm=TRUE)
                if(method=="reward") P.QTN=apply(GLM$P[,index],2,min,na.rm=TRUE)
                if(method=="mean") P.QTN=apply(GLM$P[,index],2,mean,na.rm=TRUE)
                if(method=="median") P.QTN=apply(GLM$P[,index],2,median,na.rm=TRUE)
                if(method=="onsite") P.QTN=GLM$P0[(length(GLM$P0)-nqtn+1):length(GLM$P0)]
            }else{
                if(method=="penalty") P.QTN=max(GLM$P[,index],na.rm=TRUE)
                if(method=="reward") P.QTN=min(GLM$P[,index],na.rm=TRUE)
                if(method=="mean") P.QTN=mean(GLM$P[,index],na.rm=TRUE)
                if(method=="median") P.QTN=median(GLM$P[,index],median,na.rm=TRUE)
                if(method=="onsite") P.QTN=GLM$P0[(length(GLM$P0)-nqtn+1):length(GLM$P0)]
            }
            #replace SNP pvalues with QTN pvalue
            GLM$P[position,spot] = P.QTN
            GLM$B[position,] = GLM$betapred
        }
        return(GLM)
    }#The function FarmCPU.SUB ends here


#' Remove bins that are highly correlated
#'
#' Last update: March 4, 2013
#' Requirement: GDP and GM have the same order on SNP
#' 
#' @author Xiaolei Liu and Zhiwu Zhang
#' 
#' @param GDP genotype, m by n matrix, m is marker size, n is sample size. This is Pure Genotype Data Matrix(GD). THERE IS NO COLUMN FOR TAXA
#' @param GM SNP map information, m by 3 matrix, m is marker size, the three columns are SNP_ID, Chr, and Pos
#' @param seqQTN s by 1 vecter for index of QTN on GM
#' @param seqQTN.p p value of each @param seqQTN
#' @param threshold pearson correlation threshold for remove correlated markers
#'
#' @return
#' Output: bin - n by s0 matrix of genotype
#' Output: binmap - s0 by 3 matrix for map of bin
#' Output: seqQTN - s0 by 1 vecter for index of QTN on GM
#' Relationship: bin=GDP[,c(seqQTN)], binmap=GM[seqQTN,], s0<=s
#' @keywords internal
FarmCPU.Remove <-
    function(GDP=NULL, GM=NULL, seqQTN=NULL, seqQTN.p=NULL, threshold=.99){
        if(is.null(seqQTN))return(list(bin=NULL,binmap=NULL,seqQTN=NULL))
        seqQTN=seqQTN[order(seqQTN.p)]
        
        hugeNum=10e10
        n=length(seqQTN)
        #fielter bins by physical location
        
        binmap=GM[seqQTN,]
        
        cb=as.numeric(binmap[,2])*hugeNum+as.numeric(binmap[,3])#create ID for chromosome and bp
        cb.unique=unique(cb)
        
        #print("debuge")
        #print(cb)
        #print(cb.unique)
        
        index=match(cb.unique,cb,nomatch = 0)
        seqQTN=seqQTN[index]
        
        #print("Number of bins after chr and bp fillter")
        n=length(seqQTN) #update n

        #Set sample
        ratio=.1
        maxNum=100000
        m=nrow(GDP) #sample size
        s=ncol(GDP) #number of markers
        
        sampled=s
        if(sampled>maxNum)sampled=maxNum
        
        
        #index=sample(s,sampled)
        index=1:sampled
        
        #This section has problem of turning big.matrix to R matrix
        #It is OK as x is small
        if(is.big.matrix(GDP)){
            x=t(as.matrix(deepcopy(GDP,rows=seqQTN,cols=index) ))
        }else{
            x=t(GDP[seqQTN,index] )
        }
        
        r=cor(as.matrix(x))
        index=abs(r)>threshold
        
        b=r*0
        b[index]=1
        c=1-b
        
        #The above are replaced by following
        c[lower.tri(c)]=1
        diag(c)=1
        bd <- apply(c,2,prod)
        
        position=(bd==1)
        seqQTN=seqQTN[position]
        #============================end of optimum============================================
        seqQTN=seqQTN[!is.na(seqQTN)]
        
        #This section has problem of turning big.matrix to R matrix
        if(is.big.matrix(GDP)){
            bin=t(as.matrix(deepcopy(GDP,rows=seqQTN,) ))
        }else{
            bin=t(GDP[seqQTN,] )
        }
        
        binmap=GM[seqQTN,]
        
        return(list(bin=bin, binmap=binmap, seqQTN=seqQTN))
    }#The function FarmCPU.Remove ends here


#' Set prior on existing p value
#'
#' Last update: March 10, 2013
#' Requirement: P and GM are in the same order, Prior is part of GM except P value
#' 
#' @author Xiaolei Liu and Zhiwu Zhang
#' 
#' @param GM an m by 3  matrix for SNP name, chromosome and BP
#' @param P an m by 1 matrix containing probability
#' @param Prior an s by 4  matrix for SNP name, chromosome, BP and p-value
#'
#' @return
#' Output: P - updated P value by prior information
#' 
#' @keywords internal
FarmCPU.Prior <-
    function(GM, P=NULL, Prior=NULL){
        #print("FarmCPU.Prior Started")
        
        if(is.null(Prior)& is.null(P))return(P)
        
        #get prior position
        if(!is.null(Prior)) index=match(Prior[,1],GM[,1],nomatch = 0)
        
        #if(is.null(P)) P=runif(nrow(GM)) #set random p value if not provided (This is not helpful)
        #print("debug set prior  a")
        
        #Get product with prior if provided
        if(!is.null(Prior) & !is.null(P)  )P[index]=P[index]*Prior[,4]
        
        return(P)
    }#The function FarmCPU.Prior ends here