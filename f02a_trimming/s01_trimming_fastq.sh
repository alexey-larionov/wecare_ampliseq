#!/bin/bash

# s01_trimming_fastq.sh
# Started: Alexey Larionov, 27Jun2018
# Last updated: Alexey Larionov, 27Jun2018

# Use:
# sbatch s01_trimming_fastq.sh

# Adapters had been previously trimmed by EZ
# during the fastq demultiplexing.  

# These were not the standard Illumina adapters, but 
# something from NEXTflex barcodes from Bioo Scientific 
# The adaptors sequences were not immediately available; 
# However, GC provided some info that coud be digged further

# This script uses Cutadapt to 
# - trim poor quality bases from the ends of the reads 
# - remove reads shorter than 50 bases after triming
# This also should remove Nx35 reads, which unexpectedly constituted
# ~7.6% of all te reeds (up to 70% in several worst samples)

# For parallelising I split the whole set of fastq files 
# to batches of <30 files, then I run trimming for each batch in parallel 
# using 32 cores & 192 GB RAM per node (384 GB RAM if himem)

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s01_trimming_fastq
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=01:00:00
#SBATCH --output=s01_trimming_fastq.log
#SBATCH --qos=INTR
#SBATCH --exclusive
##SBATCH --ntasks=30

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
echo "Trimming of fastq files"
date
echo ""

# Add path to our python and cutadapt v1.16 to PATH
export PATH=/rds/project/erf33/rds-erf33-medgen/tools/python/python_2.7.10/bin:$PATH
python --version
echo "cutadapt version"
cutadapt --version
echo ""

# Cutadapt settings
cutadapt_trim_qual=20
cutadapt_min_len=50
max_n_fraction=0.5

# Files and folders
base_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq"
source_fastq_folder="${base_folder}/data_and_results/d01_source_data/180522_K00178_0090_BHVMMTBBXX_alarionov"
trimmed_fastq_folder="${base_folder}/data_and_results/d02_trimmed_fastq/fastq"
rm -fr "${trimmed_fastq_folder}" # remove folder if existed
mkdir -p "${trimmed_fastq_folder}"

# Progress report
echo "base_folder: ${base_folder}"
echo "source_fastq_folder: ${source_fastq_folder}"
echo "trimmed_fastq_folder: ${trimmed_fastq_folder}"
echo ""
echo "cutadapt_trim_qual: ${cutadapt_trim_qual}"
echo "cutadapt_min_len: ${cutadapt_min_len}"
echo "max_n_fraction: ${max_n_fraction}"
echo ""

# Make list of fastq files 
cd "${source_fastq_folder}"
source_fastq_files=$(ls)

# Make list of samples 
samples=$(sed -e 's/_R._001.fastq.gz//g' <<< "${source_fastq_files}" | uniq)

# Make batches of 15 samples each (store temporary files in output folder)
cd "${trimmed_fastq_folder}"
split -l 15 <<< "${samples}"
batches=$(ls)

# Progress report
echo "Made "$(wc -w <<< $batches)" batches of up to 15 samples each"
echo ""

# Initialise batch counter
batch_no=0

# For each batch
for batch in $batches
do
  
  # Get list of fastq files in batch
  samples=$(cat $batch)

  # For each fastq file in batch
  for sample in ${samples}
  do  
    
    # Compile file names
    raw_fastq_1="${source_fastq_folder}/${sample}_R1_001.fastq.gz"
    raw_fastq_2="${source_fastq_folder}/${sample}_R2_001.fastq.gz"
    trimmed_fastq_1="${trimmed_fastq_folder}/${sample}_R1_trim.fastq.gz"
    trimmed_fastq_2="${trimmed_fastq_folder}/${sample}_R2_trim.fastq.gz"
    trimming_log="${trimmed_fastq_folder}/${sample}_trim.log"
    
    # Do trimming in the background (not wait for completion)
    # Trim low-quality bases on both ends, then discard reads, 
    # which are becoming too short after triming; 
    # keep both fastq files cyncronised
    cutadapt \
      -q "${cutadapt_trim_qual}","${cutadapt_trim_qual}" \
      --max-n "${max_n_fraction}" \
      --trim-n \
      -m "${cutadapt_min_len}" \
      --pair-filter=any \
      -o "${trimmed_fastq_1}" \
      -p "${trimmed_fastq_2}" \
      "${raw_fastq_1}" \
      "${raw_fastq_2}" > "${trimming_log}" &
    
  done # next fastq in the batch
  
  # Whait until the batch (all background processes) completed
  wait
  
  # Progress report
  batch_no=$(( $batch_no + 1 ))
  echo "$(date +%H:%M:%S) Done batch ${batch_no}"
  
done # next batch

# Remove temporary files from output folder
rm ${batches}

# Completion message
echo ""
echo "Done all tasks"
date
echo ""
