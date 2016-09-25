/**********************************************************************************
*  Program name     : calculate MAGE
*  Project          : 
*  Written by       : Lianbo Zhang
*  Date of creation : 2015-05-22
*  Description      : This is the program to calculate the MAGE avg,  MAGE +/- 
                      based on "Calculating the Mean Amplitude of Glycemic Excursion from Continuous Glucose Monitoring Data:An Automated Algorithm"
                      Peter A. Baghurst, Ph.D. 2011
*  Macros called    : 
*  Input file       : ADLB
*  Output file      : 
*  Revision History :
*  Date      Author   Description of the change
*
**********************************************************************************/
Footnote "Prog Name: %sysget(SAS_EXECFILENAME) **By: &SYSUSERID ** Run on: %sysfunc(datetime(),datetime16.)";

/***************************************************************/
/*                MAGE                                         */
/***************************************************************/
proc sql noprint;
  create table mage_source as
  select *, std(LBSTRESN) as SD
    from cgm1
    where DCOMP=1
    group by USUBJID , APERIOD
    order by USUBJID , APERIOD, ADTM
    ;
quit;

data mage1;
  set mage_source;
run;

/*options nomprint;*/
%macro calculate_laglead (obj=);
data &obj;
  set &obj ;
  by USUBJID APERIOD ADTM;
  lag_LBSTRESN = ifn(first.APERIOD=0 and first.USUBJID=0 ,lag(LBSTRESN),.);
  lag2_LBSTRESN = ifn(lag2(APERIOD)=APERIOD and lag2(USUBJID)=USUBJID ,lag2(LBSTRESN),.) ;

  if eof1=0 then
    set &obj(firstobs=2 keep= LBSTRESN rename=( LBSTRESN= lead_LBSTRESN)) end=eof1;
  if last.APERIOD then call missing(lead_LBSTRESN );
  if eof2=0 then
     set &obj(firstobs=3 keep=USUBJID APERIOD LBSTRESN rename=( USUBJID =USUBJID2 APERIOD=APERIOD2 LBSTRESN= lead2_LBSTRESN)) end=eof2;
  if APERIOD2 ne APERIOD or USUBJID2 ne USUBJID then call missing(lead2_LBSTRESN );
  drop USUBJID2 APERIOD2;
run;
%mend;

%macro filter_turningpoint;
data mage1;
  set mage1;
  if LBSTRESN = lag_LBSTRESN then del_fl=1;
run;

data mage1;
  set mage1;
  where del_fl ne 1 ;
  drop lag_LBSTRESN lag2_LBSTRESN lead_LBSTRESN lead2_LBSTRESN  del_fl ;
run;

%calculate_laglead(obj=mage1)

data mage1;
  set mage1 ;
  if   min(lead_LBSTRESN, lag_LBSTRESN)<=LBSTRESN<= max(lead_LBSTRESN ,lag_LBSTRESN)
      and nmiss(lead_LBSTRESN, lag_LBSTRESN)  = 0
          then del_fl=1 ;
run;

data mage1;
  set mage1  end=eof;
  where del_fl ne 1 ;

%global obsturn;
  if eof then call symputx('obsturn',_N_);
  drop lag_LBSTRESN lag2_LBSTRESN lead_LBSTRESN lead2_LBSTRESN del_fl;
run;

%put after delete the non turing points nobs= &obsturn ;
%mend;


%macro step2_5 ;
/*********************************************************************/
/*  recalcuate lead lag LBSTRESN   */
/*********************************************************************/
%calculate_laglead(obj=mage1)

/************************************************************/
/*            filter the turning point                     */
/************************************************************/
%filter_turningpoint

%calculate_laglead(obj=mage1)

/************************************************/
/* step 3  delete two sides*/
/************************************************/
data mage1;
  set mage1 end=eof;

/**************************************/
    /*retain rule*/
/**************************************/
  if nmiss(lead2_LBSTRESN, lag2_LBSTRESN)=0 then do ;
    if
(LBSTRESN> max(lead2_LBSTRESN, lag2_LBSTRESN) and LBSTRESN>max(lead_LBSTRESN, lag_LBSTRESN))
or
(LBSTRESN< min(lead2_LBSTRESN, lag2_LBSTRESN) and LBSTRESN< min(lead_LBSTRESN, lag_LBSTRESN))
/*or */
/*  nmiss(lead_LBSTRESN, lag_LBSTRESN) ne 0*/
      then do ;
      retain_fl=1;
    end;
  end;

  if nmiss(lead_LBSTRESN, lag_LBSTRESN)=0 then do;
     if (0<= abs(LBSTRESN-lead_LBSTRESN)<= SD and 0 <=abs(LBSTRESN-lag_LBSTRESN)<= SD)
      then do;
        del_fl=1;
     end;
  end;

  if retain_fl ne 1 and del_fl=1 then delete;
run;

data mage1;
  set mage1 end=eof;
  drop retain_fl del_fl lag_LBSTRESN lag2_LBSTRESN  lead_LBSTRESN lead2_LBSTRESN;
%global obs2s;
  if eof then call symputx('obs2s',_N_);
run;

%put after delete two sides points nobs= &obs2s;

%mend;

%macro repeat2_5 ;
  %do %until (%eval(&obs2s=&obsturn ));
    %step2_5
  %end;

%SYMDEL obs2s  obsturn  ;
%mend;

 %repeat2_5

%macro repeat6_7 ;
  %do %until (%eval(&obsturn=&obs1s) );
/*********************************************************************/
/*  recalcuate lead lag LBSTRESN   */
/*********************************************************************/

%calculate_laglead (obj=mage1)
/************************************************************/
/*            filter the turning point                     */
/************************************************************/
%filter_turningpoint

/*********************************************************************/
/*  recalcuate lead lag LBSTRESN   */
/*********************************************************************/

%calculate_laglead (obj=mage1)
 /***********************************************************************/
 /*       step 6  delete only one side                                  */
 /***********************************************************************/

   data mage1;
      set mage1 end=eof;
/*    if nmiss(lead_LBSTRESN, lag_LBSTRESN) ne 0 then do;*/
/*      retain_fl=1;*/
/*    end;*/
     if  nmiss(lag_LBSTRESN, lag_LBSTRESN)=0 then do;
        if abs(LBSTRESN-lag_LBSTRESN)<= SD then del_fl=1;
     end;
     if del_fl=1 then delete;
   run;
    data mage1;
      set mage1 end=eof;
     %global obs1s;
      if eof then call symputx('obs1s',_N_);
    drop  del_fl lag_LBSTRESN lag2_LBSTRESN lead_LBSTRESN lead2_LBSTRESN;
    run;

%END;

%put last loop nobs=&obs1s;
%SYMDEL obsturn obs1s ;


%mend;

%repeat6_7

/****************************************************************/
/* step 8 delete beginning or end  */
/****************************************************************/
data mage2;
  set mage1;
  by USUBJID APERIOD ADTM;
run;

%calculate_laglead (obj=mage2)

data mage3  ;
  set mage2;
  by USUBJID APERIOD ADTM;
  if first.APERIOD and nmiss(lead_LBSTRESN, LBSTRESN)=0  then do;
    if . <abs(lead_LBSTRESN-LBSTRESN)<=SD then delete;
  end;
  if last.APERIOD and nmiss(lag_LBSTRESN, LBSTRESN)=0  then do;
    if . <abs(lag_LBSTRESN-LBSTRESN)<=SD then delete;
  end;
  drop lag_LBSTRESN   lead_LBSTRESN lag2_LBSTRESN   lead2_LBSTRESN;
run;
**************   end line******************************************* ;

%calculate_laglead (obj=mage3)

data analysis.mage3;
  set mage3;
run;


/**************************************************************************;*/
/*       judge MAGE+ or MAGE - */
/*************************************************************************;*/
data mageavg ;
/*retain lead_LBSTRESN LBSTRESN lag_LBSTRESN;*/
  length category $8;
  set mage3;

  if max(lead_LBSTRESN, lag_LBSTRESN, LBSTRESN) =  LBSTRESN then category= 'up';
  if min(lead_LBSTRESN, lag_LBSTRESN, LBSTRESN) =  LBSTRESN then category= 'down';

  if  nmiss(lag_LBSTRESN , LBSTRESN )=0 then diff_LBSTRESN= abs(lag_LBSTRESN - LBSTRESN);
    output ;
    category='Avg';
    output;
run;
*************************************************************;
/*           calculate the MAGE index                       */
*************************************************************;
proc means data=mageavg noprint nway;
    by USUBJID APERIOD;
    class category;
    var diff_LBSTRESN;
    output out=MAGE(keep= USUBJID APERIOD category MAGE)  mean=MAGE ;
run;

proc transpose data= MAGE out=mage_trans  Prefix= mage_ ;
  id category;
  by USUBJID APERIOD;
  var MAGE;
run;


data mage_final ;
  set mage_trans;
  drop _: ;
run;
