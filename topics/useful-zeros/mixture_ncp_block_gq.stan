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
  real<lower=0> sd_pot;
  real<lower=0> sd_genotype;
  real<lower=0> sd_block;
  real<lower=0,upper=1> m;
  // random intercepts
  vector[n] r_pot;
  vector[ngenotype] r_genotype;
  vector<offset=0,multiplier=sd_block>[nblock] r_block;
}
model {
  r_bar ~ normal(1.2, .2);
  m ~ beta(.3*5,(1-.3)*5);
  r_pot ~ normal(0, sd_pot);
  r_genotype ~ normal(0, sd_genotype);
  r_block ~ normal(0, sd_block);
  // hyperparameters
  sd_pot ~ exponential(8);
  sd_genotype ~ exponential(2);
  sd_block ~ exponential(5);
  vector[n] r = r_bar + r_genotype[genotype_id] + r_block[block_id] + r_pot;
  for (i in 1:n) {
    target += poisson_mix_mortality(abd_obs[i], r[i]*time, m);
  }
}
generated quantities {
  vector[n] r = r_bar + r_genotype[genotype_id] + r_block[block_id] + r_pot;
  vector[ngenotype] r_avg_genotype = r_bar + r_genotype;
  real h = sd_genotype^2/(sd_genotype^2 + sd_pot^2 + sd_block^2 + log1p_exp(-r_bar));

  array[n] int yrep;

  for (i in 1:n) {
    real mu = r[i] * time;

    // compute total probability of observing a 0
    real p0_struct = m * m;
    real p0_mix1 = 2 * m * (1 - m) * exp(poisson_log_lpmf(0 | mu));
    real p0_mix2 = (1 - m)^2 * exp(poisson_log_lpmf(0 | log(2) + mu));
    real p0 = p0_struct + p0_mix1 + p0_mix2;

    real u = uniform_rng(0, 1);
    if (u < p0) {
      yrep[i] = 0;
    } else {
      // simulate from mixture of two Poissons, but ensure result is non-zero
      real p1 = 2 * m * (1 - m);
      real p2 = (1 - m)^2;
      real norm = p1 + p2;

      real v = uniform_rng(0, 1);
      int y = 0;
      while (y == 0) {
        if (v < p1 / norm) {
          y = poisson_log_rng(mu);
        } else {
          y = poisson_log_rng(log(2) + mu);
        }
      }
      yrep[i] = y;
    }
  }
}
