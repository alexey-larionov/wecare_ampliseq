#!/bin/bash

# s02_evaluate_bam.sh
# Started: Alexey Larionov, modifyed from script of 2016
# Last updated: Alexey Larionov, 03Jul2018

# This script is called from another script on already allocated compute node,
# so there is no need for sbatch

# 25 copies of this script is launched in parallel to process 25 BAMs per node.  
# Assuming that picard and other evaluation tools use single thread per analysis 
# and up to 6GB memory per thread, the batches of 25 samples would fit well to 
# the capacity of a single node on cluster (32 cores & 192 GB RAM per node) 

# Stop at runtime errors
set -e

# Start message
echo "Evaluate clean bam"
date
echo ""

# Read parameters
sample="${1}"
clean_bam_folder="${2}"

samtools="${3}"
gatk="${4}"
picard="${5}"
qualimap="${6}"
r_folder="${7}"

ref_genome="${8}"
amplicons_interval_list="${9}"
targets_interval_list="${10}"
targets_bed="${11}"

samtools_metrics_folder="${12}"
gatk_metrics_folder="${13}"
picard_metrics_folder="${14}"
qualimap_folder="${15}"

######################################
#
# Settings used for debugging:
#
# sample="103_S147_L007"
# clean_bam_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d04_clean_bam/bam"
#
# samtools="/rds/project/erf33/rds-erf33-medgen/tools/samtools/samtools-1.8/bin/samtools"
# gatk="/rds/project/erf33/rds-erf33-medgen/tools/gatk/gatk-4.0.5.2/gatk"
# picard="/rds/project/erf33/rds-erf33-medgen/tools/picard/picard-2.18.7/picard.jar"
# qualimap="/rds/project/erf33/rds-erf33-medgen/tools/qualimap/qualimap_v2.2.1/qualimap"
# r_folder="/rds/project/erf33/rds-erf33-medgen/tools/r/R-3.2.0/bin" 
#
# ref_genome="/rds/project/erf33/rds-erf33-medgen/resources/gatk_bundle/b37/decompressed/human_g1k_v37_decoy.fasta"
# amplicons_interval_list="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d00_targets/amplicons.interval_list"
# targets_interval_list="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d00_targets/targets.interval_list"
# targets_bed="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d00_targets/targets_6.bed"
#
# samtools_metrics_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d04_clean_bam/samtools"
# gatk_metrics_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d04_clean_bam/gatk"
# picard_metrics_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d04_clean_bam/picard"
# qualimap_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d04_clean_bam/qualimap_on_targets"
#
# mkdir -p "${samtools_metrics_folder}/flagstats"
# mkdir -p "${gatk_metrics_folder}/flagstats"
# mkdir -p "${picard_metrics_folder}/insert_sizes"
# mkdir -p "${picard_metrics_folder}/alignment_metrics"
# mkdir -p "${picard_metrics_folder}/pcr_metrics"
# mkdir -p "${qualimap_folder}"
#
# Add R version with required libraries to the path 
# (for picard insert metrics plots and qualimap)
# PATH="{r_folder}":$PATH 
#
# Variable to reset default memory settings for qualimap
# export JAVA_OPTS="-Xms1G -Xmx6G"
#
######################################

# Progress report
echo "sample: ${sample}"
echo ""
echo "clean_bam_folder: ${clean_bam_folder}"
echo ""
echo "samtools: ${samtools}"
echo "gatk: ${gatk}"
echo "picard: ${picard}"
echo "qualimap: ${qualimap}"
echo "r_folder: ${r_folder}"
echo ""
echo "java:"
java -version
echo ""
echo "ref_genome: ${ref_genome}"
echo "amplicons_interval_list: ${amplicons_interval_list}"
echo "targets_interval_list: ${targets_interval_list}"
echo "targets_bed: ${targets_bed}"
echo ""
echo "samtools_metrics_folder: ${samtools_metrics_folder}"
echo "gatk_metrics_folder: ${gatk_metrics_folder}"
echo "picard_metrics_folder: ${picard_metrics_folder}"
echo "qualimap_folder: ${qualimap_folder}"
echo ""

# ------- Start section ------- #

# Compile bam file name
clean_bam="${clean_bam_folder}/${sample}_fixmate_sort_rg.bam"

# Parce the sample name (just in case)
IFS="_" read sample_no illumina_id lane_no <<< ${sample}


# ------- Preparing targets for local realignment around indels ------- #

# Notes:

# Takes 10-20min for an initial dedupped bam of 5-10GB, whith up to 50% of 
# bases on targets.  Time estimates for the later steps refer to similar initial bams.     

# GATK tools supporting -nt option (RealignerTargetCreator and UnifyedGenotyper) require 
# more memory for running in parallel (-nt) than for running in a single-thread mode.
# Broad's web site suggests that RealignerTargetCreator with one data thread may need ~2G.
# Accordingly, in -nt 12 mode it would require ~24G.  Darwin node provide 60G, which is 
# more than enough to support -nt 12 run. 

# Progress report
echo "Preparing targets for local realignment around indels"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"

# File names
dedup_bam="${dedup_bam_folder}/${sample}_dedup.bam"
idr_targets="${idr_folder}/${sample}_idr_targets.intervals"
idr_targets_log="${idr_folder}/${sample}_idr_targets.log"

# Process sample
"${java}" -Xmx60g -jar "${gatk}" \
  -T RealignerTargetCreator \
	-R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -known "${indels_1k}" \
  -known "${indels_mills}" \
	-I "${dedup_bam}" \
  -o "${idr_targets}" \
  -nt 12 2> "${idr_targets_log}"

# Progress report
echo "Completed: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Performing local realignment around indels ------- #

# Notes:
# Takes 15-30min.
# -nt / -nct options are NOT available to paralellise IndelRealigner by multi-thrading: 
# this is one of the non-parallelisable bottlenecks when processing one sample at a time.
# -L at this step REMOVES all data outside of the target intervals from the output bam file.   
# To preserve all reads the -L option could be omitted at this step.

# Progress report
echo "Performing local realignment around indels"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"

# File names
idr_bam="${proc_bam_folder}/${sample}_idr.bam"
idr_log="${idr_folder}/${sample}_idr.log"

# Process sample
"${java}" -Xmx60g -jar "${gatk}" \
  -T IndelRealigner \
	-R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -targetIntervals "${idr_targets}" \
  -known "${indels_1k}" \
  -known "${indels_mills}" \
  -I "${dedup_bam}" \
  -o "${idr_bam}" 2> "${idr_log}"

# Remove dedup bam 
rm -f "${dedup_bam}"
rm -f "${dedup_bam%bam}bai"

# Progress report
echo "Completed: $(date +%d%b%Y_%H:%M:%S)"
echo ""


# ------- Collect gatk flagstat metrics ------- #

# Progress report
echo "Collecting gatk flagstat metrics"
echo "--------------------------------"
echo ""

# gatk flagstats metrics file name
gatk_flagstats_file="${gatk_metrics_folder}/flagstats/${sample}_flagstat.txt"

# Collect flagstat metrics using samtools (later may be switched to gatk FlagStat)
"${gatk}" FlagStat \
  -I "${clean_bam}" \
  > "${gatk_flagstats_file}"

# Progress report
echo "Completed collecting gatk flagstat metrics: $(date +%H:%M:%S)"
echo ""

# ------- Collect picard inserts sizes ------- #
# Requires R in the PATH (with certain libraries installed)

# Progress report
echo "Collecting picard insert sizes metrics"
echo "--------------------------------------"
echo ""

# Insert stats files names
picard_inserts_folder="${picard_metrics_folder}/insert_sizes"
inserts_stats="${picard_inserts_folder}/${sample}_insert_sizes.txt"
inserts_plot="${picard_inserts_folder}/${sample}_insert_sizes.pdf"

# Process sample
java -Xmx6g -jar "${picard}" CollectInsertSizeMetrics \
  INPUT="${clean_bam}" \
  OUTPUT="${inserts_stats}" \
  HISTOGRAM_FILE="${inserts_plot}" \
  VERBOSITY=ERROR \
  QUIET=true

# Progress report
echo "Completed collecting picard insert sizes metrics: $(date +%H:%M:%S)"
echo ""

# ------- Collect picard alignment summary metrics ------- #

# Progress report
echo "Collecting picard alignment summary metrics"
echo "-------------------------------------------"
echo ""

# Alignment stats file names
alignment_metrics_file="${picard_metrics_folder}/alignment_metrics/${sample}_alignment_metrics.txt"

# Process sample (using default adapters list???)
java -Xmx6g -jar "${picard}" CollectAlignmentSummaryMetrics \
  INPUT="${clean_bam}" \
  OUTPUT="${alignment_metrics_file}" \
  REFERENCE_SEQUENCE="${ref_genome}" \
  VERBOSITY=ERROR \
  QUIET=true

# Progress report
echo "Completed collecting picard alignment summary metrics: $(date +%H:%M:%S)"
echo ""

# ------- Collect picard targeted PCR metrics ------- #

# Progress report
echo "Collecting picrd targeted pcr metrics"
echo "-------------------------------------"
echo ""

# PCR stats file name
pcr_metrics_file="${picard_metrics_folder}/pcr_metrics/${sample}_pcr_metrics.txt"

# Process sample
java -Xmx6g -jar "${picard}" CollectTargetedPcrMetrics \
  INPUT="${clean_bam}" \
  OUTPUT="${pcr_metrics_file}" \
  REFERENCE_SEQUENCE="${ref_genome}" \
  AMPLICON_INTERVALS="${amplicons_interval_list}" \
  TARGET_INTERVALS="${targets_interval_list}" \
  VERBOSITY=ERROR \
  QUIET=true

# Progress report
echo "Completed collecting picard picard targeted pcr metrics: $(date +%H:%M:%S)"
echo ""

# ------- Qualimap ------- #
# Requires R in the PATH (with certain libraries installed)
# Dont use --outside-stats option

# Progress report
echo "Collecting metrics for qualimap"
echo "-------------------------------"
echo ""

# Folder for sample
qualimap_sample_folder="${qualimap_folder}/${sample}"
mkdir -p "${qualimap_sample_folder}"

# Qualimap log file name
qualimap_log="${qualimap_sample_folder}/${sample}.log"

# Start qualimap
"${qualimap}" bamqc \
  -bam "${clean_bam}" \
  --paint-chromosome-limits \
  --genome-gc-distr HUMAN \
  --feature-file "${targets_bed}" \
  -outdir "${qualimap_sample_folder}" \
  &> "${qualimap_log}"

# Progress report
echo "Completed qualimap: $(date +%H:%M:%S)"
echo ""

# Completion message
echo "--------------"
echo "Done all tasks"
date
echo ""
