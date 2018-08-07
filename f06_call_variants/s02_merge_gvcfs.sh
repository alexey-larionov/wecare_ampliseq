#!/bin/bash

# s02_merge_gvcfs.sh
# Started: Alexey Larionov, 27Jul2018
# Last updated: Alexey Larionov, 06Aug2018

# Use:
# sbatch s02_merge_gvcfs.sh

# This script merges individual gvcf files to a single merged gvcf file  

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
#SBATCH --ntasks=6
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
echo "Make merged gVCF file"
date
echo ""

# Folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"
data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
gvcf_folder="${data_folder}/d06_raw_vcf/gvcf"
merged_gvcf_folder="${data_folder}/d06_raw_vcf/merged_gvcf"

merged_gvcf="${merged_gvcf_folder}/merged.g.vcf.gz"
merging_log="${merged_gvcf_folder}/merging_gvcfs.log"

rm -fr "${merged_gvcf_folder}" # remove output folder, if existed
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
echo "merged_gvcf: ${merged_gvcf}"
echo "merging_log: ${merging_log}"
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

# Get list of source gvcf files 
cd "${gvcf_folder}"
gvcf_files=$(ls *.g.vcf.gz)
echo "Detected $(wc -w <<< ${gvcf_files}) gvcf files in the source folder"

# Initialise input list for CombineGVCFs
files_list=""

# Compile the list of files to merge for CombineGVCFs
for gvcf_file in ${gvcf_files}
do
    
  # Compile gvcf file name
  gvcf="${gvcf_folder}/${gvcf_file}"
  
  # Add file name to the input list
  files_list="${files_list} --variant ${gvcf_file}"
  
done # next file

# Progress report
echo "Started merging gvcf files ..."

# Combine gvcfs
"${gatk}" --java-options "-Xmx30g" CombineGVCFs  \
  ${files_list} \
  -O "${merged_gvcf}" \
  -R "${ref_genome}" \
  -L "${targets_interval_list}" \
  &> "${merging_log}"
  
# Completion message
echo "Completed merging gvcf files"
date
echo ""
