
## Lead tracking: date/gameID_lead_tracker_Quarter.json
# Json contains every score, the time, the team in the lead and by how much. team ID is "" when scores are level
# https://data.nba.net/data/10s/prod/v1/20191225/0021900455_lead_tracker_4.json


# Game day box scores and high scorers
# just change game date, teams are then listed
# https://stats.nba.com/stats/scoreboardV2?DayOffset=0&LeagueID=00&gameDate=12%2F25%2F2019

# full play by play https://data.nba.com/data/10s/v2015/json/mobile_teams/nba/2019/scores/pbp/0021900444_full_pbp.json

library(shiny)
library(jsonlite)
library(dplyr)
library(DT)
library(curl)


get_rank <- function(date_input) {
  val_OT <- 3
  val_finalmargin <- 10
  val_topscorer <- 0.1
  val_teampoints <- 10
  
  
  baseurl <- "https://stats.nba.com/stats/scoreboardV2?"
  
  dayoffset <- "0"
  
  LeagueID <- "00"
  
  GameDate <- date_input
  
  buildurl <- paste0(baseurl, "DayOffset=", dayoffset, "&LeagueID=", LeagueID, "&gameDate=", GameDate)
  print(buildurl)
  dat <- fromJSON(txt = buildurl, flatten = TRUE)
  
  #gameday information in dat$resultSets$rowSet[1]
  
  
  gameday <- as_tibble(setNames(object = as.data.frame(dat$resultSets$rowSet[1], stringsAsFactors = FALSE), nm = unlist(dat$resultSets$headers[1])))
  boxscores <- as_tibble(setNames(object = as.data.frame(dat$resultSets$rowSet[2], stringsAsFactors = FALSE), nm = unlist(dat$resultSets$headers[2])))
  eastStandings <- as_tibble(setNames(object = as.data.frame(dat$resultSets$rowSet[5], stringsAsFactors = FALSE), nm = unlist(dat$resultSets$headers[5])))
  westStandings <- as_tibble(setNames(object = as.data.frame(dat$resultSets$rowSet[6], stringsAsFactors = FALSE), nm = unlist(dat$resultSets$headers[6])))
  statLeaders <- as_tibble(setNames(object = as.data.frame(dat$resultSets$rowSet[8], stringsAsFactors = FALSE), nm = unlist(dat$resultSets$headers[8])))
  
  gameday <- gameday %>% select(GAME_ID, GAMECODE, HOME_TEAM_ID, VISITOR_TEAM_ID)
  
  leagueStandings <- bind_rows(eastStandings, westStandings) %>% arrange(desc(W_PCT)) %>% select(TEAM_ID, TEAM, G, W, L, W_PCT)
  
  boxscores <- boxscores %>% rename(TeamPTS = "PTS", TeamREB = REB, TeamAST = AST)
  
  fullScores <- left_join(boxscores, statLeaders) %>% select(-c(TEAM_CITY, TEAM_NICKNAME))
  fullScores <- leagueStandings %>% select(TEAM_ID, W_PCT) %>% right_join(fullScores)
  
  homeTeamScores <- fullScores %>% filter(TEAM_ID %in% gameday$HOME_TEAM_ID)
  awayTeamScores <- fullScores %>% filter(TEAM_ID %in% gameday$VISITOR_TEAM_ID)
  
  fullScores <- left_join(x = homeTeamScores, y = awayTeamScores, by = "GAME_ID", suffix = c("_h","_a")) %>%
    select(-c(GAME_DATE_EST_a, GAME_SEQUENCE_a))
  
  overtime_home_df <- fullScores %>% select(starts_with("PTS_OT")) %>% select(ends_with("_h"))
  
  overtime_away_df <- fullScores %>% select(starts_with("PTS_OT")) %>% select(ends_with("_a"))
  
  fullScores$OT_PTS_h <- rowSums(mutate_all(overtime_home_df, function(x) as.numeric(as.character(x))))
  fullScores$OT_PTS_a <- rowSums(mutate_all(overtime_away_df, function(x) as.numeric(as.character(x))))
  
  fullScores$OT_tot <- apply(X = overtime_home_df, MARGIN = 1, FUN = function(i) sum(i > 0))
  
  fullScores <- fullScores %>% select(-(starts_with("PTS_OT")))
  
  fullScores <- gameday %>% select(c(GAME_ID, GAMECODE)) %>% right_join(y = fullScores)
  
  fullScores$PlayerPTS_leader <- mutate_all(select(fullScores, c(PTS_h, PTS_a)), function(x) as.integer(x)) %>% apply(1, max)
  fullScores$TeamPTS_leader <- mutate_all(select(fullScores, c(TeamPTS_h,TeamPTS_a)), function(x) as.integer(x)) %>% apply(1, max)
  
  fullScores$finalMargin <- abs(as.numeric(fullScores$TeamPTS_h) - as.numeric(fullScores$TeamPTS_a))
  fullScores$sumWinPerc <- as.numeric(fullScores$W_PCT_h) + as.numeric(fullScores$W_PCT_a)
  
  fullScores$League_Pass_Link <- fullScores %>% select(GAMECODE) %>% apply(1, FUN = function(i) paste0("https://watch.nba.com/game/", i))
  
  fullScores$GameScore <- (as.numeric(fullScores$OT_tot) * 3) + (val_finalmargin - as.numeric(fullScores$finalMargin)) + (as.numeric(fullScores$PlayerPTS_leader) * val_topscorer) + ((as.numeric(fullScores$TeamPTS_leader) - 100) / val_teampoints)
  
  fullScores$GameScorePosNeg <- if_else(condition = fullScores$GameScore < 0, -1, 1)
  
  fullScores$AdjGameScore <- fullScores$GameScore + (((fullScores$GameScore * fullScores$sumWinPerc) - fullScores$GameScore) * fullScores$GameScorePosNeg)
  
  fullScores$Home <- paste(fullScores$TEAM_CITY_NAME_h, fullScores$TEAM_NAME_h)
  fullScores$Away <- paste(fullScores$TEAM_CITY_NAME_a, fullScores$TEAM_NAME_a)
  
  GameRank <- fullScores %>% select(Away, Home, League_Pass_Link, sumWinPerc, GameScore, AdjGameScore) %>% arrange(desc(GameScore))
  print(GameRank)
  GameRank %>% select(Away, Home, League_Pass_Link)
}

# Define UI for application that draws a histogram
ui <- fluidPage(
   
   # Application title
   titlePanel("NBA Game of the Day"),
   
   # Sidebar with a slider input for number of bins 
   sidebarLayout(
      sidebarPanel(width = 2, 
         dateInput(inputId = "Date",
                   format = "mm-dd-yyyy",
                   label = "Game Day",
                   min = "2019-10-22",
                   max = format(Sys.Date(), "%Y-%m-%d"),
                   datesdisabled = c("2019-12-25","2019-11-26")
                   ),
         actionButton(inputId = "goButton", label = "Get Game of the day!")
         
      ),
      
      # Show a plot of the generated distribution
      mainPanel(
        DT::dataTableOutput(outputId = "GameResults")
         
      )
   )
)

# Define server logic required to draw a histogram
server <- function(input, output, session) {
   observeEvent(input$goButton, {
     output$GameResults <- DT::renderDataTable({
     get_rank(input$Date)
     })
   })  
}

# Run the application 
shinyApp(ui = ui, server = server)

