functions {
  real poisson_mix_mortality(int abd_i, real mu, real m) {
    real ll;
    if (abd_i == 0) {
      ll = log_sum_exp(
        [
          2 * log(m),
          log(2) + log(m) + log1m(m) + poisson_log_lpmf(abd_i | mu),
          2 * log1m(m) + poisson_log_lpmf(abd_i | log(2) + mu)
        ]
      );
    } else {
      ll = log_sum_exp(
        log(2) + log(m) + log1m(m) + poisson_log_lpmf(abd_i | mu),
        2 * log1m(m) + poisson_log_lpmf(abd_i | log(2) + mu)
      );
    }
    return ll;
  }
}
data{
  int n;
  real time;
  int nblock;
  int ngenotype;
  array[n] int abd_obs;
  array[n] int<lower=1,upper=ngenotype> genotype_id;
  array[n] int<lower=1,upper=nblock> block_id;
}
parameters {
  real r_bar;
  real sd_total;
  simplex[3] prop_var;
  real<lower=0,upper=1> m;
  // random intercepts
  vector[n] r_pot_z;
  vector[ngenotype] r_genotype_z;
  vector[nblock] r_block_z;
}
transformed parameters {
  vector[3] scale_sd = sqrt(prop_var);
}
model {
  r_bar ~ normal(1.2, .2);
  sd_total ~ exponential(1);
  prop_var ~ dirichlet([2,2,2]);
  r_pot_z ~ std_normal();
  r_genotype_z ~ std_normal();
  r_block_z ~ std_normal();
  m ~ beta(.3*5,(1-.3)*5);
  vector[n] r_pot = r_pot_z*scale_sd[1];
  vector[ngenotype] r_genotype =  r_genotype_z*scale_sd[2];
  vector[nblock] r_block = r_block_z*scale_sd[3];
  vector[n] r = r_bar + r_genotype[genotype_id] + r_block[block_id] + r_pot;
  for (i in 1:n) {
    target += poisson_mix_mortality(abd_obs[i], r[i]*time, m);
  }
}
