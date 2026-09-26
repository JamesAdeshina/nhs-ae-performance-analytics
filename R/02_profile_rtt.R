# NHS A&E Performance Analytics
# 02 - Initial RTT data profiling

library(tidyverse)
library(janitor)
library(lubridate)
library(here)
library(skimr)
library(fs)

# ---------------------------------------------------------
# Locate RTT ZIP source files
# ---------------------------------------------------------

rtt_zip_files <- list.files(
  here("data", "raw", "rtt"),
  pattern = "\\.zip$",
  full.names = TRUE
)

rtt_zip_files


# ---------------------------------------------------------
# Inspect contents of each ZIP file
# ---------------------------------------------------------

rtt_zip_contents <- map_dfr(
  rtt_zip_files,
  ~ {
    zip_info <- unzip(.x, list = TRUE)
    
    tibble(
      source_zip = basename(.x),
      file_name = zip_info$Name,
      file_size = zip_info$Length
    )
  }
)

rtt_zip_contents


# ---------------------------------------------------------
# Create temporary extraction folder
# ---------------------------------------------------------

rtt_temp_dir <- here("data", "raw", "rtt", "_temp_extract")

dir_create(rtt_temp_dir)


# ---------------------------------------------------------
# Extract ZIP files
# ---------------------------------------------------------

walk(
  rtt_zip_files,
  ~ unzip(
    .x,
    exdir = rtt_temp_dir
  )
)


# ---------------------------------------------------------
# Locate extracted CSV files
# ---------------------------------------------------------

rtt_csv_files <- list.files(
  rtt_temp_dir,
  pattern = "\\.csv$",
  full.names = TRUE,
  recursive = TRUE
)

rtt_csv_files


# ---------------------------------------------------------
# Inspect schema of each RTT CSV
# ---------------------------------------------------------

rtt_schema <- map_dfr(
  rtt_csv_files,
  ~ tibble(
    file = basename(.x),
    column_name = names(
      read_csv(
        .x,
        n_max = 0,
        show_col_types = FALSE
      )
    )
  )
)

rtt_schema


# ---------------------------------------------------------
# Count columns in each CSV
# ---------------------------------------------------------

rtt_column_counts <- map_dfr(
  rtt_csv_files,
  ~ tibble(
    file = basename(.x),
    column_count = ncol(
      read_csv(
        .x,
        n_max = 0,
        show_col_types = FALSE
      )
    )
  )
)

rtt_column_counts


# ---------------------------------------------------------
# Check schema consistency across files
# ---------------------------------------------------------

rtt_schema_check <- rtt_schema %>%
  count(
    column_name,
    name = "files_present"
  ) %>%
  arrange(
    files_present,
    column_name
  )

rtt_schema_check


# ---------------------------------------------------------
# Read all RTT CSV files
# ---------------------------------------------------------

rtt_all <- map_dfr(
  rtt_csv_files,
  ~ read_csv(
    .x,
    show_col_types = FALSE
  ) %>%
    mutate(
      source_file = basename(.x)
    )
)

glimpse(rtt_all)


# ---------------------------------------------------------
# Basic dataset size
# ---------------------------------------------------------

rtt_overview <- tibble(
  total_rows = nrow(rtt_all),
  total_columns = ncol(rtt_all),
  source_files = n_distinct(rtt_all$source_file)
)

rtt_overview


# ---------------------------------------------------------
# Inspect column names
# ---------------------------------------------------------

names(rtt_all)


# ---------------------------------------------------------
# Preview records
# ---------------------------------------------------------

rtt_all %>%
  slice_head(n = 10)


# ---------------------------------------------------------
# Clean names ONLY for easier profiling
# This does not create the final cleaned dataset
# ---------------------------------------------------------

rtt_profile <- rtt_all %>%
  clean_names()

names(rtt_profile)


# ---------------------------------------------------------
# Identify likely date / period fields
# ---------------------------------------------------------

possible_period_columns <- names(rtt_profile)[
  str_detect(
    names(rtt_profile),
    regex(
      "period|month|date|report",
      ignore_case = TRUE
    )
  )
]

possible_period_columns


# ---------------------------------------------------------
# Identify likely provider fields
# ---------------------------------------------------------

possible_provider_columns <- names(rtt_profile)[
  str_detect(
    names(rtt_profile),
    regex(
      "provider|org|organisation|trust",
      ignore_case = TRUE
    )
  )
]

possible_provider_columns


# ---------------------------------------------------------
# Identify likely specialty / treatment-function fields
# ---------------------------------------------------------

possible_specialty_columns <- names(rtt_profile)[
  str_detect(
    names(rtt_profile),
    regex(
      "specialty|speciality|treatment|function",
      ignore_case = TRUE
    )
  )
]

possible_specialty_columns


# ---------------------------------------------------------
# Identify likely waiting-time / pathway fields
# ---------------------------------------------------------

possible_wait_columns <- names(rtt_profile)[
  str_detect(
    names(rtt_profile),
    regex(
      "wait|week|pathway|incomplete|18|52|65|78",
      ignore_case = TRUE
    )
  )
]

possible_wait_columns


# ---------------------------------------------------------
# Missing-value profile
# ---------------------------------------------------------

rtt_missing_profile <- rtt_profile %>%
  summarise(
    across(
      everything(),
      ~ sum(is.na(.))
    )
  ) %>%
  pivot_longer(
    everything(),
    names_to = "column_name",
    values_to = "missing_count"
  ) %>%
  mutate(
    missing_pct = round(
      missing_count / nrow(rtt_profile) * 100,
      2
    )
  ) %>%
  arrange(
    desc(missing_count)
  )

rtt_missing_profile


# ---------------------------------------------------------
# Data type profile
# ---------------------------------------------------------

rtt_type_profile <- tibble(
  column_name = names(rtt_profile),
  data_type = map_chr(
    rtt_profile,
    ~ class(.x)[1]
  )
)

rtt_type_profile


# ---------------------------------------------------------
# Numeric range profile
# ---------------------------------------------------------

rtt_numeric_profile <- rtt_profile %>%
  select(
    where(is.numeric)
  ) %>%
  summarise(
    across(
      everything(),
      list(
        min = ~ min(.x, na.rm = TRUE),
        max = ~ max(.x, na.rm = TRUE),
        zero_count = ~ sum(.x == 0, na.rm = TRUE),
        negative_count = ~ sum(.x < 0, na.rm = TRUE)
      )
    )
  ) %>%
  pivot_longer(
    everything(),
    names_to = c("metric", ".value"),
    names_pattern = "^(.*)_(min|max|zero_count|negative_count)$"
  )

rtt_numeric_profile


# ---------------------------------------------------------
# Count rows by source file
# ---------------------------------------------------------

rtt_rows_by_file <- rtt_profile %>%
  count(
    source_file,
    name = "rows"
  )

rtt_rows_by_file


# ---------------------------------------------------------
# Distinct-value counts for character columns
# ---------------------------------------------------------

rtt_character_profile <- rtt_profile %>%
  select(
    where(is.character)
  ) %>%
  summarise(
    across(
      everything(),
      n_distinct
    )
  ) %>%
  pivot_longer(
    everything(),
    names_to = "column_name",
    values_to = "distinct_values"
  ) %>%
  arrange(
    desc(distinct_values)
  )

rtt_character_profile


# ---------------------------------------------------------
# Search for obvious TOTAL / aggregate rows
# ---------------------------------------------------------

rtt_total_candidates <- rtt_profile %>%
  filter(
    if_any(
      where(is.character),
      ~ str_to_upper(.x) == "TOTAL"
    )
  )

rtt_total_candidates


# ---------------------------------------------------------
# Duplicate-row check across full row content
# ---------------------------------------------------------

rtt_exact_duplicates <- rtt_profile %>%
  duplicated() %>%
  sum()

rtt_exact_duplicates


# ---------------------------------------------------------
# Save profiling outputs
# ---------------------------------------------------------

dir_create(
  here("outputs", "data_quality")
)

write_csv(
  rtt_column_counts,
  here(
    "outputs",
    "data_quality",
    "rtt_column_counts.csv"
  )
)

write_csv(
  rtt_schema_check,
  here(
    "outputs",
    "data_quality",
    "rtt_schema_check.csv"
  )
)

write_csv(
  rtt_missing_profile,
  here(
    "outputs",
    "data_quality",
    "rtt_missing_profile.csv"
  )
)

write_csv(
  rtt_type_profile,
  here(
    "outputs",
    "data_quality",
    "rtt_type_profile.csv"
  )
)

write_csv(
  rtt_numeric_profile,
  here(
    "outputs",
    "data_quality",
    "rtt_numeric_profile.csv"
  )
)

write_csv(
  rtt_rows_by_file,
  here(
    "outputs",
    "data_quality",
    "rtt_rows_by_file.csv"
  )
)

write_csv(
  rtt_character_profile,
  here(
    "outputs",
    "data_quality",
    "rtt_character_profile.csv"
  )
)


# ---------------------------------------------------------
# Final console summary
# ---------------------------------------------------------

cat("\n")
cat("========================================\n")
cat("RTT INITIAL PROFILING COMPLETE\n")
cat("========================================\n")
cat("ZIP files found: ", length(rtt_zip_files), "\n")
cat("CSV files found: ", length(rtt_csv_files), "\n")
cat("Combined rows: ", nrow(rtt_profile), "\n")
cat("Combined columns: ", ncol(rtt_profile), "\n")
cat("Exact duplicate rows: ", rtt_exact_duplicates, "\n")
cat("========================================\n")





rtt_profile %>%
  count(
    rtt_part_type,
    rtt_part_description,
    sort = TRUE
  )

rtt_profile %>%
  group_by(
    rtt_part_type,
    rtt_part_description
  ) %>%
  summarise(
    rows = n(),
    non_missing_total_all = sum(!is.na(total_all)),
    total_all_sum = sum(total_all, na.rm = TRUE),
    .groups = "drop"
  )




rtt_profile %>%
  count(
    treatment_function_code,
    treatment_function_name,
    sort = TRUE
  )



