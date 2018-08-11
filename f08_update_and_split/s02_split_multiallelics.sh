#!/bin/bash

# s02_split_multiallelics.sh
# Started: Alexey Larionov, 10Aug2018
# Last updated: Alexey Larionov, 10Aug2018

# Use:
# sbatch s02_split_multiallelics.sh

# Note loading of texlive module for bcf-stats
# Note using GATK-3 (GATK-4 may be used later)

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s02_split_multiallelics
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=00:10:00
#SBATCH --output=s02_split_multiallelics.log
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
echo "Split multiallelic sites, then calculate and plot bcf-stats for the split VCF"
date
echo ""

# Folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"

data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
vcf_folder="${data_folder}/d08_processed_vcf"

# Source file
source_vcf="${vcf_folder}/wecare_ampliseq_upd.vcf"

# Tools 
tools_folder="${base_folder}/tools"
bcftools="${tools_folder}/bcftools/bcftools-1.8/bin/bcftools"
plot_vcfstats="${tools_folder}/bcftools/bcftools-1.8/bin/plot-vcfstats"
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
echo ""
echo "--- Tools ---"
echo ""
echo "bcftools: ${bcftools}"
echo "plot_vcfstats: ${plot_vcfstats}"
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

# --- Split multiallelic sites --- #
# Note that we do not normalise/left-align, just split

# References and examples:
#http://www.htslib.org/doc/bcftools.html
#https://genome.sph.umich.edu/wiki/Variant_Normalization
#https://github.com/samtools/bcftools/issues/84
#https://www.biostars.org/p/189752
# http://apol1.blogspot.co.uk/2014/11/best-practice-for-converting-vcf-files.html

# Progress report
echo "Splitting multiallelic sites ..."
echo ""

# Output file
split_vcf="${vcf_folder}/wecare_ampliseq_split.vcf"

# Split
"${bcftools}" norm -m-both "${source_vcf}" > "${split_vcf}"
echo ""

# --- Check number of split variants --- #
echo "Num of variants in split vcf:"
printf "%'d\n" $(grep -vc "^#" "${split_vcf}")
echo ""

# --- Trim split variants --- #
# Removes variants and alleles that have not been detected in any genotype

# Progress report
echo "Trimming variants ..."
echo ""

# File names
split_trim_vcf="${vcf_folder}/wecare_ampliseq_split_trim.vcf"
split_trim_log="${vcf_folder}/wecare_ampliseq_split_trim.log"

java -Xmx6g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${targets_interval_list}" \
  -V "${split_vcf}" \
  -o "${split_trim_vcf}" \
  --excludeNonVariants \
  --removeUnusedAlternates \
  &>  "${split_trim_log}"

# Note: 
# The trimming does not change the num of variants, done just in case 

# --- Check number of trimmed variants --- #
echo "Num of variants in split trimmed vcf:"
printf "%'d\n" $(grep -vc "^#" "${split_trim_vcf}")
echo ""

# --- Remove * ALT after split --- #
# * is for overlap with upstream deletion
# It is removed because it cannot be interpreted by VEP

# Progress report
echo "Remov-ng * ALT after split ..."
echo ""

# File names
split_trim_star_vcf="${vcf_folder}/wecare_ampliseq_split_trim_star.vcf"

# Remove * ALT-s
awk 'BEGIN {OFS="\t"} ; $5 != "*" ' "${split_trim_vcf}" > "${split_trim_star_vcf}"

# --- Check number of variants w/o * ALTs --- #

echo "Num of variants w/o * ALTs:"
printf "%'d\n" $(grep -vc "^#" "${split_trim_star_vcf}")
echo ""

# --- Add variant ID to INFO field --- #
# To simplify tracing variants at later steps

# Progress report
echo "Adding variant ID to INFO field ..."
echo ""

# Output file name
output_vcf="${vcf_folder}/wecare_ampliseq.vcf"

# Temporary folder and files
tmp_folder="${vcf_folder}/tmp"
rm -fr "${tmp_folder}" # Remove temporary folder, if existed
mkdir -p "${tmp_folder}"

# Compile names for temporary files
tmp1=$(mktemp --tmpdir="${tmp_folder}" "tmp1".XXXXXX)
tmp2=$(mktemp --tmpdir="${tmp_folder}" "tmp2".XXXXXX)
tmp3=$(mktemp --tmpdir="${tmp_folder}" "tmp3".XXXXXX)
tmp4=$(mktemp --tmpdir="${tmp_folder}" "tmp4".XXXXXX)

# Prepare data witout header
grep -v "^#" "${split_trim_star_vcf}" > "${tmp1}"
awk '{printf("VarID=Var%09d\t%s\n", NR, $0)}' "${tmp1}" > "${tmp2}"
awk 'BEGIN {OFS="\t"} ; { $9 = $9";"$1 ; print}' "${tmp2}" > "${tmp3}"
cut -f2- "${tmp3}" > "${tmp4}"

# Prepare header
grep "^##" "${split_trim_star_vcf}" > "${output_vcf}"
echo '##INFO=<ID=VarID,Number=1,Type=String,Description="Variant ID">' >> "${output_vcf}"
grep "^#CHROM" "${split_trim_star_vcf}" >> "${output_vcf}"

# Append data to header in the output file
cat "${tmp4}" >> "${output_vcf}"

# Remove temporary files and folder
rm -fr "${tmp_folder}" 

# --- Calculate bcf-stats --- #

# Progress report
echo "Calculating bcf-stats ..."
echo ""

# Files and folders
stats_folder="${data_folder}/d08_processed_vcf/bcf_stats"
rm -fr "${stats_folder}" # remove stats folder, if existed
mkdir -p "${stats_folder}"

stats="${stats_folder}/wecare_ampliseq.vchk"

# Calculate stats
"${bcftools}" stats "${output_vcf}" > "${stats}" 
"${plot_vcfstats}" "${stats}" -p "${stats_folder}"

# Completion message
echo ""
echo "Done all tasks"
date
echo ""
