# compile_stan_models.R
#
# Run this script once on the Posit Cloud base project to compile all Stan
# models. Compiled outputs are saved alongside each .stan file so that student
# projects (copied from the base) can reuse them without recompiling.
#
# rstan models  → saved as <model>.rds via auto_write = TRUE
# cmdstanr models → compiled executable saved in the same directory
#
# Usage (from project root):
#   source("compile_stan_models.R")

library(rstan)
library(cmdstanr)

rstan_options(auto_write = TRUE)
options(mc.cores = parallel::detectCores())

# ── Find all .stan files ──────────────────────────────────────────────────────

stan_files <- list.files(
  path       = "topics",
  pattern    = "\\.stan$",
  recursive  = TRUE,
  full.names = TRUE
)

cat(sprintf("Found %d Stan files.\n\n", length(stan_files)))

# ── Identify which backend each file uses ────────────────────────────────────
# Scan the .qmd files to see which models are called via cmdstan_model() vs
# stan_model(), then route each .stan file to the right compiler.

qmd_text <- paste(
  sapply(
    list.files("topics", pattern = "\\.qmd$", recursive = TRUE, full.names = TRUE),
    readLines, warn = FALSE
  ),
  collapse = "\n"
)

# Extract the .stan filenames referenced in cmdstan_model() calls
cmdstan_pattern <- 'cmdstan_model\\([^)]*?"([^"]+\\.stan)"'
cmdstan_refs <- regmatches(qmd_text, gregexpr(cmdstan_pattern, qmd_text))[[1]]
cmdstan_files <- regmatches(
  cmdstan_refs,
  regexpr('"[^"]+\\.stan"', cmdstan_refs)
)
cmdstan_files <- gsub('"', "", cmdstan_files)
cmdstan_files <- basename(cmdstan_files)

is_cmdstan <- basename(stan_files) %in% cmdstan_files

# ── Compile ───────────────────────────────────────────────────────────────────

results <- data.frame(
  file    = stan_files,
  backend = ifelse(is_cmdstan, "cmdstanr", "rstan"),
  status  = NA_character_
)

for (i in seq_along(stan_files)) {
  f       <- stan_files[i]
  backend <- results$backend[i]
  cat(sprintf("[%d/%d] %s  (%s) ... ", i, length(stan_files), f, backend))

  tryCatch({
    if (backend == "rstan") {
      stan_model(file = f)   # auto_write saves <f>.rds alongside
    } else {
      cmdstan_model(stan_file = f, dir = dirname(f))
    }
    results$status[i] <- "ok"
    cat("OK\n")
  }, error = function(e) {
    results$status[i] <<- paste("ERROR:", conditionMessage(e))
    cat("FAILED\n  ", conditionMessage(e), "\n")
  })
}

# ── Summary ───────────────────────────────────────────────────────────────────

cat("\n── Compilation summary ──────────────────────────────────────────────────\n")
ok   <- sum(results$status == "ok")
fail <- sum(results$status != "ok")
cat(sprintf("  Succeeded : %d\n  Failed    : %d\n\n", ok, fail))

if (fail > 0) {
  cat("Failed models:\n")
  print(results[results$status != "ok", c("file", "status")])
}
