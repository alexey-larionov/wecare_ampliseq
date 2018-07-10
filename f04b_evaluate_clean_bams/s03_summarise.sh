#!/bin/bash

# s03_summarise.sh
# Started: Alexey Larionov, 06Jul2018
# Last updated: Alexey Larionov, 09Jul2018

# Use:
# sbatch s03_summarise.sh
# or
# ./s03_summarise.sh &> s03_summarise.log

# Plot summary metrics for alignment and QC

# Notes:
# Tested with gnuplot 5.0 (may not work with old gnuplot versions)
# Requires ssh connection to be established with -X option
# Requires LiberationSans-Regular.ttf font (included in tools/config)

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s03_summarise
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=00:10:00
#SBATCH --output=s03_summarise.log
#SBATCH --exclusive
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
echo "Make summary tables and plots for BAMs QC"
date
echo ""

# --- Folders --- #

scripts_folder="$( pwd -P )"

base_folder="/rds/project/erf33/rds-erf33-medgen"
clean_bam_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results/d04_clean_bam"

bams_folder="${clean_bam_folder}/bam"
samtools_metrics_folder="${clean_bam_folder}/samtools"
gatk_metrics_folder="${clean_bam_folder}/gatk"
picard_metrics_folder="${clean_bam_folder}/picard"
qualimap_folder="${clean_bam_folder}/qualimap_on_targets"

mkdir -p "${samtools_metrics_folder}/summary"
mkdir -p "${gatk_metrics_folder}/summary"
mkdir -p "${picard_metrics_folder}/summary"
mkdir -p "${qualimap_folder}/0_summary"

# --- Tools --- #

tools_folder="${base_folder}/tools"

gnuplot="${tools_folder}/gnuplot/gnuplot-5.0.1/bin/gnuplot"
LiberationSansRegularTTF="${tools_folder}/fonts/liberation-fonts-ttf-2.00.1/LiberationSans-Regular.ttf"

qualimap="${tools_folder}/qualimap/qualimap_v2.2.1/qualimap"
r_folder="${tools_folder}/r/R-3.2.0/bin" 

# Progress report
echo "--- Folders ---"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo ""
echo "clean_bam_folder: ${clean_bam_folder}"
echo ""
echo "bams_folder: ${bams_folder}"
echo "samtools_metrics_folder: ${samtools_metrics_folder}"
echo "gatk_metrics_folder: ${gatk_metrics_folder}"
echo "picard_metrics_folder: ${picard_metrics_folder}"
echo "qualimap_folder: ${qualimap_folder}"
echo ""
echo "--- Tools ---"
echo ""
echo "gnuplot: ${gnuplot}"
echo "LiberationSansRegularTTF: ${LiberationSansRegularTTF}"
echo ""
echo "qualimap: ${qualimap}"
echo "r_folder: ${r_folder}"
echo ""

# --- Environment --- #

# Add R version with required libraries to the path 
# (for picard insert metrics plots and for qualimap)
export PATH="{r_folder}":$PATH 

# Get list of samples

# Make list of source bam files 
cd "${bams_folder}"
clean_bam_files=$(ls *_fixmate_sort_rg.bam)

# Make list of samples 
samples=$(sed -e 's/_fixmate_sort_rg.bam//g' <<< "${clean_bam_files}")
echo "Detected $(wc -w <<< ${samples}) bam files in the source folder"
echo ""

cd "${clean_bam_folder}"

# ------------------------------------------------- #
#                Samtools Flagstats                 #
# ------------------------------------------------- #

# --------------- Make summary table ---------------#

# Make header
samtools_flagstats_summary="${samtools_metrics_folder}/summary/samtools_flagstats_summary.txt"
header="sample\ttotal_reads\tsecondary\tsupplementary\tduplicates\tmapped\tpaired_in_sequencong\tread1\tread2\tproperly_paired\twith_itself_and_mate_mapped\tsingletons\twith_mate_mapped_to_a_different_chr\twith_mate_mapped_to_a_different_chr_mapq5"
echo -e "${header}" > "${samtools_flagstats_summary}" 

# For each sample
for sample in ${samples}
do
  
  # flagstats metrics file name
  flagstats_file="${sample}_flagstat.txt"
  flagstats="${samtools_metrics_folder}/flagstats/${flagstats_file}"
  
  # Initialise list of metrics
  metrics="${sample}"
  
  # Fill list of metrics
  while read metric etc
  do
    metrics="${metrics}\t${metric}"
  done < "${flagstats}"

  # Add sample to summary file
  echo -e "${metrics}" >> "${samtools_flagstats_summary}"

done

# Progress report
echo "Made summary table for samtools flagststs"

# ------------------- Make plot ------------------- #

# Parameters
plot_file="${samtools_metrics_folder}/summary/samtools_reads_counts.png"
title="Wecare ampliseq samtools flagststs: count of reads mapped in pairs"
ylabel="Read counts"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set style fill solid border
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set format y "'"%'.0f"'"
set output "'"${plot_file}"'"
plot "'"${samtools_flagstats_summary}"'" using "'"with_itself_and_mate_mapped"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for samtools flagststs reads counts"
echo ""

# ------------------------------------------------- #
#                  gatk flagstats                   #
# ------------------------------------------------- #

# --------------- Make summary table ---------------#

# Make header
gatk_flagstats_summary="${gatk_metrics_folder}/summary/gatk_flagstats_summary.txt"
header="sample\ttotal\tqc_failure\tduplicates\tmapped\tpaired_in_sequencong\tread1\tread2\tproperly_paired\twith_itself_and_mate_mapped\tsingletons\twith_mate_mapped_to_a_different_chr\twith_mate_mapped_to_a_different_chr_mapq5\tmapped_pct\tproperly_paired_pct\tsingletons_pct"
echo -e "${header}" > "${gatk_flagstats_summary}" 

# For each sample
for sample in ${samples}
do
  
  # flagstats metrics file name
  flagstats_file="${sample}_flagstat.txt"
  flagstats="${gatk_metrics_folder}/flagstats/${flagstats_file}"
  
  # Initialise list of metrics
  metrics="${sample}"
  
  # Fill list of metrics
  while read metric etc
  do
    if [ ${metric} != "Tool" ]; then
      metrics="${metrics}\t${metric}"
    fi
  done < "${flagstats}"
  
  # Percent duplicates
  pcts=$(grep -oP "\d{1,2}\.\d{2}(?=%)" "${flagstats}")
  pcts=${pcts//$'\n'/'\t'} 
  
  # Add sample to summary file
  echo -e "${metrics}\t${pcts}" "" >> "${gatk_flagstats_summary}"

done

# Progress report
echo "Made gatk flagstat summary table"

# ------------------- Make plots ------------------- #

###### Mapped pairs #####

# Parameters
plot_file="${gatk_metrics_folder}/summary/gatk_reads_counts.png"
title="Wecare ampliseq gatk flagststs: count of reads mapped in pairs"
ylabel="Read counts"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set style fill solid border
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set format y "'"%'.0f"'"
set output "'"${plot_file}"'"
plot "'"${gatk_flagstats_summary}"'" using "'"with_itself_and_mate_mapped"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for gatk flagstat read counts"

###### properly_paired_pct #####

# Parameters
plot_file="${gatk_metrics_folder}/summary/gatk_proper_pairs.png"
title="Wecare ampliseq gatk flagststs: fraction of reads mapped in proper pairs"
ylabel="Fraction of properly paired"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${gatk_flagstats_summary}"'" using "'"properly_paired_pct"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for gatk flagstat percent of proper pairs"
echo ""

# ------------------------------------------------- #
#                Picard insert sizes                #
# ------------------------------------------------- #

# --------------- Make summary table ---------------#

# Make header
picard_inserts_summary="${picard_metrics_folder}/summary/picard_inserts_summary.txt"
header="MEDIAN_INSERT_SIZE	MODE_INSERT_SIZE	MEDIAN_ABSOLUTE_DEVIATION	MIN_INSERT_SIZE	MAX_INSERT_SIZE	MEAN_INSERT_SIZE	STANDARD_DEVIATION	READ_PAIRS	PAIR_ORIENTATION	WIDTH_OF_10_PERCENT	WIDTH_OF_20_PERCENT	WIDTH_OF_30_PERCENT	WIDTH_OF_40_PERCENT	WIDTH_OF_50_PERCENT	WIDTH_OF_60_PERCENT	WIDTH_OF_70_PERCENT	WIDTH_OF_80_PERCENT	WIDTH_OF_90_PERCENT	WIDTH_OF_95_PERCENT	WIDTH_OF_99_PERCENT	SAMPLE	LIBRARY	READ_GROUP"
echo -e "SAMPLE\t${header}" > "${picard_inserts_summary}" 

# Collect data
for sample in $samples
do

  # Stats file name
  stats_file="${picard_metrics_folder}/insert_sizes/${sample}_insert_sizes.txt"
  
  # Get stats
  stats=$(awk '/^MEDIAN_INSERT_SIZE/{getline; print}' "${stats_file}")
  
  # Add stats to the file
  echo -e "${sample}\t${stats}" >> "${picard_inserts_summary}"
  
done

# Progress report
echo "Made summary table for picard insert sizes"

# ------------------- Make plot ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_insert_sizes.png"
title="Wecare ampliseq picard: median inserts sizes"
ylabel="Bases"
xlabel="Samples"

# Gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set output "'"${plot_file}"'"
plot "'"${picard_inserts_summary}"'" using "'"MEDIAN_INSERT_SIZE"'":xtic(1)'

# Plotting
"${gnuplot}" <<< "${gpl_script}"

# Progress report
echo "Made plot for picard insert sizes"
echo ""

# ------------------------------------------------- #
#         Picard alignment summary metrics          #
# ------------------------------------------------- #

# --------------- Make summary table ---------------#

# Make header
picard_alignment_metrics="${picard_metrics_folder}/summary/picard_alignment_metrics.txt"
header="CATEGORY	TOTAL_READS	PF_READS	PCT_PF_READS	PF_NOISE_READS	PF_READS_ALIGNED	PCT_PF_READS_ALIGNED	PF_ALIGNED_BASES	PF_HQ_ALIGNED_READS	PF_HQ_ALIGNED_BASES	PF_HQ_ALIGNED_Q20_BASES	PF_HQ_MEDIAN_MISMATCHES	PF_MISMATCH_RATE	PF_HQ_ERROR_RATE	PF_INDEL_RATE	MEAN_READ_LENGTH	READS_ALIGNED_IN_PAIRS	PCT_READS_ALIGNED_IN_PAIRS	PF_READS_IMPROPER_PAIRS	PCT_PF_READS_IMPROPER_PAIRS	BAD_CYCLES	STRAND_BALANCE	PCT_CHIMERAS	PCT_ADAPTER	SAMPLE	LIBRARY	READ_GROUP"
echo -e "SAMPLE\t${header}" > "${picard_alignment_metrics}" 

# Collect data
for sample in $samples
do
  
  # Stats file name
  stats_file="${picard_metrics_folder}/alignment_metrics/${sample}_alignment_metrics.txt"
  
  # Get stats
  stats=$(grep "^PAIR" "${stats_file}")
  
  # Add stats to the file
  echo -e "${sample}\t${stats}" >> "${picard_alignment_metrics}"
  
done

# Progress report
echo "Made table for picard alignment summary metrics"

# ------------------- Plot READS_ALIGNED_IN_PAIRS ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_alignment_read_counts.png"
title="Wecare ampliseq picard alignment summary metrics: count of reads mapped in pairs"
ylabel="Read counts"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set format y "'"%'.0f"'"
set output "'"${plot_file}"'"
plot "'"${picard_alignment_metrics}"'" using "'"READS_ALIGNED_IN_PAIRS"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard alignment summary metrics READS_ALIGNED_IN_PAIRS"

# ------------------- Plot PCT_READS_ALIGNED_IN_PAIRS ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_alignment_pct_reads_pairs.png"
title="Wecare ampliseq picard alignment summary metrics: fraction of reads mapped in pairs"
ylabel="Reads fraction"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0.9 :] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_alignment_metrics}"'" using "'"PCT_READS_ALIGNED_IN_PAIRS"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard alignment summary metrics PCT_READS_ALIGNED_IN_PAIRS"

# ------------------- Plot MEAN_READ_LENGTH ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_alignment_mean_read_length.png"
title="Wecare ampliseq picard alignment summary metrics: mean read length"
ylabel="Bases"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_alignment_metrics}"'" using "'"MEAN_READ_LENGTH"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard alignment summary metrics MEAN_READ_LENGTH"

# ------------------- Plot PF_INDEL_RATE ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_alignment_indel_rate.png"
title="Wecare ampliseq picard alignment summary metrics: indel rate"
ylabel="Fraction"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_alignment_metrics}"'" using "'"PF_INDEL_RATE"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard alignment summary metrics PF_INDEL_RATE"

# ------------------- Plot PF_MISMATCH_RATE ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_alignment_mismatch_rate.png"
title="Wecare ampliseq picard alignment summary metrics: mismatch rate"
ylabel="Fraction"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_alignment_metrics}"'" using "'"PF_MISMATCH_RATE"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard alignment summary metrics PF_MISMATCH_RATE"

# ------------------- Plot STRAND_BALANCE ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_alignment_strand_balance.png"
title="Wecare ampliseq picard alignment summary metrics: strand balance"
ylabel="Fraction"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0.48:0.52] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_alignment_metrics}"'" using "'"STRAND_BALANCE"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard alignment summary metrics STRAND_BALANCE"
echo ""

# ------------------------------------------------- #
#             Picard pcr targets metrics            #
# ------------------------------------------------- #

# --------------- Make summary table ---------------#

# Make header
picard_pcr_metrics="${picard_metrics_folder}/summary/picard_pcr_metrics.txt"
header="CUSTOM_AMPLICON_SET	GENOME_SIZE	AMPLICON_TERRITORY	TARGET_TERRITORY	TOTAL_READS	PF_READS	PF_BASES	PF_UNIQUE_READS	PCT_PF_READS	PCT_PF_UQ_READS	PF_UQ_READS_ALIGNED	PF_SELECTED_PAIRS	PF_SELECTED_UNIQUE_PAIRS	PCT_PF_UQ_READS_ALIGNED	PF_BASES_ALIGNED	PF_UQ_BASES_ALIGNED	ON_AMPLICON_BASES	NEAR_AMPLICON_BASES	OFF_AMPLICON_BASES	ON_TARGET_BASES	ON_TARGET_FROM_PAIR_BASES	PCT_AMPLIFIED_BASES	PCT_OFF_AMPLICON	ON_AMPLICON_VS_SELECTED	MEAN_AMPLICON_COVERAGE	MEAN_TARGET_COVERAGE	MEDIAN_TARGET_COVERAGE	MAX_TARGET_COVERAGE	FOLD_ENRICHMENT	ZERO_CVG_TARGETS_PCT	PCT_EXC_DUPE	PCT_EXC_MAPQ	PCT_EXC_BASEQ	PCT_EXC_OVERLAP	PCT_EXC_OFF_TARGET	FOLD_80_BASE_PENALTY	PCT_TARGET_BASES_1X	PCT_TARGET_BASES_2X	PCT_TARGET_BASES_10X	PCT_TARGET_BASES_20X	PCT_TARGET_BASES_30X	AT_DROPOUT	GC_DROPOUT	HET_SNP_SENSITIVITY	HET_SNP_Q	SAMPLE	LIBRARY	READ_GROUP"
echo -e "SAMPLE\t${header}" > "${picard_pcr_metrics}" 

# Collect data
for sample in ${samples}
do

  # Stats file name
  stats_file="${picard_metrics_folder}/pcr_metrics/${sample}_pcr_metrics.txt"
  
  # Get stats
  stats=$(grep "^amplicons" "${stats_file}")
  
  # Add stats to the file
  echo -e "${sample}\t${stats}" >> "${picard_pcr_metrics}"
  
done

# Progress report
echo "Made table for picard targeted pcr metrics"

# ------------------- Plot PCT_OFF_AMPLICON ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_pcr_off_amplicon.png"
title="Wecare ampliseq picard pcr targeting metrics: bases off amplicon"
ylabel="Fraction"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_pcr_metrics}"'" using "'"PCT_OFF_AMPLICON"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard pcr targeting metrics PCT_OFF_AMPLICON"

# ------------------- Plot ZERO_CVG_TARGETS_PCT ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_pcr_zero_cov_tgts.png"
title="Wecare ampliseq picard pcr targeting metrics: zero covered target bases"
ylabel="Fraction"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_pcr_metrics}"'" using "'"ZERO_CVG_TARGETS_PCT"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard pcr targeting metrics ZERO_CVG_TARGETS_PCT"

# ------------------- Plot ZERO_CVG_TARGETS_PCT ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_pcr_zero_cov_tgts.png"
title="Wecare ampliseq picard pcr targeting metrics: zero covered target bases"
ylabel="Fraction"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_pcr_metrics}"'" using "'"ZERO_CVG_TARGETS_PCT"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard pcr targeting metrics ZERO_CVG_TARGETS_PCT"

# ------------------- Plot MEAN_TARGET_COVERAGE ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_pcr_mean_tgt_cov.png"
title="Wecare ampliseq picard pcr targeting metrics: mean targets coverage"
ylabel="Coverage"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_pcr_metrics}"'" using "'"MEAN_TARGET_COVERAGE"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard pcr targeting metrics MEAN_TARGET_COVERAGE"

# ------------------- Plot MEDIAN_TARGET_COVERAGE ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_pcr_median_tgt_cov.png"
title="Wecare ampliseq picard pcr targeting metrics: median targets coverage"
ylabel="Coverage"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_pcr_metrics}"'" using "'"MEDIAN_TARGET_COVERAGE"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard pcr targeting metrics MEDIAN_TARGET_COVERAGE"

# ------------------- Plot HET_SNP_SENSITIVITY ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_pcr_sensitivity.png"
title="Wecare ampliseq picard pcr targeting metrics: expected HET SNP sensitivity"
ylabel="Theoretically predicted sensitivity"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_pcr_metrics}"'" using "'"HET_SNP_SENSITIVITY"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard pcr targeting metrics HET_SNP_SENSITIVITY"

# ------------------- Plot PCT_TARGET_BASES_10X ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_pcr_tgt_bases_10x.png"
title="Wecare ampliseq picard pcr targeting metrics: target bases covered 10x"
ylabel="Fraction"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_pcr_metrics}"'" using "'"PCT_TARGET_BASES_10X"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard pcr targeting metrics PCT_TARGET_BASES_10X"

# ------------------- Plot PCT_TARGET_BASES_20X ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_pcr_tgt_bases_20x.png"
title="Wecare ampliseq picard pcr targeting metrics: target bases covered 20x"
ylabel="Fraction"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_pcr_metrics}"'" using "'"PCT_TARGET_BASES_20X"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard pcr targeting metrics PCT_TARGET_BASES_20X"

# ------------------- Plot PCT_TARGET_BASES_30X ------------------- #

# Parameters
plot_file="${picard_metrics_folder}/summary/picard_pcr_tgt_bases_30x.png"
title="Wecare ampliseq picard pcr targeting metrics: target bases covered 30x"
ylabel="Fraction"
xlabel="Samples"

# gnuplot script
gpl_script='
set terminal png font "'"${LiberationSansRegularTTF}"'" size 800,600 noenhanced
set style data histogram
set yrange [0:] 
unset xtics
unset key
set title "'"${title}"'"
set ylabel "'"${ylabel}"'"
set xlabel "'"${xlabel}"'"
set decimal locale
set output "'"${plot_file}"'"
plot "'"${picard_pcr_metrics}"'" using "'"PCT_TARGET_BASES_30X"'":xtic(1)'

# Plotting (discard message about setting decimal symbol)
"${gnuplot}" <<< "${gpl_script}" &>/dev/null

# Progress report
echo "Made plot for picard pcr targeting metrics PCT_TARGET_BASES_30X"
echo ""

# ------- Qualimap multi-sample summary ------- #

# Variable to reset x-display and default memory settings for qualimap
export JAVA_OPTS="-Djava.awt.headless=true -Xms1G -Xmx6G"

# Progress report
echo "Started multi-sample qualimap"

# Make folder for qualimap multi-sample results
qualimap_summary_folder="${qualimap_folder}/0_summary"

# Make samples list for qualimap multi-sample run
samples_list="${qualimap_summary_folder}/samples.list"
>"${samples_list}"

for sample in ${samples}
do
  echo -e "${sample}\t${qualimap_folder}/${sample}" >> "${samples_list}"
done

# Start qualimap
qualimap_log="${qualimap_summary_folder}/summary.log"
"${qualimap}" multi-bamqc \
  --data "${samples_list}" \
  -outdir "${qualimap_summary_folder}" &> "${qualimap_log}"

# Progress report
echo "Completed multi-sample qualimap"
echo ""

# ------- Report progress ------- #

# Start message
echo "Completed all summary tables and plots for BAMs QC"
date
echo ""
