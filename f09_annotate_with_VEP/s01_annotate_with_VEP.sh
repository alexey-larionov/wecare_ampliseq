#!/bin/bash

# s01_annotate_with_vep.sh
# Started: Alexey Larionov, 11Aug2018
# Last updated: Alexey Larionov, 11Aug2018

# Use:
# sbatch s01_annotate_with_vep.sh

# ------------------------------------ #
#         sbatch instructions          #
# ------------------------------------ #

#SBATCH -J s01_annotate_with_vep
#SBATCH -A TISCHKOWITZ-SL2-CPU
#SBATCH -p skylake
#SBATCH --mail-type=ALL
#SBATCH --no-requeue
#SBATCH --nodes=1
#SBATCH --time=00:10:00
#SBATCH --output=s01_annotate_with_vep.log
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
echo "Annotate vcf with vep"
date
echo ""

# Files and folders 
scripts_folder="$( pwd -P )"
base_folder="/rds/project/erf33/rds-erf33-medgen"

data_folder="${base_folder}/users/alexey/wecare_ampliseq/data_and_results"
input_folder="${data_folder}/d08_processed_vcf"
output_folder="${data_folder}/d09_annotated_with_vep"

rm -fr "${output_folder}" # remove folder with results, if exists
mkdir -p "${output_folder}"

source_vcf="${input_folder}/wecare_ampliseq.vcf"
output_vcf="${output_folder}/wecare_ampliseq_vep.vcf"
vep_report="${output_folder}/wecare_ampliseq_vep.html"
vep_log="${output_folder}/wecare_ampliseq_vep.log"

# Tools and resources
vep_script="/rds/project/erf33/rds-erf33-medgen/tools/ensembl/v91/ensembl-vep/vep"
vep_cache="/rds/project/erf33/rds-erf33-medgen/tools/ensembl/v91/ensembl-vep/grch37_cache"

# Required annotations
vep_fields="Location,Allele,Uploaded_variation,Consequence,IMPACT,"\
"Codons,Amino_acids,cDNA_position,CDS_position,Protein_position,"\
"VARIANT_CLASS,SIFT,PolyPhen,Existing_variation,CLIN_SIG,SOMATIC,"\
"PHENO,SYMBOL,SYMBOL_SOURCE,HGNC_ID,GENE_PHENO,MOTIF_NAME,MOTIF_POS,"\
"HIGH_INF_POS,MOTIF_SCORE_CHANGE,NEAREST,MAX_AF,MAX_AF_POPS,gnomAD_AF,"\
"gnomAD_AFR_AF,gnomAD_AMR_AF,gnomAD_ASJ_AF,gnomAD_EAS_AF,gnomAD_FIN_AF,"\
"gnomAD_NFE_AF,gnomAD_OTH_AF,gnomAD_SAS_AF,EXON,INTRON,DOMAINS,HGVSc,"\
"HGVSp,HGVS_OFFSET,Feature_type,Feature,ALLELE_NUM"

# Progress report
echo "--- Files and folders ---"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo ""
echo "source_vcf: ${source_vcf}"
echo "output_vcf: ${output_vcf}"
echo "vep_report: ${vep_report}"
echo ""
echo "--- Tools and resources ---"
echo ""
echo "vep_script: ${vep_script}"
echo "vep_cache: ${vep_cache}"
echo ""
perl --version
echo ""
echo "--- Settings ---"
echo ""
echo "vep_fields: ${vep_fields}"
echo ""

# Add location of additional perl modules to PERL5LIB
export PERL5LIB="/rds/project/erf33/rds-erf33-medgen/tools/ensembl/v91/lib/perl5"

# Add location of tabix and bgzip to PATH
PATH="/rds/project/erf33/rds-erf33-medgen/tools/htslib/htslib-1.3.1/bin:$PATH"

# run vep with VCF output
echo "Running VEP-script..."
echo ""

perl "${vep_script}" \
  -i "${source_vcf}" \
  -o "${output_vcf}" --vcf \
  --stats_file "${vep_report}" \
  --cache --offline --dir_cache "${vep_cache}" \
  --check_ref --gencode_basic --pick \
  --variant_class --sift b --polyphen b \
  --check_existing --exclude_null_alleles \
  --symbol --gene_phenotype \
  --regulatory --nearest symbol \
  --max_af --af_gnomad \
  --numbers --domains --hgvs --allele_number \
  --fields "${vep_fields}" --vcf_info_field "ANN" \
  --force_overwrite --no_progress \
  &> "${vep_log}"

# Completion message
echo "Done all tasks"
date
echo ""

# -------------------------------------------------------------- #
#             Notes on selected fields and options               #
# -------------------------------------------------------------- #


# Selected fields available w/o special requiest:
#------------------------------------------------

# Location, Allele, Uploaded_variation, Consequence, IMPACT
# Codons, Amino_acids, cDNA_position, CDS_position, Protein_position


# Additional requested fields:
#-----------------------------

# --variant_class: VARIANT_CLASS
# --sift b: SIFT
# --polyphen b: PolyPhen
# --check_existing: Existing_variation, CLIN_SIG, SOMATIC, PHENO

# --symbol: SYMBOL, SYMBOL_SOURCE, HGNC_ID
# --gene_phenotype: GENE_PHENO

# --regulatory: MOTIF_NAME, MOTIF_POS, HIGH_INF_POS, MOTIF_SCORE_CHANGE
# --nearest symbol: NEAREST

# --max_af: MAX_AF, MAX_AF_POPS

# --af_gnomad: gnomAD_AF, gnomAD_AFR_AF, gnomAD_AMR_AF, gnomAD_ASJ_AF, gnomAD_EAS_AF, 
#              gnomAD_FIN_AF, gnomAD_NFE_AF, gnomAD_OTH_AF, gnomAD_SAS_AF

# --numbers: EXON, INTRON

# --domains: DOMAINS


# Additional fields requested to try:
#------------------------------------

# Feature (Ensemble ID, available w/o request)
# Feature_type (Transcript, RegulatoryFeature, MotifFeature; available w/o request)
# --allele_number: ALLELE_NUM (sanity check: should always be 1 in our data)
# --hgvs: HGVSc, HGVSp, HGVS_OFFSET

# Omitted options
#----------------

# --fork 14 (to parallelise if needed, should be consistent with ntasks requested in sbatch instructions)
# --buffer_size [number] (default 5000; could be increased to speed-up - at expence of using more mamory)

# Full lists of available fields and options:
#--------------------------------------------

# https://www.ensembl.org/info/docs/tools/vep/vep_formats.html#output
# https://www.ensembl.org/info/docs/tools/vep/script/vep_options.html
