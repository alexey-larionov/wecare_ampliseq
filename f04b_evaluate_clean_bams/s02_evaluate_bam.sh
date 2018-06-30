#!/bin/bash

# s02_evaluate_bam.sh
# Started: Alexey Larionov, modifyed from script of 2016
# Last updated: Alexey Larionov, 30Jun2018

# This script is called from another script on already allocated compute node,
# so there is no need for sbatch

# 25 copies of this script is launched in parallel to process 25 BAMs per batch 
# Assuming that picard and other evaluation tools use single thread per analysis 
# and up to 6GB memory per thread, the batches of 25 samples would fit well to 
# the capacity of a single node on cluster (32 cores & 192 GB RAM per node) 

# Stop at runtime errors
set -e

# Start message
echo "Clean and validate raw bam"
date
echo ""

# Read parameters
sample="${1}"
clean_bam_folder="${2}"

samtools="${3}"
picard="${4}"
gatk="${5}"
qualimap="${6}"

# samtools folder ?
# r folder ?

samtools_metrics_folder="${7}"
picard_metrics_folder="${8}"
gatk_metrics_folder="${9}"
qualimap_folder="${10}"

ref_genome="${11}"
amplicons_bed="${12}"
inserts_bed="${13}"

######################################

sample="103_S147_L007"
clean_bam_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d04_clean_bams/bam"

samtools="/rds/project/erf33/rds-erf33-medgen/tools/samtools/samtools-1.8/bin/samtools"
picard="/rds/project/erf33/rds-erf33-medgen/tools/picard/picard-2.18.7/picard.jar"
#gatk="/rds/project/erf33/rds-erf33-medgen/tools/gatk/..."
#qualimap="/rds/project/erf33/rds-erf33-medgen/tools/qualimap/..."

# samtools folder ?
# r folder ?

samtools_metrics_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d04_clean_bams/samtools"
picard_metrics_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d04_clean_bams/picard"
gatk_metrics_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d04_clean_bams/gatk"
qualimap_folder="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/d04_clean_bams/qualimap"

#amplicons_bed="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/..."
#inserts_bed="/rds/project/erf33/rds-erf33-medgen/users/alexey/wecare_ampliseq/..."

######################################

# Progress report
echo "sample: ${sample}"
echo ""
echo "clean_bam_folder: ${clean_bam_folder}"
echo ""
echo "samtools: ${samtools}"
echo "picard: ${picard}"
echo "gatk: ${gatk}"
echo "qualimap: ${qualimap}"
echo ""
echo "java:"
java -version
echo ""
echo "samtools_metrics_base_folder: ${samtools_metrics_base_folder}"
echo "picard_metrics_base_folder: ${picard_metrics_base_folder}"
echo "gatk_metrics_base_folder: ${gatk_metrics_base_folder}"
echo "qualimap_base_folder: ${qualimap_base_folder}"
echo ""
echo "amplicons_bed: ${amplicons_bed}"
echo "inserts_bed: ${inserts_bed}"
echo ""

# Parce the sample name (just in case)
IFS="_" read sample_no illumina_id lane_no <<< ${sample}

# ------- Collect flagstat metrics ------- #

# Progress report
echo "Started collecting flagstat metrics"

# flagstats metrics file name
flagstats_file="${sample}_flagstat.txt"
flagstats="${flagstat_folder}/${flagstats_file}"

# Sort using samtools (later may be switched to picard SortSam)
${samtools} flagstat "${mkdup_bam}" > "${flagstats}"

# Progress report
echo "Completed collecting flagstat metrics: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Collect inserts sizes ------- #

# Progress report
echo "Started collecting inserts sizes"

# Stats files names
inserts_stats="${picard_inserts_folder}/${sample}_insert_sizes.txt"
inserts_plot="${picard_inserts_folder}/${sample}_insert_sizes.pdf"

# Process sample
"${java6}" -Xmx20g -jar "${picard}" CollectInsertSizeMetrics \
  INPUT="${mkdup_bam}" \
  OUTPUT="${inserts_stats}" \
  HISTOGRAM_FILE="${inserts_plot}" \
  VERBOSITY=ERROR \
  QUIET=true &

# .. in parallel with other stats started after this .. hence akward Xmx20
# add R to path ... 

# ------- Collect alignment summary metrics ------- #

# Progress report
echo "Started collecting alignment summary metrics"

# Mkdup stats file names
alignment_metrics="${picard_alignment_folder}/${sample}_as_metrics.txt"

# Process sample (using default adapters list)
"${java6}" -Xmx20g -jar "${picard}" CollectAlignmentSummaryMetrics \
  INPUT="${mkdup_bam}" \
  OUTPUT="${alignment_metrics}" \
  REFERENCE_SEQUENCE="${ref_genome}" \
  VERBOSITY=ERROR \
  QUIET=true &

# .. in parallel with other stats started after this .. hence akward Xmx20
# use same genome as for BWA index in alignment ... 


# ------- Collect Targeted Pcr Metrics ------- #

#https://broadinstitute.github.io/picard/command-line-overview.html#CollectTargetedPcrMetrics 

java -jar picard.jar CollectTargetedPcrMetrics \
       I=input.bam \
       O=pcr_metrics.txt \
       R=reference_sequence.fasta \
       AMPLICON_INTERVALS=amplicon.interval_list \
       TARGET_INTERVALS=targets.interval_list 

# ------- Qualimap ------- #

if [ "${run_qualimap}" == "yes" ] 
then

    # Progress report
    echo "Started qualimap"
    
    # Folder for sample
    qualimap_sample_folder="${qualimap_results_folder}/${sample}"
    mkdir -p "${qualimap_sample_folder}"
    
    # Variable to reset default memory settings for qualimap
    export JAVA_OPTS="-Xms1G -Xmx60G"
    
    # Start qualimap
    qualimap_log="${qualimap_sample_folder}/${sample}.log"
    "${qualimap}" bamqc \
      -bam "${mkdup_bam}" \
      --paint-chromosome-limits \
      --genome-gc-distr HUMAN \
      --feature-file "${targets_bed_6}" \
      --outside-stats \
      -nt 14 \
      -outdir "${qualimap_sample_folder}" &> "${qualimap_log}"
    
    # Progress report
    echo "Completed qualimap: $(date +%d%b%Y_%H:%M:%S)"
    echo ""
    
elif [ "${run_qualimap}" == "no" ] 
then
    # Progress report
    echo "Omitted qualimap"
    echo ""
else
    # Error message
    echo "Wrong qualimap setting: ${run_qualimap}"
    echo "Should be yes or no"
    echo "Qualimap omitted"
    echo ""
fi


# Completion message
echo "Done all tasks"
date
echo ""
