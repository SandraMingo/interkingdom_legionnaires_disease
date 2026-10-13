#!/bin/bash
# Use: 4_run_kraken2_confidence.sh -i INPUT_DIR -o OUTPUT_DIR -d KRAKEN2_DB [-t THREADS] [-p PARALLEL_JOBS] [-c CONFIDENCE]
# Requirements: kraken2 in PATH and accessible Kraken2 database
set -euo pipefail

usage() {
  echo "Uso: $0 -i INPUT_DIR -o OUTPUT_DIR -d KRAKEN2_DB [-t THREADS] [-p PARALLEL_JOBS] [-c CONFIDENCE]"
  echo "  -i  Directory with FASTQ (*.fastq.gz) ending with _R1_001/_R2_001"
  echo "  -o  Output directory"
  echo "  -d  Kraken 2 database directory (contains hash.k2d, opts.k2d, taxo.k2d, etc.)"
  echo "  -t  Threads (default: 4)"
  echo "  -p  Number of parallel samples (default: 1; requires GNU parallel for >1)"
  echo "  -c  Confidence or minimum threshold for accepting a taxonomic assignment"
  exit 1
}

INPUT_DIR=""
OUTPUT_DIR=""
DB_DIR=""
THREADS=4
PARALLEL_JOBS=1
CONFIDENCE=0.2

while getopts ":i:o:d:t:p:c:" opt; do
  case "$opt" in
    i) INPUT_DIR="$OPTARG" ;;
    o) OUTPUT_DIR="$OPTARG" ;;
    d) DB_DIR="$OPTARG" ;;
    t) THREADS="$OPTARG" ;;
    p) PARALLEL_JOBS="$OPTARG" ;;
    c) CONFIDENCE="$OPTARG" ;;
    *) usage ;;
  esac
done

[ -z "${INPUT_DIR}" ] && usage
[ -z "${OUTPUT_DIR}" ] && usage
[ -z "${DB_DIR}" ] && usage

# Validations
[ -d "${INPUT_DIR}" ] || { echo "Error: INPUT_DIR does not exist: ${INPUT_DIR}" >&2; exit 1; }
mkdir -p "${OUTPUT_DIR}"
LOG_DIR="${OUTPUT_DIR%/}/logs"
REPORT_DIR="${OUTPUT_DIR%/}/reports"
mkdir -p "${LOG_DIR}" "${REPORT_DIR}"

# Warning if reports from a previous run already exist in this same OUTPUT_DIR.
n_existing_reports=$(find "${REPORT_DIR}" -maxdepth 1 -name "*_report.txt" | wc -l)
if [ "${n_existing_reports}" -gt 0 ]; then
  echo "Warning: ${REPORT_DIR} already contains ${n_existing_reports} report(s) from a previous run." >&2
  echo "       If any sample was deleted from ${INPUT_DIR} after that, its old report" >&2
  echo "       remains here and will be included in any subsequent aggregation even if the fastq does not exist." >&2
  echo "       Execute with CLEAN_REPORTS=1 to empty ${REPORT_DIR} before run, or do it by hand." >&2
fi

if [ "${CLEAN_REPORTS:-0}" -eq 1 ]; then
  echo "Clearing previous reports in ${REPORT_DIR}..."
  find "${REPORT_DIR}" -maxdepth 1 -name "*_report.txt" -delete
fi

command -v kraken2 >/dev/null 2>&1 || { echo "Error: kraken2 is not in PATH" >&2; exit 1; }
[ -d "${DB_DIR}" ] || { echo "Error: DB_DIR does not exist: ${DB_DIR}" >&2; exit 1; }
# Quick checks
if ! ls "${DB_DIR}"/hash.k2d "${DB_DIR}"/opts.k2d "${DB_DIR}"/taxo.k2d >/dev/null 2>&1; then
  echo "Warning: hash.k2d/opts.k2d/taxo.k2d en ${DB_DIR} could not be found; check that the DB has been created." >&2
fi

# Find R1/R2 pairs
mapfile -d '' R1_FILES < <(find "${INPUT_DIR}" -maxdepth 1 -type f -name "*_R1.fastq.gz" -print0)
if [ "${#R1_FILES[@]}" -eq 0 ]; then
  echo "Error: *_R1.fastq.gz not found in ${INPUT_DIR}" >&2
  exit 1
fi
echo "${#R1_FILES[@]} samples found."

run_one() {
  local R1="$1"
  local THREADS="$2"
  local DB_DIR="$3"
  local OUTPUT_DIR="$4"
  local LOG_DIR="$5"
  local REPORT_DIR="$6"
  local CONFIDENCE="$7"

  local base="$(basename "$R1" _R1.fastq.gz)"
  local R2="${INPUT_DIR%/}/${base}_R2.fastq.gz"
  if [ ! -f "$R2" ]; then
    echo "Warning: missing R2 for ${base}; omitted." >&2
    return 0
  fi

  local out_txt="${OUTPUT_DIR%/}/${base}_kraken2_output.txt"
  local out_report="${OUTPUT_DIR%/}/${base}_kraken2_report.txt"
  local log_file="${LOG_DIR%/}/${base}.kraken2.log"

  # Exec Kraken2 with standard report and paired classification
  {
    echo "== $(date) =="
    echo "Executing Kraken2: ${base}"
    echo "R1: $R1"
    echo "R2: $R2"
    echo "DB: $DB_DIR"
    echo "Threads: $THREADS"
  } >> "$log_file"

  set +e
  kraken2 \
    --db "$DB_DIR" \
    --paired "$R1" "$R2" \
    --threads "$THREADS" \
    --output "$out_txt" \
    --report "$out_report" \
    --confidence "$CONFIDENCE" \
    --use-names \
    >> "$log_file" 2>&1
  status=$?
  set -e

  if [ $status -ne 0 ]; then
    echo "Error: Kraken2 failed for ${base}. Check ${log_file}" >&2
    return $status
  fi

  # Move report to dedicated folder (maintain centralized copy)
  mv -f "$out_report" "${REPORT_DIR%/}/" 2>>"$log_file"

  echo "OK: ${base}"
}

export -f run_one
export INPUT_DIR

if [ "$PARALLEL_JOBS" -gt 1 ]; then
  command -v parallel >/dev/null 2>&1 || { echo "Error: PARALLEL_JOBS=${PARALLEL_JOBS} but GNU parallel it not in PATH" >&2; exit 1; }
  # Execute in parallel
  printf '%s\0' "${R1_FILES[@]}" | parallel -0 -j "${PARALLEL_JOBS}" --will-cite \
    run_one {} "${THREADS}" "${DB_DIR}" "${OUTPUT_DIR}" "${LOG_DIR}" "${REPORT_DIR}" "${CONFIDENCE}"
else
  # Sequential
  for R1 in "${R1_FILES[@]}"; do
    run_one "$R1" "${THREADS}" "${DB_DIR}" "${OUTPUT_DIR}" "${LOG_DIR}" "${REPORT_DIR}" "${CONFIDENCE}"
  done
fi

echo "Finalized. Reports in: ${REPORT_DIR}"
echo "Logs in: ${LOG_DIR}"
