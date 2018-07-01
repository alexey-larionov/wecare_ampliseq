#!/bin/bash

# s01_alignment.sh
# Started: Alexey Larionov, 29Jun2018
# Last updated: Alexey Larionov, 30Jun2018

# Use:
# sbatch s01_alignment.sh

# This script runs BWA-MEM to align fastq files against b37 genome
# b37 from the GATK bundele is used for comparability with the previous wecare WES analyis
# However, unlike to the previous analysis, I used b37-decoy version of the geneome 
# and I used the latest version of BWA 

# For parallelising I used BWA -t 12 option and split the whole set of fastq files 
# to batches of 3 samples, then I run trimming for each batch in parallel 
# using 32 cores & 192 GB RAM per node (384 GB RAM if himem)

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s01_alignment
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=05:00:00
#SBATCH --output=s01_alignment.log
#SBATCH --exclusive
##SBATCH --qos=INTR
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
echo "Alignment of wecare ampliseq data"
date
echo ""

# Folders
base_folder="/rds/project/erf33/rds-erf33-medgen"
data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"

trimmed_fastq_folder="${data_folder}/d02_trimmed_fastq/fastq"
raw_bam_folder="${data_folder}/d03_raw_bam/bam"

rm -fr "${raw_bam_folder}" # remove bams folder, if existed
mkdir -p "${raw_bam_folder}"

# Tools and resources
tools_folder="${base_folder}/tools"

bwa="${tools_folder}/bwa/bwa-0.7.17/bwa"
bwa_index="${tools_folder}/bwa/bwa-0.7.17/indices/b37_decoy/b37d_bwtsw"

samtools="${tools_folder}/samtools/samtools-1.8/bin/samtools"

# Progress report
echo "trimmed_fastq_folder: ${trimmed_fastq_folder}"
echo "raw_bam_folder: ${raw_bam_folder}"
echo "bwa: ${bwa}"
echo "bwa_index: ${bwa_index}"
echo "samtools: ${samtools}"
echo ""

# Make list of fastq files 
cd "${trimmed_fastq_folder}"
trimmed_fastq_files=$(ls *trim.fastq.gz)

# Make list of samples 
samples=$(sed -e 's/_R._trim.fastq.gz//g' <<< "${trimmed_fastq_files}" | uniq)
echo "Detected $(wc -w <<< ${samples}) PE samples in the fastq folder"

# Make batches of 3 samples each (store temporary files in output folder)
cd "${raw_bam_folder}"
split -l 3 <<< "${samples}"
batches=$(ls)

# Progress report
echo "Made "$(wc -w <<< ${batches})" batches of up to 3 samples each"
echo ""

# Initialise batch counter
batch_no=0

# For each batch
for batch in $batches
do
  
  # Get list of samples in the batch
  samples=$(cat $batch)

  # For each sample in the batch
  for sample in ${samples}
  do  
  
    # Compile file names
    trimmed_fastq_1="${trimmed_fastq_folder}/${sample}_R1_trim.fastq.gz"
    trimmed_fastq_2="${trimmed_fastq_folder}/${sample}_R2_trim.fastq.gz"
    raw_bam="${raw_bam_folder}/${sample}_raw.bam"
    alignment_log="${raw_bam_folder}/${sample}_alignment.log"
    
    # Submit sample for alignment and convert outputted SAM to BAM
    # dont wait for complewtion: & at the end
    # Options:
    # -M  Mark shorter split hits as secondary (for Picard compatibility)
    # -t  Number of threads
    "${bwa}" mem -M -t 12 "${bwa_index}" \
      "${trimmed_fastq_1}" "${trimmed_fastq_2}" 2> "${alignment_log}" | \
      "${samtools}" view -b - > "${raw_bam}" &
      
  done # next sample in the batch
  
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
