# EEG Brain Age Analysis — EuroLAD-EEG Consortium

Repository for the technical assessment based on the EuroLAD-EEG dataset.  
Contains two main tasks: **age prediction** from EEG alpha-band features, and **data organization** of supporting analysis scripts.

---

## Repository Structure

```
├── Data/
│   ├── Alpha_data.xlsx              # EEG alpha-band features + Age target
│   ├── data.xlsx                    # Clinical dataset (Diagnosis, Age, Sex, Education)
│   └── matched_*.csv                # Output of Matching_sex.R (one file per diagnosis pair)
│
├── Figures/                         # Output figures from SignalQuality.m
│
├── EEG_Age_Prediction.ipynb         # Task 1 — Age prediction pipeline
├── Clock.ipynb                      # Brain clock on artificial dataset (GBR)
├── Matching_sex.R                   # Participant matching by age, sex and education (R)
├── Matching-sex.ipynb               # Statistical comparison of matched groups (Python)
└── SignalQuality.m                  # EEG signal quality assessment (MATLAB)
```

---

## Task 1 — Age Prediction (`EEG_Age_Prediction.ipynb`)

Predicts chronological **Age** from canonical and individualized EEG alpha-band metrics (α1, α2, IAF, TF) extracted per channel from resting-state EEG.

**Two parallel pipelines:**

| Pipeline | Feature input | Rationale |
|---|---|---|
| **A** | All 66 features | No individual feature exceeds \|r\|=0.30 with Age → ElasticNet performs implicit selection via L1 regularization |
| **B** | PCA components (95% variance) | Removes multicollinearity between adjacent channels |

**Model:** ElasticNet + Bagging (20 iterations) + regression-to-mean bias correction, replicating the methodology of Prado et al. (2025).

**Metrics:** MAE (primary), RMSE, R² — evaluated on a held-out 20% test set.

**Key finding:** MAE ≈ 14 years, consistent with scalp-level alpha-only models in the literature. Performance gap relative to Prado et al. (MAE=6.22) is attributed to the absence of source-space EEG (sLORETA), multi-site harmonization, and healthy-controls-only training.

**Dependencies:**
```bash
pip install pandas openpyxl matplotlib seaborn scikit-learn xgboost shap
```

---

## Task 2 — Data Organization

### `Clock.ipynb` — Brain Clock on Artificial Dataset

Demonstrates a brain-clock pipeline using Gradient Boosting Regression (GBR) on a synthetic dataset generated with `sklearn.make_regression`.

Steps: data generation → MinMax scaling → k-fold CV → GAP bias correction (GLM) → feature importance + directional effects visualization.

**Bugs fixed:**
- `mean_absolute_error` was missing `np.abs()` → computed mean signed error instead
- `model.fit(X, y)` after `model.fit(X_train, y_train)` overwrote fold model with full-data model
- Double `sns.barplot` call in visualization cell

**Dependencies:**
```bash
pip install scikit-learn statsmodels seaborn matplotlib scipy
```

---

### `Matching_sex.R` — Participant Matching

Matches participants across all pairwise diagnostic group combinations (CN, AD, FTD, FTD-L, DCL) by **age** and **education** using nearest-neighbor propensity score matching (`MatchIt`). Tests sex balance with Chi-square or Fisher's exact test.

Outputs one matched CSV per pair to `Data/` and a summary table `matching_results_all_pairs.csv`.

**Bugs fixed:**
- `shapiro_age` was testing `Education` instead of `Age`
- `shapiro_ed` was testing `Age` instead of `Education`
- `p_wilcox_education` used `Age ~ diagnosis_binary` instead of `Education ~ diagnosis_binary`
- `mean_ed_group0/1` had group indices (0↔1) swapped
- `write.csv` saved `data_sub` (unmatched) instead of `matched_data`

**Dependencies (R):**
```r
install.packages(c("readxl", "dplyr", "MatchIt", "cobalt", "rstatix"))
```

---

### `Matching-sex.ipynb` — Statistical Comparison of Matched Groups

Consumes the matched CSVs from `Matching_sex.R` and performs:
- IQR-based outlier removal with sensitivity analysis across 4 thresholds (k = 0.1, 0.5, 1.0, 1.5)
- **Cliff's Delta** effect size for all pairwise comparisons
- **Permutation test** (10,000 permutations, two-sided) for mean Brain Age Gap (BAG) differences
- Boxplots of BAG stratified by diagnostic group

**Bugs fixed:**
- `remove_outliers_iqr`: `low`/`high` bounds were swapped (`q1 + k*IQR` and `q3 - k*IQR`); condition used `|` instead of `&`
- `cliffs_delta`: denominator was `(nx + ny)`; correct formula uses `(nx * ny)`
- `chunk_list`: `range(0, len(lst) - n, n)` dropped the last chunk; fixed to `range(0, len(lst), n)`
- `permutation_pvalue`: comparison used signed `obs_diff`; two-sided test requires `np.abs(obs_diff)`

**Dependencies:**
```bash
pip install pandas numpy seaborn matplotlib
```

---

### `SignalQuality.m` — EEG Signal Quality Assessment (MATLAB)

Computes and visualises three signal quality metrics:

| Metric | Description |
|---|---|
| **ONS** | Overall NaN Score — % of samples without missing values |
| **OHA** | Overall High-Amplitude Score — % of samples within amplitude bounds |
| **ODQ** | Overall Data Quality — combined average of ONS and OHA |

Generates three figures saved to `Figures/`:
- `quality_heatmap.png` — per-channel × epoch quality matrices
- `quality_per_channel.png` — per-channel bar chart of clean sample percentages
- `quality_summary.png` — scalar ONS / OHA / ODQ summary

**Dependencies:** EEGLAB, `+functions` package (`eeg_quality_nan`, `eeg_quality_high_amplitude`)

---

## Reference

Prado et al. (2025). *Source-space EEG Alpha Activity Reveals Brain Age Gaps Due to Neurodegeneration and Disparity*. Research Square (preprint). https://doi.org/10.21203/rs.3.rs-6623758/v1
