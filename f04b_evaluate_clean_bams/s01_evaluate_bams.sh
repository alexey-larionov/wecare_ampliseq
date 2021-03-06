#!/bin/bash

# s01_evaluate_bams.sh
# Started: Alexey Larionov, 29Jun2018
# Last updated: Alexey Larionov, 03Jul2018

# Use:
# sbatch s01_evaluate_bams.sh

# This script launches BAM's evaluation in batches of 25 BAMs per batch.   
# Assuming that picard/other tools will use single thread per analysis and 
# up to 6GB memory per thread for processing each batch, 
# batches of 25 would match the capacity of a single 
# node on cluster (32 cores & 192 GB RAM per node)

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s01_evaluate_bams
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=03:00:00
#SBATCH --output=s01_evaluate_bams.log
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
echo "Launch evaluating BAMs in batches"
date
echo ""

# --- Folders --- #

scripts_folder="$( pwd -P )"

base_folder="/rds/project/erf33/rds-erf33-medgen"

data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"

clean_bam_folder="${data_folder}/d04_clean_bam/bam"

samtools_metrics_folder="${data_folder}/d04_clean_bam/samtools"
gatk_metrics_folder="${data_folder}/d04_clean_bam/gatk"
picard_metrics_folder="${data_folder}/d04_clean_bam/picard"
qualimap_folder="${data_folder}/d04_clean_bam/qualimap_on_targets"

mkdir -p "${samtools_metrics_folder}/flagstats"
mkdir -p "${gatk_metrics_folder}/flagstats"
mkdir -p "${picard_metrics_folder}/insert_sizes"
mkdir -p "${picard_metrics_folder}/alignment_metrics"
mkdir -p "${picard_metrics_folder}/pcr_metrics"
mkdir -p "${qualimap_folder}"

# --- Tools --- #

tools_folder="${base_folder}/tools"
samtools="${tools_folder}/samtools/samtools-1.8/bin/samtools"
gatk="${tools_folder}/gatk/gatk-4.0.5.2/gatk"
picard="${tools_folder}/picard/picard-2.18.7/picard.jar"
qualimap="${tools_folder}/qualimap/qualimap_v2.2.1/qualimap"
r_folder="${tools_folder}/r/R-3.2.0/bin" 

# --- Resources --- #

resources_folder="${base_folder}/resources"
ref_genome="${resources_folder}/gatk_bundle/b37/decompressed/human_g1k_v37_decoy.fasta"
amplicons_interval_list="${data_folder}/d00_targets/amplicons.interval_list"
targets_interval_list="${data_folder}/d00_targets/targets.interval_list"
targets_bed="${data_folder}/d00_targets/targets_6.bed"

# Progress report
echo "--- Folders ---"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo ""
echo "clean_bam_folder: ${clean_bam_folder}"
echo ""
echo "samtools_metrics_folder: ${samtools_metrics_folder}"
echo "gatk_metrics_folder: ${gatk_metrics_folder}"
echo "picard_metrics_folder: ${picard_metrics_folder}"
echo "qualimap_folder: ${qualimap_folder}"
echo ""
echo "--- Tools ---"
echo ""
echo "samtools: ${samtools}"
echo "gatk: ${gatk}"
echo "picard: ${picard}"
echo "qualimap: ${qualimap}"
echo "r_folder: ${r_folder}"
echo ""
echo "java:"
java -version
echo ""
echo "--- Resources ---"
echo ""
echo "ref_genome: ${ref_genome}"
echo "amplicons_interval_list: ${amplicons_interval_list}"
echo "targets_interval_list: ${targets_interval_list}"
echo "targets_bed: ${targets_bed}"
echo ""

# --- Environment --- #

# Add R version with required libraries to the path 
# (for picard insert metrics plots and for qualimap)
export PATH="{r_folder}":$PATH 

# Variable to reset default memory settings for qualimap
export JAVA_OPTS="-Xms1G -Xmx6G"

# --- Batches --- #

# Make list of source bam files 
cd "${clean_bam_folder}"
clean_bam_files=$(ls *_fixmate_sort_rg.bam)

# Make list of samples 
samples=$(sed -e 's/_fixmate_sort_rg.bam//g' <<< "${clean_bam_files}")
echo "Detected $(wc -w <<< ${samples}) bam files in the source folder"

# Make batches of 25 samples each (store temporary files in tmp folder)
tmp_folder="${data_folder}/d04_clean_bam/tmp"
rm -fr "${tmp_folder}" # remove temporary folder, if existed
mkdir -p "${tmp_folder}"
cd "${tmp_folder}"
split -l 25 <<< "${samples}"
batches=$(ls)

# Progress report
echo "Made "$(wc -w <<< $batches)" batches of up to 25 samples each"
echo ""

# --- Analysis --- #

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
    assessment_log="${clean_bam_folder}/${sample}_assessment.log"
    
    # Launch the clean-up (dond wait for completion)
    "${scripts_folder}/s02_evaluate_bam.sh" \
      "${sample}" \
      "${clean_bam_folder}" \
      "${samtools}" \
      "${gatk}" \
      "${picard}" \
      "${qualimap}" \
      "${r_folder}" \
      "${ref_genome}" \
      "${amplicons_interval_list}" \
      "${targets_interval_list}" \
      "${targets_bed}" \
      "${samtools_metrics_folder}" \
      "${gatk_metrics_folder}" \
      "${picard_metrics_folder}" \
      "${qualimap_folder}" \
      &> "${assessment_log}" &
      
  done # next sample in the batch
  
  # Whait until the batch (all background processes) completed
  wait
  
  # Progress report
  batch_no=$(( $batch_no + 1 ))
  echo "$(date +%H:%M:%S) Done batch ${batch_no}"
  
done # next batch

# Remove temporary files
cd "${scripts_folder}"
rm -fr "${tmp_folder}"

# Completion message
echo ""
echo "Done all tasks"
date
echo ""
