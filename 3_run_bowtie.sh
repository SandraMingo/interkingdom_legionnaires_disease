#!/bin/bash

# Check if all three arguments are provided
if [ $# -ne 3 ]; then
  echo "Usage: $0 <human_index_path> <input_directory> <output_directory>"
  exit 1
fi

# Assign arguments to variables
HUMAN_INDEX="$1"
INPUT_DIR="$2"
OUTPUT_DIR="$3"

# Create the output directory if it doesn't exist
mkdir -p "${OUTPUT_DIR}"

# Iterate over FASTQ.GZ files in the specified input directory
find "${INPUT_DIR}" -maxdepth 1 -name "*_R1.fastq.gz" -print0 | while IFS= read -r -d $'\0' FILE1; do
  # Extract the sample name
  SAMPLE_NAME="${FILE1##*/}"
  SAMPLE_NAME="${SAMPLE_NAME%_R1.fastq.gz}"

  # Construct the name of the paired file
  FILE2="${INPUT_DIR}/${SAMPLE_NAME}_R2.fastq.gz"

  echo "Processing ${FILE1} and ${FILE2}..."

  # Align with Bowtie2, filter out human reads, and save to output directory
  bowtie2 -p 8 -x "${HUMAN_INDEX}" -1 "${FILE1}" -2 "${FILE2}" \
    --very-sensitive-local \
    --un-conc-gz \
    "${OUTPUT_DIR}/${SAMPLE_NAME}" \
    > "${OUTPUT_DIR}/${SAMPLE_NAME}_mapped_and_unmapped.sam"

  # Rename the output files in the output directory
  mv "${OUTPUT_DIR}/${SAMPLE_NAME}".1 "${OUTPUT_DIR}/${SAMPLE_NAME}_R1.fastq.gz"
  mv "${OUTPUT_DIR}/${SAMPLE_NAME}".2 "${OUTPUT_DIR}/${SAMPLE_NAME}_R2.fastq.gz"

  # Remove the SAM file (optional)
  rm "${OUTPUT_DIR}/${SAMPLE_NAME}_mapped_and_unmapped.sam"

  echo "Files created: ${OUTPUT_DIR}/${SAMPLE_NAME}_R1.fastq.gz and ${OUTPUT_DIR}/${SAMPLE_NAME}_R2.fastq.gz"
done

echo "Process completed."
