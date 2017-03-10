options VALIDMEMNAME=EXTEND  missing='';

libname als excel "D:\Dropbox\Parexel\Projects\#56022473AML2002\ALS\56022473AML2002_56022473AML2002_Version_7.00_02Mar2017_YR.xlsx"  ;
data forms;
   set als.'forms$A1:O'n;
   where DraftFormActive= 'TRUE';
run;


data Folders;
   set als.'Folders$A1:K'n;
   where OID ne '';
run;

data Matrix1_ALL;
   set als."'Matrix1#ALL$'"n;
/*   where Matrix_ALL ne '';*/
   array xxx _character_ ;
   do over xxx;
	   if xxx='X' then do;
	     OID= vname(xxx);
		 output;
	   end;
   end;
   keep Matrix__ALL  OID ;
run;

proc sql ;
  create table table1 as
  select a.* , b.FolderName , input(b.ordinal,best.) as ordinal_folder, 
              c.DraftFormName , input(c.ordinal,best.) as ordinal_form
  from   Matrix1_ALL  as a 
  left join FolderS as b  on a.OID= b.OID
  left join forms as c   on a.Matrix__ALL= c.OID
  ;
quit;

%let coverexist=1; 

filename bookmark "D:\Dropbox\Parexel\Projects\#56022473AML2002\eCRF\56022473AML2002 Version 7.00 02Mar2017 Unique forms_20170302\FreePic2Pdf_bkmk.txt" ;
data bookmark;
length studyinfo bookmark_raw page_raw $200 ; 
  infile bookmark dsd dlm='09'x firstobs=2  missover;
  input studyinfo $ bookmark_raw $  page_raw $   ;
  if bookmark_raw ne '' ; 
  page= page_raw - %eval(&coverexist); 
run;

proc sort data= bookmark  nodupkey;
by bookmark_raw page;
run;

proc sort data= bookmark nodupkey ;
by bookmark_raw;
run;


proc sql ;
  create table table2  as
  select a.* ,b.page 
  from table1 as a 
  left join bookmark as b
  on upcase(compress(DraftFormName))=upcase(compress(bookmark_raw) ) 
  ;

quit;

data nullpage;
  set table2;
  where page = . ;
run;


data _NULL_;
	if 0 then set nullpage nobs=n;
	call symputx('nrows',n);
	stop;
run;
%put nobs=&nrows;


filename outtemp "D:\Dropbox\Parexel\Projects\#56022473AML2002\eCRF\56022473AML2002 Version 7.00 02Mar2017 Unique forms_20170302\page_missing_madeup.csv" ;
proc export data= table2 
DBMS=CSV
OUTFILE=outtemp;
run;
x "start "" "D:\Dropbox\Parexel\Projects\#56022473AML2002\eCRF\56022473AML2002 Version 7.00 02Mar2017 Unique forms_20170302\page_missing_madeup.csv" ";
x 'pause() ' ;

%put _user_;


proc import out=table2(where=( foldername ne ''))  datafile= outtemp dbms= CSV replace;
            getnames= YES ;
			GUESSINGROWS=2000;
run;

proc sort data= table2 out= byVISIT SORTSEQ=LINGUISTIC(NUMERIC_COLLATION=ON);
  by ordinal_folder page;
run;

data byvisit_header;
  set byVISIT ;
  by ordinal_folder page;
  if first.ordinal_folder then do ;
     ordinal_folder= ordinal_folder -0.1 ; 
    output;
  end;
  keep ordinal_folder FolderName ;
run;

data byVISIT1 ;
  length class $20; 
    class='Visits'; 
	output;
  set byvisit_header  byVISIT(in=a) ;
  if a then do ;
  call missing(FolderName);
  end;

run;


proc sort data= byVISIT1  SORTSEQ=LINGUISTIC(NUMERIC_COLLATION=ON);
  by ordinal_folder page;
run;

proc sort data= table2 out= bydomain SORTSEQ=LINGUISTIC(NUMERIC_COLLATION=ON);
  by ordinal_form ordinal_folder ;
run;

data bydomain_header;
  set bydomain ;
  by ordinal_form ordinal_folder ;
  if first.ordinal_form then do ;
     ordinal_form= ordinal_form -0.1 ; 
    output;
  end;
 
  keep ordinal_form  DraftFormName page;
run;

data bydomain1 ;
length class $20; 
  class= 'Domains';
  output;
  set bydomain_header  bydomain(in=a drop = DraftFormName) ;
  if not a then do ;
   FolderName = cats(page);
   call missing(page) ; 
  end;
run;


proc sort data= bydomain1  SORTSEQ=LINGUISTIC(NUMERIC_COLLATION=ON);
  by ordinal_form ordinal_folder page;
run;


data gen_bookmark;
   set byvisit1(in=a) bydomain1(in=b) ;
   array col $200  col1 - col4 ;
      if not (ordinal_form = . and ordinal_folder = . ) then call missing(class); 
 COL1= class;
  if a then do ;
	  col2= FolderName ;
	  col3= DraftFormName;
	  col4= cats(page);
  end;  
  else if b then do ;
	  col2= DraftFormName ;
	  col3= FolderName;
	  col4= cats(page);
  end;  
  if col4=. then call missing(col4); 
  
  keep col: ; 
run;

filename genout "D:\Dropbox\Parexel\Projects\#56022473AML2002\SDTM\01. aCRF\FreePic2Pdf_bkmk.txt";
  data _null_ ;
    set gen_bookmark;
	file genout dlm='09'x dsd ;
   put COL1-COL4;
run;



