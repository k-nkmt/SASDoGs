/*** HELP START ***//* 
Generate notebook-style artifacts from an annotated SAS program

Creates `.ipynb`, single `.html`, and `.md` outputs from a SAS program
that contains a notebook header block and markdown cell markers.

### Parameters

- **prgIn**: Path to the input SAS program file
- **outLocation**: Directory where output files are written
- **nbOut**: Output notebook filename for `.ipynb` generation (optional)
- **htmlOut**: Output notebook filename for `.html` generation (optional)
- **mdOut**: Output markdown filename for `.md` generation (optional)
- **hstartPtn**: Pattern that marks the start of the notebook header block
- **hendPtn**: Pattern that marks the end of the notebook header block
- **mstartPtn**: Pattern that marks the start of a markdown cell block
- **mendPtn**: Pattern that marks the end of a markdown cell block
- **optPtn**: Pattern that marks a code-cell option line

### Header Options In The Source File

- **title**: Notebook title used in generated outputs
- **author**: Author name written to notebook metadata and HTML meta tags
- **eval**: Default code-cell execution flag (`Y` or `N`)
- **include**: Default flag to include a cell in outputs (`Y` or `N`)
- **expand**: Default flag to expand macro expressions inside markdown cells (`Y` or `N`)
- **sansserif**: Font stack for proportional text in HTML output
- **monospace**: Font stack for code and preformatted text in HTML output
- **odsstyle**: ODS style used while generating HTML results from executed code cells
- **style_ref**: Optional fileref whose contents are appended as custom CSS in HTML output

### Usage Example

```sas
%generateNB(
  prgIn=/path/to/sample.sas,
  outLocation=/path/to/output,
  nbOut=sample.ipynb,
  htmlOut=sample.html,
  mdOut=sample.md
);
```
*//*** HELP END ***/

%macro generatenb(prgIn = 
                , outLocation = 
                , nbOut = 
                , htmlOut = 
                , mdOut = 
                , hstartPtn="\/\*{3} HEADER START .*\*{3}\/"
                , hendPtn="\/\*{3} HEADER END \*{3}\/"
                , mstartPtn="\/\*{3} MD START .*\*{3}\/"
                , mendPtn="\/\*{3} MD END \*{3}\/"
                , optPtn="#{2}.+#{2}"
                ) ;

  %if %sysfunc(fileexist(&prgIn.)) = 0 %then %do ;
    %put ERROR: prgIn does not exist.;
    %abort;
  %end ;    
  %if %sysfunc(fileexist(&outLocation.)) = 0 %then %do ;
    %put ERROR: outLocation does not exist.;
    %abort;
  %end ;
  %if %length(&nbOut.&htmlOut.&mdOut.) = 0 %then %do ;
    %put ERROR: Output file is not specified ;
    %abort;
  %end ;
    
  filename _prgin "&prgIn." ;
  filename _nbout "&outLocation./&nbout." encoding="utf-8"  ;
  filename _nbcells temp ;
  filename _html_ "&outLocation./&htmlout." encoding="utf-8" ;
  filename _jscells temp  ;
  filename _mdout "&outLocation./&mdout." encoding="utf-8"  ;
  filename _mdcells temp  ;
  filename _ymlhead temp  ;
  
  %local outlist execution_count exitfl saveopt out_count i j 
         title author eval include expand sansserif monospace odsstyle style_ref 
         _mdsrc outfile nbcontent ;

  %let nbcontent = WORK._%sysfunc(datetime(), hex16.)_ ;

  %let outlist = ;
  %if %superq(nbOut) ne %then %let outlist = &outlist. _nbcells ;
  %if %superq(htmlOut) ne %then %let outlist = &outlist. _jscells ;
    
  %let execution_count = 0 ;
  %let exitfl = 1 ;

  %let nbtitle = SAS Notebook ;
  %let nbauthor = NA ;
  %let nbeval = Y ;
  %let nbinclude = Y ;
  %let nbexpand = Y ;
  %let sansserif = "Inter", "Noto Sans", "Segoe UI", "Helvetica Neue", Arial, sans-serif ;
  %let monospace = "JetBrains Mono", "Cascadia Code", "SFMono-Regular", Menlo, Consolas, monospace ;
  %let odsstyle = HTMLBlue ;
  %let style_ref = ;

  data _null_ ;
    infile _prgIn end = eof ;
    file _ymlhead ;
    retain header 0 ;
    length k v e_text $500 ;
  
    input ;
    if _n_ < 4 and prxmatch(cats('/', &hstartPtn. ,'/'), _infile_) > 0 then header = 1 ;
    if _n_ > 3 and header = 0 then stop ;
    
    if header = 1 and prxmatch(cats('/', &hendPtn. ,'/'), _infile_) > 0 then 
      do ;
        call symputx("exitfl", 0 , "L") ;    
        call symputx("firstline", _n_ + 1, "L") ;
        stop ;
      end ;
    
    k = strip(upcase(kscanx(_infile_, 1, ":"))) ;
    v = strip(kscanx(_infile_, 2, ":"));
    if lengthn(v) = 0 then return ;
    select ;
      when(k="AUTHOR") call symputx("nbauthor", v, "L");
      when(k="TITLE")  call symputx("nbtitle",  v, "L");
      when(k="EVAL"    and upcase(v) in ("N", "Y")) call symputx("nbeval",    upcase(v), "L");
      when(k="INCLUDE" and upcase(v) in ("N", "Y")) call symputx("nbinclude", upcase(v), "L");
      when(k="EXPAND"  and upcase(v) in ("N", "Y")) call symputx("nbexpand",  upcase(v), "L");
      when(k="SANSSERIF") call symputx("sansserif", v, "L");
      when(k="MONOSPACE") call symputx("monospace", v, "L");
      when(k="ODSSTYLE") call symputx("odsstyle", v, "L");
      when(k="STYLE_REF") call symputx("style_ref", ifc(fexist(v), v, ""), "L");
      otherwise 
        do ;
          e_text = _infile_ ;
          e_text = prxchange('s/(?<!\$)&/&#38;/', -1, e_text) ;
          e_text = prxchange('s/(?<!\$)%/&#37;/', -1, e_text) ;
          e_text = prxchange('s/\$(%|&)/$1/', -1, e_text) ;
          len = lengthn(e_text) ;
          put '"' e_text $varying. len '\n",' ;
        end ;
    end;
  run ;
  
  %if &exitfl. = 1 %then 
    %do ;
      %put ERROR: No header;
      %goto exit ;
    %end ;

  data &nbcontent. ;
    infile _prgIn end = eof firstobs=&firstline.;
    length text $32767 cell_type $8 ;
    retain cell_type "code" rows 0 chunk 1 eval inc expand "" ;
  
    input ;
    text = _infile_ ;
    t_space = lengthc(_infile_) - lengthn(_infile_);
      
    if prxmatch(cats('/', &mstartPtn. ,'/'), text) > 0 then 
      do ;
        if rcount > 0 then chunk + 1 ; 
        rcount = 0 ;
        cell_type = "markdown" ;
        /* md cell option */
        if prxmatch('/include\s*=\s*[NY]/i', text) = 0 then inc = "&nbinclude."  ; 
        else inc = prxchange('s/.*include\s*=\s*([NY]).*/\U$1/i', -1, strip(text)) ;
        if prxmatch('/expand\s*=\s*[NY]/i', text) = 0 then expand = "&nbexpand."  ; 
        else expand = prxchange('s/.*expand\s*=\s*([NY]).*/\U$1/i', -1, strip(text)) ;
      end ;
    else if prxmatch(cats('/', &mendPtn. ,'/'), text) > 0 then 
      do ;
       if rcount > 0 then chunk + 1 ; 
       rcount = 0 ;
       cell_type = "code" ;
      end ;
    else rcount + 1 ;
    
    /* code cell option */
    if rcount = 1 and cell_type = "code" then 
      do ;
        if prxmatch(cats('/', &optPtn. ,'/'), text) > 0 then
          do ;
            if prxmatch('/eval\s*=\s*[NY]/i', text) = 0 then eval = "&nbeval." ; 
            else eval = prxchange('s/.*eval\s*=\s*([NY]).*/\U$1/i', -1, strip(text)) ;
            if prxmatch('/include\s*=\s*[NY]/i', text) = 0 then inc = "&nbinclude."  ; 
            else inc = prxchange('s/.*include\s*=\s*([NY]).*/\U$1/i', -1, strip(text)) ;
          end ;
        else 
          do ;
            eval = "&nbeval." ; 
            inc = "&nbinclude." ;
            output ;
          end ;
      end ;
    else if rcount > 0 then output ;
  
    if eof = 1 then call symputx("nchunk", chunk) ;
  run ;

%do i = 1 %to &nchunk. ; 
  filename _htmlsrc temp ;
  filename _nbsrc temp ;
  
  data _null_;
    file _htmlsrc ;
    set &nbcontent. end = eof ;
    length e_text $32767 ;
    where chunk = &i. ;
    
    if cell_type = "markdown" then
      do ;
        e_text = htmlencode(text, "lt gt quot") ;
        e_text = prxchange('s/(?<!\$)&/&#38;/', -1, e_text) ;
        e_text = prxchange('s/(?<!\$)%/&#37;/', -1, e_text) ;
        e_text = prxchange('s/\$(%|&)/$1/', -1, e_text) ;
      end ;
    else e_text = htmlencode(text, "lt gt amp quot") ;

    len = lengthn(e_text) + t_space ; 
      
    put '"' e_text $varying. len @ ;
    if eof = 0 then put '\n",' ;   
    else 
      do ;
        put '"' ;
        call symputx("cell_id", uuidgen(), "L") ;
        call symputx("cell_type", cell_type,"L") ;
        call symputx("cell_exp", expand,"L") ;
        call symputx("cell_inc", inc,"L") ;
      end ;
  run ;
  
  data _null_ ;
    file _nbsrc ;
    infile _htmlsrc end = eof ;
    length line $32767 ;
    input ;
    line = prxchange('s/"(.*?)\\n", ?.*/$1/', 1, htmldecode(_infile_)) ;
    if compress(line) = '""' then line = "" ;
    line = prxchange('s/("|\\)/\\$1/', -1, line) ;
    len = lengthn(line) ;
    put '"' line $varying. len @ ;
    if eof = 0 then put '\n",' ;   
    else put '"' ;
  run ;
  
  %if &cell_type. = markdown %then 
    %do ;
      %if &cell_inc. = N %then %goto mdskip ;

      filename _mdsrc_e temp ;
      filename _mdsrc_d temp ;
      filename _mdeval temp ;
      
      proc stream outfile=_mdeval ; begin &streamdelim.;
%if &cell_exp. = Y %then %do ;
%include _htmlsrc 
%end ;
%if &cell_exp. = N %then &streamdelim. readfile _htmlsrc;;
;;;;
      run ; 
      
      %do k  = 1 %to 2 ;
        data _null_ ;
          file %scan(_mdsrc_e _mdsrc_d, &k.) ;
          infile _mdeval end = eof ;
          length d_text line $32767 ;
          input ;
          d_text = htmldecode(_infile_);
        %if &k. = 1 %then 
          %do ;            
            do while (prxmatch('/".*\\n",/', d_text) > 0) ;
              line = prxchange('s/"(.*?\\n)", ?.*/$1/', 1, d_text) ;
              line = prxchange('s/\\(?!n\s*$)/\\\\/' , -1, line);
              line = catt('"', prxchange('s/"/\\"/', -1, line), '",') ;
              len = lengthn(line) ;
              d_text = prxchange('s/".*?\\n", ?//', 1, d_text) ;
              put line $varying. len ;
            end;
            line = d_text ;
          %end ;
        %else 
          %do ;
            do while (prxmatch('/".*\\n",/', d_text) > 0) ;
              line = prxchange('s/"(.*?)\\n",.*/$1/', 1, d_text) ;
              len = lengthc(prxchange('s/"(.*?)\\n",.*/$1/', 1, d_text)) ;
              d_text = prxchange('s/".*?\\n", ?//', 1, d_text) ;
              put line $varying. len ;
            end;
            line = dequote(d_text) ;                    
          %end ;
          if eof = 1 then 
            do ;
              len = lengthn(line) ;
              put line $varying. len ;
            end ;
        run ;
      %end ;
          
                
      %do j = 1 %to %sysfunc(countw(&outlist.)) ;
        %let outfile = %scan(&outlist., &j.) ;

        proc stream outfile= &outfile. mod ; begin &streamdelim.;
{
  "cell_type": "markdown",
  "id": "&cell_id.",
  "metadata": {},
  "source": [
&streamdelim. readfile _mdsrc_e;
   ]
  }
  %if &i. < &nchunk. %then , ;   
;;;;
        run ; 
      %end ;
      %if %superq(mdout) ne %then
        %do ;           
          data _null_ ;
            file _mdcells mod ;
            infile _mdsrc_d ;
            input ;
            put _infile_ ;
          run ;  
        %end ;
        
      filename _mdsrc_e clear ;
      filename _mdsrc_d clear ;
      filename _mdeval clear ;
      %mdskip:
    %end ;
  %else %if &cell_type. = code %then 
    %do;
      filename _code temp ;
      filename _log temp ;
      filename _elog temp ;
      filename _html temp ;
      filename _body temp ;
      filename _odsout temp ;
    
      data _null_;
        file _code ;
        set &nbcontent. end = eof ;
        where chunk = &i. ;
        len = lengthn(text) ;
        put text $varying. len ;
        if eof = 1 then 
          do;
            call symputx("cell_eval", eval,"L") ;
            call symputx("cell_inc", inc,"L") ;
          end ;
      run ;
    
      %if &cell_eval. = Y %then 
        %do ;
          %let execution_count = %eval(&execution_count. +1) ;
          %let out_count = &execution_count. ;
          
          %let saveopt = %sysfunc(getoption(notes)) %sysfunc(getoption(source)) ;
          options nosource nonotes ;
          ods html5 file = _odsout style=&odsstyle. ;
          proc printto log = _log new ;
          run ;
          options &saveopt. ;
          %include _code ;
          proc printto ;
          run ;
    
          ods html5 close ;
        
          data _null_;
            file _html ;
            infile _odsout end = eof ;
            length e_text $32767 ;
            input ;
            e_text = prxchange('s/("|\\)/\\$1/', -1, _infile_) ;
            len = lengthn(e_text) ;
            put '"' e_text $varying. len @ ;
            if eof = 0 then put '\n",' ; 
            else put '"' ;
          run ;
  
          data _null_;
            file _body ;
            infile _odsout end = eof ;
            retain outfl 0 ;

            input ;
            length e_text $32767 ;
            e_text = prxchange('s/("|\\)/\\$1/', -1, _infile_) ;
            len = lengthn(e_text) ;
            if prxmatch("/<div/", e_text) > 0 then outfl = 1 ; 
            if prxmatch("/<\/body>/", e_text) > 0 then 
              do ;
                put '""' ;
                stop ;
              end ;
            if outfl = 1 then put '"' e_text $varying. len '\n",' ;
          run ;

          data _null_;
            infile _log end = eof ;
            file _elog ;
            length e_text $32767 ;
            input ;
            
            e_text = htmlencode(htmlencode(_infile_)) ;
            e_text = compress(e_text, '0c'x);
            e_text = prxchange('s/("|\\)/\\$1/', -1, e_text) ;
            len = lengthn(e_text) ;
            
            put '"' e_text $varying. len @ ;
            if eof = 0 then put '\n",' ; 
            else put '"' ;
          run ;
        %end ;
      %else 
        %do ;
          %let out_count = null ;
          data _null_ ;
            file _html ;
            put '""' ;
          run ;
          data _null_ ;
            file _body ;
            put '""' ;
          run ;
          data _null_ ;
            file _elog ;
            put '""' ;
          run ;        
        %end ;

    %if &cell_inc. = N %then %goto codeskip ;

    %do j = 1 %to %sysfunc(countw(&outlist.)) ;
      %let outfile = %scan(&outlist., &j.) ;
      proc stream outfile=&outfile. mod ; begin &streamdelim.;
  {
   "cell_type": "code",
   "execution_count": &out_count.,
   "id": "&cell_id.",
   "metadata": {},
   "outputs": [
        {
     "data": {
      "text/html": [
;;;;
      run ;
      
   data _null_ ;
     file &outfile. mod ;
     %if &outfile = _nbcells %then infile _html ;     
     %if &outfile = _jscells %then infile _body ;
     ;
     input ;
     put _infile_ ;
   run ;
   
   proc stream outfile=&outfile. mod ; begin &streamdelim.;
        ],
      "text/plain": [
      %if &cell_eval. = Y %then 
       "<IPython.core.display.HTML object>"
      ;
      %else
       ""
      ;
    ]
    },
     "metadata": {},
     "output_type": "display_data"
    }
   ],
%if &outfile. = _jscells %then %do; 
  "log": [
&streamdelim. readfile _elog; 
   ],
%end ;
   "source": [
&streamdelim. readfile _nbsrc;
  ]
 }
  %if &i. < &nchunk. %then , ;   
;;;;
      run ;
    %end ;
    %if %superq(mdout) ne %then 
      %do ;
        data _null_ ;
          file _mdcells mod ;
          infile _code end = eof ;
          input ;
          if _n_ = 1 then put "```sas" ;
          put _infile_ ;
          if eof = 1 then put "```" ;
        run ;
      %end ;
    %codeskip:
    filename _code clear ;
    filename _log clear ;
    filename _elog clear ;
    filename _html clear ;
    filename _body clear ;        
    filename _odsout clear ;
  %end ; 
/*     filename _htmlsrc clear ; */
%end ;

  %if %superq(nbout) ne %then 
    %do ;
      proc stream outfile=_nbout prescol ; begin &streamdelim.;
{
  "cells": [ 
  ;;;;
      run ;
/* &streamdelim. readfile _nbcells; */
 data _null_ ;
   file _nbout mod ;
   infile _nbcells ;
   input ;
   put _infile_ ;
run ;

      proc stream outfile=_nbout mod ; begin &streamdelim.;
 ],
  "metadata": {
  "kernelspec": {
   "display_name": "SAS",
   "language": "sas",
   "name": "sas"
  },
  "language_info": {
   "codemirror_mode": "sas",
   "file_extension": ".sas",
   "mimetype": "text/x-sas",
   "name": "sas"
  },
  "title": "&nbtitle.",
  "author": "&nbauthor."   
 },
 "nbformat": 4,
 "nbformat_minor": 5
}  
;;;;
      run;
    %end ; 
  %if %superq(htmlout) ne %then  
    %do ;

data _null_ ;
  file _html_ ;
  %if %superq(style_ref) ne %then 
    %do ;
      infile &style_ref. end = eof  ;
      input ;
    %end ;

  if _n_ = 1 then 
  put 
 '<!--'
/'Notebook Style Template'
/' '
/'nbconvert https://github.com/jupyter/nbconvert'
/'by Jupyter Development Team, Licensed under the Modified BSD License. '
/'SAS Theme https://github.com/sassoftware/sas_kernel/tree/master/sas_kernel/theme'
/'by SAS Software, Licensed under the Apache License, Version2.0'
/'-->'
/'<!DOCTYPE html>'
/'<html>'
/'<head>'
/'  <meta charset="utf-8">'
/'  <meta http-equiv="X-UA-Compatible" content="IE=edge">'
/' <meta name="author" content="' "&nbauthor." '">'
/'  <meta name="viewport" content="width=device-width, initial-scale=1">'
/'  <title>' "&nbtitle." '</title>'
/' '
/'  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/github-markdown-css@5.8.1/github-markdown-light.min.css">'
/'  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.css">'
/'  <style>'
/'    :root {'
/'      --page-bg: #f4f6fa;'
/'      --cell-bg: #ffffff;'
/'      --border: #d9dfe8;'
/'      --text: #1f2937;'
/'      --muted: #6b7280;'
/'      --prompt-in: #2563eb;'
/'      --prompt-out: #b91c1c;'
/'      --input-bg: #f8fafc;'
/'      --stderr-bg: #b91c1c;'
/'      --stderr-text: #ffffff;'
/'      --font-sansserif: ' "%bquote(&sansserif.)" ';'
/'      --font-monospace: ' "%bquote(&monospace.)" ';'
/'    }'
/'    * { box-sizing: border-box; }'
/'    body {'
/'      margin: 0;'
/'      padding: 18px 12px 28px;'
/'      background: var(--page-bg);'
/'      color: var(--text);'
/'      font-family: var(--font-sansserif) ;'
/'    }'
/'    #notebook {'
/'      max-width: 1100px;'
/'      margin: 0 auto;'
/'      overflow: visible;'
/'      padding: 9ex 11ex 9ex 0;'
/'      background: var(--cell-bg);'
/'    }'
/'    .cell {'
/'      display: flex;'
/'      flex-direction: column;'
/'      align-items: stretch;'
/'      border: 1px solid transparent;'
/'      border-radius: 2px;'
/'      width: 100%;'
/'      margin: 0 0 8px;'
/'      padding: 5px;'
/'      overflow: visible;'
/'    }'
/'    .text_cell {'
/'      display: flex;'
/'      flex-direction: row;'
/'      align-items: stretch;'
/'      margin-bottom: 3px;'
/'    }'
/'    .inner_cell {'
/'      min-width: 0;'
/'      display: flex;'
/'      flex-direction: column;'
/'      align-items: stretch;'
/'      flex: 1;'
/'    }'
/'    .prompt {'
/'      min-width: 14ex;'
/'      margin: 0;'
/'      padding: 0.4em;'
/'      text-align: right;'
/'      font-family: var(--font-sansserif) ;'
/'      line-height: 1.21429em;'
/'      color: var(--muted);'
/'      user-select: none;'
/'      cursor: default;'
/'      font-size: 13px;'
/'    }'
/'    .input {'
/'      display: flex;'
/'      flex-direction: row;'
/'      align-items: stretch;'
/'      page-break-inside: avoid;'
/'    }'
/'    .input_prompt {'
/'      color: var(--prompt-in);'
/'      border-top: 1px solid transparent;'
/'    }'
/'    .input_area {'
/'      border: 1px solid var(--border);'
/'      border-radius: 2px;'
/'      background: var(--input-bg);'
/'      width: 100%;'
/'      overflow-x: auto;'
/'    }'
/'    .input_area pre,'
/'    .output_text pre,'
/'    .text_cell_render pre {'
/'      margin: 0;'
/'      padding: 6px 8px;'
/'      border: 0;'
/'      border-radius: 0;'
/'      line-height: 1.35;'
/'      font-size: 14px;'
/'      white-space: pre-wrap;'
/'      word-break: break-word;'
/'      font-family: var(--font-monospace);'
/'    }'
/'    .output_wrapper {'
/'      position: relative;'
/'      display: flex;'
/'      flex-direction: column;'
/'      align-items: stretch;'
/'      z-index: 1;'
/'    }'
/'    .output { display: flex; flex-direction: column; align-items: stretch; }'
/'    .output_area {'
/'      display: flex;'
/'      flex-direction: row;'
/'      align-items: stretch;'
/'      page-break-inside: avoid;'
/'    }'
/'    .output_prompt { color: var(--prompt-out); }'
/'    .output_prompt p {margin: 0;}'
/'    .outmode-select {'
/'      margin-top: 6px;'
/'      width: 84px;'
/'      padding: 3px 4px;'
/'      border: 1px solid var(--border);'
/'      border-radius: 3px;'
/'      background: #ffffff;'
/'      color: #1f2937;'
/'      font-size: 12px;'
/'    }'
/'    .output_subarea {'
/'      overflow-x: auto;'
/'      padding: 0.4em;'
/'      flex: 1;'
/'      max-width: calc(100% - 14ex);'
/'    }'
/'    .output_text {'
/'      text-align: left;'
/'      color: #111827;'
/'      line-height: 1.35;'
/'    }'
/'    .markdown-body {'
/'      background: transparent;'
/'      color: inherit;'
/'      font-family: inherit;'
/'    }'
/'    .markdown-body > :first-child {'
/'      margin-top: 0;'
/'    }'
/'    .markdown-body > :last-child {'
/'      margin-bottom: 0;'
/'    }'
/'    .output_text .markdown-body,'
/'    .text_cell_render.markdown-body {'
/'      padding: 0;'
/'    }'
/'    .output_stderr {'
/'      background-color: var(--stderr-bg);'
/'      border-radius: 3px;'
/'      padding: 0 6px;'
/'    }'
/'    .output_stderr pre { color: var(--stderr-text); }'
/'    .text_cell_render {'
/'      width: inherit;'
/'      border-style: none;'
/'      outline: none;'
/'      resize: none;'
/'      color: #111827;'
/'      padding: 0.5em 0.5em 0.5em 0.4em;'
/'      line-height: 1.55;'
/'    }'
/'    .cm-s-default span.cm-comment { color: #008000; font-style: italic; }'
/'    .cm-s-default span.cm-atom { color: #fb0120; }'
/'    .cm-s-default span.cm-number { color: #164; }'
/'    .cm-s-default span.cm-property,'
/'    .cm-s-default span.cm-attribute { color: #a1c659; }'
/'    .cm-s-default span.cm-keyword,'
/'    .cm-s-default span.cm-def { color: #00f; }'
/'    .cm-s-default span.cm-string { color: #800080; }'
/'    .cm-s-default span.cm-operator,'
/'    .cm-s-default span.cm-bracket,'
/'    .cm-s-default span.cm-variable { color: #505050; }'
/'    .cm-s-default span.cm-variable-2,'
/'    .cm-s-default span.cm-builtin { color: #000080; font-weight: bold; }'
/'    .cm-s-default span.cm-error { background: #fb0120; color: #b0b0b0; }'
/'    .cm-s-default span.cm-tag,'
/'    .cm-s-default span.cm-meta { color: #fb0120; }'
/'    .cm-s-default span.cm-link { color: #d381c3; }'
/'   /* Custom Style */  '
;

  %if %superq(style_ref) ne %then put _infile_ ;;

put 
 '  </style>'
/'</head>'
/' '
/'<body>'
/'  <div id="notebook">'
/'    <div class="container" id="notebook-container">'
/'      <template v-for="(cell, idx) in cells" :key="cell.id || idx">'
/'        <div class="cell text_cell rendered" v-if="cell.cell_type === ' "'markdown'" '">'
/'          <div class="prompt input_prompt"></div>'
/'          <div class="inner_cell">'
/'            <div class="text_cell_render rendered_html markdown-body" v-html="renderMarkdown(normalize(cell.source))"></div>'
/'          </div>'
/'        </div>'
/' '
/'        <div class="cell code_cell rendered" v-else-if="cell.cell_type === ' "'code'" '">'
/'          <div class="input">'
/'            <div class="prompt input_prompt">In [{{ displayCount(cell.execution_count) }}]:</div>'
/'            <div class="inner_cell">'
/'              <div class="input_area">'
/'                <pre class="code cm-s-default" data-lang="sas" :data-source="normalize(cell.source)"></pre>'
/'              </div>'
/'            </div>'
/'          </div>'
/' '
/'          <div class="output_wrapper" v-if="hasResult(cell) || hasLog(cell)">'
/'            <div class="output">'
/'              <div class="output_area">'
/'                <div class="prompt output_prompt">'
/'                  <p>Out[{{ displayCount(cell.execution_count) }}]:</p>'
/'                  <select class="outmode-select"'
/'                          v-if="hasResult(cell) && hasLog(cell)"'
/'                          v-model="outmode[cellKey(cell, idx)]">'
/'                    <option value="result">result</option>'
/'                    <option value="log">log</option>'
/'                  </select>'
/'                </div>'
/' '
/'                <div class="output_text output_subarea" v-if="currentMode(cell, idx) === ' "'result'" '">'
/'                  <div class="markdown-body" v-if="resultPayload(cell).html" v-html="resultPayload(cell).html"></div>'
/'                  <pre v-else>{{ resultPayload(cell).text }}</pre>'
/'                </div>'
/' '
/'                <div class="output_text output_subarea" v-else>'
/'                  <pre>{{ normalize(cell.log) }}</pre>'
/'                </div>'
/'              </div>'
/'            </div>'
/'          </div>'
/'        </div>'
/'      </template>'
/'    </div>'
/'  </div>'
/' '
/'  <script src="https://cdn.jsdelivr.net/npm/vue@3/dist/vue.global.prod.min.js"></script>'
/'  <script src="https://cdn.jsdelivr.net/npm/codemirror@5/lib/codemirror.min.js"></script>'
/'  <script src="https://cdn.jsdelivr.net/npm/codemirror@5/mode/sas/sas.min.js"></script>'
/'  <script src="https://cdn.jsdelivr.net/npm/codemirror@5/addon/runmode/runmode.min.js"></script>'
/'  <script src="https://cdn.jsdelivr.net/npm/marked@15/marked.min.js"></script>'
/'  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.js"></script>'
/'  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16/dist/contrib/auto-render.min.js"></script>'
/' '
/'   <script id="notebook-data" type="application/json">'
/'{'
/'  "cells": ['
;
run ;


data _null_ ;
  file _html_ mod ;
  infile _jscells end = eof  ;
  input ;

  put _infile_ ;
  if eof = 1 then put
 '  ]'
/'}'
/'  </script>'
/' '
/'  <script>'
/'    (function () {'
/'      function parseNotebookData() {'
/'        var dataNode = document.getElementById("notebook-data");'
/'        try {'
/'          return JSON.parse(dataNode.textContent || "{}");'
/'        } catch (e) {'
/'          return {'
/'            cells: [{'
/'              cell_type: "markdown",'
/'              source: ["# Invalid notebook-data\n", "JSON parse error: " + e.message]'
/'            }]'
/'          };'
/'        }'
/'      }'
/' '
/'      var notebook = parseNotebookData();'
/'      Vue.createApp({'
/'        data: function () {'
/'          return {'
/'            cells: Array.isArray(notebook.cells) ? notebook.cells : [],'
/'            outmode: {}'
/'          };'
/'        },'
/'        methods: {'
/'          normalize: function (value) {'
/'            var text = Array.isArray(value) ? value.join("") : (value == null ? "" : String(value));'
/'            return text;'
/'          },'
/'          displayCount: function (count) {'
/'            return typeof count === "number" ? count : " ";'
/'          },'
/'          renderMarkdown: function (text) {'
/'            return (window.marked && typeof window.marked.parse === "function") ? window.marked.parse(text) : text;'
/'          },'
/'          cellKey: function (cell, idx) {'
/'            return (cell && cell.id) ? String(cell.id) : String(idx);'
/'          },'
/'          hasLog: function (cell) {'
/'            return this.normalize(cell && cell.log).length > 0;'
/'          },'
/'          resultPayload: function (cell) {'
/'            var outputs = Array.isArray(cell && cell.outputs) ? cell.outputs : [];'
/'            var item = outputs.find(function (x) {'
/'              return x && x.output_type === "display_data";'
/'            });'
/'            if (!item) {'
/'              return { html: "", text: "" };'
/'            }'
/'            var data = item.data || {};'
/'            var html = this.normalize(data["text/html"]);'
/'            if (html) {'
/'              return { html: html, text: "" };'
/'            }'
/'            return { html: "", text: this.normalize(data["text/plain"]) };'
/'          },'
/'          hasResult: function (cell) {'
/'            var r = this.resultPayload(cell);'
/'            return !!(r.html || r.text);'
/'          },'
/'          currentMode: function (cell, idx) {'
/'            var key = this.cellKey(cell, idx);'
/'            if (!this.outmode[key]) {'
/'              this.outmode[key] = this.hasResult(cell) ? "result" : "log";'
/'            }'
/'            return this.outmode[key];'
/'          },'
/'          colorizeAndMath: function () {'
/'            document.querySelectorAll("pre.code[data-source]").forEach(function (el) {'
/'              var src = el.getAttribute("data-source") || "";'
/'              el.textContent = "";'
/'              if (window.CodeMirror && typeof window.CodeMirror.runMode === "function") {'
/'                window.CodeMirror.runMode(src, "sas", el);'
/'              } else {'
/'                el.textContent = src;'
/'              }'
/'            });'
/'            if (typeof renderMathInElement === "function") {'
/'              renderMathInElement(document.getElementById("notebook-container"), {'
/'                delimiters: ['
/'                  { left: "$$", right: "$$", display: true },'
/'                  { left: "$", right: "$", display: false }'
/'                ],'
/'                throwOnError: false'
/'              });'
/'            }'
/'          }'
/'        },'
/'        mounted: function () {'
/'          this.$nextTick(this.colorizeAndMath);'
/'        },'
/'        updated: function () {'
/'          this.$nextTick(this.colorizeAndMath);'
/'        }'
/'      }).mount("#notebook");'
/'    })();'
/'  </script>'
/'</body>'
/'</html>'
;  
run ;

    %end ;
  %if %superq(mdout) ne %then 
    %do ;
      filename _mdsrc temp ;
      proc stream outfile=_mdsrc quoting=double ; begin &streamdelim.;
%include _ymlhead;
;;;;
        run ; 
      data _null_ ;
        file _mdout ;
        infile _mdsrc ;
        if _n_ = 1 then put "---"
                           /"title: &nbtitle.  "
                           /"author: &nbauthor."
                           ;
        input ;
        length d_text line $32767 ;
        d_text = htmldecode(_infile_);
            do while (prxmatch('/".*\\n",/', d_text) > 0) ;
              line = prxchange('s/"(.*?)\\n",.*/$1/', 1, d_text) ;
              d_text = prxchange('s/".*?\\n",//', 1, d_text) ;
              len = lengthn(line) ;
              put line $varying. len ;
            end;
        put "---" ;
      run ;
      
      data _null_ ;
        file _mdout mod ;
        infile _mdcells ;
        input ;
        put _infile_ ;
      run ;

    %end ;
    
  proc datasets lib = work nolist;
    delete %scan(&nbcontent., 2, .) ;
  quit ;

  %exit: 
  filename _nbout clear ;
  filename _nbcells clear ;
  filename _html_ clear ;
  filename _jscells clear ;
  filename _mdout clear ;
  filename _mdcells clear ;
  filename _ymlhead clear ;

%mend generateNB ;