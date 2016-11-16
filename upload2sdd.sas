%sasdrugdev_login(
sdd_url=%str(https://sddcampine.ondemand.sas.com), 
sdd_userid=%str(ABCDEG, 
sdd_password=%str(XXXXXXXX)
)


filename dirlist pipe "ls /projects/jjprd224002/stats/transfer/outputs/*define*.zip" ;
data dirlist ;
     length fname $256; 
     infile dirlist length=reclen ;
     input fname $varying256. reclen ;
run;

proc sort data= dirlist (where=(find(fname,'prod',i)>0)) out=dirlist1;
  by fname;
run;

data _null_ ;
  set dirlist1 (end=eof) ;
  by fname;
  if eof then call symputx('define', fname);
run;
%put &=define;

%let definefilename=%scan(&define,-1,/);
%let sdd_dir=%str(/SAS/3952/56022473AML2002/Files/Staging/DM_CRO/SDTM_XPT_Package/Current);


/*Syntax:*/
/*%sasdrugdev_createfile(LOCAL_PATH=local-path, SDD_PATH=sdd-path*/
/*<, SDD_VERSIONING=sdd-versioning, SDD_VERSION=sdd-version, SDD_COMMENT=sdd_comment>);*/
/**/
/*Parameters: */
/*local_path - - required - the absolute path and name of the file on the local computer.*/
/*sdd_path - - required - the path of the file to be created.*/
/*sdd_versioning - - optional - indicates whether the file being created should be*/
/*        versioned. The default value is 0, which will create a non-versioned file. A*/
/*        value of 1 will create a versioned file.*/
/*        Values: 0 | 1*/
/*        Default: 0*/
/*sdd_version - - conditional - indicates the version number to assign to the file being*/
/*        point. This option is ignored when creating non-versioned file.*/
/*sdd_comment - - conditional - the comment for the versioned file being created. This*/
/*        option is ignored when creating a non-versioned file.*/

%sasdrugdev_createfile(local_path=%str(&define) , sdd_path=%str(&sdd_dir./&definefilename) , 
sdd_versioning=, sdd_version=, sdd_comment=)  