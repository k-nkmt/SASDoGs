# SASDoGs: SAS Documentation Generator system

SASDoGs is a package for automatically generating documentation from SAS code.  
Built on the SAS Package Framework (SPF) documentation generation functionality, it features:  
- **Versatile usage**: Can be used with SAS projects beyond SPF file/folder structures.
- **Rich documentation generation**: In addition to markdown files like SPF, it can generate files for Sphinx and Jupyter Book (MyST).
- **Documentation from existing SPF packages**: Generate documentation directly from SPF package ZIP files when corresponding version documentation is not available locally.
- **GitHub Pages deployment automation**: Generate GitHub Actions workflows to automate documentation builds and deployment to GitHub Pages.

For detailed usage instructions, refer to the [documentation](https://k-nkmt.github.io/SASDoGs/), which also serves as a working example.  
It includes macro specifications and code execution examples using Jupyter Notebook.

## Install Package
```sas
filename packages "\path\to\your\packages";
%include packages(SPFinit.sas);
%installPackage(SASDoGs, github=k-nkmt);
```  