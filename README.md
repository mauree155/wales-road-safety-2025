# Slower towns, faster harm? Serious road injuries in Wales, 2025

MS4S08 Applied Statistics group project, University of South Wales.

**Team:** [Group member names]

## Research question
In Wales in 2025, are collisions on faster roads more likely to cause death or serious injury, and who is most affected?

## Key findings
- 60 mph roads had the highest rate of collisions killing or seriously injuring someone (KSI): 46.2%, against 35.4% overall. 97% of these were rural single carriageways.
- Across the 22 Welsh councils, a higher share of collisions on 60 or 70 mph roads went with a higher KSI rate (Pearson r = 0.59, p = 0.004, using DfT adjusted severity).
- Within each council, collisions on fast roads were KSI 6.3 percentage points more often than on slower roads (paired t test, 95% CI 2.7 to 10.0, p = 0.002).
- Motorcyclists were 12.6% of casualties, but 57.2% of them were KSI. KSI casualties were slightly older (median 38 vs 35 years, Mann-Whitney p < 0.001).

## Data
STATS19 road safety data, Department for Transport, 2025 collisions and casualties, filtered to Wales (3,004 collisions, 4,078 casualties).
Source: Department for Transport, Road Safety Data, data.gov.uk.

Contains public sector information licensed under the Open Government Licence v3.0.

| File | Contents |
|---|---|
| `data/wales_collisions_2025.csv` | One row per collision, cleaned and recoded |
| `data/wales_casualties_2025.csv` | One row per casualty, joined to its collision |
| `data/council_summary_2025.csv` | One row per council: KSI rates, fast road and rural shares |
| `data/council_fast_vs_slower_2025.csv` | One row per council: KSI rates on fast and slower roads |

## Scripts (SAS)
Run in this order in SAS OnDemand for Academics, with the raw DfT CSV files in the project folder:

1. `01_import.sas`: import the raw collision and casualty files
2. `02_clean.sas`: keep Wales, recode, join casualties to collisions, check the recoding
3. `03_eda.sas`: exploratory data analysis
4. `04_tests.sas`: Pearson correlation, paired t test and Mann-Whitney U test, with assumption checks
5. `05_charts.sas`: the six poster charts
6. `06_export_data.sas`: save the cleaned tables as CSV

## Charts
Six charts in `charts/`, produced with SAS PROC SGPLOT. Red marks the group with the highest risk; blue marks all other groups.

## Poster
The A2 poster PDF will be added to `poster/` after submission.

## Licence
- **Code** (`scripts/`): MIT License, see `LICENSE`.
- **Data** (`data/`): derived from Department for Transport STATS19 data. Contains public sector information licensed under the [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).
- **Charts and poster** (`charts/`, `poster/`): [Creative Commons Attribution 4.0 (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
