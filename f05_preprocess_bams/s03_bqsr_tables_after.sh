#!/bin/bash

# s03_bqsr_tables_after.sh
# Started: Alexey Larionov, 29Jun2018
# Last updated: Alexey Larionov, 10Jul2018

# Use:
# sbatch s03_bqsr_tables_after.sh

# This script launches analysis in batches of 25 BAMs per batch.   
# Assuming that gatk will use single thread per analysis and up to 6GB memory per thread, 
# batches of 25 would match the capacity of a single node on cluster (32 cores & 192 GB RAM per node)

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s03_bqsr_tables_after
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=01:00:00
#SBATCH --output=s03_bqsr_tables_after.log
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
echo "Make BQSR tables after recalibration (in batches)"
date
echo ""

# Folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"
data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
bqsr_bam_folder="${data_folder}/d05_preprocessed_bam/bqsr_bam"
tables_folder="${data_folder}/d05_preprocessed_bam/bqsr_tables_after"

rm -fr "${tables_folder}" # remove tables folder, if existed
mkdir -p "${tables_folder}"

# Tools 
tools_folder="${base_folder}/tools"
gatk="${tools_folder}/gatk/gatk-4.0.5.2/gatk"

# Resources 
targets_interval_list="${data_folder}/d00_targets/targets.interval_list"
resources_folder="${base_folder}/resources"
ref_genome="${resources_folder}/gatk_bundle/b37/decompressed/human_g1k_v37_decoy.fasta"
dbsnp="${resources_folder}/gatk_bundle/b37/decompressed/dbsnp_138.b37.vcf"
indels_1k="${resources_folder}/gatk_bundle/b37/decompressed/1000G_phase1.indels.b37.vcf"
indels_mills="${resources_folder}/gatk_bundle/b37/decompressed/Mills_and_1000G_gold_standard.indels.b37.vcf"

# Progress report
echo "--- Folders ---"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo ""
echo "bqsr_bam_folder: ${bqsr_bam_folder}"
echo "tables_folder: ${tables_folder}"
echo ""
echo "--- Tools ---"
echo ""
echo "gatk: ${gatk}"
echo ""
echo "java:"
java -version
echo ""
echo "--- Resources ---"
echo ""
echo "ref_genome: ${ref_genome}"
echo "targets_interval_list: ${targets_interval_list}"
echo "dbsnp: ${dbsnp}"
echo "indels_1k: ${indels_1k}"
echo "indels_mills: ${indels_mills}"
echo ""

# Batches 

# Make list of source bam files 
cd "${bqsr_bam_folder}"
bqsr_bam_files=$(ls *_fixmate_sort_rg_bqsr.bam)

# Make list of samples 
samples=$(sed -e 's/_fixmate_sort_rg_bqsr.bam//g' <<< "${bqsr_bam_files}")
echo "Detected $(wc -w <<< ${samples}) bam files in the source folder"

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
    bqsr_bam="${bqsr_bam_folder}/${sample}_fixmate_sort_rg_bqsr.bam"
    bqsr_table="${tables_folder}/${sample}_after.txt"
    bqsr_table_log="${tables_folder}/${sample}_after.log"
    
    # Prepere BQSR table
    "${gatk}" BaseRecalibrator \
      -I "${bqsr_bam}" \
      -O "${bqsr_table}" \
      -R "${ref_genome}" \
      -L "${targets_interval_list}" \
      --known-sites "${dbsnp}" \
      --known-sites "${indels_1k}" \
      --known-sites "${indels_mills}" \
      &> "${bqsr_table_log}" &
      
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
