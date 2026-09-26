# NHS A&E Performance Analytics
# 04 - Clean and transform RTT data

library(tidyverse)
library(janitor)
library(lubridate)
library(here)
library(fs)

# ---------------------------------------------------------
# Locate and extract RTT source files
# ---------------------------------------------------------

rtt_zip_files <- list.files(
  here("data", "raw", "rtt"),
  pattern = "\\.zip$",
  full.names = TRUE
)

rtt_temp_dir <- here(
  "data",
  "raw",
  "rtt",
  "_temp_extract"
)

dir_create(rtt_temp_dir)

walk(
  rtt_zip_files,
  ~ unzip(
    .x,
    exdir = rtt_temp_dir
  )
)

rtt_csv_files <- list.files(
  rtt_temp_dir,
  pattern = "\\.csv$",
  full.names = TRUE,
  recursive = TRUE
)

# ---------------------------------------------------------
# Read and combine source files
# ---------------------------------------------------------

rtt_raw <- map_dfr(
  rtt_csv_files,
  ~ read_csv(
    .x,
    show_col_types = FALSE
  ) %>%
    mutate(
      source_file = basename(.x)
    )
)

rtt_clean <- rtt_raw %>%
  clean_names()

# ---------------------------------------------------------
# Parse reporting month
# ---------------------------------------------------------

rtt_clean <- rtt_clean %>%
  mutate(
    report_month = str_remove(period, "^RTT-"),
    report_month = my(report_month),
    report_month = floor_date(report_month, "month")
  )

# ---------------------------------------------------------
# Keep incomplete RTT pathways only
# ---------------------------------------------------------

rtt_incomplete <- rtt_clean %>%
  filter(
    rtt_part_type == "Part_2"
  )

# ---------------------------------------------------------
# Identify weekly waiting-time columns
# ---------------------------------------------------------

week_columns <- names(rtt_incomplete)[
  str_detect(
    names(rtt_incomplete),
    "^gt_.*weeks_sum_1$"
  )
]

week_columns


# ---------------------------------------------------------
# Create week-band lookup table
# RTT = Referral to Treatment
# ---------------------------------------------------------

get_week_start <- function(column_name) {
  value <- str_extract(
    column_name,
    "(?<=gt_)\\d+"
  )
  
  as.integer(value)
}

week_band_lookup <- tibble(
  column_name = week_columns,
  week_start = map_int(
    week_columns,
    get_week_start
  )
)

week_band_lookup


# ---------------------------------------------------------
# Define waiting-time threshold groups
# ---------------------------------------------------------

within_18_columns <- week_band_lookup %>%
  filter(week_start < 18) %>%
  pull(column_name)

over_18_columns <- week_band_lookup %>%
  filter(week_start >= 18) %>%
  pull(column_name)

over_52_columns <- week_band_lookup %>%
  filter(week_start >= 52) %>%
  pull(column_name)

over_65_columns <- week_band_lookup %>%
  filter(week_start >= 65) %>%
  pull(column_name)

over_78_columns <- week_band_lookup %>%
  filter(week_start >= 78) %>%
  pull(column_name)

over_104_columns <- week_band_lookup %>%
  filter(week_start >= 104) %>%
  pull(column_name)


# ---------------------------------------------------------
# Derive RTT backlog measures
# ---------------------------------------------------------

rtt_incomplete <- rtt_incomplete %>%
  mutate(
    within_18_weeks =
      rowSums(
        across(
          all_of(within_18_columns)
        ),
        na.rm = TRUE
      ),
    
    over_18_weeks =
      rowSums(
        across(
          all_of(over_18_columns)
        ),
        na.rm = TRUE
      ),
    
    over_52_weeks =
      rowSums(
        across(
          all_of(over_52_columns)
        ),
        na.rm = TRUE
      ),
    
    over_65_weeks =
      rowSums(
        across(
          all_of(over_65_columns)
        ),
        na.rm = TRUE
      ),
    
    over_78_weeks =
      rowSums(
        across(
          all_of(over_78_columns)
        ),
        na.rm = TRUE
      ),
    
    over_104_weeks =
      rowSums(
        across(
          all_of(over_104_columns)
        ),
        na.rm = TRUE
      ),
    
    within_18_weeks_pct =
      if_else(
        total_all > 0,
        within_18_weeks / total_all,
        NA_real_
      )
  )


# ---------------------------------------------------------
# Validate derived RTT measures
# ---------------------------------------------------------

rtt_validation <- rtt_incomplete %>%
  summarise(
    rows = n(),
    
    total_matches_week_bands =
      sum(
        within_18_weeks + over_18_weeks == total_all,
        na.rm = TRUE
      ),
    
    total_mismatches =
      sum(
        within_18_weeks + over_18_weeks != total_all,
        na.rm = TRUE
      ),
    
    min_within_18_pct =
      min(
        within_18_weeks_pct,
        na.rm = TRUE
      ),
    
    max_within_18_pct =
      max(
        within_18_weeks_pct,
        na.rm = TRUE
      )
  )

rtt_validation