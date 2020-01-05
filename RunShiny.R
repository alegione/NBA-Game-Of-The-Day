packages = c("shiny", "jsonlite", "dplyr", "DT", "curl", "httr")
install.packages(packages, repos = "https://cran.rstudio.com/")
library(shiny)
runGitHub("NBA-Game-Of-The-Day", "alegione")
