# NHS A&E Performance Analytics
# 01 - Initial A&E data profiling

library(tidyverse)
library(janitor)
library(lubridate)
library(here)
library(skimr)
library(fs)


# Locate raw A&E CSV files
ae_files <- list.files(
  here("data", "raw", "ae"),
  pattern = "\\.csv$",
  full.names = TRUE
)

ae_files

# Read latest A&E file for initial schema inspection
ae_aug <- read_csv(
  here("data", "raw", "ae", "ae_2026_08.csv"),
  show_col_types = FALSE
)

# Inspect structure
glimpse(ae_aug)

# Inspect column names
names(ae_aug)

# Preview first rows
head(ae_aug)


# ---------------------------------------------------------
# Compare schemas across all A&E monthly files
# ---------------------------------------------------------

ae_schema <- map_dfr(
  ae_files,
  ~ tibble(
    file = basename(.x),
    column_name = names(read_csv(.x, n_max = 0, show_col_types = FALSE))
  )
)

ae_schema


# Count number of columns in each file
ae_column_counts <- map_dfr(
  ae_files,
  ~ tibble(
    file = basename(.x),
    column_count = ncol(read_csv(.x, n_max = 0, show_col_types = FALSE))
  )
)

ae_column_counts

# Check whether all five files have identical column names
schema_check <- ae_schema %>%
  count(column_name, name = "months_present") %>%
  arrange(months_present, column_name)

schema_check


# ---------------------------------------------------------
# Read all A&E files
# ---------------------------------------------------------

ae_all <- map_dfr(
  ae_files,
  ~ read_csv(.x, show_col_types = FALSE) %>%
    mutate(source_file = basename(.x))
)

glimpse(ae_all)


# Row count by reporting period
ae_all %>%
  count(Period)


# Duplicate provider/month combinations
duplicate_check <- ae_all %>%
  count(Period, `Org Code`) %>%
  filter(n > 1)

duplicate_check


# Provider count by reporting period
ae_all %>%
  group_by(Period) %>%
  summarise(
    rows = n(),
    distinct_org_codes = n_distinct(`Org Code`),
    .groups = "drop"
  )


# Check whether one provider code maps to multiple names
provider_name_check <- ae_all %>%
  distinct(`Org Code`, `Org name`) %>%
  count(`Org Code`, name = "name_count") %>%
  filter(name_count > 1)

provider_name_check

# ---------------------------------------------------------
# Inspect aggregate / total rows embedded in source files
# ---------------------------------------------------------

total_rows <- ae_all %>%
  filter(str_to_upper(Period) == "TOTAL")

total_rows %>%
  select(
    source_file,
    Period,
    `Org Code`,
    `Parent Org`,
    `Org name`
  )


# ---------------------------------------------------------
# Inspect provider-name changes
# ---------------------------------------------------------

ae_all %>%
  filter(`Org Code` %in% c("RA7", "RXG")) %>%
  select(
    source_file,
    Period,
    `Org Code`,
    `Org name`,
    `Parent Org`
  ) %>%
  arrange(`Org Code`, source_file)



# ---------------------------------------------------------
# Provider-level records only for profiling
# ---------------------------------------------------------

ae_provider_raw <- ae_all %>%
  filter(str_to_upper(Period) != "TOTAL")


ae_provider_raw %>%
  group_by(Period) %>%
  summarise(
    rows = n(),
    distinct_org_codes = n_distinct(`Org Code`),
    .groups = "drop"
  )


duplicate_check_provider <- ae_provider_raw %>%
  count(Period, `Org Code`) %>%
  filter(n > 1)

duplicate_check_provider


# ---------------------------------------------------------
# Missing-value profile
# ---------------------------------------------------------

missing_profile <- ae_provider_raw %>%
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
      missing_count / nrow(ae_provider_raw) * 100,
      2
    )
  ) %>%
  arrange(desc(missing_count))

missing_profile



# ---------------------------------------------------------
# Validate provider sums against published TOTAL rows
# ---------------------------------------------------------

# Numeric columns only
numeric_columns <- ae_provider_raw %>%
  select(where(is.numeric)) %>%
  names()

# Provider-level totals by source file
provider_totals <- ae_provider_raw %>%
  group_by(source_file) %>%
  summarise(
    across(
      all_of(numeric_columns),
      ~ sum(.x, na.rm = TRUE)
    ),
    .groups = "drop"
  )

# Published TOTAL rows
published_totals <- total_rows %>%
  select(
    source_file,
    all_of(numeric_columns)
  )




validation_totals <- provider_totals %>%
  pivot_longer(
    -source_file,
    names_to = "metric",
    values_to = "calculated_total"
  ) %>%
  left_join(
    published_totals %>%
      pivot_longer(
        -source_file,
        names_to = "metric",
        values_to = "published_total"
      ),
    by = c("source_file", "metric")
  ) %>%
  mutate(
    difference = calculated_total - published_total,
    matches = difference == 0
  )


validation_totals %>%
  count(matches)


validation_totals %>%
  filter(!matches)





# ---------------------------------------------------------
# Numeric range profile
# ---------------------------------------------------------

numeric_profile <- ae_provider_raw %>%
  summarise(
    across(
      where(is.numeric),
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

numeric_profile






















































