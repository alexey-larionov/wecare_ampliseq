#!/bin/bash

# s03_genotype_gvcfs.sh
# Started: Alexey Larionov, 27Jul2018
# Last updated: Alexey Larionov, 06Aug2018

# Use:
# sbatch s03_genotype_gvcfs.sh

# This script calls genotypes from the merged gvcf files.   

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s03_genotype_gvcfs
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=07:00:00
#SBATCH --output=s03_genotype_gvcfs.log
#SBATCH --ntasks=6
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
echo "Genotype merged gVCF files"
date
echo ""

# Folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"
data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
merged_gvcf_folder="${data_folder}/d06_raw_vcf/merged_gvcf"
raw_vcf_folder="${data_folder}/d06_raw_vcf/raw_vcf"

rm -fr "${raw_vcf_folder}" # remove results folder, if existed
mkdir -p "${raw_vcf_folder}"

# Input file
merged_gvcf="${merged_gvcf_folder}/merged.g.vcf.gz"

# Output files
raw_vcf="${raw_vcf_folder}/wecare_ampliseq_raw.vcf.gz"
genotyping_log="${raw_vcf_folder}/wecare_ampliseq_raw_vcf.log"

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
echo "merged_gvcf: ${merged_gvcf}"
echo "raw_vcf: ${raw_vcf}"
echo "genotyping_log: ${genotyping_log}"
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
echo "Started genotyping ..."

# Genotype gvcfs
"${gatk}" --java-options "-Xmx30g" GenotypeGVCFs \
  -V "${merged_gvcf}" \
  -O "${raw_vcf}" \
  -R "${ref_genome}" \
  -L "${targets_interval_list}" \
  &> "${genotyping_log}" 

# Completion message
echo "Completed genotyping"
date
echo ""
