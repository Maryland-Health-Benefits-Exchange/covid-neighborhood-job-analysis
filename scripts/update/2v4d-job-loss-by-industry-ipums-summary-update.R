# Using the State by IND job loss estimates from 2v4c, merge with 
# 2014-18 ACS and disemploy people based on job loss estimates and
# random number generator. Produce a file with disemployment flag
# for public release. Summarize job loss by 2-digit NAICS by PUMA and
# write out for next step.
# E.Leo update: remove wage limits and specify MD totals for PUMA


library(tidyverse)
library(testit)
library(ipumsr)


generate_acs_percent_change_by_industry = function(start_month_bls = 2,
           # remember to copy ACS files into this directory
  # for 1-year:
  start_year_bls = 2020, acs_ipums_path = "data/raw-data/big/usa_00025.xml",
  # for 5-year:
  # start_year_bls = 2020, acs_ipums_path = "data/raw-data/big/usa_00024.xml",
  acs_estimates_path = "data/processed-data/job_change_acs_estimates_most_recent.csv",
  # for 1-year:
  latest_year = 2020, latest_month = 6, ipums_vintage = "2018"){
  # for 5-year:
   #latest_year = 2020, latest_month = 6, ipums_vintage = "2013-18"){
  
  # Function to generate ACS job change by industry
  # INPUT:
  #   start_month_bls: BLS month to use as baseline to measure job loss % change
  #   start_year_bls: BLS year to use as baseline to measure job loss % change
  #   acs_ipums_path: path to DDI file from IPUMS (data file should be in same directory)
  #   acs_estimates_path: path to state by IND estimates from 2v4c
  #   latest_year: latest year from 2v4b
  #   latest_month: latest month from 2v4b
  #   ipums_vintage: The IPUMS vintage years used for the analysis
  # OUTPUT:
  # job_change_led: a dataframe, where every row is a unique PUMA and 2-digit
  #   NAICS industry. This dataframe is the measure % change in net employment 
  #   for each PUMA-NAICS in relation to the start month and year for people earning
  #   less than $40,000 per year in wages, in 2018 inflation adjusted dollars
  
  
  # Read in estimates and crosswalk data
  ddi <- read_ipums_ddi(acs_ipums_path)
  ipums_data <- read_ipums_micro(ddi)
  acs_estimates <- read_csv(acs_estimates_path)
  acs_estimates$state <- as.character(acs_estimates$state)
  
  ## Merge and disemploy -----------------------------------------------------

  # Set seed
  set.seed(20200525)
  
  # Merge and generate disemployment flag, only if person is currently employed
  ipums_data_merge <- ipums_data %>%
    mutate(IND = str_pad(as.character(IND), 4, side = "left", pad = "0"),
           state = str_pad(as.character(STATEFIP), 2, side = "left", pad = "0"),
           puma = str_pad(as.character(PUMA), 5, side = "left", pad = "0")) %>%
    left_join(acs_estimates, by = c("IND", "state")) %>%
    mutate(percent_change_state_imputed = replace_na(percent_change_state_imputed, 0),
           random_number = runif(n()),
           disemploy = ifelse((random_number < (1 + percent_change_state_imputed)) | EMPSTAT != 1,
                              0, 1),
           # wage_level = ifelse(INCWAGE < 40000, 1, 0), commented to remove wage limit
           is_employed = ifelse(EMPSTAT == 1, 1, 0),
           total_employment = PERWT * is_employed,
           total_disemployment = -total_employment * percent_change_state_imputed)
  
  # Prep for public writeout
  saveRDS(ipums_data_merge, file = "data/processed-data/ipums-data-merge.Rds")
  disemploy_file_public <- ipums_data_merge %>%
    # E.Leo: for 1-year file
     select(YEAR, SERIAL, PERNUM, percent_change_state_imputed,
            random_number, disemploy)
  # E.Leo: for 5-year file
  #select(YEAR, MULTYEAR, SERIAL, PERNUM, percent_change_state_imputed,
    #     random_number, disemploy)
  
  # Checks against national data here
  net_employment <- sum(ipums_data_merge$total_employment)
  print(str_glue("Net employment is {net_employment}"))
  net_disemployment <- round(sum(ipums_data_merge$total_disemployment))
  print(str_glue("Net disemployment is {net_disemployment}"))
  # net_li_employment <- ipums_data_merge %>%  commented to remove wage limit
    # filter(wage_level == 1) %>%
    # summarise(sum(total_employment)) %>% 
  #  pull()
  # print(str_glue("Net <$40k employment is {net_li_employment}"))
  # net_li_disemployment <- ipums_data_merge %>% 
    # filter(wage_level == 1) %>% 
  #  summarise(sum(total_disemployment)) %>% 
  #  pull() %>%
  #  round()
  # print(str_glue("Net <$40k disemployment is {net_li_disemployment}"))
  
  # Get IPUMS estimates by 2-digit NAICS by PUMA
  ipums_estimates <- ipums_data_merge %>%
    # AN: This filter condition causes some PUMA-industry combinations to have 0
    # individuals, meaning those PUMA-industry combinations disappear from our
    # estimates. To fill in these gaps, we use the  statewide industry job loss
    # percentages for that particular missing industry
    # filter(wage_level == 1) %>% commented to remove wage limit
    group_by(state, puma, led_code) %>%
    summarise(total_employed_pre = sum(total_employment),
              total_unemployed_post = sum(total_disemployment)) %>%
    ungroup() %>%
    mutate(percent_change_imputed = ifelse(total_employed_pre == 0,
                                           0,
                                           -total_unemployed_post / total_employed_pre)) %>%
    filter(!is.na(led_code))

    assert("IPUMS extract has all PUMA's in Maryland", # changed "the continental US" to MD
      ipums_estimates %>% select(state, puma) %>% distinct() %>% nrow() == 44)
  
  # Get IPUMS estimates by 2-digit NAICS by State
  ipums_state_estimates <- ipums_data_merge %>% 
    # filter(wage_level == 1) %>% commented to remove wage limit
    group_by(state, led_code) %>%
    summarise(total_employed_pre = sum(total_employment),
              total_unemployed_post = sum(total_disemployment)) %>%
    ungroup() %>%
    mutate(percent_change_imputed = ifelse(total_employed_pre == 0,
                                           0,
                                           -total_unemployed_post / total_employed_pre)) %>%
    filter(!is.na(led_code))

  # Get list of all puma industry combinations (44 pumas * 24 industries)
  all_puma_industry_combinations <- ipums_estimates %>% 
    select(state, puma) %>%
    distinct() %>% 
    expand_grid(led_code = ipums_estimates %>% pull(led_code) %>% unique()) %>% 
    # NA is seen as a unique value for led_code, so we just drop those rows
    drop_na()

  assert("Expanded puma-industry list has right number of combinations",
        nrow(all_puma_industry_combinations) == 1056)



  # Get missing puma_industry combination and substitute in their
  # state-industry values 
  missing_puma_industry_combos <- all_puma_industry_combinations %>% 
      # check which puma-industry combinations which are missing 
      anti_join(ipums_estimates, by = c("state", "puma", "led_code")) %>% 
      left_join(ipums_state_estimates, by = c("state", "led_code")) %>% 
      mutate(state_imputation = 1)

  # Get existimg puma_industry combinations and use their real values
  existing_puma_industry_combos <- all_puma_industry_combinations %>% 
      inner_join(ipums_estimates, by = c("state", "puma", "led_code"))  %>% 
      mutate(state_imputation = 0)


  # Bind existing and imputed puma-industry combinations together
  ipums_puma_estimates <- bind_rows(existing_puma_industry_combos, 
  missing_puma_industry_combos)

  assert("All rows in puma-industry job loss file are unique ", 
        ipums_puma_estimates %>%
          distinct(state, puma, led_code) %>%
          nrow() == 1056)

  assert("Final puma-industry job loss file has rows for every puma-industry 
          combination in the MD", # changed US to MD
          nrow(all_puma_industry_combinations) == nrow(ipums_puma_estimates))

  # Potential opportunity to calculate MOE with file on next release
  
  ##----Write out data------------------------------------------------
  
  # Write out disemployment file for public use with latest month and year
  
  # Create ipums subdirectory if it doesn't exist
  dir.create("data/processed-data/ipums/", showWarnings = FALSE)

  disemploy_file_public %>%
    write_csv(
      str_glue("data/processed-data/ipums/ipums_{ipums_vintage}_disemployment_{start_year_bls}_{start_month_bls}_to_{latest_year}_{latest_month}.csv")
    )

  # Write out disemployment file for public use most recent
  disemploy_file_public %>%
    write_csv(
      str_glue("data/processed-data/ipums/ipums_{ipums_vintage}_disemployment_most_recent.csv")
    )
  
  # Write out full file for analysis, for those interested. Don't need this in 
  # production pipeline, though, so commented out
   ipums_data_merge %>%
     write_csv("data/processed-data/ipums/ipums_data_full_latest.csv")
  
  # Write out job change csv specific to latest month and year
  ipums_puma_estimates %>%
    write_csv(
      str_glue("data/processed-data/job_change_ipums_estimates_{start_year_bls}_{start_month_bls}_to_{latest_year}_{latest_month}.csv")
    )
  
  # Replace most recent bls job change csv
  ipums_puma_estimates %>%
    write_csv("data/processed-data/job_change_ipums_estimates_most_recent.csv")
  
  return(ipums_puma_estimates)
}


ipums_puma_estimates = generate_acs_percent_change_by_industry()
