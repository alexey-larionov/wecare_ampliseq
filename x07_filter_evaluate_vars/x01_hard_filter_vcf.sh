#!/bin/bash

# s01_hard_filter_vcf.sh
# Filtering vcf
# Alexey Larionov, 31Aug2016

# Ref:
# http://gatkforums.broadinstitute.org/gatk/discussion/2806/howto-apply-hard-filters-to-a-call-set

# stop at any error
set -e

# Read parameters
job_file="${1}"
scripts_folder="${2}"

# Update pipeline log
echo "Started s01_filter_vcf: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Set parameters
source "${scripts_folder}/a01_read_config.sh"
echo "Read settings"
echo ""

# Go to working folder
init_dir="$(pwd)"
cd "${filtered_vcf_folder}"

# --- Copy source gvcfs to cluster --- #

# Progress report
echo "Started copying source data"

# Source files and folders (on source server)
source_vcf_folder="${dataset_name}"
source_vcf="${dataset_name}.vcf"

# Intermediate files and folders on HPC
tmp_folder="${filtered_vcf_folder}/tmp"
mkdir -p "${tmp_folder}"
mkdir -p "${histograms_folder}"
mkdir -p "${vcfstats_folder}"

# --- Copy data --- #

# Suspend stopping at errors
set +e

rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/${source_vcf_folder}/${source_vcf}" "${tmp_folder}/"
exit_code_1="${?}"

rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/${source_vcf_folder}/${source_vcf}.idx" "${tmp_folder}/"
exit_code_2="${?}"

# Stop if copying failed
if [ "${exit_code_1}" != "0" ] || [ "${exit_code_2}" != "0" ]  
then
  echo ""
  echo "Failed getting source data from NAS"
  echo "Script terminated"
  echo ""
  exit
fi

# Restore stopping at errors
set -e

# Progress report
echo "Completed copying source data: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Filter by QUAL and DP --- #

# Progress report
echo "Started filtering by QUAL and DP"

# File names
raw_vcf="${tmp_folder}/${source_vcf}"
filt_vcf="${tmp_folder}/${dataset_name}_${filter_name}_filt.vcf"
filt_log="${logs_folder}/${dataset_name}_${filter_name}_filt.log"

# Filtering SNPs
"${java}" -Xmx60g -jar "${gatk}" \
  -T VariantFiltration \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${raw_vcf}" \
  -o "${filt_vcf}" \
  --filterName "DP_LESS_THAN_${MIN_DP}" \
  --filterExpression "DP < ${MIN_DP}" \
  --filterName "QUAL_LESS_THAN_${MIN_QUAL}" \
  --filterExpression "QUAL < ${MIN_QUAL}" \
  &>  "${filt_log}"

# Progress report
echo "Completed filtering: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Remove filtered variants from vcf --- #

# Progress report
echo "Started removing filtered variants from vcf"

# File names
cln_vcf="${filtered_vcf_folder}/${dataset_name}_${filter_name}.vcf"
cln_vcf_md5="${filtered_vcf_folder}/${dataset_name}_${filter_name}.md5"
cln_vcf_log="${logs_folder}/${dataset_name}_${filter_name}_cln.log"

# Remove filtered variants
"${java}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${filt_vcf}" \
  -o "${cln_vcf}" \
  --excludeFiltered \
  -nt 14 &>  "${cln_vcf_log}"

# Make md5 file
md5sum $(basename "${cln_vcf}") $(basename "${cln_vcf}.idx") > "${cln_vcf_md5}"

# Completion message to log
echo "Completed removing filtered variants from vcf: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Prepare data for histograms --- #

# Progress report
echo "Started preparing data for histograms"

# File names
histograms_data_txt="${histograms_folder}/${dataset_name}_${filter_name}_histograms_data.txt"
histograms_data_log="${logs_folder}/${dataset_name}_${filter_name}_histograms_data.log"

# Prepare data
"${java}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${targets_intervals}" -ip 10 \
  -V "${cln_vcf}" \
  -F LocID -F FILTER -F TYPE -F MultiAllelic \
  -F CHROM -F POS -F REF -F ALT -F DP -F QUAL -F AS_VQSLOD \
  -o "${histograms_data_txt}" \
  -AMD -raw &>  "${histograms_data_log}"  

# -AMD allow missed data
# -raw keep filtered (if there was any ...)

# Progress report
echo "Completed preparing data for histograms: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Generate histograms using R markdown script --- #

# Progress report
echo "Started making histograms"

# Prepare file names
histograms_report_html="${histograms_folder}/${dataset_name}_${filter_name}_histograms_report.html"
histograms_plot_log="${logs_folder}/${dataset_name}_${filter_name}_histograms_plot.log"

# Compile R script
r_script="library('rmarkdown', lib='"${r_lib_folder}"'); render('"${scripts_folder}"/r01_make_html.Rmd', params=list(dataset='"${dataset_name}_${filter_name}_cln"' , working_folder='"${histograms_folder}"/' , data_file='"${histograms_data_txt}"', min_dp='"${MIN_DP}"', min_qual='"${MIN_QUAL}"'), output_file='"${histograms_report_html}"')"

# Execute R script
# Notes:
# Path to R was added to environment and modules required for 
# R with knitr were loaded in s01_genotype_gvcfs.sb.sh:
# module load gcc/5.2.0
# module load boost/1.50.0
# module load texlive/2015
# module load pandoc/1.15.2.1

echo "--------- Preparing html report with histograms --------- " >> "${histograms_plot_log}"
echo "" >> "${histograms_plot_log}"
"${r_bin_folder}/R" -e "${r_script}" &>> "${histograms_plot_log}"

echo "" >> "${histograms_plot_log}"

# Progress report
echo "Completed making histograms: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- vcfstats --- #

# Progress report
echo "Started calculating vcfstats and making plots for filtered variants"
echo ""

# File names
vcf_stats="${vcfstats_folder}/${dataset_name}_${filter_name}_cln.vchk"

# Calculate vcf stats
"${bcftools}" stats -F "${ref_genome}" "${cln_vcf}" > "${vcf_stats}" 

# Plot the stats
"${plot_vcfstats}" "${vcf_stats}" -p "${vcfstats_folder}/"
echo ""

# Completion message to log
echo "Completed calculating vcf stats: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Copy results to NAS --- #

# Progress report
echo "Started copying results to NAS"

# Remove temporary data
rm -fr "${tmp_folder}"

# --- Copy files to NAS --- #

# Suppress stopping at errors
set +e

rsync -thrqe "ssh -x" "${filtered_vcf_folder}" "${data_server}:${project_location}/${project}/" 
exit_code="${?}"

# Stop if copying failed
if [ "${exit_code}" != "0" ]  
then
  echo ""
  echo "Failed copying results to NAS"
  echo "Script terminated"
  echo ""
  exit
fi

# Resume stopping at errors
set -e

# Progress report to log on nas
log_on_nas="${project_location}/${project}/${dataset_name}_${filter_name}/logs/${dataset_name}_${filter_name}.log"
timestamp="$(date +%d%b%Y_%H:%M:%S)"
ssh -x "${data_server}" "echo \"Completed copying results to NAS: ${timestamp}\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Remove results from cluster
rm -f "${cln_vcf}"
rm -f "${cln_vcf}.idx"
rm -f "${cln_vcf_md5}"

#rm -fr "${logs_folder}"
#rm -fr "${histograms_folder}"
#rm -fr "${vcfstats_folder}"

ssh -x "${data_server}" "echo \"Removed vcfs from cluster\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Return to the initial folder
cd "${init_dir}"
