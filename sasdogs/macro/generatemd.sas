/*** HELP START ***//* 
Generate markdown documentation files from source code

Extracts documentation from source code comments and generates markdown files.
Supports multiple documentation depth levels for flexible organization.

### Parameters

- **fileList**: Dataset containing information about files
- **depth**: Documentation organization depth level
  - `0` = Single consolidated file (default)
  - `1` = Separate file per type (macro, function, etc.)
  - `2` = Separate file per individual file
  - `-1` = Preserve source directory structure
- **docname**: Name of output documentation file when `depth=0` (default: `document.md`)
- **docsLocation**: Output directory path for generated documentation files
- **startPtn**: Pattern marking start of help documentation in source (default: `/@@@ HELP START @@@/` @ is asterisk)
- **endPtn**: Pattern marking end of help documentation in source (default: `/@@@ HELP END @@@/` @ is asterisk)

### Output

| Depth | Output Format |
|-------|---------------|
| 0 | Single `<packagename>.md` or `<docname>` file |
| 1 | Separate files per type (`macro.md`, `function.md`, etc.) |
| 2 | Individual files per source file |
| -1 | Files organized by source directory structure |

### Usage Example

```sas
%generateMD(
    fileList=work.myfiles,
    depth=1,
    docsLocation=/path/to/docs,
    startPtn="\/\*-+ HELP START -+\*\/",
    endPtn="\/\*-+ HELP END -+\*\/"
);
```

*//*** HELP END ***/

%macro generateMD(fileList=
                , depth=0
                , docname=document.md
                , docsLocation=
                , startPtn="\/\*{3} HELP START \*{3}\/"
                , endPtn="\/\*{3} HELP END \*{3}\/"
                )/minoperator; 

  %local saveopt filesWithCodes doclib zipref ;
  /* Check parameters */
  %if %sysfunc(exist(&fileList.)) = 0 %then
    %do;
      %put ERROR: Dataset &fileList. does not exist.;
      %abort;
    %end;

  %if not(%superq(depth) = -1 or %superq(depth) in (0 1 2)) %then
    %do;
      %put ERROR: Invalid depth value &depth.. Must be 0, 1, 2, or -1.;
      %abort;
    %end; 
  
  %let savedopt = %sysfunc(getoption(dlcreatedir)) %sysfunc(getoption(notes)) %sysfunc(getoption(source));
  %let doclib = _%sysfunc(datetime(), hex6.)d ;
  %let zipref = _%sysfunc(datetime(), hex6.)z ;
  options DLCREATEDIR NOnotes NOsource;
  libname &doclib. "&docsLocation.";
  libname &doclib. clear;
  
  %if %sysfunc(fileexist(&docsLocation.)) = 0 %then
    %do;
      %put ERROR: Could not create or access directory &docsLocation..;
      %abort;
    %end;

  %let filesWithCodes =  WORK._%sysfunc(datetime(), hex16.)c ;
  /* Sort by Grouping Variable */
  data &filesWithCodes.;
    length type group $200 ; 
    set &fileList.;
    where is_dir = 0 and upcase(ext) = 'SAS' ;
    
    _order = coalesce(input(kscanx(folder, 1, "_"), ?? best.), depth) ;
    type = coalescec(type, catx("_",  put(_order, z3.), folder)) ;
    if &depth. = 0 then 
      group = "1" ;
    else if &depth. = 1 then 
      group = coalescec(group, type) ;
    else 
      group = cats(_n_);
  run;
  
  proc sort data=&filesWithCodes.;
    by group name ;
  run;

  /* Main processing */
  data _null_; 
    /* break if no data */
    if 0 = NOBS then stop; 

    length refcode clcode filepath $1024 mod $3;
    mod = "" ;

    do until(EOFDS);
      set &filesWithCodes. end = EOFDS nobs = NOBS curobs=CUROBS;    
      by group ; 
      /* If targetLocation is a ZIP file */
      if prxmatch("/\.zip$/i", strip(base)) > 0 then 
        do ;
          call execute('filename ' || "&zipref." || '  zip "'|| strip(base) ||'";') ;
          refcode =  'infile ' || "&zipref.(" || strip(name) || ') end = EOF;';
          clcode =  'filename ' || "&zipref." || '  clear;' ;
        end;
      else
        do ;
          refcode =  'infile "'|| strip(path) ||'" end = EOF;';
          clcode =  '' ;
        end;
      /* Single file */
      %if %superq(depth) = 0 %then
        %do;
              
          if first.group then mod = "" ;
          else            mod = "MOD" ;

          %if %symexist(packageName) %then
            %do;
              filepath = cats("&docsLocation./", lowcase("&packageName..md"));

              call execute("data _null_;");
              call execute('  file "' || strip(filepath) || '" encoding =' || "&packageEncoding. mod ;");  
              call execute('  put ''## ' || catx(" ",fileshort2,type2) || ' <a name="' || strip(link) || '"></a> ######'';');
            %end;
          %else
            %do;
              filepath = "&docsLocation./&docName.";

              call execute("data _null_;");
              call execute('  file "' || strip(filepath) || '" '|| mod ||';');  
              call execute('  put ''## ' || name || ''';');
            %end;
        %end;
      /* Separate files per type */
      %if %superq(depth) = 1 %then
        %do;
          filepath = cats("&docsLocation./", lowcase(type), ".md");
          
          /* Create file header */
          if first.group then do;
            call execute('data _null_; file "' || strip(filepath) || '";');
            call execute('put "# ' || strip(type) || '"; put " "; run;');
          end;

          call execute("data _null_;");
          call execute('  file "' || strip(filepath) || '" mod;');
          call execute('  put " " / "## ' || strip(fileshort) || '";');
          call execute('  put " ";');
        %end;
      /* Separate files per individual file */
      %else %if %superq(depth) = 2 %then
        %do;
          filepath = cats("&docsLocation./", type, "_",  fileshort,".md");

          call execute("data _null_;");
          call execute('  file "' || strip(filepath) || '";');
          call execute('  put " " / "# ' || strip(fileshort) || '";');
          call execute('  put " ";');
        %end;
      /* Preserve source directory structure */
      %else %if %superq(depth) = -1 %then
        %do;
          filepath = cats("&docsLocation.", substr(path, length(base)+1, length(path)-length(base)-length(name)), fileshort,".md");
          /* Create Folder */
          call execute('options dlcreatedir;');
          call execute("libname _temp_ '" || cats("&docsLocation.", substr(path, length(base)+1, length(path)-length(base)-length(name))) || "';");
          call execute("libname _temp_ clear;");

          call execute("data _null_;");
          call execute('  file "' || strip(filepath) || '";');
          call execute('  put " " / "# ' || strip(fileshort) || '";');
          call execute('  put " ";');
        %end;
      
      /* Append content */    
      call execute(refcode) ;

      call execute("    printer = 0;");
      call execute("    do until(EOF);");
      call execute("      input;");
      call execute("      if prxmatch(cat('/', %bquote(&endPtn.) ,'/'), strip(_infile_)) > 0 then printer = 0;");
      call execute("      if printer then put _infile_;");
      call execute("      if prxmatch(cat('/', %bquote(&startPtn.) ,'/'), strip(_infile_)) > 0 then printer = 1;");
      call execute("    end;");

      if last.group = 0  then call execute('  put "  " / "---" / " ";                                             ');

      call execute('  putlog ''Doc. note ' !! cats(CUROBS) !! ' for ' !! strip(filepath) !! ' ready.'';');
      call execute("  stop;                                                               ");
      call execute("run;");
    end;
    
    call execute(clcode);
    stop;
  run;

  /* Clean Up */
  options &saveopt. ;

  proc datasets lib=work nolist;
    delete %scan(&filesWithCodes., 2, .) ;
  quit;

%mend generateMD;
