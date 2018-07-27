#!/bin/bash

# s01_make_gvcfs.sh
# Started: Alexey Larionov, 24Jul2018
# Last updated: Alexey Larionov, 24Jul2018

# Use:
# sbatch s01_make_gvcfs.sh

# This script launches analysis in batches of 30 BAMs per batch.   
# Allowing gatk to use 6GB memory per run, batches of 20 would match 
# the capacity of a single node on cluster (32 cores & 192 GB RAM per node)

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s01_make_gvcfs
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=36:00:00
#SBATCH --output=s01_make_gvcfs.log
#SBATCH --exclusive
##SBATCH --qos=INTR

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
echo "Make individual gVCF files (in batches)"
date
echo ""

# Folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"
data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
bam_folder="${data_folder}/d05_preprocessed_bam/bqsr_bam"
gvcf_folder="${data_folder}/d06_gvcf/gvcf"

rm -fr "${gvcf_folder}" # remove tables folder, if existed
mkdir -p "${gvcf_folder}"

# Tools 
tools_folder="${base_folder}/tools"
gatk="${tools_folder}/gatk/gatk-4.0.5.2/gatk"

# Resources 
targets_interval_list="${data_folder}/d00_targets/targets.interval_list"
resources_folder="${base_folder}/resources"
ref_genome="${resources_folder}/gatk_bundle/b37/decompressed/human_g1k_v37_decoy.fasta"

# Progress report
echo "--- Folders ---"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo ""
echo "bam_folder: ${bam_folder}"
echo "gvcf_folder: ${gvcf_folder}"
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
echo "targets_interval_list: ${targets_interval_list}"
echo ""

# Batches 

# Make list of source bam files 
# note sorting by size: -S to get files of similar size into batches
cd "${bam_folder}"
bam_files=$(ls -S *_fixmate_sort_rg_bqsr.bam)

# Make list of samples 
samples=$(sed -e 's/_fixmate_sort_rg_bqsr.bam//g' <<< "${bam_files}")
echo "Detected $(wc -w <<< ${samples}) bam files in the source folder"

# Make batches of 30 samples each (store batch files in tmp folder)
tmp_folder="${gvcf_folder}/tmp"
rm -fr "${tmp_folder}" # remove temporary folder, if existed
mkdir -p "${tmp_folder}"
cd "${tmp_folder}"
split -l 30 <<< "${samples}"
batches=$(ls)

# Progress report
echo "Made "$(wc -w <<< $batches)" batches of up to 30 samples each"
echo ""

# Initialise batch counter
batch_no=0

# For each batch
for batch in ${batches}
do
  
  # Get list of samples in the batch
  samples=$(cat $batch)

  # For each sample in the batch
  for sample in ${samples}
  do  
  
    # Compile file names
    bam="${bam_folder}/${sample}_fixmate_sort_rg_bqsr.bam"
    gvcf="${gvcf_folder}/${sample}.g.vcf.gz"
    hc_gvcf_log="${gvcf_folder}/${sample}.log"
    
    "${gatk}" --java-options "-Xmx6g" HaplotypeCaller  \
      -I "${bam}" \
      -O "${gvcf}" \
      -R "${ref_genome}" \
      -L "${targets_interval_list}" \
      -ERC GVCF \
      --max-reads-per-alignment-start 0 \
      &> "${hc_gvcf_log}" &
      
      # --max-reads-per-alignment-start 0 
      # Suppress down-sampling - assuming PCR may give random proportions of alleles ...
      # should sort of somatic tool be used with DP 10 and AF 20 ?? 
      
  done # next sample in the batch
  
  # Whait until the batch (all background processes) completed
  wait
  
  # Progress report
  batch_no=$(( $batch_no + 1 ))
  echo "$(date +%H:%M:%S) Done batch ${batch_no}"
  
done # next batch

# Remove temporary files
cd "${scripts_folder}"
rm -fr "${tmp_folder}"

# Completion message
echo ""
echo "Done all tasks"
date
echo ""
