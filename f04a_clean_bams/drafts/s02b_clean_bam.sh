#!/bin/bash

# s02_clean_bam.sh
# Started: Alexey Larionov, modifyed from script of 2016
# Last updated: Alexey Larionov, 27Jun2018

# This script is called from another script on already allocated compute node,
# so there is no need for sbatch

# 30 copies of this script is launched in parallel to process 30 BAMs per batch 
# Assuming that samtools and picard use single thread per analysis and 
# up to 6GB memory per thread, this would fit to the capacity of a single 
# node on cluster (32 cores & 192 GB RAM per node)
# Accordingly, max memory for the java/picard steps is explicitly limited by 6GB 

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
samtools="${4}"
picard="${5}"
htsjdk="${6}"
library="${7}"
platform="${8}"
flowcell="${9}"

######################################

sample="103_S147_L007"
raw_bam_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d03_bams/n01_raw_bams"
clean_bam_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d03_bams/n02_clean_bams"
samtools="/rds/project/erf33/rds-erf33-medgen/tools/samtools/samtools-1.8/bin/samtools"
picard="/rds/project/erf33/rds-erf33-medgen/tools/picard/picard-2.18.7/picard.jar"
htsjdk="/rds/project/erf33/rds-erf33-medgen/tools/htsjdk/htsjdk-2.16.0/htsjdk-2.16.0-4-gc4912e9-SNAPSHOT.jar"
library="wecare_ampliseq_01"
platform="illumina"
flowcell="HVMMTBBXX"

######################################

# Progress report
echo "sample: ${sample}"
echo ""
echo "raw_bam_folder: ${raw_bam_folder}"
echo "clean_bam_folder: ${clean_bam_folder}"
echo ""
echo "samtools: ${samtools}"
echo "picard: ${picard}"
echo "htsjdk: ${htsjdk}"
echo ""
java -version
echo ""
echo "library: ${library}"
echo "platform: ${platform}"
echo "flowcell: ${flowcell}"
echo ""

# Parce the sample name (lane_no is used in RG group)
IFS="_" read sample_no illumina_id lane_no <<< ${sample}

# ------- Sort by name ------- #

# Progress report
echo "Started sorting by name (required by fixmate)"

# Compile file names
raw_bam="${raw_bam_folder}/${sample}_raw.bam"
nsort_bam="${clean_bam_folder}/${sample}_nsort.bam"

# Sort using samtools (later may be switched to picard SortSam)
"${samtools}" sort -n -o "${nsort_bam}" \
  -T "${nsort_bam/_nsort.bam/_nsort_tmp}_${RANDOM}" \
  "${raw_bam}"

# Remove raw bam
#rm -f "${raw_bam}"

# Progress report
echo "Completed sorting by name: $(date +%H:%M:%S)"
echo ""

# ------- Fixmate ------- #

# Progress report
echo "Started fixing mate-pairs"

# Fixmated bam file name  
fixmate_bam="${clean_bam_folder}/${sample}_fixmate.bam"

# Fixmate (later may be switched to Picard FixMateInformation)
"${samtools}" fixmate "${nsort_bam}" "${fixmate_bam}"
# -r option would remove secondary and unmapped reads.

# Remove nsorted bam
rm -f "${nsort_bam}"

# Progress report
echo "Completed fixing mate-pairs: $(date +%H:%M:%S)"
echo ""

# ------- Sort by coordinate ------- #

# Progress report
echo "Started sorting by coordinate"

# Sorted bam file name
sort_bam="${clean_bam_folder}/${sample}_fixmate_sort.bam"

# Sort using samtools
"${samtools}" sort -o "${sort_bam}" \
  -T "${sort_bam/_sort.bam/_sort_tmp}_${RANDOM}" \
  "${fixmate_bam}"

# Remove fixmated bam
rm -f "${fixmate_bam}"

# Progress report
echo "Completed sorting by coordinate: $(date +%H:%M:%S)"
echo ""

# ------- FixBAMFile ------- #
# Fixing Bin field errors 
# ERROR: bin field of BAM record does not equal value computed based on 
# alignment start and end, and length of sequence to which read is aligned
# http://gatkforums.broadinstitute.org/gatk/discussion/4290/sam-bin-field-error-for-the-gatk-run
# Solution: htsjdk.samtools.FixBAMFile - as used below
# https://sourceforge.net/p/samtools/mailman/message/31853465/
# https://github.com/samtools/htsjdk/blob/master/src/main/java/htsjdk/samtools/FixBAMFile.java
#

# Progress report
echo "Started fixing bam bins field errors"

# File name for cleaned bam
binfix_bam="${clean_bam_folder}/${sample}_fixmate_sort_binfix.bam"

# Fix Bin field errors
java -Xmx6g -cp "${htsjdk}" htsjdk.samtools.FixBAMFile \
  "${sort_bam}" \
  "${binfix_bam}"

# Remove cleaned bam
rm -f "${sort_bam}"

# Progress report
echo "Completed fixing bam bins field errors: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- CleanSam ------- #
# Soft-clipping beyond-end-of-reference alignments and setting MAPQ to 0 for unmapped reads
# BWA samse/sampe (but not BWA MEM) often generates reads flagged as unmapped with MAPQ <> 0
# Correcting these is required to pass Picard strict validation.
# Indexing is suppressed because it caused an error during testing. 

# Progress report
echo "Started cleaning BAM file"

# File name for cleaned bam
clean_bam="${clean_bam_folder}/${sample}_fixmate_sort_binfix_clean.bam"

# Clean bam
java -Xmx6g -jar "${picard}" CleanSam \
  INPUT="${binfix_bam}" \
  OUTPUT="${clean_bam}" \
  VERBOSITY=ERROR \
  QUIET=true

# Remove sorted bam and its index
rm -f "${binfix_bam}"

# Progress report
echo "Completed bam cleaning: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Add RG and index ------- #

# Progress report
echo "Started adding read group information"

# File name for bam with RGs
rg_bam="${clean_bam_folder}/${sample}_fixmate_sort_binfix_clean_rg.bam"

# Add read groups
java -Xmx6g -jar "${picard}" AddOrReplaceReadGroups \
  INPUT="${clean_bam}" \
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
rm -f "${clean_bam}"

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
echo "Completed bam validation: $(date %H:%M:%S)"
echo ""

# Completion message
echo "Done all tasks"
date
echo ""
