# NHS A&E Performance Analytics
# 05 - Build analytical model dimensions

library(tidyverse)
library(lubridate)
library(here)

# ---------------------------------------------------------
# Load processed fact tables
# ---------------------------------------------------------

fact_ae <- read_csv(
  here("data", "processed", "fact_ae.csv"),
  show_col_types = FALSE
)

fact_rtt_provider <- read_csv(
  here("data", "processed", "fact_rtt_provider.csv"),
  show_col_types = FALSE
)

fact_rtt_specialty <- read_csv(
  here("data", "processed", "fact_rtt_specialty.csv"),
  show_col_types = FALSE
)

# ---------------------------------------------------------
# Ensure reporting dates are parsed correctly
# ---------------------------------------------------------

fact_ae <- fact_ae %>%
  mutate(
    report_month = as.Date(report_month)
  )

fact_rtt_provider <- fact_rtt_provider %>%
  mutate(
    report_month = as.Date(report_month)
  )

fact_rtt_specialty <- fact_rtt_specialty %>%
  mutate(
    report_month = as.Date(report_month)
  )

# ---------------------------------------------------------
# Build date dimension
# ---------------------------------------------------------

min_report_month <- min(
  c(
    fact_ae$report_month,
    fact_rtt_provider$report_month,
    fact_rtt_specialty$report_month
  ),
  na.rm = TRUE
)

max_report_month <- max(
  c(
    fact_ae$report_month,
    fact_rtt_provider$report_month,
    fact_rtt_specialty$report_month
  ),
  na.rm = TRUE
)

dim_date <- tibble(
  report_month = seq(
    from = floor_date(min_report_month, "month"),
    to = floor_date(max_report_month, "month"),
    by = "month"
  )
) %>%
  mutate(
    year = year(report_month),
    month_number = month(report_month),
    month_name = month(
      report_month,
      label = TRUE,
      abbr = FALSE
    ),
    month_short = month(
      report_month,
      label = TRUE,
      abbr = TRUE
    ),
    year_month = format(
      report_month,
      "%Y-%m"
    ),
    month_year_label = format(
      report_month,
      "%b %Y"
    ),
    quarter = paste0(
      "Q",
      quarter(report_month)
    ),
    year_quarter = paste0(
      year(report_month),
      " Q",
      quarter(report_month)
    )
  )

# ---------------------------------------------------------
# Build provider dimension
# ---------------------------------------------------------

ae_providers <- fact_ae %>%
  transmute(
    provider_code,
    provider_name,
    provider_parent_code = NA_character_,
    provider_parent_name = region,
    source_system = "A&E"
  )

rtt_providers <- fact_rtt_provider %>%
  transmute(
    provider_code = provider_org_code,
    provider_name = provider_org_name,
    provider_parent_code = provider_parent_org_code,
    provider_parent_name = provider_parent_name,
    source_system = "RTT"
  )

provider_history <- bind_rows(
  ae_providers,
  rtt_providers
)

# ---------------------------------------------------------
# Identify providers with multiple names
# ---------------------------------------------------------

provider_name_changes <- provider_history %>%
  distinct(
    provider_code,
    provider_name
  ) %>%
  count(
    provider_code,
    name = "name_count"
  ) %>%
  filter(
    name_count > 1
  )

provider_name_changes

# ---------------------------------------------------------
# Build canonical provider dimension
# ---------------------------------------------------------

dim_provider <- provider_history %>%
  filter(
    !is.na(provider_code),
    provider_code != ""
  ) %>%
  group_by(
    provider_code
  ) %>%
  summarise(
    provider_name = last(
      na.omit(provider_name)
    ),
    
    provider_parent_code = first(
      na.omit(provider_parent_code),
      default = NA_character_
    ),
    
    provider_parent_name = last(
      na.omit(provider_parent_name)
    ),
    
    appears_in_ae = any(
      source_system == "A&E"
    ),
    
    appears_in_rtt = any(
      source_system == "RTT"
    ),
    
    .groups = "drop"
  )

# ---------------------------------------------------------
# Build specialty dimension
# ---------------------------------------------------------

dim_specialty <- fact_rtt_specialty %>%
  distinct(
    treatment_function_code,
    treatment_function_name
  ) %>%
  filter(
    !is.na(treatment_function_code),
    treatment_function_code != ""
  ) %>%
  arrange(
    treatment_function_name
  )

# ---------------------------------------------------------
# Validation checks
# ---------------------------------------------------------

date_duplicates <- dim_date %>%
  count(report_month) %>%
  filter(n > 1)

provider_duplicates <- dim_provider %>%
  count(provider_code) %>%
  filter(n > 1)

specialty_duplicates <- dim_specialty %>%
  count(treatment_function_code) %>%
  filter(n > 1)

cat(
  "Date dimension rows:",
  nrow(dim_date),
  "\n"
)

cat(
  "Provider dimension rows:",
  nrow(dim_provider),
  "\n"
)

cat(
  "Specialty dimension rows:",
  nrow(dim_specialty),
  "\n"
)

cat(
  "Date duplicate keys:",
  nrow(date_duplicates),
  "\n"
)

cat(
  "Provider duplicate keys:",
  nrow(provider_duplicates),
  "\n"
)

cat(
  "Specialty duplicate keys:",
  nrow(specialty_duplicates),
  "\n"
)

# ---------------------------------------------------------
# Export dimensions
# ---------------------------------------------------------

write_csv(
  dim_date,
  here("data", "processed", "dim_date.csv")
)

write_csv(
  dim_provider,
  here("data", "processed", "dim_provider.csv")
)

write_csv(
  dim_specialty,
  here("data", "processed", "dim_specialty.csv")
)

# ---------------------------------------------------------
# Confirm exports
# ---------------------------------------------------------

cat(
  "dim_date exported:",
  file.exists(
    here("data", "processed", "dim_date.csv")
  ),
  "\n"
)

cat(
  "dim_provider exported:",
  file.exists(
    here("data", "processed", "dim_provider.csv")
  ),
  "\n"
)

cat(
  "dim_specialty exported:",
  file.exists(
    here("data", "processed", "dim_specialty.csv")
  ),
  "\n"
)