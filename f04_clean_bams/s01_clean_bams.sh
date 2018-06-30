#!/bin/bash

# s01_clean_bams.sh
# Started: Alexey Larionov, 29Jun2018
# Last updated: Alexey Larionov, 30Jun2018

# Use:
# sbatch s01_clean_bams.sh

# This script launches cleaning of BAMs in batches of 30 BAMs per batch.   
# Assuming that picard will use single thread per analysis and 
# up to 6GB memory per thread for processing each batch, 
# 30 batches at once would match well the capacity of a single 
# node on cluster (32 cores & 192 GB RAM per node)

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s01_clean_bams
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=03:00:00
#SBATCH --output=s01_clean_bams.log
#SBATCH --exclusive
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
echo "Launch cleaning of BAMs in batches"
date
echo ""

# Folders
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"

data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
raw_bam_folder="${data_folder}/d03_raw_bams"
clean_bam_folder="${data_folder}/d04_clean_bams"

rm -fr "${clean_bam_folder}" # remove clean bams folder, if existed
mkdir -p "${clean_bam_folder}"

# Tools and resources
tools_folder="${base_folder}/tools"
picard="${tools_folder}/picard/picard-2.18.7/picard.jar"

# Data for read group info
library="wecare_ampliseq_01"
platform="illumina"
flowcell="HVMMTBBXX" # K00178:90:HVMMTBBXX - from fastq file headers

# Progress report
echo "scripts_folder: ${scripts_folder}"
echo "raw_bam_folder: ${raw_bam_folder}"
echo "clean_bam_folder: ${clean_bam_folder}"
echo ""
echo "Java:"
java -version
echo ""
echo "picard: ${picard}"
echo ""
echo "library: ${library}"
echo "platform: ${platform}"
echo "flowcell: ${flowcell}"
echo ""

# Make list of source bam files 
cd "${raw_bam_folder}"
source_bam_files=$(ls *_raw.bam)

# Make list of samples 
samples=$(sed -e 's/_raw.bam//g' <<< "${source_bam_files}")
echo "Detected $(wc -w <<< ${samples}) bam files in the source folder"

# Make batches of 30 samples each (store temporary files in output folder)
cd "${clean_bam_folder}"
split -l 30 <<< "${samples}"
batches=$(ls)

# Progress report
echo "Made "$(wc -w <<< $batches)" batches of up to 30 samples each"
echo ""

# Initialise batch counter
batch_no=0

# For each batch
for batch in ${batches}
do
  
  # Get list of samples in the batch
  samples=$(cat $batch)

  # For each sample in the batch
  for sample in ${samples}
  do  
  
    # Make log file name
    cleanup_log="${clean_bam_folder}/${sample}_cleanup.log"
    
    # Launch the clean-up (dond wait for completion)
    "${scripts_folder}/s02_clean_bam.sh" \
      "${sample}" \
      "${raw_bam_folder}" \
      "${clean_bam_folder}" \
      "${picard}" \
      "${library}" \
      "${platform}" \
      "${flowcell}" \
      &> "${cleanup_log}" &
      
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
