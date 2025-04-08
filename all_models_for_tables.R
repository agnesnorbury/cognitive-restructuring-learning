## Analyses to re-run to get correct intervals ---------------------------------
## Setup -----------------------------------------------------------------------
pth_s1 <- paste0(getwd(), "/study-1/analysis/")
pth_s2 <- paste0(getwd(), "/study-2/analysis/")
round_tb <- function(var, digits = 3, nsmall = 3) {
  format(round(mean(var), digits = digits), nsmall = nsmall, scientific = FALSE)
}

## Table S1/S2: CR/CR+learning on causal attribution in study 1/2 --------------
## Prep data
prep_data_cr <- function(pth, file, learn = FALSE) {
  library(magrittr)
  ## load data
  nTrials <- ID <- X <- uid <- taskNo <- itemNo <- condition <- valence <-
    learningCondition <- interventionCondition <- NULL
  ret <- list()
  data_long_all <- read.csv(file = paste0(pth, file)) |>
    dplyr::select(-nTrials, -ID, -X) |>
    dplyr::arrange(uid, taskNo, itemNo) |>
    dplyr::mutate(sess = taskNo + 1, neg_pos = ifelse(valence=="negative", 0, 1))

  ## get number of time points etc
  ret$nPpts <- length(unique(data_long_all$uid))
  ret$nTimes <- max(data_long_all$sess)

  ret$nTrials_all <- data_long_all |>
    dplyr::arrange(uid) |>
    dplyr::group_by(uid) |>
    dplyr::summarize(nTrials = dplyr::n()) |>
    dplyr::mutate(ID = seq(1, ret$nPpts, 1))  # assign sequential numeric IDs for later
  ret$data_long_all <- merge(data_long_all, ret$nTrials_all, by="uid")

  ret$nTrials_max <- ret$nTrials_all %>% {max(.$nTrials)} #nolint

  # get ordered list of intervention conditions
  if (learn) {
    ret$int_conds <- ret$data_long_all |>
      dplyr::arrange(ID) |>
      dplyr::group_by(ID) |>
      dplyr::select(ID, interventionCondition) |>
      dplyr::distinct() |>
      dplyr::mutate(condition01 = ifelse(interventionCondition=="psychoed", 1, 0))
    ret$learn_conds <- ret$data_long_all |>
      dplyr::arrange(ID) |>
      dplyr::group_by(ID) |>
      dplyr::select(ID, learningCondition) |>
      dplyr::distinct() |>
      dplyr::mutate(condition01 = ifelse(learningCondition=="causal", 1, 0))
  } else {
    ret$int_conds <- ret$data_long_all |>
      dplyr::arrange(ID) |>
      dplyr::group_by(ID) |>
      dplyr::select(ID, condition) |>
      dplyr::distinct() |>
      dplyr::mutate(condition01 = ifelse(condition=="psychoed", 1, 0))
  }
  return(ret)
}
study1_cr <- prep_data_cr(pth_s1, "causal-attr-1-2-causal-attribution-task-data-anon.csv")
study2_cr <- prep_data_cr(
  pth_s2, "causal-attr-learn-causal-attribution-task-data-anon.csv", learn = TRUE
)

## Fit models
model_s1 <- "m_bernoulli_negpos_IGcorr2_multisess_intervention_additive"
model_s2 <- "m_bernoulli_negpos_IGcorr2_multisess_intervention_learning_additive"

## Study 1
get_stan_data_cr <- function(prep_data, learn = FALSE) {
  data_long_all <- prep_data$data_long_all
  nPpts <- prep_data$nPpts
  nTimes <- prep_data$nTimes
  nTrials_max <- prep_data$nTrials_max
  int_conds <- prep_data$int_conds

  ## create data list for stan
  internalChosen_neg <- internalChosen_pos <- globalChosen_neg <-
    globalChosen_pos <- array(0, dim = c(nPpts, nTimes, nTrials_max/2))
  nT_ppts <- array(nTrials_max, dim = c(nPpts, nTimes))
  for (i in 1:nPpts) {
    for (t in 1:nTimes) {
      internalChosen_neg[i, t, ] <- with(data_long_all, internalChosen[ID==i & sess==t & neg_pos==0])
      internalChosen_pos[i, t, ] <- with(data_long_all, internalChosen[ID==i & sess==t & neg_pos==1])
      globalChosen_neg[i, t, ] <- with(data_long_all, globalChosen[ID==i & sess==t & neg_pos==0])
      globalChosen_pos[i, t, ] <- with(data_long_all, globalChosen[ID==i & sess==t & neg_pos==1])
    }
  }

  ## create list to pass to stan
  if (learn) {
    learn_conds <- prep_data$learn_conds
    data_list <- list(
      nTimes = nTimes,
      nPpts = nPpts,
      nTrials_max = nTrials_max/2,             # max number of trials per  session per participant
      nT_ppts = nT_ppts,                       # actual number of trials per session per participant
      condition = int_conds$condition01,      # 0 = control, 1 = psychoed
      int_condition = int_conds$condition01,   # 0 = control, 1 = psychoed
      learn_condition = learn_conds$condition01,   # 0 = control, 1 = causal
      internal_neg = internalChosen_neg,
      internal_pos = internalChosen_pos,
      global_neg = globalChosen_neg,
      global_pos = globalChosen_pos
    )
  } else {
    data_list <- list(
      nTimes = nTimes,
      nPpts = nPpts,
      nTrials_max = nTrials_max/2,         # max number of trials per  session per participant
      nT_ppts = nT_ppts,                   # actual number of trials per session per participant
      condition = int_conds$condition01,   # 0 = control, 1 = psychoed
      internal_neg = internalChosen_neg,
      internal_pos = internalChosen_pos,
      global_neg = globalChosen_neg,
      global_pos = globalChosen_pos
    )
  }
  return(data_list)
}
dl_s1 <- get_stan_data_cr(study1_cr)
dl_s2 <- get_stan_data_cr(study2_cr, learn = TRUE)

## fit model using rstan
fit_m1 <- rstan::stan(
  file = paste0(pth_s2, "/stan-models/", model_s1, ".stan"),
  data = dl_s1,
  chains = 4,
  warmup = 2000,
  iter = 4000,
  cores = 4
)
saveRDS(fit_m1, file = paste0(pth_s1, "stan-fits/", model_s1, "-", "causal-attr-1-2-fit.rds"))
# fit_m1 <- readRDS(paste0(pth_s1, "stan-fits/", model_s1, "-", "causal-attr-1-2-fit.rds"))

params_m1_qcis <- rstan::summary(
  fit_m1,
  pars = c(
    "mu_internal_theta_neg[1]", "mu_internal_theta_neg[2]", "mu_internal_theta_pos[1]",
    "mu_internal_theta_pos[2]", "mu_global_theta_neg[1]",  "mu_global_theta_neg[2]",
    "mu_global_theta_pos[1]",  "mu_global_theta_pos[2]", "theta_int_internal_neg",
    "theta_int_internal_pos", "theta_int_global_neg", "theta_int_global_pos"
  ),
  probs = c(0.025, 0.05, 0.95, 0.975)
)$summary
pm1_tb <- tibble::as_tibble(params_m1_qcis) |>
  dplyr::select(-2) |> # remove se(mean)
  # round to 3 d.p.
  dplyr::rowwise() |>
  dplyr::mutate(
    dplyr::across(
      tidyselect::where(is.numeric),
      ~ round_tb(.x, digits = 3, nsmall = 3)
    )
  )
write.csv(
  pm1_tb,
  file = paste0(pth_s1, "stan-fits/", model_s1, "-", "causal-attr-1-2-summary.csv"),
  row.names = FALSE
)

# Table S2

# fit model using rstan
fit_m2 <- rstan::stan(
  file = paste0(pth_s2, "/stan-models/", model_s2, ".stan"),
  data = dl_s2,
  chains = 4,
  warmup = 2000,
  iter = 4000,
  cores = 4
)
saveRDS(fit_m2, file = paste0(pth_s2, "/stan-fits/", model_s2, "-", "causal-attr-learn-fit.rds"))
params_m2_qcis <- rstan::summary(
  fit_m2,
  pars = c(
    "mu_internal_theta_neg[1]", "mu_internal_theta_neg[2]", "mu_internal_theta_pos[1]",
    "mu_internal_theta_pos[2]", "mu_global_theta_neg[1]", "mu_global_theta_neg[2]",
    "mu_global_theta_pos[1]",   "mu_global_theta_pos[2]", "theta_int_internal_neg",
    "theta_int_internal_pos", "theta_int_global_neg", "theta_int_global_pos",
    "theta_learn_internal_neg", "theta_learn_internal_pos", "theta_learn_global_neg",
    "theta_learn_global_pos"
  ),
  probs = c(0.025, 0.05, 0.95, 0.975)
)$summary
pm2_tb <- tibble::as_tibble(params_m2_qcis) |>
  dplyr::select(-2) |> # remove se(mean)
  # round to 3 d.p.
  dplyr::rowwise() |>
  dplyr::mutate(
    dplyr::across(
      tidyselect::where(is.numeric),
      ~ round_tb(.x, digits = 3, nsmall = 3)
    )
  )
write.csv(
  pm2_tb,
  file = paste0(pth_s2, "/stan-fits/", model_s2, "-", "causal-attr-learn-summary.csv"),
  row.names = FALSE
)

## Table S3-S6 -----------------------------------------------------------------
# joint models of choices and learning
get_stan_data_joint <- function(pth, task_ver, learn = FALSE, ids = NULL) {
  X <- uid <- taskNo <- itemNo <- condition <- valence <- trialNo <- blockNo <-
    chosen_attr_type <- correct <- rt <- timedout <- ID <- learningCondition <-
    interventionCondition <- NULL

  # Load learning task data
  data_long_all <- read.csv(file = paste0(pth, task_ver, "-learning-task-data-anon.csv")) |>
    dplyr::select(-X) |>
    dplyr::arrange(uid, trialNo) |>
    dplyr::filter(timedout == FALSE)

  if (!is.null(ids)) data_long_all <- data_long_all |> dplyr::filter(uid %in% ids)

  ## get number of time points etc
  if (!learn) {
    nPpts <- length(unique(data_long_all$uid))
    nTrials_all <- data_long_all |>
      dplyr::arrange(uid) |>
      dplyr::group_by(uid) |>
      dplyr::summarize(nTrials = dplyr::n()) |>
      dplyr::mutate(ID = seq(1, nPpts, 1))          # assign sequential numeric uids for ease / anonymity
    data_long_all <- merge(data_long_all, nTrials_all, by="uid")
  } else if (!is.null(ids)) {
    data_long_all <- data_long_all |>
      dplyr::select(-ID) |>
      dplyr::filter(uid %in% ids) |>
      dplyr::group_by(uid) |>
      dplyr::mutate(ID = dplyr::cur_group_id()) |>
      dplyr::ungroup()
  }

  # Common processing for both studies
  data_long_all_learning <- data_long_all |>
    dplyr::select(uid, ID, trialNo, itemNo, blockNo, valence, chosen_attr_type, correct, rt) |>
    dplyr::mutate(
      valence01 = ifelse(valence == "negative", 0,  ifelse(valence == "positive", 1, NA)),
      choiceIG = ifelse(chosen_attr_type == "internal_global", 2, 1),
      choiceIG01 = ifelse(chosen_attr_type == "internal_global", 1, 0)
    ) |>
    dplyr::group_by(uid) |>
    dplyr::mutate(newTrialNo = seq_len(dplyr::n())) |>
    dplyr::ungroup() |>
    dplyr::arrange(uid)

  # Load choice data
  data_long_all_choice <- read.csv(file=paste0(pth, task_ver, "-causal-attribution-task-data-anon.csv")) |>
    dplyr::select(-X) |>
    dplyr::arrange(uid)

  if (!is.null(ids)) {
    data_long_all_choice <- data_long_all_choice |>
      dplyr::select(-ID) |>
      dplyr::filter(uid %in% ids) |>
      dplyr::group_by(uid) |>
      dplyr::mutate(ID = dplyr::cur_group_id()) |>
      dplyr::ungroup()
  }

  # Process choice data with study-specific handling
  if (learn) {
    data_long_all_choice <- data_long_all_choice |>
      dplyr::mutate(sess = taskNo + 1, neg_pos = ifelse(valence == "negative", 0, 1))
  }

  # Check alignment
  nPpts_c <- length(unique(data_long_all_learning$uid))
  nPpts_l <- length(unique(data_long_all_choice$uid))
  if (nPpts_c != nPpts_l) {
    warning("Number of participants in learning and choice data don't match!")
  }

  # Organize data for rstan
  nPpts <- nPpts_c
  nTrials_max_l <- max(data_long_all_learning$newTrialNo)
  nTrials_max_c <- max(data_long_all_choice$nTrials)
  nTimes <- max(data_long_all_choice$sess)

  # Create arrays for data
  blockNo <- valence <- choiceIG <- choiceIG01 <- outcome <- array(0, dim = c(nPpts, nTrials_max_l))
  nT_ppts_l <- array(nTrials_max_l, dim = c(nPpts))

  internalChosen_neg <- internalChosen_pos <- globalChosen_neg <-
    globalChosen_pos <- array(0, dim = c(nPpts, nTimes, nTrials_max_c/2))
  nT_ppts_c <- array(nTrials_max_c, dim = c(nPpts, nTimes))

  # Fill arrays with participant data
  for (p in 1:nPpts) {
    blockNo[p, ]   <- with(data_long_all_learning, blockNo[ID == p])
    valence[p, ]   <- with(data_long_all_learning, valence01[ID == p])
    choiceIG[p, ]  <- with(data_long_all_learning, choiceIG[ID == p])
    choiceIG01[p, ] <- with(data_long_all_learning, choiceIG01[ID == p])
    outcome[p, ]   <- with(data_long_all_learning, correct[ID == p])

    for (t in 1:nTimes) {
      internalChosen_neg[p, t, ] <- with(data_long_all_choice, internalChosen[ID==p & sess==t & neg_pos==0])
      internalChosen_pos[p, t, ] <- with(data_long_all_choice, internalChosen[ID==p & sess==t & neg_pos==1])
      globalChosen_neg[p, t, ] <- with(data_long_all_choice, globalChosen[ID==p & sess==t & neg_pos==0])
      globalChosen_pos[p, t, ] <- with(data_long_all_choice, globalChosen[ID==p & sess==t & neg_pos==1])
    }
  }

  # Get condition information
  if (learn) {
    # For study 2 (with intervention and learning conditions)
    int_conds <- data_long_all_choice |>
      dplyr::arrange(ID) |>
      dplyr::group_by(ID) |>
      dplyr::select(ID, interventionCondition) |>
      dplyr::distinct() |>
      dplyr::mutate(condition01 = ifelse(interventionCondition == "psychoed", 1, 0))

    learn_conds <- data_long_all_choice |>
      dplyr::arrange(ID) |>
      dplyr::group_by(ID) |>
      dplyr::select(ID, learningCondition) |>
      dplyr::distinct() |>
      dplyr::mutate(condition01 = ifelse(learningCondition == "causal", 1, 0))

    # Create data list with both condition types
    data_list <- list(
      # overall data
      nPpts = nPpts,
      nTimes = nTimes,
      # learning task data
      nTrials_max_l = nTrials_max_l,
      nT_ppts_l = nT_ppts_l,
      blockNo = blockNo,
      valence = valence,
      nChoices_l = 2,
      choice = choiceIG,
      outcome = outcome,
      # causal attribution task data
      nTrials_max_c = nTrials_max_c/2,
      nT_ppts_c = nT_ppts_c/2,
      int_condition = int_conds$condition01,
      learn_condition = learn_conds$condition01,
      internal_neg = internalChosen_neg,
      internal_pos = internalChosen_pos,
      global_neg = globalChosen_neg,
      global_pos = globalChosen_pos
    )
  } else {
    # For study 1 (with only intervention condition)
    int_conds <- data_long_all_choice |>
      dplyr::arrange(ID) |>
      dplyr::group_by(ID) |>
      dplyr::select(ID, condition) |>
      dplyr::distinct() |>
      dplyr::mutate(condition01 = ifelse(condition == "psychoed", 1, 0))

    # Create data list with only intervention condition
    data_list <- list(
      # overall
      nPpts = nPpts,
      nTimes = nTimes,
      # learning task data
      nTrials_max_l = nTrials_max_l,
      nT_ppts_l = nT_ppts_l,
      blockNo = blockNo,
      valence = valence,
      nChoices_l = 2,
      choice = choiceIG,
      outcome = outcome,
      # causal attribution task data
      nTrials_max_c = nTrials_max_c/2,
      nT_ppts_c = nT_ppts_c/2,
      condition = int_conds$condition01,
      internal_neg = internalChosen_neg,
      internal_pos = internalChosen_pos,
      global_neg = globalChosen_neg,
      global_pos = globalChosen_pos
    )
  }

  return(data_list)
}

# For study 1
dl_joint_s1 <- get_stan_data_joint(pth_s1, "causal-attr-1-2", learn = FALSE)
# For study 2
dl_joint_s2 <- get_stan_data_joint(pth_s2, "causal-attr-learn", learn = TRUE)

## Table S3: joint model 1 for study 1
## joint model 1:
model_s3 <- "m_bernoulli_negpos_IGcorr2_multisess_intervention_additive_joint_Qlearning4_bothg_IG"

## fit model using rstan
fit_m3 <- rstan::stan(
  file = paste0(pth_s1, "/stan-models/", model_s3, ".stan"),
  data = dl_joint_s1,
  chains = 4,
  warmup = 2000,
  iter = 4000,
  cores = 4
)
# c <- posterior::as_draws_df(fit)
# b <- posterior::summarise_draws(c)
## save
saveRDS(fit_m3, file = paste0(pth_s1, "stan-fits/", model_s3, "-", "causal-attr-1-2-fit.rds"))

# # get params
# m3_lr <- fit_m3 |>
#   tidybayes::spread_draws(`alpha_pos\\[\\d+\\]`, regex=TRUE) |>
#   dplyr::select(1:200)
# sd_alpha_pos <- apply(m3_lr, 1, sd)
# m3_draws <- fit_m3 |>
#   rstan::extract(
#     pars = c(
#       "theta_int_internal_neg", "theta_int_internal_pos", "theta_int_global_neg",
#       "theta_int_global_pos", "beta_both_internal", "beta_both_global",
#       "pars_sigma_pos[3]", "pars_sigma_pos[4]"
#     )
#   ) |>
#   posterior::as_draws_df() |>
#   dplyr::mutate(
#     alpha_pos_sd = sd_alpha_pos,
#     beta_both_internal = alpha_pos_sd/sqrt(`pars_sigma_pos[3]`) * beta_both_internal,
#     beta_both_global = alpha_pos_sd/sqrt(`pars_sigma_pos[4]`) * beta_both_global
#   )
params_m3_qcis <- rstan::summary(
  fit_m3,
  pars = c(
    "theta_int_internal_neg", "theta_int_internal_pos", "theta_int_global_neg",
    "theta_int_global_pos", "beta_both_internal", "beta_both_global"
  ),
  probs = c(0.025, 0.05, 0.95, 0.975)
)$summary
params_m3_qcis[5:6, 1:7] <- params_m3_qcis[5:6, 1:7] / 100
pm3_tb <- tibble::as_tibble(params_m3_qcis) |>
  # round to 3 d.p.
  dplyr::select(-2) |> # remove se(mean)
  dplyr::rowwise() |>
  dplyr::mutate(
    dplyr::across(
      tidyselect::where(is.numeric),
      ~ round_tb(.x, digits = 3, nsmall = 3)
    )
  )
write.csv(
  pm3_tb,
  file = paste0(pth_s1, "stan-fits/", model_s3, "-", "causal-attr-1-2-summary.csv"),
  row.names = FALSE
)

## Table S4: joint model 1 for study 2
model_s4 <- "m_bernoulli_negpos_IGcorr2_multisess_intervention_additive_joint_Qlearning4_bothg_IG_seplearning"

## fit model using rstan
fit_m4 <- rstan::stan(
  file = paste0(pth_s2, "/stan-models/", model_s4, ".stan"),
  data = dl_joint_s2,
  chains = 4,
  warmup = 2000,
  iter = 4000,
  cores = 4
)
# c <- posterior::as_draws_df(fit)
# b <- posterior::summarise_draws(c)
## save
saveRDS(fit_m4, file = paste0(pth_s2, "stan-fits/", model_s4, "-", "causal-attr-learn-fit.rds"))

params_m4_qcis <- rstan::summary(
  fit_m4,
  pars = c(
    "theta_int_internal_neg", "theta_int_internal_pos", "theta_int_global_neg",
    "theta_int_global_pos", "theta_learn_internal_neg", "theta_learn_internal_pos",
    "theta_learn_global_neg", "theta_learn_global_pos", "beta_causal_internal",
    "beta_causal_global", "beta_control_internal", "beta_control_global"
  ),
  probs = c(0.025, 0.05, 0.95, 0.975)
)$summary
params_m4_qcis[9:12, 1:7] <- params_m4_qcis[9:12, 1:7] / 100
pm4_tb <- tibble::as_tibble(params_m4_qcis) |>
  # round to 3 d.p.
  dplyr::select(-2) |> # remove se(mean)
  dplyr::rowwise() |>
  dplyr::mutate(
    dplyr::across(
      tidyselect::where(is.numeric),
      ~ round_tb(.x, digits = 3, nsmall = 3)
    )
  )
write.csv(
  pm4_tb,
  file = paste0(pth_s2, "stan-fits/", model_s4, "-", "causal-attr-learn-summary.csv"),
  row.names = FALSE
)

## Table S5: joint model 2 for study 1
model_s5 <- "m_bernoulli_negpos_IGcorr2_multisess_intervention_additive_joint_Qlearning4_bothg_activ_IG"

## fit model using rstan
fit_m5 <- rstan::stan(
  file = paste0(pth_s1, "/stan-models/", model_s5, ".stan"),
  data = dl_joint_s1,
  chains = 4,
  warmup = 2000,
  iter = 4000,
  cores = 4
)
# c <- posterior::as_draws_df(fit_m5)
# b <- posterior::summarise_draws(c)
## save
saveRDS(fit_m5, file = paste0(pth_s1, "stan-fits/", model_s5, "-", "causal-attr-1-2-fit.rds"))

# # get params
params_m5_qcis <- rstan::summary(
  fit_m5,
  pars = c(
    "theta_int_internal_neg", "theta_int_internal_pos", "theta_int_global_neg",
    "theta_int_global_pos", "beta_both_internal", "beta_both_global",
    "beta_activ_internal", "beta_activ_global"
  ),
  probs = c(0.025, 0.05, 0.95, 0.975)
)$summary
params_m5_qcis[5:8, 1:7] <- params_m5_qcis[5:8, 1:7] / 100
pm5_tb <- tibble::as_tibble(params_m5_qcis) |>
  # round to 3 d.p.
  dplyr::select(-2) |> # remove se(mean)
  dplyr::rowwise() |>
  dplyr::mutate(
    dplyr::across(
      tidyselect::where(is.numeric),
      ~ round_tb(.x, digits = 3, nsmall = 3)
    )
  )
write.csv(
  pm5_tb,
  file = paste0(pth_s1, "stan-fits/", model_s5, "-", "causal-attr-1-2-summary.csv"),
  row.names = FALSE
)

## Table S6: joint model 2 for study 2
model_s6 <- "m_bernoulli_negpos_IGcorr2_multisess_intervention_additive_joint_Qlearning4_bothg_IG_seplearning_activ2"

## fit model using rstan
fit_m6 <- rstan::stan(
  file = paste0(pth_s2, "/stan-models/", model_s6, ".stan"),
  data = dl_joint_s2,
  chains = 4,
  warmup = 2000,
  iter = 4000,
  cores = 4
)
# c <- posterior::as_draws_df(fit_m6)
# b <- posterior::summarise_draws(c)
## save
saveRDS(fit_m6, file = paste0(pth_s2, "stan-fits/", model_s6, "-", "causal-attr-learn-fit.rds"))

# # get params
params_m6_qcis <- rstan::summary(
  fit_m6,
  pars = c(
    "theta_int_internal_neg", "theta_int_internal_pos", "theta_int_global_neg",
    "theta_int_global_pos", "theta_learn_internal_neg", "theta_learn_internal_pos",
    "theta_learn_global_neg", "theta_learn_global_pos", "beta_causal_internal",
    "beta_causal_global", "beta_causal_activ_internal", "beta_causal_activ_global",
    "beta_control_internal", "beta_control_global"
  ),
  probs = c(0.025, 0.05, 0.95, 0.975)
)$summary
params_m6_qcis[9:14, 1:7] <- params_m6_qcis[9:14, 1:7] / 100
pm6_tb <- tibble::as_tibble(params_m6_qcis) |>
  # round to 3 d.p.
  dplyr::select(-2) |> # remove se(mean)
  dplyr::rowwise() |>
  dplyr::mutate(
    dplyr::across(
      tidyselect::where(is.numeric),
      ~ round_tb(.x, digits = 3, nsmall = 3)
    )
  )
write.csv(
  pm6_tb,
  file = paste0(pth_s2, "stan-fits/", model_s6, "-", "causal-attr-learn-summary.csv"),
  row.names = FALSE
)

## Supplementary analysis in depressed participants ----------------------------
self_rep_s1 <- read.csv(file = paste0(pth_s1, "causal-attr-1-2-self-report-data-anon.csv"))
hi_phq9_s1 <- self_rep_s1 |>
  dplyr::filter(PHQ9_total >= 10) |>
  dplyr::pull(uid)

self_rep_s2 <- read.csv(file = paste0(pth_s2, "causal-attr-learn-self-report-data-anon.csv"))
hi_phq9_s2 <- self_rep_s2 |>
  dplyr::filter(PHQ9_total >= 10) |>
  dplyr::pull(uid)

# For study 1
dl_joint_s1_dep <- get_stan_data_joint(pth_s1, "causal-attr-1-2", learn = FALSE, ids = hi_phq9_s1)
# For study 2
dl_joint_s2_dep <- get_stan_data_joint(pth_s2, "causal-attr-learn", learn = TRUE, ids = hi_phq9_s2)

## joint model 1:
model_s3 <- "m_bernoulli_negpos_IGcorr2_multisess_intervention_additive_joint_Qlearning4_bothg_IG"

## fit model using rstan
fit_m3_dep <- rstan::stan(
  file = paste0(pth_s1, "/stan-models/", model_s3, ".stan"),
  data = dl_joint_s1_dep,
  chains = 4,
  warmup = 2000,
  iter = 4000,
  cores = 4
)
# c <- posterior::as_draws_df(fit_m3_dep)
# b <- posterior::summarise_draws(c)
## save
saveRDS(fit_m3_dep, file = paste0(pth_s1, "stan-fits/", model_s3, "-", "causal-attr-1-2-fit-depr-subsamp.rds"))

# get params
m3_dep_subsamp <- rstan::summary(
  fit_m3_dep,
  pars = c(
    "theta_int_internal_neg", "theta_int_internal_pos", "theta_int_global_neg",
    "theta_int_global_pos", "beta_both_internal", "beta_both_global"
  ),
  probs = c(0.025, 0.05, 0.95, 0.975)
)$summary
m3_dep_subsamp[5:6, 1:7] <- m3_dep_subsamp[5:6, 1:7] / 100
pm3_dep_subsamp_tb <- tibble::as_tibble(m3_dep_subsamp) |>
  # round to 3 d.p.
  dplyr::select(-2) |> # remove se(mean)
  dplyr::rowwise() |>
  dplyr::mutate(
    dplyr::across(
      tidyselect::where(is.numeric),
      ~ round_tb(.x, digits = 3, nsmall = 3)
    )
  )
write.csv(
  pm3_dep_subsamp_tb,
  file = paste0(pth_s1, "stan-fits/", model_s3, "-", "causal-attr-1-2-summary-depr-subsamp.csv"),
  row.names = FALSE
)

# Study 2
## fit model using rstan
model_s4 <- "m_bernoulli_negpos_IGcorr2_multisess_intervention_additive_joint_Qlearning4_bothg_IG_seplearning"
fit_m4_dep <- rstan::stan(
  file = paste0(pth_s2, "/stan-models/", model_s4, ".stan"),
  data = dl_joint_s2_dep,
  chains = 4,
  warmup = 2000,
  iter = 4000,
  cores = 4
)

# save
saveRDS(fit_m4_dep, file = paste0(pth_s2, "stan-fits/", model_s4, "-", "causal-attr-learn-fit-depr-subsamp.rds"))

# get params
m4_dep_subsamp <- rstan::summary(
  fit_m4_dep,
  pars = c(
    "theta_int_internal_neg", "theta_int_internal_pos", "theta_int_global_neg",
    "theta_int_global_pos", "theta_learn_internal_neg", "theta_learn_internal_pos",
    "theta_learn_global_neg", "theta_learn_global_pos", "beta_causal_internal",
    "beta_causal_global", "beta_control_internal", "beta_control_global"
  ),
  probs = c(0.025, 0.05, 0.95, 0.975)
)$summary
m4_dep_subsamp[9:12, 1:7] <- m4_dep_subsamp[9:12, 1:7] / 100
pm4_dep_subsamp_tb <- tibble::as_tibble(m4_dep_subsamp) |>
  # round to 3 d.p.
  dplyr::select(-2) |> # remove se(mean)
  dplyr::rowwise() |>
  dplyr::mutate(
    dplyr::across(
      tidyselect::where(is.numeric),
      ~ round_tb(.x, digits = 3, nsmall = 3)
    )
  )
write.csv(
  pm4_dep_subsamp_tb,
  file = paste0(pth_s2, "stan-fits/", model_s4, "-", "causal-attr-learn-summary-depr-subsamp.csv"),
  row.names = FALSE
)