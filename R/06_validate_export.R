# NHS A&E Performance Analytics
# 06 - Final validation and export QA
#
# A&E = Accident and Emergency
# RTT = Referral to Treatment
# KPI = Key Performance Indicator
# QA = Quality Assurance

library(tidyverse)
library(here)
library(lubridate)

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
# Load dimensions
# ---------------------------------------------------------

dim_date <- read_csv(
  here("data", "processed", "dim_date.csv"),
  show_col_types = FALSE
)

dim_provider <- read_csv(
  here("data", "processed", "dim_provider.csv"),
  show_col_types = FALSE
)

dim_specialty <- read_csv(
  here("data", "processed", "dim_specialty.csv"),
  show_col_types = FALSE
)

# ---------------------------------------------------------
# Standardise date types
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

dim_date <- dim_date %>%
  mutate(
    report_month = as.Date(report_month)
  )

# ---------------------------------------------------------
# Basic row counts
# ---------------------------------------------------------

row_counts <- tibble(
  table_name = c(
    "fact_ae",
    "fact_rtt_provider",
    "fact_rtt_specialty",
    "dim_date",
    "dim_provider",
    "dim_specialty"
  ),
  row_count = c(
    nrow(fact_ae),
    nrow(fact_rtt_provider),
    nrow(fact_rtt_specialty),
    nrow(dim_date),
    nrow(dim_provider),
    nrow(dim_specialty)
  )
)

row_counts

# ---------------------------------------------------------
# Validate fact-table grain
# ---------------------------------------------------------

ae_duplicates <- fact_ae %>%
  count(
    report_month,
    provider_code
  ) %>%
  filter(n > 1)

rtt_provider_duplicates <- fact_rtt_provider %>%
  count(
    report_month,
    provider_org_code
  ) %>%
  filter(n > 1)

rtt_specialty_duplicates <- fact_rtt_specialty %>%
  count(
    report_month,
    provider_org_code,
    treatment_function_code
  ) %>%
  filter(n > 1)

# ---------------------------------------------------------
# Validate dimension keys
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

# ---------------------------------------------------------
# Validate date relationships
# ---------------------------------------------------------

ae_missing_dates <- fact_ae %>%
  anti_join(
    dim_date,
    by = "report_month"
  )

rtt_provider_missing_dates <- fact_rtt_provider %>%
  anti_join(
    dim_date,
    by = "report_month"
  )

rtt_specialty_missing_dates <- fact_rtt_specialty %>%
  anti_join(
    dim_date,
    by = "report_month"
  )

# ---------------------------------------------------------
# Validate provider relationships
# ---------------------------------------------------------

ae_missing_providers <- fact_ae %>%
  anti_join(
    dim_provider,
    by = "provider_code"
  )

rtt_provider_missing_providers <- fact_rtt_provider %>%
  anti_join(
    dim_provider,
    by = c(
      "provider_org_code" = "provider_code"
    )
  )

rtt_specialty_missing_providers <- fact_rtt_specialty %>%
  anti_join(
    dim_provider,
    by = c(
      "provider_org_code" = "provider_code"
    )
  )

# ---------------------------------------------------------
# Validate specialty relationships
# ---------------------------------------------------------

rtt_missing_specialties <- fact_rtt_specialty %>%
  anti_join(
    dim_specialty,
    by = "treatment_function_code"
  )

# ---------------------------------------------------------
# A&E KPI sanity checks
# ---------------------------------------------------------

ae_kpi_validation <- fact_ae %>%
  summarise(
    rows = n(),
    
    negative_total_attendances =
      sum(
        total_attendances < 0,
        na.rm = TRUE
      ),
    
    negative_total_over4 =
      sum(
        total_over4 < 0,
        na.rm = TRUE
      ),
    
    negative_within_4_hours =
      sum(
        within_4_hours < 0,
        na.rm = TRUE
      ),
    
    negative_emergency_admissions =
      sum(
        total_emergency_admissions < 0,
        na.rm = TRUE
      ),
    
    performance_below_zero =
      sum(
        ae_4_hour_performance_pct < 0,
        na.rm = TRUE
      ),
    
    performance_above_one =
      sum(
        ae_4_hour_performance_pct > 1,
        na.rm = TRUE
      )
  )

ae_kpi_validation

# ---------------------------------------------------------
# RTT KPI sanity checks
# RTT = Referral to Treatment
# ---------------------------------------------------------

rtt_provider_kpi_validation <- fact_rtt_provider %>%
  summarise(
    rows = n(),
    
    negative_total_waiting =
      sum(
        total_waiting < 0,
        na.rm = TRUE
      ),
    
    negative_within_18 =
      sum(
        within_18_weeks < 0,
        na.rm = TRUE
      ),
    
    negative_over_18 =
      sum(
        over_18_weeks < 0,
        na.rm = TRUE
      ),
    
    negative_over_52 =
      sum(
        over_52_weeks < 0,
        na.rm = TRUE
      ),
    
    negative_over_65 =
      sum(
        over_65_weeks < 0,
        na.rm = TRUE
      ),
    
    negative_over_78 =
      sum(
        over_78_weeks < 0,
        na.rm = TRUE
      ),
    
    negative_over_104 =
      sum(
        over_104_weeks < 0,
        na.rm = TRUE
      ),
    
    pct_below_zero =
      sum(
        within_18_weeks_pct < 0,
        na.rm = TRUE
      ),
    
    pct_above_one =
      sum(
        within_18_weeks_pct > 1,
        na.rm = TRUE
      ),
    
    reconciliation_mismatches =
      sum(
        within_18_weeks + over_18_weeks != total_waiting,
        na.rm = TRUE
      )
  )

rtt_provider_kpi_validation

# ---------------------------------------------------------
# Validate specialty RTT reconciliation
# ---------------------------------------------------------

rtt_specialty_kpi_validation <- fact_rtt_specialty %>%
  summarise(
    rows = n(),
    
    reconciliation_mismatches =
      sum(
        within_18_weeks + over_18_weeks != total_waiting,
        na.rm = TRUE
      ),
    
    pct_below_zero =
      sum(
        within_18_weeks_pct < 0,
        na.rm = TRUE
      ),
    
    pct_above_one =
      sum(
        within_18_weeks_pct > 1,
        na.rm = TRUE
      )
  )

rtt_specialty_kpi_validation

# ---------------------------------------------------------
# Compare provider totals against summed specialties
# ---------------------------------------------------------

specialty_provider_totals <- fact_rtt_specialty %>%
  group_by(
    report_month,
    provider_org_code
  ) %>%
  summarise(
    specialty_total_waiting =
      sum(
        total_waiting,
        na.rm = TRUE
      ),
    
    specialty_within_18 =
      sum(
        within_18_weeks,
        na.rm = TRUE
      ),
    
    specialty_over_52 =
      sum(
        over_52_weeks,
        na.rm = TRUE
      ),
    
    specialty_over_65 =
      sum(
        over_65_weeks,
        na.rm = TRUE
      ),
    
    specialty_over_78 =
      sum(
        over_78_weeks,
        na.rm = TRUE
      ),
    
    specialty_over_104 =
      sum(
        over_104_weeks,
        na.rm = TRUE
      ),
    
    .groups = "drop"
  )

rtt_provider_reconciliation <- fact_rtt_provider %>%
  select(
    report_month,
    provider_org_code,
    total_waiting,
    within_18_weeks,
    over_52_weeks,
    over_65_weeks,
    over_78_weeks,
    over_104_weeks
  ) %>%
  left_join(
    specialty_provider_totals,
    by = c(
      "report_month",
      "provider_org_code"
    )
  ) %>%
  mutate(
    total_waiting_difference =
      total_waiting - specialty_total_waiting,
    
    within_18_difference =
      within_18_weeks - specialty_within_18,
    
    over_52_difference =
      over_52_weeks - specialty_over_52,
    
    over_65_difference =
      over_65_weeks - specialty_over_65,
    
    over_78_difference =
      over_78_weeks - specialty_over_78,
    
    over_104_difference =
      over_104_weeks - specialty_over_104
  )

# ---------------------------------------------------------
# Summarise reconciliation differences
# ---------------------------------------------------------

rtt_reconciliation_summary <- rtt_provider_reconciliation %>%
  summarise(
    provider_month_rows = n(),
    
    total_waiting_exact_matches =
      sum(
        total_waiting_difference == 0,
        na.rm = TRUE
      ),
    
    total_waiting_mismatches =
      sum(
        total_waiting_difference != 0,
        na.rm = TRUE
      ),
    
    max_absolute_total_difference =
      max(
        abs(total_waiting_difference),
        na.rm = TRUE
      )
  )

rtt_reconciliation_summary

# ---------------------------------------------------------
# Validate processed output files exist
# ---------------------------------------------------------

export_check <- tibble(
  file_name = c(
    "fact_ae.csv",
    "fact_rtt_provider.csv",
    "fact_rtt_specialty.csv",
    "dim_date.csv",
    "dim_provider.csv",
    "dim_specialty.csv"
  ),
  exists = c(
    file.exists(
      here("data", "processed", "fact_ae.csv")
    ),
    file.exists(
      here("data", "processed", "fact_rtt_provider.csv")
    ),
    file.exists(
      here("data", "processed", "fact_rtt_specialty.csv")
    ),
    file.exists(
      here("data", "processed", "dim_date.csv")
    ),
    file.exists(
      here("data", "processed", "dim_provider.csv")
    ),
    file.exists(
      here("data", "processed", "dim_specialty.csv")
    )
  )
)

export_check

# ---------------------------------------------------------
# Build final QA summary
# QA = Quality Assurance
# ---------------------------------------------------------

qa_summary <- tibble(
  check = c(
    "A&E fact duplicate keys",
    "RTT provider fact duplicate keys",
    "RTT specialty fact duplicate keys",
    "Date dimension duplicate keys",
    "Provider dimension duplicate keys",
    "Specialty dimension duplicate keys",
    "A&E missing date keys",
    "RTT provider missing date keys",
    "RTT specialty missing date keys",
    "A&E missing provider keys",
    "RTT provider missing provider keys",
    "RTT specialty missing provider keys",
    "RTT missing specialty keys",
    "A&E performance below 0",
    "A&E performance above 1",
    "RTT provider reconciliation mismatches",
    "RTT specialty reconciliation mismatches",
    "RTT provider percentage below 0",
    "RTT provider percentage above 1",
    "RTT specialty percentage below 0",
    "RTT specialty percentage above 1"
  ),
  
  issue_count = c(
    nrow(ae_duplicates),
    nrow(rtt_provider_duplicates),
    nrow(rtt_specialty_duplicates),
    nrow(date_duplicates),
    nrow(provider_duplicates),
    nrow(specialty_duplicates),
    nrow(ae_missing_dates),
    nrow(rtt_provider_missing_dates),
    nrow(rtt_specialty_missing_dates),
    nrow(ae_missing_providers),
    nrow(rtt_provider_missing_providers),
    nrow(rtt_specialty_missing_providers),
    nrow(rtt_missing_specialties),
    ae_kpi_validation$performance_below_zero,
    ae_kpi_validation$performance_above_one,
    rtt_provider_kpi_validation$reconciliation_mismatches,
    rtt_specialty_kpi_validation$reconciliation_mismatches,
    rtt_provider_kpi_validation$pct_below_zero,
    rtt_provider_kpi_validation$pct_above_one,
    rtt_specialty_kpi_validation$pct_below_zero,
    rtt_specialty_kpi_validation$pct_above_one
  )
) %>%
  mutate(
    status = if_else(
      issue_count == 0,
      "PASS",
      "REVIEW"
    )
  )

qa_summary

# ---------------------------------------------------------
# Create QA output folder
# ---------------------------------------------------------

dir.create(
  here("outputs", "validation"),
  recursive = TRUE,
  showWarnings = FALSE
)

# ---------------------------------------------------------
# Export QA results
# ---------------------------------------------------------

write_csv(
  row_counts,
  here(
    "outputs",
    "validation",
    "model_row_counts.csv"
  )
)

write_csv(
  qa_summary,
  here(
    "outputs",
    "validation",
    "qa_summary.csv"
  )
)

write_csv(
  rtt_provider_reconciliation,
  here(
    "outputs",
    "validation",
    "rtt_provider_specialty_reconciliation.csv"
  )
)

write_csv(
  rtt_reconciliation_summary,
  here(
    "outputs",
    "validation",
    "rtt_reconciliation_summary.csv"
  )
)

write_csv(
  export_check,
  here(
    "outputs",
    "validation",
    "export_check.csv"
  )
)

# ---------------------------------------------------------
# Final console summary
# ---------------------------------------------------------

cat("\n")
cat("========================================\n")
cat("FINAL MODEL VALIDATION COMPLETE\n")
cat("========================================\n")

cat(
  "A&E fact rows:",
  nrow(fact_ae),
  "\n"
)

cat(
  "RTT provider fact rows:",
  nrow(fact_rtt_provider),
  "\n"
)

cat(
  "RTT specialty fact rows:",
  nrow(fact_rtt_specialty),
  "\n"
)

cat(
  "QA checks passed:",
  sum(qa_summary$status == "PASS"),
  "of",
  nrow(qa_summary),
  "\n"
)

cat(
  "QA checks requiring review:",
  sum(qa_summary$status == "REVIEW"),
  "\n"
)

cat(
  "All final processed files exist:",
  all(export_check$exists),
  "\n"
)

cat("========================================\n")