#!/bin/bash

# s02_merge_gvcfs.sh
# Started: Alexey Larionov, 27Jul2018
# Last updated: Alexey Larionov, 27Jul2018

# Use:
# sbatch s02_merge_gvcfs.sh

# This script merges up to 100 gvcf files per merged file.   

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s02_merge_gvcfs
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=01:00:00
#SBATCH --output=s02_merge_gvcfs.log
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
echo "Make merged gVCF files (in batches)"
date
echo ""

# Folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"
data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
gvcf_folder="${data_folder}/d06_gvcf/gvcf"
merged_gvcf_folder="${data_folder}/d06_gvcf/merged_gvcf"

rm -fr "${merged_gvcf_folder}" # remove tables folder, if existed
mkdir -p "${merged_gvcf_folder}"

# Tools 
tools_folder="${base_folder}/tools"
gatk="${tools_folder}/gatk/gatk-4.0.5.2/gatk"

# Resources 
targets_interval_list="${data_folder}/d00_targets/targets.interval_list"
resources_folder="${base_folder}/resources"
ref_genome="${resources_folder}/gatk_bundle/b37/decompressed/human_g1k_v37_decoy.fasta"

# Progress report
echo "--- Folders ---"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo ""
echo "gvcf_folder: ${gvcf_folder}"
echo "merged_gvcf_folder: ${merged_gvcf_folder}"
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
echo ""

# Batches 

# Make list of source bam files 
cd "${gvcf_folder}"
gvcf_files=$(ls *.g.vcf.gz)

# Make list of samples 
samples=$(sed -e 's/.g.vcf.gz//g' <<< "${gvcf_files}")
echo "Detected $(wc -w <<< ${samples}) gvcf files in the source folder"

# Make batches of 100 samples each (store batch files in tmp folder)
tmp_folder="${merged_gvcf_folder}/tmp"
rm -fr "${tmp_folder}" # remove temporary folder, if existed
mkdir -p "${tmp_folder}"
cd "${tmp_folder}"
split -l 100 <<< "${samples}"
batches=$(ls)

# Progress report
echo "Made "$(wc -w <<< $batches)" batches of up to 100 samples each"
echo ""

# Initialise batch counter
batch_no=0

# For each batch
for batch in ${batches}
do
  
  # Increment batch number
  batch_no=$(( $batch_no + 1 ))
  
  # Compile batch output file names
  merged_gvcf="${merged_gvcf_folder}/batch_${batch_no}.g.vcf.gz"
  merging_log="${merged_gvcf_folder}/batch_${batch_no}.log"
  
  # Get list of samples in the batch
  samples=$(cat $batch)
  
  # Compile input list for CombineGVCFs
  samples_list=""
  for sample in ${samples}
  do  
  
    # Compile gvcf file name
    gvcf="${gvcf_folder}/${sample}.g.vcf.gz"
    
    # Add file name to the input list
    samples_list="${samples_list} --variant ${gvcf}"
    
  done # next sample
  
  # Combine gvcfs in the batch
  "${gatk}" --java-options "-Xmx30g" CombineGVCFs  \
    ${samples_list} \
    -O "${merged_gvcf}" \
    -R "${ref_genome}" \
    -L "${targets_interval_list}" \
    &> "${merging_log}" &  
  # Dont wait until the batch completed - do all 6 batches in parallel
  
  # Progress report
  echo "Started batch ${batch_no}"
  
done # next batch

# Wait until all batches (background tasks) complete
wait 

# Remove temporary files
cd "${scripts_folder}"
rm -fr "${tmp_folder}"

# Completion message
echo ""
echo "Done all tasks"
date
echo ""
