#!/bin/bash

# s04_bqsr_plots.sh
# Started: Alexey Larionov, 29Jun2018
# Last updated: Alexey Larionov, 10Jul2018

# Use:
# sbatch s04_bqsr_plots.sh

# This script launches analysis in batches of 25 BAMs per batch.   
# Assuming that gatk will use single thread per analysis and up to 6GB memory per thread, 
# batches of 25 would match the capacity of a single node on cluster (32 cores & 192 GB RAM per node)

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s04_bqsr_plots
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=01:00:00
#SBATCH --output=s04_bqsr_plots.log
#SBATCH --exclusive
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

# Stop at runtime errors
set -e

# Start message
echo "Make BQSR plots (in batches)"
date
echo ""

# Folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"
data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
bqsr_bam_folder="${data_folder}/d05_preprocessed_bam/bqsr_bam"
tables_before_folder="${data_folder}/d05_preprocessed_bam/bqsr_tables_before"
tables_after_folder="${data_folder}/d05_preprocessed_bam/bqsr_tables_after"
plots_folder="${data_folder}/d05_preprocessed_bam/bqsr_plots"

rm -fr "${plots_folder}" # remove tables folder, if existed
mkdir -p "${plots_folder}"

# Tools 
tools_folder="${base_folder}/tools"
r_folder="${tools_folder}/r/R-3.2.0/bin"
gatk="${tools_folder}/gatk/gatk-4.0.5.2/gatk"


# Progress report
echo "--- Folders ---"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo ""
echo "bqsr_bam_folder: ${bqsr_bam_folder}"
echo "tables_before_folder: ${tables_before_folder}"
echo "tables_after_folder: ${tables_after_folder}"
echo "plots_folder: ${plots_folder}"
echo ""
echo "--- Tools ---"
echo ""
echo "gatk: ${gatk}"
echo "r_folder: ${r_folder}"
echo ""
echo "java:"
java -version
echo ""

# Add R version with required libraries to the path
export PATH="${r_folder}":$PATH 

# Batches 

# Make list of source bam files 
cd "${bqsr_bam_folder}"
bqsr_bam_files=$(ls *_fixmate_sort_rg_bqsr.bam)

# Make list of samples 
samples=$(sed -e 's/_fixmate_sort_rg_bqsr.bam//g' <<< "${bqsr_bam_files}")
echo "Detected $(wc -w <<< ${samples}) bqsr bam files"

#samples="103_S147_L007 108_S482_L008"

# Make batches of 25 samples each (store temporary files in tmp folder)
tmp_folder="${data_folder}/d05_preprocessed_bam/tmp"
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
  
    # Compile file names
    bqsr_table_before="${tables_before_folder}/${sample}_before.txt"
    bqsr_table_after="${tables_after_folder}/${sample}_after.txt"
    bqsr_plots="${plots_folder}/${sample}_bqsr_plots.pdf"
    bqr_plots_data="${plots_folder}/${sample}_bqsr_plots.csv"
    bqsr_plots_log="${plots_folder}/${sample}_bqsr_plots.log"
    
    # Make plots
    "${gatk}" AnalyzeCovariates \
      -before "${bqsr_table_before}" \
      -after "${bqsr_table_after}" \
      -plots "${bqsr_plots}" \
      -csv "${bqr_plots_data}" \
      &> "${bqsr_plots_log}" &
      
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
