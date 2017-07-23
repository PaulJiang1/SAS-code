
libname SDTM "\\kennet.na.pxl.int\jjprd224002\stats\transfer\data\transfer" ; 
libname out "C:\PAREXEL\New Folder" ; 

proc sql noprint;
   select memname into :datalists separated by ' ' from sashelp.vtable where libname= "SDTM"  ;
quit;

%let datalists = &datalists; 
%put &=datalists;


%macro xxx ; 

  %let count=1 ;
  %do %while (%scan(%str(&datalists), %eval(&count.) ) ne %str() ) ; 

data %scan(%str(&datalists), %eval(&count.) );
length findname $500 N_PDV 8. special_char $300 ;
  set sdtm.%scan(%str(&datalists), %eval(&count.) ) (encoding=any);
/*  where DELETEDITEM ne 'Y';*/
  ARRAY CHAR _character_;
  do over char;
  findname= '';                   /*remove A-z,0-9,under score and some punctuations listed in argument2 */
  if compress(char,"#.,/+-()%;\><=&^*@!~`?'{}[]|: " || '"', 'n') ne ''
  then do;
    findname= vname(char);
    N_PDV =_n_;
		special_char= compress(char,"#.,/+-()%;\><=&^*@!~`?'{}[]|: " || '"', 'n');
   	output;
  end;
  end;
run;


data _NULL_;
	if 0 then set %scan(%str(&datalists), %eval(&count.) ) nobs=n;
	call symputx('nrows',n);
	stop;
run;
%put nobs=&nrows;

%if %eval(&nrows) > 0  %then %do;
  data out.%scan(%str(&datalists), %eval(&count.) ); 
    set %scan(%str(&datalists), %eval(&count.) );
  run;

PROC EXPORT DATA=  out.%scan(%str(&datalists), %eval(&count.) )
            DBMS=EXCEL 
            OUTFILE= "C:\PAREXEL\New Folder\specal character in SDTM.xls"   ;
			sheet=%scan(%str(&datalists), %eval(&count.) );
RUN;

%end;



%let count=%eval(&count + 1) ; 

%end; 


%mend; 

%xxx
