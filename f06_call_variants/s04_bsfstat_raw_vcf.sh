#!/bin/bash

# s01_bsfstat_raw_vcf.sh
# Started: Alexey Larionov, 06Aug2018
# Last updated: Alexey Larionov, 06Aug2018

# Use:
# sbatch s01_bsfstat_raw_vcf.sh

# Calculate and plot bcf-stats for raw VCF

# Note loading of texlive module!

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s01_bsfstat_raw_vcf
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=01:00:00
#SBATCH --output=s01_bsfstat_raw_vcf.log
#SBATCH --ntasks=2
#SBATCH --qos=INTR

## Modules section (required, do not remove)
. /etc/profile.d/modules.sh
module purge
module load rhel7/default-peta4 
module load texlive # required to make summary pdf

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
echo "Calculate and plot bcf-stats for raw VCF"
date
echo ""

# Folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"

data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
vcf_folder="${data_folder}/d06_raw_vcf/raw_vcf"
stats_folder="${data_folder}/d06_raw_vcf/bcf_stats"

rm -fr "${stats_folder}" # remove results folder, if existed
mkdir -p "${stats_folder}"

# Files
vcf="${vcf_folder}/wecare_ampliseq_raw.vcf.gz"
stats="${stats_folder}/wecare_ampliseq.vchk"

# Tools 
tools_folder="${base_folder}/tools"
bcftools="${tools_folder}/bcftools/bcftools-1.8/bin/bcftools"
plot_vcfstats="${tools_folder}/bcftools/bcftools-1.8/bin/plot-vcfstats"

# Resources 
#targets_interval_list="${data_folder}/d00_targets/targets.interval_list"
#resources_folder="${base_folder}/resources"
#ref_genome="${resources_folder}/gatk_bundle/b37/decompressed/human_g1k_v37_decoy.fasta"

# Progress report
echo "--- Files and folders ---"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo ""
echo "vcf: ${vcf}"
echo "stats_folder: ${stats_folder}"
echo "stats: ${stats}"
echo ""
echo "--- Tools ---"
echo ""
echo "bcftools: ${bcftools}"
echo "plot_vcfstats: ${plot_vcfstats}"
echo ""
#echo "--- Resources ---"
#echo ""
#echo "ref_genome: ${ref_genome}"
#echo "targets_interval_list: ${targets_interval_list}"
echo ""

# Calculate vcf stats
echo "Calculating stats..."
"${bcftools}" stats "${vcf}" > "${stats}" 

#To explore:
# -R "${targets_bed}" -R or -T options to focus stats on targets ?? 
# -F "${ref_genome}" does not like FAI ...
# -d 0,1000,100 does not change much ...

# Plot the stats (plotting not ran for now, can run script manually and it works!)
echo "Making plots..."
"${plot_vcfstats}" "${stats}" -p "${stats_folder}"
echo ""

# Completion message
echo "Done"
date
echo ""
