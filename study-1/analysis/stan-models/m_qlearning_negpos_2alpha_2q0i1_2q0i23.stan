
data {
  int nPpts;                       // number participants
  int nTrials_max;                 // maximum number of trials per participant
  int nT_ppts[nPpts];              // actual number of trials per participant
  int nChoices;
  int blockLength;
  
  int<lower=1, upper=4> blockNo[nPpts, nTrials_max];  // choice array is a function of block
  int<lower=0, upper=1> valence[nPpts, nTrials_max];  // 0 = negative, 1 = positive
  int<lower=1, upper=2>  choice[nPpts, nTrials_max];  // chosen option
  int<lower=0, upper=1> outcome[nPpts, nTrials_max];  // 0 = incorrect, 1 = correct
}

parameters {
  // group-level parameters
  vector[7] mu_p;                   // group-level parameter means
  vector<lower=0>[7] sigma_p;       // group-level parameter sigmas (must be positive)
  
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
  // participant-level parameters (transformed values)
  vector[nPpts] alpha_neg; 
  vector[nPpts] alpha_pos;  
  vector[nPpts] beta;
  vector[nPpts] q0_1_IG_neg;
  vector[nPpts] q0_1_IG_pos;
  vector[nPpts] q0_23_IG_neg;
  vector[nPpts] q0_23_IG_pos;
  
  // transform using non-centered reparameterization since we are using a hierarchical model 
  for (p in 1:nPpts) {
    alpha_neg[p] = Phi_approx(mu_p[1] + sigma_p[1] * alpha_neg_raw[p]);      // implies alpha ~ normal(mu_alpha, sigma_alpha), constrained to be in range [0,1]
    alpha_pos[p] = Phi_approx(mu_p[2] + sigma_p[2] * alpha_pos_raw[p]);      // implies alpha ~ normal(mu_alpha, sigma_alpha), constrained to be in range [0,1]
    beta[p]   = Phi_approx(mu_p[3] + sigma_p[3] * beta_raw[p])*20;           // implies beta ~ normal(mu_beta, sigma_beta), constrained to be in range [0,20]
    q0_1_IG_neg[p] = (mu_p[4] + sigma_p[4] * q0_1_IG_neg_raw[p]);
    q0_1_IG_pos[p] = (mu_p[5] + sigma_p[5] * q0_1_IG_pos_raw[p]);
    q0_23_IG_neg[p] = (mu_p[6] + sigma_p[6] * q0_23_IG_neg_raw[p]);
    q0_23_IG_pos[p] = (mu_p[7] + sigma_p[7] * q0_23_IG_pos_raw[p]);
  }
}

model {
  // declare model variables
  vector[nChoices] q_neg[nTrials_max+1];           // vectors of q values for choice options for negative items
  vector[nChoices] q_pos[nTrials_max+1];           // vectors of q values for choice options for positive items
  
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

  // loop over observations
  for (p in 1:nPpts) {
    // loop over trials that participant completed
    for (t in 1:nT_ppts[p]) {
      
      // if first trial in a block, initialise q values for that block
      //if ( (t-1)/blockLength == 0 ) {     // integer division issues this way
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
  }
}

generated quantities {
  // let's output some key quantities for our model
  //real log_lik[nPpts, nTrials_max];                // log likelihood
  vector[nPpts] log_lik;                             // sum log lik over trials for each ppts
  int y_rep[nPpts, nTrials_max];                     // posterior predictions
  int outcome_sim[nPpts, nTrials_max];             // outcomes for replicate choices
  vector[nChoices] q2_neg[nTrials_max+1];            // values
  vector[nChoices] q2_pos[nTrials_max+1];            // values
  
  // initialize LL and post_pred arrays 
  //log_lik = rep_array(0.0, nPpts, nTrials_max);
  y_rep[nPpts, nTrials_max] = 0;
  
  // loop over observations
  for (p in 1:nPpts) {
    
    // initialise sLL at 0
    log_lik[p] = 0;
    
    for (t in 1:nT_ppts[p]) {
      
      // if first trial in a block, initialise q values for that block
      //if ( (t-1)/blockLength == 0 ) {
      if ( t == 1 ) {
        q2_neg[t] = [0.5, q0_1_IG_neg[p]]';                  
        q2_pos[t] = [0.5, q0_1_IG_pos[p]]';                  
      } else if ( t == 11 || t == 21 ) {
        q2_neg[t] = [0.5, q0_23_IG_neg[p]]';                  
        q2_pos[t] = [0.5, q0_23_IG_pos[p]]';
      }
      
      // propagate values forward
      q2_neg[t+1] = q2_neg[t];
      q2_pos[t+1] = q2_pos[t];
      
      // valence-specific value updating
      if ( valence[p,t] == 0 ) {
        // choice likelihood is a function of q values
        //log_lik[p,t] = categorical_logit_lpmf(choice[p,t] | beta[p] * q2_neg[t]);
        log_lik[p] = log_lik[p] + categorical_logit_lpmf(choice[p,t] | beta[p] * q2_neg[t]);
        // posterior samples
        y_rep[p,t] = categorical_logit_rng(beta[p] * q2_neg[t]);
        // simulate relevant outcome
        if ( y_rep[p,t] == 1 ) {
           outcome_sim[p,t] = 1;
        } else {
           outcome_sim[p,t] = 0;
        }
        //update value of chosen option
        q2_neg[t+1, y_rep[p,t]] = q2_neg[t, y_rep[p,t]] + alpha_neg[p]*(outcome_sim[p,t] - q2_neg[t, y_rep[p,t]]);
        //q2_neg[t+1, y_rep[p,t]] = q2_neg[t, y_rep[p,t]] + alpha_neg[p]*(outcome[p,t] - q2_neg[t, y_rep[p,t]]);
        
      } else {
        // choice likelihood is a function of q values
        //log_lik[p,t] = categorical_logit_lpmf(choice[p,t] | beta[p] * q2_pos[t]);
        log_lik[p] = log_lik[p] + categorical_logit_lpmf(choice[p,t] | beta[p] * q2_pos[t]);
        // posterior samples
        y_rep[p,t] = categorical_logit_rng(beta[p] * q2_pos[t]);
        // simulate relevant outcome
        if ( y_rep[p,t] == 2 ) {
           outcome_sim[p,t] = 1;
        } else {
           outcome_sim[p,t] = 0;
        }
        //update value of chosen option
        q2_pos[t+1, y_rep[p,t]] = q2_pos[t, y_rep[p,t]] + alpha_pos[p]*(outcome_sim[p,t] - q2_pos[t, y_rep[p,t]]);
        //q2_pos[t+1, y_rep[p,t]] = q2_pos[t, y_rep[p,t]] + alpha_pos[p]*(outcome[p,t] - q2_pos[t, y_rep[p,t]]);
      }
      
    }
  }
}


