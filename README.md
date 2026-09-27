# NHS A&E Performance Analytics

A reproducible **data engineering and business intelligence portfolio project** using publicly available NHS England operational data to analyse:

- **A&E (Accident and Emergency)** activity and four-hour performance
- Emergency admissions and long waits after a **DTA (Decision to Admit)**
- **RTT (Referral to Treatment)** waiting-list performance
- Provider-level and specialty-level backlog pressure
- Long waits at 52+, 65+, 78+, and 104+ weeks

The project uses **R** for ingestion, profiling, cleaning, validation, dimensional modelling, and export, with **Microsoft Power BI** as the final reporting layer.

> **Portfolio / demonstration project only.**  
> This repository uses public, aggregated NHS England data. It is not an internal NHS system, does not contain patient-level data, and should not be used for clinical decision-making.


## Project Status

**Current stage:** Data engineering and analytical modelling complete. Power BI dashboard development is next.

Completed so far:

- A&E source profiling
- RTT source profiling
- A&E cleaning and KPI derivation
- RTT cleaning and waiting-band derivation
- Provider-level RTT fact table
- Specialty-level RTT fact table
- Date, provider, and specialty dimensions
- Referential-integrity checks
- KPI sanity checks
- Provider-to-specialty reconciliation
- Final quality-assurance outputs
- Power BI-ready CSV exports


## Business Objective

The objective is to build a concise operational performance dashboard that helps a manager understand:

- current A&E demand and emergency-admission pressure
- four-hour A&E performance
- long waits following a Decision to Admit
- changes in operational pressure over time
- which providers are under the greatest pressure
- total Referral to Treatment waiting-list backlog
- the proportion of pathways within 18 weeks
- long waits at 52+, 65+, 78+, and 104+ weeks
- which specialties contribute most to long waits
- where performance is improving or deteriorating

The final dashboard is intended to reduce manual analysis and present a clear management view of operational pressure.


## Core Business Questions

1. What is the current level of A&E activity?
2. How many emergency admissions are arising from A&E?
3. What percentage of A&E attendances are completed within four hours?
4. How has A&E performance changed over time?
5. Which providers or regions show the greatest operational pressure?
6. How many patients are waiting more than four or twelve hours after a Decision to Admit?
7. What is the total Referral to Treatment waiting list?
8. What percentage of incomplete pathways are within 18 weeks?
9. Which providers have the highest long-wait backlog?
10. Which specialties contribute most to 52+, 65+, 78+, and 104+ week waits?
11. Which organisations are improving or deteriorating month on month?
12. What should management pay attention to in the latest reporting period?


## Data Sources

The project uses public monthly datasets published by **NHS England**.

### A&E — Accident and Emergency

Current development extract:

- April 2026
- May 2026
- June 2026
- July 2026
- August 2026

The source contains provider-level measures including:

- Type 1 A&E attendances
- Type 2 A&E attendances
- other A&E department attendances
- booked appointments
- attendances over four hours
- 4–12 hour waits following a Decision to Admit
- 12+ hour waits following a Decision to Admit
- emergency admissions via A&E
- other emergency admissions

### RTT — Referral to Treatment

Current development extract:

- April 2026
- May 2026
- June 2026
- July 2026

The full extract contains:

- provider organisation
- provider parent organisation
- commissioner organisation
- RTT part type
- treatment function / specialty
- weekly waiting-time bands from 0–1 weeks through 104+ weeks
- total pathway measures

The analytical backlog model uses:

**Part_2 — Incomplete Pathways**

These represent pathways that are still waiting for treatment and are therefore the primary source for waiting-list backlog analysis.


## Current Data Volume

### Raw RTT extract

The four monthly RTT files contain:

**723,735 raw rows**

with **121 source columns** per monthly extract.

### Final analytical tables

| Table | Grain | Rows |
|---|---|---:|
| `fact_ae` | Month × provider | 956 |
| `fact_rtt_provider` | Month × provider | 2,130 |
| `fact_rtt_specialty` | Month × provider × specialty | 14,298 |
| `dim_date` | Month | 5 |
| `dim_provider` | Provider | 591 |
| `dim_specialty` | Treatment function / specialty | 23 |

The raw RTT data is intentionally reduced to analytics-friendly fact tables before loading into Power BI. The objective is not to preserve redundant commissioner-level records in the reporting model, but to create fact tables at the correct business grain.


## Key Performance Indicators

### A&E — Accident and Emergency

- Total A&E Attendances
- Attendances Over Four Hours
- Attendances Within Four Hours
- A&E Four-Hour Performance %
- DTA 4–12 Hour Waits
- DTA 12+ Hour Waits
- DTA 4+ Hour Waits
- Emergency Admissions via A&E
- Total Emergency Admissions

### RTT — Referral to Treatment

- Total Waiting List
- Within 18 Weeks
- Within 18 Weeks %
- 18+ Week Waits
- 52+ Week Waits
- 65+ Week Waits
- 78+ Week Waits
- 104+ Week Waits


## RTT Waiting-Band Logic

The source provides **105 weekly waiting-time bands** from 0–1 weeks through 104+ weeks.

These are transformed into management-level thresholds:

```text
Within 18 weeks = sum of bands starting at week 0 through week 17
18+ weeks       = sum of bands starting at week 18 and above
52+ weeks       = sum of bands starting at week 52 and above
65+ weeks       = sum of bands starting at week 65 and above
78+ weeks       = sum of bands starting at week 78 and above
104+ weeks      = 104+ week band
```

Validation confirmed:

```text
Within 18 weeks + 18+ weeks = Total incomplete waiting list
```

for all **253,553 Part_2 incomplete-pathway source records**, with **0 mismatches**.


## Data Model

The project uses a star-style analytical model.

```text
                        dim_date
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
      fact_ae      fact_rtt_provider   fact_rtt_specialty
          │                │                │
          └──────────── dim_provider ───────┘
                                           │
                                           ▼
                                   dim_specialty
```

### Fact Tables

#### `fact_ae`

Grain:

```text
one row per reporting month × A&E provider
```

#### `fact_rtt_provider`

Grain:

```text
one row per reporting month × provider
```

This table uses `C_999`, which represents the source total across treatment functions.

#### `fact_rtt_specialty`

Grain:

```text
one row per reporting month × provider × treatment function
```

`C_999` total rows are excluded from this table to prevent double counting.

### Dimensions

#### `dim_date`

Contains reporting month, year, month number, month labels, quarter, and year-quarter fields.

#### `dim_provider`

Contains provider code, canonical provider name, parent organisation, and source presence indicators.

The pipeline identified two provider codes with historical name changes:

```text
RA7
RXG
```

These are treated as naming-history issues rather than duplicate provider identities.

#### `dim_specialty`

Contains treatment function code and treatment function name.


## Data Engineering Workflow

```text
Public NHS England files
          │
          ▼
      Raw data
          │
          ▼
   Schema profiling
          │
          ▼
  Data-quality checks
          │
          ▼
       Cleaning
          │
          ▼
    KPI derivation
          │
          ▼
 Aggregation to correct
     analytical grain
          │
          ▼
      Fact tables
          │
          ▼
      Dimensions
          │
          ▼
 Referential integrity
     + reconciliation
          │
          ▼
 Power BI-ready exports
          │
          ▼
      Power BI model
          │
          ▼
       Dashboard
```


## Data Quality and Validation

### A&E validation

For the current five-month A&E extract:

- **90 of 90** provider aggregation checks matched the published NHS monthly totals
- no provider-month duplicates
- no negative attendance measures
- no negative emergency-admission measures
- four-hour performance remained between 0% and 100%

### RTT validation

- 253,553 incomplete-pathway source records tested
- 253,553 waiting-band reconciliations passed
- 0 waiting-band mismatches
- 0 provider fact duplicate keys
- 0 specialty fact duplicate keys
- no negative waiting-list measures
- within-18-weeks percentages remained between 0% and 100%

### Provider / Specialty Reconciliation

```text
Provider-month rows checked: 2,130
Exact matches:               2,130
Mismatches:                  0
Maximum absolute difference: 0
```

### Final QA — Quality Assurance

```text
21 of 21 checks PASS
0 checks require review
All expected processed files exist
```

Validation outputs are stored under:

```text
outputs/validation/
```


## Project Structure

```text
NHS-AE-Performance-Analytics/
│
├── data/
│   ├── raw/
│   │   ├── ae/
│   │   ├── rtt/
│   │   └── reference/
│   │
│   └── processed/
│       ├── fact_ae.csv
│       ├── fact_rtt_provider.csv
│       ├── fact_rtt_specialty.csv
│       ├── dim_date.csv
│       ├── dim_provider.csv
│       └── dim_specialty.csv
│
├── R/
│   ├── 01_profile_ae.R
│   ├── 02_profile_rtt.R
│   ├── 03_clean_ae.R
│   ├── 04_clean_rtt.R
│   ├── 05_build_model.R
│   └── 06_validate_export.R
│
├── outputs/
│   ├── data_quality/
│   └── validation/
│
├── powerbi/
├── docs/
├── assets/
├── .gitignore
├── .Rprofile
├── renv.lock
├── NHS-AE-Performance-Analytics.Rproj
└── README.md
```


## R Scripts

### `01_profile_ae.R`

Profiles Accident and Emergency source files, including schema checks, duplicate checks, missingness, aggregate-row identification, provider-name consistency, reconciliation to published totals, and numeric-range checks.

### `02_profile_rtt.R`

Profiles Referral to Treatment full CSV extracts, including ZIP extraction, schema inspection, monthly row counts, missingness, waiting-time-field discovery, numeric profiling, and data-quality outputs.

### `03_clean_ae.R`

Cleans Accident and Emergency data, derives four-hour and emergency-admission measures, validates the fact grain, and exports `fact_ae.csv`.

### `04_clean_rtt.R`

Cleans Referral to Treatment data, derives waiting-time thresholds, builds provider and specialty fact tables, validates the grain, and exports Power BI-ready files.

### `05_build_model.R`

Builds `dim_date`, `dim_provider`, and `dim_specialty`, while also checking dimension uniqueness and provider name changes.

### `06_validate_export.R`

Performs final model validation, including foreign-key checks, KPI range checks, provider-specialty reconciliation, processed-file checks, and Quality Assurance outputs.


## Reproducibility

The project uses `renv` to isolate and reproduce the R package environment.

Key packages include:

- `tidyverse`
- `readr`
- `janitor`
- `lubridate`
- `here`
- `skimr`
- `fs`

Restore the R environment with:

```r
install.packages("renv")
renv::restore()
```

Then run:

```text
01_profile_ae.R
02_profile_rtt.R
03_clean_ae.R
04_clean_rtt.R
05_build_model.R
06_validate_export.R
```


## Raw Data Policy

Raw NHS source files are excluded from Git using:

```gitignore
data/raw/
```

This keeps the repository lightweight and avoids committing large monthly source extracts.

The repository contains transformation scripts, processed outputs, data-quality results, validation results, and Power BI assets as the project develops.


## Power BI Dashboard Plan

The next stage is to build the final reporting experience in Microsoft Power BI.

### 1. Executive Overview

- A&E attendances
- emergency admissions
- four-hour performance
- Referral to Treatment waiting list
- within-18-weeks performance
- long waits
- latest month-on-month changes

### 2. A&E Performance

- attendance volumes
- four-hour performance
- provider ranking
- regional comparison
- Decision-to-Admit waits
- emergency admissions

### 3. Performance Trends

- monthly trends
- deterioration / improvement
- provider trajectories
- month-on-month change

### 4. RTT Long-Wait Analysis

- total waiting list
- within 18 weeks
- 52+ weeks
- 65+ weeks
- 78+ weeks
- 104+ weeks
- provider comparison
- specialty contribution
- provider-to-specialty drilldown

Planned filters:

- reporting month
- provider
- provider parent / region
- specialty / treatment function


## Planned Enhancements

- extend A&E history back to approximately April 2025
- extend Referral to Treatment history to the same reporting window
- add month-on-month change measures
- add provider ranking and percentile logic
- refine canonical provider mapping
- build Power BI semantic model and DAX measures
- create dashboard wireframes
- complete dashboard QA
- publish final portfolio case study
- add architecture and data-model diagrams


## Tools

| Area | Tools |
|---|---|
| Data source | NHS England public operational statistics |
| Data engineering | R / RStudio |
| Wrangling | tidyverse, readr, janitor, lubridate |
| Reproducibility | renv |
| Data modelling | Star-schema design |
| Business intelligence | Microsoft Power BI |
| Design | Figma |
| Version control | Git / GitHub |
| Portfolio publishing | Personal portfolio / case study |


## Design Principles

- preserve raw source files unchanged
- perform transformations in code
- retain source lineage
- use stable provider codes as analytical keys
- never silently replace missing values with zero
- identify duplicates before aggregation
- avoid double counting total and specialty rows
- reconcile derived totals against source totals
- keep fact-table grain explicit
- separate facts from dimensions
- keep the reporting layer focused on business questions
- document assumptions and source limitations
- avoid unsupported causal claims


## Limitations

- the current development window is shorter than the intended final historical period
- NHS organisational names and mappings may change over time
- historical definitions may change between reporting periods
- public operational data may contain suppression, revisions, or reporting differences
- provider-level patterns do not establish causation
- this project is not a live NHS operational system
- this project contains no patient-level data
- this project is not intended for clinical decision-making


## Repository Goal

This repository demonstrates capability across:

- business requirements interpretation
- public-sector data handling
- R-based data engineering
- schema profiling
- data-quality assessment
- reproducible transformation
- dimensional modelling
- KPI engineering
- validation and reconciliation
- Git version control
- Power BI modelling
- dashboard design
- analytical storytelling

The goal is to show the full workflow from operational source data to a validated management-reporting product, rather than simply producing charts from a pre-cleaned dataset.


## Author

**James Adeshina**

Data / Analytics / Business Intelligence Portfolio Project

GitHub: [JamesAdeshina](https://github.com/JamesAdeshina)

Portfolio: [jamesadeshina.com](https://jamesadeshina.com/)


## Disclaimer

This is an independent portfolio project created using publicly available NHS England data.

It is **not affiliated with, endorsed by, or produced on behalf of NHS England**.

All analysis is intended for demonstration and educational purposes only.
