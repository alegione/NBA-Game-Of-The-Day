required_packages = c("shiny", "jsonlite", "dplyr", "DT", "curl", "httr")

packages_to_install = required_packages[!(required_packages %in% installed.packages()[, 1])]

if (length(packages_to_install) > 0) {
  install.packages(packages_to_install, repos = "https://cran.rstudio.com/")
}

library(shiny)

runGitHub("NBA-Game-Of-The-Day", "alegione")
