// Generated by using Rcpp::compileAttributes() -> do not edit by hand
// Generator token: 10BE3573-1514-4C36-9D1C-5A225CD40393

#include <Rcpp.h>

using namespace Rcpp;

// vcf_parser_map
List vcf_parser_map(std::string vcf_file, std::string out);
RcppExport SEXP _MVP_vcf_parser_map(SEXP vcf_fileSEXP, SEXP outSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< std::string >::type vcf_file(vcf_fileSEXP);
    Rcpp::traits::input_parameter< std::string >::type out(outSEXP);
    rcpp_result_gen = Rcpp::wrap(vcf_parser_map(vcf_file, out));
    return rcpp_result_gen;
END_RCPP
}
// vcf_parser_genotype
void vcf_parser_genotype(std::string vcf_file, SEXP pBigMat, int threads, bool show_progress);
RcppExport SEXP _MVP_vcf_parser_genotype(SEXP vcf_fileSEXP, SEXP pBigMatSEXP, SEXP threadsSEXP, SEXP show_progressSEXP) {
BEGIN_RCPP
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< std::string >::type vcf_file(vcf_fileSEXP);
    Rcpp::traits::input_parameter< SEXP >::type pBigMat(pBigMatSEXP);
    Rcpp::traits::input_parameter< int >::type threads(threadsSEXP);
    Rcpp::traits::input_parameter< bool >::type show_progress(show_progressSEXP);
    vcf_parser_genotype(vcf_file, pBigMat, threads, show_progress);
    return R_NilValue;
END_RCPP
}
// hapmap_parser_map
List hapmap_parser_map(Rcpp::StringVector hmp_file, std::string out);
RcppExport SEXP _MVP_hapmap_parser_map(SEXP hmp_fileSEXP, SEXP outSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< Rcpp::StringVector >::type hmp_file(hmp_fileSEXP);
    Rcpp::traits::input_parameter< std::string >::type out(outSEXP);
    rcpp_result_gen = Rcpp::wrap(hapmap_parser_map(hmp_file, out));
    return rcpp_result_gen;
END_RCPP
}
// hapmap_parser_genotype
void hapmap_parser_genotype(std::string hmp_file, SEXP pBigMat, bool show_progress);
RcppExport SEXP _MVP_hapmap_parser_genotype(SEXP hmp_fileSEXP, SEXP pBigMatSEXP, SEXP show_progressSEXP) {
BEGIN_RCPP
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< std::string >::type hmp_file(hmp_fileSEXP);
    Rcpp::traits::input_parameter< SEXP >::type pBigMat(pBigMatSEXP);
    Rcpp::traits::input_parameter< bool >::type show_progress(show_progressSEXP);
    hapmap_parser_genotype(hmp_file, pBigMat, show_progress);
    return R_NilValue;
END_RCPP
}
// numeric_scan
List numeric_scan(std::string num_file);
RcppExport SEXP _MVP_numeric_scan(SEXP num_fileSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< std::string >::type num_file(num_fileSEXP);
    rcpp_result_gen = Rcpp::wrap(numeric_scan(num_file));
    return rcpp_result_gen;
END_RCPP
}
// write_bfile
void write_bfile(SEXP pBigMat, std::string bed_file, int threads, bool verbose);
RcppExport SEXP _MVP_write_bfile(SEXP pBigMatSEXP, SEXP bed_fileSEXP, SEXP threadsSEXP, SEXP verboseSEXP) {
BEGIN_RCPP
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type pBigMat(pBigMatSEXP);
    Rcpp::traits::input_parameter< std::string >::type bed_file(bed_fileSEXP);
    Rcpp::traits::input_parameter< int >::type threads(threadsSEXP);
    Rcpp::traits::input_parameter< bool >::type verbose(verboseSEXP);
    write_bfile(pBigMat, bed_file, threads, verbose);
    return R_NilValue;
END_RCPP
}
// read_bfile
void read_bfile(std::string bed_file, SEXP pBigMat, long maxLine, int threads, bool verbose);
RcppExport SEXP _MVP_read_bfile(SEXP bed_fileSEXP, SEXP pBigMatSEXP, SEXP maxLineSEXP, SEXP threadsSEXP, SEXP verboseSEXP) {
BEGIN_RCPP
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< std::string >::type bed_file(bed_fileSEXP);
    Rcpp::traits::input_parameter< SEXP >::type pBigMat(pBigMatSEXP);
    Rcpp::traits::input_parameter< long >::type maxLine(maxLineSEXP);
    Rcpp::traits::input_parameter< int >::type threads(threadsSEXP);
    Rcpp::traits::input_parameter< bool >::type verbose(verboseSEXP);
    read_bfile(bed_file, pBigMat, maxLine, threads, verbose);
    return R_NilValue;
END_RCPP
}

static const R_CallMethodDef CallEntries[] = {
    {"_MVP_vcf_parser_map", (DL_FUNC) &_MVP_vcf_parser_map, 2},
    {"_MVP_vcf_parser_genotype", (DL_FUNC) &_MVP_vcf_parser_genotype, 4},
    {"_MVP_hapmap_parser_map", (DL_FUNC) &_MVP_hapmap_parser_map, 2},
    {"_MVP_hapmap_parser_genotype", (DL_FUNC) &_MVP_hapmap_parser_genotype, 3},
    {"_MVP_numeric_scan", (DL_FUNC) &_MVP_numeric_scan, 1},
    {"_MVP_write_bfile", (DL_FUNC) &_MVP_write_bfile, 4},
    {"_MVP_read_bfile", (DL_FUNC) &_MVP_read_bfile, 5},
    {NULL, NULL, 0}
};

RcppExport void R_init_MVP(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
