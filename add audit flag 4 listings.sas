/*-----------------------------------------------------------------------------
  PAREXEL INTERNATIONAL LTD

  Sponsor / Protocol No:  
  PXL Study Code:        

  SAS Version:           9.3
  Operating System:      UNIX
-------------------------------------------------------------------------------

  Author:                Lianbo Zhang $LastChangedBy:  $
  Creation Date:         8Dec2015 / $LastChangedDate: 2015-12-03 00:34:14 -0500 (Thu, 03 Dec 2015) $

  Program Location/name: $HeadURL: $

  Files Created:

  Program Purpose:       Please flag -- old output = N, new output = Y

  Macro Parameters       NA

-------------------------------------------------------------------------------
MODIFICATION HISTORY:    Subversion $Rev:  $
-----------------------------------------------------------------------------*/

%macro updates ;

%put &SYSLAST;
%let libref=%scan(&syslast,1,.);
%let dsname=%scan(&syslast,2,.);

%if &libref=WORK %then %do ;
  %put %nrstr(Attent1on! Current file is n0t final d@tasets !!) ;
   %return;
%end;
%if %sysfunc(substr(%sysfunc(reverse(&libref )),1,1))=P %then %do ;
  %put %str(nima, zhe ge shi  preivous folder , hao bu hao) ;
   %return;
%end ;

%if not %sysfunc(exist(%unquote(&libref)%str(p.)%unquote(&dsname))) %then %do ;
%put %str(D@ta set &libref.p.&dsname d0es n0t ex1st.);
  %return;
%end;
/* get all variables' name before do the UPDATE */
ods select none;
PROC CONTENTS
        directory
        DATA=&SYSLAST
        position
        out=ContentsAsDataSet ;
run;
ods select default;

data xxx;
length newname $100;
  set ContentsAsDataSet ;
  newname= compress('a.'||name||' = b.'||name) ;
run;

proc sql noprint ;
select distinct newname into :keyvar  separated by " and "  from xxx ;
quit;

%let keyvar=&keyvar ;

/* ommit the variables "newoutput" in old datasets during the compare */

data temp ;
length newoutput $1;
  set &libref.P.&dsname ;
   newoutput='N' ;
run;

ods select none;
PROC CONTENTS
        directory
        DATA=&libref.P.&dsname
        position
        out=ContentsAslastDataSet ;
run;
ods select default;

data _null_ ;
  set ContentsAslastDataSet ;
  if _n_ =1 then do ;
    CRDATE_c= put(datepart(CRDATE),date9.) ;
    put "previous folder`s dataset was created on: "  CRDATE_c ;
        stop;
  end;
run;


/* do the UPDATE */
proc sql;
alter table &libref..&dsname.
  add newoutput  char(1) label="Changed?";
  update &libref..&dsname.  set newoutput = 'N' ;
  update &libref..&dsname. as a
  set newoutput='Y' where not exists(select * from temp as b where &keyvar ) ;
quit;

/*NOTE3: Please flag -- old output = 1, new output = 2 */
/*NOTE3: Please flag -- old output = N, new output = Y */

proc datasets library = work nolist;
    delete temp xxx ContentsAsDataSet  ContentsAslastDataSet;
quit;

%mend;

