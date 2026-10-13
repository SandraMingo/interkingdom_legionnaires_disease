#!/bin/bash

# Verify necessary arguments
if [ "$#" -ne 2 ]; then
    echo "Use: $0 <input_directory> <output_directory>"
    exit 1
fi

# Adapters and primers
ADAPTER1_FWD="TCGTCGGCAGCGTCAGATGTGTATAAGAGACAG"
ADAPTER1_REV="GTCTCGTGGGCTCGGAGATGTGTATAAGAGACAG"
PRIMER1_FWD="TACACACCGCCCGTC"
PRIMER1_REV="TGATCCTTCYGCAGGTTCACCTAC"

# Input and output directories
DIR_IN="$1"
DIR_OUT="$2"

mkdir -p "$DIR_OUT"

# Iterate through all the _R1_001.fastq.gz files in the input directory
for R1 in "$DIR_IN"/*_R1.fastq.gz; do
    # Find the corresponding R2 file
    R2="${R1/_R1.fastq.gz/_R2.fastq.gz}"

    # Check R2 file exists
    if [ -f "$R2" ]; then
        # Create output filenames
        R1_trimmed="$DIR_OUT/$(basename ${R1/_R1.fastq.gz/_R1.fastq.gz})"
        R2_trimmed="$DIR_OUT/$(basename ${R2/_R2.fastq.gz/_R2.fastq.gz})"

        # Exec Cutadapt
        cutadapt -a $ADAPTER1_FWD -A $ADAPTER1_REV \
                 -g $PRIMER1_FWD -G $PRIMER1_REV \
                 -o "$R1_trimmed" -p "$R2_trimmed" \
                 "$R1" "$R2"

        echo "Processed: $R1 y $R2"
    else
        echo "R2 file not found for $R1"
    fi
done

