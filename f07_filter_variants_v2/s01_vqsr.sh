#!/bin/bash

# s01_vqsr.sh
# Started: Alexey Larionov, 07Aug2018
# Last updated: Alexey Larionov, 09Aug2018

# Use:
# sbatch s01_vqsr.sh

# VQSR raw VCF

# Notes;

# 1) a customised R installation is used (with some R libraries pre-installed)

# 2) After the preliminary assessment
# - QD was excluded from the model 
# - Stricter VQSR TS settings (95 for SNPs and for 90 INDELs)

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s01_vqsr
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=00:10:00
#SBATCH --output=s01_vqsr.log
#SBATCH --ntasks=4
#SBATCH --qos=INTR

## Modules section (required, do not remove)
. /etc/profile.d/modules.sh
module purge
module load rhel7/default-peta4 

module load gcc/5.2.0
module load boost/1.50.0
module load texlive/2015
module load pandoc/1.15.2.1
export PATH=/rds/project/erf33/rds-erf33-medgen/tools/r/R-3.3.2/bin:$PATH

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
echo "VQSR"
date
echo ""

# Folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"
data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
raw_vcf_folder="${data_folder}/d06_raw_vcf/raw_vcf"
vqsr_folder="${data_folder}/d07_filtered_vcf_v02/vqsr"
vqsr_tmp_folder="${data_folder}/d07_filtered_vcf_v02/vqsr/misc"

rm -fr "${vqsr_folder}" # remove results folder, if existed
mkdir -p "${vqsr_tmp_folder}"

# Sourse file
raw_vcf="${raw_vcf_folder}/wecare_ampliseq_raw.vcf.gz"

# Tools 
tools_folder="${base_folder}/tools"
gatk="${tools_folder}/gatk/gatk-4.0.5.2/gatk"

# Resources 
targets_interval_list="${data_folder}/d00_targets/targets.interval_list"

resources_folder="${base_folder}/resources"
ref_genome="${resources_folder}/gatk_bundle/b37/decompressed/human_g1k_v37_decoy.fasta"
hapmap="${resources_folder}/gatk_bundle/b37/decompressed/hapmap_3.3.b37.vcf"
omni="${resources_folder}/gatk_bundle/b37/decompressed/1000G_omni2.5.b37.vcf"
phase1_1k_hc="${resources_folder}/gatk_bundle/b37/decompressed/1000G_phase1.snps.high_confidence.b37.vcf"
dbsnp_138="${resources_folder}/gatk_bundle/b37/decompressed/dbsnp_138.b37.vcf"
mills="${resources_folder}/gatk_bundle/b37/decompressed/Mills_and_1000G_gold_standard.indels.b37.vcf"

# Settings
SNP_TS="95.0"
INDEL_TS="90.0"

# Progress report
echo "--- Files and folders ---"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo "vqsr_tmp_folder: ${vqsr_tmp_folder}"
echo ""
echo "raw_vcf: ${raw_vcf}"
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
echo "hapmap: ${hapmap}"
echo "omni: ${omni}"
echo "phase1_1k_hc: ${phase1_1k_hc}"
echo "dbsnp_138: ${dbsnp_138}"
echo ""
echo "targets_interval_list: ${targets_interval_list}"
echo ""
echo "--- Settings ---"
echo ""
echo "SNP_TS: ${SNP_TS}"
echo "INDEL_TS: ${INDEL_TS}"
echo ""

# --- Train vqsr snp model --- #

# Progress report
echo "Training vqsr snp model ..."

# File names
recal_snp="${vqsr_tmp_folder}/wecare_ampliseq_snp.recal"
plots_snp="${vqsr_tmp_folder}/wecare_ampliseq_snp_plots.R"
tranches_snp="${vqsr_tmp_folder}/wecare_ampliseq_snp.tranches"
log_train_snp="${vqsr_tmp_folder}/wecare_ampliseq_snp_train.log"

# Train vqsr snp model
"${gatk}" VariantRecalibrator \
  --java-options "-Xmx20g" \
  -R "${ref_genome}" \
  -L "${targets_interval_list}" \
  -V "${raw_vcf}" \
  -O "${recal_snp}" \
  -mode SNP \
  --resource hapmap,known=false,training=true,truth=true,prior=15.0:"${hapmap}" \
  --resource omni,known=false,training=true,truth=false,prior=12.0:"${omni}" \
  --resource 1000G,known=false,training=true,truth=false,prior=10.0:"${phase1_1k_hc}" \
  --resource dbsnp,known=true,training=false,truth=false,prior=2.0:"${dbsnp_138}" \
  -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR \
  -tranche 100.0 -tranche 99.0 -tranche 95.0  -tranche 90.0 \
  --tranches-file "${tranches_snp}" \
  --rscript-file "${plots_snp}" \
  --max-gaussians 4 \
  -titv 3.2 \
  &>  "${log_train_snp}"

# --- Apply vqsr snp model --- #

# Progress report
echo "Applying vqsr snp model ..."

# File names
vqsr_snp_vcf="${vqsr_tmp_folder}/wecare_ampliseq_snp_vqsr.vcf"
log_apply_snp="${vqsr_tmp_folder}/wecare_ampliseq_snp_apply.log"

# Apply vqsr snp model
"${gatk}" ApplyVQSR \
  --java-options "-Xmx20g" \
  -R "${ref_genome}" \
  -L "${targets_interval_list}" \
  -V "${raw_vcf}" \
  -O "${vqsr_snp_vcf}" \
  --recal-file "${recal_snp}" \
  --tranches-file "${tranches_snp}" \
  --truth-sensitivity-filter-level "${SNP_TS}" \
  -mode SNP \
  &>  "${log_apply_snp}"

# --- Train vqsr indel model --- #

# Progress report
echo "Training vqsr indel model ..."

# File names
recal_indel="${vqsr_tmp_folder}/wecare_ampliseq_indel.recal"
plots_indel="${vqsr_tmp_folder}/wecare_ampliseq_indel_plots.R"
tranches_indel="${vqsr_tmp_folder}/wecare_ampliseq_indel.tranches"
log_train_indel="${vqsr_tmp_folder}/wecare_ampliseq_indel_train.log"

# Train vqsr indel model
"${gatk}" VariantRecalibrator \
  --java-options "-Xmx20g" \
  -R "${ref_genome}" \
  -L "${targets_interval_list}" \
  -V "${vqsr_snp_vcf}" \
  -O "${recal_indel}" \
  --resource mills,known=false,training=true,truth=true,prior=12.0:"${mills}" \
  --resource dbsnp,known=true,training=false,truth=false,prior=2.0:"${dbsnp_138}" \
  -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR \
  --tranches-file "${tranches_indel}" \
  --rscript-file "${plots_indel}" \
  -tranche 100.0 -tranche 99.0 -tranche 95.0 -tranche 90.0 \
  --max-gaussians 4 \
  -mode INDEL \
  &>  "${log_train_indel}"

# --- Apply vqsr indel model --- #

# Progress report
echo "Applying vqsr indel model..."

# File names
out_vcf="${vqsr_folder}/wecare_ampliseq_vqsr.vcf"
log_apply_indel="${vqsr_tmp_folder}/wecare_ampliseq_indel_apply.log"

# Apply vqsr indel model
"${gatk}" ApplyVQSR \
  --java-options "-Xmx20g" \
  -R "${ref_genome}" \
  -L "${targets_interval_list}" \
  -V "${vqsr_snp_vcf}" \
  -O "${out_vcf}" \
  --recal-file "${recal_indel}" \
  --tranches-file "${tranches_indel}" \
  --truth-sensitivity-filter-level "${INDEL_TS}" \
  -mode INDEL \
  &>  "${log_apply_indel}"  

# Progress report
echo "Done all tasks"
date
echo ""
