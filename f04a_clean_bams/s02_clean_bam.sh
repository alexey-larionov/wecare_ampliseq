#!/bin/bash

# s02_clean_bam.sh
# Started: Alexey Larionov, modifyed from script of 2016
# Last updated: Alexey Larionov, 30Jun2018

# This script is called from another script on already allocated compute node,
# so there is no need for sbatch

# 30 copies of this script is launched in parallel to process 30 BAMs per batch 
# Assuming that picard uses single thread per analysis and it is explicitly limited 
# by up to 6GB memory per thread, this would fit to the capacity of a single 
# node on cluster (32 cores & 192 GB RAM per node) 

# Stop at runtime errors
set -e

# Start message
echo "Clean and validate raw bam"
date
echo ""

# Read parameters
sample="${1}"
raw_bam_folder="${2}"
clean_bam_folder="${3}"
picard="${4}"
library="${5}"
platform="${6}"
flowcell="${7}"

######################################

#sample="103_S147_L007"
#raw_bam_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d03_bams/n01_raw_bams"
#clean_bam_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d03_bams/n02_clean_bams"
#picard="/rds/project/erf33/rds-erf33-medgen/tools/picard/picard-2.18.7/picard.jar"
#library="wecare_ampliseq_01"
#platform="illumina"
#flowcell="HVMMTBBXX"

######################################

# Progress report
echo "sample: ${sample}"
echo ""
echo "raw_bam_folder: ${raw_bam_folder}"
echo "clean_bam_folder: ${clean_bam_folder}"
echo ""
#echo "samtools: ${samtools}"
echo "picard: ${picard}"
#echo "htsjdk: ${htsjdk}"
echo ""
echo "java:"
java -version
echo ""
echo "library: ${library}"
echo "platform: ${platform}"
echo "flowcell: ${flowcell}"
echo ""

# Parce the sample name (lane_no is used in RG group)
IFS="_" read sample_no illumina_id lane_no <<< ${sample}

# ------- Fixmate ------- #

# Progress report
echo "Started fixing mate-pairs"

# Compile file names
raw_bam="${raw_bam_folder}/${sample}_raw.bam"
fixmate_bam="${clean_bam_folder}/${sample}_fixmate.bam"

# Fixmate
java -Xmx6g -jar "${picard}" FixMateInformation \
  INPUT="${raw_bam}" \
  OUTPUT="${fixmate_bam}" \
  VERBOSITY=ERROR \
  QUIET=true

# Remove raw bam
#rm -f "${raw_bam}"

# Progress report
echo "Completed fixing mate-pairs: $(date +%H:%M:%S)"
echo ""

# ------- Sort by coordinate ------- #

# Progress report
echo "Started sorting by coordinate"

# Sorted bam file name
sort_bam="${clean_bam_folder}/${sample}_fixmate_sort.bam"

# Sort
java -Xmx6g -jar "${picard}" SortSam \
  INPUT="${fixmate_bam}" \
  OUTPUT="${sort_bam}" \
  SORT_ORDER=coordinate \
  VERBOSITY=ERROR \
  QUIET=true

# Remove fixmated bam
rm -f "${fixmate_bam}"

# Progress report
echo "Completed sorting by coordinate: $(date +%H:%M:%S)"
echo ""

# ------- Add RG and index ------- #

# Progress report
echo "Started adding read group information"

# File name for bam with RGs
rg_bam="${clean_bam_folder}/${sample}_fixmate_sort_rg.bam"

# Add read groups
java -Xmx6g -jar "${picard}" AddOrReplaceReadGroups \
  INPUT="${sort_bam}" \
  OUTPUT="${rg_bam}" \
  RGID="${sample}_${library}" \
  RGLB="${library}" \
  RGPL="${platform}" \
  RGPU="${flowcell}_${lane_no}" \
  RGSM="${sample}" \
  VERBOSITY=ERROR \
  CREATE_INDEX=true \
  QUIET=true

# Remove bam without RG
rm -f "${sort_bam}"

# Progress report
echo "Completed indexing and adding read group information: $(date +%H:%M:%S)"
echo ""

# ------- Validate bam ------- #
# exits if errors found (prints initial 100 errors by default)

# Progress report
echo "Started bam validation"

# Validate bam
java -Xmx6g -jar "${picard}" ValidateSamFile \
  INPUT="${rg_bam}"
#  MODE=SUMMARY

# Progress report
echo "Completed bam validation: $(date +%H:%M:%S)"
echo ""

# Completion message
echo "Done all tasks"
date
echo ""
