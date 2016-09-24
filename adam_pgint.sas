*********************************************************************;
/*you should put spec.xlsm under the same folder with the program*/


%macro ADaMiniter(specname=, domainlist=);

options  mprint mlogic nosymbolgen noxwait;
/*options nomerror nonotes;*/

%macro currentroot;
%global currentroot;
%let currentroot= %sysfunc(getoption(sysin));
%if "&currentroot" eq "" %then %do;
%let currentroot= %sysget(SAS_EXECFILEPATH);
%end;
%mend;
%currentroot
%let saswork=%sysfunc(pathname(work));

%let pgmname=  %scan( %str(&currentroot),-1,\) ; 
%let root=%substr(%str(&currentroot),1,%eval(%index(%str(&currentroot), %str(&pgmname))-1));


%let specname=&specname;     %*here is the paramenter ;

data _null_ ;
length command $599;
 command= "copy /y  "||'"' || "&root&specname" || '"' || '  '||
          '"'|| "&saswork.\&specname" || '"' ;
  call system (command);
run;


libname spec "&saswork.\&specname" ;

data study;
  set spec.'ADSTUDYDEF$A1:E3'n  ;
  if _n_ ne 1;
run;

data _null_;
  set study ;
  call symputx('STUDYNAM',STUDYNAM);
  call symputx('PROTNAME',PROTNAME);
  call symputx('creatd', put(today(),date9.));
run;

data header;
  set spec.'ADM Variables$A1:aa'n  ;
  if _N_ = 1;
run;

proc transpose data= header  out=vheader ;
  var _ALL_;
run;

data _null_;
length VARLABEL $ 5999  ;
  set vheader  end = eof ;
  retain  VARLABEL;
  COL1= substr(COL1,1,256);
 if _n_ =1 then  VARLABEL= 'label ' ||_NAME_ || "="|| COL1;
 else VARLABEL= catx('',VARLABEL, _NAME_,'=', COL1);
  if eof then call symputx("addlabel", VARLABEL);
run;

data text ;
  set spec.'ADM Variables$A1:aa'n  
(dbsastype= (LNGTH=numeric))   ;
  if _n_ ne 1;

  &addlabel;
run;


data common;     /*maybe have other functions*/
  set text end=eof;
  where DATASET= "COMMON" ;
  array aa[5] $13 a1-a5;
  retain  a1--a5;
  count+1;
  aa[count]= VARNAME;
  if int(count/5)= count/5 or eof then do; 
    output;
    count2+1 ;
    call missing(of a1-a5 ,count);
  end;
  if eof then call symputx('obscom', count2);
  drop count:;
run;
%put &obscom;

data common_attri;     /*maybe have other functions*/
  set text end=eof;
  where DATASET= "COMMON" ;
/*  rename VARLABEL=VARLABEL DATATYPE= DATATYPE    LNGTH= LNGTH_C   NUMFMT=NUMFMT_C ;*/
run;

proc sort data= common_attri nodupkey;
    by VARNAME;
run;

%let domainlist= &domainlist ;   %* here is the paramter;

data _null_;
  count=1;
  do while (scan("&domainlist",count) ne '' );
   count+1;
  end;
  call symputx('domain_NO', count-1);
run;
%put &domain_NO;

%do i= 1 %to &domain_NO; 

    %let domain= %scan(&domainlist, &i);
    %if &domain ne %str() %then %do;
data text_pre ;
      set text ;
/*  *this place need adjust due to the relationship between ADSL and COMMON ;*/
      %if %upcase(&domain)=ADSL %then %do;
          where upcase(DATASET) in( "&domain" , "COMMON"); 
      %end;
      %else %do;
          where upcase(DATASET)= "&domain" ;  
      %end; 

/*      where upcase(DATASET)= "&domain" ;  */


     VARLABEL=tranwrd(VARLABEL,'0D0A'x,'');
      order+1;
    run;

    proc sort data= text_pre out=text_pre1 nodupkey;
      by DATASET VARNAME VARLABEL;
    run;

/*    proc sort data= text_pre1;*/
/*      by VARNAME;*/
/*    run;*/

/*    data text_pre2;*/
/*      merge text_pre1  Common_attri (keep= VARNAME VARLABEL  VARROLE DATATYPE LNGTH NUMFMT );*/
/*      by VARNAME;*/
/*      if VARLABEL_C ne VARLABEL then VARLABEL= VARLABEL_C ;*/
/*      if LNGTH= . then LNGTH=LNGTH_c;*/
/*      if NUMFMT='' then NUMFMT=NUMFMT_c;*/
/*      if DATATYPE='' then DATATYPE=DATATYPE_c ;*/
/*    run;*/

    proc sort data= text_pre1;
      by order;
    run;

title "ADM spec check finding:   DOMAIN= &domain" ;
    data text_out;
       length attr1 $20 attr2 $20  attr3 $320; 
       set text_pre1 end= eof ;
     file print;
       where  upcase(DERVCOPY) ="DERIVED" ;
       DATATYPE= lowcase(DATATYPE);
       if DATATYPE in( 'text') and ^missing(LNGTH )  then attr1= compress(catx('','char(',LNGTH,')'));
       else if  DATATYPE in('integer', 'float','date')  then attr1=  DATATYPE ;
       else do ;
          put "Spec DATATYPE and LNGTH maybe incomplete, please check.";
		      put "   Variable Name=  " VARNAME;
          put "**************************************************";
	     end;
       if length(VARNAME)>8 then do ;
          put "Variable name length > 8 char, please check" ;
		      put "   DOMAIN= &domain";
		      put "   Variable Name=  " VARNAME;
          put "**************************************************";
       end;
       if length(VARLABEL)>40 then do ;
          put "Variable label length > 40 char, please check" ;
		      put "   Variable Name=  " VARNAME;
          put "**************************************************";
       end;

       if NUMFMT ne '' then attr2= compress(catx('','format=', NUMFMT)); 
       if not eof then attr3= cats ( "label='",strip(VARLABEL), "' , ");
       else attr3= cats ( "label='",strip(VARLABEL), "'   ");
    run;

    data  obj_domain;
      set text_pre1 end= eof ;
/*      20160603 update this place for ADSL and COMMON issue*/
      where upcase(DATASET)= "&domain" ;  
/* ------------------eof -----------------------------------*/
      array bb[5] $13 b1-b5;
      retain  b1--b5;
      count+1;
      bb[count]=  VARNAME;
      if int(count/5)= count/5 or eof then do; 
        output;
        count2+1 ;
        call missing(of b1-b5 ,count);
      end;
      if eof then call symputx('obsdomain', count2);
      keep b1-b5;
    run;

    filename spectext "&root.&domain..sas"; 
      data _null_;
       set text_out  end = eof;
       file spectext;
       if _n_=1 then do;
/*set PXL header*/
    put @1 '/*-----------------------------------------------------------------------------' ; 
    put @1 'PAREXEL INTERNATIONAL LTD' ;
    put @1 "Sponsor / Protocol No: Janssen Research %nrstr(&) Development / &PROTNAME" ; 
    put @1 "PXL Study Code: &STUDYNAM";
    put @1 "SAS Version: 9.3";
    put @1 "Operating System: UNIX";
    put @1 "-------------------------------------------------------------------------------";
    put @1 "Author:          $LastChangedBy:   $";
    put @1 "Creation / modified: &creatd  / $LastChangedDate: $";
    put @1 "Program Location/name: $HeadURL: http://kennet.na.pxl.int:$";
    put @1 "Files Created: %lowcase(&domain).sas7bdat    %lowcase(&domain).log";
    put @1 "Program Purpose: Produce &domain. domain ";
    put @1 "Macro Parameters: NA";
    put @1 "-------------------------------------------------------------------------------";
    put @1 "MODIFICATION HISTORY: Subversion $Rev: $";
    put @1 "-----------------------------------------------------------------------------*/" ;
    put @1 "    " ;
    put @1 "    " ;

/*kill all dataset in work library*/
         put @1 '/*Kill datasets/views in WORK lib*/' ;
         put @1 'proc datasets lib=work memtype=(data view) nolist kill; run; quit;' ;
/*set common variable (not useful yet)*/
         put @1 '%let comvar= ' @;
         do i= 1 to &obscom ;
           set common(keep=a1-a5) point=i;
           put @13 a1 - a5 ;
          if i= &obscom then put @13 ';' / ;
         end;
/*set domain variable list , you can keep them and retain them to adjust the variable order*/
          put @1  '%let ' @; put @6 "&domain.var=" @ ;     
         do j= 1 to &obsdomain  ;
           set obj_domain  point=j ;
           put @20 b1 - b5 ;
          if j= &obsdomain then put @20 ';' / ;
         end;
/*set domain variable's metadata*/
         put /@1 'proc sql noprint;' ;
         put @3 "create table template" ;   
         put @3 ' ('  ;
       end;
        put  @8 VARNAME @;
        put  @21 attr1 @;
        put  @41 attr2 @;
        put  @61 attr3  ;
        if eof then do;
        put @3 ' );'  ; 
          put @1 'quit;' ;
      end;
    run;
 %end;
    
 %end;
 title;
/*    %symdel  obsdomain domain specname domainlist  obscom;*/
%mend;

%ADaMiniter(specname=  %str(222323 ADMMetadata 20160829 v0.1.xlsm)
            , 
            domainlist=ADSL
ADAE
ADMH
ADFBR
ADCM
ADJNT
ADART
ADNAL
ADLEE
ADDAC
ADVAS
ADBSF
ADEX
ADDSACT
ADLB
ADVS
ADHA
ADMDA
)


libname spec clear;


