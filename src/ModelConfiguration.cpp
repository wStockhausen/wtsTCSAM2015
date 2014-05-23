#include <admodel.h>
#include <wtsADMB.hpp>
#include "ModelConstants.hpp"
#include "ModelConfiguration.hpp"

using namespace std;

//**********************************************************************
//  Includes
//      ModelConfiguration
//      ModelOptions
//**********************************************************************
int ModelConfiguration::debug=0;
int ModelOptions::debug      =0;
//--------------------------------------------------------------------------------
//          ModelConfiguration
//--------------------------------------------------------------------------------
int    ModelConfiguration::mnYr     = -1;//min model year
int    ModelConfiguration::mxYr     = -1;//max model year
int    ModelConfiguration::nSrv     = -1;//number of model surveys
int    ModelConfiguration::nFsh     = -1;//number of model fisheries
int    ModelConfiguration::nSXs     = -1;//number of model sex states
int    ModelConfiguration::nMSs     = -1;//number of model maturity states
int    ModelConfiguration::nSCs     = -1;//number of model shell condition states
int    ModelConfiguration::nZBs     = -1;//number of model size bins
int    ModelConfiguration::jitter   = OFF;//flag to jitter initial parameter values
double ModelConfiguration::jitFrac  = 1.0;//fraction to jitter bounded parameter values
int    ModelConfiguration::resample = OFF;//flag to resample initial parameter values
double ModelConfiguration::vif      = 1.0;//variance inflation factor for resampling parameter values
/***************************************************************
*   creation                                                   *
***************************************************************/
ModelConfiguration::ModelConfiguration(){
    runOpMod=fitToPriors=INT_TRUE;//default to TRUE
    ModelConfiguration::nSXs = tcsam::nSXs;
    ModelConfiguration::nMSs = tcsam::nMSs;
    ModelConfiguration::nSCs = tcsam::nSCs;
}
/***************************************************************
*   destruction                                                *
***************************************************************/
ModelConfiguration::~ModelConfiguration(){
    if (debug) cout<<"destroying ModelConfiguration "<<this<<endl;
    if (debug) cout<<"destruction complete "<<endl;
}

/***************************************************************
*   function to read from file in ADMB format                  *
***************************************************************/
void ModelConfiguration::read(const adstring & fn) {
    if (debug) cout<<"ModelConfiguration::read(fn). Reading from '"<<fn<<"'"<<endl;
    cifstream strm(fn);
    read(strm);
    if (debug) cout<<"end ModelConfiguration::read(fn). Read from '"<<fn<<"'"<<endl;
}

/***************************************************************
*   function to write to file in ADMB format                   *
***************************************************************/
void ModelConfiguration::write(const adstring & fn) {
    if (debug) cout<<"#start ModelConfiguration::write(fn). Writing to '"<<fn<<"'"<<endl;
    ofstream strm(fn,ofstream::out|ofstream::trunc);
    write(strm); //write to file
    strm.close();
    if (debug) cout<<"#end ModelConfiguration::write(fn). Wrote to '"<<fn<<"'"<<endl;
}

/***************************************************************
*   function to read from file in ADMB format                  *
***************************************************************/
void ModelConfiguration::read(cifstream & is) {
    if (debug) cout<<"ModelConfiguration::read(cifstream & is)"<<endl;
    is>>cfgName;
    if (debug) cout<<cfgName<<endl;
    is>>mnYr; //min model year
    is>>mxYr; //max model year
    is>>nZBs; //number of model size bins
    if (debug){
        cout<<mnYr <<tb<<"#model min year"<<endl;
        cout<<mxYr <<tb<<"#model max year"<<endl;
        cout<<nZBs<<tb<<"#number of size bins"<<endl;
    }
    zMidPts.allocate(1,nZBs); 
    zCutPts.allocate(1,nZBs+1); 
    onesZMidPts.allocate(1,nZBs); onesZMidPts = 1.0;
    is>>zCutPts;
    for (int z=1;z<=nZBs;z++) zMidPts(z) = 0.5*(zCutPts(z)+zCutPts(z+1));
    if (debug){
        cout<<"#size bins (mm CW)"<<endl;
        cout<<zMidPts<<endl;
        cout<<"#size bin cut points (mm CW)"<<endl;
        cout<<zCutPts <<endl;
        cout<<"enter 1 to continue : ";
        cin>>debug;
        if (debug<0) exit(1);
    }
        
    is>>nFsh; //number of fisheries
    lblsFsh.allocate(1,nFsh);
    for (int i=1;i<=nFsh;i++) is>>lblsFsh(i); //labels for fisheries
    if (debug){
        cout<<nFsh<<tb<<"#number of fisheries"<<endl;
        for (int i=1;i<=nFsh;i++) cout<<lblsFsh(i)<<tb;
        cout<<tb<<"#labels for fisheries"<<endl;
    }
    
    is>>nSrv; //number of surveys
    lblsSrv.allocate(1,nSrv);
    for (int i=1;i<=nSrv;i++) is>>lblsSrv(i);//labels for surveys
    if (debug){
        cout<<nSrv<<tb<<"#number of surveys"<<endl;
        for (int i=1;i<=nSrv;i++) cout<<lblsSrv(i)<<tb;
        cout<<tb<<"#labels for surveys"<<endl;
    }
    
    adstring str1;
    is>>str1; runOpMod    = wts::getBooleanType(str1);//run population model?
    is>>str1; fitToPriors = wts::getBooleanType(str1);//fit priors?
    
    is>>fnMPI;//model parameters information file
    is>>fnMDS;//model datasets file
    is>>fnMOs;//model options file
    
    is>>str1; ModelConfiguration::jitter = wts::getOnOffType(str1);
    is>>ModelConfiguration::jitFrac;
    is>>str1; ModelConfiguration::resample = wts::getOnOffType(str1);
    is>>ModelConfiguration::vif;
    
    //convert model quantities to csv strings
    csvYrs  =qt+str(mnYr)+qt; for (int y=(mnYr+1);y<=mxYr;    y++) csvYrs  += cc+qt+str(y)+qt;
    csvYrsP1=qt+str(mnYr)+qt; for (int y=(mnYr+1);y<=(mxYr+1);y++) csvYrsP1 += cc+qt+str(y)+qt;
    csvSXs=qt+tcsam::getSexType(1)     +qt; for (int i=2;i<=nSXs;i++) csvSXs += cc+qt+tcsam::getSexType(i)     +qt;
    csvMSs=qt+tcsam::getMaturityType(1)+qt; for (int i=2;i<=nMSs;i++) csvMSs += cc+qt+tcsam::getMaturityType(i)+qt;
    csvSCs=qt+tcsam::getShellType(1)   +qt; for (int i=2;i<=nSCs;i++) csvSCs += cc+qt+tcsam::getShellType(i)   +qt;
    csvZCs=wts::to_qcsv(zCutPts);
    csvZBs=wts::to_qcsv(zMidPts);
    csvFsh=wts::to_qcsv(lblsFsh);
    csvSrv=wts::to_qcsv(lblsSrv);
    
    if (debug){
        cout<<wts::getBooleanType(runOpMod)   <<"   #run operating model?"<<endl;
        cout<<wts::getBooleanType(fitToPriors)<<"   #fit to priors?"<<endl;
        cout<<fnMPI<<"   #model parameters configuration file"<<endl;
        cout<<fnMDS<<"   #model datasets file"<<endl;
        cout<<fnMOs<<"   #model options file"<<endl;
        cout<<wts::getOnOffType(ModelConfiguration::jitter)<<tb<<"#jitter?"<<endl;
        cout<<ModelConfiguration::jitFrac<<tb<<"#jitter fraction"<<endl;
        cout<<wts::getOnOffType(ModelConfiguration::resample)<<tb<<"#resmple?"<<endl;
        cout<<ModelConfiguration::vif<<tb<<"#variance inflation factor"<<endl;
        cout<<"enter 1 to continue : ";
        cin>>debug;
        if (debug<0) exit(1);
    }
    
    if (debug) cout<<"end ModelConfiguration::read(cifstream & is)"<<endl;
}

/***************************************************************
*   function to write to file in ADMB format                   *
***************************************************************/
void ModelConfiguration::write(ostream & os) {
    if (debug) cout<<"#start ModelConfiguration::write(ostream)"<<endl;
    os<<"#######################################################"<<endl;
    os<<"#TCSAM2013 Model Configuration File                   #"<<endl;
    os<<"#######################################################"<<endl;
    os<<cfgName<<tb<<"#Model configuration name"<<endl;
    os<<mnYr<<tb<<"#Min model year"<<endl;
    os<<mxYr<<tb<<"#Max model year"<<endl;
    os<<nZBs<<tb<<"#Number of model size classes"<<endl;
    os<<"#size bin cut points"<<endl;
    os<<zCutPts <<endl;
    
    os<<nFsh<<tb<<"#number of fisheries"<<endl;
    for (int i=1;i<=nFsh;i++) cout<<lblsFsh(i)<<tb;
        cout<<tb<<"#labels for fisheries"<<endl;
    os<<nSrv<<tb<<"#number of surveys"<<endl;
    for (int i=1;i<=nSrv;i++) cout<<lblsSrv(i)<<tb;
        cout<<tb<<"#labels for surveys"<<endl;    
        
    os<<wts::getBooleanType(runOpMod)   <<tb<<"#run operating model?"<<endl;
    os<<wts::getBooleanType(fitToPriors)<<tb<<"#fit priors?"<<endl;
    
    os<<fnMPI<<tb<<"#Model parameters info file"<<endl;
    os<<fnMDS<<tb<<"#Model datasets file"<<endl;
    os<<fnMOs<<tb<<"#Model options file"<<endl;
    
    os<<wts::getOnOffType(ModelConfiguration::jitter)<<tb<<"#jitter?"<<endl;
    os<<ModelConfiguration::jitFrac<<tb<<"#jitter fraction"<<endl;
    os<<wts::getOnOffType(ModelConfiguration::resample)<<tb<<"#resmple?"<<endl;
    os<<ModelConfiguration::vif<<tb<<"#variance inflation factor"<<endl;

    if (debug) cout<<"#end ModelConfiguration::write(ostream)"<<endl;
}

/***************************************************************
*   Function to write object to R list.                        *
***************************************************************/
void ModelConfiguration::writeToR(ostream& os, std::string nm, int indent) {
    for (int n=0;n<indent;n++) os<<tb;
        os<<nm<<"=list("<<endl;
    indent++;
    for (int n=0;n<indent;n++) os<<tb;
        os<<"configName='"<<cfgName<<"'"<<cc;
        os<<"mnYr="<<mnYr<<", mxYr="<<mxYr<<cc;
        os<<"SXs=c("<<csvSXs<<")"<<cc;
        os<<"MSs=c("<<csvMSs<<")"<<cc;
        os<<"SCs=c("<<csvSCs<<")"<<cc;
        os<<"nZBs="<<nZBs<<cc<<endl;
    for (int n=0;n<indent;n++) os<<tb;
        os<<"zBs="; wts::writeToR(os,zMidPts);os<<cc<<endl;
    for (int n=0;n<indent;n++) os<<tb;
        os<<"zCs="; wts::writeToR(os,zCutPts);os<<cc<<endl;
    for (int n=0;n<indent;n++) os<<tb;
        os<<"nFsh="<<nFsh<<cc;
        os<<"lbls.fsh="; wts::writeToR(os,lblsFsh); os<<cc<<endl;
    for (int n=0;n<indent;n++) os<<tb;
        os<<"nSrv="<<nSrv<<cc;
        os<<"lbls.srv="; wts::writeToR(os,lblsSrv); os<<cc<<endl;
    for (int n=0;n<indent;n++) os<<tb;
        os<<"flags=list(";
        os<<"runOpMod="<<runOpMod<<cc;
        os<<"fitToPriors="<<fitToPriors<<"),";
        os<<endl;
    for (int n=0;n<indent;n++) os<<tb; os<<"fnMPI='"<<fnMPI<<"',"<<endl;
    for (int n=0;n<indent;n++) os<<tb; os<<"fnMDS='"<<fnMDS<<"',"<<endl;
    for (int n=0;n<indent;n++) os<<tb; os<<"fnMOs='"<<fnMOs<<"'"<<endl;
    indent--;
    for (int n=0;n<indent;n++) os<<tb;
        os<<")";
}
/////////////////////////////////end ModelConfiguration/////////////////////////

//--------------------------------------------------------------------------------
//          ModelOptions
//--------------------------------------------------------------------------------
ModelOptions::ModelOptions(ModelConfiguration& mc){
    ptrMC=&mc;
    
    lblsFcAvgOpts.allocate(0,2);
    lblsFcAvgOpts(0) = "no averaging"; 
    lblsFcAvgOpts(1) = "average capture rate";
    lblsFcAvgOpts(2) = "average exploitation rate";
    
}
/***************************************************************
*   function to read from file in ADMB format                  *
***************************************************************/
void ModelOptions::read(cifstream & is) {
    if (debug) cout<<"ModelOptions::read(cifstream & is)"<<endl;
    int idx;
    adstring str;
    optsFcAvg.allocate(1,ptrMC->nFsh);
    for (int f=1;f<=ptrMC->nFsh;f++){
        is>>str; cout<<str<<"# fishery"<<tb;
        idx = wts::which(str,ptrMC->lblsFsh);
        cout<<idx<<tb;
        is>>optsFcAvg(idx);
        cout<<"= "<<optsFcAvg(idx)<<endl;
    }
    if (debug) cout<<"optsFcAvg = "<<optsFcAvg<<endl;
    if (debug){
        cout<<"enter 1 to continue : ";
        cin>>debug;
        if (debug<0) exit(1);
    }
    
    if (debug) cout<<"end ModelOptions::read(cifstream & is)"<<endl;
}

/***************************************************************
*   function to write to file in ADMB format                   *
***************************************************************/
void ModelOptions::write(ostream & os) {
    if (debug) cout<<"#start ModelOptions::write(ostream)"<<endl;
    os<<"#######################################"<<endl;
    os<<"#TCSAM2014 Model Options File         #"<<endl;
    os<<"#######################################"<<endl;

    //averaging options for fishery capture rates
    os<<"#Fishery Capture Rate Averaging Options"<<endl;
    for (int o=lblsFcAvgOpts.indexmin();o<=lblsFcAvgOpts.indexmax();o++) {
        os<<"#"<<o<<" - "<<lblsFcAvgOpts(o)<<endl;
    }
    os<<"#Fishery    Option"<<endl;
    for (int f=1;f<=ptrMC->nFsh;f++){
        os<<ptrMC->lblsFsh(f)<<tb<<tb<<optsFcAvg(f)<<endl;
    }
    
    if (debug) cout<<"#end ModelOptions::write(ostream)"<<endl;
}

/***************************************************************
*   Function to write object to R list.                        *
***************************************************************/
void ModelOptions::writeToR(ostream& os, std::string nm, int indent) {
    for (int n=0;n<indent;n++) os<<tb;
        os<<nm<<"=list("<<endl;
    indent++;
    indent--;
    for (int n=0;n<indent;n++) os<<tb;
        os<<")";
}
/////////////////////////////////end ModelOptions/////////////////////////

