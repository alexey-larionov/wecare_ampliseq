#!/bin/bash

# s02_summarise_fastqc.sh
# Started: Alexey Larionov, Nov2016
# Last updated: Alexey Larionov, 28Jun2018

# Use: 
# sbatch s02_summarise_fastqc.sh

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s02_summarise_fastqc
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --time=00:10:00
#SBATCH --output=s02_summarise_fastqc.log
#SBATCH --qos=INTR

## Modules section (required, do not remove)
. /etc/profile.d/modules.sh
module purge
module load rhel7/default-peta4 

## Set initial working folder
cd "${SLURM_SUBMIT_DIR}"

## Report settings and run the job
echo "Job id: ${SLURM_JOB_ID}"
echo "Job name: ${SLURM_JOB_NAME}"
echo "Allocated node: $(hostname)"
echo "Time: $(date)"
echo ""
echo "Initial working folder:"
echo "${SLURM_SUBMIT_DIR}"
echo ""
echo "------------------ Output ------------------"
echo ""

# ---------------------------------------- #
#                    job                   #
# ---------------------------------------- #

# Start message
echo "Summarise fastqc"
date
echo ""

# Files and folders
base_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq"
data_folder="${base_folder}/data_and_results/d02_trimmed_fastq/fastqc"
output_folder="${base_folder}/data_and_results/d02_trimmed_fastq/fastqc_summary"
read_counts_file="${output_folder}/read_counts.txt"
summary_file="${output_folder}/summary.txt"
rm -fr "${output_folder}" # remove folder, if existed
mkdir -p "${output_folder}"

# Progress report
echo "base_folder: ${base_folder}"
echo "data_folder: ${data_folder}"
echo "output_folder: ${output_folder}"
echo "read_counts_file: ${read_counts_file}"
echo "summary_file: ${summary_file}"
echo ""

# Get list of fastqc folders
cd "${data_folder}"
fastqc_folders="$(find -mindepth 1 -maxdepth 1 -type d -name "*fastqc" | sed 's|^./||')"

# Progress report
echo "Found $(wc -w <<< $fastqc_folders) fast-qc folders"

# Prepare header for the fastqc summary file
read a_fastqc_folder <<< "${fastqc_folders}"
a_fastqc_summary_file="${data_folder}/${a_fastqc_folder}/summary.txt"
fastqc_summary_fields=$(awk 'BEGIN { FS="\t" } ; {print $2}' "${a_fastqc_summary_file}")
fastqc_summary_header=${fastqc_summary_fields// /_}
fastqc_summary_header=${fastqc_summary_header//$'\n'/'\t'} 
# note $ before '\n'
# http://stackoverflow.com/questions/7129047/new-line-in-bash-parameter-substitution-rev-n
fastqc_summary_header="sample_no\tillumina_id\tlane_no\tread_no\t${fastqc_summary_header}"

# Initialise output files
echo -e "sample_no\tillumina_id\tlane_no\tread_no\tCount" > "${read_counts_file}"
echo -e "${fastqc_summary_header}" > "${summary_file}"

# For each fast-qc folder
for fastqc_folder in ${fastqc_folders}
do

  # Parce the folder name 
  IFS="_" read sample_no illumina_id lane_no read_no etc <<< $fastqc_folder

  # Add data to read counts file
  fastqc_data_file="${fastqc_folder}/fastqc_data.txt"
  reads_count=$(awk 'BEGIN {FS="\t"}; $1=="Total Sequences" {print $2}' "${fastqc_data_file}")
  reads_count="${sample_no}\t${illumina_id}\t${lane_no}\t${read_no}\t${reads_count}"
  echo -e "${reads_count}" >> "${read_counts_file}"
  
  # Add data to summary file
  fastqc_summary_file="${fastqc_folder}/summary.txt"
  fastqc_summary_data=$(awk '{print $1}' "${fastqc_summary_file}")
  fastqc_summary_data=${fastqc_summary_data//$'\n'/'\t'}
  fastqc_summary_data="${sample_no}\t${illumina_id}\t${lane_no}\t${read_no}\t${fastqc_summary_data}"
  echo -e "${fastqc_summary_data}" >> "${summary_file}"

done # Next fast-qc folder

# Completion message
echo "Completed"
date
echo ""

# Check results
echo "Quick checks"
echo ""

wc -l "${read_counts_file}"
head "${read_counts_file}"
echo ""
grep S143 "${read_counts_file}"
echo ""

wc -l "${summary_file}"
head "${summary_file}"
echo ""
grep S143 "${summary_file}"
echo ""
