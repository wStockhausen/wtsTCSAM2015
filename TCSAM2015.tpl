//TCSAM2015: Bering Sea Tanner crab model
//
// Author: William Stockhausen (william.stockhausen@noaa.gov)
//
// Model units (unless otherwise noted):
//  Individual crab weights are in KG (kilograms).
//  Abundance (numbers) is in MILLIONS (10^6's) of crabs.
//  Biomass (weight) is in 1000's MT (metric tons).
//
//  mxYr denotes the final fishery year (July, mxYr->June, mxYr+1) prior to the assessment.
//  Typically, the final survey is conducted July, mxYr+1.
//  The assessment is conducted for mxYr+1. 
//  Final population abundance is estimated for July 1, mxYr+1.
//
// History:
//  2014-02-11: created
//  2014-05-23: renamed TCSAM2015
//  2014-06-05: 1. moved setDevs() to ) to tcsam::setDevs() in ModelParameterFunctions.hpp/cpp
//              2. moved calcPriors(...) to tcsam::calcPriors(...) in ModelParameterFunctions.hpp/cpp
//  2014-06-09: started review to make sure deep copies are implemented for objects that 
//              should not be modified within a computational unit.
//  2014-06-11: 1. created setFinalVal(...), setFinalVals(...) functionality for ModelParameterInfoTypes
//                 and revised writeToR(...) for parameters to output both initial and final values.
//  2014-06-16: 1. Added sdrLnR_y, sdrSpB_xy, sdrFinlPop_xmsz and MCMC calc.s
//  2014-09-30: 1. Changed to MALE=1, FEMALE=2 ordering of sexes
//              2. Added constant "BioData->recLag" for recruitment lag (set in BioData file)
//  2014-10-30: 1. Corrected sex, maturity, and shell condition dimensioning and loops 
//                  to be independent of ordering of MALE/FEMALE, NEW/OLD_SHELL, and IMMATURE/MATURE
//                  values.
//              2. Added logic to avoid FEMALE-specific logic if model includes only MALEs.
//              3. Updated to use tcsam::ALL_SXs, tcsam::ALL_SCs, tcsam::ALL_MSs
//  2014-11-18: 1. Corrected output of simulated data for retrospective model runs
//              2. Added "-doRetro iRetro" command line option to facilitate retrospective model runs
//              3. Corrected IndexRange behavior for retrospective runs
//              4. MAKE SURE max IndexRanges for TRAWL SURVEYS are set to "-2" (max year index=mxYr+1) 
//                  for correct behavior in retrospective runs
//  2014-11-21: 1. Added ability to simulate data and fit it within a single model run.
//              2. Added "fitSimData" command line option to invoke 1.
//  2014-11-24: 1. Added option to add stochasticity to simulated data fit within the model.
//              2. Added R output for objective function components
//  2014-12-02: 1. Enabled switch to use pin file
//              2. Added 'seed' as input flag to change rng seed (iSeed) for jittering/resampling
//              3. Enabled jitter functionality by modifying setInitVals(...) functions
//  2014-12-08: 1. Added several parameterizations for logistic, double logistic selectivity functions.
//              2. Changed IndexRange to interpret a single input value as a max, not min, index.
//              3. Modified calcNLLs_CatchNatZ to handle more fitting options and not return a value.
//              4. Modified calcMultinomialNLL to write obs, mod values to R list.
//              5. Changed input format for BioData to read in "typical" and "atypical" values
//                  for fishing season midpoint and mating time (the latter by year).
//              6. Changed input format for AggregateCatchData to "long format" from "wide format"
//                  so data is input by sex, maturity, shell_condition factor combinations with rows having
//                      year, value, cv
//  2014-12-22: 1. Finished 6. from above.
//              2. Modified other calcNLLs to write obs, mod, std values to R list.
//              3. Upped version to 01.02 to reflect format changes.
//  2015-02-18: 1. Changed NLL calculations for normal, lognormal error structures
//                  to depend only on the zscores (so they don't include the log(sigma) terms)
//                  so that NLLs are non-negative.
//              2. Added asclogistic50Ln95 selectivity function.
//              3. Implemented ability to read initial value vectors for VectorVector and DevsVector
//                  parameter info classes.
//              4. Revised BioData class and input data file to simplify input.
//              5. Revised aggregateData() and replaceCatchData() functions in AggregateCatchData class.
//              6. Added units_KMT to units_KMT conversion factor (=1) to getConversionFactor(...) functions
//              7. Incremented version to reflect changes.
//
// =============================================================================
// =============================================================================
GLOBALS_SECTION
    #include <math.h>
    #include <time.h>
    #include <admodel.h>
    #include "TCSAM.hpp"
    
    adstring model  = "TCSAM2015";
    adstring modVer = "01.03"; 
    
    time_t start,finish;
    
    //model objects
    ModelConfiguration*  ptrMC; //ptr to model configuration object
    ModelParametersInfo* ptrMPI;//ptr to model parameters info object
    ModelOptions*        ptrMOs;//ptr to model options object
    ModelDatasets*       ptrMDS;//ptr to model datasets object
    ModelDatasets*       ptrSimMDS;//ptr to simulated model datasets object
    
    //file streams and filenames
    std::ofstream mcmc;        //stream for mcmc output
    
    //filenames
    adstring fnMCMC = "TCSAM2015.MCMC.R";
    adstring fnConfigFile;//configuration file
    adstring fnResultFile;//results file name 
    adstring fnPin;       //pin file
    
    //runtime flags (0=false)
    int jitter     = 0;//use jittering for initial parameter values
    int resample   = 0;//use resampling for initial parameter values
    int opModMode  = 0;//run as operating model, no fitting
    int usePin     = 0;//flag to initialize parameter values using a pin file
    int doRetro    = 0;//flag to facilitate a retrospective model run
    int fitSimData = 0;//flag to fit model to simulated data calculated in the PRELIMINARY_CALCs section
    
    int yRetro = 0; //number of years to decrement for retrospective model run
    int iSeed =  0;//default random number generator seed
    random_number_generator rng(-1);//random number generator
    int iSimDataSeed = 0;
    random_number_generator rngSimData(-1);//random number generator for data simulation
    

    //debug flags
    int debugModelConfig     = 0;
    int debugModelDatasets   = 0;
    int debugModelParamsInfo = 0;
    int debugModelParams     = 0;
    
    int debugDATA_SECTION    = 0;
    int debugPARAMS_SECTION  = 0;
    int debugPRELIM_CALCS    = 0;
    int debugPROC_SECTION    = 0;
    int debugREPORT_SECTION  = 0;
    
    int showActiveParams = 0;    
    int debugRunModel    = 0;    
    int debugObjFun      = 0;
    
    int debugMCMC = 0;
    
    int dbgCalcProcs = 10;
    int dbgObjFun = 20;
    int dbgPriors = tcsam::dbgPriors;
    int dbgPopDy  = 70;
    int dbgApply  = 80;
    int dbgDevs   = 90;
    int dbgAll    = tcsam::dbgAll;
    
    int nSXs    = tcsam::nSXs;
    int MALE    = tcsam::MALE;
    int FEMALE  = tcsam::FEMALE;
    int ALL_SXs = tcsam::ALL_SXs;
    
    int nMSs     = tcsam::nMSs;
    int IMMATURE = tcsam::IMMATURE;
    int MATURE   = tcsam::MATURE;
    int ALL_MSs  = tcsam::ALL_MSs;
    
    int nSCs      = tcsam::nSCs;
    int NEW_SHELL = tcsam::NEW_SHELL;
    int OLD_SHELL = tcsam::OLD_SHELL;
    int ALL_SCs   = tcsam::ALL_SCs;
    
    double smlVal = 0.00001;//small value to keep things > 0
    
// =============================================================================
// =============================================================================
DATA_SECTION

 LOCAL_CALCS
    rpt::echo<<"#Starting "<<model<<" (ver "<<modVer<<") Code"<<endl;
    rpt::echo<<"#Starting DATA_SECTION"<<endl;
    cout<<"#Starting "<<model<<" (ver "<<modVer<<") Code"<<endl;
    cout<<"#Starting DATA_SECTION"<<endl;
 END_CALCS

 //Set commandline options
 LOCAL_CALCS
    int on = 0;
    int flg = 0;
    rpt::echo<<"#------Reading command line options---------"<<endl;
    //configFile
    fnConfigFile = "TCSAM2015_ModelConfig.dat";//default model config filename
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-configFile"))>-1) {
        fnConfigFile = ad_comm::argv[on+1];
        rpt::echo<<"#config file changed to '"<<fnConfigFile<<"'"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg=1;
    }
    //resultsFile
    fnResultFile = "TCSAM2015_ResultFile";//default results file name
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-resultsFile"))>-1) {
        fnResultFile = ad_comm::argv[on+1];
        rpt::echo<<"#results file changed to '"<<fnResultFile<<"'"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg=1;
    }
    //parameter input file
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-pin"))>-1) {
        usePin = 1;
        fnPin = ad_comm::argv[on+1];
        rpt::echo<<"#Initial parameter values from pin file: "<<fnPin<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
    }
    //parameter input file
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-binp"))>-1) {
        usePin = 1;
        fnPin = ad_comm::argv[on+1];
        rpt::echo<<"#Initial parameter values from pin file: "<<fnPin<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
    }
    //parameter input file
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-ainp"))>-1) {
        usePin = 1;
        fnPin = ad_comm::argv[on+1];
        rpt::echo<<"#Initial parameter values from pin file: "<<fnPin<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
    }
    //opModMode
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-opModMode"))>-1) {
        opModMode=1;
        rpt::echo<<"#operating model mode turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debugModelConfig
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-debugModelConfig"))>-1) {
        debugModelConfig=1;
        rpt::echo<<"#debugModelConfig turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debugModelDatasets
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-debugModelDatasets"))>-1) {
        debugModelDatasets=1;
        rpt::echo<<"#debugModelDatasets turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debugModelParamsInfo
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-debugModelParamsInfo"))>-1) {
        debugModelParamsInfo=1;
        rpt::echo<<"#debugModelParamsInfo turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //doRetro
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-doRetro"))>-1) {
        doRetro=1;
        cout<<"#doRetro turned ON"<<endl;
        rpt::echo<<"#doRetro turned ON"<<endl;
        if (on+1<argc) {
            yRetro=atoi(ad_comm::argv[on+1]);
            cout<<"#Retrospective model run using yRetro = "<<yRetro<<endl;
            rpt::echo<<"#Retrospective model run using yRetro = "<<yRetro<<endl;
        }
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //fitSimData
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-fitSimData"))>-1) {
        fitSimData=1;
        if (on+1<argc) {
            iSimDataSeed=atoi(ad_comm::argv[on+1]);
        } else {
            cout<<"-------------------------------------------"<<endl;
            cout<<"Enter random number seed (0 -> deterministic) for data simulation: ";
            cin>>iSimDataSeed;
        }
        if (iSimDataSeed) rng.reinitialize(iSimDataSeed);
        rpt::echo<<"#Simulating data to fit using "<<iSimDataSeed<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //seed
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-seed"))>-1) {
        if (on+1<argc) {
            iSeed=atoi(ad_comm::argv[on+1]);
        } else {
            cout<<"-------------------------------------------"<<endl;
            cout<<"Enter random number seed for jittering/resampling: ";
            cin>>iSeed;
        }
        rng.reinitialize(iSeed);
        rpt::echo<<"#Random number seed set to "<<iSeed<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //jitter
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-jitter"))>-1) {
        jitter=1;
        rpt::echo<<"#Jittering for initial parameter values turned ON "<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //resample
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-resample"))>-1) {
        resample=1;
        rpt::echo<<"#Resampling for initial parameter values turned ON "<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debugModelConfig
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-debugModelConfig"))>-1) {
        debugModelConfig=1;
        rpt::echo<<"#debugModelConfig turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debugModelParams
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-debugModelParams"))>-1) {
        debugModelParams=1;
        cout<<"#debugModelParams turned ON"<<endl;
        rpt::echo<<"#debugModelParams turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debugDATA_SECTION
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-debugDATA_SECTION"))>-1) {
        debugDATA_SECTION=1;
        rpt::echo<<"#debugDATA_SECTION turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debugPARAMS_SECTION
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-debugPARAMS_SECTION"))>-1) {
        debugPARAMS_SECTION=1;
        rpt::echo<<"#debugPARAMS_SECTION turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debugPRELIM_CALCS
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-debugPRELIM_CALCS"))>-1) {
        debugPRELIM_CALCS=1;
        rpt::echo<<"debugPRELIM_CALCS turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debugPROC_SECTION
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-debugPROC_SECTION"))>-1) {
        debugPROC_SECTION=1;
        rpt::echo<<"#debugPROC_SECTION turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debugREPORT_SECTION
    if ((on=option_match(ad_comm::argc,ad_comm::argv,"-debugREPORT_SECTION"))>-1) {
        debugREPORT_SECTION=1;
        rpt::echo<<"#debugREPORT_SECTION turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debugRunModel
    if (option_match(ad_comm::argc,ad_comm::argv,"-debugRunModel")>-1) {
        debugRunModel=1;
        rpt::echo<<"#debugRunModel turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debugObjFun
    if (option_match(ad_comm::argc,ad_comm::argv,"-debugObjFun")>-1) {
        debugObjFun=1;
        rpt::echo<<"#debugObjFun turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //showActiveParams
    if (option_match(ad_comm::argc,ad_comm::argv,"-showActiveParams")>-1) {
        showActiveParams=1;
        rpt::echo<<"#showActiveParams turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
    //debuMCMC
    if (option_match(ad_comm::argc,ad_comm::argv,"-debugMCMC")>-1) {
        debugMCMC=1;
        rpt::echo<<"#debugMCMC turned ON"<<endl;
        rpt::echo<<"#-------------------------------------------"<<endl;
        flg = 1;
    }
 END_CALCS
 
    int nZBs;  //number of model size bins
    int mnYr;  //min model year
    int mxYr;  //max model year
    int mxYrp1;//max model year + 1
    int nSel;  //number of selectivity functions
    int nFsh;  //number of fisheries
    int nSrv;  //number of surveys
 LOCAL_CALCS
    rpt::echo<<"#-----------------------------------"<<endl;
    rpt::echo<<"#-----------------------------------"<<endl;
    rpt::echo<<"#Reading configuration file '"<<fnConfigFile<<"'"<<endl;
    ad_comm::change_datafile_name(fnConfigFile);
    ptrMC = new ModelConfiguration();
    ptrMC->read(*(ad_comm::global_datafile));
    
    mnYr   = ptrMC->mnYr;
    mxYr   = ptrMC->mxYr;
    if (doRetro){mxYr = mxYr-yRetro; ptrMC->setMaxModelYear(mxYr);}
    if (jitter)   {ptrMC->jitter=1;}
    if (resample) {ptrMC->resample = 1;}
    
    rpt::echo<<"#------------------ModelConfiguration-----------------"<<endl;
    rpt::echo<<(*ptrMC);
    rpt::echo<<"#-----------------------------------"<<endl;
    rpt::echo<<"#----finished model configuration---"<<endl;
    rpt::echo<<"#-----------------------------------"<<endl;
    if (debugDATA_SECTION){
        cout<<"#------------------ModelConfiguration-----------------"<<endl;
        cout<<(*ptrMC);
        cout<<"#-----------------------------------"<<endl;
        cout<<"#----finished model configuration---"<<endl;
        cout<<"#-----------------------------------"<<endl;
        cout<<"enter 1 to continue : ";
        cin>>debugDATA_SECTION;
        if (debugDATA_SECTION<0) exit(1);
    }
    
    mxYrp1 = mxYr+1;
    nFsh   = ptrMC->nFsh;
    nSrv   = ptrMC->nSrv;
    nZBs   = ptrMC->nZBs;
 END_CALCS   
    vector zBs(1,nZBs)
    !!zBs  = ptrMC->zMidPts;
    
    //read model parameters info
 LOCAL_CALCS
    rpt::echo<<"#-----------------------------------"<<endl;
    rpt::echo<<"#Reading parameters info file '"<<ptrMC->fnMPI<<"'"<<endl;
    if (debugModelParamsInfo) ModelParametersInfo::debug=1;
    ptrMPI = new ModelParametersInfo(*ptrMC);
    ad_comm::change_datafile_name(ptrMC->fnMPI);
    ptrMPI->read(*(ad_comm::global_datafile));
    if (debugModelParamsInfo) {
        cout<<"enter 1 to continue : ";
        cin>>debugModelParamsInfo;
        if (debugModelParamsInfo<0) exit(1);
        ModelParametersInfo::debug=debugModelParamsInfo;
    }
    rpt::echo<<"#----finished model parameters info---"<<endl;
    if (debugDATA_SECTION){
        cout<<"#------------------ModelParametersInfo-----------------"<<endl;
        cout<<(*ptrMPI);
        cout<<"#----finished model parameters info---"<<endl;
        cout<<"enter 1 to continue : ";
        cin>>debugDATA_SECTION;
        if (debugDATA_SECTION<0) exit(1);
    }
 END_CALCS
        
    //read model data
 LOCAL_CALCS
    rpt::echo<<"#-----------------------------------"<<endl;
    rpt::echo<<"#Reading datasets file '"<<ptrMC->fnMDS<<"'"<<endl;
    if (debugModelDatasets) {
        BioData::debug=1;
        FisheryData::debug=1;
        SurveyData::debug=1;
    }
    ptrMDS = new ModelDatasets(ptrMC);
    ad_comm::change_datafile_name(ptrMC->fnMDS);
    ptrMDS->read(*(ad_comm::global_datafile));
    if (debugModelDatasets) {
        cout<<"enter 1 to continue : ";
        cin>>debugModelDatasets;
        if (debugModelDatasets<0) exit(1);
        ModelDatasets::debug=debugModelDatasets;
        BioData::debug=debugModelDatasets;
        SurveyData::debug=debugModelDatasets;
    }
    rpt::echo<<"#----finished model datasets---"<<endl;
    if (debugDATA_SECTION){
        cout<<"#------------------ModelDatasets-----------------"<<endl;
        cout<<(*ptrMDS);
        cout<<"#----finished model datasets---"<<endl;
        cout<<"enter 1 to continue : ";
        cin>>debugDATA_SECTION;
        if (debugDATA_SECTION<0) exit(1);
    }
 END_CALCS
    
    //read model data again to create SimMDS object
 LOCAL_CALCS
    rpt::echo<<"#-----------------------------------"<<endl;
    rpt::echo<<"#Reading datasets file again to create SimMDS object '"<<ptrMC->fnMDS<<"'"<<endl;
    ptrSimMDS = new ModelDatasets(ptrMC);
    ad_comm::change_datafile_name(ptrMC->fnMDS);
    ptrSimMDS->read(*(ad_comm::global_datafile));
    rpt::echo<<"---SimMDS object after reading datasets---"<<endl;
    rpt::echo<<(*ptrSimMDS);
    rpt::echo<<"#finished SimMDS object"<<endl;
 END_CALCS   
    
    //read model options
 LOCAL_CALCS
    rpt::echo<<"#-----------------------------------"<<endl;
    rpt::echo<<"#Reading model options file '"<<ptrMC->fnMOs<<"'"<<endl;
    if (debugModelParamsInfo) ModelOptions::debug=1;
    ptrMOs = new ModelOptions(*ptrMC);
    ad_comm::change_datafile_name(ptrMC->fnMOs);
    ptrMOs->read(*(ad_comm::global_datafile));
    if (debugModelParamsInfo) {
        cout<<"enter 1 to continue : ";
        cin>>debugModelParamsInfo;
        if (debugModelParamsInfo<0) exit(1);
        ModelOptions::debug=debugModelParamsInfo;
    }
//    rpt::echo<<"#------------------ModelOptions-----------------"<<endl;
//    rpt::echo<<(*ptrMOs);
    rpt::echo<<"#----finished model options---"<<endl;
    if (debugDATA_SECTION){
        cout<<"#------------------ModelOptions-----------------"<<endl;
        cout<<(*ptrMOs);
        cout<<"#----finished model options---"<<endl;
        cout<<"enter 1 to continue : ";
        cin>>debugDATA_SECTION;
        if (debugDATA_SECTION<0) exit(1);
    }
 END_CALCS
        
    //Match up model fisheries with fisheries data
    ivector mapD2MFsh(1,nFsh);
    ivector mapM2DFsh(1,nFsh);
 LOCAL_CALCS
    {
     int idx;
     for (int f=1;f<=nFsh;f++){
         idx = wts::which(ptrMDS->ppFsh[f-1]->name,ptrMC->lblsFsh);
         mapD2MFsh(f)   = idx;//map from fishery data object f to model fishery idx
         mapM2DFsh(idx) = f;  //map from model fishery idx to fishery data object f
     }
     rpt::echo<<"model fisheries map to fishery data objects: "<<mapM2DFsh<<endl;
     cout<<"model fisheries map to fishery data objects: "<<mapM2DFsh<<endl;
    }
 END_CALCS
        
    //Match up model surveys with surveys data
    ivector mapD2MSrv(1,nSrv);
    ivector mapM2DSrv(1,nSrv);
 LOCAL_CALCS
    {
     int idx;
     for (int v=1;v<=nSrv;v++){
         idx = wts::which(ptrMDS->ppSrv[v-1]->name,ptrMC->lblsSrv);
         mapD2MSrv(v)   = idx;//map from survey data object v to model survey idx
         mapM2DSrv(idx) = v;  //map from model survey idx to survey data object v
     }
     rpt::echo<<"model surveys map to survey data objects: "<<mapM2DSrv<<endl;
     cout<<"model surveys map to survey data objects: "<<mapM2DSrv<<endl;
    }
 END_CALCS
 
    //Extract parameter information
    //recruitment parameters
    int npLnR; ivector phsLnR; vector lbLnR; vector ubLnR;
    !!tcsam::setParameterInfo(ptrMPI->ptrRec->pLnR,npLnR,lbLnR,ubLnR,phsLnR,rpt::echo);
    
    int npLnRCV; ivector phsLnRCV; vector lbLnRCV; vector ubLnRCV;
    !!tcsam::setParameterInfo(ptrMPI->ptrRec->pLnRCV,npLnRCV,lbLnRCV,ubLnRCV,phsLnRCV,rpt::echo);
    
    int npLgtRX; ivector phsLgtRX; vector lbLgtRX; vector ubLgtRX;
    !!tcsam::setParameterInfo(ptrMPI->ptrRec->pLgtRX,npLgtRX,lbLgtRX,ubLgtRX,phsLgtRX,rpt::echo);
    
    int npLnRa; ivector phsLnRa; vector lbLnRa; vector ubLnRa;
    !!tcsam::setParameterInfo(ptrMPI->ptrRec->pLnRa,npLnRa,lbLnRa,ubLnRa,phsLnRa,rpt::echo);
    
    int npLnRb; ivector phsLnRb; vector lbLnRb; vector ubLnRb;
    !!tcsam::setParameterInfo(ptrMPI->ptrRec->pLnRb,npLnRb,lbLnRb,ubLnRb,phsLnRb,rpt::echo);
    
    int npDevsLnR; ivector mniDevsLnR; ivector mxiDevsLnR; imatrix idxsDevsLnR;
    vector lbDevsLnR; vector ubDevsLnR; ivector phsDevsLnR;
    !!tcsam::setParameterInfo(ptrMPI->ptrRec->pDevsLnR,npDevsLnR,mniDevsLnR,mxiDevsLnR,idxsDevsLnR,lbDevsLnR,ubDevsLnR,phsDevsLnR,rpt::echo);
    
    //natural mortality parameters
    int npLnM; ivector phsLnM; vector lbLnM; vector ubLnM;
    !!tcsam::setParameterInfo(ptrMPI->ptrNM->pLnM,npLnM,lbLnM,ubLnM,phsLnM,rpt::echo);
    
    int npLnDMT; ivector phsLnDMT; vector lbLnDMT; vector ubLnDMT;
    !!tcsam::setParameterInfo(ptrMPI->ptrNM->pLnDMT,npLnDMT,lbLnDMT,ubLnDMT,phsLnDMT,rpt::echo);
    
    int npLnDMX; ivector phsLnDMX; vector lbLnDMX; vector ubLnDMX;
    !!tcsam::setParameterInfo(ptrMPI->ptrNM->pLnDMX,npLnDMX,lbLnDMX,ubLnDMX,phsLnDMX,rpt::echo);
    
    int npLnDMM; ivector phsLnDMM; vector lbLnDMM; vector ubLnDMM;
    !!tcsam::setParameterInfo(ptrMPI->ptrNM->pLnDMM,npLnDMM,lbLnDMM,ubLnDMM,phsLnDMM,rpt::echo);
    
    int npLnDMXM; ivector phsLnDMXM; vector lbLnDMXM; vector ubLnDMXM;
    !!tcsam::setParameterInfo(ptrMPI->ptrNM->pLnDMXM,npLnDMXM,lbLnDMXM,ubLnDMXM,phsLnDMXM,rpt::echo);
    
    number zMref;
    !!zMref = ptrMPI->ptrNM->zRef;
    
    //maturity parameters
    int npLgtPrMat; ivector mniLgtPrMat; ivector mxiLgtPrMat; imatrix idxsLgtPrMat;
    vector lbLgtPrMat; vector ubLgtPrMat; ivector phsLgtPrMat;
    !!tcsam::setParameterInfo(ptrMPI->ptrMat->pLgtPrMat,npLgtPrMat,mniLgtPrMat,mxiLgtPrMat,idxsLgtPrMat,lbLgtPrMat,ubLgtPrMat,phsLgtPrMat,rpt::echo);
 
    //growth parameters
    int npLnGrA; ivector phsLnGrA; vector lbLnGrA; vector ubLnGrA;
    !!tcsam::setParameterInfo(ptrMPI->ptrGr->pLnGrA,npLnGrA,lbLnGrA,ubLnGrA,phsLnGrA,rpt::echo);
    
    int npLnGrB; ivector phsLnGrB; vector lbLnGrB; vector ubLnGrB;
    !!tcsam::setParameterInfo(ptrMPI->ptrGr->pLnGrB,npLnGrB,lbLnGrB,ubLnGrB,phsLnGrB,rpt::echo);
    
    int npLnGrBeta; ivector phsLnGrBeta; vector lbLnGrBeta; vector ubLnGrBeta;
    !!tcsam::setParameterInfo(ptrMPI->ptrGr->pLnGrBeta,npLnGrBeta,lbLnGrBeta,ubLnGrBeta,phsLnGrBeta,rpt::echo);
    
    //selectivity parameters
    !!nSel = ptrMPI->ptrSel->nPCs;//number of selectivity functions defined
    int npS1; ivector phsS1; vector lbS1; vector ubS1;
    !!tcsam::setParameterInfo(ptrMPI->ptrSel->pS1,npS1,lbS1,ubS1,phsS1,rpt::echo);
    int npS2; ivector phsS2; vector lbS2; vector ubS2;
    !!tcsam::setParameterInfo(ptrMPI->ptrSel->pS2,npS2,lbS2,ubS2,phsS2,rpt::echo);
    int npS3; ivector phsS3; vector lbS3; vector ubS3;
    !!tcsam::setParameterInfo(ptrMPI->ptrSel->pS3,npS3,lbS3,ubS3,phsS3,rpt::echo);
    int npS4; ivector phsS4; vector lbS4; vector ubS4;
    !!tcsam::setParameterInfo(ptrMPI->ptrSel->pS4,npS4,lbS4,ubS4,phsS4,rpt::echo);
    int npS5; ivector phsS5; vector lbS5; vector ubS5;
    !!tcsam::setParameterInfo(ptrMPI->ptrSel->pS5,npS5,lbS5,ubS5,phsS5,rpt::echo);
    int npS6; ivector phsS6; vector lbS6; vector ubS6;
    !!tcsam::setParameterInfo(ptrMPI->ptrSel->pS6,npS6,lbS6,ubS6,phsS6,rpt::echo);
    
    int npDevsS1; ivector mniDevsS1; ivector mxiDevsS1;  imatrix idxsDevsS1;
    vector lbDevsS1; vector ubDevsS1; ivector phsDevsS1;
    !!tcsam::setParameterInfo(ptrMPI->ptrSel->pDevsS1,npDevsS1,mniDevsS1,mxiDevsS1,idxsDevsS1,lbDevsS1,ubDevsS1,phsDevsS1,rpt::echo);
    int npDevsS2; ivector mniDevsS2; ivector mxiDevsS2;  imatrix idxsDevsS2;
    vector lbDevsS2; vector ubDevsS2; ivector phsDevsS2;
    !!tcsam::setParameterInfo(ptrMPI->ptrSel->pDevsS2,npDevsS2,mniDevsS2,mxiDevsS2,idxsDevsS2,lbDevsS2,ubDevsS2,phsDevsS2,rpt::echo);
    int npDevsS3; ivector mniDevsS3; ivector mxiDevsS3;  imatrix idxsDevsS3;
    vector lbDevsS3; vector ubDevsS3; ivector phsDevsS3;
    !!tcsam::setParameterInfo(ptrMPI->ptrSel->pDevsS3,npDevsS3,mniDevsS3,mxiDevsS3,idxsDevsS3,lbDevsS3,ubDevsS3,phsDevsS3,rpt::echo);
    int npDevsS4; ivector mniDevsS4; ivector mxiDevsS4;  imatrix idxsDevsS4;
    vector lbDevsS4; vector ubDevsS4; ivector phsDevsS4;
    !!tcsam::setParameterInfo(ptrMPI->ptrSel->pDevsS4,npDevsS4,mniDevsS4,mxiDevsS4,idxsDevsS4,lbDevsS4,ubDevsS4,phsDevsS4,rpt::echo);
    int npDevsS5; ivector mniDevsS5; ivector mxiDevsS5;  imatrix idxsDevsS5;
    vector lbDevsS5; vector ubDevsS5; ivector phsDevsS5;
    !!tcsam::setParameterInfo(ptrMPI->ptrSel->pDevsS5,npDevsS5,mniDevsS5,mxiDevsS5,idxsDevsS5,lbDevsS5,ubDevsS5,phsDevsS5,rpt::echo);
    int npDevsS6; ivector mniDevsS6; ivector mxiDevsS6;  imatrix idxsDevsS6;
    vector lbDevsS6; vector ubDevsS6; ivector phsDevsS6;
    !!tcsam::setParameterInfo(ptrMPI->ptrSel->pDevsS6,npDevsS6,mniDevsS6,mxiDevsS6,idxsDevsS6,lbDevsS6,ubDevsS6,phsDevsS6,rpt::echo);
    
        
    //fisheries parameters
    int npHM; ivector phsHM; vector lbHM; vector ubHM;
    !!tcsam::setParameterInfo(ptrMPI->ptrFsh->pHM,npHM,lbHM,ubHM,phsHM,rpt::echo);
    
    int npLnC; ivector phsLnC; vector lbLnC; vector ubLnC;
    !!tcsam::setParameterInfo(ptrMPI->ptrFsh->pLnC,npLnC,lbLnC,ubLnC,phsLnC,rpt::echo);
    
    int npLnDCT; ivector phsLnDCT; vector lbLnDCT; vector ubLnDCT;
    !!tcsam::setParameterInfo(ptrMPI->ptrFsh->pLnDCT,npLnDCT,lbLnDCT,ubLnDCT,phsLnDCT,rpt::echo);
    
    int npLnDCX; ivector phsLnDCX; vector lbLnDCX; vector ubLnDCX;
    !!tcsam::setParameterInfo(ptrMPI->ptrFsh->pLnDCX,npLnDCX,lbLnDCX,ubLnDCX,phsLnDCX,rpt::echo);
    
    int npLnDCM; ivector phsLnDCM; vector lbLnDCM; vector ubLnDCM;
    !!tcsam::setParameterInfo(ptrMPI->ptrFsh->pLnDCM,npLnDCM,lbLnDCM,ubLnDCM,phsLnDCM,rpt::echo);
    
    int npLnDCXM; ivector phsLnDCXM; vector lbLnDCXM; vector ubLnDCXM;
    !!tcsam::setParameterInfo(ptrMPI->ptrFsh->pLnDCXM,npLnDCXM,lbLnDCXM,ubLnDCXM,phsLnDCXM,rpt::echo);
    
    int npDevsLnC; ivector mniDevsLnC; ivector mxiDevsLnC; imatrix idxsDevsLnC;
    vector lbDevsLnC; vector ubDevsLnC; ivector phsDevsLnC;
    !!tcsam::setParameterInfo(ptrMPI->ptrFsh->pDevsLnC,npDevsLnC,mniDevsLnC,mxiDevsLnC,idxsDevsLnC,lbDevsLnC,ubDevsLnC,phsDevsLnC,rpt::echo);
    
    //surveys parameters
    int npLnQ; ivector phsLnQ; vector lbLnQ; vector ubLnQ;
    !!tcsam::setParameterInfo(ptrMPI->ptrSrv->pLnQ,npLnQ,lbLnQ,ubLnQ,phsLnQ,rpt::echo);
    
    int npLnDQT; ivector phsLnDQT; vector lbLnDQT; vector ubLnDQT;
    !!tcsam::setParameterInfo(ptrMPI->ptrSrv->pLnDQT,npLnDQT,lbLnDQT,ubLnDQT,phsLnDQT,rpt::echo);
    
    int npLnDQX; ivector phsLnDQX; vector lbLnDQX; vector ubLnDQX;
    !!tcsam::setParameterInfo(ptrMPI->ptrSrv->pLnDQX,npLnDQX,lbLnDQX,ubLnDQX,phsLnDQX,rpt::echo);
    
    int npLnDQM; ivector phsLnDQM; vector lbLnDQM; vector ubLnDQM;
    !!tcsam::setParameterInfo(ptrMPI->ptrSrv->pLnDQM,npLnDQM,lbLnDQM,ubLnDQM,phsLnDQM,rpt::echo);
    
    int npLnDQXM; ivector phsLnDQXM; vector lbLnDQXM; vector ubLnDQXM;
    !!tcsam::setParameterInfo(ptrMPI->ptrSrv->pLnDQXM,npLnDQXM,lbLnDQXM,ubLnDQXM,phsLnDQXM,rpt::echo);

    //other data
    vector dtF(mnYr,mxYr);//timing of midpoint of fishing season (by year)
    !!dtF = ptrMDS->ptrBio->fshTiming_y(mnYr,mxYr);
    vector dtM(mnYr,mxYr);//timing of mating (by year))
    !!dtM = ptrMDS->ptrBio->fshTiming_y(mnYr,mxYr);

    ivector optsFcAvg(1,nFsh);//option flags for fishery capture rate averaging
    !!optsFcAvg = ptrMOs->optsFcAvg;
    vector avgEff(1,nFsh);//average effort over fishery-specific time period

    //number of parameter combinations for various processes
    int npcRec;
    !!npcRec = ptrMPI->ptrRec->nPCs;
    int npcNM;
    !!npcNM = ptrMPI->ptrNM->nPCs;
    int npcMat;
    !!npcMat = ptrMPI->ptrMat->nPCs;
    int npcGr;
    !!npcGr = ptrMPI->ptrGr->nPCs;
    int npcSel;
    !!npcSel = ptrMPI->ptrSel->nPCs;
    int npcFsh;
    !!npcFsh = ptrMPI->ptrFsh->nPCs;
    int npcSrv;
    !!npcSrv = ptrMPI->ptrSrv->nPCs;
    
    imatrix idxDevsLnC_fy(1,nFsh,mnYr,mxYr); //matrix to check devs indexing ffor lnC
 LOCAL_CALCS
    rpt::echo<<"#finished DATA_SECTION"<<endl;
    cout<<"#finished DATA_SECTION"<<endl;
//    exit(1);
 END_CALCS
// =============================================================================
// =============================================================================
INITIALIZATION_SECTION

// =============================================================================
// =============================================================================
PARAMETER_SECTION
    !!rpt::echo<<"#Starting PARAMETER_SECTION"<<endl;
    !!cout<<"#Starting PARAMETER_SECTION"<<endl;
 
    //recruitment parameters TODO: implement devs
    init_bounded_number_vector pLnR(1,npLnR,lbLnR,ubLnR,phsLnR);              //mean ln-scale recruitment
    init_bounded_number_vector pLnRCV(1,npLnRCV,lbLnRCV,ubLnRCV,phsLnRCV);    //ln-scale recruitment cv
    init_bounded_number_vector pLgtRX(1,npLgtRX,lbLgtRX,ubLgtRX,phsLgtRX);    //logit-scale male sex ratio
    init_bounded_number_vector pLnRa(1,npLnRa,lbLnRa,ubLnRa,phsLnRa);         //size distribution parameter
    init_bounded_number_vector pLnRb(1,npLnRb,lbLnRb,ubLnRb,phsLnRb);         //size distribution parameter
    init_bounded_vector_vector pDevsLnR(1,npDevsLnR,mniDevsLnR,mxiDevsLnR,lbDevsLnR,ubDevsLnR,phsDevsLnR);//ln-scale rec devs
    matrix devsLnR(1,npDevsLnR,mniDevsLnR,mxiDevsLnR+1);
   
    //natural mortality parameters
    init_bounded_number_vector pLnM(1,npLnM,lbLnM,ubLnM,phsLnM);               //base
    init_bounded_number_vector pLnDMT(1,npLnDMT,lbLnDMT,ubLnDMT,phsLnDMT);     //main temporal offsets
    init_bounded_number_vector pLnDMX(1,npLnDMX,lbLnDMX,ubLnDMX,phsLnDMX);     //female offsets
    init_bounded_number_vector pLnDMM(1,npLnDMM,lbLnDMM,ubLnDMM,phsLnDMM);     //immature offsets
    init_bounded_number_vector pLnDMXM(1,npLnDMXM,lbLnDMXM,ubLnDMXM,phsLnDMXM);//female-immature offsets
    
    //growth parameters
    init_bounded_number_vector pLnGrA(1,npLnGrA,lbLnGrA,ubLnGrA,phsLnGrA); //ln-scale mean growth coefficient "a"
    init_bounded_number_vector pLnGrB(1,npLnGrB,lbLnGrB,ubLnGrB,phsLnGrB); //ln-scale mean growth coefficient "b"
    init_bounded_number_vector pLnGrBeta(1,npLnGrBeta,lbLnGrBeta,ubLnGrBeta,phsLnGrBeta);//ln-scale growth scale parameter
    
    //maturity parameters
    init_bounded_vector_vector pLgtPrMat(1,npLgtPrMat,mniLgtPrMat,mxiLgtPrMat,lbLgtPrMat,ubLgtPrMat,phsLgtPrMat);//logit-scale maturity ogive parameters
    
    //selectivity parameters
    init_bounded_number_vector pS1(1,npS1,lbS1,ubS1,phsS1);
    init_bounded_number_vector pS2(1,npS2,lbS2,ubS2,phsS2);
    init_bounded_number_vector pS3(1,npS3,lbS3,ubS3,phsS3);
    init_bounded_number_vector pS4(1,npS4,lbS4,ubS4,phsS4);
    init_bounded_number_vector pS5(1,npS5,lbS5,ubS5,phsS5);
    init_bounded_number_vector pS6(1,npS6,lbS6,ubS6,phsS6);
    init_bounded_vector_vector pDevsS1(1,npDevsS1,mniDevsS1,mxiDevsS1,lbDevsS1,ubDevsS1,phsDevsS1);
    init_bounded_vector_vector pDevsS2(1,npDevsS2,mniDevsS2,mxiDevsS2,lbDevsS2,ubDevsS2,phsDevsS2);
    init_bounded_vector_vector pDevsS3(1,npDevsS3,mniDevsS3,mxiDevsS3,lbDevsS3,ubDevsS3,phsDevsS3);
    init_bounded_vector_vector pDevsS4(1,npDevsS4,mniDevsS4,mxiDevsS4,lbDevsS4,ubDevsS4,phsDevsS4);
    init_bounded_vector_vector pDevsS5(1,npDevsS5,mniDevsS5,mxiDevsS5,lbDevsS5,ubDevsS5,phsDevsS5);
    init_bounded_vector_vector pDevsS6(1,npDevsS6,mniDevsS6,mxiDevsS6,lbDevsS6,ubDevsS6,phsDevsS6);
    matrix devsS1(1,npDevsS1,mniDevsS1,mxiDevsS1+1);
    matrix devsS2(1,npDevsS2,mniDevsS2,mxiDevsS2+1);
    matrix devsS3(1,npDevsS3,mniDevsS3,mxiDevsS3+1);
    matrix devsS4(1,npDevsS4,mniDevsS4,mxiDevsS4+1);
    matrix devsS5(1,npDevsS5,mniDevsS5,mxiDevsS5+1);
    matrix devsS6(1,npDevsS6,mniDevsS6,mxiDevsS6+1);
    
    //fishing capture rate parameters
    init_bounded_number_vector pHM(1,npHM,lbHM,ubHM,phsHM);                    //handling mortality
    init_bounded_number_vector pLnC(1,npLnC,lbLnC,ubLnC,phsLnC);               //ln-scale base fishing mortality (mature males)
    init_bounded_number_vector pLnDCT(1,npLnDCT,lbLnDCT,ubLnDCT,phsLnDCT);     //ln-scale year-block offsets
    init_bounded_number_vector pLnDCX(1,npLnDCX,lbLnDCX,ubLnDCX,phsLnDCX);     //female offsets
    init_bounded_number_vector pLnDCM(1,npLnDCM,lbLnDCM,ubLnDCM,phsLnDCM);     //immature offsets
    init_bounded_number_vector pLnDCXM(1,npLnDCXM,lbLnDCXM,ubLnDCXM,phsLnDCXM);//female-immature offsets
    init_bounded_vector_vector pDevsLnC(1,npDevsLnC,mniDevsLnC,mxiDevsLnC,lbDevsLnC,ubDevsLnC,phsDevsLnC);//ln-scale deviations
    matrix devsLnC(1,npDevsLnC,mniDevsLnC,mxiDevsLnC+1);
    
    //survey catchbility parameters
    init_bounded_number_vector pLnQ(1,npLnQ,lbLnQ,ubLnQ,phsLnQ);               //base (mature male))
    init_bounded_number_vector pLnDQT(1,npLnDQT,lbLnDQT,ubLnDQT,phsLnDQT);     //main temporal offsets
    init_bounded_number_vector pLnDQX(1,npLnDQX,lbLnDQX,ubLnDQX,phsLnDQX);     //female offsets
    init_bounded_number_vector pLnDQM(1,npLnDQM,lbLnDQM,ubLnDQM,phsLnDQM);     //immature offsets
    init_bounded_number_vector pLnDQXM(1,npLnDQXM,lbLnDQXM,ubLnDQXM,phsLnDQXM);//female-immature offsets
    
    //objective function value
    objective_function_value objFun;
    
    //population-related quantities
    matrix  spb_yx(mnYr,mxYr,1,nSXs);                        //mature (spawning) biomass at mating time
    5darray n_yxmsz(mnYr,mxYr+1,1,nSXs,1,nMSs,1,nSCs,1,nZBs);//numbers at size, July 1 year y
    5darray nmN_yxmsz(mnYr,mxYr,1,nSXs,1,nMSs,1,nSCs,1,nZBs);  //natural mortality (numbers) during year)
    5darray tmN_yxmsz(mnYr,mxYr,1,nSXs,1,nMSs,1,nSCs,1,nZBs);//total mortality (numbers) during year)
    
    //recruitment-related quantities
    vector R_y(mnYr,mxYr);         //total number of recruits by year
    vector Rx_c(1,npcRec);         //male fraction of recruits by parameter combination
    matrix R_yx(mnYr,mxYr,1,nSXs); //sex-specific number of recruits by year
    matrix R_cz(1,npcRec,1,nZBs);  //size distribution of recruits by parameter combination
    matrix R_yz(mnYr,mxYr,1,nZBs); //size distribution of recruits by year
    matrix stdvDevsLnR_cy(1,npcRec,mnYr,mxYr); //ln-scale recruitment std. devs by parameter combination and year
    matrix zscrDevsLnR_cy(1,npcRec,mnYr,mxYr); //standardized ln-scale recruitment residuals by parameter combination and year
    
    //natural mortality-related quantities
    3darray M_cxm(1,npcNM,1,nSXs,1,nMSs);//natural mortality rate by parameter combination
    4darray M_yxmz(mnYr,mxYr,1,nSXs,1,nMSs,1,nZBs);//size-specific natural mortality rate
    
    //maturity-related quantities
    matrix  prMat_cz(1,npcMat,1,nZBs);         //prob. of immature crab molting to maturity by parameter combination
    3darray  prMat_yxz(mnYr,mxYr,1,nSXs,1,nZBs);//prob. of immature crab molting to maturity given sex x, pre-molt size x
    
    //growth related quantities
    3darray prGr_czz(1,npcGr,1,nZBs,1,nZBs);                  //prob of growth to z (row) from zp (col) by parameter combination
    5darray prGr_yxmzz(mnYr,mxYr,1,nSXs,1,nMSs,1,nZBs,1,nZBs);//prob of growth to z from zp given sex and whether molt is to maturity or not
    
    //Selectivity (and retention) functions
    matrix sel_cz(1,npcSel,1,nZBs);            //all selectivity functions (fisheries and surveys) by parameter combination (no devs))
    3darray sel_iyz(1,nSel,mnYr,mxYr+1,1,nZBs);//all selectivity functions (fisheries and surveys)
    
    //fishery-related quantities
    matrix dvsLnC_fy(1,nFsh,mnYr,mxYr);                   //matrix to capture lnC-devs
    4darray avgFc(1,nFsh,1,nSXs,1,nMSs,1,nSCs);           //avg capture rate over a fishery-specific period
    4darray avgRatioFc2Eff(1,nFsh,1,nSXs,1,nMSs,1,nSCs);  //ratio of avg capture rate to effort
    matrix  Fhm_fy(1,nFsh,mnYr,mxYr);                               //handling mortality
    5darray cF_fyxms(1,nFsh,mnYr,mxYr,1,nSXs,1,nMSs,1,nSCs);        //fully-selected fishing capture rates NOT mortality)
    6darray cF_fyxmsz(1,nFsh,mnYr,mxYr,1,nSXs,1,nMSs,1,nSCs,1,nZBs);//fishing capture rate (NOT mortality) by fishery
    6darray rmF_fyxmsz(1,nFsh,mnYr,mxYr,1,nSXs,1,nMSs,1,nSCs,1,nZBs);//size-specific retained fishing mortality by fishery
    6darray dmF_fyxmsz(1,nFsh,mnYr,mxYr,1,nSXs,1,nMSs,1,nSCs,1,nZBs);//size-specific discard mortality rate  by fishery
    5darray tmF_yxmsz(mnYr,mxYr,1,nSXs,1,nMSs,1,nSCs,1,nZBs);        //total size-specific fishing mortality (over all fisheries))
        
    6darray cN_fyxmsz(1,nFsh,mnYr,mxYr,1,nSXs,1,nMSs,1,nSCs,1,nZBs);//catch at size in fishery f
    6darray dN_fyxmsz(1,nFsh,mnYr,mxYr,1,nSXs,1,nMSs,1,nSCs,1,nZBs);//discarded catch (numbers, NOT mortality) at size in fishery f
    6darray rmN_fyxmsz(1,nFsh,mnYr,mxYr,1,nSXs,1,nMSs,1,nSCs,1,nZBs);//retained catch (numbers=mortality) at size in fishery f
    6darray dmN_fyxmsz(1,nFsh,mnYr,mxYr,1,nSXs,1,nMSs,1,nSCs,1,nZBs);//discard catch mortality at size in fishery f
    
    //survey-related quantities
    3darray spb_vyx(1,nSrv,mnYr,mxYr+1,1,nSXs);//mature (spawning) biomass at time of survey
    5darray q_vyxms(1,nSrv,mnYr,mxYr+1,1,nSXs,1,nMSs,1,nSCs);        //fully-selected catchability in survey v
    6darray q_vyxmsz(1,nSrv,mnYr,mxYr+1,1,nSXs,1,nMSs,1,nSCs,1,nZBs);//size-specific catchability in survey v
    6darray n_vyxmsz(1,nSrv,mnYr,mxYr+1,1,nSXs,1,nMSs,1,nSCs,1,nZBs);//catch at size in survey v
    
    //objective function penalties
    vector fPenRecDevs(1,npDevsLnR);//recruitment devs penalties
    
    vector fPenSmoothLgtPrMat(1,npLgtPrMat);//smoothness penalties on pr(mature|z)
    vector fPenNonDecLgtPrMat(1,npLgtPrMat);//non-decreasing penalties on pr(mature|z)
    
    vector fPenDevsS1(1,npDevsS1);//penalties on S1 devs (selectivity parameters)
    vector fPenDevsS2(1,npDevsS2);//penalties on S2 devs (selectivity parameters)
    vector fPenDevsS3(1,npDevsS3);//penalties on S3 devs (selectivity parameters)
    vector fPenDevsS4(1,npDevsS4);//penalties on S4 devs (selectivity parameters)
    vector fPenDevsS5(1,npDevsS5);//penalties on S5 devs (selectivity parameters)
    vector fPenDevsS6(1,npDevsS6);//penalties on S6 devs (selectivity parameters)
    
    vector fPenDevsLnC(1,npDevsLnC);//penalties on LnC devs (fishery capture parameters)
    
    //likelihood components
    vector nllRecDevs(1,npcRec);//negative log-likelihoods associated with recruitment
    
    //sdreport variables
    sdreport_vector sdrLnR_y(mnYr,mxYr);
    sdreport_matrix sdrSpB_xy(1,nSXs,mnYr+5,mxYr);

    
    !!cout<<"#finished PARAMETER_SECTION"<<endl;
    !!rpt::echo<<"#finished PARAMETER_SECTION"<<endl;
    
// =============================================================================
// =============================================================================
PRELIMINARY_CALCS_SECTION
    rpt::echo<<"#Starting PRELIMINARY_CALCS_SECTION"<<endl;
    cout<<"#Starting PRELIMINARY_CALCS_SECTION"<<endl;
    int debug=1;
    
    //set initial values for all parameters
    if (usePin) {
        rpt::echo<<"NOTE: setting initial values for parameters using pin file"<<endl;
    } else {
        rpt::echo<<"NOTE: setting initial values for parameters using setInitVals(...)"<<endl;
        setInitVals();
    }

    cout<<"testing setAllDevs()"<<endl;
    setAllDevs(0,rpt::echo);
        
    {cout<<"writing data to R"<<endl;
     ofstream echo1; echo1.open("ModelData.R", ios::trunc);
     ReportToR_Data(echo1,0,cout);
    }
    
    {cout<<"writing parameters info to R"<<endl;
     ofstream echo1; echo1.open("ModelParametersInfo.R", ios::trunc);
     ptrMPI->writeToR(echo1);
    }
    
    //calculate average effort for fisheries over specified time periods
    avgEff = 0.0;
    for (int f=1;f<=nFsh;f++){//fishery data object
        if (ptrMDS->ppFsh[f-1]->ptrEff){
            IndexRange* pir = ptrMDS->ppFsh[f-1]->ptrEff->ptrAvgIR;
            int fm = mapD2MFsh(f);//index of corresponding model fishery
            int mny = max(mnYr,pir->getMin());
            int mxy = min(mxYr,pir->getMax());
            avgEff(fm) = mean(ptrMDS->ppFsh[f-1]->ptrEff->eff_y(mny,mxy));
        }
    }
    if (debug) rpt::echo<<"avgEff = "<<avgEff<<endl;

    if (option_match(ad_comm::argc,ad_comm::argv,"-mceval")<0) {
        cout<<"testing calcRecruitment():"<<endl;
        calcRecruitment(dbgCalcProcs+1,rpt::echo);
        rpt::echo<<"testing calcNatMort():"<<endl;
        calcNatMort(dbgCalcProcs+1,rpt::echo);
        rpt::echo<<"testing calcGrowth():"<<endl;
        calcGrowth(dbgCalcProcs+1,rpt::echo);
        rpt::echo<<"testing calcMaturity():"<<endl;
        calcMaturity(dbgCalcProcs+1,rpt::echo);

        rpt::echo<<"testing calcSelectivities():"<<endl;
        calcSelectivities(dbgCalcProcs+1,rpt::echo);

        rpt::echo<<"testing calcFisheryFs():"<<endl;
        calcFisheryFs(dbgCalcProcs+1,rpt::echo);

        rpt::echo<<"testing calcSurveyQs():"<<endl;
        calcSurveyQs(dbgCalcProcs+1,cout);

        rpt::echo<<"testing runPopDyMod():"<<endl;
        runPopDyMod(dbgCalcProcs+1,cout);
        rpt::echo<<"n_yxm:"<<endl;
        for (int y=mnYr;y<=(mxYr+1);y++){
            for (int x=1;x<=nSXs;x++){
                for (int m=1;m<=nMSs;m++){
                   rpt::echo<<y<<cc;
                   rpt::echo<<tcsam::getSexType(x)<<cc;
                   rpt::echo<<tcsam::getMaturityType(m)<<cc;
                   rpt::echo<<sum(n_yxmsz(y,x,m))<<endl;
                }
            }
        }
        rpt::echo<<"n_yxmsz:"<<endl;
        for (int y=mnYr;y<=(mxYr+1);y++){
            for (int x=1;x<=nSXs;x++){
                for (int m=1;m<=nMSs;m++){
                    for (int s=1;s<=nSCs;s++){
                       rpt::echo<<y<<cc;
                       rpt::echo<<tcsam::getSexType(x)<<cc;
                       rpt::echo<<tcsam::getMaturityType(m)<<cc;
                       rpt::echo<<tcsam::getShellType(s)<<cc;
                       rpt::echo<<n_yxmsz(y,x,m,s)<<endl;
                    }
                }
            }
        }

        
        if (fitSimData){
            cout<<"creating sim data to fit in model"<<endl;
            rpt::echo<<"creating sim data to fit in model"<<endl;
            createSimData(1,rpt::echo,iSimDataSeed,ptrMDS);//stochastic if iSimDataSeed<>0
            {cout<<"re-writing data to R"<<endl;
             rpt::echo<<"re-writing data to R"<<endl;
             ofstream echo1; echo1.open("ModelData.R", ios::trunc);
             ReportToR_Data(echo1,0,cout);
            }
        }
        
        cout<<"Testing calcObjFun()"<<endl;
        rpt::echo<<"Testing calcObjFun()"<<endl;
        calcObjFun(-1,rpt::echo);
        rpt::echo<<"Testing calcObjFun() again"<<endl;
        calcObjFun(dbgAll,rpt::echo);

        {cout<<"writing model results to R"<<endl;
            rpt::echo<<"writing model results to R"<<endl;
            ofstream echo1; echo1.open("ModelRes0.R", ios::trunc);
            ReportToR(echo1,1,cout);
        }
        
        {cout<<"writing model sim data to file"<<endl;
            rpt::echo<<"writing model sim data to file"<<endl;
            createSimData(1,rpt::echo,0,ptrSimMDS);//deterministic
            ofstream echo1; echo1.open("ModelSimData0.dat", ios::trunc);
            writeSimData(echo1,0,rpt::echo,ptrSimMDS);
        }
        cout<<"#finished PRELIMINARY_CALCS_SECTION"<<endl;
        rpt::echo<<"#finished PRELIMINARY_CALCS_SECTION"<<endl;
//        int tmp = 1;
//        cout<<"Enter 1 to continue > ";
//        cin>>tmp;
//        if (tmp<0) exit(-1);
    } else {
        writeMCMCHeader();
        cout<<"MCEVAL is on"<<endl;
        rpt::echo<<"MCEVAL is on"<<endl;
    }
    
    
// =============================================================================
// =============================================================================
PROCEDURE_SECTION

    objFun.initialize();

    runPopDyMod(0,rpt::echo);

    calcObjFun(0,rpt::echo);
    
    if (sd_phase()){
        sdrLnR_y = log(R_y);
        for (int x=1;x<=nSXs;x++){
            for (int y=mnYr+ptrMDS->ptrBio->recLag; y<=mxYr; y++){
                sdrSpB_xy(x,y) = spb_yx(y,x);
            }
        }
    }
    
    if (mceval_phase()){
        updateMPI(0, cout);
        writeMCMCtoR(mcmc);
    }

//*****************************************
FUNCTION setInitVals
    //recruitment parameters
    setInitVals(ptrMPI->ptrRec->pLnR,    pLnR,    0,rpt::echo);
    setInitVals(ptrMPI->ptrRec->pLnRCV,  pLnRCV,  0,rpt::echo);
    setInitVals(ptrMPI->ptrRec->pLgtRX,  pLgtRX,  0,rpt::echo);
    setInitVals(ptrMPI->ptrRec->pLnRa,   pLnRa,   0,rpt::echo);
    setInitVals(ptrMPI->ptrRec->pLnRb,   pLnRb,   0,rpt::echo);
    setInitVals(ptrMPI->ptrRec->pDevsLnR,pDevsLnR,0,rpt::echo);

    //natural mortality parameters
    setInitVals(ptrMPI->ptrNM->pLnM,   pLnM,   0,rpt::echo);
    setInitVals(ptrMPI->ptrNM->pLnDMT, pLnDMT, 0,rpt::echo);
    setInitVals(ptrMPI->ptrNM->pLnDMX, pLnDMX, 0,rpt::echo);
    setInitVals(ptrMPI->ptrNM->pLnDMM, pLnDMM, 0,rpt::echo);
    setInitVals(ptrMPI->ptrNM->pLnDMXM,pLnDMXM,0,rpt::echo);

    //growth parameters
    setInitVals(ptrMPI->ptrGr->pLnGrA,   pLnGrA,   0,rpt::echo);
    setInitVals(ptrMPI->ptrGr->pLnGrB,   pLnGrB,   0,rpt::echo);
    setInitVals(ptrMPI->ptrGr->pLnGrBeta,pLnGrBeta,0,rpt::echo);

    //maturity parameters
    setInitVals(ptrMPI->ptrMat->pLgtPrMat,pLgtPrMat,0,rpt::echo);

    //selectivity parameters
    setInitVals(ptrMPI->ptrSel->pS1, pS1,0,rpt::echo);
    setInitVals(ptrMPI->ptrSel->pS2, pS2,0,rpt::echo);
    setInitVals(ptrMPI->ptrSel->pS3, pS3,0,rpt::echo);
    setInitVals(ptrMPI->ptrSel->pS4, pS4,0,rpt::echo);
    setInitVals(ptrMPI->ptrSel->pS5, pS5,0,rpt::echo);
    setInitVals(ptrMPI->ptrSel->pS6, pS6,0,rpt::echo);
    setInitVals(ptrMPI->ptrSel->pDevsS1, pDevsS1,0,rpt::echo);
    setInitVals(ptrMPI->ptrSel->pDevsS2, pDevsS2,0,rpt::echo);
    setInitVals(ptrMPI->ptrSel->pDevsS3, pDevsS3,0,rpt::echo);
    setInitVals(ptrMPI->ptrSel->pDevsS4, pDevsS4,0,rpt::echo);
    setInitVals(ptrMPI->ptrSel->pDevsS5, pDevsS5,0,rpt::echo);
    setInitVals(ptrMPI->ptrSel->pDevsS6, pDevsS6,0,rpt::echo);

    //fully-selected fishing capture rate parameters
    setInitVals(ptrMPI->ptrFsh->pHM,     pHM,     0,rpt::echo);
    setInitVals(ptrMPI->ptrFsh->pLnC,    pLnC,    0,rpt::echo);
    setInitVals(ptrMPI->ptrFsh->pLnDCT,  pLnDCT,  0,rpt::echo);
    setInitVals(ptrMPI->ptrFsh->pLnDCX,  pLnDCX,  0,rpt::echo);
    setInitVals(ptrMPI->ptrFsh->pLnDCM,  pLnDCM,  0,rpt::echo);
    setInitVals(ptrMPI->ptrFsh->pLnDCXM, pLnDCXM, 0,rpt::echo);
    setInitVals(ptrMPI->ptrFsh->pDevsLnC,pDevsLnC,0,rpt::echo);

    //survey catchability parameters
    setInitVals(ptrMPI->ptrSrv->pLnQ,   pLnQ,   0,rpt::echo);
    setInitVals(ptrMPI->ptrSrv->pLnDQT, pLnDQT, 0,rpt::echo);
    setInitVals(ptrMPI->ptrSrv->pLnDQX, pLnDQX, 0,rpt::echo);
    setInitVals(ptrMPI->ptrSrv->pLnDQM, pLnDQM, 0,rpt::echo);
    setInitVals(ptrMPI->ptrSrv->pLnDQXM,pLnDQXM,0,rpt::echo);

//----------------------------------------------------------------------------------
//write header to MCMC eval file
FUNCTION writeMCMCHeader
    mcmc.open((char*)(fnMCMC),ofstream::out|ofstream::trunc);
    mcmc<<"mcmc=list("<<endl;
    mcmc.close();
    
//******************************************************************************
FUNCTION void writeMCMCtoR(ostream& mcmc,NumberVectorInfo* ptr)
    mcmc<<ptr->name<<"="; ptr->writeFinalValsToR(mcmc);
    
//******************************************************************************
FUNCTION void writeMCMCtoR(ostream& mcmc,BoundedNumberVectorInfo* ptr)
    mcmc<<ptr->name<<"="; ptr->writeFinalValsToR(mcmc);
    
//******************************************************************************
FUNCTION void writeMCMCtoR(ostream& mcmc,BoundedVectorVectorInfo* ptr)
    mcmc<<ptr->name<<"="; ptr->writeFinalValsToR(mcmc);
    
//******************************************************************************
FUNCTION void writeMCMCtoR(ostream& mcmc,DevsVectorVectorInfo* ptr)
    mcmc<<ptr->name<<"="; ptr->writeFinalValsToR(mcmc);
    
//******************************************************************************
FUNCTION void writeMCMCtoR(ofstream& mcmc)
    mcmc.open((char *) fnMCMC, ofstream::out|ofstream::app);
    mcmc<<"list(objFun="<<objFun<<cc<<endl;
    //write parameter values
        //recruitment values
        writeMCMCtoR(mcmc,ptrMPI->ptrRec->pLnR);   mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrRec->pLnRCV); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrRec->pLgtRX); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrRec->pLnRa);  mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrRec->pLnRb);  mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrRec->pDevsLnR);  mcmc<<cc<<endl;

        //natural mortality parameters
        writeMCMCtoR(mcmc,ptrMPI->ptrNM->pLnM); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrNM->pLnDMT); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrNM->pLnDMX); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrNM->pLnDMM); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrNM->pLnDMXM); mcmc<<cc<<endl;

        //growth parameters
        writeMCMCtoR(mcmc,ptrMPI->ptrGr->pLnGrA); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrGr->pLnGrB); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrGr->pLnGrBeta); mcmc<<cc<<endl;

        //maturity parameters
        writeMCMCtoR(mcmc,ptrMPI->ptrMat->pLgtPrMat); mcmc<<cc<<endl;

        //selectivity parameters
        writeMCMCtoR(mcmc,ptrMPI->ptrSel->pS1); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSel->pS2); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSel->pS3); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSel->pS4); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSel->pS5); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSel->pS6); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSel->pDevsS1); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSel->pDevsS2); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSel->pDevsS3); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSel->pDevsS4); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSel->pDevsS5); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSel->pDevsS6); mcmc<<cc<<endl;

        //fully-selected fishing capture rate parameters
        writeMCMCtoR(mcmc,ptrMPI->ptrFsh->pHM); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrFsh->pLnC); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrFsh->pLnDCT); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrFsh->pLnDCX); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrFsh->pLnDCM); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrFsh->pLnDCXM); mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrFsh->pDevsLnC); mcmc<<cc<<endl;

        //survey catchability parameters
        writeMCMCtoR(mcmc,ptrMPI->ptrSrv->pLnQ);    mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSrv->pLnDQT);  mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSrv->pLnDQX);  mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSrv->pLnDQM);  mcmc<<cc<<endl;
        writeMCMCtoR(mcmc,ptrMPI->ptrSrv->pLnDQXM); mcmc<<cc<<endl;
    
        //write other quantities
        mcmc<<"R_y="; wts::writeToR(mcmc,value(R_y)); mcmc<<cc<<endl;
        ivector bnds = wts::getBounds(spb_yx);
        adstring dsxs = tcsamDims::getSXsForR(bnds[3],bnds[4]);
        mcmc<<"spb_xy="; wts::writeToR(mcmc,trans(value(spb_yx)),dsxs,ptrMC->dimYrsToR); //mcmc<<cc<<endl;
        
    mcmc<<")"<<cc<<endl;
    mcmc.close();
    
//******************************************************************************
FUNCTION void createSimData(int debug, ostream& cout, int iSimDataSeed, ModelDatasets* ptrSim)
    if (debug)cout<<"simulating model results as data"<<endl;
    d6_array vn_vyxmsz = wts::value(n_vyxmsz);
    d6_array vcN_fyxmsz = wts::value(cN_fyxmsz);
    d6_array vrmN_fyxmsz = wts::value(rmN_fyxmsz);
    for (int f=1;f<=nFsh;f++) {
        if (debug) cout<<"fishery f: "<<f<<endl;
        (ptrSim->ppFsh[f-1])->replaceCatchData(iSimDataSeed,rngSimData,vcN_fyxmsz(f),vrmN_fyxmsz(f),ptrSim->ptrBio->wAtZ_xmz);
    }
    for (int v=1;v<=nSrv;v++) {
        if (debug) cout<<"survey "<<v<<endl;
        (ptrSim->ppSrv[v-1])->replaceCatchData(iSimDataSeed,rngSimData,vn_vyxmsz(v),ptrSim->ptrBio->wAtZ_xmz);
    }
    if (debug) cout<<"finished simulating model results as data"<<endl;
     
//******************************************************************************
FUNCTION void writeSimData(ostream& os, int debug, ostream& cout, ModelDatasets* ptrSim)
    if (debug)cout<<"writing model results as data"<<endl;
    for (int v=1;v<=nSrv;v++) {
        os<<"#------------------------------------------------------------"<<endl;
        os<<(*(ptrSim->ppSrv[v-1]))<<endl;
    }
    //     cout<<4<<endl;
    for (int f=1;f<=nFsh;f++) {
        os<<"#------------------------------------------------------------"<<endl;
        os<<(*(ptrSim->ppFsh[f-1]))<<endl;
    }
    if (debug) cout<<"finished writing model results as data"<<endl;
     
//******************************************************************************
//* Function: void setInitVals(NumberVectorInfo* pI, param_init_number_vector& p, int debug, ostream& cout)
//* 
//* Description: Sets initial values for a parameter vector.
//*
//* Note: this function MUST be declared/defined as a FUNCTION in the tpl code
//*     because the parameter assignment is a private method but the model_parameters 
//*     class has friend access.
//* 
//* Inputs:
//*  pI (NumberVectorInfo*) 
//*     pointer to NumberVectorInfo object
//*  p (param_init_number_vector&)
//*     parameter vector
//* Returns:
//*  void
//* Alters:
//*  p - changes initial values
//******************************************************************************
FUNCTION void setInitVals(NumberVectorInfo* pI, param_init_number_vector& p, int debug, ostream& cout)
//    debug=dbgAll;
    if (debug>=dbgAll) std::cout<<"Starting setInitVals(NumberVectorInfo* pI, param_init_number_vector& p) for "<<p(1).label()<<endl; 
    int np = pI->getSize();
    if (np){
        dvector vls = pI->getInitVals();//initial values from parameter info
        dvector def = pI->getInitVals();//defaults are initial values
        for (int i=1;i<=np;i++) {
            p(i) = vls(i);  //assign initial value from parameter info
            NumberInfo* ptrI = (*pI)[i];
            if ((p(i).get_phase_start()>0)&&(ptrMC->resample)&&(ptrI->resample)){
                p(i) = ptrI->drawInitVal(rng,ptrMC->vif);//assign initial value based on resampling prior pdf
            }
        }
        //p.set_initial_value(vls);
        rpt::echo<<"InitVals for "<<p(1).label()<<": "<<endl;
        rpt::echo<<tb<<"inits  : "<<vls<<endl;
        rpt::echo<<tb<<"default: "<<def<<endl;
        rpt::echo<<tb<<"actual : "<<p<<endl;
        if (debug>=dbgAll) {
            std::cout<<"InitVals for "<<p(1).label()<<": "<<endl;
            std::cout<<tb<<p<<std::endl;
        }
    } else {
        rpt::echo<<"InitVals for "<<p(1).label()<<" not defined because np = "<<np<<endl;
    }
    
    if (debug>=dbgAll) {
        std::cout<<"Enter 1 to continue >>";
        std::cin>>np;
        if (np<0) exit(-1);
        std::cout<<"Finished setInitVals(NumberVectorInfo* pI, param_init_number_vector& p) for "<<p(1).label()<<endl; 
    }
     
//******************************************************************************
//* Function: void setInitVals(BoundedNumberVectorInfo* pI, param_init_bounded_number_vector& p, int debug, ostream& cout)
//* 
//* Description: Sets initial values for a parameter vector.
//*
//* Note: this function MUST be declared/defined as a FUNCTION in the tpl code
//*     because the parameter assignment is a private method but the model_parameters 
//*     class has friend access.
//* 
//* Inputs:
//*  pI (BoundedNumberVectorInfo*) 
//*     pointer to BoundedNumberVectorInfo object
//*  p (param_init_bounded_number_vector&)
//*     parameter vector
//* Returns:
//*  void
//* Alters:
//*  p - changes initial values
//******************************************************************************
FUNCTION void setInitVals(BoundedNumberVectorInfo* pI, param_init_bounded_number_vector& p, int debug, ostream& cout)
//    debug=dbgAll;
    if (debug>=dbgAll) std::cout<<"Starting setInitVals(BoundedNumberVectorInfo* pI, param_init_bounded_number_vector& p) for "<<p(1).label()<<endl; 
    int np = pI->getSize();
    if (np){
        dvector vls = pI->getInitVals();//initial values from parameter info
        dvector def = 0.5*(pI->getUpperBounds()+pI->getLowerBounds());//defaults are midpoints of ranges
        for (int i=1;i<=np;i++) {
            p(i) = vls(i);  //assign initial value from parameter info
            BoundedNumberInfo* ptrI = (*pI)[i];
            if ((p(i).get_phase_start()>0)&&(ptrMC->jitter)&&(ptrI->jitter)){
                rpt::echo<<"jittering "<<p(i).label()<<endl;
                p(i) = wts::jitterParameter(p(i), ptrMC->jitFrac, rng);//only done if parameter phase > 0
            } else 
            if ((p(i).get_phase_start()>0)&&(ptrMC->resample)&&(ptrI->resample)){
                p(i) = ptrI->drawInitVal(rng,ptrMC->vif);
            }
        }
        //p.set_initial_value(vls);
        rpt::echo<<"InitVals for "<<p(1).label()<<": "<<endl;
        rpt::echo<<tb<<"inits  : "<<vls<<endl;
        rpt::echo<<tb<<"default: "<<def<<endl;
        rpt::echo<<tb<<"actual : "<<p<<endl;
        if (debug>=dbgAll) {
            std::cout<<"InitVals for "<<p(1).label()<<": "<<endl;
            std::cout<<tb<<p<<std::endl;
        }
    } else {
        rpt::echo<<"InitVals for "<<p(1).label()<<" not defined because np = "<<np<<endl;
    }
    
    if (debug>=dbgAll) {
        std::cout<<"Enter 1 to continue >>";
        std::cin>>np;
        if (np<0) exit(-1);
        std::cout<<"Finished setInitVals(BoundedNumberVectorInfo* pI, param_init_bounded_number_vector& p) for "<<p(1).label()<<endl; 
    }

//******************************************************************************
//* Function: void setInitVals(BoundedVectorVectorInfo* pI, param_init_bounded_vector_vector& p, int debug, ostream& cout)
//* 
//* Description: Sets initial values for a vector of parameter vectors.
//*
//* Note: this function MUST be declared/defined as a FUNCTION in the tpl code
//*     because the parameter assignment is a private method but the model_parameters 
//*     class has friend access.
//* 
//* Inputs:
//*  pI (BoundedVectorVectorInfo*) 
//*     pointer to BoundedNumberVectorInfo object
//*  p (param_init_bounded_vector_vector&)
//*     parameter vector
//* Returns:
//*  void
//* Alters:
//*  p - changes initial values
//******************************************************************************
FUNCTION void setInitVals(BoundedVectorVectorInfo* pI, param_init_bounded_vector_vector& p, int debug, ostream& cout)
//    debug=dbgAll;
    if (debug>=dbgAll) std::cout<<"Starting setInitVals(BoundedVectorVectorInfo* pI, param_init_bounded_vector_vector& p) for "<<p(1).label()<<endl; 
    int np = pI->getSize();
    if (np){
        for (int i=1;i<=np;i++) {
            rpt::echo<<"InitVals "<<p(i).label()<<":"<<endl;
            dvector pns = value(p(i));
            dvector vls = (*pI)[i]->getInitVals();//initial values from parameter info
            if (debug>=dbgAll) std::cout<<"pc "<<i<<" :"<<tb<<p(i).indexmin()<<tb<<p(i).indexmax()<<tb<<vls.indexmin()<<tb<<vls.indexmax()<<endl;
            for (int j=p(i).indexmin();j<=p(i).indexmax();j++) p(i,j)=vls(j);
            BoundedVectorInfo* ptrI = (*pI)[i];
            if ((p(i).get_phase_start()>0)&&(ptrMC->jitter)&&(ptrI->jitter)){
                rpt::echo<<tb<<"jittering "<<p(i).label()<<endl;
                dvector rvs = wts::jitterParameter(p(i), ptrMC->jitFrac, rng);//get jittered values
                for (int j=p(i).indexmin();j<=p(i).indexmax();j++) p(i,j)=rvs(j);
                rpt::echo<<tb<<"pin values       = "<<pns<<endl;
                rpt::echo<<tb<<"info values      = "<<vls<<endl;
                rpt::echo<<tb<<"resampled values = "<<rvs<<endl;
                rpt::echo<<tb<<"final values     = "<<p(i)<<endl;
            } else
            if ((p(i).get_phase_start()>0)&&(ptrMC->resample)&&(ptrI->resample)){
                rpt::echo<<tb<<"resampling "<<p(i).label()<<endl;
                dvector rvs = ptrI->drawInitVals(rng,ptrMC->vif);//get resampled values
                for (int j=p(i).indexmin();j<=p(i).indexmax();j++) p(i,j)=rvs(j);
                rpt::echo<<tb<<"pin values       = "<<pns<<endl;
                rpt::echo<<tb<<"info values      = "<<vls<<endl;
                rpt::echo<<tb<<"resampled values = "<<rvs<<endl;
                rpt::echo<<tb<<"final values     = "<<p(i)<<endl;
            } else {
                rpt::echo<<tb<<"No jittering or resampling "<<p(i).label()<<endl;
                rpt::echo<<tb<<"pin values       = "<<pns<<endl;
                rpt::echo<<tb<<"info values      = "<<vls<<endl;
                rpt::echo<<tb<<"final values     = "<<p(i)<<endl;
            }
            if (debug>=dbgAll){
                std::cout<<"pns(i) = "<<pns<<endl;
                std::cout<<"vls(i) = "<<vls<<endl;
                std::cout<<"p(i)   = "<<p(i)<<endl;
            }
        }
    } else {
        rpt::echo<<"InitVals for "<<p(1).label()<<" not defined because np = "<<np<<endl;
    }
    
    if (debug>=dbgAll) {
        std::cout<<"Enter 1 to continue >>";
        std::cin>>np;
        if (np<0) exit(-1);
        std::cout<<"Finished setInitVals(BoundedVectorVectorInfo* pI, param_init_bounded_vector_vector& p) for "<<p(1).label()<<endl; 
    }

//******************************************************************************
//* Function: void setInitVals(BoundedVectorVectorInfo* pI, param_init_bounded_vector_vector& p, int debug, ostream& cout)
//* 
//* Description: Sets initial values for a vector of parameter vectors.
//*
//* Note: this function MUST be declared/defined as a FUNCTION in the tpl code
//*     because the parameter assignment is a private method but the model_parameters 
//*     class has friend access.
//* 
//* Inputs:
//*  pI (BoundedVectorVectorInfo*) 
//*     pointer to BoundedNumberVectorInfo object
//*  p (param_init_bounded_vector_vector&)
//*     parameter vector
//* Returns:
//*  void
//* Alters:
//*  p - changes initial values
//******************************************************************************
FUNCTION void setInitVals(DevsVectorVectorInfo* pI, param_init_bounded_vector_vector& p, int debug, ostream& cout)
//    debug=dbgAll;
    if (debug>=dbgAll) std::cout<<"Starting setInitVals(DevsVectorVectorInfo* pI, param_init_bounded_vector_vector& p) for "<<p(1).label()<<endl; 
    int np = pI->getSize();
    if (np){
        for (int i=1;i<=np;i++) {
            rpt::echo<<"InitVals "<<p(i).label()<<":"<<endl;
            dvector pns = value(p(i));
            dvector vls = (*pI)[i]->getInitVals();//initial values from parameter info
            if (debug>=dbgAll) std::cout<<"pc "<<i<<" :"<<tb<<p(i).indexmin()<<tb<<p(i).indexmax()<<tb<<vls.indexmin()<<tb<<vls.indexmax()<<endl;
            for (int j=p(i).indexmin();j<=p(i).indexmax();j++) p(i,j)=vls(j);
            DevsVectorInfo* ptrI = (*pI)[i];
            if ((p(i).get_phase_start()>0)&&(ptrMC->jitter)&&(ptrI->jitter)){
                rpt::echo<<tb<<"jittering "<<p(i).label()<<endl;
                dvector rvs = wts::jitterParameter(p(i), ptrMC->jitFrac, rng);//get jittered values
                for (int j=p(i).indexmin();j<=p(i).indexmax();j++) p(i,j)=rvs(j);
                rpt::echo<<tb<<"pin values       = "<<pns<<endl;
                rpt::echo<<tb<<"info values      = "<<vls<<endl;
                rpt::echo<<tb<<"resampled values = "<<rvs<<endl;
                rpt::echo<<tb<<"final values     = "<<p(i)<<endl;
            } else
            if ((p(i).get_phase_start()>0)&&(ptrMC->resample)&&(ptrI->resample)){
                rpt::echo<<tb<<"resampling "<<p(i).label()<<endl;
                dvector rvs = ptrI->drawInitVals(rng,ptrMC->vif);//get resampled values
                for (int j=p(i).indexmin();j<=p(i).indexmax();j++) p(i,j)=rvs(j);
                rpt::echo<<tb<<"pin values       = "<<pns<<endl;
                rpt::echo<<tb<<"info values      = "<<vls<<endl;
                rpt::echo<<tb<<"resampled values = "<<rvs<<endl;
                rpt::echo<<tb<<"final values     = "<<p(i)<<endl;
            } else {
                rpt::echo<<tb<<"No jittering or resampling "<<p(i).label()<<endl;
                rpt::echo<<tb<<"pin values       = "<<pns<<endl;
                rpt::echo<<tb<<"info values      = "<<vls<<endl;
                rpt::echo<<tb<<"final values     = "<<p(i)<<endl;
            }
            if (debug>=dbgAll){
                std::cout<<"pns(i) = "<<pns<<endl;
                std::cout<<"vls(i) = "<<vls<<endl;
                std::cout<<"p(i)   = "<<p(i)<<endl;
            }
        }
    } else {
        rpt::echo<<"InitVals for "<<p(1).label()<<" not defined because np = "<<np<<endl;
    }
    
    if (debug>=dbgAll) {
        std::cout<<"Enter 1 to continue >>";
        std::cin>>np;
        if (np<0) exit(-1);
        std::cout<<"Finished setInitVals(DevsVectorVectorInfo* pI, param_init_bounded_vector_vector& p) for "<<p(1).label()<<endl; 
    }

//-------------------------------------------------------------------------------------
FUNCTION void setAllDevs(int debug, ostream& cout)
    if (debug>=dbgAll) cout<<"starting setAllDevs()"<<endl;
    tcsam::setDevs(devsLnR, pDevsLnR,debug,cout);

    tcsam::setDevs(devsS1, pDevsS1,debug,cout);
    tcsam::setDevs(devsS2, pDevsS2,debug,cout);
    tcsam::setDevs(devsS3, pDevsS3,debug,cout);
    tcsam::setDevs(devsS4, pDevsS4,debug,cout);
    tcsam::setDevs(devsS5, pDevsS5,debug,cout);
    tcsam::setDevs(devsS6, pDevsS6,debug,cout);
    
    tcsam::setDevs(devsLnC, pDevsLnC,debug,cout);
    if (debug>=dbgAll) cout<<"finished setAllDevs()"<<endl;

    
//-------------------------------------------------------------------------------------
FUNCTION void runPopDyMod(int debug, ostream& cout)
    if (debug>=dbgPopDy) cout<<"starting runPopDyMod()"<<endl;
    //initialize population model
    initPopDyMod(debug, cout);
    //run population model
    for (int y=mnYr;y<=mxYr;y++){
        doSurveys(y,debug,cout);
        runPopDyModOneYear(y,debug,cout);        
    }
    doSurveys(mxYr+1,debug,cout);//do final surveys
    
    if (debug>=dbgPopDy) cout<<"finished runPopDyMod()"<<endl;
    
//-------------------------------------------------------------------------------------
FUNCTION void initPopDyMod(int debug, ostream& cout)
    if (debug>=dbgPopDy) cout<<"starting initPopDyMod()"<<endl;
    
    spb_yx.initialize();
    n_yxmsz.initialize();
    nmN_yxmsz.initialize();
    tmN_yxmsz.initialize();
       
    setAllDevs(debug,cout);//set devs vectors
    
    calcRecruitment(debug,cout);//calculate recruitment
    calcNatMort(debug,cout);    //calculate natural mortality rates
    calcGrowth(debug,cout);     //calculate growth transition matrices
    calcMaturity(debug,cout);   //calculate maturity ogives
    
    calcSelectivities(debug,cout);
    calcFisheryFs(debug,cout);
    calcSurveyQs(debug,cout);
    
    if (debug>=dbgPopDy) cout<<"finished initPopDyMod()"<<endl;

//-------------------------------------------------------------------------------------
//calculate surveys.
FUNCTION void doSurveys(int y,int debug,ostream& cout)
    if (debug>=dbgPopDy) cout<<"starting doSurveys("<<y<<")"<<endl;

    for (int v=1;v<=nSrv;v++){
        for (int x=1;x<=nSXs;x++){
            for (int m=1;m<=nMSs;m++){
                for (int s=1;s<=nSCs;s++){
                    n_vyxmsz(v,y,x,m,s) = elem_prod(q_vyxmsz(v,y,x,m,s),n_yxmsz(y,x,m,s));
                }
            }
        }
    }
    for (int v=1;v<=nSrv;v++){
        spb_vyx(v,y) = calcSpB(n_vyxmsz(v,y),y,debug,cout);
    }
    if (debug>=dbgPopDy) cout<<"finished doSurveys("<<y<<")"<<endl;

//-------------------------------------------------------------------------------------
FUNCTION void runPopDyModOneYear(int yr, int debug, ostream& cout)
    if (debug>=dbgPopDy) cout<<"Starting runPopDyModOneYear("<<yr<<")"<<endl;

    dvar4_array n1_xmsz(1,nSXs,1,nMSs,1,nSCs,1,nZBs);
    dvar4_array n2_xmsz(1,nSXs,1,nMSs,1,nSCs,1,nZBs);
    dvar4_array n3_xmsz(1,nSXs,1,nMSs,1,nSCs,1,nZBs);
    dvar4_array n4_xmsz(1,nSXs,1,nMSs,1,nSCs,1,nZBs);
    dvar4_array n5_xmsz(1,nSXs,1,nMSs,1,nSCs,1,nZBs);
    
    if (dtF(yr)<=dtM(yr)){//fishery occurs BEFORE molting/growth/maturity
        if (debug>=dbgPopDy) cout<<"Fishery occurs BEFORE molting/growth/maturity"<<endl;
        //apply natural mortality before fisheries
        n1_xmsz = applyNatMort(n_yxmsz(yr),yr,dtF(yr),debug,cout);
        //conduct fisheries
        n2_xmsz = applyFshMort(n1_xmsz,yr,debug,cout);
        //apply natural mortality from fisheries to molting/growth/maturity
        if (dtF(yr)==dtM(yr)) {
            n3_xmsz = n2_xmsz;
        } else {
            n3_xmsz = applyNatMort(n2_xmsz,yr,dtM(yr)-dtF(yr),debug,cout);
        }
        //calc mature (spawning) biomass at time of mating (TODO: does this make sense??)
        spb_yx(yr) = calcSpB(n3_xmsz,yr,debug,cout);
        //apply molting, growth and maturation
        n4_xmsz = applyMGM(n3_xmsz,yr,debug,cout);
        //apply natural mortality to end of year
        if (dtM(yr)==1.0) {
            n5_xmsz = n4_xmsz;
        } else {
            n5_xmsz = applyNatMort(n4_xmsz,yr,1.0-dtM(yr),debug,cout);
        }
    } else {              //fishery occurs AFTER molting/growth/maturity
        if (debug>=dbgPopDy) cout<<"Fishery occurs AFTER molting/growth/maturity"<<endl;
        //apply natural mortality before molting/growth/maturity
        n1_xmsz = applyNatMort(n_yxmsz(yr),yr,dtM(yr),debug,cout);
        //calc mature (spawning) biomass at time of mating (TODO: does this make sense??)
        spb_yx(yr) = calcSpB(n1_xmsz,yr,debug,cout);
        //apply molting, growth and maturation
        n2_xmsz = applyMGM(n1_xmsz,yr,debug,cout);
        //apply natural mortality from molting/growth/maturity to fisheries
        if (dtM(yr)==dtF(yr)) {
            n3_xmsz = n2_xmsz;
        } else {
            n3_xmsz = applyNatMort(n2_xmsz,yr,dtF(yr)-dtM(yr),debug,cout);
        }
        //conduct fisheries
        n4_xmsz = applyFshMort(n3_xmsz,yr,debug,cout);
        //apply natural mortality to end of year
        if (dtF(yr)==1.0) {
            n5_xmsz = n4_xmsz;
        } else {
            n5_xmsz = applyNatMort(n4_xmsz,yr,1.0-dtF(yr),debug,cout);
        }
    }
    
    //advance surviving individuals to next year
    for (int x=1;x<=nSXs;x++){
        for (int m=1;m<=nMSs;m++){
            for (int s=1;s<=nSCs;s++){
                n_yxmsz(yr+1,x,m,s) = n5_xmsz(x,m,s);
            }
        }
    }
    //add in recruits
    for (int x=1;x<=nSXs;x++) n_yxmsz(yr+1,x,IMMATURE,NEW_SHELL) += R_y(yr)*R_yx(yr,x)*R_yz(yr);
    
    if (debug>=dbgPopDy) cout<<"finished runPopDyModOneYear("<<yr<<")"<<endl;
    
//-------------------------------------------------------------------------------------
FUNCTION dvar_vector calcSpB(dvar4_array& n0_xmsz, int y, int debug, ostream& cout)
    if (debug>dbgApply) cout<<"starting calcSpB("<<y<<")"<<endl;
    RETURN_ARRAYS_INCREMENT();
    dvar_vector spb(1,nSXs); spb.initialize();
    for (int x=1;x<=nSXs;x++){
        for (int s=1;s<=nSCs;s++) spb(x) += n0_xmsz(x,MATURE,s)*ptrMDS->ptrBio->wAtZ_xmz(x,MATURE);//dot product here
    }
    if (debug>dbgApply) cout<<"finished calcSpB("<<y<<")"<<endl;
    RETURN_ARRAYS_DECREMENT();
    return spb;
    
//-------------------------------------------------------------------------------------
FUNCTION dvar4_array applyNatMort(dvar4_array& n0_xmsz, int y, double dt, int debug, ostream& cout)
    if (debug>dbgApply) cout<<"starting applyNatMort("<<y<<cc<<dt<<")"<<endl;
    RETURN_ARRAYS_INCREMENT();
    dvar4_array n1_xmsz(1,nSXs,1,nMSs,1,nSCs,1,nZBs);
    for (int x=1;x<=nSXs;x++){
        for (int m=1;m<=nMSs;m++){
            for (int s=1;s<=nSCs;s++){
                n1_xmsz(x,m,s) = elem_prod(exp(-M_yxmz(y,x,m)*dt),n0_xmsz(x,m,s));//survivors
                nmN_yxmsz(y,x,m,s) += n0_xmsz(x,m,s)-n1_xmsz(x,m,s); //natural mortality
                tmN_yxmsz(y,x,m,s) += n0_xmsz(x,m,s)-n1_xmsz(x,m,s); //natural mortality
            }
        }
    }
    if (debug>dbgApply) cout<<"finished applyNatMort("<<y<<cc<<dt<<")"<<endl;
    RETURN_ARRAYS_DECREMENT();
    return n1_xmsz;
    
//-------------------------------------------------------------------------------------
FUNCTION dvar4_array applyFshMort(dvar4_array& n0_xmsz, int y, int debug, ostream& cout)
    if (debug>dbgApply) cout<<"starting applyFshMort("<<y<<")"<<endl;
    RETURN_ARRAYS_INCREMENT();
    dvar_vector tm_z(1,nZBs);//total mortality (numbers) by size
    dvar_vector tvF_z(1,nZBs);//total fishing mortality rate by size, for use in calculating fishing rate components
    dvector     tdF_z(1,nZBs);//total fishing mortality rate by size, for use in calculating fishing rate components
    dvar4_array n1_xmsz(1,nSXs,1,nMSs,1,nSCs,1,nZBs);//numbers surviving fisheries
    n1_xmsz.initialize();
    for (int x=1;x<=nSXs;x++){
        for (int m=1;m<=nMSs;m++){
            for (int s=1;s<=nSCs;s++){
                tmF_yxmsz(y,x,m,s) = 0.0;//total fishing mortality rate
                for (int f=1;f<=nFsh;f++) tmF_yxmsz(y,x,m,s) += rmF_fyxmsz(f,y,x,m,s)+dmF_fyxmsz(f,y,x,m,s);
                n1_xmsz(x,m,s) = elem_prod(mfexp(-tmF_yxmsz(y,x,m,s)),n0_xmsz(x,m,s));//numbers surviving all fisheries
                tm_z = n0_xmsz(x,m,s)-n1_xmsz(x,m,s);  //numbers killed by all fisheries
                tmN_yxmsz(y,x,m,s) += tm_z;            //add in numbers killed by all fisheries to total killed
                
                //calculate fishing rate components (need to ensure NOT dividing by 0)
                tdF_z = value(tmF_yxmsz(y,x,m,s));
                tvF_z = elem_prod(1-wts::isEQ(tdF_z,0.0),tmF_yxmsz(y,x,m,s)) + 
                                  wts::isEQ(tdF_z,0.0);
//                cout<<"y,x,m,s = "<<y<<tb<<x<<tb<<m<<tb<<s<<endl;
//                cout<<"tdF_z      = "<<tdF_z<<endl;
//                cout<<"tdF_z==0.0 = "<<wts::isEQ(tdF_z,0.0)<<endl;
//                cout<<"tvF_z      = "<<tvF_z<<endl;
//                int tmp; cout<<"Enter 1 to continue > "; cin>>tmp; if (!tmp) exit(-1);
                for (int f=1;f<=nFsh;f++){                   
                    cN_fyxmsz(f,y,x,m,s)  = elem_prod(elem_div( cF_fyxmsz(f,y,x,m,s),tvF_z),tm_z);//numbers captured in fishery f
                    rmN_fyxmsz(f,y,x,m,s) = elem_prod(elem_div(rmF_fyxmsz(f,y,x,m,s),tvF_z),tm_z);//retained mortality in fishery f (numbers)
                    dmN_fyxmsz(f,y,x,m,s) = elem_prod(elem_div(dmF_fyxmsz(f,y,x,m,s),tvF_z),tm_z);//discards mortality in fishery f (numbers)
                    dN_fyxmsz(f,y,x,m,s)  = cN_fyxmsz(f,y,x,m,s)-rmN_fyxmsz(f,y,x,m,s);//discarded catch (NOT mortality) in fishery f (numbers)                    
                }
            }
        }
    }
    if (debug>dbgApply) cout<<"finished applyFshMort("<<y<<")"<<endl;
    RETURN_ARRAYS_DECREMENT();
    return n1_xmsz;
    
//------------------------------------------------------------------------------
//Apply molting/growth/maturity to population numbers    
FUNCTION dvar4_array applyMGM(dvar4_array& n0_xmsz, int y, int debug, ostream& cout)
    if (debug>dbgApply) cout<<"starting applyMGM("<<y<<")"<<endl;
    RETURN_ARRAYS_INCREMENT();
    dvar4_array n1_xmsz(1,nSXs,1,nMSs,1,nSCs,1,nZBs);
    n1_xmsz.initialize();
    for (int x=1;x<=nSXs;x++){
        n1_xmsz(x,IMMATURE,NEW_SHELL) = prGr_yxmzz(y,x,IMMATURE)*elem_prod(1.0-prMat_yxz(y,x),n0_xmsz(x,IMMATURE,NEW_SHELL));
        n1_xmsz(x,IMMATURE,OLD_SHELL) = 0.0;
        n1_xmsz(x,MATURE,NEW_SHELL)   = prGr_yxmzz(y,x,MATURE)  *elem_prod(    prMat_yxz(y,x),n0_xmsz(x,IMMATURE,NEW_SHELL));
        n1_xmsz(x,MATURE,OLD_SHELL)   = n0_xmsz(x,MATURE,NEW_SHELL)+n0_xmsz(x,MATURE,OLD_SHELL);
    }
    if (debug>dbgApply) cout<<"finished applyNatMGM("<<y<<")"<<endl;
    RETURN_ARRAYS_DECREMENT();
    return n1_xmsz;
    
//-------------------------------------------------------------------------------------
//calculate recruitment.
FUNCTION void calcRecruitment(int debug, ostream& cout)
    if (debug>dbgCalcProcs) cout<<"starting calcRecruitment()"<<endl;

    RecruitmentInfo* ptrRI = ptrMPI->ptrRec;
    
    R_y.initialize();
    Rx_c.initialize();
    R_yx.initialize();
    R_cz.initialize();
    R_yz.initialize();
    stdvDevsLnR_cy.initialize();
    zscrDevsLnR_cy.initialize();
    
    int k; int y;
    dvector dzs = zBs+(zBs[2]-zBs[1])/2.0-zBs[1];
    for (int pc=1;pc<=ptrRI->nPCs;pc++){
        ivector pids = ptrRI->getPCIDs(pc);
        k=ptrRI->nIVs+1;//first parameter variable column in ParameterComnbinations
        dvariable mnLnR    = pLnR(pids[k++]);
        dvariable lnRCV    = pLnRCV(pids[k++]);
        dvariable lgtRX    = pLgtRX(pids[k++]);
        dvariable lnRa     = pLnRa(pids[k++]);
        dvariable lnRb     = pLnRb(pids[k++]);
        if (debug>dbgCalcProcs){
            cout<<"pids  = "<<pids<<endl;
            cout<<"mnLnR = "<<mnLnR<<endl;
            cout<<"lnRCV = "<<lnRCV<<endl;
            cout<<"lgtRX = "<<lgtRX<<endl;
            cout<<"lnRa  = "<<lnRa<<endl;
            cout<<"lnRb  = "<<lnRb<<endl;
        }

        int useDevs = pids[k]; k++;
        dvariable mdR;
        dvar_vector dvsLnR;
        ivector idxDevsLnR;
        if (useDevs) {
            dvsLnR     = devsLnR(useDevs);
            idxDevsLnR = idxsDevsLnR(useDevs);
            if (debug>dbgCalcProcs) {
                cout<<"lims(dvsLnR) = "<<dvsLnR.indexmin()<<cc<<dvsLnR.indexmax()<<endl;
                cout<<"idx(dvsLnR) = "<<idxDevsLnR<<endl;
                cout<<"dvsLnR = "<<dvsLnR<<endl;
            }
        } else {
            mdR = mfexp(mnLnR);
        }
        
        Rx_c(pc) = 1.0/(1.0+mfexp(-lgtRX));
        R_cz(pc) = elem_prod(pow(dzs,mfexp(lnRa-lnRb)-1.0),mfexp(-dzs/mfexp(lnRb)));
        R_cz(pc) /= sum(R_cz(pc));//normalize to sum to 1

        imatrix idxs = ptrRI->getModelIndices(pc);
        for (int idx=idxs.indexmin();idx<=idxs.indexmax();idx++){
            y = idxs(idx,1);
            if ((mnYr<=y)&&(y<=mxYr)){
                if (debug>dbgCalcProcs+10) cout<<"y,i = "<<y<<tb<<idxDevsLnR(y)<<endl;
                if (useDevs){
                    R_y(y) = mfexp(mnLnR+dvsLnR[idxDevsLnR[y]]);
                } else {
                    R_y(y) = mdR;
                }
                if (debug>dbgCalcProcs+10) cout<<"R_y(y)="<<R_y(y)<<tb;
                R_yx(y,MALE)   = Rx_c(pc);
                if (debug>dbgCalcProcs+10) cout<<R_yx(y,MALE)<<endl;
                if (FEMALE<=nSXs) R_yx(y,FEMALE) = 1.0-R_yx(y,MALE);

                R_yz(y) = R_cz(pc);
                if (debug>dbgCalcProcs+10) cout<<"R_yz(y)="<<R_yz(y)<<endl;

                stdvDevsLnR_cy(pc,y) = sqrt(log(1.0+mfexp(2.0*lnRCV)));           //ln-scale std dev
                zscrDevsLnR_cy(pc,y) = dvsLnR(idxDevsLnR(y))/stdvDevsLnR_cy(pc,y);//standardized ln-scale rec devs
            } else {
                if (debug>dbgCalcProcs) cout<<"skipping y,i = "<<y<<tb<<idxDevsLnR(y)<<endl;
            }
        }//idx
    }//pc
    
    if (debug>dbgCalcProcs) {
        cout<<"R_y = "<<R_y<<endl;
        cout<<"R_yx(MALE) = "<<column(R_yx,MALE)<<endl;
        cout<<"R_yz = "<<endl<<R_yz<<endl;
        cout<<"zscr = "<<zscrDevsLnR_cy<<endl;
        cout<<"finished calcRecruitment()"<<endl;
    }

//******************************************************************************
//* Function: void calcNatMort(void)
//* 
//* Description: Calculates natural mortality rates for all years.
//* 
//* Inputs:
//*  none
//* Returns:
//*  void
//* Alters:
//*  M_yxmz - year/sex/maturity state/size-specific natural mortality rate
//******************************************************************************
FUNCTION void calcNatMort(int debug, ostream& cout)  
    if(debug>dbgCalcProcs) cout<<"Starting calcNatMort()"<<endl;
    
    NaturalMortalityInfo* ptrNM = ptrMPI->ptrNM;
    
    dvar_matrix lnM(1,nSXs,1,nMSs);
    dvar3_array M_xmz(1,nSXs,1,nMSs,1,nZBs);
    
    M_cxm.initialize();
    M_yxmz.initialize();

    int y; 
    for (int pc=1;pc<=ptrNM->nPCs;pc++){
        lnM.initialize();
        ivector pids = ptrNM->getPCIDs(pc);
        int k=ptrNM->nIVs+1;//1st parameter variable column
        //add in base (ln-scale) natural mortality (mature males)
        if (pids[k]) {for (int x=1;x<=nSXs;x++) lnM(x) += pLnM(pids[k]);}   k++;
        //add in main temporal offsets
        if (pids[k]) {for (int x=1;x<=nSXs;x++) lnM(x) += pLnDMT(pids[k]);} k++;
        if (FEMALE<=nSXs){
            //add in female offset
            if (pids[k]) {lnM(FEMALE) += pLnDMX(pids[k]);}                      k++;
            //add in immature offsets
            if (pids[k]) {for (int x=1;x<=nSXs;x++) lnM(x,IMMATURE) += pLnDMM(pids[k]);} k++;
            //add in offset immature females for stanza
            if (pids[k]) {lnM(FEMALE,IMMATURE) += pLnDMXM(pids[k]);}            k++; //advance k to zScaling in pids
        }
        
        //convert from ln-scale to arithmetic scale
        M_cxm(pc) = mfexp(lnM);
        if (debug>dbgCalcProcs){
            cout<<"pc: "<<pc<<tb<<"lnM:"<<endl<<lnM<<endl;
            cout<<"pc: "<<pc<<tb<<"M_xm:"<<endl<<M_cxm(pc)<<endl;
        }
        
        //add in size-scaling, if requested
        M_xmz.initialize();
        for (int x=1;x<=nSXs;x++){
            for (int m=1;m<=nMSs;m++){
                if (pids[k]&&(current_phase()>=pids[k])) {
                    M_xmz(x,m) = M_cxm(pc,x,m)*(zMref/zBs);//factor in size dependence
                } else {
                    M_xmz(x,m) = M_cxm(pc,x,m);//no size dependence
                }
            }
        }
        
        //loop over model indices as defined in the index blocks
        imatrix idxs = ptrNM->getModelIndices(pc);
        for (int idx=idxs.indexmin();idx<=idxs.indexmax();idx++){
            y = idxs(idx,1);//only model index for natural mortality is year
            if ((mnYr<=y)&&(y<=mxYr)){
                for (int x=1;x<=nSXs;x++){
                    for (int m=1;m<=nMSs;m++){
                        M_yxmz(y,x,m) = M_xmz(x,m);
                    }
                }
            }
        }
    }
    if (debug>dbgCalcProcs) cout<<"Finished calcNatMort()"<<endl;
    
//-------------------------------------------------------------------------------------
//calculate Pr(maturity-at-size)
FUNCTION void calcMaturity(int debug, ostream& cout)
    if (debug>dbgCalcProcs) cout<<"starting calcMaturity()"<<endl;

    MaturityInfo* ptrMI = ptrMPI->ptrMat;
    
    prMat_cz.initialize();
    prMat_yxz.initialize();
    
    int k; int y; int x;
    for (int pc=1;pc<=ptrMI->nPCs;pc++){
        ivector pids = ptrMI->getPCIDs(pc);
        k=ptrMI->nIVs+1;//first parameter variable column in ParameterComnbinations
        dvar_vector lgtPrMat = pLgtPrMat(pids[k++]);
        int vmn = lgtPrMat.indexmin();
        int vmx = lgtPrMat.indexmax();
        if (debug>dbgCalcProcs){
            cout<<"pc = "<<pc<<". mn = "<<vmn<<", mx = "<<vmx<<endl;
            cout<<"lgtPrMat = "<<lgtPrMat<<endl;
        }

        prMat_cz(pc) = 1.0;//default is 1
        prMat_cz(pc)(vmn,vmx) = 1.0/(1.0+mfexp(-lgtPrMat));
            
        imatrix idxs = ptrMI->getModelIndices(pc);
        if (debug>dbgCalcProcs) cout<<"maturity indices"<<endl<<idxs<<endl;
        for (int idx=idxs.indexmin();idx<=idxs.indexmax();idx++){
            y = idxs(idx,1);
            if ((mnYr<=y)&&(y<=mxYr)){
                x = idxs(idx,2);
                if (debug>dbgCalcProcs) cout<<"y = "<<y<<tb<<"sex = "<<tcsam::getSexType(x)<<endl;
                prMat_yxz(y,x) = prMat_cz(pc);//note: this change made a difference, but not sure why!
            }
        }
    }
    
    if (debug>dbgCalcProcs) cout<<"finished calcMaturity()"<<endl;

//******************************************************************************
//* Function: void calcGrowth(void)
//* 
//* Description: Calculates growth transition matrices for all years.
//* 
//* Inputs:
//*  none
//* Returns:
//*  void
//* Alters:
//*  prGr_yxmzz - year/sex/maturity state/size-specific growth transition matrices
//******************************************************************************
FUNCTION void calcGrowth(int debug, ostream& cout)  
    if(debug>dbgCalcProcs) cout<<"Starting calcGrowth()"<<endl;
    
    GrowthInfo* ptrGrI = ptrMPI->ptrGr;
    
    dvariable grA;
    dvariable grB;
    dvariable grBeta;
    
    prGr_czz.initialize();
    prGr_yxmzz.initialize();
    
    dvar_matrix prGr_zz(1,nZBs,1,nZBs);

    int y; int x;
    for (int pc=1;pc<=ptrGrI->nPCs;pc++){
        ivector pids = ptrGrI->getPCIDs(pc);
        int k=ptrGrI->nIVs+1;//1st parameter column
        grA = mfexp(pLnGrA(pids[k])); k++; //"a" coefficient for mean growth
        grB = mfexp(pLnGrB(pids[k])); k++; //"b" coefficient for mean growth
        grBeta = mfexp(pLnGrBeta(pids[k])); k++; //shape factor for gamma function growth transition
        if (debug>dbgCalcProcs){
            cout<<"pc: "<<pc<<tb<<"grA:"<<tb<<grA<<". grB:"<<tb<<grB<<". grBeta:"<<grBeta<<endl;
        }
        
        //compute growth transition matrix for this pc
        prGr_zz.initialize();
        dvar_vector mnZ = mfexp(grA)*pow(zBs,grB);//mean size after growth from zBs
        dvar_vector alZ = (mnZ-zBs)/grBeta;//scaled mean growth increment from zBs
        for (int z=1;z<nZBs;z++){//pre-molt growth bin
            dvar_vector dZs =  zBs(z,nZBs) - zBs(z);//realized growth increments (note non-neg. growth only)
            if (debug) cout<<"dZs: "<<dZs.indexmin()<<":"<<dZs.indexmax()<<endl;
            dvar_vector prs = elem_prod(pow(dZs,alZ(z)-1.0),mfexp(-dZs/grBeta)); //pr(dZ|z)
            if (debug) cout<<"prs: "<<prs.indexmin()<<":"<<prs.indexmax()<<endl;
            if (prs.size()>10) prs(z+10,nZBs) = 0.0;//limit growth range TODO: this assumes bin size is 5 mm
            if (debug) cout<<prs<<endl;
            prs = prs/sum(prs);//normalize to sum to 1
            if (debug) cout<<prs<<endl;
            prGr_zz(z)(z,nZBs) = prs;
        }
        prGr_zz(nZBs,nZBs) = 1.0; //no growth from max size
        prGr_czz(pc) = trans(prGr_zz);//transpose so rows are post-molt (i.e., "to") z's so n+ = prGr_zz*n
        
        //loop over model indices as defined in the index blocks
        imatrix idxs = ptrGrI->getModelIndices(pc);
        if (debug) cout<<"growth indices"<<endl<<idxs<<endl;
        for (int idx=idxs.indexmin();idx<=idxs.indexmax();idx++){
            y = idxs(idx,1); //year index
            if ((mnYr<=y)&&(y<=mxYr)){
                x = idxs(idx,2); //sex index
                for (int m=1;m<=nMSs;m++){
                    for (int z=1;z<=nZBs;z++){
                        prGr_yxmzz(y,x,m,z) = prGr_czz(pc,z);
                    }
                }
            }
        }
    }
    
    if (debug>dbgCalcProcs) cout<<"finished calcGrowth()"<<endl;

//******************************************************************************
//* Function: void calcSelectivities(int debug=0, ostream& cout=std::cout)
//* 
//* Description: Calculates all selectivity functions.
//* 
//* Required inputs:
//*  none
//* Returns:
//*  void
//* Alters:
//*  sel_iyz - selectivity array
//******************************************************************************
FUNCTION void calcSelectivities(int debug, ostream& cout)  
    if(debug>dbgCalcProcs) cout<<"Starting calcSelectivities()"<<endl;
    
    SelectivityInfo* ptrSel = ptrMPI->ptrSel;

    double fsZ;             //fully selected size
    int idSel;              //selectivity function id
    int idxFSZ = ptrSel->nIVs+ptrSel->nPVs+1;//index for fsZ in pids vector below
    
    ivector mniSelDevs(1,6);//min indices of devs vectors
    ivector mxiSelDevs(1,6);//max indices of devs vectors
    dvar_vector params(1,6);//vector for number_vector params
        
    sel_cz.initialize();//selectivities w/out deviations
    sel_iyz.initialize();//selectivity array

    int y;
    for (int pc=1;pc<=ptrSel->nPCs;pc++){
        params.initialize();
        ivector pids = ptrSel->getPCIDs(pc);
        //extract the number parameters
        int k=ptrSel->nIVs+1;//1st parameter variable column
        if (pids[k]) {params[1] = pS1(pids[k]);}   k++;
        if (pids[k]) {params[2] = pS2(pids[k]);}   k++;
        if (pids[k]) {params[3] = pS3(pids[k]);}   k++;
        if (pids[k]) {params[4] = pS4(pids[k]);}   k++;
        if (pids[k]) {params[5] = pS5(pids[k]);}   k++;
        if (pids[k]) {params[6] = pS6(pids[k]);}   k++;
        if (debug>dbgCalcProcs) {
            cout<<"pc: "<<pc<<tb<<"pids = "<<pids<<endl;
            cout<<tb<<"params:"<<tb<<params<<endl;
        }
        
        int useDevsS1=pids[k++];
        dvar_vector dvsS1; ivector idxDevsS1;
        if (useDevsS1){
            dvsS1 = devsS1(useDevsS1);
            idxDevsS1 = idxsDevsS1(useDevsS1);
            if (debug>dbgCalcProcs){
                cout<<"idx(dvsS1) = "<<idxDevsS1<<endl;
                cout<<"dvsS1      = "<<dvsS1<<endl;
            }
        }
        int useDevsS2=pids[k++];
        dvar_vector dvsS2; ivector idxDevsS2;
        if (useDevsS2){
            dvsS2 = devsS2(useDevsS2);
            idxDevsS2 = idxsDevsS2(useDevsS2);
            if (debug>dbgCalcProcs){
                cout<<"idx(dvsS2) = "<<idxDevsS2<<endl;
                cout<<"dvsS2      = "<<dvsS2<<endl;
            }
        }
        int useDevsS3=pids[k++];
        dvar_vector dvsS3; ivector idxDevsS3;
        if (useDevsS3){
            dvsS3 = devsS3(useDevsS3);
            idxDevsS3 = idxsDevsS3(useDevsS3);
            if (debug>dbgCalcProcs){
                cout<<"idx(dvsS3) = "<<idxDevsS3<<endl;
                cout<<"dvsS3      = "<<dvsS3<<endl;
            }
        }
        int useDevsS4=pids[k++];
        dvar_vector dvsS4; ivector idxDevsS4;
        if (useDevsS4){
            dvsS4 = devsS4(useDevsS4);
            idxDevsS4 = idxsDevsS4(useDevsS4);
            if (debug>dbgCalcProcs){
                cout<<"idx(dvsS4) = "<<idxDevsS4<<endl;
                cout<<"dvsS4      = "<<dvsS4<<endl;
            }
        }
        int useDevsS5=pids[k++];
        dvar_vector dvsS5; ivector idxDevsS5;
        if (useDevsS5){
            dvsS5 = devsS5(useDevsS5);
            idxDevsS5 = idxsDevsS5(useDevsS5);
            if (debug>dbgCalcProcs){
                cout<<"idx(dvsS5) = "<<idxDevsS5<<endl;
                cout<<"dvsS5      = "<<dvsS5<<endl;
            }
        }
        int useDevsS6=pids[k++];
        dvar_vector dvsS6; ivector idxDevsS6;
        if (useDevsS6){
            dvsS6 = devsS6(useDevsS6);
            idxDevsS6 = idxsDevsS6(useDevsS6);
            if (debug>dbgCalcProcs){
                cout<<"idx(dvsS6) = "<<idxDevsS6<<endl;
                cout<<"dvsS6      = "<<dvsS6<<endl;
            }
        }

        fsZ   = pids[idxFSZ];
        idSel = pids[idxFSZ+1];
        if (debug>dbgCalcProcs) cout<<tb<<"fsZ: "<<fsZ<<tb<<"idSel"<<tb<<idSel<<tb<<SelFcns::getSelFcnID(idSel)<<endl;;

        sel_cz(pc) = SelFcns::calcSelFcn(idSel, zBs, params, fsZ);
            
        //loop over model indices as defined in the index blocks
        imatrix idxs = ptrSel->getModelIndices(pc);
        for (int idx=idxs.indexmin();idx<=idxs.indexmax();idx++){
            y = idxs(idx,1);//year
            if ((mnYr<=y)&&(y<=mxYr+1)){
                k=ptrSel->nIVs+1+6;//1st devs vector variable column
                if (useDevsS1) {params[1] += devsS1(useDevsS1,idxDevsS1[y]);}
                if (useDevsS2) {params[2] += devsS2(useDevsS2,idxDevsS2[y]);}
                if (useDevsS3) {params[3] += devsS3(useDevsS3,idxDevsS3[y]);}
                if (useDevsS4) {params[4] += devsS4(useDevsS4,idxDevsS4[y]);}
                if (useDevsS5) {params[5] += devsS5(useDevsS5,idxDevsS5[y]);}
                if (useDevsS6) {params[6] += devsS6(useDevsS6,idxDevsS6[y]);}
                sel_iyz(pc,y) = SelFcns::calcSelFcn(idSel, zBs, params, fsZ);
                if (debug>dbgCalcProcs) cout<<tb<<"y = "<<y<<tb<<"sel: "<<sel_iyz(pc,y)<<endl;
            } else {
                if (debug>dbgCalcProcs) cout<<tb<<"y = "<<y<<tb<<"y outside model range--skipping year!"<<endl;
            }
        }
    }
    if (debug>dbgCalcProcs) cout<<"finished calcSelectivities()"<<endl;

//******************************************************************************
//* Function: void calcFisheryFs(int debug, ostream& cout)
//* 
//* Description: Calculates fishery F's for all years.
//* 
//* Inputs:
//*  none
//* Returns:
//*  void
//* Alters:
//*  cF_fyxms  - fully-selected fishery/year/sex/maturity state/shell condition-specific capture rate
//*  cF_fyxmsz - fishery/year/sex/maturity state/shell condition/size-specific capture rate
//*  rmF_fyxmsz - fishery/year/sex/maturity state/shell condition/size-specific retained mortality rate
//*  dmF_fyxmsz - fishery/year/sex/maturity state/shell condition/size-specific discard mortality rate
//******************************************************************************
FUNCTION void calcFisheryFs(int debug, ostream& cout)  
    if(debug>dbgCalcProcs) cout<<"Starting calcFisheryFs()"<<endl;
    
    FisheriesInfo* ptrFsh = ptrMPI->ptrFsh;
    
    dvariable hm;                   //handling mortality
    dvar_matrix lnC(1,nSXs,1,nMSs); //ln-scale capture rate
    dvar_matrix C_xm(1,nSXs,1,nMSs);//arithmetic-scale capture rate
    
    dvsLnC_fy.initialize();
    for (int f=1;f<=nFsh;f++) idxDevsLnC_fy(f) = -1;
    
    Fhm_fy.initialize();   //handling mortality
    cF_fyxms.initialize(); //fully-selected capture rate
    cF_fyxmsz.initialize();//size-specific capture rate
    rmF_fyxmsz.initialize();//retention rate
    dmF_fyxmsz.initialize();//discard mortality rate
    tmF_yxmsz.initialize(); //total mortality rate
    
    /******************************************************\n
     * Fully-selected annual capture rates are calculated  \n
     * using 2 approaches:                                 \n
     *  1. from parameter values (if useER=0 below)        \n
     *  2. based on effort and the average ratio between   \n
     *     effort and capture rates over some time period  \n
     *     in the fishery        (if useER=1 below)        \n
     * Consequently, calculating all the above quantities  \n
     * requires 2 passes through parameter combinations.   \n
    ******************************************************/

    int idxER = ptrFsh->idxUseER;//index into pids below for flag to use effort ratio
    int y; int f; int x; int idSel; int idRet; int useER; int useDevs;
    //Pass 1: calculations based on parameter values
    for (int pc=1;pc<=ptrFsh->nPCs;pc++){
        ivector pids = ptrFsh->getPCIDs(pc);
        if (debug>dbgCalcProcs) cout<<"pc: "<<pc<<tb<<"pids: "<<pids<<endl;
        useER = pids[idxER];//flag to use effort ratio
        if (!useER){//calculate capture rates from parameters
            lnC.initialize();
            C_xm.initialize();
            int k=ptrFsh->nIVs+1;//1st parameter variable column
            //get handling mortality (default to 1)
            hm = 1.0;
            if (pids[k]) {hm = pHM(pids[k]);}                                   k++;
            //set base (ln-scale) capture rate (mature males)
            if (pids[k]) {for (int x=1;x<=nSXs;x++) lnC(x) += pLnC(pids[k]);}   k++;
            //add in main temporal offsets
            if (pids[k]) {for (int x=1;x<=nSXs;x++) lnC(x) += pLnDCT(pids[k]);} k++;
            if (FEMALE<=nSXs){
                //add in female offset
                if (pids[k]) {lnC(FEMALE) += pLnDCX(pids[k]);}                      k++;
                //add in immature offsets
                if (pids[k]) {for (int x=1;x<=nSXs;x++) lnC(x,IMMATURE) += pLnDCM(pids[k]);} k++;
                //add in offset immature females for stanza
                if (pids[k]) {lnC(FEMALE,IMMATURE) += pLnDCXM(pids[k]);}            k++; 
            }

            //extract devs vector
            useDevs = pids[k]; k++;
            dvar_vector dvsLnC;             
            ivector idxDevsLnC;
            if (useDevs) {
                dvsLnC     = devsLnC(useDevs);
                idxDevsLnC = idxsDevsLnC(useDevs);
                if (debug>dbgCalcProcs){
                    cout<<"y   idx    devsLnC"<<endl;
                    for (int i=idxDevsLnC.indexmin();i<=idxDevsLnC.indexmax();i++) {
                        cout<<i<<tb<<idxDevsLnC(i)<<tb;
                        if (idxDevsLnC(i)) cout<<dvsLnC[idxDevsLnC(i)];
                        cout<<endl;
                    }
                }
            } else {
                C_xm = mfexp(lnC);
            }
            
            k = ptrFsh->nIVs+ptrFsh->nPVs+1;//1st extra variable column
            idSel = pids[k++];//selectivity function id
            idRet = pids[k++];//retention function id
        
            //convert from ln-scale to arithmetic scale
            if (debug>dbgCalcProcs){
                cout<<"pc: "<<pc<<". idSel = "<<idSel<<". idRet = "<<idRet<<"."<<endl;
                cout<<tb<<tb<<"lnC:"<<endl<<lnC<<endl;
                if (useDevs) {
                    cout<<tb<<tb<<"dvsLnC["<<dvsLnC.indexmin()<<cc<<dvsLnC.indexmax()<<"] = "<<dvsLnC<<endl;
                } else {
                    cout<<tb<<tb<<"C_xm:"<<endl<<C_xm<<endl;
                }
            }

            //loop over model indices as defined in the index blocks
            imatrix idxs = ptrFsh->getModelIndices(pc);
            for (int idx=idxs.indexmin();idx<=idxs.indexmax();idx++){
                f = idxs(idx,1);//fishery
                y = idxs(idx,2);//year
                if ((mnYr<=y)&&(y<=mxYr)){
                    x = idxs(idx,3);//sex
                    if (debug>dbgCalcProcs) cout<<"f,y,x,useDevs = "<<f<<cc<<y<<cc<<x<<cc<<useDevs<<endl;
                    if (useDevs) {
                        idxDevsLnC_fy(f,y) = idxDevsLnC[y];
                        dvsLnC_fy(f,y)     = dvsLnC[idxDevsLnC[y]];
                        C_xm = mfexp(lnC+dvsLnC[idxDevsLnC[y]]);//recalculate C_xm w/ devs
                    }
                    for (int m=1;m<=nMSs;m++){
                        for (int s=1;s<=nSCs;s++){
                            cF_fyxms(f,y,x,m,s)  = C_xm(x,m);                 //fully-selected capture rate
                            cF_fyxmsz(f,y,x,m,s) = C_xm(x,m)*sel_iyz(idSel,y);//size-specific capture rate
                            if (idRet){//fishery has retention
                                rmF_fyxmsz(f,y,x,m,s) = elem_prod(sel_iyz(idRet,y),         cF_fyxmsz(f,y,x,m,s));//retention mortality
                                dmF_fyxmsz(f,y,x,m,s) = elem_prod(hm*(1.0-sel_iyz(idRet,y)),cF_fyxmsz(f,y,x,m,s));//discard mortality
                            } else {//discard only
                                dmF_fyxmsz(f,y,x,m,s) = hm*cF_fyxmsz(f,y,x,m,s);//discard mortality
                            }
                        }
                    }
                }
            }
        }//useER=FALSE
    }
    if (debug) cout<<"finished pass 1"<<endl;
    
    //calculate ratio of average capture rate to effort
    if (debug>dbgCalcProcs) cout<<"calculating avgRatioFc2Eff"<<endl;
    dvariable tot;
    for (int f=1;f<=nFsh;f++){//model fishery objects
        int fd = mapM2DFsh(f);//index of corresponding fishery data object
        if (ptrMDS->ppFsh[fd-1]->ptrEff){
            IndexRange* pir = ptrMDS->ppFsh[fd-1]->ptrEff->ptrAvgIR;
            int mny = max(mnYr,pir->getMin());//adjust for model min
            int mxy = min(mxYr,pir->getMax());//adjust for model max
            if (debug>dbgCalcProcs) cout<<"f,mny,mxy = "<<f<<tb<<mny<<tb<<mxy<<endl;
            for (int x=1;x<=nSXs;x++){
                for (int m=1;m<=nMSs;m++){
                    for (int s=1;s<=nSCs;s++){
                        tot.initialize();
                        switch (optsFcAvg(f)){
                            case 1:
                                for (int y=mny;y<=mxy;y++) tot += cF_fyxms(f,y,x,m,s);
                                avgFc(f,x,m,s) = tot/(mxy-mny+1); break;
                            case 2:
                                for (int y=mny;y<=mxy;y++) tot += 1.0-mfexp(-cF_fyxms(f,y,x,m,s));
                                avgFc(f,x,m,s) = tot/(mxy-mny+1); break;
                            case 3:
                                for (int y=mny;y<=mxy;y++) tot += mean(cF_fyxmsz(f,y,x,m,s));
                                avgFc(f,x,m,s) = tot/(mxy-mny+1); break;
                            default:
                                cout<<"optsFcAvg("<<f<<") = "<<optsFcAvg(f)<<" to calculate average Fc is invalid."<<endl;
                                cout<<"Aborting..."<<endl;
                                exit(-1);
                        }
                        avgRatioFc2Eff(f,x,m,s) = avgFc(f,x,m,s)/avgEff(f);
                    }
                }
            }
        }
    }
    if (debug>dbgCalcProcs) cout<<"calculated avgRatioFc2Eff"<<endl;
    
    //Pass 2: calculations based on effort and average effort:capture rate ratios
    int fd; double eff;
    for (int pc=1;pc<=ptrFsh->nPCs;pc++){
        ivector pids = ptrFsh->getPCIDs(pc);
        useER = pids[idxER];//flag to use effort ratio
        if (useER){//calculate capture rates from parameters
            int k=ptrFsh->nIVs+1;//1st parameter variable column
            //get handling mortality (default to 1)
            hm = 1.0;
            if (pids[k]) {hm = pHM(pids[k]);} k++;
            
            k = ptrFsh->nIVs+ptrFsh->nPVs+1;//1st extra variable column
            idSel = pids[k++];   //selectivity function id
            idRet = pids[k++];   //retention function id
            
            if (debug>dbgCalcProcs) cout<<"pc: "<<pc<<". hm = "<<hm<<". idSel = "<<idSel<<". idRet = "<<idRet<<". Using ER"<<endl;

            //loop over model indices as defined in the index blocks
            imatrix idxs = ptrFsh->getModelIndices(pc);
            for (int idx=idxs.indexmin();idx<=idxs.indexmax();idx++){
                f = idxs(idx,1);//fishery
                y = idxs(idx,2);//year
                if ((mnYr<=y)&&(y<=mxYr)){
                    x = idxs(idx,3);//sex
                    fd = mapM2DFsh(f);//index of corresponding fishery data object
                    eff = ptrMDS->ppFsh[fd-1]->ptrEff->eff_y(y);
                    if (debug>dbgCalcProcs) cout<<"f,y,x,eff = "<<f<<tb<<y<<tb<<x<<tb<<eff<<endl;
                    for (int m=1;m<=nMSs;m++){
                        for (int s=1;s<=nSCs;s++){
                            //fully-selected capture rate
                            switch(optsFcAvg(f)) {
                                case 1:
                                    cF_fyxms(f,y,x,m,s) = avgRatioFc2Eff(f,x,m,s)*eff; break;
                                case 2:
                                    cF_fyxms(f,y,x,m,s) = -log(1.0-avgRatioFc2Eff(f,x,m,s)*eff); break;
                                case 3:
                                    cF_fyxms(f,y,x,m,s) = avgRatioFc2Eff(f,x,m,s)*eff; break;
                            }
                            cF_fyxmsz(f,y,x,m,s) = cF_fyxms(f,y,x,m,s)*sel_iyz(idSel,y);//size-specific capture rate
                            if (idRet){//fishery has retention
                                rmF_fyxmsz(f,y,x,m,s) = elem_prod(sel_iyz(idRet,y),         cF_fyxmsz(f,y,x,m,s));//retention mortality rate
                                dmF_fyxmsz(f,y,x,m,s) = elem_prod(hm*(1.0-sel_iyz(idRet,y)),cF_fyxmsz(f,y,x,m,s));//discard mortality rate
                            } else {//discard only
                                dmF_fyxmsz(f,y,x,m,s) = hm*cF_fyxmsz(f,y,x,m,s);//discard mortality rate
                            }
                        }
                    }
                }
            }
        }//useER=TRUE
    }
    if (debug>dbgCalcProcs) cout<<"finished pass 2."<<endl;
    if (debug>dbgCalcProcs) cout<<"finished calcFisheryFs()"<<endl;

//******************************************************************************
//* Function: void calcSurveyQs(int debug, ostream& cout)
//* 
//* Description: Calculates survey catchabilities for all years.
//* 
//* Inputs:
//*  none
//* Returns:
//*  void
//* Alters:
//*  q_vyxms  - fully-selected survey/year/sex/maturity state/shell condition-specific catchability
//*  q_vyxmsz - survey/year/sex/maturity state/shell condition/size-specific catchability
//******************************************************************************
FUNCTION void calcSurveyQs(int debug, ostream& cout)  
    if(debug>dbgCalcProcs) cout<<"Starting calcSurveyQs()"<<endl;
    
    SurveysInfo* ptrSrv = ptrMPI->ptrSrv;
    
    dvar_matrix lnQ(1,nSXs,1,nMSs);
    dvar_matrix Q_xm(1,nSXs,1,nMSs);
    
    q_vyxms.initialize();
    q_vyxmsz.initialize();

    int y; int v; int x; int idSel;
    for (int pc=1;pc<=ptrSrv->nPCs;pc++){
        lnQ.initialize();
        Q_xm.initialize();
        ivector pids = ptrSrv->getPCIDs(pc);
        int k=ptrSrv->nIVs+1;//1st parameter variable column
        //add in base (ln-scale) catchability (mature males)
        if (pids[k]) {for (int x=1;x<=nSXs;x++) lnQ(x) += pLnQ(pids[k]);}   k++;
        //add in main temporal offsets
        if (pids[k]) {for (int x=1;x<=nSXs;x++) lnQ(x) += pLnDQT(pids[k]);} k++;
        if (FEMALE<=nSXs){
            //add in female offset
            if (pids[k]) {lnQ(FEMALE) += pLnDQX(pids[k]);}                      k++;
            //add in immature offsets
            if (pids[k]) {for (int x=1;x<=nSXs;x++) lnQ(x,IMMATURE) += pLnDQM(pids[k]);} k++;
            //add in offset immature females for stanza
            if (pids[k]) {lnQ(FEMALE,IMMATURE) += pLnDQXM(pids[k]);}            k++; 
        }
        
        idSel = pids[k];//selectivity function id
        
        //convert from ln-scale to arithmetic scale
        Q_xm = mfexp(lnQ);
        if (debug>dbgCalcProcs){
            cout<<"pc: "<<pc<<tb<<"lnQ:"<<endl<<lnQ<<endl;
            cout<<"pc: "<<pc<<tb<<"Q_xm:"<<endl<<Q_xm<<endl;
        }
        
        //loop over model indices as defined in the index blocks
        imatrix idxs = ptrSrv->getModelIndices(pc);
        for (int idx=idxs.indexmin();idx<=idxs.indexmax();idx++){
            v = idxs(idx,1);//survey
            y = idxs(idx,2);//year
            if ((mnYr<=y)&&(y<=mxYrp1)){
                x = idxs(idx,3);//sex
                if (y <= mxYr+1){
                    for (int m=1;m<=nMSs;m++){
                        for (int s=1;s<=nSCs;s++){
                            q_vyxms(v,y,x,m,s)  = Q_xm(x,m);
                            q_vyxmsz(v,y,x,m,s) = Q_xm(x,m)*sel_iyz(idSel,y);
                        }
                    }
                }
            }
        }
    }
    if (debug>dbgCalcProcs) cout<<"finished calcSurveyQs()"<<endl;
    
//-------------------------------------------------------------------------------------
//Calculate penalties for objective function. TODO: finish
FUNCTION void calcPenalties(int debug, ostream& cout)
    if (debug>=dbgObjFun) cout<<"Started calcPenalties()"<<endl;
    if (debug<0) cout<<"list("<<endl;//start list of penalties by category

    if (debug<0) cout<<tb<<"maturity=list("<<endl;//start of maturity penalties list
    //smoothness penalties on maturity parameters (NOT maturity ogives)
    double penWgtLgtPrMat = 1.0;//TODO: read in value from input file
    fPenSmoothLgtPrMat.initialize();
    if (debug<0) cout<<tb<<tb<<"smoothness=list(";//start of smoothness penalties list
    for (int i=1;i<npLgtPrMat;i++){
        dvar_vector v; v = 1.0*pLgtPrMat(i);
        fPenSmoothLgtPrMat(i) = norm2(calc2ndDiffs(v));
        objFun += penWgtLgtPrMat*fPenSmoothLgtPrMat(i);
        if (debug<0) cout<<tb<<tb<<tb<<"'"<<i<<"'=list(wgt="<<penWgtLgtPrMat<<cc<<"pen="<<fPenSmoothLgtPrMat(i)<<cc<<"objfun="<<penWgtLgtPrMat*fPenSmoothLgtPrMat(i)<<"),"<<endl;
    }
    {
        int i = npLgtPrMat;
        dvar_vector v; v = 1.0*pLgtPrMat(i);
        fPenSmoothLgtPrMat(i) = norm2(calc2ndDiffs(v));
        objFun += penWgtLgtPrMat*fPenSmoothLgtPrMat(i);
        if (debug<0) cout<<tb<<tb<<tb<<"'"<<i<<"'=list(wgt="<<penWgtLgtPrMat<<cc<<"pen="<<fPenSmoothLgtPrMat(i)<<cc<<"objfun="<<penWgtLgtPrMat*fPenSmoothLgtPrMat(i)<<")"<<endl;
    }
    if (debug<0) cout<<tb<<tb<<")"<<cc<<endl;//end of smoothness penalties list

    //non-decreasing penalties on maturity parameters (NOT maturity ogives)
    double penWgtNonDecLgtPrMat = 1.0;//TODO: read in value from input file
    fPenNonDecLgtPrMat.initialize();
    if (debug<0) cout<<tb<<tb<<"nondecreasing=list(";//start of non-decreasing penalties list
    for (int i=1;i<npLgtPrMat;i++){
        dvar_vector v; v = calc1stDiffs(pLgtPrMat(i));
        for (int iv=v.indexmin();iv<=v.indexmax();iv++){
            posfun2(v(iv),1.0E-2,fPenNonDecLgtPrMat(i));
        }
        objFun += penWgtNonDecLgtPrMat*fPenNonDecLgtPrMat(i);
        if (debug<0) cout<<tb<<tb<<tb<<"'"<<i<<"'=list(wgt="<<penWgtNonDecLgtPrMat<<cc<<"pen="<<fPenNonDecLgtPrMat(i)<<cc<<"objfun="<<penWgtNonDecLgtPrMat*fPenNonDecLgtPrMat(i)<<"),";
    }
    {
        int i = npLgtPrMat;
        dvar_vector v; v = calc1stDiffs(pLgtPrMat(i));
        for (int iv=v.indexmin();iv<=v.indexmax();iv++){
            posfun2(v(iv),1.0E-2,fPenNonDecLgtPrMat(i));
        }
        objFun += penWgtNonDecLgtPrMat*fPenNonDecLgtPrMat(i);
        if (debug<0) cout<<tb<<tb<<tb<<"'"<<i<<"'=list(wgt="<<penWgtNonDecLgtPrMat<<cc<<"pen="<<fPenNonDecLgtPrMat(i)<<cc<<"objfun="<<penWgtNonDecLgtPrMat*fPenNonDecLgtPrMat(i)<<")";
    }
    if (debug<0) cout<<tb<<tb<<")"<<endl;//end of non-decreasing penalties list    
    if (debug<0) cout<<tb<<")";//end of maturity penalties list
    
    if (debug<0) cout<<")";//end of penalties list
    if (debug>=dbgObjFun) cout<<"Finished calcPenalties()"<<endl;

//-------------------------------------------------------------------------------------
//Calculate 1st differences of vector
FUNCTION dvar_vector calc1stDiffs(const dvar_vector& d)
//    cout<<"Starting calc1stDiffs"<<endl;
    RETURN_ARRAYS_INCREMENT();
    int mn = d.indexmin();
    int mx = d.indexmax();
    dvar_vector cp; cp = d;
    dvar_vector r(mn,mx-1);
    r = cp(mn+1,mx).shift(mn)-cp(mn,mx-1);
    RETURN_ARRAYS_DECREMENT();
//    cout<<"Finished calc1stDiffs"<<endl;
    return r;

//-------------------------------------------------------------------------------------
//Calculate 2nd differences of vector
FUNCTION dvar_vector calc2ndDiffs(const dvar_vector& d)
//    cout<<"Starting calc2ndDiffs"<<endl;
    RETURN_ARRAYS_INCREMENT();
    int mn = d.indexmin();
    int mx = d.indexmax();
    dvar_vector r = calc1stDiffs(calc1stDiffs(d));
    RETURN_ARRAYS_DECREMENT();
//    cout<<"Finished calc2ndDiffs"<<endl;
    return r;

//-------------------------------------------------------------------------------------
//Calculate recruitment components in the likelihood.
FUNCTION void calcNLLs_Recruitment(int debug, ostream& cout)
    if (debug>=dbgObjFun) cout<<"Starting calcNLLs_Recruitment"<<endl;
    double nllWgtRecDevs = 1.0;//TODO: read in from input file (as vector?))
    nllRecDevs.initialize();
    if (debug<0) cout<<"list("<<endl;
    if (debug<0) cout<<tb<<"recDevs=list("<<endl;
    for (int pc=1;pc<npcRec;pc++){
        nllRecDevs(pc) = 0.5*norm2(zscrDevsLnR_cy(pc));
        for (int y=mnYr;y<=mxYr;y++) if (value(stdvDevsLnR_cy(pc,y))>0) {nllRecDevs(pc) += log(stdvDevsLnR_cy(pc,y));}
        objFun += nllWgtRecDevs*nllRecDevs(pc);
        if (debug<0){
            cout<<tb<<tb<<"'"<<pc<<"'=list(type='normal',wgt="<<nllWgtRecDevs<<cc<<"nll="<<nllRecDevs(pc)<<cc<<"objfun="<<nllWgtRecDevs*nllRecDevs(pc)<<cc;
            cout<<"zscrs="; wts::writeToR(cout,value(zscrDevsLnR_cy(pc))); cout<<cc;
            cout<<"stdvs="; wts::writeToR(cout,value(stdvDevsLnR_cy(pc))); cout<<")"<<cc<<endl;
        }
    }//pc
    {
        int pc = npcRec;
        nllRecDevs(pc) = 0.5*norm2(zscrDevsLnR_cy(pc));
        for (int y=mnYr;y<=mxYr;y++) if (value(stdvDevsLnR_cy(pc,y))>0) {nllRecDevs(pc) += log(stdvDevsLnR_cy(pc,y));}
        objFun += nllWgtRecDevs*nllRecDevs(pc);
        if (debug<0){
            cout<<tb<<tb<<"'"<<pc<<"'=list(type='normal',wgt="<<nllWgtRecDevs<<cc<<"nll="<<nllRecDevs(pc)<<cc<<"objfun="<<nllWgtRecDevs*nllRecDevs(pc)<<cc;
            cout<<"zscrs="; wts::writeToR(cout,value(zscrDevsLnR_cy(pc))); cout<<cc;
            cout<<"stdvs="; wts::writeToR(cout,value(stdvDevsLnR_cy(pc))); cout<<")"<<endl;
        }
    }//pc
    if (debug<0) cout<<tb<<")";//recDevs
    if (debug<0) cout<<")";
    if (debug>=dbgObjFun) cout<<"Finished calcNLLs_Recruitment"<<endl;

//-------------------------------------------------------------------------------------
//Calculate objective function TODO: finish
FUNCTION void calcObjFun(int debug, ostream& cout)
    if ((debug>=dbgObjFun)||(debug<0)) cout<<"Starting calcObjFun"<<endl;

    //objective function penalties
    calcPenalties(debug,cout);

    //prior likelihoods
    calcAllPriors(debug,cout);

    //recruitment component
    calcNLLs_Recruitment(debug,cout);
    
    //data components
    calcNLLs_Fisheries(debug,cout);
    calcNLLs_Surveys(debug,cout);
    
    if (debug<0) cout<<"total objFun = "<<objFun<<endl;
    if ((debug>=dbgObjFun)||(debug<0)) cout<<"Finished calcObjFun"<<endl<<endl;
    
//-------------------------------------------------------------------------------------
//Calculate norm2 NLL contribution to objective function
FUNCTION void calcNorm2NLL(dvar_vector& mod, dvector& obs, dvector& stdv, ivector& yrs, int debug, ostream& cout)
    if (debug>=dbgAll) cout<<"Starting calcNorm2NLL()"<<endl;
    int y;
    dvariable nll = 0.0;
    dvar_vector zscr(mod.indexmin(),mod.indexmax());
    zscr.initialize();
    for (int i=1;i<=yrs.size();i++){
        y = yrs(i);
        if ((zscr.indexmin()<=y)&&(y<=zscr.indexmax())) {
            zscr(y) = (obs[i]-mod[y]);
        }
    }
    nll += 0.5*norm2(zscr);
    double wgt = 1.0;//TODO: implement likelihood weights
    objFun += wgt*nll;
    if (debug<0){
        adstring obsyrs = wts::to_qcsv(yrs);
        adstring modyrs = str(mod.indexmin())+":"+str(mod.indexmax());
        cout<<"list(nll.type='norm2',wgt="<<wgt<<cc<<"nll="<<nll<<cc<<"objfun="<<wgt*nll<<cc<<endl; 
        cout<<"obs=";   wts::writeToR(cout,obs,        obsyrs); cout<<cc<<endl;
        cout<<"mod=";   wts::writeToR(cout,value(mod), modyrs); cout<<cc<<endl;
        cout<<"stdv=";  wts::writeToR(cout,stdv,       obsyrs); cout<<cc<<endl;
        cout<<"zscrs="; wts::writeToR(cout,value(zscr),modyrs); cout<<")";
    }
    if (debug>=dbgAll) cout<<"Finished calcNorm2NLL()"<<endl;
    
//-------------------------------------------------------------------------------------
//Calculate normal NLL contribution to objective function
FUNCTION void calcNormalNLL(dvar_vector& mod, dvector& obs, dvector& stdv, ivector& yrs, int debug, ostream& cout)
   if (debug>=dbgAll) cout<<"Starting calcNormalNLL()"<<endl;
    int y;
    dvariable nll = 0.0;
    dvar_vector zscr(mod.indexmin(),mod.indexmax());
    zscr.initialize();
    for (int i=1;i<=yrs.size();i++){
        y = yrs(i);
        if ((zscr.indexmin()<=y)&&(y<=zscr.indexmax())) {
            zscr(y) = (obs[i]-mod[y])/stdv[i];
//            nll += log(stdv[i]);
        }
    }
    nll += 0.5*norm2(zscr);
    double wgt = 1.0;//TODO: implement likelihood weights
    objFun += wgt*nll;
    if (debug<0){
        adstring obsyrs = wts::to_qcsv(yrs);
        adstring modyrs = str(mod.indexmin())+":"+str(mod.indexmax());
        cout<<"list(nll.type='normal',wgt="<<wgt<<cc<<"nll="<<nll<<cc<<"objfun="<<wgt*nll<<cc<<endl; 
        cout<<"obs=";   wts::writeToR(cout,obs,        obsyrs); cout<<cc<<endl;
        cout<<"mod=";   wts::writeToR(cout,value(mod), modyrs); cout<<cc<<endl;
        cout<<"stdv=";  wts::writeToR(cout,stdv,       obsyrs); cout<<cc<<endl;
        cout<<"zscrs="; wts::writeToR(cout,value(zscr),modyrs); cout<<")";
    }
   if (debug>=dbgAll) cout<<"Finished calcNormalNLL()"<<endl;
    
//-------------------------------------------------------------------------------------
//Calculate lognormal NLL contribution to objective function
FUNCTION void calcLognormalNLL(dvar_vector& mod, dvector& obs, dvector& stdv, ivector& yrs, int debug, ostream& cout)
    if (debug>=dbgAll) cout<<"Starting calcLognormalNLL()"<<endl;
    int y;
    dvariable nll = 0.0;
    dvar_vector zscr(mod.indexmin(),mod.indexmax());
    zscr.initialize();
    for (int i=1;i<=yrs.size();i++){
        y = yrs(i);
        if ((zscr.indexmin()<=y)&&(y<=zscr.indexmax())) {
            zscr(y) = (log(obs[i]+smlVal)-log(mod[y]+smlVal))/stdv[i];
//            nll += log(stdv[i]);
        }
    }
    nll += 0.5*norm2(zscr);
    double wgt = 1.0;//TODO: implement likelihood weights
    objFun += wgt*nll;
    if (debug<0){
        adstring obsyrs = wts::to_qcsv(yrs);
        adstring modyrs = str(mod.indexmin())+":"+str(mod.indexmax());
        cout<<"list(nll.type='lognormal',wgt="<<wgt<<cc<<"nll="<<nll<<cc<<"objfun="<<wgt*nll<<cc<<endl; 
        cout<<"obs=";   wts::writeToR(cout,obs,        obsyrs); cout<<cc<<endl;
        cout<<"mod=";   wts::writeToR(cout,value(mod), modyrs); cout<<cc<<endl;
        cout<<"stdv=";  wts::writeToR(cout,stdv,       obsyrs); cout<<cc<<endl;
        cout<<"zscrs="; wts::writeToR(cout,value(zscr),modyrs); cout<<")";
    }
   if (debug>=dbgAll) cout<<"Finished calcLognormalNLL()"<<endl;
    
//-------------------------------------------------------------------------------------
//Calculate multinomial NLL contribution to objective function
FUNCTION void calcMultinomialNLL(dvar_vector& mod, dvector& obs, double& ss, int debug, ostream& cout)
    if (debug>=dbgAll) cout<<"Starting calcMultinomialNLL()"<<endl;
    dvariable nll = -ss*(obs*(log(mod+smlVal)-log(obs+smlVal)));//note dot-product sums
    double wgt = 1.0;//TODO: incorporate weights
    objFun += wgt*nll;
    if (debug<0){
        dvector vmod = value(mod);
        dvector nlls = -ss*(elem_prod(obs,log(vmod+smlVal)-log(obs+smlVal)));
        dvector zscrs = elem_div(obs-vmod,sqrt(elem_prod((vmod+smlVal),1.0-(vmod+smlVal))/ss));//pearson residuals
        double effN = (vmod*(1.0-vmod))/norm2(obs-vmod);
        cout<<"list(nll.type='multinomial',wgt="<<wgt<<cc<<"nll="<<nll<<cc<<"objfun="<<wgt*nll<<cc<<"ss="<<ss<<cc<<"effN="<<effN<<cc<<endl; 
        adstring dzbs = "size=c("+ptrMC->csvZBs+")";
        cout<<"nlls=";  wts::writeToR(cout,nlls, dzbs); cout<<cc<<endl;
        cout<<"obs=";   wts::writeToR(cout,obs,  dzbs); cout<<cc<<endl;
        cout<<"mod=";   wts::writeToR(cout,vmod, dzbs); cout<<cc<<endl;
        cout<<"zscrs="; wts::writeToR(cout,zscrs,dzbs); cout<<endl;
        cout<<")";
    }
    if (debug>=dbgAll) cout<<"Finished calcMultinomialNLL()"<<endl;
 
//-------------------------------------------------------------------------------------
//Calculate time series contribution to objective function
FUNCTION void calcNLL(int llType, dvar_vector& mod, dvector& obs, dvector& stdv, ivector& yrs, int debug, ostream& cout)
    switch (llType){
        case tcsam::LL_NONE:
            break;
        case tcsam::LL_LOGNORMAL:
            calcLognormalNLL(mod,obs,stdv,yrs,debug,cout);
            break;
        case tcsam::LL_NORMAL:
            calcNormalNLL(mod,obs,stdv,yrs,debug,cout);
            break;
        case tcsam::LL_NORM2:
            calcNorm2NLL(mod,obs,stdv,yrs,debug,cout);
            break;
        default:
            cout<<"Unrecognized likelihood type in calcNLL(1)"<<endl;
            cout<<"Input type was "<<llType<<endl;
            cout<<"Aborting..."<<endl;
            exit(-1);
    }    

//-------------------------------------------------------------------------------------
//Calculate size frequency contribution to objective function
FUNCTION void calcNLL(int llType, dvar_vector& mod, dvector& obs, double& ss, int debug, ostream& cout)
    switch (llType){
        case tcsam::LL_NONE:
            break;
        case tcsam::LL_MULTINOMIAL:
            calcMultinomialNLL(mod,obs,ss,debug,cout);
            break;
        default:
            cout<<"Unrecognized likelihood type in calcNLL(2)"<<endl;
            cout<<"Input type was "<<llType<<endl;
            cout<<"Aborting..."<<endl;
            exit(-1);
    }
   
//-------------------------------------------------------------------------------------
//Calculate aggregate catch (abundance or biomass) components to objective function
FUNCTION void calcNLLs_AggregateCatch(AggregateCatchData* ptrAB, dvar5_array& mA_yxmsz, int debug, ostream& cout)
    if (debug>=dbgAll) cout<<"Starting calcNLLs_AggregateCatch()"<<endl;
    int mny = mA_yxmsz.indexmin();
    int mxy = mA_yxmsz.indexmax();//may NOT be mxYr
    dvar_vector tAB_y(mny,mxy);
    int isBio = ptrAB->type==AggregateCatchData::KW_BIOMASS_DATA;
    if (debug>=dbgAll) cout<<"isBio="<<isBio<<tb<<"type="<<ptrAB->type<<endl;
    if (debug<0) cout<<"list(fit.type='"<<tcsam::getFitType(ptrAB->optFit)<<"',fits=list("<<endl;
    if (ptrAB->optFit==tcsam::FIT_BY_TOT){
        tAB_y.initialize();
        if (isBio){
            for (int x=1;x<=nSXs;x++) {
                for (int m=1;m<=nMSs;m++) {
                    if (debug>=dbgAll) cout<<"w("<<x<<cc<<m<<") = "<<ptrMDS->ptrBio->wAtZ_xmz(x,m)<<endl;
                    for (int s=1;s<=nSCs;s++) {
                        for (int y=mny;y<=mxy;y++) {
                            tAB_y(y) += mA_yxmsz(y,x,m,s)*ptrMDS->ptrBio->wAtZ_xmz(x,m);
                        }//y
                    }//s
                }//m
            }//x
        } else {
            for (int y=mny;y<=mxy;y++) tAB_y(y) += sum(mA_yxmsz(y));//sum over x,m,s,z
        }
        if (debug>=dbgAll) cout<<"FIT_BY_TOT: "<<tAB_y<<endl;
        if (debug<0) {
            cout<<"list(";
            cout<<"sx="<<qt<<tcsam::getSexType(ALL_SXs)     <<qt<<cc;
            cout<<"ms="<<qt<<tcsam::getMaturityType(ALL_MSs)<<qt<<cc;
            cout<<"sc="<<qt<<tcsam::getShellType(ALL_SCs)   <<qt<<cc;
            cout<<"nll=";
        }
        calcNLL(ptrAB->llType, tAB_y, ptrAB->C_xmsy(ALL_SXs,ALL_MSs,ALL_SCs), ptrAB->sd_xmsy(ALL_SXs,ALL_MSs,ALL_SCs), ptrAB->yrs, debug, cout);                
        if (debug<0) cout<<")";
        if (debug<0) cout<<")";
    } else if (ptrAB->optFit==tcsam::FIT_BY_X){
        for (int x=1;x<=nSXs;x++){
            tAB_y.initialize();
            if (isBio){
                for (int m=1;m<=nMSs;m++) {
                    if (debug>=dbgAll) cout<<"w("<<x<<cc<<m<<") = "<<ptrMDS->ptrBio->wAtZ_xmz(x,m)<<endl;
                    for (int s=1;s<=nSCs;s++) {
                        for (int y=mny;y<=mxy;y++) {
                            tAB_y(y) += mA_yxmsz(y,x,m,s)*ptrMDS->ptrBio->wAtZ_xmz(x,m);
                        }//y
                    }//s
                }//m
            } else {
                for (int y=mny;y<=mxy;y++) tAB_y(y) += sum(mA_yxmsz(y,x));//sum over m,s,z
            }
            if (debug>=dbgAll) cout<<"FIT_BY_X("<<x<<"): "<<tAB_y<<endl;
            if (debug<0) {
                cout<<"list(";
                cout<<"sx="<<qt<<tcsam::getSexType(x)           <<qt<<cc;
                cout<<"ms="<<qt<<tcsam::getMaturityType(ALL_MSs)<<qt<<cc;
                cout<<"sc="<<qt<<tcsam::getShellType(ALL_SCs)   <<qt<<cc;
                cout<<"nll=";
            }
            calcNLL(ptrAB->llType, tAB_y, ptrAB->C_xmsy(x,ALL_MSs,ALL_SCs), ptrAB->sd_xmsy(x,ALL_MSs,ALL_SCs), ptrAB->yrs, debug, cout); 
            if (debug<0) cout<<"),"<<endl;
        }//x
        if (debug<0) cout<<"NULL)";
    } else if (ptrAB->optFit==tcsam::FIT_BY_XM){
        for (int x=1;x<=nSXs;x++){
            for (int m=1;m<=nMSs;m++){
                tAB_y.initialize();
                if (isBio){
                    if (debug>=dbgAll) cout<<"w("<<x<<cc<<m<<") = "<<ptrMDS->ptrBio->wAtZ_xmz(x,m)<<endl;
                    for (int s=1;s<=nSCs;s++) {
                        for (int y=mny;y<=mxy;y++) {
                            tAB_y(y) += mA_yxmsz(y,x,m,s)*ptrMDS->ptrBio->wAtZ_xmz(x,m);
                        }//y
                    }//s
                } else {
                    for (int y=mny;y<=mxy;y++) tAB_y(y) += sum(mA_yxmsz(y,x,m));//sum over s,z
                }
                if (debug<0) {
                    cout<<"list(";
                    cout<<"sx="<<qt<<tcsam::getSexType(x)        <<qt<<cc;
                    cout<<"ms="<<qt<<tcsam::getMaturityType(m)   <<qt<<cc;
                    cout<<"sc="<<qt<<tcsam::getShellType(ALL_SCs)<<qt<<cc;
                    cout<<"nll=";
                }
                calcNLL(ptrAB->llType, tAB_y, ptrAB->C_xmsy(x,m,ALL_SCs), ptrAB->sd_xmsy(x,m,ALL_SCs), ptrAB->yrs, debug, cout); 
                if (debug<0) cout<<"),"<<endl;
            }//m
        }//x
        if (debug<0) cout<<"NULL)";
    } else if (ptrAB->optFit==tcsam::FIT_BY_XS){
        for (int x=1;x<=nSXs;x++){
            for (int s=1;s<=nSCs;s++){
                tAB_y.initialize();
                if (isBio){
                    for (int m=1;m<=nMSs;m++) {
                        if (debug>=dbgAll) cout<<"w("<<x<<cc<<m<<") = "<<ptrMDS->ptrBio->wAtZ_xmz(x,m)<<endl;
                        for (int y=mny;y<=mxy;y++) {
                            tAB_y(y) += mA_yxmsz(y,x,m,s)*ptrMDS->ptrBio->wAtZ_xmz(x,m);
                        }//y
                    }//m
                } else {
                    for (int m=1;m<=nMSs;m++) {
                        for (int y=mny;y<=mxy;y++) {
                            tAB_y(y) += sum(mA_yxmsz(y,x,m,s));//sum over m,z
                        }//y
                    }//m
                }
                if (debug<0) {
                    cout<<"list(";
                    cout<<"sx="<<qt<<tcsam::getSexType(x)           <<qt<<cc;
                    cout<<"ms="<<qt<<tcsam::getMaturityType(ALL_MSs)<<qt<<cc;
                    cout<<"sc="<<qt<<tcsam::getShellType(s)         <<qt<<cc;
                    cout<<"nll=";
                }
                calcNLL(ptrAB->llType, tAB_y, ptrAB->C_xmsy(x,ALL_MSs,s), ptrAB->sd_xmsy(x,ALL_MSs,s), ptrAB->yrs, debug, cout); 
                if (debug<0) cout<<"),"<<endl;
            }//s
        }//x
        if (debug<0) cout<<"NULL)";
    } else if (ptrAB->optFit==tcsam::FIT_BY_XMS){
        for (int x=1;x<=nSXs;x++){
            for (int m=1;m<=nMSs;m++){
                for (int s=1;s<=nSCs;s++){
                    tAB_y.initialize();
                    if (isBio){
                        if (debug>=dbgAll) cout<<"w("<<x<<cc<<m<<") = "<<ptrMDS->ptrBio->wAtZ_xmz(x,m)<<endl;
                        for (int y=mny;y<=mxy;y++) tAB_y(y) += mA_yxmsz(y,x,m,s)*ptrMDS->ptrBio->wAtZ_xmz(x,m);
                    } else {
                        for (int y=mny;y<=mxy;y++) tAB_y(y) += sum(mA_yxmsz(y,x,m,s));//sum over z
                    }
                    if (debug<0) {
                        cout<<"list(";
                        cout<<"sx="<<qt<<tcsam::getSexType(x)     <<qt<<cc;
                        cout<<"ms="<<qt<<tcsam::getMaturityType(m)<<qt<<cc;
                        cout<<"sc="<<qt<<tcsam::getShellType(s)   <<qt<<cc;
                        cout<<"nll=";
                    }
                    calcNLL(ptrAB->llType, tAB_y, ptrAB->C_xmsy(x,m,s), ptrAB->sd_xmsy(x,m,s), ptrAB->yrs, debug, cout); 
                    if (debug<0) cout<<"),"<<endl;
                }//s
            }//m
        }//x
        if (debug<0) cout<<"NULL)";
    } else {
        std::cout<<"Calling calcNLLs_AggregateCatch with invalid fit option."<<endl;
        std::cout<<"Invalid fit option was '"<<tcsam::getFitType(ptrAB->optFit)<<qt<<endl;
        std::cout<<"Aborting..."<<endl;
        exit(-1);
    }
    if (debug<0) cout<<")";
    if (debug>=dbgAll){
        cout<<"Finished calcNLLs_AggregateCatch()"<<endl;
    }

//-------------------------------------------------------------------------------------
//Calculate catch size frequencies components to objective function
FUNCTION void calcNLLs_CatchNatZ(SizeFrequencyData* ptrZFD, dvar5_array& mA_yxmsz, int debug, ostream& cout)
    if (debug>=dbgAll) cout<<"Starting calcNLLs_CatchNatZ()"<<endl;
    if (ptrZFD->optFit==tcsam::FIT_NONE) return;
    ivector yrs = ptrZFD->yrs;
    int y;
    double ss;
    dvariable nT;
    int mny = mA_yxmsz.indexmin();
    int mxy = mA_yxmsz.indexmax();//may NOT be mxYr
    dvector     oP_z;//observed size comp.
    dvar_vector mP_z;//model size comp.
    if (ptrZFD->optFit==tcsam::FIT_BY_XE){
        oP_z.allocate(1,nSXs*nZBs);
        mP_z.allocate(1,nSXs*nZBs);
    } else 
    if (ptrZFD->optFit==tcsam::FIT_BY_XME){
        oP_z.allocate(1,nSXs*nMSs*nZBs);
        mP_z.allocate(1,nSXs*nMSs*nZBs);
    } else {
        oP_z.allocate(1,nZBs);
        mP_z.allocate(1,nZBs);
    }
    if (debug<0) cout<<"list("<<endl;
    for (int iy=1;iy<=yrs.size();iy++) {
        y = yrs[iy];
        if (debug>0) cout<<"y = "<<y<<endl;
        if ((mny<=y)&&(y<=mxy)) {
            if (ptrZFD->optFit==tcsam::FIT_BY_TOT){
                ss = 0;
                nT = sum(mA_yxmsz[y]);//=0 if not calculated
                if (value(nT)>0){
                    oP_z.initialize();//observed size comp.
                    mP_z.initialize();//model size comp.
                    for (int x=1;x<=ALL_SXs;x++){
                        for (int m=1;m<=ALL_MSs;m++) {
                            for (int s=1;s<=ALL_SCs;s++) {
                                ss   += ptrZFD->ss_xmsy(x,m,s,iy);
                                oP_z += ptrZFD->PatZ_xmsyz(x,m,s,iy);
                            }
                        }
                    }
                    oP_z /= sum(oP_z);
                    if (debug>0){
                        cout<<"ss = "<<ss<<endl;
                        cout<<"oP_Z = "<<oP_z<<endl;
                    }
                    for (int x=1;x<=nSXs;x++){
                        for (int m=1;m<=nMSs;m++) {
                            for (int s=1;s<=nSCs;s++)mP_z += mA_yxmsz(y,x,m,s);
                        }
                    }
                    mP_z /= nT;//normalize model size comp
                    if (debug>0) cout<<"mP_z = "<<mP_z<<endl;
                    if (debug<0) {
                        cout<<"'"<<y<<"'=list(";
                        cout<<"fit.type='"<<tcsam::getFitType(ptrZFD->optFit)<<"'"<<cc;
                        cout<<"yr="<<y<<cc;
                        cout<<"sx='"<<tcsam::getSexType(ALL_SXs)<<"'"<<cc;
                        cout<<"ms='"<<tcsam::getMaturityType(ALL_MSs)<<"'"<<cc;
                        cout<<"sc='"<<tcsam::getShellType(ALL_SCs)<<"'"<<cc;
                        cout<<"fit=";
                    }
                    calcNLL(ptrZFD->llType,mP_z,oP_z,ss,debug,cout);
                    if (debug<0) cout<<")"<<cc<<endl;
                }
                //FIT_BY_TOT
            } else
            if (ptrZFD->optFit==tcsam::FIT_BY_X){
                for (int x=1;x<=nSXs;x++) {
                    ss = 0;
                    nT = sum(mA_yxmsz(y,x));//=0 if not calculated
                    if (value(nT)>0){
                        oP_z.initialize();//observed size comp.
                        mP_z.initialize();//model size comp.
                        for (int m=1;m<=ALL_MSs;m++) {
                            for (int s=1;s<=ALL_SCs;s++) {
                                ss   += ptrZFD->ss_xmsy(x,m,s,iy);
                                oP_z += ptrZFD->PatZ_xmsyz(x,m,s,iy);
                            }
                        }
                        oP_z /= sum(oP_z);
                        if (debug>0){
                            cout<<"ss = "<<ss<<endl;
                            cout<<"oP_Z = "<<oP_z<<endl;
                        }
                        for (int m=1;m<=nMSs;m++) {
                            for (int s=1;s<=nSCs;s++) mP_z += mA_yxmsz(y,x,m,s);
                        }
                        mP_z /= nT;//normalize model size comp
                        if (debug>0) cout<<"mP_z = "<<mP_z<<endl;
                        if (debug<0) {
                            cout<<"'"<<y<<"'=list(";
                            cout<<"fit.type='"<<tcsam::getFitType(ptrZFD->optFit)<<"'"<<cc;
                            cout<<"yr="<<y<<cc;
                            cout<<"sx='"<<tcsam::getSexType(x)<<"'"<<cc;
                            cout<<"ms='"<<tcsam::getMaturityType(ALL_MSs)<<"'"<<cc;
                            cout<<"sc='"<<tcsam::getShellType(ALL_SCs)<<"'"<<cc;
                            cout<<"fit=";
                        }
                        calcNLL(ptrZFD->llType,mP_z,oP_z,ss,debug,cout);
                        if (debug<0) cout<<")"<<cc<<endl;
                    }//nT>0
                }//x
                //FIT_BY_X
            } else 
            if (ptrZFD->optFit==tcsam::FIT_BY_XE){
                ss = 0;
                nT = sum(mA_yxmsz[y]);//=0 if not calculated
                if (value(nT)>0){
                    oP_z.initialize();//observed size comp.
                    mP_z.initialize();//model size comp.
                    for (int x=1;x<=nSXs;x++) {
                        int mnz = 1+(x-1)*nZBs;
                        int mxz = x*nZBs;
                        for (int m=1;m<=ALL_MSs;m++) {
                            for (int s=1;s<=ALL_SCs;s++) {
                                ss += ptrZFD->ss_xmsy(x,m,s,iy);
                                oP_z(mnz,mxz).shift(1) += ptrZFD->PatZ_xmsyz(x,m,s,iy);
                            }
                        }
                        for (int m=1;m<=nMSs;m++) {
                            for (int s=1;s<=nSCs;s++) mP_z(mnz,mxz).shift(1) += mA_yxmsz(y,x,m,s);
                        }
                    }//x
                    oP_z /= sum(oP_z);
                    if (debug>0){
                        cout<<"ss = "<<ss<<endl;
                        cout<<"oP_Z = "<<oP_z<<endl;
                    }
                    mP_z /= nT;//normalize model size comp
                    if (debug>0) cout<<"mP_z = "<<mP_z<<endl;
                    for (int x=1;x<=nSXs;x++) {
                        int mnz = 1+(x-1)*nZBs;
                        int mxz = mnz+nZBs-1;
                        dvar_vector mPt = mP_z(mnz,mxz);
                        dvector oPt = oP_z(mnz,mxz);
                        if (debug<0) {
                            cout<<"'"<<y<<"'=list(";
                            cout<<"fit.type='"<<tcsam::getFitType(ptrZFD->optFit)<<"'"<<cc;
                            cout<<"yr="<<y<<cc;
                            cout<<"sx='"<<tcsam::getSexType(x)<<"'"<<cc;
                            cout<<"ms='"<<tcsam::getMaturityType(ALL_MSs)<<"'"<<cc;
                            cout<<"sc='"<<tcsam::getShellType(ALL_SCs)<<"'"<<cc;
                            cout<<"fit=";
                        }
                        calcNLL(ptrZFD->llType,mPt,oPt,ss,debug,cout);
                        if (debug<0) cout<<")"<<cc<<endl;
                    }//x
                }//nT>0
                //FIT_BY_XE
            } else
            if (ptrZFD->optFit==tcsam::FIT_BY_XM){
                for (int x=1;x<=nSXs;x++) {
                    for (int m=1;m<=nMSs;m++){
                        ss = 0;
                        nT = sum(mA_yxmsz(y,x,m));//=0 if not calculated
                        if (value(nT)>0){
                            oP_z.initialize();//observed size comp.
                            mP_z.initialize();//model size comp.
                            for (int s=1;s<=ALL_SCs;s++) {
                                ss   += ptrZFD->ss_xmsy(x,m,s,iy);
                                oP_z += ptrZFD->PatZ_xmsyz(x,m,s,iy);
                            }
                            oP_z /= sum(oP_z);
                            if (debug>0){
                                cout<<"ss = "<<ss<<endl;
                                cout<<"oP_Z = "<<oP_z<<endl;
                            }
                            for (int s=1;s<=nSCs;s++) mP_z += mA_yxmsz(y,x,m,s);
                            mP_z /= nT;//normalize model size comp
                            if (debug>0) cout<<"mP_z = "<<mP_z<<endl;
                            if (debug<0) {
                                cout<<"'"<<y<<"'=list(";
                                cout<<"fit.type='"<<tcsam::getFitType(ptrZFD->optFit)<<"'"<<cc;
                                cout<<"yr="<<y<<cc;
                                cout<<"sx='"<<tcsam::getSexType(x)<<"'"<<cc;
                                cout<<"ms='"<<tcsam::getMaturityType(m)<<"'"<<cc;
                                cout<<"sc='"<<tcsam::getShellType(ALL_SCs)<<"'"<<cc;
                                cout<<"fit=";
                            }
                            calcNLL(ptrZFD->llType,mP_z,oP_z,ss,debug,cout);
                            if (debug<0) cout<<")"<<cc<<endl;
                        }//nT>0
                    }//m
                }//x
                //FIT_BY_XM
            } else 
            if (ptrZFD->optFit==tcsam::FIT_BY_XME){
                ss = 0;
                nT = sum(mA_yxmsz[y]);//=0 if not calculated
                if (value(nT)>0){
                    oP_z.initialize();//observed size comp.
                    mP_z.initialize();//model size comp.
                    for (int x=1;x<=nSXs;x++) {
                        for (int m=1;m<=nMSs;m++) {
                            int mnz = 1+(m-1)*nZBs+(x-1)*nMSs*nZBs;
                            int mxz = mnz+nZBs-1;
                            for (int s=1;s<=ALL_SCs;s++) {
                                ss += ptrZFD->ss_xmsy(x,m,s,iy);
                                oP_z(mnz,mxz).shift(1) += ptrZFD->PatZ_xmsyz(x,m,s,iy);
                            }
                            if (debug>0){
                                cout<<"ss = "<<ss<<endl;
                                cout<<"oP_Z = "<<oP_z<<endl;
                            }
                            if (m<=nMSs) {for (int s=1;s<=nSCs;s++) mP_z(mnz,mxz).shift(1) += mA_yxmsz(y,x,m,s);}
                        }//m
                    }//x
                    oP_z /= sum(oP_z);
                    if (debug>0){
                        cout<<"ss = "<<ss<<endl;
                        cout<<"oP_Z = "<<oP_z<<endl;
                    }
                    mP_z /= nT;//normalize model size comp
                    if (debug>0) cout<<"mP_z = "<<mP_z<<endl;
                    for (int x=1;x<=nSXs;x++) {
                        for (int m=1;m<=nMSs;m++) {
                            int mnz = 1+(m-1)*nZBs+(x-1)*nMSs*nZBs;
                            int mxz = mnz+nZBs-1;
                            dvar_vector mPt = mP_z(mnz,mxz);
                            dvector oPt = oP_z(mnz,mxz);
                            if (debug<0) {
                                cout<<"'"<<y<<"'=list(";
                                cout<<"fit.type='"<<tcsam::getFitType(ptrZFD->optFit)<<"'"<<cc;
                                cout<<"yr="<<y<<cc;
                                cout<<"sx='"<<tcsam::getSexType(x)<<"'"<<cc;
                                cout<<"ms='"<<tcsam::getMaturityType(m)<<"'"<<cc;
                                cout<<"sc='"<<tcsam::getShellType(ALL_SCs)<<"'"<<cc;
                                cout<<"fit=";
                            }
                            calcNLL(ptrZFD->llType,mPt,oPt,ss,debug,cout);
                            if (debug<0) cout<<")"<<cc<<endl;
                        }//m
                    }//x
                    //FIT_BY_XME
                }//nT>0
            } else 
            if (ptrZFD->optFit==tcsam::FIT_BY_XS){
                for (int x=1;x<=nSXs;x++) {
                    for (int s=1;s<=nSCs;s++){
                        ss = 0;
                        nT.initialize();
                        for (int m=1;m<=ALL_MSs;m++) nT += sum(mA_yxmsz(y,x,m,s));//=0 if not calculated
                        if (value(nT)>0){
                            oP_z.initialize();//observed size comp.
                            mP_z.initialize();//model size comp.
                            for (int m=1;m<=ALL_MSs;m++) {
                                ss   += ptrZFD->ss_xmsy(x,m,s,iy);
                                oP_z += ptrZFD->PatZ_xmsyz(x,m,s,iy);
                            }
                            oP_z /= sum(oP_z);
                            if (debug>0){
                                cout<<"ss = "<<ss<<endl;
                                cout<<"oP_Z = "<<oP_z<<endl;
                            }
                            for (int m=1;m<=nMSs;m++) mP_z += mA_yxmsz(y,x,m,s);
                            mP_z /= nT;//normalize model size comp
                            if (debug>0) cout<<"mP_z = "<<mP_z<<endl;
                            if (debug<0) {
                                cout<<"'"<<y<<"'=list(";
                                cout<<"fit.type='"<<tcsam::getFitType(ptrZFD->optFit)<<"'"<<cc;
                                cout<<"yr="<<y<<cc;
                                cout<<"sx='"<<tcsam::getSexType(x)<<"'"<<cc;
                                cout<<"ms='"<<tcsam::getMaturityType(ALL_MSs)<<"'"<<cc;
                                cout<<"sc='"<<tcsam::getShellType(s)<<"'"<<cc;
                                cout<<"fit=";
                            }
                            calcNLL(ptrZFD->llType,mP_z,oP_z,ss,debug,cout);
                            if (debug<0) cout<<")"<<cc<<endl;
                        }//nT>0
                    }//m
                }//x
                //FIT_BY_XS
            } else 
            if (ptrZFD->optFit==tcsam::FIT_BY_XMS){
                for (int x=1;x<=nSXs;x++) {
                    for (int m=1;m<=nMSs;m++){
                        for (int s=1;s<=nSCs;s++) {
                            ss = 0;
                            nT = sum(mA_yxmsz(y,x,m));//=0 if not calculated
                            if (value(nT)>0){
                                oP_z.initialize();//observed size comp.
                                mP_z.initialize();//model size comp.                            
                                ss   += ptrZFD->ss_xmsy(x,m,s,iy);
                                oP_z += ptrZFD->PatZ_xmsyz(x,m,s,iy);
                                oP_z /= sum(oP_z);
                                if (debug>0){
                                    cout<<"ss = "<<ss<<endl;
                                    cout<<"oP_Z = "<<oP_z<<endl;
                                }
                                mP_z += mA_yxmsz(y,x,m,s);
                                mP_z /= nT;//normalize model size comp
                                if (debug>0) cout<<"mP_z = "<<mP_z<<endl;
                                if (debug<0) {
                                    cout<<"'"<<y<<"'=list(";
                                    cout<<"fit.type='"<<tcsam::getFitType(ptrZFD->optFit)<<"'"<<cc;
                                    cout<<"yr="<<y<<cc;
                                    cout<<"sx='"<<tcsam::getSexType(x)<<"'"<<cc;
                                    cout<<"ms='"<<tcsam::getMaturityType(m)<<"'"<<cc;
                                    cout<<"sc='"<<tcsam::getShellType(s)<<"'"<<cc;
                                    cout<<"fit=";
                                }
                                calcNLL(ptrZFD->llType,mP_z,oP_z,ss,debug,cout);
                                if (debug<0) cout<<")"<<cc<<endl;
                            }//nT>0
                        }//s
                    }//m
                }//x
                //FIT_BY_XMS
            } else 
            {
                std::cout<<"Calling calcNLLs_CatchNatZ with invalid fit option."<<endl;
                std::cout<<"Invalid fit option was '"<<tcsam::getFitType(ptrZFD->optFit)<<qt<<endl;
                std::cout<<"Aborting..."<<endl;
                exit(-1);
            }
        } //if ((mny<=y)&&(y<=mxy))
    } //loop over iy
    if (debug<0) cout<<"NULL)";
    if (debug>=dbgAll) cout<<"Finished calcNLLs_CatchNatZ()"<<endl;

//-------------------------------------------------------------------------------------
//Calculate fishery components to objective function
FUNCTION void calcNLLs_Fisheries(int debug, ostream& cout)
    if (debug>0) debug = dbgAll+10;
    if (debug>=dbgAll) cout<<"Starting calcNLLs_Fisheries()"<<endl;
    if (debug<0) cout<<"list("<<endl;
    for (int f=1;f<=nFsh;f++){
        if (debug>0) cout<<"calculating NLLs for fishery "<<ptrMC->lblsFsh[f]<<endl;
        if (debug<0) cout<<ptrMC->lblsFsh[f]<<"=list("<<endl;
        FisheryData* ptrObs = ptrMDS->ppFsh[f-1];
        if (ptrObs->hasRCD){//retained catch data
            if (debug<0) cout<<"retained.catch=list("<<endl;
            if (ptrObs->ptrRCD->hasN && ptrObs->ptrRCD->ptrN->optFit){
                if (debug>0) cout<<"---retained catch abundance"<<endl;
                if (debug<0) cout<<"abundance="<<endl;
                calcNLLs_AggregateCatch(ptrObs->ptrRCD->ptrN,rmN_fyxmsz(f),debug,cout);
                if (debug<0) cout<<","<<endl;
            }
            if (ptrObs->ptrRCD->hasB && ptrObs->ptrRCD->ptrB->optFit){
                if (debug>0) cout<<"---retained catch biomass"<<endl;
                if (debug<0) cout<<"biomass="<<endl;
                calcNLLs_AggregateCatch(ptrObs->ptrRCD->ptrB,rmN_fyxmsz(f),debug,cout);
                if (debug<0) cout<<","<<endl;
            }
            if (ptrObs->ptrRCD->hasZFD && ptrObs->ptrRCD->ptrZFD->optFit){
                if (debug>0) cout<<"---retained catch size frequencies"<<endl;
                if (debug<0) cout<<"n.at.z="<<endl;
                calcNLLs_CatchNatZ(ptrObs->ptrRCD->ptrZFD,rmN_fyxmsz(f),debug,cout);
                if (debug<0) cout<<","<<endl;
            }
            if (debug<0) cout<<"NULL),"<<endl;
        }
        if (ptrObs->hasTCD){//observed total catch data
            if (debug<0) cout<<"total.catch=list("<<endl;
            if (ptrObs->ptrTCD->hasN && ptrObs->ptrTCD->ptrN->optFit){
                if (debug>0) cout<<"---total catch abundance"<<endl;
                if (debug<0) cout<<"abundance="<<endl;
                calcNLLs_AggregateCatch(ptrObs->ptrTCD->ptrN,cN_fyxmsz(f),debug,cout);
                if (debug<0) cout<<","<<endl;
            }
            if (ptrObs->ptrTCD->hasB && ptrObs->ptrTCD->ptrB->optFit){
                if (debug>0) cout<<"---total catch biomass"<<endl;
                if (debug<0) cout<<"biomass="<<endl;
                calcNLLs_AggregateCatch(ptrObs->ptrTCD->ptrB,cN_fyxmsz(f),debug,cout);
                if (debug<0) cout<<","<<endl;
            }
            if (ptrObs->ptrTCD->hasZFD && ptrObs->ptrTCD->ptrZFD->optFit){
                if (debug>0) cout<<"---total catch size frequencies"<<endl;
                if (debug<0) cout<<"n.at.z="<<endl;
                calcNLLs_CatchNatZ(ptrObs->ptrTCD->ptrZFD,cN_fyxmsz(f),debug,cout);
                if (debug<0) cout<<","<<endl;
            }
            if (debug<0) cout<<"NULL),"<<endl;
        }
        if (ptrObs->hasDCD){//observed discard catch data
            if (debug<0) cout<<"discard.catch=list("<<endl;
            if (ptrObs->ptrDCD->hasN && ptrObs->ptrDCD->ptrN->optFit){
                if (debug>0) cout<<"---discard catch abundance"<<endl;
                if (debug<0) cout<<"abundance="<<endl;
                calcNLLs_AggregateCatch(ptrObs->ptrDCD->ptrN,dN_fyxmsz(f),debug,cout);
                if (debug<0) cout<<","<<endl;
            }
            if (ptrObs->ptrDCD->hasB && ptrObs->ptrDCD->ptrB->optFit){
                if (debug>0) cout<<"---discard catch biomass"<<endl;
                if (debug<0) cout<<"biomass="<<endl;
                calcNLLs_AggregateCatch(ptrObs->ptrDCD->ptrB,dN_fyxmsz(f),debug,cout);
                if (debug<0) cout<<","<<endl;
            }
            if (ptrObs->ptrDCD->hasZFD && ptrObs->ptrDCD->ptrZFD->optFit){
                if (debug>0) cout<<"---discard catch size frequencies"<<endl;
                if (debug<0) cout<<"n.at.z="<<endl;
                calcNLLs_CatchNatZ(ptrObs->ptrDCD->ptrZFD,dN_fyxmsz(f),debug,cout);
                if (debug<0) cout<<","<<endl;
            }
            if (debug<0) cout<<"NULL),"<<endl;
        }
        if (debug<0) cout<<"NULL),"<<endl;
    }//fisheries
    if (debug<0) cout<<"NULL)"<<endl;
    if (debug>=dbgAll) cout<<"Finished calcNLLs_Fisheries()"<<endl;

//-------------------------------------------------------------------------------------
//Calculate survey components to objective function
FUNCTION void calcNLLs_Surveys(int debug, ostream& cout)
    if (debug>0) debug = dbgAll+10;
    if (debug>=dbgAll) cout<<"Starting calcNLLs_Surveys()"<<endl;
    if (debug<0) cout<<"list("<<endl;
    for (int v=1;v<=nSrv;v++){
        if (debug>0) cout<<"calculating NLLs for survey "<<ptrMC->lblsSrv[v]<<endl;
        if (debug<0) cout<<ptrMC->lblsSrv[v]<<"=list("<<endl;
        SurveyData* ptrObs = ptrMDS->ppSrv[v-1];
        if (ptrObs->hasN && ptrObs->ptrN->optFit){
            if (debug>0) cout<<"---survey abundance"<<endl;
            if (debug<0) cout<<"abundance="<<endl;
            calcNLLs_AggregateCatch(ptrObs->ptrN,n_vyxmsz(v),debug,cout);
            if (debug<0) cout<<","<<endl;
        }
        if (ptrObs->hasB && ptrObs->ptrB->optFit){
            if (debug>0) cout<<"---survey biomass"<<endl;
            if (debug<0) cout<<"biomass="<<endl;
            calcNLLs_AggregateCatch(ptrObs->ptrB,n_vyxmsz(v),debug,cout);
            if (debug<0) cout<<","<<endl;
        }
        if (ptrObs->hasZFD && ptrObs->ptrZFD->optFit){
            if (debug>0) cout<<"---survey size frequencies"<<endl;
            if (debug<0) cout<<"n.at.z="<<endl;
            calcNLLs_CatchNatZ(ptrObs->ptrZFD,n_vyxmsz(v),debug,cout);
            if (debug<0) cout<<","<<endl;
        }
        if (debug<0) cout<<"NULL),"<<endl;
    }//surveys loop
    if (debug<0) cout<<"NULL)"<<endl;
    if (debug>=dbgAll) cout<<"Finished calcNLLs_Surveys()"<<endl;

//-------------------------------------------------------------------------------------
//Calculate contributions to objective function from all priors                                         
FUNCTION void calcAllPriors(int debug, ostream& cout)
    if (debug>=dbgPriors) cout<<"Starting calcAllPriors()"<<endl;
    if (debug<0) cout<<"list("<<endl;

    //recruitment parameters
    if (debug<0) cout<<tb<<"recruitment=list("<<endl;
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrRec->pLnR,  pLnR,  debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrRec->pLnRCV,pLnRCV,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrRec->pLgtRX,pLgtRX,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrRec->pLnRa, pLnRa, debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrRec->pLnRb, pLnRb, debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrRec->pDevsLnR,devsLnR,debug,cout); if (debug<0){cout<<endl;}
    if (debug<0) cout<<tb<<")"<<cc<<endl;
   
    //natural mortality parameters
    if (debug<0) cout<<tb<<"'natural mortality'=list("<<endl;
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrNM->pLnM,   pLnM,   debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrNM->pLnDMT, pLnDMT, debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrNM->pLnDMX, pLnDMX, debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrNM->pLnDMM, pLnDMM, debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrNM->pLnDMXM,pLnDMXM,debug,cout); if (debug<0){cout<<endl;}
    if (debug<0) cout<<tb<<")"<<cc<<endl;
    
    //growth parameters
    if (debug<0) cout<<tb<<"growth=list("<<endl;
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrGr->pLnGrA,   pLnGrA,   debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrGr->pLnGrB,   pLnGrB,   debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrGr->pLnGrBeta,pLnGrBeta,debug,cout); if (debug<0){cout<<endl;}
    if (debug<0) cout<<tb<<")"<<cc<<endl;
    
    //maturity parameters
    if (debug<0) cout<<tb<<"maturity=list("<<endl;
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrMat->pLgtPrMat,pLgtPrMat,debug,cout); if (debug<0){cout<<endl;}
    if (debug<0) cout<<tb<<")"<<cc<<endl;
    
    //selectivity parameters
    if (debug<0) cout<<tb<<"'selectivity functions'=list("<<endl;
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSel->pS1,pS1,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSel->pS2,pS2,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSel->pS3,pS3,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSel->pS4,pS4,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSel->pS5,pS5,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSel->pS6,pS6,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSel->pDevsS1,devsS1,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSel->pDevsS2,devsS2,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSel->pDevsS3,devsS3,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSel->pDevsS4,devsS4,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSel->pDevsS5,devsS5,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSel->pDevsS6,devsS6,debug,cout); if (debug<0){cout<<endl;}
    if (debug<0) cout<<tb<<")"<<cc<<endl;
    
    //fishing mortality parameters
    if (debug<0) cout<<tb<<"fisheries=list("<<endl;
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrFsh->pLnC,    pLnC,   debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrFsh->pLnDCT,  pLnDCT, debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrFsh->pLnDCX,  pLnDCX, debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrFsh->pLnDCM,  pLnDCM, debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrFsh->pLnDCXM, pLnDCXM,debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrFsh->pDevsLnC,devsLnC,debug,cout); if (debug<0){cout<<endl;}
    if (debug<0) cout<<tb<<")"<<cc<<endl;
   
    //survey catchability parameters
    if (debug<0) cout<<tb<<"surveys=list("<<endl;
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSrv->pLnQ,    pLnQ,   debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSrv->pLnDQT,  pLnDQT, debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSrv->pLnDQX,  pLnDQX, debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSrv->pLnDQM,  pLnDQM, debug,cout); if (debug<0){cout<<cc<<endl;}
    if (debug<0) {cout<<tb;} tcsam::calcPriors(objFun,ptrMPI->ptrSrv->pLnDQXM, pLnDQXM,debug,cout); if (debug<0){cout<<endl;}
    if (debug<0) cout<<tb<<")"<<endl;
    
    if (debug<0) cout<<")"<<endl;
    if (debug>=dbgPriors) cout<<"Finished calcAllPriors()"<<endl;

//-------------------------------------------------------------------------------------
//Write data to file as R list
FUNCTION void ReportToR_Data(ostream& os, int debug, ostream& cout)
    if (debug) cout<<"Starting ReportToR_Data(...)"<<endl;
    ptrMDS->writeToR(os,"data",0);
    if (debug) cout<<"Finished ReportToR_Data(...)"<<endl;

//-------------------------------------------------------------------------------------
//Write parameter values to file as R list
FUNCTION void ReportToR_Params(ostream& os, int debug, ostream& cout)
    if (debug) cout<<"Starting ReportToR_Params(...)"<<endl;
    ptrMPI->writeToR(os);
    if (debug) cout<<"Finished ReportToR_Params(...)"<<endl;

//-------------------------------------------------------------------------------------
//Write population quantities to file as R list
FUNCTION void ReportToR_PopQuants(ostream& os, int debug, ostream& cout)
    if (debug) cout<<"Starting ReportToR_PopQuants(...)"<<endl;
    //abundance
    d5_array vn_yxmsz = wts::value(n_yxmsz);
    d5_array n_xmsyz = tcsam::rearrangeYXMSZtoXMSYZ(vn_yxmsz);
    //natural mortality (numbers)
    d5_array vnmN_yxmsz = wts::value(nmN_yxmsz);
    d5_array nmN_xmsyz = tcsam::rearrangeYXMSZtoXMSYZ(vnmN_yxmsz);
    //total mortality (numbers)
    d5_array vtmN_yxmsz = wts::value(tmN_yxmsz);
    d5_array tmN_xmsyz = tcsam::rearrangeYXMSZtoXMSYZ(vtmN_yxmsz);
        
    //total fishing mortality rates
    d5_array vtmF_yxmsz = wts::value(tmF_yxmsz);
    d5_array tmF_xmsyz  = tcsam::rearrangeYXMSZtoXMSYZ(vtmF_yxmsz);
    if (debug) cout<<"finished tmF_xmsyz"<<endl;
    
    os<<"pop.quants=list("<<endl;
    os<<"R.y=";       wts::writeToR(os,value(R_y),               ptrMC->dimYrsToR);os<<cc<<endl;
    os<<"Rx.y=";      wts::writeToR(os,trans(value(R_yx))(MALE), ptrMC->dimYrsToR);os<<cc<<endl;
    os<<"Rx.c=";      wts::writeToR(os,value(Rx_c),adstring("pc=1:"+str(npcRec))); os<<cc<<endl;
    os<<"R.cz=";      wts::writeToR(os,value(R_cz),adstring("pc=1:"+str(npcRec)),    ptrMC->dimZBsToR); os<<cc<<endl;
    os<<"M.cxm=";     wts::writeToR(os,value(M_cxm),   adstring("pc=1:"+str(npcNM)), ptrMC->dimSXsToR,ptrMC->dimMSsToR); os<<cc<<endl;
    os<<"prMat.cz=";  wts::writeToR(os,value(prMat_cz),adstring("pc=1:"+str(npcMat)),ptrMC->dimZBsToR); os<<cc<<endl;
    os<<"prGr.czz=";  wts::writeToR(os,value(prGr_czz),adstring("pc=1:"+str(npcGr)), ptrMC->dimZBsToR,ptrMC->dimZBsToR); os<<cc<<endl;
    os<<"spb.yx=";    wts::writeToR(os,value(spb_yx),ptrMC->dimYrsToR,ptrMC->dimSXsToR); os<<cc<<endl;
    os<<"n.xmsyz=";   wts::writeToR(os,n_xmsyz,  ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsP1ToR,ptrMC->dimZBsToR); os<<cc<<endl;
    os<<"nmN.xmsyz="; wts::writeToR(os,nmN_xmsyz,ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsToR,ptrMC->dimZBsToR); os<<cc<<endl;
    os<<"tmN.xmsyz="; wts::writeToR(os,tmN_xmsyz,ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsToR,ptrMC->dimZBsToR); os<<cc<<endl;
    os<<"tmF.xmsyz="; wts::writeToR(os,tmF_xmsyz,ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsToR,ptrMC->dimZBsToR); os<<endl;
    os<<")";
    if (debug) cout<<"Finished ReportToR_PopQuants(...)"<<endl;

//-------------------------------------------------------------------------------------
//Write selectivity functions to file as R list
FUNCTION void ReportToR_SelFuncs(ostream& os, int debug, ostream& cout)
    if (debug) cout<<"Starting ReportToR_SelFuncs(...)"<<endl;
    os<<"sel.funcs=list("<<endl;
    os<<"sel_cz=";  wts::writeToR(os,value(sel_cz),  adstring("pc=1:"+str(npcSel)),ptrMC->dimZBsToR);os<<endl;
    os<<")";
    if (debug) cout<<"Finished ReportToR_SelFuncs(...)"<<endl;

//-------------------------------------------------------------------------------------
//Write fishery-related quantities to file as R list
FUNCTION void ReportToR_FshQuants(ostream& os, int debug, ostream& cout)
    if (debug) cout<<"Starting ReportToR_FshQuants(...)"<<endl;

    //fishing capture rates (NOT mortality rates)
    d5_array vcF_fyxms = wts::value(cF_fyxms);//fully-selected
    d5_array cF_fxmsy  = tcsam::rearrangeIYXMStoIXMSY(vcF_fyxms);
    if (debug) cout<<"finished cF_fxmsy"<<endl;
    d6_array vFc_fyxmsz = wts::value(cF_fyxmsz);
    d6_array cF_fxmsyz  = tcsam::rearrangeIYXMSZtoIXMSYZ(vFc_fyxmsz);
    if (debug) {
        cout<<"idxDevsLnC_fy, dvsLnc_fy"<<endl;
        for (int f=1;f<=nFsh;f++){
            cout<<"fishery"<<tb; for (int y=mnYr;y<=mxYr;y++) cout<<y<<tb; cout<<endl;
            cout<<f<<tb<<idxDevsLnC_fy(f)<<endl;
            cout<<f<<tb<<dvsLnC_fy(f)<<endl;
        }
        cout<<"cF_fyxms"<<endl;
        for (int f=1;f<=nFsh;f++){
            for (int y=(mxYr-1);y<=mxYr;y++){
                cout<<"f, y = "<<f<<tb<<y<<endl;
                cout<<cF_fyxms(f,y)<<endl;
            }
        }
        cout<<"cF_fyxmsz"<<endl;
        for (int f=1;f<=nFsh;f++){
            for (int y=(mxYr-1);y<=mxYr;y++){
                cout<<"f, y = "<<f<<tb<<y<<endl;
                cout<<cF_fyxmsz(f,y)<<endl;
            }
        }
        cout<<"finished cF_fxmsyz"<<endl;
    }
    
    //retention mortality rates
    d6_array vrmF_fyxmsz = wts::value(rmF_fyxmsz);
    d6_array rmF_fxmsyz  = tcsam::rearrangeIYXMSZtoIXMSYZ(vrmF_fyxmsz);
    if (debug) cout<<"finished rmF_fxmsyz"<<endl;
    
    //discard mortality rates
    d6_array vdmF_fyxmsz = wts::value(dmF_fyxmsz);
    d6_array dmF_fxmsyz  = tcsam::rearrangeIYXMSZtoIXMSYZ(vdmF_fyxmsz);
    if (debug) cout<<"finished dmF_fxmsyz"<<endl;
    
    //numbers, biomass captured (NOT mortality)
    d6_array vcN_fyxmsz = wts::value(cN_fyxmsz);
    d3_array cN_fxy     = tcsam::calcIXYfromIYXMSZ(vcN_fyxmsz);
    d3_array cB_fxy     = tcsam::calcIXYfromIYXMSZ(vcN_fyxmsz,ptrMDS->ptrBio->wAtZ_xmz);
    d6_array cN_fxmsyz  = tcsam::rearrangeIYXMSZtoIXMSYZ(vcN_fyxmsz);
    if (debug) {
        cout<<"cN_fyxmsz"<<endl;
        for (int f=1;f<=nFsh;f++){
            for (int y=(mxYr-1);y<=mxYr;y++){
                cout<<"f, y = "<<f<<tb<<y<<endl;
                cout<<cN_fyxmsz(f,y)<<endl;
            }
        }
        cout<<"finished cN_fxmsyz"<<endl;
    }
    
    //numbers, biomass discards (NOT mortality)
    d6_array vdN_fyxmsz = wts::value(dN_fyxmsz);
    d3_array dN_fxy     = tcsam::calcIXYfromIYXMSZ(vdN_fyxmsz);
    d3_array dB_fxy     = tcsam::calcIXYfromIYXMSZ(vdN_fyxmsz,ptrMDS->ptrBio->wAtZ_xmz);
    d6_array dN_fxmsyz  = tcsam::rearrangeIYXMSZtoIXMSYZ(vdN_fyxmsz);
    if (debug) cout<<"finished dN_fxmsyz"<<endl;
    
    //numbers, biomass retained (mortality)
    d6_array vrmN_fyxmsz = wts::value(rmN_fyxmsz);
    d3_array rmN_fxy     = tcsam::calcIXYfromIYXMSZ(vrmN_fyxmsz);
    d3_array rmB_fxy     = tcsam::calcIXYfromIYXMSZ(vrmN_fyxmsz,ptrMDS->ptrBio->wAtZ_xmz);
    d6_array rmN_fxmsyz  = tcsam::rearrangeIYXMSZtoIXMSYZ(vrmN_fyxmsz);
    if (debug) cout<<"finished rmN_fxmsyz"<<endl;
    
    //numbers, biomass discard mortality
    d6_array vdmN_fyxmsz = wts::value(dmN_fyxmsz);
    d3_array dmN_fxy     = tcsam::calcIXYfromIYXMSZ(vdmN_fyxmsz);
    d3_array dmB_fxy     = tcsam::calcIXYfromIYXMSZ(vdmN_fyxmsz,ptrMDS->ptrBio->wAtZ_xmz);
    d6_array dmN_fxmsyz  = tcsam::rearrangeIYXMSZtoIXMSYZ(vdmN_fyxmsz);
    if (debug) cout<<"finished dmN_fxmsyz"<<endl;   
    
    os<<"fisheries=list("<<endl;
    for (int f=1;f<=nFsh;f++){
        os<<ptrMC->lblsFsh[f]<<"=list("<<endl;
        os<<"cap=list("<<endl;
            os<<"n.xy=";   wts::writeToR(os,cN_fxy(f),   ptrMC->dimSXsToR,ptrMC->dimYrsToR); os<<cc<<endl;
            os<<"b.xy=";   wts::writeToR(os,cB_fxy(f),   ptrMC->dimSXsToR,ptrMC->dimYrsToR); os<<cc<<endl;
            os<<"n.xmsyz=";wts::writeToR(os,cN_fxmsyz(f),ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsToR,ptrMC->dimZBsToR); os<<cc<<endl;
            os<<"F.xmsy="; wts::writeToR(os,cF_fxmsy(f), ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsToR); os<<cc<<endl;
            os<<"F.xmsyz=";wts::writeToR(os,cF_fxmsyz(f),ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsToR,ptrMC->dimZBsToR); 
        os<<")"<<cc<<endl;
        os<<"dm=list("<<endl;
            os<<"n.xy="; wts::writeToR(os,dmN_fxy(f),      ptrMC->dimSXsToR,ptrMC->dimYrsToR); os<<cc<<endl;
            os<<"b.xy="; wts::writeToR(os,dmB_fxy(f),      ptrMC->dimSXsToR,ptrMC->dimYrsToR); os<<cc<<endl;
            os<<"n.xmsyz="; wts::writeToR(os,dmN_fxmsyz(f),ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsToR,ptrMC->dimZBsToR); os<<cc<<endl;
            os<<"F.xmsyz="; wts::writeToR(os,dmF_fxmsyz(f),ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsToR,ptrMC->dimZBsToR); 
        os<<")"<<cc<<endl;
        if (sum(rmN_fxy(f))>0){
            os<<"rm=list("<<endl;
                os<<"n.xy="; wts::writeToR(os,rmN_fxy(f),      ptrMC->dimSXsToR,ptrMC->dimYrsToR); os<<cc<<endl;
                os<<"b.xy="; wts::writeToR(os,rmB_fxy(f),      ptrMC->dimSXsToR,ptrMC->dimYrsToR); os<<cc<<endl;
                os<<"n.xmsyz="; wts::writeToR(os,rmN_fxmsyz(f),ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsToR,ptrMC->dimZBsToR); os<<cc<<endl;
                os<<"F.xmsyz="; wts::writeToR(os,rmF_fxmsyz(f),ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsToR,ptrMC->dimZBsToR); 
            os<<")"<<cc<<endl;
        }
        os<<"NULL),"<<endl;    
    }
    os<<"NULL)";
    if (debug) cout<<"Finished ReportToR_FshQuants(...)"<<endl;

//-------------------------------------------------------------------------------------
//Write survey-related quantities to file as R list
FUNCTION void ReportToR_SrvQuants(ostream& os, int debug, ostream& cout)
    if (debug) cout<<"Starting ReportToR_SrvQuants(...)"<<endl;
    d5_array vq_vyxms = wts::value(q_vyxms);
    d5_array q_vxmsy = tcsam::rearrangeIYXMStoIXMSY(vq_vyxms);
    d6_array vq_vyxmsz = wts::value(q_vyxmsz);
    d6_array q_vxmsyz = tcsam::rearrangeIYXMSZtoIXMSYZ(vq_vyxmsz);
    
    d6_array vn_vyxmsz = wts::value(n_vyxmsz);
    d3_array n_vxy = tcsam::calcIXYfromIYXMSZ(vn_vyxmsz);
    d3_array b_vxy = tcsam::calcIXYfromIYXMSZ(vn_vyxmsz,ptrMDS->ptrBio->wAtZ_xmz);
    d6_array n_vxmsyz = tcsam::rearrangeIYXMSZtoIXMSYZ(vn_vyxmsz);
    
    os<<"surveys=list("<<endl;
    for (int v=1;v<=nSrv;v++){
        os<<ptrMC->lblsSrv[v]<<"=list("<<endl;
        os<<"q.xmsy=";  wts::writeToR(os,q_vxmsy(v), ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsP1ToR); os<<cc<<endl;
        os<<"q.xmsyz="; wts::writeToR(os,q_vxmsyz(v),ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsP1ToR,ptrMC->dimZBsToR); os<<cc<<endl;
        os<<"n.xy=";    wts::writeToR(os,n_vxy(v),  ptrMC->dimSXsToR,ptrMC->dimYrsP1ToR); os<<cc<<endl;
        os<<"b.xy=";    wts::writeToR(os,b_vxy(v),  ptrMC->dimSXsToR,ptrMC->dimYrsP1ToR); os<<cc<<endl;
        os<<"spb.yx=";  wts::writeToR(os,value(spb_vyx(v)),ptrMC->dimYrsP1ToR,ptrMC->dimSXsToR); os<<cc<<endl;
        os<<"n.xmsyz="; wts::writeToR(os,n_vxmsyz(v),ptrMC->dimSXsToR,ptrMC->dimMSsToR,ptrMC->dimSCsToR,ptrMC->dimYrsP1ToR,ptrMC->dimZBsToR); os<<endl;
        os<<")"<<cc<<endl;
    }
    os<<"NULL)";
    if (debug) cout<<"Finished ReportToR_SrvQuants(...)"<<endl;

//-------------------------------------------------------------------------------------
//Write quantities related to model fits to file as R list
FUNCTION void ReportToR_ModelFits(ostream& os, int debug, ostream& cout)
    if (debug) cout<<"Starting ReportToR_ModelFits(...)"<<endl;
    //recalc objective function components and and write results to os
    os<<"model.fits=list("<<endl;
        os<<tb<<"penalties="; calcPenalties(-1,os);      os<<cc<<endl;
        os<<tb<<"priors=";    calcAllPriors(-1,os);      os<<cc<<endl;
        os<<tb<<"components=list("<<endl;
            os<<tb<<tb<<"recruitment="; calcNLLs_Recruitment(-1,os); os<<endl;
        os<<tb<<")"<<cc<<endl;
        os<<tb<<"fisheries="; calcNLLs_Fisheries(-1,os);  os<<cc<<endl; 
        os<<tb<<"surveys=";   calcNLLs_Surveys(-1,os);    os<<endl;  
    os<<")";
    if (debug) cout<<"Finished ReportToR_ModelFits(...)"<<endl;

//-------------------------------------------------------------------------------------
//Update MPI for current parameter values (mainly for export))
FUNCTION void updateMPI(int debug, ostream& cout)
    if (debug) cout<<"Starting updateMPI(...)"<<endl;
//    NumberVectorInfo::debug=1;
//    BoundedVectorInfo::debug=1;
//    DevsVectorInfo::debug=1;
//    DevsVectorVectorInfo::debug=1;
    //recruitment parameters
    ptrMPI->ptrRec->pLnR->setFinalVals(pLnR);
    ptrMPI->ptrRec->pLnRCV->setFinalVals(pLnRCV);
    ptrMPI->ptrRec->pLgtRX->setFinalVals(pLgtRX);
    ptrMPI->ptrRec->pLnRa->setFinalVals(pLnRa);
    ptrMPI->ptrRec->pLnRb->setFinalVals(pLnRb);
    //cout<<"setting final vals for pDevsLnR"<<endl;
    for (int p=1;p<=ptrMPI->ptrRec->pDevsLnR->getSize();p++) (*ptrMPI->ptrRec->pDevsLnR)[p]->setFinalVals(pDevsLnR(p));
     
    //natural mortality parameters
    ptrMPI->ptrNM->pLnM->setFinalVals(pLnM);
    ptrMPI->ptrNM->pLnDMT->setFinalVals(pLnDMT);
    ptrMPI->ptrNM->pLnDMX->setFinalVals(pLnDMX);
    ptrMPI->ptrNM->pLnDMM->setFinalVals(pLnDMM);
    ptrMPI->ptrNM->pLnDMXM->setFinalVals(pLnDMXM);
    
    //growth parameters
    ptrMPI->ptrGr->pLnGrA->setFinalVals(pLnGrA);
    ptrMPI->ptrGr->pLnGrB->setFinalVals(pLnGrB);
    ptrMPI->ptrGr->pLnGrBeta->setFinalVals(pLnGrBeta);
    
    //maturity parameters
    //cout<<"setting final vals for pLgtPrMat"<<endl;
    for (int p=1;p<=npLgtPrMat;p++) (*ptrMPI->ptrMat->pLgtPrMat)[p]->setFinalVals(pLgtPrMat(p));
    
    //selectivity parameters
    ptrMPI->ptrSel->pS1->setFinalVals(pS1);
    ptrMPI->ptrSel->pS2->setFinalVals(pS2);
    ptrMPI->ptrSel->pS3->setFinalVals(pS3);
    ptrMPI->ptrSel->pS4->setFinalVals(pS4);
    ptrMPI->ptrSel->pS5->setFinalVals(pS5);
    ptrMPI->ptrSel->pS6->setFinalVals(pS6);
    //cout<<"setting final vals for pDevsS1"<<endl;
    for (int p=1;p<=ptrMPI->ptrSel->pDevsS1->getSize();p++) (*ptrMPI->ptrSel->pDevsS1)[p]->setFinalVals(pDevsS1(p));
    //cout<<"setting final vals for pDevsS2"<<endl;
    for (int p=1;p<=ptrMPI->ptrSel->pDevsS2->getSize();p++) (*ptrMPI->ptrSel->pDevsS2)[p]->setFinalVals(pDevsS2(p));
    //cout<<"setting final vals for pDevsS3"<<endl;
    for (int p=1;p<=ptrMPI->ptrSel->pDevsS3->getSize();p++) (*ptrMPI->ptrSel->pDevsS3)[p]->setFinalVals(pDevsS3(p));
    //cout<<"setting final vals for pDevsS4"<<endl;
    for (int p=1;p<=ptrMPI->ptrSel->pDevsS4->getSize();p++) (*ptrMPI->ptrSel->pDevsS4)[p]->setFinalVals(pDevsS4(p));
    //cout<<"setting final vals for pDevsS5"<<endl;
    for (int p=1;p<=ptrMPI->ptrSel->pDevsS5->getSize();p++) (*ptrMPI->ptrSel->pDevsS5)[p]->setFinalVals(pDevsS5(p));
    //cout<<"setting final vals for pDevsS6"<<endl;
    for (int p=1;p<=ptrMPI->ptrSel->pDevsS6->getSize();p++) (*ptrMPI->ptrSel->pDevsS6)[p]->setFinalVals(pDevsS6(p));
     
    //fully-selected fishing capture rate parameters
    ptrMPI->ptrFsh->pHM->setFinalVals(pHM);
    ptrMPI->ptrFsh->pLnC->setFinalVals(pLnC);
    ptrMPI->ptrFsh->pLnDCT->setFinalVals(pLnDCT);
    ptrMPI->ptrFsh->pLnDCX->setFinalVals(pLnDCX);
    ptrMPI->ptrFsh->pLnDCM->setFinalVals(pLnDCM);
    ptrMPI->ptrFsh->pLnDCXM->setFinalVals(pLnDCXM);
    //cout<<"setting final vals for pDevsLnC"<<endl;
    for (int p=1;p<=ptrMPI->ptrFsh->pDevsLnC->getSize();p++) (*ptrMPI->ptrFsh->pDevsLnC)[p]->setFinalVals(pDevsLnC(p));
    
    //survey catchability parameters
    ptrMPI->ptrSrv->pLnQ->setFinalVals(pLnQ);
    ptrMPI->ptrSrv->pLnDQT->setFinalVals(pLnDQT);
    ptrMPI->ptrSrv->pLnDQX->setFinalVals(pLnDQX);
    ptrMPI->ptrSrv->pLnDQM->setFinalVals(pLnDQM);
    ptrMPI->ptrSrv->pLnDQXM->setFinalVals(pLnDQXM);
    
    if (debug) cout<<"Finished updateMPI(...)"<<endl;

//-------------------------------------------------------------------------------------
//Write results to file as R list
FUNCTION void ReportToR(ostream& os, int debug, ostream& cout)
    if (debug) cout<<"Starting ReportToR(...)"<<endl;

    updateMPI(debug,cout);
        
    os<<"res=list("<<endl;
        //model configuration
        ptrMC->writeToR(os,"mc",0); os<<","<<endl;
        
        //model data
        ptrMDS->writeToR(os,"data",0); os<<","<<endl;
        
        //parameter values
        ReportToR_Params(os,debug,cout); os<<","<<endl;

        //selectivity functions
        ReportToR_SelFuncs(os,debug,cout); os<<","<<endl;

        //population quantities
        ReportToR_PopQuants(os,debug,cout); os<<","<<endl;

        //fishery quantities
        ReportToR_FshQuants(os,debug,cout); os<<","<<endl;

        //survey quantities 
        ReportToR_SrvQuants(os,debug,cout); os<<","<<endl;

        //model fit quantities
        ReportToR_ModelFits(os,debug,cout); os<<","<<endl;
        
        //simulated model data
        createSimData(debug, cout, 0, ptrSimMDS);//deterministic
        ptrSimMDS->writeToR(os,"sim.data",0); 
        os<<endl;

    os<<")"<<endl;
    if (debug) cout<<"Finished ReportToR(...)"<<endl;

// =============================================================================
// =============================================================================
REPORT_SECTION
        
    //write active parameters to rpt::echo
    rpt::echo<<"Finished phase "<<current_phase()<<endl;
    
    //write report as R file
    ReportToR(report,1,rpt::echo);

// =============================================================================
// =============================================================================
BETWEEN_PHASES_SECTION

// =============================================================================
// =============================================================================
FINAL_SECTION
    {cout<<"writing model sim data to file"<<endl;
        ofstream echo1; echo1.open("ModelSimData.dat", ios::trunc);
        writeSimData(echo1,0,cout,ptrSimMDS);
    }

    if (option_match(ad_comm::argc,ad_comm::argv,"-mceval")>-1) {
        mcmc.open((char*)(fnMCMC),ofstream::out|ofstream::app);
        mcmc<<"NULL)"<<endl;
        mcmc.close();
    }

    
    long hour,minute,second;
    double elapsed_time;
    
    time(&finish); 
    elapsed_time = difftime(finish,start);
    
    hour = long(elapsed_time)/3600;
    minute = long(elapsed_time)%3600/60;
    second = (long(elapsed_time)%3600)%60;
    cout << endl << endl << "Starting time: " << ctime(&start);
    cout << "Finishing time: " << ctime(&finish);
    cout << "This run took: " << hour << " hours, " << minute << " minutes, " << second << " seconds." << endl << endl;
    
// =============================================================================
// =============================================================================
RUNTIME_SECTION
//one number for each phase, if more phases then uses the last number
  maximum_function_evaluations 1000,5000,5000,5000,5000,5000,10000
  convergence_criteria 1,1,.01,.001,.001,.001,1e-3,1e-3

// =============================================================================
// =============================================================================
TOP_OF_MAIN_SECTION
  arrmblsize = 1000000000; //must be smaller than 2,147,483,647
  gradient_structure::set_GRADSTACK_BUFFER_SIZE(40000000); // this may be incorrect in the AUTODIF manual.
  gradient_structure::set_CMPDIF_BUFFER_SIZE(1500000000);
  gradient_structure::set_NUM_DEPENDENT_VARIABLES(4000);
  time(&start);

