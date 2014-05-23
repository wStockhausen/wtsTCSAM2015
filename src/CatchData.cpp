#include <admodel.h>
#include "wtsADMB.hpp"
#include "ModelConstants.hpp"
#include "ModelConfiguration.hpp"
#include "ModelIndexBlocks.hpp"
#include "ModelData.hpp"

using namespace tcsam;

//**********************************************************************
//  Includes
//      EffortData
//      CatchData
//      SurveyData
//      FisheryData
//**********************************************************************
int EffortData::debug  = 0;
int CatchData::debug   = 0;
int SurveyData::debug  = 0;
int FisheryData::debug = 0;
//----------------------------------------------------------------------
//          EffortData
//----------------------------------------------------------------------
const adstring EffortData::KW_EFFORT_DATA = "EFFORT_DATA";
/***************************************************************
*   destruction.                                               *
***************************************************************/
EffortData::~EffortData(){
    delete ptrAvgIR; ptrAvgIR=0;
}
/***************************************************************
*   read.                                                      *
***************************************************************/
void EffortData::read(cifstream & is){
    if (debug){
        cout<<"start EffortData::read(...) "<<this<<endl;
        cout<<"#------------------------------------------"<<endl;
        cout<<"#file name is "<<is.get_file_name()<<endl;
        cout<<"#------------------------------------------"<<endl;
    }
    if (!is) {
        cout<<"Apparent error reading EffortData."<<endl;
        cout<<"#file name is "<<is.get_file_name()<<endl;
        cout<<"File stream is 'bad'--file may not exist!"<<endl;
        cout<<"Terminating!!"<<endl;
        exit(-1);
    }
    
    adstring str;
    is>>str;
    if (!(str==KW_EFFORT_DATA)){
        cout<<"#Error reading effort data from "<<is.get_file_name()<<endl;
        cout<<"Expected keyowrd '"<<KW_EFFORT_DATA<<"' but got '"<<str<<"'"<<endl;
        cout<<"Aborting..."<<endl;
        exit(-1);
    }
    is>>ny;//number of years of effort data
    rpt::echo<<ny<<tb<<"#number of years"<<endl;
    ptrAvgIR = new IndexRange(ModelConfiguration::mnYr,ModelConfiguration::mxYr);
    is>>(*ptrAvgIR);
    rpt::echo<<(*ptrAvgIR)<<tb<<"#interval over which to average effort/fishing mortality"<<endl;
    is>>units;
    rpt::echo<<units<<tb<<"#units"<<endl;
    inpEff_yc.allocate(1,ny,1,2);
    is>>inpEff_yc;
    rpt::echo<<"#year potlifts ("<<units<<")"<<endl<<inpEff_yc<<endl;
    
    yrs.allocate(1,ny);
    yrs = (ivector) column(inpEff_yc,1);
    int mny = min(yrs);
    int mxy = max(yrs);
    eff_y.allocate(mny,mxy); eff_y = 0.0;
    for (int iy=1;iy<=ny;iy++) eff_y(yrs(iy)) = inpEff_yc(iy,2);
    if (debug) cout<<"end EffortData::read(...) "<<this<<endl;
}
/***************************************************************
*   write.                                                     *
***************************************************************/
void EffortData::write(ostream & os){
    if (debug) cout<<"start EffortData::write(...) "<<this<<endl;
    os<<KW_EFFORT_DATA<<tb<<"#required keyword"<<endl;
    os<<ny<<tb<<"#number of years of effort data"<<endl;
    os<<(*ptrAvgIR)<<tb<<"#interval over which to average effort/fishing mortality"<<endl;
    os<<units<<tb<<"#units for pot lifts"<<endl;
    os<<"#year   potlifts"<<endl<<inpEff_yc<<endl;
    if (debug) cout<<"end EffortData::write(...) "<<this<<endl;
}
/***************************************************************
*   Function to write object to R list.                        *
***************************************************************/
void EffortData::writeToR(ostream& os, std::string nm, int indent) {
    if (debug) cout<<"EffortData::writing to R"<<endl;
    adstring y  = wts::to_qcsv(yrs);
    for (int n=0;n<indent;n++) os<<tb;
        os<<"effort=list("<<endl;
        indent++; 
            for (int n=0;n<indent;n++) os<<tb;
            os<<"avgRng="<<(*ptrAvgIR)<<cc<<endl;
            os<<"units="<<qt<<units<<qt<<cc<<endl;
            for (int n=0;n<indent;n++) os<<tb;
            os<<"data="; wts::writeToR(os,column(inpEff_yc,2),y); os<<endl;
        indent--;
    for (int n=0;n<indent;n++) os<<tb; os<<")"<<endl;
    if (debug) cout<<"EffortData::done writing to R"<<endl;
}
/////////////////////////////////end EffortData/////////////////////////
//----------------------------------------------------------------------
//          CatchData
//----------------------------------------------------------------------
const adstring CatchData::KW_CATCH_DATA = "CATCH_DATA";
/***************************************************************
*   instantiation.                                             *
***************************************************************/
CatchData::CatchData(){
    hasN = 0;   ptrN = 0;
    hasB = 0;   ptrB = 0;
    hasZFD = 0; ptrZFD = 0;
}

/***************************************************************
*   destruction.                                               *
***************************************************************/
CatchData::~CatchData(){
    if (ptrN)   delete ptrB;   ptrN = 0;
    if (ptrB)   delete ptrB;   ptrB = 0;
    if (ptrZFD) delete ptrZFD; ptrZFD = 0;
}
/*************************************************\n
 * Replaces catch data based on newNatZ_yxmsz.
 * 
 * @param newNatZ_yxmsz - POINTER to d5_array of catch-at-size by sex/maturity/shell condition/year
 * @param wAtZ_xmz - weight-at-size by sex/maturity
 */
void CatchData::replaceCatchData(d5_array& newNatZ_yxmsz, d3_array& wAtZ_xmz){
    int mnY = newNatZ_yxmsz.indexmin();
    int mxY = newNatZ_yxmsz.indexmax();
    if (hasN) {
        if (debug) cout<<"replacing abundance data"<<endl;
        dmatrix newN_yx(mnY,mxY,1,nSXs); newN_yx.initialize();
        for (int y=mnY;y<=mxY;y++){
            for (int x=1;x<=nSXs;x++) newN_yx(y,x) = sum((newNatZ_yxmsz)(y,x));
        }
        ptrN->replaceCatchData(newN_yx);
        if (debug) cout<<"replaced catch data"<<endl;
    }
    if (hasB){
        if (debug) cout<<"replacing biomass data"<<endl;
        dmatrix newB_yx(mnY,mxY,1,nSXs); newB_yx.initialize();
        for (int y=mnY;y<=mxY;y++){
            for (int x=1;x<=nSXs;x++){
                for (int m=1;m<=nMSs;m++){
                    for (int s=1;s<=nSCs;s++) newB_yx(y,x) += newNatZ_yxmsz(y,x,m,s)*wAtZ_xmz(x,m);
                }
            }
        }
        ptrB->replaceCatchData(newB_yx);
        if (debug) cout<<"replaced biomass data"<<endl;
    }
    if (hasZFD){
        if (debug) cout<<"replacing n-at-size data"<<endl;
        ptrZFD->replaceSizeFrequencyData(newNatZ_yxmsz);
        if (debug) cout<<"replaced n-at-size data"<<endl;
    }
}
/***************************************************************
*   read.                                                      *
***************************************************************/
void CatchData::read(cifstream & is){
    if (debug){
        cout<<"start CatchData::read(...) for "<<type<<endl;
        cout<<"#------------------------------------------"<<endl;
        cout<<"#file name is "<<is.get_file_name()<<endl;
        cout<<"#------------------------------------------"<<endl;
    }
    if (!is) {
        cout<<"Apparent error reading CatchData for "<<type<<endl;
        cout<<"#file name is "<<is.get_file_name()<<endl;
        cout<<"File stream is 'bad'--file may not exist!"<<endl;
        cout<<"Terminating!!"<<endl;
        exit(-1);
    }
    adstring str;
    is>>str;
    rpt::echo<<str<<tb<<"#Required keyword"<<endl;
    if (!(str==KW_CATCH_DATA)){
        cout<<"#Error reading catch data from "<<is.get_file_name()<<endl;
        cout<<"Expected keyowrd '"<<KW_CATCH_DATA<<"' but got '"<<str<<"'"<<endl;
        cout<<"Aborting..."<<endl;
        exit(-1);
    }
    
    is>>str; hasN = wts::getBooleanType(str);  //has aggregate abundance data?
    is>>str; hasB = wts::getBooleanType(str);  //has aggregate biomass data?
    is>>str; hasZFD = wts::getBooleanType(str);//has size frequency data?

    rpt::echo<<wts::getBooleanType(hasN)<<tb<<"#has aggregate catch abundance (numbers) data?"<<endl;
    rpt::echo<<wts::getBooleanType(hasB)<<tb<<"#has aggregate catch biomass (weight) data?"<<endl;
    rpt::echo<<wts::getBooleanType(hasZFD)<<tb<<"#has size frequency data?"<<endl;
    rpt::echo<<"#-----------AGGREGATE CATCH ABUNDANCE (NUMBERS)---------------#"<<endl;

    
    //ABUNDANCE
    if (hasN){
        ptrN = new AggregateCatchData();
        rpt::echo<<"#---Reading abundance data"<<endl;
        is>>(*ptrN);
        rpt::echo<<"#---Read abundance data"<<endl;
    }
    
    //BIOMASS
    if (hasB){
        ptrB = new AggregateCatchData();
        rpt::echo<<"#---Reading biomass data"<<endl;
        is>>(*ptrB);
        rpt::echo<<"#---Read biomass data"<<endl;
    }
    
    //NUMBERS-AT-SIZE 
    if (hasZFD){
        ptrZFD = new SizeFrequencyData();
        rpt::echo<<"#---Reading size frequency data"<<endl;
        is>>(*ptrZFD);
        rpt::echo<<"#---Read size frequency data"<<endl;
    }
    if (debug) cout<<"end CatchData::read(...) "<<this<<endl;
}
/***************************************************************
*   write.                                                     *
***************************************************************/
void CatchData::write(ostream & os){
    if (debug) cout<<"start CatchData::write(...) "<<this<<endl;
    os<<KW_CATCH_DATA<<tb<<"#required keyword"<<endl;
    os<<wts::getBooleanType(hasN)<<tb<<"#has aggregate catch abundance (numbers) data?"<<endl;
    os<<wts::getBooleanType(hasB)<<tb<<"#has aggregate catch biomass (weight) data?"<<endl;
    os<<wts::getBooleanType(hasZFD)<<tb<<"#has size frequency data?"<<endl;
    os<<"#-----------AGGREGATE CATCH ABUNDANCE (NUMBERS)---------------#"<<endl;
    if (hasN) os<<(*ptrN)<<endl;
    os<<"#-----------AGGREGATE CATCH BIOMASS (WEIGHT)------------------#"<<endl;
    if (hasB) os<<(*ptrB)<<endl;
    os<<"#-----------NUMBERS-AT-SIZE-----------------------------------#"<<endl;
    if (hasZFD) os<<(*ptrZFD);
    if (debug) cout<<"end CatchData::write(...) "<<this<<endl;
}
/***************************************************************
*   Function to write object to R list.                        *
***************************************************************/
void CatchData::writeToR(ostream& os, std::string nm, int indent) {
    if (debug) cout<<"CatchData::writing to R"<<endl;
    for (int n=0;n<indent;n++) os<<tb;
    os<<nm<<"=list(name="<<qt<<name<<qt<<cc<<endl;
    indent++;
        //abundance
        if (hasN) {ptrN->writeToR(os,"abundance",indent); os<<cc<<endl;}
        
        //biomass
        if (hasB) {ptrB->writeToR(os,"biomass",indent); os<<cc<<endl;}
        
        //NatZ
        if (hasZFD) {ptrZFD->writeToR(os,"nAtZ",indent); os<<cc<<endl;}
    indent--;
    os<<"dummy=0)";
    if (debug) cout<<"CatchData::done writing to R"<<endl;
}
/////////////////////////////////end CatchData/////////////////////////
//----------------------------------------------------------------------
//          SurveyData
//----------------------------------------------------------------------
const adstring SurveyData::KW_SURVEY_DATA = "SURVEY_DATA";
/***************************************************************
*   read.                                                      *
***************************************************************/
void SurveyData::read(cifstream & is){
    if (debug) {
        cout<<"start SurveyData::read(...) for "<<type<<endl;
        cout<<"#------------------------------------------"<<endl;
        cout<<"#file name is "<<is.get_file_name()<<endl;
        cout<<"#------------------------------------------"<<endl;
    }
    if (!is) {
        cout<<"Apparent error reading SurveyData for "<<type<<endl;
        cout<<"#file name is "<<is.get_file_name()<<endl;
        cout<<"File stream is 'bad'--file may not exist!"<<endl;
        cout<<"Terminating!!"<<endl;
        exit(-1);
    }
    adstring str;
    is>>str;
    rpt::echo<<str<<tb<<"#Required keyword"<<endl;
    if (!(str==KW_SURVEY_DATA)){
        cout<<"#Error reading survey data from "<<is.get_file_name()<<endl;
        cout<<"Expected keyowrd '"<<KW_SURVEY_DATA<<"' but got '"<<str<<"'"<<endl;
        cout<<"Aborting..."<<endl;
        exit(-1);
    }
    
    is>>name;
    rpt::echo<<name<<tb<<"#survey name"<<endl;
    CatchData::read(is);//use parent class to read remainder of file
    if (debug) cout<<"end SurveyData::read(...) "<<this<<endl;
}
/***************************************************************
*   write.                                                     *
***************************************************************/
void SurveyData::write(ostream & os){
    if (debug) cout<<"start SurveyData::write(...) "<<this<<endl;
    os<<KW_SURVEY_DATA<<tb<<"#required keyword"<<endl;
    os<<name<<tb<<"#survey name"<<endl;
    CatchData::write(os);//use parent class to write remainder
    if (debug) cout<<"end SurveyData::write(...) "<<this<<endl;
}
/***************************************************************
*   Function to write object to R list.                        *
***************************************************************/
void SurveyData::writeToR(ostream& os, std::string nm, int indent) {
    if (debug) cout<<"SurveyData::writing to R"<<endl;
    for (int n=0;n<indent;n++) os<<tb;
    os<<nm<<"=list(name="<<qt<<name<<qt<<cc<<endl;
    indent++;
        //abundance
        if (hasN) {ptrN->writeToR(os,"abundance",indent); os<<cc<<endl;}
        
        //biomass
        if (hasB) {ptrB->writeToR(os,"biomass",indent); os<<cc<<endl;}
        
        //NatZ
        if (hasZFD) {ptrZFD->writeToR(os,"nAtZ",indent++); os<<cc<<endl;}
    indent--;
    os<<"dummy=0)";
    if (debug) cout<<"SurveyData::done writing to R"<<endl;
}
/////////////////////////////////end SurveyData/////////////////////////
//----------------------------------------------------------------------
//          FisheryData
//----------------------------------------------------------------------
const adstring FisheryData::KW_FISHERY_DATA = "FISHERY_DATA";
/***************************************************************
*   instantiation.                                             *
***************************************************************/
FisheryData::FisheryData(){
    hasEff = 0; ptrEff = 0;
    hasRCD = 0; ptrRCD = 0;
    hasDCD = 0; ptrDCD = 0;
    hasTCD = 0; ptrTCD = 0;
}
/***************************************************************
*   destruction.                                               *
***************************************************************/
FisheryData::~FisheryData(){
    if (ptrEff) delete ptrEff; ptrEff = 0;
    if (ptrRCD) delete ptrRCD; ptrRCD = 0;
    if (ptrDCD) delete ptrDCD; ptrDCD = 0;
    if (ptrTCD) delete ptrTCD; ptrTCD = 0;
}

/**************************************************************\n
 * Replace existing catch data with new values.
 * 
 * @param newCatZ_yxmsz - new total catch-at-size
 * @param newRatZ_yxmsz - new retained catch-at-size
 * @param wAtZ_xmz - weight-at-size
 */
void FisheryData::replaceCatchData(d5_array& newCatZ_yxmsz,d5_array& newRatZ_yxmsz,d3_array& wAtZ_xmz){
    if (hasTCD) {
        if (debug) cout<<"replacing total catch data"<<endl;
        ptrTCD->replaceCatchData(newCatZ_yxmsz,wAtZ_xmz);
        if (debug) cout<<"replaced total catch data"<<endl;
    }
    if (hasRCD) {
        if (debug) cout<<"replacing retained catch data"<<endl;
        ptrRCD->replaceCatchData(newRatZ_yxmsz,wAtZ_xmz);
        if (debug) cout<<"replaced retained catch data"<<endl;
    }
    if (hasDCD) {
        if (debug) cout<<"replacing discard catch data"<<endl;
        ivector bnds = wts::getBounds(newCatZ_yxmsz);
        d5_array newDatZ_yxmsz(bnds(1),bnds(2),bnds(3),bnds(4),bnds(5),bnds(6),bnds(7),bnds(8),bnds(9),bnds(10)); 
        newDatZ_yxmsz.initialize();
        for (int y=newDatZ_yxmsz.indexmin();y<=newDatZ_yxmsz.indexmax();y++){
            for (int x=1;x<=nSXs;x++){
                for (int m=1;m<=nMSs;m++){
                    for (int s=1;s<=nSCs;s++) {
//                        cout<<y<<tb<<x<<tb<<m<<tb<<s<<endl;
                        newDatZ_yxmsz(y,x,m,s) = newCatZ_yxmsz(y,x,m,s)-newRatZ_yxmsz(y,x,m,s);
//                        {
//                            cout<<"newCatZ = "<<newCatZ_yxmsz(y,x,m,s)<<endl;
//                            cout<<"newRatZ = "<<newRatZ_yxmsz(y,x,m,s)<<endl;
//                            cout<<"newDatZ = "<<newDatZ_yxmsz(y,x,m,s)<<endl;
//                        }
                    }
                }
            }
        }
        ptrDCD->replaceCatchData(newDatZ_yxmsz,wAtZ_xmz);
        if (debug) cout<<"replaced discard catch data"<<endl;
    }
}

/***************************************************************
*   read.                                                      *
***************************************************************/
void FisheryData::read(cifstream & is){
    if (debug) {
        cout<<"start FisheryData::read(...) for "<<this<<endl;
        cout<<"#------------------------------------------"<<endl;
        cout<<"#file name is "<<is.get_file_name()<<endl;
        cout<<"#------------------------------------------"<<endl;
    }
    if (!is) {
        cout<<"Apparent error reading FisheryData for "<<this<<endl;
        cout<<"#file name is "<<is.get_file_name()<<endl;
        cout<<"File stream is 'bad'--file may not exist!"<<endl;
        cout<<"Terminating!!"<<endl;
        exit(-1);
    }
    adstring str;
    is>>str;
    rpt::echo<<str<<tb<<"#Required keyword"<<endl;
    if (!(str==KW_FISHERY_DATA)){
        //TODO: do something here!!
    }
    is>>name;//fishery name
    is>>str; hasEff = wts::getBooleanType(str);//has effort data?
    is>>str; hasRCD = wts::getBooleanType(str);//has retained catch data?
    is>>str; hasDCD = wts::getBooleanType(str);//has discard catch data?
    is>>str; hasTCD = wts::getBooleanType(str);//has total catch data?
    
    rpt::echo<<name<<tb<<"#fishery source name"<<endl;
    rpt::echo<<wts::getBooleanType(hasEff)<<tb<<"#has effort data?"<<endl;
    rpt::echo<<wts::getBooleanType(hasRCD)<<tb<<"#has retained catch data?"<<endl;
    rpt::echo<<wts::getBooleanType(hasDCD)<<tb<<"#has observed discard catch data?"<<endl;
    rpt::echo<<wts::getBooleanType(hasTCD)<<tb<<"#has observed total catch data?"<<endl;
    
    //-----------Effort--------------------------
    if (hasEff){
        ptrEff = new EffortData();
        rpt::echo<<"#---Reading effort data for "<<name<<endl;
        is>>(*ptrEff);
        rpt::echo<<"#---Read effort data"<<endl;
    }
    //-----------Retained Catch--------------------------
    if (hasRCD){
        ptrRCD = new CatchData();
        rpt::echo<<"#---Reading retained catch data for "<<name<<endl;
        is>>(*ptrRCD);
        rpt::echo<<"#---Read retained catch data"<<endl;
    }
    //-----------Discard Catch--------------------------
    if (hasDCD){
        ptrDCD = new CatchData();
        rpt::echo<<"#---Reading discard catch data for "<<name<<endl;
        is>>(*ptrDCD);
        rpt::echo<<"#---Read discard catch data"<<endl;
    }
    //-----------Total catch--------------------------
    if (hasTCD){
        ptrTCD = new CatchData();
        rpt::echo<<"#---Reading total catch data for"<<name<<endl;
        is>>(*ptrTCD);
        rpt::echo<<"#---Read total catch data"<<endl;
    }
    if (debug) cout<<"end FisheryData::read(...) "<<this<<endl;
}
/***************************************************************
*   write.                                                     *
***************************************************************/
void FisheryData::write(ostream & os){
    if (debug) cout<<"start FisheryData::write(...) "<<this<<endl;
    os<<KW_FISHERY_DATA<<tb<<"#required keyword"<<endl;
    os<<name<<tb<<"#fishery source name"<<endl;
    os<<wts::getBooleanType(hasEff)<<tb<<"#has effort data?"<<endl;
    os<<wts::getBooleanType(hasRCD)<<tb<<"#has retained catch data?"<<endl;
    os<<wts::getBooleanType(hasDCD)<<tb<<"#has observed discard catch data?"<<endl;
    os<<wts::getBooleanType(hasTCD)<<tb<<"#has observed total catch data?"<<endl;
    os<<"#-----------Effort Data---------------#"<<endl;
    if (hasEff) os<<(*ptrEff);
    os<<"#-----------Retained Catch Data---------------#"<<endl;
    if (hasRCD) os<<(*ptrRCD);
    os<<"#-----------Observed Discard Catch Data----------------#"<<endl;
    if (hasDCD) os<<(*ptrDCD);
    os<<"#-----------Observed Total Catch Data------------------#"<<endl;
    if (hasTCD) os<<(*ptrTCD);
    if (debug) cout<<"end FisheryData::write(...) "<<this<<endl;
}
/***************************************************************
*   Function to write object to R list.                        *
***************************************************************/
void FisheryData::writeToR(ostream& os, std::string nm, int indent) {
    if (debug) cout<<"FisheryData::writing to R"<<endl;
    for (int n=0;n<indent;n++) os<<tb;
    os<<nm<<"=list(name="<<qt<<name<<qt<<cc<<endl;
    indent++;
        //effort
        if (hasEff) {ptrEff->writeToR(os,"effort",indent); os<<cc<<endl;}
        
        //retained catch data
        if (hasRCD) {ptrRCD->writeToR(os,"retained.catch",indent); os<<cc<<endl;}
        
        //observed discard catch data
        if (hasDCD) {ptrDCD->writeToR(os,"discard.catch",indent++); os<<cc<<endl;}
        
        //observed total catch data
        if (hasTCD) {ptrTCD->writeToR(os,"total.catch",indent++); os<<cc<<endl;}
    indent--;
    os<<"dummy=0)";
    if (debug) cout<<"FisheryData::done writing to R"<<endl;
}
/////////////////////////////////end FisheryData/////////////////////////

