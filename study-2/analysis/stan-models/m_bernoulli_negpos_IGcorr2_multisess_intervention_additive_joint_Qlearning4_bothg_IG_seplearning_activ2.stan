
data {
  // overall
  int nTimes;                                  // number of time points (sessions)
  int nPpts;                                   // number of participants
  
  // choice task data
  int nTrials_max_c;                           // maximum number of trials per participant per session
  int nT_ppts_c[nPpts, nTimes];                // actual number of trials per participant per session
  int<lower=0, upper=1> int_condition[nPpts];                              // intervention condition for each participant
  int<lower=0, upper=1> learn_condition[nPpts];                              // intervention condition for each participant
  int<lower=0, upper=1> internal_neg[nPpts, nTimes, nTrials_max_c];    // responses for each participant per session 
  int<lower=0, upper=1> internal_pos[nPpts, nTimes, nTrials_max_c];    // responses for each participant per session 
  int<lower=0, upper=1> global_neg[nPpts, nTimes, nTrials_max_c];      // responses for each participant per session 
  int<lower=0, upper=1> global_pos[nPpts, nTimes, nTrials_max_c];      // responses for each participant per session 

  // learning task data
  int nTrials_max_l;                 // maximum number of trials per participant
  int nT_ppts_l[nPpts];              // actual number of trials per participant
  int nChoices_l;                    // number of choice options
  int<lower=1, upper=4> blockNo[nPpts, nTrials_max_l];     // choice array is a function of block
  int<lower=0, upper=1> valence[nPpts, nTrials_max_l];     // 0 = negative, 1 = positive
  int<lower=1, upper=2>  choice[nPpts, nTrials_max_l];     // chosen option
  int<lower=0, upper=1> outcome[nPpts, nTrials_max_l];     // 0 = incorrect, 1 = correct
}

parameters {
  ////////////////////////////choice task parameters////////////////////////
  // group-level correlation matrix (cholesky factor for faster computation)
  // across timepoints and two parameters
  cholesky_factor_corr[4] R_chol_theta_neg; 
  cholesky_factor_corr[4] R_chol_theta_pos; 
  
  // group-level parameters
  // means for each parameter and timepoint
  vector[nTimes] mu_internal_theta_neg;
  vector[nTimes] mu_internal_theta_pos;
  vector[nTimes] mu_global_theta_neg;
  vector[nTimes] mu_global_theta_pos;
  
  // sds for each parameter and timepoint
  vector<lower=0>[4] pars_sigma_neg; 
  vector<lower=0>[4] pars_sigma_pos; 
  
  // individual-level parameters (raw/untransformed values)
  matrix[4,nPpts] pars_pr_neg; 
  matrix[4,nPpts] pars_pr_pos; 
  
  // group-level effects of active intervention at t2 (group level)
  real theta_int_internal_neg;
  real theta_int_internal_pos;
  real theta_int_global_neg;
  real theta_int_global_pos;
  
  // group-level effects of having done the learning task at t2 (group level)
  real theta_learn_internal_neg;
  real theta_learn_internal_pos;
  real theta_learn_global_neg;
  real theta_learn_global_pos;
  
  // beta weights for intervention effects
  real beta_causal_internal; 
  real beta_causal_global; 
  real beta_causal_activ_internal; 
  real beta_causal_activ_global; 

  // beta weights for learning task effects
  real beta_control_internal; 
  real beta_control_global; 
  
  ///////////////////////learning task parameters////////////////////////////
  // group-level parameters
  vector[13] mu_p;                   // group-level parameter means
  vector<lower=0>[13] sigma_p;       // group-level parameter sigmas (must be positive)
  
  // participant-level parameters (raw/untransformed values)
  vector[nPpts] alpha_neg_raw; 
  vector[nPpts] alpha_pos_raw;  
  vector[nPpts] beta_raw;
  vector[nPpts] q0_1_IG_neg_raw;
  vector[nPpts] q0_1_IG_pos_raw;
  vector[nPpts] q0_23_IG_neg_raw;
  vector[nPpts] q0_23_IG_pos_raw;
}

transformed parameters {
  ////////////////////////////choice task parameters////////////////////////
  // individual-level parameter off-sets (for non-centered parameterization)
  matrix[4,nPpts] pars_tilde_neg;
  matrix[4,nPpts] pars_tilde_pos;
  
  // individual-level parameters (transformed values)
  matrix[nPpts,2] theta_internal_neg;
  matrix[nPpts,2] theta_internal_pos;
  matrix[nPpts,2] theta_global_neg;
  matrix[nPpts,2] theta_global_pos;
  
  ///////////////////////learning task parameters////////////////////////////
  // participant-level parameters (transformed values)
  vector[nPpts] alpha_neg; 
  vector[nPpts] alpha_pos;  
  vector[nPpts] beta;
  vector[nPpts] q0_1_IG_neg;
  vector[nPpts] q0_1_IG_pos;
  vector[nPpts] q0_23_IG_neg;
  vector[nPpts] q0_23_IG_pos;
  
  // construct individual offsets (for non-centered parameterization)
  // with potential correlation for parameters across timepoints
  // and potential correlation between internal-global parameter estimates
  pars_tilde_neg = diag_pre_multiply(pars_sigma_neg, R_chol_theta_neg) * pars_pr_neg;
  pars_tilde_pos = diag_pre_multiply(pars_sigma_pos, R_chol_theta_pos) * pars_pr_pos;
  
  // compute individual-level parameters from non-centered parameterization
  for ( p in 1:nPpts ) {
    // learning task params:
    // separate group means for causal and control learning task alphas and q0s
    if ( learn_condition[p] == 1 ) {
      alpha_neg[p] = Phi_approx(mu_p[1] + sigma_p[1] * alpha_neg_raw[p]);      // implies alpha ~ normal(mu_alpha, sigma_alpha), constrained to be in range [0,1]
      alpha_pos[p] = Phi_approx(mu_p[2] + sigma_p[2] * alpha_pos_raw[p]);      // implies alpha ~ normal(mu_alpha, sigma_alpha), constrained to be in range [0,1]
      q0_1_IG_neg[p] = (mu_p[3] + sigma_p[3] * q0_1_IG_neg_raw[p]);
      q0_1_IG_pos[p] = (mu_p[4] + sigma_p[4] * q0_1_IG_pos_raw[p]);
      q0_23_IG_neg[p] = (mu_p[5] + sigma_p[5] * q0_23_IG_neg_raw[p]);
      q0_23_IG_pos[p] = (mu_p[6] + sigma_p[6] * q0_23_IG_pos_raw[p]);
    } else {
      alpha_neg[p] = Phi_approx(mu_p[7] + sigma_p[7] * alpha_neg_raw[p]);      // implies alpha ~ normal(mu_alpha, sigma_alpha), constrained to be in range [0,1]
      alpha_pos[p] = Phi_approx(mu_p[8] + sigma_p[8] * alpha_pos_raw[p]);      // implies alpha ~ normal(mu_alpha, sigma_alpha), constrained to be in range [0,1]
      q0_1_IG_neg[p] = (mu_p[9] + sigma_p[9] * q0_1_IG_neg_raw[p]);
      q0_1_IG_pos[p] = (mu_p[10] + sigma_p[10] * q0_1_IG_pos_raw[p]);
      q0_23_IG_neg[p] = (mu_p[11] + sigma_p[11] * q0_23_IG_neg_raw[p]);
      q0_23_IG_pos[p] = (mu_p[12] + sigma_p[12] * q0_23_IG_pos_raw[p]);
    }
    beta[p]   = Phi_approx(mu_p[13] + sigma_p[13] * beta_raw[p])*20; 
    
    // choice task params:
    // negative events at time 1
    theta_internal_neg[p,1] = mu_internal_theta_neg[1] + pars_tilde_neg[1,p];
    theta_global_neg[p,1]   = mu_global_theta_neg[1]   + pars_tilde_neg[2,p];
    // negative events time 2
    if ( int_condition[p] == 1  && learn_condition[p] == 1 ) {
      // for active intervention participants who completed the learning task
      theta_internal_neg[p,2] = mu_internal_theta_neg[2] + pars_tilde_neg[3,p] + theta_int_internal_neg + theta_learn_internal_neg;
      theta_global_neg[p,2]   = mu_global_theta_neg[2]   + pars_tilde_neg[4,p] + theta_int_global_neg + theta_learn_global_neg;
    } else if ( int_condition[p] == 1  && learn_condition[p] == 0 ) {
      // for active intervention participants who didn't complete the learning task
      theta_internal_neg[p,2] = mu_internal_theta_neg[2] + pars_tilde_neg[3,p] + theta_int_internal_neg;
      theta_global_neg[p,2]   = mu_global_theta_neg[2]   + pars_tilde_neg[4,p] + theta_int_global_neg;
    } else if ( int_condition[p] == 0  && learn_condition[p] == 1 ) {
      // for control intervention participants who completed the learning task
      theta_internal_neg[p,2] = mu_internal_theta_neg[2] + pars_tilde_neg[3,p] + theta_learn_internal_neg;
      theta_global_neg[p,2]   = mu_global_theta_neg[2]   + pars_tilde_neg[4,p] + theta_learn_global_neg;
    }
    
    // positive events at time 1
    theta_internal_pos[p,1] = mu_internal_theta_pos[1] + pars_tilde_pos[1,p];
    theta_global_pos[p,1]   = mu_global_theta_pos[1]   + pars_tilde_pos[2,p];
    // positive events at time 2
    if ( int_condition[p] == 1  && learn_condition[p] == 1 ) {
      // for active intervention participants who completed the learning task
      theta_internal_pos[p,2] = mu_internal_theta_pos[2] + pars_tilde_pos[3,p] + theta_int_internal_pos + theta_learn_internal_pos + beta_causal_internal*alpha_pos[p] + beta_causal_activ_internal*alpha_pos[p];
      theta_global_pos[p,2]   = mu_global_theta_pos[2]   + pars_tilde_pos[4,p] + theta_int_global_pos + theta_learn_global_pos + beta_causal_global*alpha_pos[p] + beta_causal_activ_global*alpha_pos[p];
    } else if ( int_condition[p] == 1  && learn_condition[p] == 0 ) {
      // for active intervention participants who did the control learning task
      theta_internal_pos[p,2] = mu_internal_theta_pos[2] + pars_tilde_pos[3,p] + theta_int_internal_pos + beta_control_internal*alpha_pos[p];
      theta_global_pos[p,2]   = mu_global_theta_pos[2]   + pars_tilde_pos[4,p] + theta_int_global_pos + beta_control_global*alpha_pos[p];
    } else if ( int_condition[p] == 0  && learn_condition[p] == 1 ) {
      // for control intervention participants who completed the causal learning task
      theta_internal_pos[p,2] = mu_internal_theta_pos[2] + pars_tilde_pos[3,p] + theta_learn_internal_pos + beta_causal_internal*alpha_pos[p];
      theta_global_pos[p,2]   = mu_global_theta_pos[2]   + pars_tilde_pos[4,p] + theta_learn_global_pos + beta_causal_global*alpha_pos[p];
    }
  }
}

model {
  ////////////////////////////learning task model/////////////////////////////
  // declare model variables
  vector[nChoices_l] q_neg[nTrials_max_l+1];           // vectors of q values for choice options for negative items
  vector[nChoices_l] q_pos[nTrials_max_l+1];           // vectors of q values for choice options for positive items
  
  // priors on distribution of group-level parameters
  mu_p ~ normal(0,1);
  sigma_p ~ cauchy(0,1);
  
  // priors on individual participant deviations from group parameter values
  alpha_neg_raw ~ normal(0,1); 
  alpha_pos_raw ~ normal(0,1);  
  beta_raw ~ normal(0,1); 
  q0_1_IG_neg_raw ~ normal(0,1); 
  q0_1_IG_pos_raw ~ normal(0,1); 
  q0_23_IG_neg_raw ~ normal(0,1); 
  q0_23_IG_pos_raw ~ normal(0,1); 
  
  ////////////////////////////choice task model/////////////////////////////
  // uniform [0,1] priors on cholesky factor of correlation matrix
  R_chol_theta_neg ~ lkj_corr_cholesky(1);
  R_chol_theta_pos ~ lkj_corr_cholesky(1);
  
  // define priors on distribution of group-level parameters
  // means
  mu_internal_theta_neg ~ normal(0,1);
  mu_internal_theta_pos ~ normal(0,1);
  mu_global_theta_neg   ~ normal(0,1);
  mu_global_theta_pos   ~ normal(0,1);
    
  // priors on group-level effects of active intervention on theta values at t2
  theta_int_internal_neg ~ normal(0,1);
  theta_int_internal_pos ~ normal(0,1);
  theta_int_global_neg   ~ normal(0,1);
  theta_int_global_pos   ~ normal(0,1);
  
  // priors on group-level effects of causal learning task on theta values at t2
  theta_learn_internal_neg ~ normal(0,1);
  theta_learn_internal_pos ~ normal(0,1);
  theta_learn_global_neg   ~ normal(0,1);
  theta_learn_global_pos   ~ normal(0,1);
  
  // define priors on individual participant deviations from group parameter values
  to_vector(pars_pr_neg) ~ normal(0,1);
  to_vector(pars_pr_pos) ~ normal(0,1);
  
  // loop over observations
  for ( p in 1:nPpts ) {
    
    // learning task model:
    for (t in 1:nT_ppts_l[p]) {
      // if first trial in a block, initialise q values for that block
      if ( t == 1 ) {
        q_neg[t] = [0.5, q0_1_IG_neg[p]]';                  
        q_pos[t] = [0.5, q0_1_IG_pos[p]]';                  
      } else if ( t == 11 || t == 21 ) {
        q_neg[t] = [0.5, q0_23_IG_neg[p]]';                  
        q_pos[t] = [0.5, q0_23_IG_pos[p]]';
      }
      // propagate values forward
      q_neg[t+1] = q_neg[t];
      q_pos[t+1] = q_pos[t];
      
      // valence-specific value updating
      if ( valence[p,t] == 0 ) {
        // choice probability is a function of q values
        choice[p,t] ~ categorical_logit(beta[p] * q_neg[t]);
        // update value of chosen option
        q_neg[t+1, choice[p,t]] = q_neg[t, choice[p,t]] + alpha_neg[p]*(outcome[p,t] - q_neg[t,choice[p,t]]);
      } else {
        // choice probability is a function of q values
        choice[p,t] ~ categorical_logit(beta[p] * q_pos[t]);
        // update value of chosen option
        q_pos[t+1, choice[p,t]] = q_pos[t, choice[p,t]] + alpha_pos[p]*(outcome[p,t] - q_pos[t,choice[p,t]]);
      }
    }
    
    // choice task model:
    // t1
    internal_neg[p,1,:] ~ bernoulli_logit(theta_internal_neg[p,1]);
    internal_pos[p,1,:] ~ bernoulli_logit(theta_internal_pos[p,1]);
    global_neg[p,1,:] ~ bernoulli_logit(theta_global_neg[p,1]);
    global_pos[p,1,:] ~ bernoulli_logit(theta_global_pos[p,1]);
    // t2
    internal_neg[p,2,:] ~ bernoulli_logit(theta_internal_neg[p,2]);
    internal_pos[p,2,:] ~ bernoulli_logit(theta_internal_pos[p,2]);
    global_neg[p,2,:] ~ bernoulli_logit(theta_global_neg[p,2]);
    global_pos[p,2,:] ~ bernoulli_logit(theta_global_pos[p,2]);
  }
}

generated quantities {
  // test-retest correlations
  corr_matrix[4] R_theta_neg;
  corr_matrix[4] R_theta_pos;
  
  // success probability estimates for each individual
  matrix[nPpts, nTimes] p_internal_neg;
  matrix[nPpts, nTimes] p_internal_pos;
  matrix[nPpts, nTimes] p_global_neg;
  matrix[nPpts, nTimes] p_global_pos;
  
  // log_lik over choice dimensions  
  vector[nPpts] log_lik;
  
  // // replicated data
  // int<lower=0, upper=1> Y_neg_rep[nPpts, nTimes, nTrials_max];
  // int<lower=0, upper=1> Y_pos_rep[nPpts, nTimes, nTrials_max];

	// reconstruct correlation matrix from cholesky factors
  R_theta_neg = R_chol_theta_neg * R_chol_theta_neg';
  R_theta_pos = R_chol_theta_pos * R_chol_theta_pos';
  
  // sucess probabilities for participants and sessions
  p_internal_neg = inv_logit(theta_internal_neg);
  p_internal_pos = inv_logit(theta_internal_pos);
  p_global_neg = inv_logit(theta_global_neg);
  p_global_pos = inv_logit(theta_global_pos);

  // loop over observations
	for (p in 1:nPpts){
	 // log_lik of learning data:

   // log_lik of choice data:
   log_lik[p] = bernoulli_logit_lpmf( internal_neg[p,1] | theta_internal_neg[p,1] ) +
                bernoulli_logit_lpmf( internal_pos[p,1] | theta_internal_pos[p,1] ) +
                bernoulli_logit_lpmf( global_neg[p,1]   | theta_global_neg[p,1] ) +
                bernoulli_logit_lpmf( global_pos[p,1]   | theta_global_pos[p,1] ) +
                bernoulli_logit_lpmf( internal_neg[p,2] | theta_internal_neg[p,2] ) +
                bernoulli_logit_lpmf( internal_pos[p,2] | theta_internal_pos[p,2] ) +
                bernoulli_logit_lpmf( global_neg[p,2]   | theta_global_neg[p,2] ) +
                bernoulli_logit_lpmf( global_pos[p,2]   | theta_global_pos[p,2] );
	}
}

