#!/bin/bash

# s02_preprocess_raw_vcf.sh
# Started: Alexey Larionov, 06Aug2018
# Last updated: Alexey Larionov, 06Aug2018

# Use:
# sbatch s02_preprocess_raw_vcf.sh

# Preproces raw VCF:
# Count variants
# Trim 
# Add location ID to INFO field
# Add multiallelic flag tpo INFO field

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s02_preprocess_raw_vcf
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=01:00:00
#SBATCH --output=s02_preprocess_raw_vcf.log
#SBATCH --ntasks=2
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
echo "Preprocess VCF"
date
echo ""

# Folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"

data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
raw_vcf_folder="${data_folder}/d06_raw_vcf/raw_vcf"
pre_processed_vcf_folder="${data_folder}/d06_raw_vcf/preprocessed_vcf"

rm -fr "${pre_processed_vcf_folder}" # remove results folder, if existed
mkdir -p "${pre_processed_vcf_folder}"

# Files
raw_vcf="${raw_vcf_folder}/wecare_ampliseq_raw.vcf.gz"
pre_processed_vcf="${pre_processed_vcf_folder}/wecare_ampliseq_pre_proc.vcf.gz"

# Tools 
#tools_folder="${base_folder}/tools"
# gatk=
#bcftools="${tools_folder}/bcftools/bcftools-1.8/bin/bcftools"
#plot_vcfstats="${tools_folder}/bcftools/bcftools-1.8/bin/plot-vcfstats"

# Resources 
#targets_interval_list="${data_folder}/d00_targets/targets.interval_list"
#resources_folder="${base_folder}/resources"
#ref_genome="${resources_folder}/gatk_bundle/b37/decompressed/human_g1k_v37_decoy.fasta"

# Progress report
echo "--- Files and folders ---"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo ""
echo "raw_vcf: ${raw_vcf}"
echo "pre_processed_vcf: ${pre_processed_vcf}"
echo ""
#echo "--- Tools ---"
#echo ""
#echo "bcftools: ${bcftools}"
#echo "plot_vcfstats: ${plot_vcfstats}"
#echo ""
#echo "--- Resources ---"
#echo ""
#echo "ref_genome: ${ref_genome}"
#echo "targets_interval_list: ${targets_interval_list}"
#echo ""

#######################################################

echo "Num of variants in raw vcf:"
printf "%'d\n" $(zgrep -v "^#" "${raw_vcf}" | wc -l)

exit

# --- Trim the variants --- #
# Removes variants and alleles that have not been detected in any genotype

# Progress report
echo "Started trimming variants"

# File names
trim_vcf="${tmp_folder}/${dataset}_trim.vcf"
trim_log="${logs_folder}/${dataset}_trim.log"

"${java}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${raw_vcf}" \
  -o "${trim_vcf}" \
  --excludeNonVariants \
  --removeUnusedAlternates \
  -nt 14 &>  "${trim_log}"

# Note: 
# This trimming may not be necessary for most analyses. 
# For instance, it looked excessive in wecare analysis
# because it does not change the num of variants: 
echo "Num of variants before trimming: $(grep -v "^#" "${raw_vcf}" | wc -l)"
echo "Num of variants after trimming: $(grep -v "^#" "${trim_vcf}" | wc -l)"

# Progress report
echo "Completed trimming variants: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add locations IDs to INFO field --- #
# To simplyfy tracing variants locations at later steps

# Progress report
echo "Started adding locations IDs to INFO field"

# File name
trim_lid_vcf="${tmp_folder}/${dataset}_trim_lid.vcf"

# Compile names for temporary files
lid_tmp1=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_lid_tmp1".XXXXXX)
lid_tmp2=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_lid_tmp2".XXXXXX)
lid_tmp3=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_lid_tmp3".XXXXXX)
lid_tmp4=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_lid_tmp4".XXXXXX)

# Prepare data witout header
grep -v "^#" "${trim_vcf}" > "${lid_tmp1}"
awk '{printf("LocID=Loc%09d\t%s\n", NR, $0)}' "${lid_tmp1}" > "${lid_tmp2}"
awk 'BEGIN {OFS="\t"} ; { $9 = $9";"$1 ; print}' "${lid_tmp2}" > "${lid_tmp3}"
cut -f2- "${lid_tmp3}" > "${lid_tmp4}"

# Prepare header
grep "^##" "${trim_vcf}" > "${trim_lid_vcf}"
echo '##INFO=<ID=LocID,Number=1,Type=String,Description="Location ID">' >> "${trim_lid_vcf}"
grep "^#CHROM" "${trim_vcf}" >> "${trim_lid_vcf}"

# Append data to header in the output file
cat "${lid_tmp4}" >> "${trim_lid_vcf}"

# Progress report
echo "Completed adding locations IDs to INFO field: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Make mask for multiallelic variants --- #

# Progress report
echo "Started making mask for multiallelic variants"

# File names
trim_lid_ma_mask_vcf="${tmp_folder}/${dataset}_trim_lid_ma_mask.vcf"
trim_lid_ma_mask_log="${logs_folder}/${dataset}_trim_lid_ma_mask.log"

# Make mask
"${java}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${trim_lid_vcf}" \
  -o "${trim_lid_ma_mask_vcf}" \
  -restrictAllelesTo MULTIALLELIC \
  -nt 14 &>  "${trim_lid_ma_mask_log}"

# Progress report
echo "Completed making mask: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add flag for multiallelic variants --- #

# Progress report
echo "Started adding flag for multiallelic variants"

# File names
trim_lid_ma_vcf="${tmp_folder}/${dataset}_trim_lid_ma.vcf"
trim_lid_ma_log="${logs_folder}/${dataset}_trim_lid_ma.log"

# Add flag
"${java}" -Xmx60g -jar "${gatk}" \
  -T VariantAnnotator \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${trim_lid_vcf}" \
  -comp:MultiAllelic "${trim_lid_ma_mask_vcf}" \
  -o "${trim_lid_ma_vcf}" \
  -nt 14 &>  "${trim_lid_ma_log}"

# Progress report
echo "Completed adding flag for multiallelic variants: $(date +%d%b%Y_%H:%M:%S)"
echo ""


########################################################



# Completion message
echo "Done all tasks"
date
echo ""
