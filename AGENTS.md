# AGENTS.md
 
## Purpose
This file contains instructions for AI agents.

This repository creates SAS packages using the SAS Package Framework (SPF).

The package enhances the versatility of SPF's documentation generation functionality and generates markdown files and configuration files for creating richer documentation using Sphinx and JupyterBook.

## Development Environment
While Sphinx and JupyterBook operation verification uses uv, it's not limited to uv; conda works fine as well.  
This package's functionality merely creates source markdown files and documentation build configuration files. The build library versions generally should be the latest or close to the latest versions.
Note that for JupyterBook, v2 using MyST is assumed.  
While v1 is Sphinx-based and easier to handle, v2 is used considering future updates and maintenance.

## Project Structure
The package root is `sasdogs`.  
Files excluded from documentation have filenames starting with `_`. Relatively important/complex ones are in individual files, while others are consolidated in `_inner.sas`.

Documentation is placed in `docs`, and the built version is displayed on GitHub Pages.  
Local builds are manually verified, while remote builds use GitHub Actions.
The workflow supports both Sphinx and MyST; this project uses MyST to add examples using .ipynb files.

Test code is not included in the package, but basic functionality is verified through .ipynb files for documentation.
Since .ipynb files are not included in the toc, they must be manually added to myst.yml.

## Other Notes
For stability and maintainability, coding should follow SPFinit.sas logic as much as possible, and the coding style should align with it.  
Macros intended to be called by users should have parameter validation, while those called internally don't require validation.