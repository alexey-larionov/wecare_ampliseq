echo "wecare ampliseq source data check and extract"
echo "AL14Jun2018"
date
cd /home/al720/rds/rds-erf33-medgen/users/alexey/wecare_ampliseq/data_and_results/source_data
md5sum -c 180522_K00178_0090_BHVMMTBBXX_alarionov.tar.gz.md5
tar -xf 180522_K00178_0090_BHVMMTBBXX_alarionov.tar.gz
echo "Checked and extracted"
