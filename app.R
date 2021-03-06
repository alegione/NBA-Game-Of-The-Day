
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
library(httr)

request_headers <- c(
  "accept-encoding" = "gzip, deflate, sdch",
  "accept-language" = "en-US,en;q=0.8",
  "cache-control" = "no-cache",
  "connection" = "keep-alive",
  "host" = "stats.nba.com",
  "pragma" = "no-cache",
  "referer" = "https://www.nba.com/",
  "upgrade-insecure-requests" = "1",
  "user-agent" = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_2) AppleWebKit/601.3.9 (KHTML, like Gecko) Version/9.0.2 Safari/601.3.9"
)

get_rank <- function(date_input,
                     winadj,
                     marginadj,
                     val_OT,
                     val_finalmargin, 
                     val_topscorer, 
                     val_teampoints,
                     ShowScores) {
  if (is.null(winadj)) {
    winadj <- FALSE
  }
  if (is.null(marginadj)) {
    marginadj <- FALSE
  }

  baseurl <- "https://stats.nba.com/stats/scoreboardV2?"
  
  dayoffset <- "0"
  
  LeagueID <- "00"
  
  GameDate <- format.Date(date_input, "%Y%%2F%m%%2F%d")
  
  buildurl <- paste0(baseurl, "DayOffset=", dayoffset, "&LeagueID=", LeagueID, "&gameDate=", GameDate)

  gethttp <- GET(buildurl, add_headers(request_headers))
  
  dat <- fromJSON(txt = content(gethttp, as = "text"), flatten = TRUE)
  
  #gameday information in dat$resultSets$rowSet[1]
  
  gameday <- as_tibble(setNames(object = as.data.frame(dat$resultSets$rowSet[1],
                                                       stringsAsFactors = FALSE),
                                nm = unlist(dat$resultSets$headers[1])))
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
  
  fullScores$League_Pass_Link <- fullScores %>% select(GAMECODE) %>% apply(1, FUN = function(i) paste0("<a href='https://watch.nba.com/game/", i, "'>", i, "</a>"))
  
  if (marginadj == TRUE) {
    val_finalmargin <- max(fullScores$finalMargin)
  }
  
  fullScores$GameScore <- (as.numeric(fullScores$OT_tot) * val_OT) + (val_finalmargin - as.numeric(fullScores$finalMargin)) + (as.numeric(fullScores$PlayerPTS_leader) * val_topscorer) + ((as.numeric(fullScores$TeamPTS_leader) - 100) * val_teampoints)
  
  fullScores$GameScorePosNeg <- if_else(condition = fullScores$GameScore < 0, -1, 1)
  
  fullScores$AdjGameScore <- fullScores$GameScore + (((fullScores$GameScore * fullScores$sumWinPerc) - fullScores$GameScore) * fullScores$GameScorePosNeg)
  
  fullScores$Home <- paste0("<img src='", fullScores$TEAM_ABBREVIATION_h, ".png' height='52'></img>", fullScores$TEAM_CITY_NAME_h, " ", fullScores$TEAM_NAME_h)
  fullScores$Away <- paste0(fullScores$TEAM_CITY_NAME_a, " ", fullScores$TEAM_NAME_a, "<img src='", fullScores$TEAM_ABBREVIATION_a, ".png' height='52'></img>")
  
  if (winadj == FALSE) {
    GameRank <- fullScores %>%
      select(Away, Home, League_Pass_Link, GameScore) %>%
      mutate(ranking = dense_rank(desc(GameScore)))
  } else {
    GameRank <- fullScores %>%
      select(Away, Home, League_Pass_Link, AdjGameScore) %>%
      mutate(ranking = dense_rank(desc(AdjGameScore)))
    GameRank$GameScore <- GameRank$AdjGameScore
  }
  
  # GameRank <- fullScores %>%
  #   select(Away, Home, League_Pass_Link, sumWinPerc, GameScore, AdjGameScore) %>%
  #   {ifelse(test = winadj == TRUE, yes = arrange(., desc(AdjGameScore)), no = arrange(., desc(GameScore)))} %>%
  #   {ifelse(test = winadj == TRUE, yes = mutate(., ranking = dense_rank(desc(GameScore))), no = mutate(., ranking = dense_rank(desc(AdjGameScore))))}
  print(select(fullScores, Home, Away, GameScore, sumWinPerc, AdjGameScore))

  if (ShowScores == TRUE) { 
    GameRank %>% select(ranking, Away, Home, GameScore, League_Pass_Link) %>% arrange(ranking)
  } else {
    GameRank %>% select(ranking, Away, Home, League_Pass_Link) %>% arrange(ranking)
  }
  
}

# Define UI for application that draws a histogram
ui <- fluidPage(
   
   # Application title
   titlePanel("NBA Game of the Day"),
   
   # Sidebar with a slider input for number of bins 
   sidebarLayout(
      sidebarPanel(width = 3, 
         dateInput(inputId = "Date",
                   format = "yyyy-mm-dd",
                   label = "Game Day",
                   min = "2019-10-22",
                   max = format(Sys.Date(), "%Y-%m-%d"),
                   datesdisabled = c("2019-12-25","2019-11-26")
                   ),
         numericInput(inputId = "val_OT",
                      label = "Overtime",
                      value = 3,
                      min = 0,
                      max = 100,
                      step = 1),
         numericInput(inputId = "val_finalmargin",
                      label = "Final Margin",
                      value = 10,
                      min = 0,
                      max = 100,
                      step = 1),
         numericInput(inputId = "val_topscorer",
                      label = "Top Player Points",
                      value = 0.1,
                      min = 0,
                      max = 10,
                      step = 0.1),
         numericInput(inputId = "val_teampoints",
                      label = "Top Team Points",
                      value = 0.1,
                      min = 0,
                      max = 10,
                      step = 0.1),
         checkboxInput(inputId = "WinPercentageAdj",
                       label = "Win Percentages",
                       value = FALSE),
         checkboxInput(inputId = "MarginAdj",
                       label = "Nightly Margins",
                       value = FALSE),
         checkboxInput(inputId = "ShowScores",
                       label = "Show Rank Score",
                       value = FALSE),
         actionButton(inputId = "goButton",
                      label = "Get Game of the day!")
         
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
       print("RunningGetRank")
       get_rank(input$Date,
                input$WinPercentageAdj,
                input$MarginAdj,
                input$val_OT,
                input$val_finalmargin,
                input$val_topscorer,
                input$val_teampoints,
                input$ShowScores
       )
     }, escape = FALSE,
     rownames = FALSE, 
     options = list(columnDefs = list(list(className = 'dt-center', targets = "_all")))
     )
     
   })  
}

# Run the application 
shinyApp(ui = ui, server = server)

