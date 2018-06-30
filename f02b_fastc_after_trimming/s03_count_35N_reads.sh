#!/bin/bash

# s03_count_35N_reads.sh
# Started: Alexey Larionov, 26Jun2018
# Last updated: Alexey Larionov, 28Jun2018

# Use:
# sbatch s03_count_35N_reads.sh

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s03_count_35N_reads
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=03:00:00
#SBATCH --output=s03_count_35N_reads.log
#SBATCH --ntasks=2
##SBATCH --exclusive
##SBATCH --qos=INTR

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

# Stop at runtime errors
set -e

# Start message
echo "Conunt Nx35 reads after trimming"
date
echo ""

# Files and folders
base_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq"
fastq_folder="${base_folder}/data_and_results/d02_trimmed_fastq/fastq"
output_folder="${base_folder}/data_and_results/d02_trimmed_fastq/count_35N_reads"
counts_file="${output_folder}/count_35N_reads.txt"
rm -fr "${output_folder}" # remove folder if existed
mkdir -p "${output_folder}"

# Progress report
echo "base_folder: ${base_folder}"
echo "fastq_folder: ${fastq_folder}"
echo "counts_file: ${counts_file}"
echo ""

# Make list of fastq files 
cd "${fastq_folder}"
fastq_files=$( ls *trim.fastq.gz )
echo "Found $(wc -w <<< ${fastq_files}) fastq files"

# Initialise output file
echo -e "Sample\tIllumina_id\tRead\tLane\tTotal_reads\tN35_reads" > "${counts_file}"

# For each fastq file in batch
for fastq in ${fastq_files}
do
  
  # Parce the file name 
  IFS="_" read sample_no illumina_id lane_no read_no etc <<< ${fastq}
  
  # Total count of reads
  total_reads=$(( $(zcat "${fastq}" | wc -l) / 4 ))
  
  # N35 reads (note that grep -c does NOT generate 0 if it finds nothing ...)
  n35_reads=$( zgrep NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN "${fastq}" | wc -l )
  
  # Write result to output file
  echo -e "${sample_no}\t${illumina_id}\t${read_no}\t${lane_no}\t${total_reads}\t${n35_reads}" >> "${counts_file}"
  
done # next fastq in the batch

# Completion message
echo "Done all fastq files"
date
echo ""
