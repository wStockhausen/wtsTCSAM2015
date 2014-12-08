/* 
 * File:   ModelConstants.hpp
 * Author: william.stockhausen
 *
 * Created on March 12, 2013, 7:12 AM
 * 
 * History:
 * 20140605: added tcsam::dgbAll, dbgPriors
 * 20140918: renamed string constants of form "name_STR" to follow format "STR_name"
 * 20140930: switched MALE, FEMALE so MALE=1, FEMALE=2
 * 20141030: switched ANY to ALL
 */

#pragma once
#ifndef MODELCONSTANTS_HPP
    #define	MODELCONSTANTS_HPP
   
class rpt{
    public:
        /* Global output filestream */
        static std::ofstream echo;
};

class tcsamDims{
    public:
        static adstring getSXsForR(int mn,int mx);
        static adstring getMSsForR(int mn,int mx);
        static adstring getSCsForR(int mn,int mx);
};

namespace tcsam{    
    /* minimum debugging level that will print ALL debug info */
    const int dbgAll = 100;
    const int dbgPriors = 30;
    
    /* Model dimension name for sex */
    const adstring STR_SEX = "SEX";
    /* Model dimension name for maturity state */
    const adstring STR_MATURITY_STATE = "MATURITY_STATE";
    /* Model dimension name for shell condition */
    const adstring STR_SHELL_CONDITION = "SHELL_CONDITION";
    /* Model dimension name for size (bins) */
    const adstring STR_SIZE = "SIZE";
    /* Model dimension name for year */
    const adstring STR_YEAR = "YEAR";
    /* Model dimension name for fisheries */
    const adstring STR_FISHERY = "FISHERY";
    /* Model dimension name for surveys */
    const adstring STR_SURVEY = "SURVEY";
    /* Model flag name for selectivity functions */
    const adstring STR_SELFCN = "selFcn";
    
    //sexes
    const int nSXs      = 2;//number of model sexes
    const int MALE      = 1;//integer indicating sex=male
    const int FEMALE    = 2;//integer indicating sex=female
    const int ALL_SXs   = nSXs+1*(nSXs>1);//integer indicating all sexes combined
    const adstring STR_MALE    = "MALE";   //string indicating male
    const adstring STR_FEMALE  = "FEMALE"; //string indicating female
    const adstring STR_ALL_SXs = "ALL_SEX";//string indicating all sexes combined
//    extern adstring_array STR_SXs(1,nSXs);  //string array
    
    //maturity states
    const int nMSs     = 2; //number of model maturity states
    const int IMMATURE = 1; //integer indicating immature
    const int MATURE   = 2; //integer indicating mature
    const int ALL_MSs = nMSs+1*(nMSs>1); //integer indicating all maturity states combined
    const adstring STR_IMMATURE = "IMMATURE";//string indicating immature
    const adstring STR_MATURE   = "MATURE";  //string indicating mature
    const adstring STR_ALL_MSs  = "ALL_MATURITY"; //string indicating all maturity states combined
//    const adstring_array STR_MSs(1,nMSs);  //string array
        
    //shell conditions
    const int nSCs = 2;     //number of model shell conditions
    const int NEW_SHELL = 1;//integer indicating new shell condition
    const int OLD_SHELL = 2;//integer indicating old shell condition
    const int ALL_SCs = nSCs+1*(nSCs>1);//integer indicating all shell conditions combined
    const adstring STR_NEW_SHELL = "NEW_SHELL"; //string indicating new shell condition
    const adstring STR_OLD_SHELL = "OLD_SHELL"; //string indicating old shell condition
    const adstring STR_ALL_SCs   = "ALL_SHELL"; //string indicating all shell conditions combined
//    const adstring_array STR_SCs(1,nSCs);  //string array
    
    //objective function fitting option types
    const adstring STR_FIT_NONE   = "NONE";
    const adstring STR_FIT_BY_TOT = "BY_TOTAL";
    const adstring STR_FIT_BY_X   = "BY_SEX";
    const adstring STR_FIT_BY_XE  = "BY_SEX_EXTENDED";
    const adstring STR_FIT_BY_XM  = "BY_SEX_MATURITY";
    const adstring STR_FIT_BY_XME = "BY_SEX_MATURITY_EXTENDED";
    const adstring STR_FIT_BY_XS  = "BY_SEX_SHELL_CONDITON";
    const adstring STR_FIT_BY_XMS = "BY_SEX_MATURITY_SHELL_CONDITON";
    const int FIT_NONE   = 0;
    const int FIT_BY_TOT = 1;
    const int FIT_BY_X   = 2;
    const int FIT_BY_XE  = 3;
    const int FIT_BY_XM  = 4;
    const int FIT_BY_XME = 5;
    const int FIT_BY_XS  = 5;
    const int FIT_BY_XMS = 5;
    
    //likelihood types
    const adstring STR_LL_NONE        = "NONE";
    const adstring STR_LL_NORM2       = "NORM2";
    const adstring STR_LL_NORMAL      = "NORMAL";
    const adstring STR_LL_LOGNORMAL   = "LOGNORMAL";
    const adstring STR_LL_MULTINOMIAL = "MULTINOMIAL";
    const int LL_NONE        = 0;
    const int LL_NORM2       = 1;
    const int LL_NORMAL      = 2;
    const int LL_LOGNORMAL   = 3;
    const int LL_MULTINOMIAL = 4;
    
    //Stock-recruit function types
    const adstring STR_CONSTANT = "CONSTANT";
    const adstring STR_BEVHOLT  = "BEVHOLT";
    const adstring STR_RICKER   = "RICKER";
    const int SRTYPE_CONSTANT = 1;//integer indicating a constant recruitment SRR
    const int SRTYPE_BEVHOLT  = 2;//integer indicating a Beverton-Holt SRR
    const int SRTYPE_RICKER   = 3;//integer indicating a Ricker SRR
    
    const adstring STR_VAR = "VARIANCE";
    const adstring STR_STD = "STD_DEV";
    const adstring STR_CV  = "CV";
    const int SCLTYPE_VAR = 0;//integer indicating variances are given
    const int SCLTYPE_STD = 1;//integer indicating std devs are given
    const int SCLTYPE_CV  = 2;//integer indicating cv's are given
    
    //units
    const adstring UNITS_ONES      = "ONES";//"ONES"
    const adstring UNITS_THOUSANDS = "THOUSANDS";//"THOUSANDS"
    const adstring UNITS_MILLIONS  = "MILLIONS";//"MILLIONS"
    const adstring UNITS_BILLIONS  = "BILLIONS";//"BILLIONS"
    const adstring UNITS_GM        = "GM";//"GM"
    const adstring UNITS_KG        = "KG";//"KG"
    const adstring UNITS_MT        = "MT";//"MT"
    const adstring UNITS_KMT       = "THOUSANDS_MT";//"THOUSANDS_MT"
    const adstring UNITS_LBS       = "LBS";//"LBS"
    const adstring UNITS_MLBS      = "MILLIONS_LBS";//"MILLIONS_LBS"
    //unit conversions
    const double CONV_KGtoLBS = 2.20462262; //multiplier conversion from kg to lbs
    
    int getMaturityType(adstring s);
    adstring getMaturityType(int i);

    int getSexType(adstring s);
    adstring getSexType(int i);

    int getShellType(adstring s);
    adstring getShellType(int i);

    //Stock-recruit function types
    int getSRType(adstring s);
    adstring getSRType(int i);

    int getScaleType(adstring sclType);
    adstring getScaleType(int sclFlg);
    
    /**
     * Translate from adstring fit type to int version.
     * @param fitType
     * @return 
     */
    int getFitType(adstring fitType);
    /**
     * Translate from integer fit type to adstring version.
     * @param i
     * @return 
     */
    adstring getFitType(int i);

    double convertToStdDev(double sclVal, double mnVal, int sclFlg);
    dvector convertToStdDev(dvector sclVal, dvector mnVal, int sclFlg);
    
    /**
     * Gets multiplicative conversion factor from "from" units to "to" units. 
     * @param from - adstring UNITS_ keyword
     * @param to   - adstring UNITS_ keyword
     * @return - multiplicative factor: to_units  = factor*from_units
     */
    double getConversionMultiplier(adstring from,adstring to);
        
    /**
     * Translate from adstring likelihood type to int version.
     * @param fitType
     * @return 
     */
    int getLikelihoodType(adstring fitType);
    /**
     * Translate from integer likelihood type to adstring version.
     * @param i
     * @return 
     */
    adstring getLikelihoodType(int i);
}


#endif	/* MODELCONSTANTS_HPP */

