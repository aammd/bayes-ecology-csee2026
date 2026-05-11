# check_stan_files.R
#
# Run locally before pushing to GitHub to confirm that:
#   1. All .stan files are tracked by git (not excluded by .gitignore)
#   2. Compiled artifacts (.rds, executables) are NOT tracked (intentional)
#
# Usage: source("check_stan_files.R")

stan_files <- list.files(
  path = "topics", pattern = "\\.stan$",
  recursive = TRUE, full.names = TRUE
)

# Ask git which of these are tracked
tracked <- system2("git", c("ls-files", "--error-unmatch", stan_files),
                   stdout = TRUE, stderr = FALSE)

tracked_files   <- stan_files[stan_files %in% tracked]
untracked_files <- stan_files[!stan_files %in% tracked]

cat(sprintf("Stan files tracked by git  : %d\n", length(tracked_files)))
cat(sprintf("Stan files NOT tracked     : %d\n", length(untracked_files)))

if (length(untracked_files) > 0) {
  cat("\nThe following .stan files are excluded by .gitignore and will NOT\n")
  cat("be available on Posit Cloud. Add them or adjust .gitignore:\n\n")
  cat(paste(" ", untracked_files, collapse = "\n"), "\n")
} else {
  cat("\nAll .stan files are tracked. Safe to push.\n")
}

# Remind about compiled artifacts
rds_files <- list.files("topics", pattern = "\\.rds$",
                        recursive = TRUE, full.names = TRUE)
if (length(rds_files) > 0) {
  cat(sprintf(
    "\nNote: %d compiled .rds file(s) exist locally but are excluded from git.\n",
    length(rds_files)
  ))
  cat("They will be recreated by compile_stan_models.R on Posit Cloud.\n")
}
