#!/bin/bash

# s03_filter_vcf.sh
# Started: Alexey Larionov, 08Aug2018
# Last updated: Alexey Larionov, 09Aug2018

# Use:
# sbatch s03_filter_vcf.sh

# Filter VCF

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s03_filter_vcf
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=00:10:00
#SBATCH --output=s03_filter_vcf.log
#SBATCH --ntasks=1
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
echo "Filter VCF using pre-selected 5,830 target variants"
date
echo ""

# Folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"
data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
input_folder="${data_folder}/d07_filtered_vcf_v03/vqsr"
output_folder="${data_folder}/d07_filtered_vcf_v03"
# output_folder contains targets.txt file with pre-selected 5,830 variants

# Files
source_vcf="${input_folder}/wecare_ampliseq_vqsr.vcf"
filtered_vcf="${output_folder}/wecare_ampliseq_filt_5830.vcf"
targets_file="${scripts_folder}/targets.txt"

# Tools 
tools_folder="${base_folder}/tools"
bcftools="${tools_folder}/bcftools/bcftools-1.8/bin/bcftools"

# Progress report
echo "--- Files and folders ---"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo "input_folder: ${input_folder}"
echo "output_folder: ${output_folder}"
echo ""
echo "source_vcf: ${source_vcf}"
echo "filtered_vcf: ${filtered_vcf}"
echo "targets_file: ${targets_file}"
echo ""
echo "--- Tools ---"
echo ""
echo "bcftools: ${bcftools}"
echo ""

# Check number of targets
echo "Num of targets:"
printf "%'d\n" $(cat "${targets_file}" | wc -l)
echo ""

# Check number of input variants
echo "Num of variants in source vcf:"
printf "%'d\n" $(grep -vc "^#" "${source_vcf}")
echo ""

# Filter VCF
echo "Filtering VCF..."
echo ""
"${bcftools}" view -O v -T "${targets_file}" "${source_vcf}" > "${filtered_vcf}"
# -O v : output to uncompressed VCF

# Check number of output variants
echo "Num of variants in filtered vcf:"
printf "%'d\n" $(grep -vc "^#" "${filtered_vcf}")
echo ""

# Progress report
echo "Done all tasks"
date
echo ""
