#!/bin/bash
mkdir 18S_DB

# NCBI taxonomy
kraken2-build --download-taxonomy --db 18S_DB/ --use-ftp

kraken2-build --download-library protozoa --db 18S_DB/ --use-ftp
kraken2-build --download-library fungi --db 18S_DB/ --use-ftp

# Build
kraken2-build --build --db 18S_DB/
kraken2-build --clean --db 18S_DB/



