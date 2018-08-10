#!/bin/bash

# s01_update_vcf.sh
# Started: Alexey Larionov, 10Aug2018
# Last updated: Alexey Larionov, 10Aug2018

# Use:
# sbatch s01_update_vcf.sh

# Trim and add some technical annotations to variants
# - Remove variants and alleles that have not been detected in any sample
# - Add VariantType and some genotypes quality summaries to INFO
# - Add INFO annotations that flag multiallelics and count alt alleles number
# - Add location IDs to INFO

# VariantAnnotator is yet in beta-version in gatk-4.0.2.1.
# It does not have proper help and documentation on the web site.
# So, GATK3 is used here (note different syntax in GATK3 and GATK4)

# Surprisingly, there was no pre-designed annotations in GATK to flag  
# multiallelic variants and show the number of Alt alleles - so it is 
# done using slightly awkard semi-manual work-arounds

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s01_update_vcf
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=00:10:00
#SBATCH --output=s01_update_vcf.log
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
echo "Update filtered VCF:"
echo " - Remove variants and alleles that have not been detected in any sample"
echo " - Add VariantType and some genotypes quality summaries to INFO"
echo " - Add INFO annotations that flag multiallelics and count alt alleles number"
echo " - Add location IDs to INFO"
echo ""
date
echo ""

# Folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"

data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"

source_folder="${data_folder}/d07_filtered_vcf_v03"
output_folder="${data_folder}/d08_processed_vcf"

rm -fr "${output_folder}" # remove results folder, if existed
mkdir -p "${output_folder}"

# Source vcf file
source_vcf="${source_folder}/wecare_ampliseq_filt_5830.vcf"

# Tools USE GATK3!
tools_folder="${base_folder}/tools"
gatk="${tools_folder}/gatk/gatk-3.8-0/GenomeAnalysisTK-3.8-0/GenomeAnalysisTK.jar"

# Resources 
targets_interval_list="${data_folder}/d00_targets/targets.interval_list"

resources_folder="${base_folder}/resources"
ref_genome="${resources_folder}/gatk_bundle/b37/decompressed/human_g1k_v37_decoy.fasta"

# Progress report
echo "--- Files and folders ---"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo ""
echo "source_vcf: ${source_vcf}"
echo "output_folder: ${output_folder}"
echo ""
echo "--- Tools ---"
echo ""
echo "gatk: ${gatk}"
echo ""
java -version
echo ""
echo "--- Resourses ---"
echo ""
echo "targets_interval_list: ${targets_interval_list}"
echo "ref_genome: ${ref_genome}"
echo ""

# --- Check number of input variants --- #

echo "Num of variants in source vcf:"
printf "%'d\n" $(grep -vc "^#" "${source_vcf}")
echo ""

# --- Trim the variants --- #
# Removes variants and alleles that have not been detected in any genotype

# Progress report
echo "Trimming variants ..."
echo ""

# File names
trim_vcf="${output_folder}/wecare_ampliseq_trim.vcf"
trim_log="${output_folder}/wecare_ampliseq_trim.log"

java -Xmx6g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${targets_interval_list}" \
  -V "${source_vcf}" \
  -o "${trim_vcf}" \
  --excludeNonVariants \
  --removeUnusedAlternates \
  &>  "${trim_log}"

# --- Check number of trimmed variants --- #
echo "Num of variants in trimmed vcf:"
printf "%'d\n" $(grep -vc "^#" "${trim_vcf}")
echo ""

# Note: 
# Trimming may not change the num of variants here, 
# still better to be done: just in case 

# --- Add annotations --- #

# Progress report
echo "Adding selected technical annotations ..."
echo ""

# File names
ann_vcf="${output_folder}/wecare_ampliseq_ann.vcf"
ann_log="${output_folder}/wecare_ampliseq_ann.log"

# Add Type annotation
java -Xmx6g -jar "${gatk}" \
   -T VariantAnnotator \
  -R "${ref_genome}" \
  -L "${targets_interval_list}" \
  -V "${trim_vcf}" \
  -o "${ann_vcf}" \
  -A VariantType \
  -A GenotypeSummaries \
  &>  "${ann_log}"

# --- Flag multiallelic variants --- #

# Make mask for multiallelic variants

# Progress report
echo "Making mask for multiallelic variants ..."

# File names
ma_mask_vcf="${output_folder}/wecare_ampliseq_ma_mask.vcf"
ma_mask_log="${output_folder}/wecare_ampliseq_ma_mask.log"

# Make mask
java -Xmx6g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${targets_interval_list}" \
  -V "${ann_vcf}" \
  -o "${ma_mask_vcf}" \
  -restrictAllelesTo MULTIALLELIC \
  &> "${ma_mask_log}"

# Add flag for multiallelic variants

# Progress report
echo "Adding flag for multiallelic variants ..."
echo ""

# File names
ma_vcf="${output_folder}/wecare_ampliseq_ma.vcf"
ma_log="${output_folder}/wecare_ampliseq_ma.log"

# Add flag
java -Xmx6g -jar "${gatk}" \
  -T VariantAnnotator \
  -R "${ref_genome}" \
  -L "${targets_interval_list}" \
  -V "${ann_vcf}" \
  -comp:MultiAllelic "${ma_mask_vcf}" \
  -o "${ma_vcf}" \
  &> "${ma_log}"

# --- Add locations IDs to INFO field --- #
# To facilitate tracing variants locations and 
# dealing with multiallelic sites at later steps

# Progress report
echo "Adding location ID and number of ALT alleles to INFO field ..."
echo ""

# Output file name
upd_vcf="${output_folder}/wecare_ampliseq_upd.vcf"

# Temporary folder and files
tmp_folder="${output_folder}/tmp"
rm -fr "${tmp_folder}" # remove temporary folder, if exists
mkdir -p "${tmp_folder}"

# Compile names for temporary files
tmp1=$(mktemp --tmpdir="${tmp_folder}" "tmp1".XXXXXX)
tmp2=$(mktemp --tmpdir="${tmp_folder}" "tmp2".XXXXXX)
tmp3=$(mktemp --tmpdir="${tmp_folder}" "tmp3".XXXXXX)
tmp4=$(mktemp --tmpdir="${tmp_folder}" "tmp4".XXXXXX)
tmp5=$(mktemp --tmpdir="${tmp_folder}" "tmp5".XXXXXX)
tmp6=$(mktemp --tmpdir="${tmp_folder}" "tmp6".XXXXXX)
tmp7=$(mktemp --tmpdir="${tmp_folder}" "tmp7".XXXXXX)

# Get source data witout header
grep -v "^#" "${ma_vcf}" > "${tmp1}"

# Add LocID
awk '{printf("LocID=Loc%09d\t%s\n", NR, $0)}' "${tmp1}" > "${tmp2}"
awk 'BEGIN {OFS="\t"} ; { $9 = $9";"$1 ; print}' "${tmp2}" > "${tmp3}"
cut -f2- "${tmp3}" > "${tmp4}"

# Add number of ALT alleles (= number of commas in ALT field + 1)
# https://stackoverflow.com/questions/8629410/unix-count-occurrences-of-character-per-line-field
# https://www.gnu.org/software/gawk/manual/html_node/String-Functions.html
awk '{print gsub(/,/,",",$5), $0}' "${tmp4}" > "${tmp5}"
awk 'BEGIN {OFS="\t"} ; { $9 = $9";NumALTs="$1+1 ; print}' "${tmp5}" > "${tmp6}"
cut -f2- "${tmp6}" > "${tmp7}"

# Prepare updated header
grep "^##" "${ma_vcf}" > "${upd_vcf}"
echo '##INFO=<ID=LocID,Number=1,Type=String,Description="Location ID">' >> "${upd_vcf}"
echo '##INFO=<ID=NumALTs,Number=1,Type=Integer,Description="Number of ALT alleles">' >> "${upd_vcf}"
grep "^#CHROM" "${ma_vcf}" >> "${upd_vcf}"

# Append data to header in the output file
cat "${tmp7}" >> "${upd_vcf}"

# Remove temporary files
rm -fr "${tmp_folder}"

# Completion message
echo "Done all tasks"
date
echo ""
