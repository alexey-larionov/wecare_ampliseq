#!/bin/bash

# s01_bqsr_tables.sh
# Started: Alexey Larionov, 10Jul2018
# Last updated: Alexey Larionov, 10Jul2018

# Use:
# sbatch s01_bqsr_tables.sh

# Notes:
#
# Indel realignment is obsolete with GATK-4 HC: 
# https://gatkforums.broadinstitute.org/gatk/discussion/11455/realignertargetcreator-and-indelrealigner
#
# Running BQSR may also be questionable because of supposedly small number on bases in non-PCR duplicates: 
# https://gatkforums.broadinstitute.org/gatk/discussion/4272/targeted-sequencing-appropriate-to-use-baserecalibrator-bqsr-on-150m-bases-over-small-intervals
#
# Memory requirements:
# GATK tools supporting -nt option (RealignerTargetCreator and UnifyedGenotyper) require 
# more memory for running in parallel (-nt) than for running in a single-thread mode.
# Broad's web site suggests that RealignerTargetCreator with one data thread may need ~2G.
# Accordingly, in -nt 12 mode it would require ~24G.  One thread in HPC is provided 6G RAM,
# which is more than enough to support GATK run. 

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s01_bqsr_tables
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=01:00:00
#SBATCH --output=s01_bqsr_tables.log
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
echo "Base quality score recalibrarion on cleaned BAMs"
date
echo ""

# --- Folders --- #

scripts_folder="$( pwd -P )"

base_folder="/rds/project/erf33/rds-erf33-medgen"

data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
clean_bam_folder="${data_folder}/d04_clean_bam/bam"
tables_bam_folder="${data_folder}/d05_preprocessed_bam/table"
mkdir -p "${tables_bam_folder}"

# --- Tools --- #

tools_folder="${base_folder}/tools"
gatk="${tools_folder}/gatk/gatk-4.0.5.2/gatk"
r_folder="${tools_folder}/r/R-3.2.0/bin"

# --- Resources --- #
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
echo "clean_bam_folder: ${clean_bam_folder}"
echo "tables_bam_folder: ${tables_bam_folder}"
echo ""
echo "--- Tools ---"
echo ""
echo "gatk: ${gatk}"
echo "r_folder: ${r_folder}"
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

# --- Environment --- #

# Add R version with required libraries to the path (for plots?)
export PATH="${r_folder}":$PATH 

# --- Samples --- #

# Get list of source bam files 
cd "${clean_bam_folder}"
clean_bam_files=$(ls *_fixmate_sort_rg.bam)

# Make list of samples 
samples=$(sed -e 's/_fixmate_sort_rg.bam//g' <<< "${clean_bam_files}")
echo "Detected $(wc -w <<< ${samples}) bam files in the source folder"

# --- Analysis --- #

# Initialise batch counter
sample_count=0

#samples="103_S147_L007"
samples="108_S482_L008"

# For each sample
for sample in ${samples}
do
  
  # Parce the sample name
  IFS="_" read sample_no illumina_id lane_no <<< ${sample}
  
  # Compile file names
  clean_bam="${clean_bam_folder}/${sample}_fixmate_sort_rg.bam"
  bqsr_table="${tables_bam_folder}/${sample}_bqsr.txt"
  bqsr_table_log="${tables_bam_folder}/${sample}_bqsr.log"
  
  # Prepere BQSR table
  "${gatk}" BaseRecalibrator \
    -I "${clean_bam}" \
    -O "${bqsr_table}" \
    -R "${ref_genome}" \
    -L "${targets_interval_list}" \
    --known-sites "${dbsnp}" \
    --known-sites "${indels_1k}" \
    --known-sites "${indels_mills}" \
    &> "${bqsr_table_log}"
    
done # next sample

# Progress report


# Remove temporary files
#cd "${scripts_folder}"
#rm -fr "${tmp_folder}"

# Completion message
echo ""
echo "Done all tasks"
date
echo ""
