#!/bin/bash
# Use: 2_trim.sh -i INPUT_DIR -o OUTPUT_DIR
# Required: trimmomatic y Java in PATH

set -euo pipefail

usage() {
  echo "Use: $0 -i INPUT_DIR -o OUTPUT_DIR"
  exit 1
}

INPUT_DIR=""
OUTPUT_DIR=""

while getopts ":i:o:" opt; do
  case "$opt" in
    i) INPUT_DIR="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    *) usage ;;
  esac
done

[ -z "${INPUT_DIR}" ] && usage
[ -z "${OUTPUT_DIR}" ] && usage

# Basic validations
[ -d "${INPUT_DIR}" ] || { echo "Error: INPUT_DIR does not exist ${INPUT_DIR}" >&2; exit 1; }
mkdir -p "${OUTPUT_DIR}"

# Output
PAIRED_DIR="${OUTPUT_DIR%/}/paired"
UNPAIRED_DIR="${OUTPUT_DIR%/}/unpaired"
LOG_DIR="${OUTPUT_DIR%/}/logs"
mkdir -p "${PAIRED_DIR}" "${UNPAIRED_DIR}" "${LOG_DIR}"

# Dependencies
command -v trimmomatic >/dev/null 2>&1 || { echo "Error: trimmomatic not found in PATH" >&2; exit 1; }
command -v java >/dev/null 2>&1 || { echo "Error: java not found in PATH" >&2; exit 1; }

# Find samples with _R1_001.fastq.gz
mapfile -d '' R1_FILES < <(find "${INPUT_DIR}" -type f -name "*_R1.fastq.gz" -print0)

if [ "${#R1_FILES[@]}" -eq 0 ]; then
  echo "Error: Files with *_R1.fastq.gz not found in ${INPUT_DIR}" >&2
  exit 1
fi

echo "Found ${#R1_FILES[@]} samples (R1)."

# Iterate samples
for R1 in "${R1_FILES[@]}"; do
  # Basename without _R1_001.fastq.gz
  base="$(basename "$R1")"
  sample_prefix="${base%_R1.fastq.gz}"

  R2="${INPUT_DIR%/}/${sample_prefix}_R2.fastq.gz"
  if [ ! -f "$R2" ]; then
    echo "Warning: Missing R2 for ${sample_prefix}, omitted." >&2
    continue
  fi

  # Output files
  out_R1_paired="${PAIRED_DIR}/${sample_prefix}_R1.fastq.gz"
  out_R1_unpaired="${UNPAIRED_DIR}/${sample_prefix}_R1_unpaired.fastq.gz"
  out_R2_paired="${PAIRED_DIR}/${sample_prefix}_R2.fastq.gz"
  out_R2_unpaired="${UNPAIRED_DIR}/${sample_prefix}_R2_unpaired.fastq.gz"
  log_file="${LOG_DIR}/${sample_prefix}.trim.log"

  echo "Processing: ${sample_prefix}"
  set +e
  trimmomatic PE -threads "4" -phred33 \
    "$R1" "$R2" \
    "$out_R1_paired" "$out_R1_unpaired" \
    "$out_R2_paired" "$out_R2_unpaired" \
    HEADCROP:19 \
    LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:100 AVGQUAL:30 \
    2> "$log_file"
  status=$?
  set -e

  if [ $status -ne 0 ]; then
    echo "Error: Trimmomatic failed for ${sample_prefix}. Check ${log_file}" >&2
    # Next sample
    continue
  fi

  echo "OK: ${sample_prefix}"
done

echo "Trimming complete. Output:"
echo "  Paired:   ${PAIRED_DIR}"
echo "  Unpaired: ${UNPAIRED_DIR}"
echo "  Logs:     ${LOG_DIR}"

