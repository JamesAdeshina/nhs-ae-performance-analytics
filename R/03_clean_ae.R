# NHS A&E Performance Analytics
# 03 - Clean and transform A&E data

library(tidyverse)
library(janitor)
library(lubridate)
library(here)

# ---------------------------------------------------------
# Locate raw A&E source files
# ---------------------------------------------------------

ae_files <- list.files(
  here("data", "raw", "ae"),
  pattern = "\\.csv$",
  full.names = TRUE
)

# ---------------------------------------------------------
# Read and combine monthly A&E files
# ---------------------------------------------------------

ae_raw <- map_dfr(
  ae_files,
  ~ read_csv(.x, show_col_types = FALSE) %>%
    mutate(source_file = basename(.x))
)

# ---------------------------------------------------------
# Standardise column names
# ---------------------------------------------------------

ae_clean <- ae_raw %>%
  clean_names()

# ---------------------------------------------------------
# Remove published aggregate TOTAL rows
# ---------------------------------------------------------

ae_clean <- ae_clean %>%
  filter(str_to_upper(period) != "TOTAL")

# ---------------------------------------------------------
# Convert reporting period to proper date
# ---------------------------------------------------------

ae_clean <- ae_clean %>%
  mutate(
    report_month = str_remove(period, "^MSitAE-"),
    report_month = my(report_month),
    report_month = floor_date(report_month, "month")
  )

# ---------------------------------------------------------
# Initial checks
# ---------------------------------------------------------

glimpse(ae_clean)

names(ae_clean)

ae_clean %>%
  distinct(period, report_month) %>%
  arrange(report_month)

nrow(ae_clean)







# ---------------------------------------------------------
# Rename columns to analytics-friendly names
# ---------------------------------------------------------

ae_clean <- ae_clean %>%
  rename(
    provider_code = org_code,
    provider_name = org_name,
    region = parent_org,
    
    attendances_type1 = a_e_attendances_type_1,
    attendances_type2 = a_e_attendances_type_2,
    attendances_other = a_e_attendances_other_a_e_department,
    
    attendances_booked_type1 =
      a_e_attendances_booked_appointments_type_1,
    
    attendances_booked_type2 =
      a_e_attendances_booked_appointments_type_2,
    
    attendances_booked_other =
      a_e_attendances_booked_appointments_other_department,
    
    over4_type1 =
      attendances_over_4hrs_type_1,
    
    over4_type2 =
      attendances_over_4hrs_type_2,
    
    over4_other =
      attendances_over_4hrs_other_department,
    
    over4_booked_type1 =
      attendances_over_4hrs_booked_appointments_type_1,
    
    over4_booked_type2 =
      attendances_over_4hrs_booked_appointments_type_2,
    
    over4_booked_other =
      attendances_over_4hrs_booked_appointments_other_department,
    
    dta_4_12_hours =
      patients_who_have_waited_4_12_hs_from_dta_to_admission,
    
    dta_12_plus_hours =
      patients_who_have_waited_12_hrs_from_dta_to_admission,
    
    emergency_admissions_type1 =
      emergency_admissions_via_a_e_type_1,
    
    emergency_admissions_type2 =
      emergency_admissions_via_a_e_type_2,
    
    emergency_admissions_other_ae =
      emergency_admissions_via_a_e_other_a_e_department
  )



# ---------------------------------------------------------
# Derive analytical measures
# ---------------------------------------------------------

ae_clean <- ae_clean %>%
  mutate(
    total_attendances =
      attendances_type1 +
      attendances_type2 +
      attendances_other +
      attendances_booked_type1 +
      attendances_booked_type2 +
      attendances_booked_other,
    
    total_over4 =
      over4_type1 +
      over4_type2 +
      over4_other +
      over4_booked_type1 +
      over4_booked_type2 +
      over4_booked_other,
    
    within_4_hours =
      total_attendances - total_over4,
    
    ae_4_hour_performance_pct =
      if_else(
        total_attendances > 0,
        within_4_hours / total_attendances,
        NA_real_
      ),
    
    dta_4_plus_hours =
      dta_4_12_hours + dta_12_plus_hours,
    
    emergency_admissions_via_ae =
      emergency_admissions_type1 +
      emergency_admissions_type2 +
      emergency_admissions_other_ae,
    
    total_emergency_admissions =
      emergency_admissions_via_ae +
      other_emergency_admissions
  )



# ---------------------------------------------------------
# Sanity checks on derived measures
# ---------------------------------------------------------

ae_clean %>%
  summarise(
    min_performance = min(ae_4_hour_performance_pct, na.rm = TRUE),
    max_performance = max(ae_4_hour_performance_pct, na.rm = TRUE),
    negative_within_4 = sum(within_4_hours < 0, na.rm = TRUE),
    negative_total_attendances = sum(total_attendances < 0, na.rm = TRUE),
    negative_total_emergency_admissions =
      sum(total_emergency_admissions < 0, na.rm = TRUE)
  )




# ---------------------------------------------------------
# Select final A&E fact-table columns
# ---------------------------------------------------------

fact_ae <- ae_clean %>%
  select(
    report_month,
    provider_code,
    provider_name,
    region,
    
    attendances_type1,
    attendances_type2,
    attendances_other,
    attendances_booked_type1,
    attendances_booked_type2,
    attendances_booked_other,
    
    total_attendances,
    total_over4,
    within_4_hours,
    ae_4_hour_performance_pct,
    
    dta_4_12_hours,
    dta_12_plus_hours,
    dta_4_plus_hours,
    
    emergency_admissions_type1,
    emergency_admissions_type2,
    emergency_admissions_other_ae,
    emergency_admissions_via_ae,
    other_emergency_admissions,
    total_emergency_admissions,
    
    source_file
  ) %>%
  arrange(report_month, provider_code)



glimpse(fact_ae)

fact_ae %>%
  slice_head(n = 10)


# ---------------------------------------------------------
# Validate fact-table grain
# ---------------------------------------------------------

fact_ae %>%
  count(report_month, provider_code) %>%
  filter(n > 1)


# ---------------------------------------------------------
# Export Power BI-ready A&E fact table
# ---------------------------------------------------------

write_csv(
  fact_ae,
  here("data", "processed", "fact_ae.csv")
)


