%sasdrugdev_login(
sdd_url=%str(https://sddcampine.ondemand.sas.com), 
sdd_userid=%str(ABCDEFG), 
sdd_password=%str(XXXXX)
)


%sasdrugdev_getchildren(
sdd_path=%str(/SAS/3952/56022473AML2002/Files/Staging/LAB/Biomarkers) ,
SAS_DSNAME=filelist,
sdd_recursive=1
)

proc sort data= filelist(where=(name like '56022473AML2002_ST_%.zip'))
          out=filelist1;
by path name ;
run;

data _null_ ;
  set filelist1 ;
  by path name ;
  if last.path ;
  call symputx('latest_st',path ) ;
run;
%put &=latest_st;

%let filename=%scan(&latest_st,-1,/);
%put &=filename;
%let kennet_dir=/projects/jjprd224002/stats/transfer/data/edt;


%sasdrugdev_downloadfile(
sdd_path=&latest_st,
sdd_version=, 
local_path= %str(&kennet_dir./&filename)
)

%sasdrugdev_logout