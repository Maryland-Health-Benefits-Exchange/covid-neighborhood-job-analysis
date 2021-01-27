library(tidyverse)
library(sf)
library(testit)

# Set Params -------------------------------------------------

setwd("H:/Documents/Uninsured_by_zip/R Studio/COVID19_Uninsured_Analysis/covid-neighborhood-job-analysis-master")

# Set static=TRUE if its your first time running the scripts, FALSE otherwise.
# This runs the scripts located in the scripts/static folder
static <- FALSE

# set dryrun = FALSE if you want to upload files to S3. Most users can safely
# set dryrun = TRUE
dryrun <- TRUE

# Set bin values for legend bins and histograms. The histogram needs to be
# manually reviewed and may need to change these values
tmax_bins <- c(100, 150, 200, 250, 675)
max_bins <- c(100, 250, 500, 750, 1000, 2000, 5000, 10000, 175000)



if (static) {
    # uncomment to re-run large file downloads
    source("scripts/static/1-download-data-static.R", encoding = "UTF-8")
    source("scripts/static/2-produce-geo-files-static.R", encoding = "UTF-8")
    source("scripts/static/3-produce-data-files-static.R", encoding = "UTF-8")
    if (!dryrun) {
        source("scripts/static/4-transfer-to-s3-static.R", encoding = "UTF-8")
    }
}

source("scripts/update/1-download-data-update.R", encoding = "UTF-8") # verified, need
# Filter CES and SAE data to just November to compare old incorrect Nov data to
# 'correct' Nov numbers
source("scripts/update/1b-filter-downloaded-data.R", encoding = "UTF-8")
source("scripts/update/2v4a-job-loss-projected-forward-ces.R", encoding = "UTF-8") # verified, need
source("scripts/update/2v4b-job-loss-by-industry-ces-sae-ipums-update.R", encoding = "UTF-8") # verified, need
source("scripts/update/2v4c-job-loss-by-industry-ipums-update.R", encoding = "UTF-8") # verified, need
source("scripts/update/2v4d-job-loss-by-industry-ipums-summary-update.R", encoding = "UTF-8") # verified, need
#source("scripts/update/3-produce-data-files-update.R", encoding = "UTF-8") # do not need
#source("scripts/update/4-produce-summary-stats-update.R", encoding = "UTF-8") # do not need, just histograms

# stop because you need to review the histograms and confirm legend bounds
#stop() # E.Leo: not producing histograms
# source("scripts/update/5-create-sum-files-update.R", encoding = "UTF-8")
# if (!dryrun) {
#     source("scripts/update/6-transfer-to-s3-update.R", encoding = "UTF-8")
# }

ipums_data_merge <- readRDS(file = "data/processed-data/ipums-data-merge.Rds")
setwd("H:/Documents/Uninsured_by_zip/R Studio/COVID19_Uninsured_Analysis")
saveRDS(ipums_data_merge, file = "data/processed/ipums-data-merge.Rds")
# clear global environment in preparation for COVID Uninsured Analysis
rm(list = ls())
gc()
