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


#' MVP.Data: To prepare data for MVP package
#' Author: Xiaolei Liu, Lilin Yin and Haohao Zhang
#' Build date: Aug 30, 2016
#' Last update: Sep 12, 2018
#' 
#' @param fileVCF Genotype in VCF format
#' @param fileHMP Genotype in hapmap format
#' @param fileBed Genotype in PLINK binary format
#' @param fileNum Genotype in numeric format; pure 0, 1, 2 matrix; m * n, m is marker size, n is sample size
#' @param filePhe Phenotype, the first column is taxa name, the subsequent columns are traits
#' @param fileMap SNP map information, there are three columns, including SNP_ID, Chromosome, and Position
#' @param fileKin Kinship that represents relationship among individuals, n * n matrix, n is sample size
#' @param filePC Principal components, n*npc, n is sample size, npc is number of top columns of principal components
#' @param out A marker on output file name
#' @param sep.vcf seperator for vcf file.
#' @param sep.num seperator for numeric file.
#' @param sep.map seperator for map file.
#' @param sep.phe seperator for phenotype file.
#' @param sep.kin seperator for Kinship file.
#' @param sep.pc seperator for PC file.
#' @param type.geno type parameter in bigmemory, genotype data
#' @param type.kin type parameter in bigmemory, Kinship
#' @param type.pc type parameter in bigmemory, PC
#' @param type.map type parameter in bigmemory, PC
#' @param SNP.effect "Add" or "Dom"
#' @param SNP.impute "Left", "Middle", "Right"
#' @param maxLine number of SNPs, only used for saving memory when calculate kinship matrix
#' @param maxRecord maximum number for markers
#' @param maxInd maximum number for individuals
#' @param priority "speed" or "memory"
#' @param perc Percentage of markers used to calculate PCA
#' @param pcs.keep how many PCs to keep
#' @param verbose whether to print
#'
#' Output files:
#' genotype.desc, genotype.bin: genotype file in bigmemory format
#' phenotype.phe: ordered phenotype file, same taxa order with genotype file
#' map.map: SNP information
#' k.desc, k.bin: Kinship matrix in bigmemory format
#' pc.desc, pc.bin: PC matrix in bigmemory format
#' Requirement: fileHMP, fileBed, and fileNum can not input at the same time
#' @examples 
#' bfilePath <- system.file("extdata", "mvp", package = "rMVP")
#' MVP.Data(fileBed=bfilePath)
MVP.Data <- function(fileMVP = NULL, fileVCF = NULL, fileHMP = NULL, fileBed = NULL, fileNum = NULL, fileMap = NULL,
                     filePhe = NULL, fileInd = NULL, fileKin = TRUE, filePC = TRUE, out = "mvp", sep.num = "\t",
                     auto_transpose = TRUE, sep.map = "\t", sep.phe = "\t", sep.kin = "\t", sep.pc = "\t",
                     type.geno = "char", pheno_cols = NULL, SNP.impute = "Major", maxLine = 10000, priority = "speed",
                     perc = 1, pcs.keep = 5, verbose = TRUE, ...) {
    
    cat("Preparing data for MVP...\n")
    
    # Parameter compatible upgrade
    params <- list(...)
    if ("sep.vcf" %in% names(params)) { message("WARNING: 'sep.vcf' has been DEPRECATED.") }
    if ("vcf.jump" %in% names(params)) { message("WARNING: 'vcf.jump' has been DEPRECATED.") }
    if ("SNP.effect" %in% names(params)) { message("WARNING: 'SNP.effect' has been DEPRECATED.") }
    if ("sep.hmp" %in% names(params)) { message("WARNING: 'sep.hmp' has been DEPRECATED.") }
    if ("type.kin" %in% names(params)) { message("WARNING: 'type.kin' has been DEPRECATED.") }
    if ("type.pc" %in% names(params)) { message("WARNING: 'type.pc' has been DEPRECATED.") }
    if ("type.map" %in% names(params)) { message("WARNING: 'type.map' has been DEPRECATED.") }
    if ("maxRecord" %in% names(params)) { message("WARNING: 'maxRecord' has been DEPRECATED. Use maxLine instead.") }
    if ("maxInd" %in% names(params)) { message("WARNING: 'maxInd' has been DEPRECATED. Use maxLine instead.") }
    
    # Check Data Input
    geno_files <- !sapply(list(
        fileMVP, fileVCF, fileHMP, fileBed, fileNum, fileMap
        ), is.null)
    
    flag <- paste(sapply(strsplit(as.character(geno_files), ''), `[[`, 1), collapse = '')   # flag = 'TFFFFF'
    
    # convert genotype file
    error_input <- function(geno_files) {
        if (length(which(geno_files[1:5])) != 1) {
            stop("Please input only one genotype data format!")
        }
        
        if (length(which(geno_files[5:6])) == 1) {
            stop("Both Map and Numeric genotype files are needed!")
        }
    }
    switch(flag,
           # fileMVP, fileVCF, fileHMP, fileBed, fileNum, fileMap
           # TODO: Fix it
           # TFFFFF = MVP.Data.MVP2MVP(),
           FTFFFF = 
               MVP.Data.VCF2MVP(
                   vcf_file = fileVCF, 
                   out = out,
                   verbose = verbose
               ),
           FFTFFF = 
               MVP.Data.Hapmap2MVP(
                   hapmap_file = fileHMP, 
                   out = out,
                   verbose = verbose
               ),
           FFFTFF = 
               MVP.Data.Bfile2MVP(
                   bfile = fileBed, 
                   out = out, 
                   maxLine = maxLine, 
                   priority = priority, 
                   type.geno = type.geno,
                   verbose = verbose
               ),
           FFFFTT = 
               MVP.Data.Numeric2MVP( 
                   num_file = fileNum, 
                   out = out, 
                   maxLine = maxLine, 
                   priority = priority, 
                   type.geno = type.geno,
                   auto_transpose = auto_transpose,
                   verbose = verbose
               ),
           error_input(geno_files)
    )
    cat("Preparation for Genotype File is done!\n")
    
    # phenotype
    if (!is.null(filePhe)) {
        MVP.Data.Pheno(
            pheno_file = filePhe, 
            out = out, 
            header = TRUE,
            cols = pheno_cols, 
            sep = sep.phe
            # , missing = missing
        )
    }
    # impute
    if (!is.null(SNP.impute)) {
        MVP.Data.impute(
            mvp_file = paste0(out, '.geno.desc'), 
            out = paste0(out, '.imp'), 
            method = SNP.impute
            # ,ncpus = ncpus
        )
        out <- paste0(out, '.imp')
    }
    
    # get pc
    MVP.Data.PC(
        filePC = filePC, 
        mvp_prefix = out, 
        perc = perc, 
        pcs.keep = pcs.keep, 
        sep = sep.pc
    )
    
    # get kin
    MVP.Data.Kin(
        fileKin = fileKin, 
        mvp_prefix = out, 
        maxLine = maxLine, 
        priority = priority, 
        sep = sep.kin
    )

    cat("MVP data prepration accomplished successfully!\n")
} # end of MVP.Data function

#' MVP.Data.VCF2MVP: To transform vcf data to MVP package
#' Author: Haohao Zhang
#' Build date: Sep 12, 2018
#' 
#' @param vcf_file Genotype in VCF format
#' @param out the name of output file
#' @param maxLine the max number of line to write to big matrix for each loop
#' @param type.geno the type of genotype elements
#' @param threads number of thread for transforming
#' @param verbose whether to print the reminder
#'
#' @return number of individuals and markers.
#' Output files:
#' genotype.desc, genotype.bin: genotype file in bigmemory format
#' phenotype.phe: ordered phenotype file, same taxa order with genotype file
#' map.map: SNP information
#' @examples 
#' vcfPath <- system.file("extdata", "mvp.vcf", package = "rMVP")
#' MVP.Data.VCF2MVP(vcfPath)
MVP.Data.VCF2MVP <- function(vcf_file, out='mvp', maxLine = 1e4, type.geno='char', threads=1, verbose=TRUE) {
    t1 <- as.numeric(Sys.time())
    # check old file
    backingfile <- paste0(basename(out), ".geno.bin")
    descriptorfile <- paste0(basename(out), ".geno.desc")
    if (file.exists(backingfile)) file.remove(backingfile)
    if (file.exists(descriptorfile)) file.remove(descriptorfile)
    
    # parser map
    cat("Reading file...\n")
    m_res <- vcf_parser_map(vcf_file = vcf_file, out = out)
    cat(paste0("inds: ", m_res$n, "\tmarkers:", m_res$m, '\n'))
    
    # parse genotype
    bigmat <- filebacked.big.matrix(
        nrow = m_res$m,
        ncol = m_res$n,
        type = type.geno,
        backingfile = backingfile,
        backingpath = dirname(out),
        descriptorfile = descriptorfile,
        dimnames = c(NULL, NULL)
    )
    vcf_parser_genotype(vcf_file = vcf_file, pBigMat = bigmat@address, maxLine = maxLine, threads = threads, verbose = verbose)
    t2 <- as.numeric(Sys.time())
    cat("Preparation for GENOTYPE data is done within", format_time(t2 - t1), "\n")
    return(c(m, n))
}

#' MVP.Data.Bfile2MVP: To transform plink binary data to MVP package
#' Author: Haohao Zhang
#' Build date: Sep 12, 2018
#' 
#' @param bfile Genotype in binary format (.bed, .bim, .fam)
#' @param out the name of output file
#' @param maxLine the max number of line to write to big matrix for each loop
#' @param priority 'memory' or 'speed'
#' @param type.geno the type of genotype elements
#' @param threads number of thread for transforming
#' @param verbose whether to print the reminder
#'
#' @return number of individuals and markers.
#' Output files:
#' genotype.desc, genotype.bin: genotype file in bigmemory format
#' phenotype.phe: ordered phenotype file, same taxa order with genotype file
#' map.map: SNP information
#' @examples 
#' bfilePath <- system.file("extdata", "mvp", package = "rMVP")
#' MVP.Data.Bfile2MVP(bfilePath)
MVP.Data.Bfile2MVP <- function(bfile, out='mvp', maxLine=1e4, priority='speed', type.geno='char', threads=0, verbose=TRUE) {
    t1 <- as.numeric(Sys.time())
    # check old file
    backingfile <- paste0(basename(out), ".geno.bin")
    descriptorfile <- paste0(basename(out), ".geno.desc")
    if (file.exists(backingfile)) file.remove(backingfile)
    if (file.exists(descriptorfile)) file.remove(descriptorfile)
    
    # parser map
    cat("Reading file...\n")
    m <- MVP.Data.Map(map_file = paste0(bfile, '.bim'), out = out, cols = c(2, 1, 4), header = FALSE)
    
    # parser phenotype, ind file
    fam <- read.table(paste0(bfile, '.fam'), header = FALSE)
    n <- nrow(fam)
    write.table(fam[, 2], paste0( out, '.geno.ind'), col.names = FALSE, quote = FALSE)
    
    cat(paste0("inds: ", n, "\tmarkers:", m, '\n'))
    
    # parse genotype
    bigmat <- filebacked.big.matrix(
        nrow = m,
        ncol = n,
        type = type.geno,
        backingfile = backingfile,
        backingpath = dirname(out),
        descriptorfile = descriptorfile,
        dimnames = c(NULL, NULL)
    )
    
    if (priority == "speed") { maxLine <- -1 }
    read_bfile(bed_file = bfile, pBigMat = bigmat@address, maxLine = maxLine, threads = threads, verbose = verbose)
    t2 <- as.numeric(Sys.time())
    cat("Preparation for GENOTYPE data is done within", format_time(t2 - t1), "\n")
    return(c(m, n))
}

#' MVP.Data.Hapmap2MVP: To transform Hapmap data to MVP package
#' Author: Haohao Zhang
#' Build date: Sep 12, 2018
#' 
#' @param hapmap_file Genotype in Hapmap format
#' @param out the name of output file
#' @param type.geno the type of genotype elements
#' @param verbose whether to print the reminder
#'
#' @return number of individuals and markers.
#' Output files:
#' genotype.desc, genotype.bin: genotype file in bigmemory format
#' phenotype.phe: ordered phenotype file, same taxa order with genotype file
#' map.map: SNP information
#' @examples 
#' hapmapPath <- system.file("extdata", "mvp.hmp", package = "rMVP")
#' MVP.Data.Hapmap2MVP(hapmapPath)
MVP.Data.Hapmap2MVP <- function(hapmap_file, out='mvp', type.geno='char', verbose=TRUE) {
    t1 <- as.numeric(Sys.time())
    # check old file
    backingfile <- paste0(basename(out), ".geno.bin")
    descriptorfile <- paste0(basename(out), ".geno.desc")
    if (file.exists(backingfile)) file.remove(backingfile)
    if (file.exists(descriptorfile)) file.remove(descriptorfile)
    
    # parser map
    cat("Reading file...\n")
    m_res <- hapmap_parser_map(hapmap_file, out)
    cat(paste0("inds: ", m_res$n, "\tmarkers:", m_res$m, '\n'))
    
    # parse genotype
    bigmat <- filebacked.big.matrix(
        nrow = m_res$m,
        ncol = m_res$n,
        type = type.geno,
        backingfile = backingfile,
        backingpath = dirname(out),
        descriptorfile = descriptorfile,
        dimnames = c(NULL, NULL)
    )
    hapmap_parser_genotype(hapmap_file, bigmat@address, verbose)
    t2 <- as.numeric(Sys.time())
    cat("Preparation for GENOTYPE data is done within", format_time(t2 - t1), "\n")
    return(c(m, n))
}

#' MVP.Data.Numeric2MVP: To transform Numeric data to MVP package
#' Author: Haohao Zhang
#' Build date: Sep 12, 2018
#' 
#' @param num_file Genotype in Numeric format (0,1,2)
#' @param out the name of output file
#' @param maxLine the max number of line to write to big matrix for each loop
#' @param priority 'memory' or 'speed'
#' @param row_names whether the numeric genotype has row names
#' @param col_names whether the numeric genotype has column names
#' @param type.geno the type of genotype elements
#' @param auto_transpose whether to detecte the row and column
#' @param verbose whether to print the reminder
#'
#' @return number of individuals and markers.
#' Output files:
#' genotype.desc, genotype.bin: genotype file in bigmemory format
#' phenotype.phe: ordered phenotype file, same taxa order with genotype file
#' map.map: SNP information
#' @examples 
#' numericPath <- system.file("extdata", "mvp.num", package = "rMVP")
#' MVP.Data.Numeric2MVP(numericPath)
MVP.Data.Numeric2MVP <- function(num_file, out='mvp', maxLine=1e4, priority='speed', row_names=FALSE, col_names=FALSE, type.geno='char', auto_transpose=TRUE, verbose=TRUE) {
    t1 <- as.numeric(Sys.time())
    # check old file
    backingfile <- paste0(basename(out), ".geno.bin")
    descriptorfile <- paste0(basename(out), ".geno.desc")
    if (file.exists(backingfile)) file.remove(backingfile)
    if (file.exists(descriptorfile)) file.remove(descriptorfile)
    
    # detecte n(ind) and m(marker)
    cat("Reading file...\n")
    scan <- numeric_scan(num_file)
    n <- scan$n
    m <- scan$m

    transposed <- FALSE
    if (auto_transpose & (m < n)) {
        message("WARNING: nrow < ncol detected, has been automatically transposed.")
        transposed <- TRUE
        t <- n; n <- m; m <- t;
    }
    cat(paste0("inds: ", n, "\tmarkers:", m, '\n'))
    
    # define bigmat
    bigmat <- filebacked.big.matrix(
        nrow = m,
        ncol = n,
        type = type.geno,
        backingfile = backingfile,
        backingpath = dirname(out),
        descriptorfile = descriptorfile,
        dimnames = c(NULL, NULL)
    )
    
    # convert to bigmat - speed
    if (priority == "speed") {
        options(bigmemory.typecast.warning = FALSE)
        
        # detecte sep
        con <- file(num_file, open = 'r')
        line <- readLines(con, 1)
        close(con)
        sep <- substr(line, 2, 2)
        
        # load geno
        suppressWarnings(
            geno <- read.big.matrix(num_file, head = FALSE, sep = sep)
        )
        if (transposed) {
            bigmat[, ] <- t(geno[, ])
        } else {
            bigmat[, ] <- geno[, ]
        }
        rm("geno")
    }
    
    # convert to bigmat - memory
    if (priority == "memory") {
        i <- 0
        con <- file(num_file, open = 'r')
        if (col_names) { readLines(con, n = 1) }
        while (TRUE) {
            line = readLines(con, n = maxLine)

            len <- length(line)
            if (len == 0) { break }

            line <- do.call(rbind, strsplit(line, '\\s+'))
            if (row_names) { line <- line[, 2:ncol(line)]}
            if (transposed) {
                bigmat[, (i + 1):(i + length(line))] <- line
                i <- i + length(line)
                percent <- 100 * i / n
            } else {
                bigmat[(i + 1):(i + length(line)), ] <- line
                i <- i + length(line)
                percent <- 100 * i / m
            }

            cat(paste0("Written into MVP File: ", percent, "%"))
        }
        close(con)
    }
    
    flush(bigmat)
    gc()
    t2 <- as.numeric(Sys.time())
    cat("Preparation for GENOTYPE data is done within", format_time(t2 - t1), "\n")
    return(c(m, n))
}

#' MVP.Data.MVP2Bfile: To transform MVP data to binary format
#' Author: Haohao Zhang
#' Build date: Sep 12, 2018
#' 
#' @param bigmatrix Genotype in bigmatrix format (0,1,2)
#' @param map the map file
#' @param pheno the phenotype file
#' @param out the name of output file
#' @param verbose whether to print the reminder
#'
#' @return NULL
#' Output files:
#' .bed, .bim, .fam
#' 
#' @examples 
#' bigmat <- as.big.matrix(matrix(1:6, 3, 2))
#' map <- matrix(c("rs1", "rs2", "rs3", 1, 1, 1, 10, 20, 30), 3, 3)
#' MVP.Data.MVP2Bfile(bigmat, map)
MVP.Data.MVP2Bfile <- function(bigmat, map, pheno=NULL, out='mvp.plink', verbose=TRUE) {
    t1 <- as.numeric(Sys.time())
    # write bed file
    write_bfile(bigmat@address, out)
    
    # write fam
    #  1. Family ID ('FID')
    #  2. Within-family ID ('IID'; cannot be '0')
    #  3. Within-family ID of father ('0' if father isn't in dataset)
    #  4. Within-family ID of mother ('0' if mother isn't in dataset)
    #  5. Sex code ('1' = male, '2' = female, '0' = unknown)
    #  6. Phenotype value ('1' = control, '2' = case, '-9'/'0'/non-numeric = missing data if case/control)
    if (is.null(pheno)) {
        ind <- paste0("ind", 1:ncol(bigmat))
        pheno <- rep(-9, ncol(bigmat))
        message("pheno is NULL, automatically named individuals.")
    } else if (ncol(pheno) == 1) {
        ind <- pheno[, 1]
        pheno <- rep(-9, ncol(bigmat))
    } else if (ncol(pheno) >= 2) {
        ind <- pheno[, 1]
        pheno <- pheno[, 2]
        if (ncol(pheno) > 2) { 
            message("Only the first phenotype is written to the fam file, and the remaining ", ncol(pheno) - 1, " phenotypes are ignored.")
        }
    }
    
    fam <- cbind(ind, ind, 0, 0, 0, pheno)
    write.table(fam, paste0(out, '.fam'), quote = FALSE, row.names = FALSE, col.names = FALSE, sep = ' ')
    
    # write bim
    #  1. Chromosome code (either an integer, or 'X'/'Y'/'XY'/'MT'; '0' indicates unknown) or name
    #  2. Variant identifier
    #  3. Position in morgans or centimorgans (safe to use dummy value of '0')
    #  4. Base-pair coordinate (normally 1-based, but 0 ok; limited to 231-2)
    #  5. Allele 1 (corresponding to clear bits in .bed; usually minor)
    #  6. Allele 2 (corresponding to set bits in .bed; usually major)
    bim <- cbind(map[, 2], map[, 1], 0, map[, 3], 0, 0)
    write.table(bim, paste0(out, '.bim'), quote = FALSE, row.names = FALSE, col.names = FALSE, sep = '\t')
    t2 <- as.numeric(Sys.time())
    cat("Done within", format_time(t2 - t1), "\n")
}

#' MVP.Data.Pheno: To clean up phenotype file
#' Author: Haohao Zhang
#' Build date: Sep 12, 2018
#' 
#' @param pheno_file the name of phenotype file
#' @param out the name of output file
#' @param cols selected columns
#' @param header whether the file contains header
#' @param sep seperator of the file
#' @param missing the missing value
#'
#' @return NULL
#' Output files:
#' cleaned phenotype file
#' @examples 
#' phePath <- system.file("extdata", "mvp.phe", package = "rMVP")
#' MVP.Data.Pheno(phePath)
MVP.Data.Pheno <- function(pheno_file, out='mvp', cols=NULL, header=TRUE, sep='\t', missing=c(NA, 'NA', '-9', 9999)) {
    t1 <- as.numeric(Sys.time())
    # read data
    if (!is.vector(pheno_file)) { pheno_file <- c(pheno_file) }

    # phenotype files
    phe <- read.delim(pheno_file, sep = sep, header = header)
    
    # auto select columns
    if (is.null(cols)) {
        cols <- c(1:ncol(phe))
    }
    
    # check phenotype file
    if (length(cols) < 2) {
        stop("ERROR: At least 2 columns in the phenotype file should be specified.")
    }
    phe[, cols[1]] <- sapply(phe[, cols[1]], function(x){gsub("^\\s+|\\s+$", "", x)}) 
    
    # read geno ind list
    geno.id.file <- paste0(out, '.geno.id')
    if (file.exists(geno.id.file)) {
        # read from file
        geno.id <- read.table(geno.id.file, stringsAsFactors = FALSE)
        overlap.ind <- intersect(geno.id[, 1], phe[, cols[1]])
        if (length(overlap.ind) == 0) {
            cat(paste0("Phenotype individuals: ", paste(phe[, cols[1]][1:5], collapse = ", "), "..."), "\n")
            cat(paste0("Genotype individuals: ", paste(geno.id[1:5, 1], collapse = ", "), "..."), "\n")
            stop("No common individuals between phenotype and genotype!")
        } else {
            cat(paste(length(overlap.ind), "common individuals between phenotype and genotype."), "\n")
        }
    } else {
        # use ind. name from phenotypefile
        geno.id <- phe[, cols[1]]
    }
    
    # merge
    pheno <- merge(geno.id, phe[, cols],  by = 1, all.x = TRUE)
    
    # rename header
    colnames(pheno)[1] <- 'Taxa'
    if (!header)  {
        traits <- 2:ncol(pheno)
        colnames(pheno)[traits] <- paste0('t', traits - 1)
    }
    
    # drop empty traits
    pheno[pheno %in% missing] <- NA
    drop = c()
    for (i in 2:ncol(pheno)) {
        if (all(is.na(pheno[, i]))) {
            drop = c(drop, i)
        }
    }
    if (length(drop) > 0) {
        pheno <- pheno[, -drop]
    }
    
    # Output
    write.table(pheno, paste0(out, '.phe'), quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)
    t2 <- as.numeric(Sys.time())
    cat("Preparation for PHENOTYPE data is Done within", format_time(t2 - t1), "\n")
}

#' MVP.Data.Map: To check map file
#' Author: Haohao Zhang
#' Build date: Sep 12, 2018
#' 
#' @param map_file the name of map file
#' @param out the name of output file
#' @param cols selected columns
#' @param header whether the file contains header
#' @param sep seperator of the file
#' 
#' @return NULL
#' 
#' @examples 
#' mapPath <- system.file("extdata", "mvp.map", package = "rMVP")
#' MVP.Data.Map(mvp.map)
MVP.Data.Map <- function(map_file, out='mvp', cols=c(1, 2, 3), header=TRUE, sep='\t') {
    t1 <- as.numeric(Sys.time())
    map <- read.table(map_file, header = header)
    map <- map[, cols]
    colnames(map) <- c("SNP", "CHROM", "POS")
    if (length(unique(map[, 1])) != nrow(map)) {
        warning("WARNING: SNP is not unique and has been automatically renamed.")
        map[, 1] <- apply(map[, c(2, 3)], 1, paste, collapse = "-")
    }
    table = write.table(map, paste0(out, ".map"), row.names = FALSE, col.names = TRUE, sep = '\t', quote = FALSE)
    t2 <- as.numeric(Sys.time())
    cat("Preparation for MAP data is done within", format_time(t2 - t1), "\n")
    return(nrow(map))
}

MVP.Data.PC <- function(filePC, mvp_prefix='mvp', out=NULL, perc=1, pcs.keep=5, sep='\t') {
    if (is.null(out)) out <- mvp_prefix
    
    # check old file
    backingfile <- paste0(basename(out), ".pc.bin")
    descriptorfile <- paste0(basename(out), ".pc.desc")
    if (file.exists(backingfile)) file.remove(backingfile)
    if (file.exists(descriptorfile)) file.remove(descriptorfile)
    
    # get pc
    if (is.character(filePC)) {
        myPC <- read.big.matrix(filePC, head = FALSE, type = 'double', sep = sep)
    } else if (filePC == TRUE) {
        geno <- attach.big.matrix(paste0(mvp_prefix, ".geno.desc"))
        myPC <- MVP.PCA(geno, perc = perc, pcs.keep = pcs.keep)$PCs
    } else if (filePC == FALSE || is.null(filePC)) {
        return()
    } else {
        stop("ERROR: The value of filePC is invalid.")
    }
    
    # define bigmat
    PC <- filebacked.big.matrix(
        nrow = nrow(myPC),
        ncol = ncol(myPC),
        type = 'double',
        backingfile = backingfile,
        backingpath = dirname(out),
        descriptorfile = descriptorfile,
        dimnames = c(NULL, NULL)
    )
    
    PC[, ] <- myPC[, ]
    flush(PC)
    cat("Preparation for PC matrix is done!\n")
}

MVP.Data.Kin <- function(fileKin, mvp_prefix='mvp', out=NULL, maxLine=1e4, priority='speed', sep='\t') {
    if (is.null(out)) out <- mvp_prefix
    
    # check old file
    backingfile <- paste0(basename(out), ".kin.bin")
    descriptorfile <- paste0(basename(out), ".kin.desc")
    if (file.exists(backingfile)) file.remove(backingfile)
    if (file.exists(descriptorfile)) file.remove(descriptorfile)
    
    # get kin
    if (is.character(fileKin)) {
        myKin <- read.big.matrix(fileKin, head = FALSE, type = 'double', sep = sep)
    } else if (fileKin == TRUE) {
        geno <- attach.big.matrix(paste0(mvp_prefix, ".geno.desc"))
        cat("Calculate KINSHIP using Vanraden method...\n")
        myKin <- MVP.K.VanRaden(geno, priority = priority, maxLine = maxLine)
    } else if (fileKin == FALSE || is.null(fileKin)) {
        return()
    } else {
        stop("ERROR: The value of fileKin is invalid.")
    }
    
    # define bigmat
    Kinship <- filebacked.big.matrix(
        nrow = nrow(myKin),
        ncol = ncol(myKin),
        type = 'double',
        backingfile = backingfile,
        backingpath = dirname(out),
        descriptorfile = descriptorfile,
        dimnames = c(NULL, NULL)
    )
    
    Kinship[, ] <- myKin[, ]
    flush(Kinship)
    cat("Preparation for Kinship matrix is done!\n")
}

#' MVP.Data.impute: To impute the missing genotype
#' Author: Haohao Zhang
#' Build date: Sep 12, 2018
#' 
#' @param mvp_file the name of mvp file
#' @param out the name of output file
#' @param method 'Major', 'Minor', "Middle"
#' @param ncpus number of threads for imputing
#'
#' Output files:
#' imputed genotype file
#' @examples 
#' mvpPath <- system.file("extdata", "mvp.geno.desc", package = "rMVP")
#' MVP.Data.impute(mvpPath)
# TODO:A little slow (inds: 6, markers:50703 ~ 10s @haohao's mbp)
MVP.Data.impute <- function(mvp_file, out='mvp.imp', method='Major', ncpus=NULL) {
    cat("Imputing...\n")
    # input
    bigmat  <- attach.big.matrix(mvp_file)
    options(bigmemory.typecast.warning = FALSE)
    if (is.null(ncpus)) ncpus <- detectCores()
    
    if (is.null(out)) {
        message("out is NULL, impute inplace.")
        outmat <- attach.big.matrix(mvp_file)
    } else {
        # output to new genotype file.
        backingfile <- paste0(basename(out), ".geno.bin")
        descriptorfile <- paste0(basename(out), ".geno.desc")
        if (file.exists(backingfile)) file.remove(backingfile)
        if (file.exists(descriptorfile)) file.remove(descriptorfile)
        
        outmat <- filebacked.big.matrix(
            nrow = nrow(bigmat),
            ncol = ncol(bigmat),
            type = typeof(bigmat),
            backingfile = backingfile,
            backingpath = dirname(out),
            descriptorfile = descriptorfile,
            dimnames = c(NULL, NULL)
        )
        outmat[, ] <- bigmat[, ]
    }
    
    # impute single marker
    impute_marker <- function(i) {
        # get frequency 
        c <- table(outmat[i, ])
        
        # get Minor / Major / Middle Gene
        if (method == 'Middle' | length(c) == 0) { A <- 1 }
        else if (method == 'Major') { A <- as.numeric(names(c[c == max(c)])) }
        else if (method == 'Minor') { A <- as.numeric(names(c[c == min(c)])) }
        
        # impute
        if (length(A) > 1) { A <- A[1] }
        outmat[i, is.na(outmat[i, ])] <- A
    }
    
    
    mclapply(1:nrow(outmat), impute_marker, mc.cores = ncpus)
    
    cat("Impute Genotype File is done!\n")
    # biganalytics::apply(bigmat, 1, impute.marker, MISSING = MISSING, method = method)
}

#' MVP.Data.QC: quality control of genotype
#' Author: Haohao Zhang
#' Build date: Sep 12, 2018
#' 
#' @param mvp_file the name of genotype file
#' @param out the name of output file
#' @param geno the threshold of calling rate of markers
#' @param mind the threshold of calling rate of individuals
#' @param maf the threshold of minor allel frequency
#' @param hwe the threshold of hwe
#' @param ncpus the number of threads for quality control
#'
#' Output files:
#' cleaned genotype file
MVP.Data.QC <- function(mvp_file, out='mvp.qc', geno=0.1, mind=0.1, maf=0.05, hwe=NULL, ncpus=NULL) {
        cat("Quality control...\n")
        # input
        bigmat  <- attach.big.matrix(mvp_file)
        options(bigmemory.typecast.warning = FALSE)
        if (is.null(ncpus)) ncpus <- detectCores()
        
        # qc marker
        marker_index <- rep(TRUE, nrow(bigmat))
        if (!is.null(geno)) {
            qc_marker <- function(i, cutoff) {
                c <- table(bigmat[i, ])
                if (c[NA] > cutoff) {return(FALSE)} else {return(TRUE)}
        }
            marker_index <- cbind(mclapply(1:nrow(bigmat), qc_marker, mc.cores = ncpus, cutoff = (geno * nrow(bigmat))))
            cat(paste0(length(marker_index[marker_index == FALSE, ])), "markers are filtered because the missing ratio is higher than", geno, "\n")
        }
        
        # qc individual
        ind_index <- rep(TRUE, ncol(bigmat))
        if (!is.null(mind)) {
            qc_ind <- function(i, cutoff) {
                c <- table(bigmat[, i])
                if (c[NA] > cutoff) {return(FALSE)} else {return(TRUE)}
        }
            ind_index <- cbind(mclapply(1:ncol(bigmat), qc_ind, mc.cores = ncpus, cutoff = (mind * ncol(bigmat))))
            cat(paste0(length(marker_index[marker_index == FALSE, ])), "individuals are filtered because the missing ratio is higher than", mind, "\n")
        }
        
        # TODO: support hwe
        # TODO: qc report
        
        bigmat <- bigmat[marker_index, ind_index]
 }

