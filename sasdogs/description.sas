Type: Package
Package: SASDoGs
Title: SAS Documentation Generator system
Version: 0.1
Author: Ken Nakamatsu (ken-nakamatsu@knworx.com)
Maintainer: Ken Nakamatsu (ken-nakamatsu@knworx.com)
License: MIT
Encoding: UTF8

Required: "Base SAS Software"        

DESCRIPTION START:
 SASDoGs is a package for automatically generating documentation from comments in SAS code.  
 Built on the SAS Package Framework (SPF) documentation generation functionality, it features:  
 - Versatile usage: Enables creation of markdown files for SAS projects beyond SPF file/folder structures. Supports hierarchical document structures through options.
 - Rich package documentation generation: In addition to markdown files like SPF, it can also generate configuration files for Sphinx and Jupyter Book (MyST).
 - Documentation from existing SPF packages: Generate documentation directly from SPF package ZIP files when corresponding version documentation is not available locally.
 - GitHub Pages deployment automation: Generate GitHub Actions workflows to automate documentation builds and deployment to GitHub Pages.

 Available macros for invocation:  
 - `%collectFiles`: Collect file and folder information from specified folder or ZIP file and create a listing dataset.
 - `%generateMD`: Generate markdown files for documentation based on information collected by `%collectFiles`.  
 - `%packageDoc`: Generate markdown files and documentation configuration files from specified SPF folder or package ZIP file.

DESCRIPTION END: