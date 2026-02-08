/*** HELP START ***//* 
Main macro for generating source files for SAS package documentation

Primary entry point for generating source of comprehensive documentation for SAS 
packages following the SAS Packages Framework (SPF) structure. 
Supports Jupyterbook(MyST) and Sphinx for documentation engines.

### Parameters

- **filesLocation**: Path to package source directory or ZIP file
- **docsLocation**: Output directory path for generated documentation
- **docDepth**: Documentation organization depth level
  - `0` = Single consolidated file
  - `1` = Separate files by type
  - `2` = Separate file per source file
- **engine**: Documentation engine to use (default: `SPF`)
  - `SPF` = Standard SPF markdown format
  - `Sphinx` = Sphinx documentation system
  - `MyST` = MyST Markdown for Jupyter Book
- **newConf**: Flag to create new configuration files (1 = yes, 0 = no; default: 0)
- **docTheme**: HTML theme for Sphinx/MyST engines (optional)
- **sphinxExt**: Sphinx extensions to include (for Sphinx engine) (optional)
- **ghActions**: Flag to generate GitHub Actions workflows for documentation deployment (0 = no, 1 = yes; default: 0)
- **wfLocation**: Location to save GitHub Actions workflow file(deploy.yml) (optional) 
  If you use SAS Ondemand, need to set this to use file system(.github is invisible).

### Usage Examples

**Basic SPF documentation:**

```sas
%packageDoc(
    filesLocation=/path/to/package,
    docsLocation=/path/to/docs
);
```

**Sphinx documentation with custom theme:**

```sas
%packageDoc(
    filesLocation=/path/to/package,
    docsLocation=/path/to/docs,
    docDepth=1,
    engine=Sphinx,
    newConf=1,
    docTheme=sphinx_rtd_theme,
    sphinxExt=napoleon
);
```

**MyST/Jupyter Book documentation:**

```sas
%packageDoc(
    filesLocation=/path/to/package,
    docsLocation=/path/to/docs,
    engine=MyST
);
```

*//*** HELP END ***/

%macro packageDoc(filesLocation  =
                , filesWithCodes =
                , docsLocation   =
                , docDepth       = 
                , engine         = SPF 
                , newConf        = 0                
                , docTheme       =
                , sphinxExt      =
                , ghActions      = 0
                , wfLocation     =    
                )/minoperator;

  %local packageName packageVersion packageGenerated packageAuthor packageMaintainer packageTitle packageEncoding 
        packageLicense packageRequired packageReqPackages packageHashF packageHashC
        pkgSPFVer pkgOSVer pkgSASVer filesWithCodes additionalContent
        saveopt doclib tmpdoc tmpOutDir device pkgref delref delDS  repoLocation relDocLocation;
        ;

  %let saveopt = %sysfunc(getoption(dlcreatedir)) %sysfunc(getoption(notes)) %sysfunc(getoption(source)) ;
  options DLCREATEDIR NOnotes NOsource;

  /* Check parameters */
  %let engine = %sysfunc(upcase(%superq(engine))) ;

  %if %sysfunc(fileexist(&filesLocation.)) = 0  %then
    %do;
      %put ERROR: Specified filesLocation &filesLocation. does not exist.;
      %abort;
    %end;

  %if %superq(filesWithCodes) ne and %sysfunc(exist(&filesWithCodes.)) = 0 %then
    %do;
      %put ERROR: Dataset &filesWithCodes. does not exist.;
      %abort;
    %end;

    /* Create docs directory if it doesn't exist */
  %let doclib = _%sysfunc(datetime(), hex6.)d ;
  libname &doclib. "&docsLocation.";
  libname &doclib. clear;
  %if %sysfunc(fileexist(&docsLocation.)) = 0 %then
    %do;
      %put ERROR: Specified docsLocation &docsLocation. could not be created.;
      %abort;
    %end;

  %if not(%superq(engine) in (SPF SPHINX MYST)) %then
    %do;
      %put ERROR: Invalid engine value &engine.. Must be SPF, SPHINX, or MYST.;
      %abort;
    %end;

  %if %superq(docDepth) ne %then 
    %do ;
      %if not(%superq(docDepth) in (0 1 2)) %then
        %do;
          %put ERROR: Invalid docDepth value &docDepth.. Must be 0, 1, or 2.;
          %abort;
        %end;
      %if %superq(docDepth) = 0 and %superq(engine) ne SPF %then
        %do;
          %put ERROR: docDepth=0 is only supported with engine=SPF.;
          %abort;
        %end;
      %if %superq(docDepth) in (1 2) and not(%superq(engine) in (SPHINX MYST)) %then
        %do;
          %put ERROR: engine=Sphinx/MyST only supports docDepth=1 or 2.;
          %abort;
        %end;
    %end ;
  %else
    %do ;
      %if %superq(engine) in (MYST SPHINX) %then
        %do;
          %put ERROR: docDepth parameter is required for engine=Sphinx/MyST.;
          %abort;
        %end;
    %end ;  

  %if %superq(newConf) ne %then 
    %do ;
      %if not(%superq(newConf) in (0 1)) %then
        %do;
          %put ERROR: Invalid newConf value &newConf.. Must be 0 or 1.;
          %abort;
        %end;
    %end ;

  %if %superq(ghActions) ne %then 
    %do ;
      %if not(%superq(ghActions) in (0 1)) %then
        %do;
          %put ERROR: Invalid ghActions value &ghActions.. Must be 0 or 1.;
          %abort;
        %end;
    %end ;

  /* Extract package metadata */
  %_getPackagemeta(targetPath = &filesLocation. ); 

  %if %superq(filesWithCodes) eq %then
    %do;
      %let filesWithCodes = WORK._%sysfunc(datetime(), hex16.)_ ;
      %let delDS = 1 ;
      %_collectFilesWithCodes(filesLocation = &filesLocation., filesWithCodes = &filesWithCodes. );
    %end;

  /* Check if filesLocation is a ZIP file */
  %if %sysfunc(prxmatch(/\.zip$/i, %superq(filesLocation))) > 0 %then 
  %do;
    %let device = zip;
    
    /* Create temporary directory for extracted file headers */
    %let tmpdoc = _%sysfunc(datetime(), hex6.)s ;
    %let tmpOutDir = %sysfunc(pathname(work))/&tmpdoc.;
    libname &tmpdoc. "&tmpOutDir.";
    libname &tmpdoc. clear;
    %let pkgref = _%sysfunc(datetime(), hex6.)z;
    filename &pkgref. zip "&filesLocation." ;
    
    %put NOTE: Extracting first 2 lines from ZIP files to temporary directory: &tmpOutDir.;
    
    data _null_;
      set &filesWithCodes.;
            
      /* Generate data step to extract first 2 lines */
      call execute(
        'data _null_; '||
        'infile &pkgref.('|| strip(name)|| ') end=eof; '||
        'file "'||"&tmpOutDir./"||strip(name)|| '"; '||
        'do linenum = 1 to 2 while(not eof); '||
        'input; '||
        'put _infile_; '||
        'end; '||
        'run;'
      );      
    run;
    
    /* Update filesWithCodes.path to point to temporary directory */
    data &filesWithCodes.;
      set &filesWithCodes.;
      path = catx("/", "&tmpOutDir.", name);
    run;
    
    filename &pkgref. clear;
  %end;

  %if %superq(engine)= SPF %then
    %do;
      %_spfDoc(docsLocation   = &docsLocation.
             , filesWithCodes = &filesWithCodes.
          ) ;
    %end;
  %else %if %superq(engine) = SPHINX %then
    %do;
      %_sphinxDoc(docsLocation   = &docsLocation.
                , filesWithCodes = &filesWithCodes.
                , docDepth       = &docDepth.
                , newConf        = &newConf.
                %if %superq(docTheme) ne %then
                , htmlTheme      = &docTheme.  ;
                %if %superq(sphinxExt) ne %then
                , sphinxExt      = &sphinxExt.  ;
                );
    %end;
  %else %if %superq(engine) = MYST %then
    %do;
      %_mystDoc(docsLocation   = &docsLocation.
              , filesWithCodes = &filesWithCodes.
              , docDepth       = &docDepth.
              , newConf        = &newConf.
              %if %superq(docTheme) ne %then
              , mystTheme      = &docTheme.  ;
              );
    %end;

  /* Generate GitHub Actions workflows if requested */
  %if %superq(ghActions)=1 %then
    %do;
      %if %index(%superq(docsLocation), %superq(filesLocation)) > 0 %then
      /* repository root = package root */
        %let repoLocation = %superq(filesLocation) ; 
      %else
      /* repository root is parent directory of package root */
        %let repoLocation = %sysfunc(prxchange(s/(.*)[\\\/].+[\\\/]?/$1/, -1, %superq(filesLocation))) ; 

      %let relDocLocation = %substr(%superq(docsLocation), %eval(%length(%superq(repoLocation))+2)) ;

      %put NOTE: Generating GitHub Actions workflows for repository &repoLocation. and relative docs path &relDocLocation..;
      %_generateWorkflows(repoLocation    = &repoLocation.
                        , relDocLocation  = &relDocLocation.
                        , wfLocation      = &wfLocation.
                          );
    %end;

  /* Clean Up */
  
  /* Delete temporary extraction directory if created */
  %if %superq(device) = zip %then 
    %do;
      data _null_;
        set &filesWithCodes. end=eof;
        rc = filename("&delref.", path);
        rc = fdelete("&delref.");

        if eof then do;
            rc = filename("&delref.", "&tmpOutDir.");
            rc = fdelete("&delref.");
            rc = filename("&delref.");
        end;
      run;
    %end;
  
  options &saveopt. ;
  %if %superq(delDS) ne  %then
    %do;
      proc datasets lib=work nolist;
        delete %scan(&filesWithCodes., 2, .): ;
      quit;
    %end;

%mend packageDoc;