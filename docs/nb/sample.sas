/*##ExcludeFromDocumentation##*/

/*** HEADER START ***//* 
title: SAS Notebook
author: NA 
eval: Y
include: Y
expand: Y
sansserif: "Inter", "Noto Sans", "Segoe UI", "Helvetica Neue", Arial, sans-serif 
monospace: "JetBrains Mono", "Cascadia Code", "SFMono-Regular", Menlo, Consolas, monospace 
odsstyle: HtmlBlue
style_ref:
date: $%sysfunc(putn($%sysfunc(today()), yymmdd10.))
*//*** HEADER END ***/
/*** MD START ***//* 
# Notebook Sample

This sample demonstrates notebook-style documentation inspired by R Markdown, Jupyter Notebook, and nbconvert.  
It can generate `.ipynb`, `.html`, and `.md` outputs from a SAS program that remains
directly executable as a standard SAS source file.  
It also supports notebook-style options such as `eval` and `include`, as well as
macro expansion inside markdown cells.

## Header
The header section stores notebook-level settings such as title and author.  
The header start pattern (default: `/*** HEADER START ***//*`) must appear within the first three lines.  
In practice it is usually placed at the top of the file, but an exclusion marker can still appear before it.  
This sample lists the default header options below.  

- **title**: Notebook title used in generated outputs
- **author**: Notebook author written to metadata
- **eval**: Default execution setting for code cells
- **include**: Default inclusion setting for cells in generated outputs
- **expand**: Default macro expansion setting for markdown cells
- **sansserif**: Sans-serif font stack for HTML output
- **monospace**: Monospace font stack for HTML output
- **odsstyle**: ODS style used for HTML result rendering
- **style_ref**: Optional fileref for custom CSS appended to the HTML output

## Cells
Markdown cells are defined by block comments wrapped by specific markers
(default: `/*** MD START ***//*` and `/*** MD END ***//*`).  
All other content is treated as a code cell.  
Global defaults are defined in the header, but cell-level options can override them.  
Markdown cell options are written on the markdown start marker, and code cell options
are written on the first line of the code cell using the option marker pattern.  

*//*** MD END ***/
proc print data=sashelp.class(obs=5);
  var name ;
run;

/*** MD START include = N***//* 
This cell is not included in generated outputs.  
The following code is therefore kept executable in the source file while being omitted  
from notebook-style outputs, which is useful for setup code.  
*//*** MD END ***/
*## include = N ##;
%let test2 = expanded ;
%macro hello(name=) ; hello &name. from macro %mend;

/*** MD START ***//* 
## Using Macros Inside Markdown Cells
Macro expansion is enabled by default.  
To allow `%` and `&` to expand inside markdown cells, prefix them with `$`.  
```
&test1. is not expanded.  
&test2. is $&test2..  

$%hello(name=world).  
```
Only code that has already run before the current markdown cell can contribute macro values.  
Macros defined later in the file are not available yet.  
To disable expansion explicitly, set `expand=N`.  

## Code Execution
Code cell execution is enabled by default.  
Because this feature uses `ods` and `proc printto`, it may interfere with code that manages
those destinations directly. In such cases, set `eval=N`.  
The code cell itself is still included in output, but it is not executed, so no result is captured.  
*//*** MD END ***/
*## eval = N ##;
/* Not executed */
proc print data=sashelp.class(obs=5);
run;

data _null_ ;
  a = "text\aa" ;
run ;

/*** MD START ***//* 
## YAML Header In Markdown Output
When generating markdown output, header entries other than notebook control settings
are emitted as-is into the YAML front matter.  

## Customizing HTML Output
You can customize the font stacks through `sansserif` and `monospace`.  
If you need stronger support for non-English text, explicitly selecting fonts is recommended.  

For more detailed styling, use `style_ref` to point to a fileref whose contents are appended
as custom CSS in the generated HTML output.  

*//*** MD END ***/