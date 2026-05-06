# EEG Brain Age Analysis — RedLat-EEG Consortium

Repositorio para la prueba tecnica basada en el dataset RedLat-EEG.
Contiene dos tareas principales: **prediccion de edad** a partir de features alpha del EEG, y **organizacion de datos** con scripts de soporte (matching, calidad de senal y demo de brain clock).

---

## Estructura del repositorio

```
Files/
├── Data/
│   ├── Alpha_data.xlsx                  # Features alpha-band (alpha1, alpha2, IAF, TF) por canal + Age
│   ├── data.xlsx                        # Dataset clinico (Diagnosis, Age, Sex, Education)
│   ├── matched_*.csv                    # Salidas de Matching_sex.R (un CSV por par diagnostico)
│   └── matching_results_all_pairs.csv   # Tabla resumen de todos los pares matcheados
│
├── QA_Code/
│   ├── SignalQuality.m                  # Script principal de calidad de senal (MATLAB)
│   ├── +functions/                      # Package MATLAB con utilidades
│   │   ├── eeg_quality_nan.m
│   │   ├── eeg_quality_high_amplitude.m
│   │   ├── PSD.m
│   │   └── plot_eeg_psd.m
│   ├── sub-02_ses-01_task-RSVP_run-01_eeg.edf
│   ├── sub-10_ses-01_task-RSVP_run-01_eeg.edf
│   ├── sub-11_ses-01_task-RSVP_run-01_eeg.edf
│   └── Results/                         # Figuras y CSV generados por SignalQuality.m
│
├── EEG_Age_Prediction.ipynb             # Tarea 1 — Pipeline de prediccion de edad
├── Clock.ipynb                          # Brain clock sobre dataset artificial (GBR)
├── Matching_sex.R                       # Matching por edad/sexo/educacion (R)
├── Matching-sex.ipynb                   # Comparacion estadistica de grupos matcheados
├── requirements.txt                     # Dependencias Python
└── README.md
```

---

## Setup

```bash
pip install -r requirements.txt
```

Para los scripts en R y MATLAB ver las secciones correspondientes mas abajo.

---

## Tarea 1 — Prediccion de edad (`EEG_Age_Prediction.ipynb`)

Predice la **edad cronologica** a partir de metricas alpha canonicas e individualizadas (alpha1, alpha2, IAF, TF) extraidas por canal del EEG en reposo.

**Dos pipelines en paralelo:**

| Pipeline | Input | Justificacion |
|---|---|---|
| **A** | Features seleccionadas por consenso SHAP (XGBoost + ElasticNet) | Reduce ruido de features no informativas y mejora interpretabilidad |
| **B** | Componentes PCA (95% varianza) | Elimina multicolinealidad entre canales adyacentes |

**Modelo:** ElasticNet + Bagging (20 iteraciones) + correccion de bias por regresion a la media (sin leakage), siguiendo Prado et al. (2025). Comparado contra XGBoost y SVR con CV anidada.

**Metricas:** MAE (principal), RMSE, R^2 — sobre test hold-out 20%.

**Hallazgo clave:** MAE ≈ 14 anos, GAP con MAE ≈ 7.

---

## Tarea 2 — Organizacion de datos

### `Clock.ipynb` — Brain clock sobre dataset artificial

Pipeline demostrativo de brain clock con Gradient Boosting Regression (GBR) sobre dataset sintetico (`sklearn.make_regression`).

Pasos: generacion de datos → MinMax scaling → k-fold CV → correccion de GAP via GLM → importancia de features y efectos direccionales.

**Bugs corregidos:**
- `mean_absolute_error` no aplicaba `np.abs()` (calculaba el error medio con signo).
- Doble llamada a `model.fit` que sobrescribia el modelo del fold con uno entrenado sobre todo el dataset.
- Doble `sns.barplot` en la celda de visualizacion.

---

### `Matching_sex.R` — Matching de participantes (R)

Empareja participantes entre todas las combinaciones por pares de grupos diagnosticos (CN, AD, FTD, FTD-L, DCL) por **edad** y **educacion** usando matching por nearest-neighbor / propensity score (`MatchIt`). Verifica balance de sexo con Chi-cuadrado o test exacto de Fisher.

Genera un CSV por par en `Data/` y una tabla resumen `matching_results_all_pairs.csv`.

**Bugs corregidos:**
- `shapiro_age` testeaba `Education` en vez de `Age`.
- `shapiro_ed` testeaba `Age` en vez de `Education`.
- `p_wilcox_education` usaba `Age ~ diagnosis_binary` en vez de `Education ~ diagnosis_binary`.
- `mean_ed_group0/1` tenia los indices de grupo (0 ↔ 1) intercambiados.
- `write.csv` guardaba `data_sub` (sin matchear) en lugar de `matched_data`.

**Dependencias R:**
```r
install.packages(c("readxl", "dplyr", "MatchIt", "cobalt", "rstatix"))
```

---

### `Matching-sex.ipynb` — Comparacion estadistica de grupos matcheados

Consume los CSV producidos por `Matching_sex.R` y aplica:
- Remocion de outliers por IQR con analisis de sensibilidad sobre 4 umbrales (k = 0.1, 0.5, 1.0, 1.5).
- **Cliff's Delta** como tamano de efecto en todas las comparaciones por pares.
- **Test de permutacion** (10.000 permutaciones, dos colas) para diferencias en Brain Age Gap (BAG).
- Boxplots de BAG estratificados por grupo diagnostico.

**Bugs corregidos:**
- `remove_outliers_iqr`: limites `low`/`high` invertidos (`q1 + k*IQR` y `q3 - k*IQR`); condicion usaba `|` en lugar de `&`.
- `cliffs_delta`: denominador era `(nx + ny)`; la formula correcta es `(nx * ny)`.
- `chunk_list`: `range(0, len(lst) - n, n)` perdia el ultimo chunk; corregido a `range(0, len(lst), n)`.
- `permutation_pvalue`: comparacion usaba `obs_diff` con signo; un test de dos colas requiere `np.abs(obs_diff)`.

---

### `QA_Code/SignalQuality.m` — Calidad de senal EEG (MATLAB)

Script de evaluacion de calidad sobre los tres registros `.edf` incluidos. Procesa los archivos en un loop y guarda salidas en `QA_Code/Results/`.

**Metricas calculadas:**

| Metrica | Descripcion |
|---|---|
| **ONS** | Overall NaN Score — % de muestras sin NaN/Inf |
| **OHA** | Overall High-Amplitude Score — % de muestras dentro de los limites de amplitud |
| **ODQ** | Overall Data Quality — promedio combinado de ONS y OHA |

**Salidas en `Results/`:**
- `<sujeto>_quality.png` — heatmap por canal × ventana (NaN/Inf y amplitud) por cada sujeto.
- `quality_summary.csv` — tabla con ONS, OHA, ODQ de los tres sujetos.

**Como ejecutar:**
```matlab
cd 'Files/QA_Code'
SignalQuality
```

**Dependencias MATLAB:**
- *Signal Processing Toolbox* (para `edfread` / `edfinfo`).
- *Statistics and Machine Learning Toolbox* (para `nanmean` en `+functions/eeg_quality_high_amplitude.m`).
- Package local `+functions/` (incluido).

---

## Referencia

Prado et al. (2025). *Source-space EEG Alpha Activity Reveals Brain Age Gaps Due to Neurodegeneration and Disparity*. Research Square (preprint). https://doi.org/10.21203/rs.3.rs-6623758/v1
