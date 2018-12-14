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


#' Print MVP Banner
#'
#' Build date: Aug 30, 2017
#' Last update: Dec 12, 2018
#' 
#' @author Lilin Yin, Haohao Zhang, and Xiaolei Liu
#' 
#' @param width the width of the message
#'
#' @return NULL
#' @export
#'
#' @examples
#' MVP.version()
MVP.Version <- function(width=60) {
    welcome <- "Welcome to MVP"
    title   <- "A Memory-efficient, Visualization-enhanced, and Parallel-accelerated Tool For GWAS"
    authors <- "Authors: Lilin Yin, Haohao Zhang, and Xiaolei Liu"
    contact <- "Contact: xiaoleiliu@mail.hzau.edu.cn"
    logo_s  <- c(" __  __  __   __  ___",
                 "|  \\/  | \\ \\ / / | _ \\",
                 "| |\\/| |  \\ V /  |  _/",
                 "|_|  |_|   \\_/   |_|")

    print_info(welcome = welcome, title = title, logo = logo_s, authors = authors, contact = contact, linechar = '=', width = 60)
}


print_accomplished <- function(width = 60) {
    cat(make_line("MVP ACCOMPLISHED", width = width, linechar = '='), "\n")
}

#' Print R Package information, include title, short_title, logo, version, authors, contact
#'
#' Build date: Oct 22, 2018
#' Last update: Oct 22, 2018
#' 
#' @keywords internal
#' @author Haohao Zhang
#' 
#' @param welcome welcome text, for example: "Welcom to <Packagename>"
#' @param title long text to introduct package
#' @param short_title short label, top-left of logo
#' @param logo logo
#' @param version short label, bottom-right of logo
#' @param authors 
#' @param contact email or website
#' @param line 1, 2, or char
#' @param width banner width
#'
#' @examples
#' welcome <- "Welcome to MVP"
#' title   <- "A Memory-efficient, Visualization-enhanced, and Parallel-accelerated Tool For GWAS"
#' authors <- "Authors: Lilin Yin, Haohao Zhang, and Xiaolei Liu"
#' contact <- "Contact: xiaoleiliu@mail.hzau.edu.cn"
#' logo_s  <- c(" __  __  __   __  ___",
#'              "|  \/  | \ \ / / | _ \",
#'              "| |\/| |  \ V /  |  _/",
#'              "|_|  |_|   \_/   |_|")
#' print_info(welcome = welcome, title = title, logo = logo_s, authors = authors, contact = contact, linechar = '=', width = width)
print_info <- function(welcome=NULL, title=NULL, short_title=NULL, logo=NULL, version=NULL, authors=NULL, contact=NULL, linechar = '=', width=NULL) {
    msg <- c()
    # width
    if (is.null(width)) { width <- getOption('width') }
    # version
    if (is.null(version)) {
        if (getPackageName() == ".GlobalEnv") {
            version <- "devel"
        } else {
            version <- as.character(packageVersion(getPackageName()))
        }
    }
    # welcome
    if (is.null(welcome)) { 
        if (getPackageName() == ".GlobalEnv") {
            welcome <- ""
        } else {
            welcome <- paste0("Welcome to ", getPackageName())
        }
    }
    msg <- c(msg, make_line(welcome, line = linechar, width = width))
    # title
    if (!is.null(title)) {
        msg <- c(msg, rule_wrap(string = title, width = width, align = "center"))
    }
    
    # align logo
    logo_width <- max(sapply(logo, nchar))
    for (i in 1:length(logo)) {
        l <- paste0(logo[i], paste(rep(" ", logo_width - nchar(logo[i])), collapse = ""))
        l <- make_line(l, width)
        msg <- c(msg, l)
    }
    
    # paste short_title label to logo top-left
    if (!is.null(short_title)) {
        i <- length(msg) - length(logo) + 1
        msg[i] <- paste_label(msg[i], paste0(short_title), side = "left")
    }
    
    # paste version label to logo bottom-right
    msg[length(msg)] <- paste_label(msg[length(msg)], paste0("Version: ", version), side = "right")
    
    # authors
    if (!is.null(authors)) {
        msg <- c(msg, rule_wrap(string = authors, align = "left", linechar = " ", width = width))
    }
    # contact
    if (!is.null(contact)) {
        msg <- c(msg, rule_wrap(string = contact, align = "left", linechar = " ", width = width))
    }
    # bottom line
    msg <- c(msg, paste0(rep(linechar, width), collapse = ''))
    
    cat(msg, sep = "\n")
}

#' make line
#' 
#' Build date: Dec 12, 2018
#' Last update: Dec 12, 2018
#' 
#' @keywords internal
#' @author Haohao Zhang
make_line <- function(string, width, linechar = " ", align = "center", margin = 1) {
    string <- paste0(paste0(rep(" ", margin), collapse = ""),
                     string,
                     paste0(rep(" ", margin), collapse = ""))
    
    if (align == "center") {
        if (width > nchar(string)) {
            left_width <- (width - nchar(string)) %/% 2
            right_width <- width - nchar(string) - left_width
            string <-
                paste0(paste0(rep(linechar, left_width), collapse = ""),
                       string,
                       paste0(rep(linechar, right_width), collapse = ""))
        }
    } else if (align == "left") {
        if (width > nchar(string)) {
            string <-
                paste0(linechar,
                       string,
                       paste0(rep(linechar, width - nchar(string) - 1), collapse = ""))
        }
    }
    return(string)
}

#' wrap text to multiple line, align left, right or center.
#' 
#' Build date: Oct 22, 2018
#' Last update: Dec 12, 2018
#' by using base::strwarp.
#' 
#' @keywords internal
#' @author Haohao Zhang
rule_wrap <- function(string, width, align = "center", linechar = " ") {
    # define
    msg <- c()
    lines <- strwrap(string, width = width - 4)

    # wrap
    for (i in 1:length(lines)) {
        l <- make_line(lines[i], width = width, linechar = linechar, align = align)
        msg <- c(msg, l)
    }
    return(msg)
}

#' Paste label to a line
#' 
#' Build date: Oct 22, 2018
#' Last update: Oct 22, 2018
#' 
#' @param line long text
#' @param label short label
#' @param side "right" or "left"
#' @param margin default 2
#' 
#' @keywords internal
#' @author Haohao Zhang
paste_label <- function(line, label, side = "right", margin = 2) {
    if (side == "right") {
        end   <- nchar(line) - margin
        start <- end - (nchar(label) - 1)
    } else {
        start <- 1 + margin
        end   <- start + (nchar(label) - 1)
    }
    substr(line, start, end) <- label
    return(line)
}

#' format time
#' 
#' @param x seconds
#' 
#' @keywords internal
#' @author Lilin Yin
format_time <- function(x) {
    h <- x %/% 3600
    m <- (x %% 3600) %/% 60
    s <- ((x %% 3600) %% 60)
    index <- which(c(h, m, s) != 0)
    num <- c(h, m, s)[index]
    num <- round(num, 0)
    char <- c("h", "m", "s")[index]
    return(paste0(num, char, collapse = ""))
}