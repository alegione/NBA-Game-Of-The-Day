
teams <- c("atl","bkn","bos","cha","chi","cle","dal","den","det","gsw","hou","ind","lac","lal","mem","mia","mil","min","nop","nyk","okc","orl","phi","phx","por","sac","sas","tor","uta","was")

for (i in teams) {
  link <- paste0("http://i.cdn.turner.com/nba/nba/.element/img/1.0/teamsites/logos/teamlogos_500x500/", i ,".png")
  i <- toupper(i)
  dest <- paste0("www/", i, ".png")
  download.file(url = link, destfile = dest, mode = "wb")
}

