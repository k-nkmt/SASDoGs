# macro
 
 
## collectfiles
 
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

  
---
 
 
## generatemd
 
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

  
---
 
 
## packagedoc
 
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

