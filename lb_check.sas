proc delete data= _all_ ;
run;

libname transfer "D:\";
filename trial "D:\LABDICT_2015_08.xls";
filename latest "D:\LABDICT_ALL_2017_05.xls";
filename  valust "D:\LUDWIG_VALUELST_2017_05.xls" ;
filename result "D:\_LB_CHECK.xls" ;


 proc transpose data= transfer.supplb  out=supplb (drop=_:  );
	 by USUBJID IDVARVAL ;
	 ID QNAM ;
	 IDLABEL QLABEL ;
	 VAR QVAL;
 run;
proc sql noprint;
  select distinct QNAM into :suppvar separated by ",b." from transfer.supplb;
quit; 
%let suppvar= &suppvar; 
%put &suppvar; 

proc sql ;
  create table LB_RAW as 
  select a.* , b.&suppvar
  from transfer.LB  as a left join  
   supplb as b   
  on a.USUBJID=b.USUBJID  and b.IDVARVAL= cats(a.LBSEQ)
  ;
quit;

PROC IMPORT	OUT=  LUDWIG_VALUELST 
   DATAFILE= valust
        DBMS=EXCEL REPLACE;
   SHEET=LUDWIG_VALUELST; 
  GETNAMES=YES;    
RUN;

PROC IMPORT	 OUT=  LABDICT_ALL
  DATAFILE= latest
        DBMS=xls REPLACE;	
   SHEET=LABDICT_ALL; 
  GETNAMES=YES;    
RUN;

PROC IMPORT	 OUT=  LABDICT_trial
   DATAFILE= trial
        DBMS=xls REPLACE;	
   GETNAMES=YES;    
RUN;

proc sql ;
alter table LABDICT_ALL modify 
LBCAT char(65) ,
LBSPEC char(100),
LBMETHOD char(100),
LBTESTCD char(8),
LBTEST char(40)
;
alter table LABDICT_trial modify 
LBCAT char(65) ,
LBSPEC char(100),
LBMETHOD char(100),
LBTESTCD char(8),
LBTEST char(40)
;
alter table LB_RAW modify 
LBCAT char(65) ,
LBSPEC char(100),
LBMETHOD char(100),
LBTESTCD char(8),
LBTEST char(40)
;
quit;


filename DR_Map url "https://raw.githubusercontent.com/zhanglianbo35/SAS-code/master/45_Discrete_Result_Map.csv";
data Discrete_Result_Map;
length LBORRES $200 LBSTRESC $200; 
infile DR_Map dsd dlm=',' firstobs=2;
input LBORRES $ LBSTRESC $  ; 
run;

proc sort data= Discrete_Result_Map out=ore2std nodupkey;
	by _all_ ;
run;

data fmtDataset;
	set ore2std;
	retain fmtname '$ore2std' type 'C';
	rename LBORRES = Start  LBSTRESC= LABEL;
run;

proc format CNTLIN=fmtDataset;
run;

data LUDWIG_VALUELST_lv4;
  set LUDWIG_VALUELST ;
  where LEV= 'level 4' ; 
  LBCAT= scan(VALUEOID,3,'.') ;
  LBSPEC= scan(VALUEOID,5,'.') ;  
  LBMETHOD= scan(VALUEOID,7,'.') ;  
  LBTESTCD= VALVAL ;
  LBTEST= VALLABEL ;
  array val LBCAT  LBSPEC LBMETHOD ;
   do i=  1 to 3;
    if val[i]= '(NO VALUE RECORDED)' then val[i] = '' ;
   end;

  keep CODE LB: ;
run;

data LABDICT_ALL1;
  set LABDICT_ALL;
  drop LBDESCR LBFROM -- LcTO;
run;

data LABDICT_trial1;
  set LABDICT_trial;
  drop LBDESCR ;
run;

proc sort data= LABDICT_ALL1 out= LABDICT_ALL1_uni nodupkey; 
	by  LBCAT LBSPEC LBMETHOD LBTESTCD ;
run;

proc sort data= LABDICT_trial1 out=LABDICT_trial1_uni nodupkey; 
	by  LBCAT LBSPEC LBMETHOD LBTESTCD ;
run;


proc sort data= lb_raw(where=(LBTESTCD ne 'LBALL')) out=LB;
	by  LBCAT LBSPEC LBMETHOD LBTESTCD ;
run;

/*chk 10*/
/*LBNRIND is null but either LBORNRLO, LBORNRHI or LBSTNRC has been provided*/
data lb_chk10 ;
  set lb_raw ;
  where LBNRIND is missing and  cats(LBORNRLO, LBORNRHI , LBSTNRC) ne '' ;
  if LBSTRESC = "INDETERMINATE" and missing(LBNRIND) then delete ; 
run;

/*chk 11*/
/*LBORNRLO has been provided but LBSTNRLO has not been provided (and vice versa)*/
/*chk 12*/
/*LBSTORHI has been provided but LBSTNRHI has not be provided (and vice versa)*/

/*chk 18*/
/*If LBORNRLO contains a qualifier, it should be either > or >=*/
/*chk 19*/
/*If LBORNRHI contains a qualifier, it should be either < or <=*/
/*chk 20*/
/*If LBORNRLO contains a qualifier and that qualifier = '>' or '>=' then
SUPPLB.LBSTNRLQ should be present and populate with the same qualifier*/

/*chk 22*/
/*For discrete tests, check if the LBORRES is in Appendix 2 and ensure that the correct standardized representation is presented in LBSTRESC*/
/*chk 25*/
/*Flag error if LBORNRLO = LBORNRHI when both are not null*/
/*chk 26*/
/*Flag error if LBSTNRLO = LBSTNRHI when both are not null*/
/*chk 30*/
/*If the record indicated Not Done, LBORRES, LBORRESU, LBORNRLO, LBORNRHI, LBSTRESC, LBSTRESN, LBSTRESU, LBSTNRC, LBNRIND should be null*/

data lb_chk11 lb_chk12 lb_chk18 lb_chk19 lb_chk20 lb_chk21 lb_chk22 lb_chk25 lb_chk26  lb_chk30;
  set lb_raw;
  if (missing(LBORNRLO) and ^missing(LBSTNRLO))  or  (^missing(LBORNRLO) and missing(LBSTNRLO))  then output lb_chk11 ;
  if (missing(LBORNRHI) and ^missing(LBSTNRHI))  or  (^missing(LBORNRHI) and missing(LBSTNRHI))  then output lb_chk12 ;

  if compress(LBORNRLO,'>=') ne LBORNRLO and  not (find(LBORNRLO,'>' )=1 or find(LBORNRLO,'>=' )=1) then do;
    output lb_chk18 ; 
	if not (compress(LBSTNRLQ,  compress(LBSTNRLQ,'>=') ) ne compress(LBORNRLO,  compress(LBORNRLO,'>=') ) and (find(LBORNRLO,'>' )=1 or find(LBORNRLO,'>=' )=1) ) 
    then output lb_chk20;
  end;

  if compress(LBORNRHI,'<=') ne LBORNRHI and  not (find(LBORNRHI,'<' )=1 or find(LBORNRHI,'<=' )=1) then do ;
    output lb_chk19 ; 
	if not (compress(LBSTNRHQ,  compress(LBSTNRHQ,'<=') ) ne compress(LBORNRHI,  compress(LBORNRHI,'<=') ) and (find(LBORNRLO,'>' )=1 or find(LBORNRLO,'>=' )=1) ) 
    then output lb_chk21;
  end;

  if put(LBORRES,$ore2std.) ne LBORRES and put(LBORRES,ore2std.) ne LBSTRESC and LBORRES ne '' then output  lb_chk22 ;
  if LBORNRLO = LBORNRHI and ^missing(LBORNRLO) then output lb_chk25; 
  if LBSTNRLO = LBSTNRHI and ^missing(LBSTNRHI) then output lb_chk26; 
  if LBSTAT='NOT DONE' and compress(cats(LBORRES, LBORRESU, LBORNRLO, LBORNRHI, LBSTRESC, LBSTRESN, LBSTRESU, LBSTNRC, LBNRIND),'.') ne '' then output lb_chk30; 
run;  

/*chk 15*/
/*If ORSTRESU is present in SUPPLB, it should be differ from LBORRESU and LBSTRESU*/

data lb_chk15 ;
  set lb_raw;
  if find("&suppvar","ORSTRESU")>0 then do ;
    if ORSTRESU= LBORRESU or ORSTRESU=  LBSTRESU then output lb_chk15;
  end;
run;

/*chk 21*/
/*If LBORNRHI contains a qualifier and that qualifier =' <' or '<=' then */
/*SUPPLB.LBSTNRHQ should be present and populated with the same qualifier*/

data lb_chk21 ;
  set lb_raw;
 if compress(LBORNRHI,'<=') ne LBORNRHI and  not (find(LBORNRHI,'<' )=1 or find(LBORNRHI,'<=' )=1) then do ;
	if not (compress(LBSTNRHQ,  compress(LBSTNRHQ,'<=') ) ne compress(LBORNRHI,  compress(LBORNRHI,'<=') ) and (find(LBORNRLO,'>' )=1 or find(LBORNRLO,'>=' )=1) ) 
    then output lb_chk21;
  end;
run;



/*chk 13*/
/*LBORRES contains a qualifier, the result is continuous and LBSTRESN is not null*/

/*chk 14*/
/*LBORRES contains a qualifier, the result is continuous and LBSTRESC does not contain the same qualifer*/

data lb_chk13  lb_chk14;
 set lb_raw; 
 where LBSTAT= '' ;
 if compress(LBORRES,'<=>') ne LBORRES and input(compress(LBORRES,'<=>'),??best.) ne . then do;
   if (find(LBORRES,'>')=1 or find(LBORRES,'<')=1 or find(LBORRES,'>=')=1 or find(LBORRES,'<=')=1) and LBSTRESN ne . then output lb_chk13 ; 
   if substr(LBORRES,1,2) ne substr(LBSTRESC,1,2) then output lb_chk14 ;
 end;
run;

 
/*chk 1*/
/*The combination of LB.LBTESTCD/LBCAT/LBSPEC/LBMETHOD  
is not available in trial LUDWIG and not in current LUDWIG*/

data lb_chk1;
  merge lb(in=a) LABDICT_trial1_uni (in=b keep= LBCAT LBSPEC LBMETHOD LBTESTCD) ;
  by  LBCAT LBSPEC LBMETHOD LBTESTCD ;
  if a and not b ;
run;


/*chk 2*/
/*The combination of LB.LBTESTCD/LBCAT/LBSPEC/LBMETHOD 
is not available in trial LUDWIG and but is available in the current LUDWIG*/

data lb_chk2;
  merge lb(in=a) LABDICT_trial1_uni (in=b keep= LBCAT LBSPEC LBMETHOD LBTESTCD) 
                 LABDICT_ALL1_uni   (in=c keep= LBCAT LBSPEC LBMETHOD LBTESTCD)
         ;
  by  LBCAT LBSPEC LBMETHOD LBTESTCD ;
  if a and c and not b ;
run;



proc sort data= LABDICT_trial1 out=LABDICT_trial302_uni(keep= LBTESTCD) nodupkey; 
	by LBTESTCD ;
run;
proc sort data= LABDICT_trial1 out=LABDICT_trial303_uni(keep= LBTEST) nodupkey; 
	by LBTEST ;
run;
proc sort data= LABDICT_trial1 out=LABDICT_trial301_uni(keep= LBTESTCD LBTEST) nodupkey; 
	by LBTEST LBTESTCD ;
run;


proc sort data= lb;
	by LBTEST LBTESTCD ;
run;

/*chk 301*/
/*Both LB.LBTESTCD and LB.LBTEST are not available in trial LUDWIG*/

data lb_chk301;
  merge lb(in=a) LABDICT_trial301_uni(in=b); 
  by  LBTEST LBTESTCD ;
  if a and not b ;
run;


proc sort data= lb;
	by  LBTESTCD ;
run;

/*chk 302*/
/*LB.LBTESTCD is available in trial LUDWIG but LB.LBTEST is not*/

data lb_chk302;
  merge lb(in=a) LABDICT_trial302_uni(in=b); 
  by  LBTESTCD ;
  if a and not b ;
run;


proc sort data= lb;
	by  LBTEST ;
run;

/*chk 303*/
/*LB.LBTEST is available in trial LUDWIG but LB.LBTESTCD is not*/

data lb_chk303;
  merge lb(in=a) LABDICT_trial303_uni(in=b); 
  by  LBTEST ;
  if a and not b ;
run;



proc sort data= LABDICT_trial1(where=(TESTTYPE= 'CONTINUOUS')) out=LABDICT_trial4_uni nodupkey; 
	by LBCAT LBSPEC LBMETHOD LBTESTCD LBSTRESU ;
run;

proc sort data= LABDICT_trial1(where=(TESTTYPE= 'DISCRETE')) out=LABDICT_trial8_uni nodupkey; 
	by LBCAT LBSPEC LBMETHOD LBTESTCD LBSTRESU ;
run;

proc sort data= lb (where=(LBSTAT='' and  COMPRESS(LBORRES, "1234567890+-.")='' )) out= lb_continu;
	by LBCAT LBSPEC LBMETHOD LBTESTCD LBSTRESU ;
run;

data lb_continu1;
  merge lb_continu(in=a ) LABDICT_trial4_uni(in=b keep=LBCAT LBSPEC LBMETHOD LBTESTCD ); 
  by LBCAT LBSPEC LBMETHOD LBTESTCD  ;
  if a and b ;
run;


/*chk 4*/
/*If the combo has a testtype of continuous, 
does the LBSTRESU in LB match the LBSTRESU in trial LUDWIG*/

data lb_chk4;
  merge lb_continu1(in=a ) LABDICT_trial4_uni(in=b keep=LBCAT LBSPEC LBMETHOD LBTESTCD LBSTRESU); 
  by LBCAT LBSPEC LBMETHOD LBTESTCD LBSTRESU ;
  if a and not b ;
run;


proc sort data= lb  ; 
	by LBCAT LBSPEC LBMETHOD LBTESTCD  ;
run;

/*chk 5*/
/*If the combo has a testtype of continuous, please ensure that LBSTNRC is null*/

/*chk 7*/
/*If the combo has a testtype of continuous and LBNRIND is provided, it should be either HIGH/LOW or NORMAL*/

/*chk 31*/
/*For continuous record, derive LBNRIND based on ORRES values - check it matches LBNRIND provided in the dataset (use rules from document)*/
data lb_chk5 lb_chk7 lb_chk31;
  merge lb(in=a ) LABDICT_trial4_uni(in=b keep=LBCAT LBSPEC LBMETHOD LBTESTCD ); 
  by LBCAT LBSPEC LBMETHOD LBTESTCD  ;
  if a and  b ;
  if LBSTNRC ne '' then output lb_chk5; 
  if LBNRIND not in ('HIGH','LOW' , 'NORMAL' , '') then output lb_chk7; 

  if LBORRES ne '' and LBNRIND ne '' then do;
    if (LBNRIND= 'HIGH' and input(LBORRES, best.)<= input(LBORNRHI,best.) )
	  or (LBNRIND= 'LOW' and input(LBORRES, best.)>= input(LBORNRLO,best.) )
	  or (LBNRIND= 'NORMAL' and  not( input(LBORNRLO,best.)<=input(LBORRES, best.)<=  input(LBORNRHI,best.))  )
	  then output lb_chk31 ;
  end;
  else if LBORRES ne '' and  LBNRIND = '' then do;
    if  input(LBORRES, best.)> input(LBORNRHI,best.) > . 
	   or .<input(LBORRES, best.)< input(LBORNRLO,best.)
	   or   .<input(LBORNRLO,best.) <=input(LBORRES, best.) <= input(LBORNRHI,best.)
	   then output lb_chk31 ;
  end;

run;

/*chk 8*/
/*If the combo has a testtype of discrete and LBNRIND is provided,
it should be either ABNORMAL or NORMAL*/
/*chk 9*/
/*If the combination of LBTESTCD/LBCAT/LBSPEC/LBMETHOD has a testtype of discrete,*/
/*LBORNRLO, LBORNRHI, LBSTRESN, LBSTNRLO and LBSTNRHI should be null*/
/*chk 29*/
/*If the test is discrete and LBORRES is populated, LBORRESU should be null*/
/*chk 34*/
/*For discrete tests, ensure LBORNRLO and LBORNRHI are both null*/


data lb_chk8  lb_chk9  lb_chk29 lb_chk34  lb_chk35 (drop=_:);
  merge lb(in=a )  LABDICT_trial8_uni(in=b keep=LBCAT LBSPEC LBMETHOD LBTESTCD ); 
  by LBCAT LBSPEC LBMETHOD LBTESTCD  ;
  if a and  b ;
  if LBNRIND not in ('ABNORMAL' , 'NORMAL','') and LBORRES ne '' then output lb_chk8; 
  if  compress(cats(LBORNRLO,  LBORNRHI,  LBSTRESN,  LBSTNRLO , LBSTNRHI),'.') ne '' then   output lb_chk9; 
  if  LBORRES ne '' and  LBORRESU ne '' then output lb_chk29 ; 
  if cmiss( LBORNRLO , LBORNRHI) ne 2 then output lb_chk34;

  if LBSTNRC ne '' and LBSTRESC ne 'INDETERMINATE' then do ;
  _LBSTNRC = LBSTNRC ;
  _LBSTNRC = tranwrd(_LBSTNRC,' TO ','^');
  _LBSTNRC = tranwrd(_LBSTNRC,' to ','^');
  _LBSTNRC = compress(_LBSTNRC);

  _LBSTRESC = compress(LBSTRESC); 

/*  array var1 $200 _LBSTRESC _LBSTNRC ;*/
/*  array var2    LBSTRESC  LBSTNRC ;*/
/*  do i = 1 to 2; */
/*    var1[i]=  var2[i]; */
/*	var1[i]= tranwrd(var1[i],'NOT ','UN');*/
/*	var1[i]= tranwrd(var1[i],'NON ','UN');*/
/*  end;*/
    if not (
           ((_LBSTRESC ne scan(_LBSTNRC,1, '^;,')  and _LBSTRESC ne scan(_LBSTNRC,-1, '^;,')) and LBNRIND = 'ABNORMAL'  ) or 
           ((_LBSTRESC = scan(_LBSTNRC,1, '^;,')  or _LBSTRESC = scan(_LBSTNRC,-1, '^;,')) and  LBNRIND = 'NORMAL' )
           ) 
     then output lb_chk35 ;
  end;

run;


proc sort data= LABDICT_trial1(where=(TESTTYPE= 'CONTINUOUS')) out=LABDICT_trial6_uni nodupkey; 
	by LBCAT LBSPEC LBMETHOD LBTESTCD  ;
run;

proc sort data= LABDICT_trial1 out=LABDICT_trial7_uni nodupkey; 
	by LBTESTCD LBTEST ;
run;


data lb_continu1;
  merge lb_continu(in=a ) LABDICT_trial6_uni(in=b keep=LBCAT LBSPEC LBMETHOD LBTESTCD ); 
  by LBCAT LBSPEC LBMETHOD LBTESTCD  ;
  if a and b ;
run;


/*chk 6*/
/*If the combo has a testtype of continuous, 
does the LBORRESU in LB match an available LBORRESU in LUDWIG*/

proc sort data= lb_continu1 ;
	by LBCAT LBSPEC LBMETHOD LBTESTCD LBORRESU ;
run;

proc sort data= LABDICT_trial1(where=(TESTTYPE= 'CONTINUOUS')) out=LABDICT_trial6_1_uni nodupkey; 
	by LBCAT LBSPEC LBMETHOD LBTESTCD LBORRESU ;
run;


data lb_chk6;
  merge lb_continu1(in=a ) LABDICT_trial6_1_uni(in=b keep=LBCAT LBSPEC LBMETHOD LBTESTCD LBORRESU); 
  by LBCAT LBSPEC LBMETHOD LBTESTCD LBORRESU ;
  if a and not b ;
run;


proc sort data= lB;
by LBTESTCD LBTEST;
run;

/*chk 40*/
/*LB.LBTESTCD/LB.LBTEST should be a unique combination and match with trial LUDWIG*/

data lb_chk40;
  merge lb(in=a ) LABDICT_trial7_uni(in=b keep=LBTESTCD LBTEST); 
  by LBTESTCD LBTEST ;
  if a and not b ;
run;


proc sort data= lb;
  by LBCAT LBSPEC LBMETHOD LBTESTCD  ;
run;

/*chk 41*/
/*List out any continuous measure records where the LBORRES is not a numeric value,*/
data lb_chk41;
  merge lb(in=a ) LABDICT_trial6_uni(in=b keep=LBCAT LBSPEC LBMETHOD LBTESTCD ); 
  by LBCAT LBSPEC LBMETHOD LBTESTCD  ;
  if a and b ;
  if LBSTAT ne 'NOT DONE'  and input(LBORRES,??best.) = . ;
run;


ods select none;
PROC CONTENTS 
	directory 	
	DATA=_all_    	
	position                
	out=ContentsAsDataSet ; 
run;
ods select default;

data ContentsAsDataSet1;
  set ContentsAsDataSet;
  where MEMNAME like 'LB_CHK%';
  keep MEMNAME nobs ; 
run;

proc sort data= ContentsAsDataSet1 nodupkey;
by MEMNAME;
run;

filename lbdisc url "https://raw.githubusercontent.com/zhanglianbo35/SAS-code/master/LB_check_Description.csv";
data lbdisc;
length Check_No $8 Severity $20 Description $5000 Interpretation_Guidance $8000; 
infile lbdisc dsd dlm=',' firstobs=2;
input Check_No $ Severity $ Description $ Interpretation_Guidance $ ; 
label   Check_No = 'Check No.'
		Severity = 'Severity'
		Description = 'Description'
		Interpretation_Guidance = 'Interpretation Guidance' ;
run;

proc sql ;
create table ExceptionSummary as 
  select Check_No, nobs as count, Severity , Description , Interpretation_Guidance
  from lbdisc left join ContentsAsDataSet1 
  on  cats(Check_No)= substr(MEMNAME,7 );
quit;


proc sort data= ContentsAsDataSet1(where=(nobs>0)) out=ContentsAsDataSet2 SORTSEQ =LINGUISTIC (NUMERIC_COLLATION=ON); ;
	by MEMNAME;
run;

proc sort data= ExceptionSummary SORTSEQ =LINGUISTIC (NUMERIC_COLLATION=ON);
	by Check_No;
run;


proc sql noprint;
  select distinct MEMNAME into :chcklst separated by ' ' from ContentsAsDataSet2  ;
quit;
%let chcklst=&chcklst;
%put &chcklst;

%macro help(num);
 %global var type len;
 %let dsid=%sysfunc(open(&indsn,i));
 %let var=%sysfunc(varname(&dsid,&num));
 %let type=%sysfunc(vartype(&dsid,&num));
 %let len=%sysfunc(varlen(&dsid,&num));
 %let rc=%sysfunc(close(&dsid));
 %mend help;
%macro trim1(indsn= );
%let dsid=%sysfunc(open(&indsn,i));
 %let nvars=%sysfunc(attrn(&dsid,nvars));
 %let nobs=%sysfunc(attrn(&dsid,nobs));
 %let label=%sysfunc(attrc(&dsid,label));
 %let rc=%sysfunc(close(&dsid));
%if %length(&label)>0 %then %let label= label=&label;;

 options varlenchk=nowarn;
 %if &nobs>0 %then %do;
 data temp ;
  set &indsn ;
 run; 
   data _null_ (compress=Y);
    set temp end=last;
     retain _1-_&nvars 1;
     length _all $10000;
       %do i=1 %to &nvars;
         %help(&i);
         %if &type=C %then _&i=max(_&i,length(&var),8);/*lianbo update this place  see reference :   https://pharmasug.org/proceedings/2012/CC/PharmaSUG-2012-CC17.pdf*/
         %else if _n_=1 then _&i=&len;
          ;
       %end;
     if last then do;
        %do i=1 %to &nvars;
           %help(&i);
            %if &type=C  %then  _all=catx(' , ',_all , cat("&var char(",cats(_&i),')  format=$',cats(_&i),'.' ) ); ;
		%end;
            call execute("proc sql ; alter table  &indsn  modify  " || _all || ';quit;');
      drop _: ;
     end;
   run;
 %end;

 options varlenchk=warn;
 %mend trim1;


%macro cvt_char(data=);
    data %if %index(&data,.)>0 %then %scan(&data,2,'.'); %else &data;;
        set &data;
        array cvt  _character_;
        do over cvt;
            cvt =  tranwrd(cvt,'&',"%nrstr(&amp;)");
            cvt =  tranwrd(cvt,'<',"%nrstr(&lt;)");
            cvt =  tranwrd(cvt,'>',"%nrstr(&gt;)");
            cvt =  tranwrd(cvt,'"',"%nrstr(&quot;)");
            cvt =  tranwrd(cvt,"%bquote(')","%nrstr(&apos;)");
        end;
    run;
%mend;


data _null_;
    gendate=today(); gentime=time() ;
    call symputx("datum",put(date(),date9.)   ) ;
run;

%put &datum;


footnote;
ods html close; 
ods listing close;
   ods tagsets.excelxp   file=result
   style=seaside
         options(EMBEDDED_TITLES       = "yes"
                 EMBED_TITLES_ONCE     = "yes"
                 AUTOFIT_HEIGHT        = "yes"
                 ORIENTATION           = "landscape"
                 FROZEN_HEADERS        = "3"
                 CENTER_HORIZONTAL     = "yes"
			      AUTOFILTER            = "all");

 ods tagsets.ExcelXP options(sheet_name="ExceptionSummary"  FROZEN_HEADERS = "3");
%trim1(indsn=ExceptionSummary)

proc report data=ExceptionSummary nowd;
  title "ExceptionSummary";
   columns Check_No	count	Severity	Description	Interpretation_Guidance;
 define Check_No / style(column)=[cellwidth=3cm];
 define count / "Count" style(column)=[cellwidth=3cm];
 define Severity / style(column)=[cellwidth=3cm];
 define Description / style(column)=[cellwidth=10cm];
 define Interpretation_Guidance / style(column)=[cellwidth=16cm];
run;
title;

%macro repeat ;
%let count=1 ; 
  %do %while (%scan(&chcklst, &count,%str( )) ne %str() );

ods tagsets.ExcelXP options(sheet_name="check_%substr(%scan(&chcklst, &count,%str( )),7)"  FROZEN_HEADERS = "1");
/*%cvt_char(data=%scan(&chcklst, &count,%str( ))); */
%trim1(indsn=%scan(&chcklst, &count,%str( )) )

    proc print data=%scan(&chcklst, &count,%str( )) (drop= STUDYID DOMAIN)  noobs;
        var  _all_  /  style (data)={tagattr='format:@'};
    run;

%let count= %eval(&count +1) ; 

  %end;

 %mend;

 %repeat

  ods tagsets.ExcelXP options(sheet_name="Discrete_Result_Map" ABSOLUTE_COLUMN_WIDTH ="20.");
    proc print data=Discrete_Result_Map label noobs;
        var  _all_  /  style (data)={tagattr='format:@'};
    run;


 ods tagsets.excelxp close; 




