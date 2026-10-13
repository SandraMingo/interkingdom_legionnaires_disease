#!/bin/bash

#RDP database
wget https://genome-idx.s3.amazonaws.com/kraken/16S_RDP11.5_20200326.tgz
gunzip 16S_RDP11.5_20200326.tgz
tar -xvf 16S_RDP11.5_20200326.tar
kraken2-build --clean --db 16S_RDP_k2db/
kraken2-inspect --db 16S_RDP_k2db/

