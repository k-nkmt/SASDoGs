/*** HELP START ***//* 
Collect file information from directory or ZIP archive

Recursively scans a directory or ZIP file and creates a dataset containing
detailed information about all files and subdirectories found.
Extracts file metadata and path information.

### Parameters

- **targetLocation**: Path to directory or ZIP file to scan
- **maxDepth**: Maximum recursion depth for directory traversal (default: `10`)
  - Automatically set to `1` for ZIP files
- **listDataSet**: Output dataset name for file listing (default: `work.files`)

### Output Dataset Variables

| Variable | Description |
|----------|-------------|
| `path` | Full path to the file |
| `base` | Base directory path |
| `name` | File or directory name |
| `folder` | Parent folder name |
| `fileshort` | Filename without extension |
| `ext` | File extension |
| `is_dir` | Flag indicating if entry is a directory (`1`) or file (`0`) |
| `depth` | Recursion depth level |

### Usage Example

```sas
%collectFiles(
    targetLocation=/path/to/package, 
    maxDepth=5, 
    listDataSet=work.myfiles
);
```

*//*** HELP END ***/

%macro collectFiles(targetLocation =
                  , maxDepth       = 10
                  , listDataSet    = work.files
                  ) ;

  /* Check Parameters */
  %if %sysfunc(fileexist(&targetLocation.)) = 0 %then
    %do;
      %put ERROR: Target location &targetLocation. does not exist.;
      %abort;
    %end;

  /* Base Dataset */
  data &listDataSet. ;
    length path base $512 name folder fileshort $256 ext $16;
    call missing(of _all_) ;
    path = "&targetLocation.";
    base = path ;
    is_dir = 1;
    depth = 0;
  run;

  /* Recursive Directory or ZIP File Scan */
  data &listDataSet. ;
    length fref $8;
    modify &listDataSet.;

    device = "disk" ;
    maxDepth = &maxDepth. ;
    if prxmatch("/\.zip$/i", strip(base)) then 
      do;
        device = "zip" ;
        maxDepth = 1 ;
      end;

    if is_dir = 0 or depth >= maxDepth then return ;

    root = path ;
    folder = name ;
    r_depth = depth ;

    rc = filename(fref, root, device);
    if rc = 0 then
    do;
      did = dopen(fref);
      dnum = dnum(did);
      rc = filename(fref);
    end;
    else
    do;
      putlog 'ERROR: Unable to open ' root;
      return;
    end;

    do i = 1 to dnum;
      name = dread(did, i);
      path = catt(root, "/", name);
      depth = r_depth + 1 ;

      if device = "zip" then fid = 1 ;
      else
        do;
          fid = mopen(did, name);    
          rc = fclose(fid);
        end;
  
      if fid > 0 then
        do;
          fileshort = prxchange('s/(.*)\.(.*)/$1/', 1, name);
          ext = prxchange('s/(.*)\.(.*)/$2/', 1, name);
          if name = ext then call missing(ext) ;
          is_dir = 0 ;
          output ;
        end;
      else
        do;
          is_dir = 1 ;
          output ;
        end;
    end;
    rc = dclose(did);
  run;

  proc sort data=&listDataSet.;
    by path ;
  run;

%mend collectFiles;