options(max.print = 3000)

library(readxl)
library(dplyr)
library(MatchIt)
library(cobalt)
library(rstatix)

data <- read_excel("C:\\Users\\eguen\\Documents\\Ernesto\\Articulos\\RedLat\\Files\\Data\\data.xlsx", sheet = 1)

diagnoses <- c("CN", "AD", "FTD", "FTD-L", "DCL")

pairs <- combn(diagnoses, 2, simplify = FALSE)

results_list <- list()

for (pair in pairs) {

  group1 <- pair[1]
  group2 <- pair[2]

  cat("\n============================\n")
  cat("Processing:", group1, "vs", group2, "\n")
  cat("============================\n")

  data_sub <- data[data$Diagnosis %in% c(group1, group2), ]

  data_sub$diagnosis_binary <- ifelse(
    data_sub$Diagnosis == group2, 1,
    ifelse(data_sub$Diagnosis == group1, 0, NA)
  )

  data_sub <- data_sub %>%
    filter(!is.na(Age), !is.na(Education))

  if (length(unique(data_sub$diagnosis_binary)) < 2) {
    cat("Skipping", group1, "vs", group2, "- only one group available after filtering\n")
    next
  }

  match_obj <- tryCatch({
    matchit(
      diagnosis_binary ~ Age + Education,
      data       = data_sub,
      method     = "nearest",
      caliper    = 2,
      std.caliper = TRUE
    )
  }, error = function(e) {
    cat("Matching failed for", group1, "vs", group2, "\n")
    cat("Error:", e$message, "\n")
    return(NULL)
  })

  if (is.null(match_obj)) next

  matched_data <- match.data(match_obj)

  if (length(unique(matched_data$diagnosis_binary)) < 2) {
    cat("Skipping", group1, "vs", group2, "- only one group after matching\n")
    next
  }

  # ── Sex balance test ──────────────────────────────────────────
  tab_sex  <- table(matched_data$Sex_1F_2M, matched_data$diagnosis_binary)
  chi_obj  <- suppressWarnings(chisq.test(tab_sex))

  if (any(chi_obj$expected < 5)) {
    p_sex    <- fisher.test(tab_sex)$p.value
    sex_test <- "Fisher"
  } else {
    p_sex    <- chi_obj$p.value
    sex_test <- "Chi-square"
  }

  # ── Normality tests (Shapiro-Wilk) ───────────────────────────
  # BUG FIXED: shapiro_age tested Education; shapiro_ed tested Age → swapped
  shapiro_age <- matched_data %>%
    group_by(diagnosis_binary) %>%
    summarise(
      p_shapiro_age = ifelse(
        n() >= 3 & n() <= 5000,
        shapiro.test(Age)$p.value,       # corrected: Age
        NA_real_
      ),
      .groups = "drop"
    )

  shapiro_ed <- matched_data %>%
    group_by(diagnosis_binary) %>%
    summarise(
      p_shapiro_ed = ifelse(
        n() >= 3 & n() <= 5000,
        shapiro.test(Education)$p.value, # corrected: Education
        NA_real_
      ),
      .groups = "drop"
    )

  # ── Statistical tests ─────────────────────────────────────────
  p_t_age <- tryCatch(
    t.test(Age ~ diagnosis_binary, data = matched_data)$p.value,
    error = function(e) NA
  )

  p_t_education <- tryCatch(
    t.test(Education ~ diagnosis_binary, data = matched_data)$p.value,
    error = function(e) NA
  )

  p_wilcox_age <- tryCatch(
    wilcox.test(Age ~ diagnosis_binary, data = matched_data)$p.value,
    error = function(e) NA
  )

  # BUG FIXED: p_wilcox_education used Age instead of Education
  p_wilcox_education <- tryCatch(
    wilcox.test(Education ~ diagnosis_binary, data = matched_data)$p.value,
    error = function(e) NA
  )

  n_group0 <- sum(matched_data$diagnosis_binary == 0)
  n_group1 <- sum(matched_data$diagnosis_binary == 1)

  sex_counts <- matched_data %>%
    group_by(diagnosis_binary, Sex_1F_2M) %>%
    summarise(n = n(), .groups = "drop")

  out_name <- paste0("C:\\Users\\eguen\\Documents\\Ernesto\\Articulos\\RedLat\\Files\\Data\\matched_", group1, "_vs_", group2, ".csv")

  # BUG FIXED: was saving data_sub (unmatched) instead of matched_data
  write.csv(matched_data, out_name, row.names = FALSE)

  results_list[[paste0(group1, "_vs_", group2)]] <- data.frame(
    comparison   = paste(group1, "vs", group2),
    n_group0     = n_group0,
    n_group1     = n_group1,

    mean_age_group0 = mean(matched_data$Age[matched_data$diagnosis_binary == 0], na.rm = TRUE),
    mean_age_group1 = mean(matched_data$Age[matched_data$diagnosis_binary == 1], na.rm = TRUE),

    # BUG FIXED: group indices were swapped (0↔1)
    mean_ed_group0 = mean(matched_data$Education[matched_data$diagnosis_binary == 0], na.rm = TRUE),
    mean_ed_group1 = mean(matched_data$Education[matched_data$diagnosis_binary == 1], na.rm = TRUE),

    p_t_age            = p_t_age,
    p_t_education      = p_t_education,
    p_wilcox_age       = p_wilcox_age,
    p_wilcox_education = p_wilcox_education,
    sex_test           = sex_test,
    p_sex              = p_sex,
    stringsAsFactors   = FALSE
  )

  cat("Matched sample saved to:", out_name, "\n")
  print(results_list[[paste0(group1, "_vs_", group2)]])
}

results_df <- bind_rows(results_list)

write.csv(results_df, "C:\\Users\\eguen\\Documents\\Ernesto\\Articulos\\RedLat\\Files\\Data\\matching_results_all_pairs.csv", row.names = FALSE)

print(results_df)

