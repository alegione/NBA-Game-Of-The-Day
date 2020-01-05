# NBA-Game-Of-The-Day
A shiny web application that ranks daily NBA games for your viewing pleasure

Currently in alpha form, please feel free to submit comments, suggestions, or pull requests

All data comes from the [NBA Stats API](https://stats.nba.com/), and all data and any team logo images belong to the NBA.



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

## Game Ranking Algorithm

The aim of the ranking system is to assign value to a game based on 'watchability' or 'excitment'. This is hard for numbers alone to achieve but we've given it a go (and open it ideas). Current methodology follows the below basic formula:

```
Number of overtimes x 'Overtime Value' (default: 3) +
'Final Margin Value' - Final game margin + 
Individual player highest points scored x 'Top Player Points Value' (default: 0.1) +
Team highest points scored - 100 x 'Top Team Points Value' (default: 0.1)
```

There are two final score adjustments possible, which can both be utilised at the same time.

1) **Win Percentages:** Multiply final *'Game Rank'* score by the sum of the win percentages of the competing teams.
For example, two teams above .500 will increase the total *'Game Rank'* score
2) **Nightly Margin:** Rather than using an arbitrary value for the *'Final Margin Value'*, replace it with the maximum margin for the night.
