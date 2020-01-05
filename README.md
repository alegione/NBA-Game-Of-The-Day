# NBA-Game-Of-The-Day
A shiny web application that ranks daily NBA games for your viewing pleasure

Currently in alpha form, please feel free to submit comments, suggestions, or pull requests

All data comes from the [NBA Stats API](https://stats.nba.com/), and all data and team logos images belong to the NBA.



## Run your own local version

You can run 'NBA Game of the Day' on your own computer. Hopefully one day it will be available online.

To run, start by installing the programming language [R](https://cran.rstudio.com/) and the GUI interface [RStudio](https://rstudio.com/products/rstudio/download/)

Then either clone this repo and run the RunShiny.R script



OR run the below commands in the terminal
```R
packages = c("shiny", "jsonlite", "dplyr", "DT", "curl", "httr")
install.packages(packages, repos = "https://cran.rstudio.com/")
library(shiny)
runGitHub("NBA-Game-Of-The-Day", "alegione")
```

This will download and run the Shiny application locally