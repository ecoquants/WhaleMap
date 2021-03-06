# server.R
# WhaleMap - a Shiny app for visualizing whale survey data

# setup -------------------------------------------------------------------

# required libraries
suppressPackageStartupMessages(library(shiny))
suppressPackageStartupMessages(library(leaflet))
suppressPackageStartupMessages(library(rgdal))
suppressPackageStartupMessages(library(htmltools))
suppressPackageStartupMessages(library(htmlwidgets))
suppressPackageStartupMessages(library(maptools))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(oce))
suppressPackageStartupMessages(library(shinydashboard))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(plotly))
suppressPackageStartupMessages(library(leaflet.extras))

# define color palette list to choose from
palette_list = list(heat.colors(200), 
                    oce.colorsTemperature(200),
                    oce.colorsSalinity(200),
                    oce.colorsDensity(200),
                    oce.colorsChlorophyll(200),
                    oce.colorsGebco(200),
                    oce.colorsJet(200),
                    oceColorsViridis(200))

# define score colors
score_cols = c('definite acoustic' = 'red', 
               'possible acoustic' = 'yellow', 
               'definite visual' = 'darkslategray',
               'possible visual' = 'gray')

# define visual and acoustic platforms
visual_platforms = c('plane', 'vessel')
acoustic_platforms = c('slocum', 'buoy', 'wave')

# read in map polygons
mpa = readRDS('data/processed/mpa.rds')
load('data/processed/tss.rda')
load('data/processed/management_areas.rda')

# define track point plotting threshold
npts = 250000

# define time lag for startup plotting
tlag = 14 # days

# make dcs icons
dcsIcons = iconList(
  slocum = makeIcon("icons/slocum.png", iconWidth = 40, iconHeight = 40),
  wave = makeIcon("icons/wave.png", iconWidth = 35, iconHeight = 30),
  buoy = makeIcon("icons/buoy.png", iconWidth = 50, iconHeight = 40)
)

# make sono icon
sonoIcon = makeIcon("icons/sono.png", iconWidth = 10, iconHeight = 45)

# read in password file
load('data/processed/password.rda')

# server ------------------------------------------------------------------

function(input, output, session){
  
  # read in data -------------------------------------------------------
  
  # tracklines
  tracks = readRDS('data/processed/tracks.rds')
  
  # latest dcs positions
  lfile = 'data/processed/dcs_live_latest_position.rds'
  if(file.exists(lfile)){
    latest = readRDS(lfile) 
  }
  
  # sightings / detections
  obs = readRDS('data/processed/observations.rds')
  
  # sonobuoys
  sono = readRDS('data/processed/sonobuoys.rds')
  
  # build date UI -------------------------------------------------------
  
  output$dateChoice <- renderUI({
    
    # set begin and end dates for slider
    begin_date = as.Date('2019-01-01')
    end_date = as.Date('2019-12-31')
    
    # make vector of all possible dates
    date_vec = format.Date(seq.Date(from = begin_date,to = end_date, by = 1), '%b-%d')
    
    switch(input$dateType,
           
           'select' = selectInput("date", label = NULL,
                                  choices = date_vec,
                                  selected = format.Date(Sys.Date(), '%b-%d'), multiple = FALSE),
           
           'range' = sliderInput("date", label = NULL, begin_date, end_date,
                                 value = c(Sys.Date()-tlag, Sys.Date()), timeFormat = '%b-%d',
                                 animate = F)
    )
  })
  
  # choose date -------------------------------------------------------
  
  # define start time
  ydays <- reactive({
    if (input$go == 0){ 
      # yday list on startup
      seq(yday(Sys.Date()-tlag), yday(Sys.Date()), 1)
    } else {
      # choose date on action button click
      isolate({
        if(input$dateType == 'select'){
          yday(as.Date(input$date, format = '%b-%d'))
        } else if(input$dateType == 'range'){
          seq(yday(input$date[1]), yday(input$date[2]), 1)
        }
      })
    }
  })
  
  # choose year -------------------------------------------------------
  
  years <- reactive({
    # assign default year if action button hasn't been pushed yet  
    if (input$go == 0){
      as.character(year(Sys.Date()))
    } else {
      # choose year on action button click
      isolate({
        as.character(input$year)
      })
    }
  })
  
  # choose species -----------------------------------------------------------
  
  # species
  species <- eventReactive(input$go|input$go == 0,{
    input$species
  })
  
  # choose platform -----------------------------------------------------------
  
  platform <- eventReactive(input$go|input$go == 0,{
    input$platform
  })
  
  # choose colorby -----------------------------------------------------------
  
  colorby <- eventReactive(input$go|input$go == 0,{
    input$colorby  
  })
  
  # reactive data -----------------------------------------------------------
  
  # choose tracks year(s) and platform(s) (no cp without password)
  Tracks <- eventReactive(input$go|input$go == 0, {
    if(input$password == password){
      tmp = tracks[tracks$year %in% years(),]
      tmp[tmp$platform %in% platform(),]
    } else if(input$password == jasco_password){
      tmp = tracks[tracks$year %in% years(),]
      tmp = tmp[tmp$platform %in% platform(),]
      tmp[tmp$name!='cp_king_air',]
    } else {
      tmp = tracks[tracks$year %in% years(),]
      tmp = tmp[tmp$platform %in% platform(),]
      tmp = tmp[tmp$name!='cp_king_air',]
      tmp[tmp$name!='jasco_test',]
    }
  })
  
  # choose observations
  Obs <- eventReactive(input$go|input$go == 0, {
    tmp = obs[obs$year %in% years(),]
    tmp[tmp$platform %in% platform(),]
  })
  
  # position for live dcs platform
  if(file.exists(lfile)){
    LATEST <- eventReactive(input$go|input$go == 0, {
      
      if(input$password == password | input$password == jasco_password){
        tmp = latest[latest$year %in% years(),]
        tmp = tmp[tmp$platform %in% platform(),]
        tmp = tmp[tmp$yday %in% ydays(),]
        tmp
      } else {
        tmp = latest[latest$year %in% years(),]
        tmp = tmp[tmp$platform %in% platform(),]
        tmp = tmp[tmp$yday %in% ydays(),]
        tmp[tmp$name!='jasco_test',]
      }
      
    })
  }
  
  # position for live dcs platform
  SONO <- eventReactive(input$go|input$go == 0, {
    tmp = sono[sono$year %in% years(),]
    tmp[tmp$yday %in% ydays(),]
  })
  
  # choose track date range
  TRACKS <- eventReactive(input$go|input$go == 0, {
    Tracks()[Tracks()$yday %in% ydays(),]
  })
  
  # choose species date range
  OBS <- eventReactive(input$go|input$go == 0, {
    Obs()[Obs()$yday %in% ydays(),]
  })
  
  # choose species
  spp <- eventReactive(input$go|input$go == 0, {
    if(input$password == password|input$password == jasco_password){
      droplevels(OBS()[OBS()$species %in% species(),])
    } else {
      tmp = droplevels(OBS()[OBS()$species %in% species(),])
      tmp[tmp$name!='jasco_test',]
    }
  })
  
  # only possible
  pos <- eventReactive(input$go|input$go == 0, {
    if(input$password == password){
      droplevels(spp()[spp()$score=='possible acoustic'|spp()$score=='possible visual',])
    } else {
      droplevels(spp()[spp()$score=='possible acoustic',])
    }
  })
  
  # only definite
  det <- reactive({
    droplevels(spp()[spp()$score=='definite acoustic'|spp()$score=='definite visual',])
  })
  
  # combine track and observations
  allBounds <- reactive({
    
    # combine limits
    lat = c(spp()$lat, TRACKS()$lat)
    lon = c(spp()$lon, TRACKS()$lon)
    
    # join in list
    list(lat, lon)
  })
  
  # password warning -----------------------------------------------
  
  observeEvent(input$go,{
    if(input$password == password){
      showNotification('Password was correct! Showing unverified and/or test data...',
                       duration = 7, closeButton = T, type = 'message')

    } else if(input$password == jasco_password){
      showNotification('Password was correct! Showing JASCO test data...',
                       duration = 7, closeButton = T, type = 'message')
    } else {
      
    }
  })
  
  # warnings --------------------------------------------------------
  
  observe({
    
    # track warning
    if(nrow(TRACKS())>npts){
      showNotification(paste0('Warning! Tracklines have been turned off because 
                              you have chosen to plot more data than this application 
                              can currently handle (i.e. more than ', as.character(npts), ' points). 
                              Please select less data to view tracks.'), 
                       duration = 7, closeButton = T, type = 'warning')
    }
    
    # species warning
    if(paste(species(),collapse=',')!='right'){
      showNotification('Note: WhaleMap focuses on right whales. Other species
                              information is incomplete.', 
                       duration = 7, closeButton = T, type = 'warning')
    }
    
    # year warning
    if(min(years())<2017){
      showNotification('Note: Data before 2017 are incomplete.', 
                       duration = 7, closeButton = T, type = 'warning')
    }
    
  })
  
  # colorpal -----------------------------------------------------------------
  
  # define color palette for any column variable
  colorpal <- reactive({
    
    # define index of color selection for use in palette list
    ind = as.numeric(input$pal)
    
    if(colorby() %in% c('yday', 'lat', 'lon')){
      
      # use continuous palette
      colorNumeric(palette_list[[ind]], spp()[,which(colnames(spp())==colorby())])  
      
    } else if (colorby() == 'number'){
      
      if(is.infinite(min(spp()$number, na.rm = T))){
        # define colorbar limits if 'number' is selected without sightings data
        colorNumeric(palette_list[[ind]], c(NA,0), na.color = 'darkgrey')
      } else {
        # use continuous palette
        colorNumeric(palette_list[[ind]], spp()$number, na.color = 'darkgrey')
      }
      
    } else if (colorby() == 'score'){
      
      # hard wire colors for score factor levels
      colorFactor(levels = c('definite acoustic', 'possible acoustic', 'possible visual', 'definite visual'), 
                  palette = c('red', 'yellow', 'grey', 'darkslategray'))  
      
    } else {
      
      # color by factor level
      colorFactor(palette_list[[ind]], spp()[,which(colnames(spp())==colorby())])  
      
    }
  })
  
  # basemap -----------------------------------------------------------------
  
  output$map <- renderLeaflet({
    leaflet(tracks) %>% 
      addProviderTiles(providers$Esri.OceanBasemap) %>%
      fitBounds(~max(lon, na.rm = T), 
                ~min(lat, na.rm = T), 
                ~min(lon, na.rm = T), 
                ~max(lat, na.rm = T)) %>%
      
      # add graticules
      # addWMSTiles(
      #   'https://gis.ngdc.noaa.gov/arcgis/services/graticule/MapServer/WMSServer',
      #   layers = c('1', '2', '3'),
      #   options = WMSTileOptions(format = "image/png8", transparent = TRUE),
      #   attribution = "NOAA") %>%
      
      # use NOAA graticules
      addWMSTiles(
        "https://gis.ngdc.noaa.gov/arcgis/services/graticule/MapServer/WMSServer/",
        layers = c("1-degree grid", "5-degree grid"),
        options = WMSTileOptions(format = "image/png8", transparent = TRUE),
        attribution = NULL) %>%
      
      # add extra map features
      addScaleBar(position = 'topright')%>%
      addFullscreenControl(pseudoFullscreen = TRUE) %>%
      addMeasure(
        primaryLengthUnit = "kilometers",
        secondaryLengthUnit = 'miles', 
        primaryAreaUnit = "hectares",
        secondaryAreaUnit="acres", 
        activeColor = "darkslategray",
        completedColor = "darkslategray",
        position = 'bottomleft')
  })
  
  # extract trackline color ------------------------------------------------  
  
  getColor <- function(tracks) {
    if(tracks$platform[1] == 'slocum') {
      "blue"
    } else if(tracks$platform[1] == 'plane') {
      "#8B6914"
    } else if(tracks$platform[1] == 'vessel'){
      "black"
    } else if(tracks$platform[1] == 'wave'){
      "purple"
    } else {
      "darkgrey"
    }
  }
  
  # mpa observer ------------------------------------------------------  
  
  observe(priority = 4, {
    
    # define proxy
    proxy <- leafletProxy("map")
    proxy %>% clearGroup('mpa')
    
    if(input$mpa){
      
      # add mpas
      proxy %>%
        addPolygons(data=mpa, lng=~lon, lat=~lat, group = 'mpa',
                    fill = T, 
                    fillOpacity = 0.25, 
                    stroke = T, 
                    # smoothFactor = 3,
                    dashArray = c(5,5), 
                    options = pathOptions(clickable = F),
                    weight = 1, 
                    color = 'darkgreen', 
                    fillColor = 'darkgreen')
      
      # switch to show/hide
      ifelse(input$mpa, showGroup(proxy, 'mpa'),hideGroup(proxy, 'mpa'))
    }
    
  })
  
  # tc_lanes observer ------------------------------------------------------  
  
  observe(priority = 4, {
    
    # define proxy
    proxy <- leafletProxy("map")
    proxy %>% clearGroup('tc_lanes')
    
    if(input$tc_lanes){
      
      # add polygons
      proxy %>%
        addPolygons(data=tc_lanes, group = 'tc_lanes',
                    fill = T, 
                    fillOpacity = 0.4, 
                    stroke = T, 
                    # smoothFactor = 3,
                    dashArray = c(5,5), 
                    options = pathOptions(clickable = F),
                    weight = 1, 
                    color = 'purple', 
                    fillColor = 'purple')
      
      # switch to show/hide
      ifelse(input$tc_lanes, showGroup(proxy, 'tc_lanes'),hideGroup(proxy, 'tc_lanes'))
    }
    
  })
  
  # tc_zone observer ------------------------------------------------------  
  
  observe(priority = 4, {
    
    # define proxy
    proxy <- leafletProxy("map")
    proxy %>% clearGroup('tc_zone')
    
    if(input$tc_zone){
      
      # add polygons
      proxy %>%
        addPolygons(data=tc_zone, group = 'tc_zone',
                    fill = T, 
                    fillOpacity = 0.25, 
                    stroke = T, 
                    # smoothFactor = 3,
                    dashArray = c(5,5), 
                    options = pathOptions(clickable = F),
                    weight = 1, 
                    color = 'grey', 
                    fillColor = 'grey')
      
      # switch to show/hide
      ifelse(input$tc_zone, showGroup(proxy, 'tc_zone'),hideGroup(proxy, 'tc_zone'))
    }
    
  })
  
  # static_zone observer ------------------------------------------------------  
  
  observe(priority = 4, {
    
    # define proxy
    proxy <- leafletProxy("map")
    proxy %>% clearGroup('static_zone')
    
    if(input$static_zone){
      
      # add polygons
      proxy %>%
        addPolygons(data=static_zone, group = 'static_zone',
                    lat = ~lat, lng = ~lon,
                    fill = T, 
                    fillOpacity = 0.25, 
                    stroke = T, 
                    # smoothFactor = 3,
                    dashArray = c(5,5), 
                    options = pathOptions(clickable = F),
                    weight = 1, 
                    color = 'darkblue', 
                    fillColor = 'darkblue')
      
      # switch to show/hide
      ifelse(input$static_zone, showGroup(proxy, 'static_zone'),hideGroup(proxy, 'static_zone'))
    }
    
  })
  
  # forage_areas observer ------------------------------------------------------  
  
  observe(priority = 4, {
    
    # define proxy
    proxy <- leafletProxy("map")
    proxy %>% clearGroup('forage_areas')
    
    if(input$forage_areas){
      
      # add polygons
      proxy %>%
        addPolygons(data=forage_areas, group = 'forage_areas',
                    fill = T, 
                    fillOpacity = 0.25, 
                    stroke = T, 
                    weight = 1, 
                    color = 'darkslategrey', 
                    fillColor = 'orange')
      
      # switch to show/hide
      ifelse(input$forage_areas, showGroup(proxy, 'forage_areas'),hideGroup(proxy, 'forage_areas'))
    }
    
  })
  
  # tss observer ------------------------------------------------------  
  
  observe(priority = 4, {
    
    # define proxy
    proxy <- leafletProxy("map")
    proxy %>% clearGroup('tss')
    
    if(input$tss){
      
      # plot shipping lanes

      proxy %>%
        addPolylines(tss_lines$lon, tss_lines$lat,
                     weight = .5,
                     color = 'grey',
                     # smoothFactor = 3,
                     options = pathOptions(clickable = F),
                     group = 'tss') %>%
        addPolygons(tss_polygons$lon, tss_polygons$lat,
                    weight = .5,
                    color = 'grey',
                    fillColor = 'grey',
                    # smoothFactor = 3,
                    options = pathOptions(clickable = F),
                    group = 'tss')
      
      # switch to show/hide
      ifelse(input$tss, showGroup(proxy, 'tss'),hideGroup(proxy, 'tss'))
    }
  
  })
  
  
  # track observer ------------------------------------------------------  
  
  observe(priority = 3, {
    
    # define proxy
    proxy <- leafletProxy("map")
    proxy %>% clearGroup('tracks')
    
    # tracks
    
    if(input$tracks & nrow(TRACKS())<npts){
      
      # set up polyline plotting
      tracks.df <- split(TRACKS(), TRACKS()$id)
      
      # add lines
      names(tracks.df) %>%
        purrr::walk( function(df) {
          proxy <<- proxy %>%
            addPolylines(data=tracks.df[[df]], group = 'tracks',
                         lng=~lon, lat=~lat, weight = 2,
                         popup = paste0('Track ID: ', unique(tracks.df[[df]]$id)),
                         smoothFactor = 1, color = getColor(tracks.df[[df]]))
        })
    }
    
  })
  
  # latest observer ------------------------------------------------------  
  if(file.exists(lfile)){
    
    observe(priority = 3, {
      
      # define proxy
      proxy <- leafletProxy("map")
      proxy %>% clearGroup('latest')
      
      # tracks
      
      if(input$latest){
        
        # add icons for latest position of live dcs platforms
        proxy %>% addMarkers(data = LATEST(), ~lon, ~lat, icon = ~dcsIcons[platform],
                             popup = ~paste(sep = "<br/>",
                                            strong('Latest position'),
                                            paste0('Platform: ', as.character(platform)),
                                            paste0('Name: ', as.character(name)),
                                            paste0('Time: ', as.character(time), ' UTC'),
                                            paste0('Position: ', 
                                                   as.character(lat), ', ', as.character(lon))),
                             label = ~paste0('Latest position of ', as.character(name), ': ', 
                                             as.character(time), ' UTC'), group = 'latest')
        
      }
      
    })
  }
  
  # sono observer ------------------------------------------------------  
  
  observe(priority = 1, {
    
    # define proxy
    proxy <- leafletProxy("map")
    proxy %>% clearGroup('sono')
    
    # add sonobuoys
    if(input$sono){
      
      # add icons for latest position of live dcs platforms
      proxy %>% addMarkers(data = SONO(), ~lon, ~lat, group='sono', icon = sonoIcon,
                           popup = ~paste(sep = "<br/>",
                                          strong('Sonobuoy position'),
                                          paste0('Date: ', as.character(date)),
                                          paste0('Time: ', as.character(time), ' UTC'),
                                          paste0('ID: ', as.character(stn_id)),
                                          paste0('SN: ', as.character(sn)),
                                          paste0('Position: ', 
                                                 as.character(lat), ', ', as.character(lon)))
                           # label = ~paste0('sonobuoy ', as.character(stn_id), ': ', 
                           #                 as.character(date), ' UTC'), group = 'sono'
                           )
      
    }
    
  })
  
  # possible observer ------------------------------------------------------  
  
  observe(priority = 2,{
    
    # define proxy
    proxy <- leafletProxy("map")
    proxy %>% clearGroup('possible')
    
    if(input$possible){
      
      # set up color palette plotting
      pal <- colorpal()
      
      # possible detections
      addCircleMarkers(map = proxy, data = pos(), ~lon, ~lat, group = 'possible',
                       radius = 4, fillOpacity = 0.9, stroke = T, col = 'black', weight = 0.5,
                       fillColor = pal(pos()[,which(colnames(pos())==colorby())]),
                       popup = ~paste(sep = "<br/>" ,
                                      paste0("Species: ", species),
                                      paste0("Score: ", score),
                                      paste0("Platform: ", platform),
                                      paste0("Name: ", name),
                                      paste0('Date: ', as.character(date)),
                                      paste0('Time: ', as.character(format(time, '%H:%M:%S'))),
                                      paste0('Position: ',
                                             as.character(lat), ', ', as.character(lon)))
                       )
    }
  })
  
  # definite observer ------------------------------------------------------  
  
  observe(priority = 1,{
    
    # define proxy
    proxy <- leafletProxy("map")
    proxy %>% clearGroup('detected')
    
    if(input$detected){
      
      # set up color palette plotting
      pal <- colorpal()
      
      # definite detections
      addCircleMarkers(map = proxy, data = det(), ~lon, ~lat, group = 'detected',
                       radius = 4, fillOpacity = 0.9, stroke = T, col = 'black', weight = 0.5,
                       fillColor = pal(det()[,which(colnames(det())==colorby())]),
                       popup = ~paste(sep = "<br/>" ,
                                      paste0("Species: ", species),
                                      paste0("Score: ", score),
                                      paste0("Number: ", number),
                                      paste0("Platform: ", platform),
                                      paste0("Name: ", name),
                                      paste0('Date: ', as.character(date)),
                                      paste0('Time: ', as.character(format(time, '%H:%M:%S'))),
                                      paste0('Position: ', 
                                             as.character(lat), ', ', as.character(lon))),
                       options = markerOptions(removeOutsideVisibleBounds=T))
    }
  })
  
  # legend observer ------------------------------------------------------  
  
  observe({
    
    # define proxy
    proxy <- leafletProxy("map")
    
    # determine which dataset to use based on display switches
    if(input$detected & input$possible){
      dat <- rbind(det(),pos())
    } else if(input$detected & !input$possible){
      dat <- det()
    } else if(!input$detected & input$possible){
      dat <- pos()
    } else {
      proxy %>% clearControls()
      return(NULL)
    }
    
    # set up color palette plotting
    pal <- colorpal()
    var <- dat[,which(colnames(dat)==colorby())]
    
    # legend
    if(input$legend){
      proxy %>% clearControls() %>% 
        addLegend(position = "bottomright",labFormat = labelFormat(big.mark = ""),
                  pal = pal, values = var, 
                  title = colorby())
    } else {
      proxy %>% clearControls()
    }
  })
  
  # center map ------------------------------------------------------  
  
  observeEvent(input$zoom,{
    leafletProxy("map") %>% 
      fitBounds(max(allBounds()[[2]], na.rm = T), 
                min(allBounds()[[1]], na.rm = T), 
                min(allBounds()[[2]], na.rm = T), 
                max(allBounds()[[1]], na.rm = T))
  })
  
  # inbounds data ------------------------------------------------------  
  
  # determine deployments in map bounds
  tInBounds <- reactive({
    if (is.null(input$map_bounds))
      return(TRACKS()[FALSE,])
    bounds <- input$map_bounds
    latRng <- range(bounds$north, bounds$south)
    lngRng <- range(bounds$east, bounds$west)
    
    subset(TRACKS(),
           lat >= latRng[1] & lat <= latRng[2] &
             lon >= lngRng[1] & lon <= lngRng[2])
  })
  
  # determine detected calls in map bounds
  dInBounds <- reactive({
    
    # determine which dataset to use based on display switches
    if(input$detected & input$possible){
      dat <- rbind(det(),pos())
    } else if(input$detected & !input$possible){
      dat <- det()
    } else if(!input$detected & input$possible){
      dat <- pos()
    } else {
      dat = data.frame()
      return(dat[FALSE,])
    }
    
    # catch error if no data is displayed
    if (is.null(input$map_bounds)){
      return(dat[FALSE,])
    }
    
    # define map bounds
    bounds <- input$map_bounds
    latRng <- range(bounds$north, bounds$south)
    lngRng <- range(bounds$east, bounds$west)
    
    # subset of data in bounds
    subset(dat,
           lat >= latRng[1] & lat <= latRng[2] &
             lon >= lngRng[1] & lon <= lngRng[2])
  })
  
  # create text summary
  output$summary <- renderUI({
    if(nrow(spp())==0){
      HTML('No data available...')
    } else {
      
      # list species names in bounds 
      spp_names = paste(levels(dInBounds()$species), collapse = ', ')
      
      # sighting/detection info
      str1 <- paste0('<strong>Species</strong>: ', spp_names)
      
      str2 <- paste0('<strong>Number of definite sighting events</strong>: ', 
                     nrow(dInBounds()[dInBounds()$score=='definite visual',]))
      
      str3 <- paste0('<strong>Number of whales sighted (includes duplicates)</strong>: ', 
                     sum(dInBounds()$number[dInBounds()$score=='definite visual'], na.rm = T))
      
      ifelse(input$possible, 
             t<-nrow(dInBounds()[dInBounds()$score=='possible visual',]),
             t<-0)
      
      str4 <- paste0('<strong>Number of possible sighting events</strong>: ', t)
      
      ifelse(input$possible, 
             u<-sum(dInBounds()$number[dInBounds()$score=='possible visual'], na.rm = T),
             u<-0)
      
      str5 <- paste0('<strong>Number of whales possibly sighted</strong>: ', u)
      
      str6 <- paste0('<strong>Number of definite detections</strong>: ', 
                     nrow(dInBounds()[dInBounds()$score=='definite acoustic',]))
      
      ifelse(input$possible, 
             v<-nrow(dInBounds()[dInBounds()$score=='possible acoustic',]),
             v<-0)
      
      str7 <- paste0('<strong>Number of possible detections</strong>: ', v)
      
      # earliest and latest observation info
      str8 <- paste0('<strong>Earliest observation</strong>: ', min(dInBounds()$date, na.rm = T))
      rec_ind = which.max(dInBounds()$date)
      
      str9 <- paste0('<strong>Most recent observation</strong>: ', dInBounds()$date[rec_ind])
      
      str10 <- paste0('<strong>Most recent position</strong>: ', 
                     dInBounds()$lat[rec_ind], ', ', dInBounds()$lon[rec_ind])
      
      # paste and render
      HTML(paste(str1, str2, str3, str4, str5, str6, str7, str8, str9, str10, sep = '<br/>'))
    }
  })
  
  # bargraph ----------------------------------------------------------------
  
  output$graph <- renderPlotly({
    
    # define input observations
    if(input$plotInBounds){
      # use only data within map bounds
      obs = dInBounds()
    } else {
      # use all input data
      obs = spp()  
    }
    
    # define input tracks
    if(input$plotInBounds){
      # use only data within map bounds
      tracks = tInBounds()
    } else {
      # use all input data
      tracks = TRACKS()  
    }
    
    # conditionally remove possibles for plotting
    if(!input$possible){
      obs = obs[obs$score!='possible acoustic' & obs$score!='possible visual',]
    }
    
    # avoid error if no data selected or in map view
    if(nrow(obs)==0|nrow(tracks)==0){
      return(NULL)
    }
    
    # make categories for facet plotting
    obs$cat = ''
    obs$cat[obs$score == 'definite visual' | obs$score == 'possible visual'] = 'Sighting events per day'
    obs$cat[obs$score == 'definite acoustic' | obs$score == 'possible acoustic'] = 'Acoustic detection events per day'
    
    # determine days with trackline effort
    vis_effort = unique(tracks$yday[tracks$platform %in% visual_platforms])
    aco_effort = unique(tracks$yday[tracks$platform %in% acoustic_platforms])
    eff = data.frame('yday' = c(vis_effort, aco_effort),
                     'cat' = c(rep('Sighting events per day',length(vis_effort)), 
                               rep('Acoustic detection events per day',length(aco_effort))),
                     'y' = -1)
    
    # determine number of factor levels to color
    ncol = length(unique(obs[,which(colnames(obs)==colorby())]))
    
    # get input for color palette choice
    ind = as.numeric(input$pal)
    
    # list palettes for discrete scale (must be in the same order as palette_list)
    palette_list2 = list(heat.colors(ncol), 
                         oce.colorsTemperature(ncol),
                         oce.colorsSalinity(ncol),
                         oce.colorsDensity(ncol),
                         oce.colorsChlorophyll(ncol),
                         oce.colorsGebco(ncol),
                         oce.colorsJet(ncol),
                         oceColorsViridis(ncol))
    
    if(colorby() %in% c('number', 'lat','lon', 'year')){
      
      # replace all sightings/detections with '1' to facilitate stacked plotting
      obs$counter = 1
      
      if(colorby() == 'year'){
        # convert year to factor
        obs$year = as.factor(obs$year)
      }
      
      # choose palette for discrete scale
      cols = palette_list2[[ind]]
      
      # define palette for discrete scale
      fillcols = scale_fill_manual(values = cols, name = colorby())
        
      # build plot
      g = ggplot(obs, aes(x = yday, y = counter))+
        geom_histogram(stat = "identity", na.rm = T, aes_string(fill = paste0(colorby())))+
        labs(x = '', y = '')+
        fillcols+
        facet_wrap(~cat, scales="free_y", nrow = 2)+
        scale_x_continuous(labels = function(x) format(as.Date(as.character(x), "%j"), "%d-%b"), 
                           breaks = seq(from = min(ydays()), to = max(ydays()), length.out = 6))+
        geom_point(data = eff, aes(x = yday, y=y), pch=45, cex = 3, col = 'blue')+
        aes(text = paste('date: ', format(as.Date(as.character(yday), "%j"), "%d-%b")))+
        expand_limits(x = c(min(ydays()), max(ydays())))
      
    } else {
      if(colorby()=='score'){
        
        # manually define colors based on score
        fillcols = scale_fill_manual(values = score_cols, name = colorby())
        
        # order factors so possibles plot first
        obs$score <- factor(obs$score, 
                            levels=levels(obs$score)[order(levels(obs$score), decreasing = TRUE)])
        
      } else if(colorby()=='yday'){
        
        # choose palette for continuous scale
        cols = palette_list[[ind]]
        
        # define colors for continuous scale
        fillcols = scale_fill_gradientn(colours = cols, name = colorby())
        
      } else {
        
        # choose palette for discrete scale
        cols = palette_list2[[ind]]
        
        # define palette for discrete scale
        fillcols = scale_fill_manual(values = cols, name = colorby())
      }
      
      # build plot
      g = ggplot(obs, aes(x = yday))+
        geom_histogram(stat = "count", na.rm = T, aes_string(fill = paste0(colorby())))+
        labs(x = '', y = '')+
        fillcols+
        facet_wrap(~cat, scales="free_y", nrow = 2)+
        scale_x_continuous(labels = function(x) format(as.Date(as.character(x), "%j"), "%d-%b"),
                           breaks = seq(from = min(ydays()), to = max(ydays()), length.out = 6))+
        geom_point(data = eff, aes(x = yday, y=y), pch=45, cex = 3, col = 'blue')+
        aes(text = paste('date: ', format(as.Date(as.character(yday), "%j"), "%d-%b")))+
        expand_limits(x = c(min(ydays()), max(ydays())))
    }
    
    # build interactive plot
    gg = ggplotly(g, dynamicTicks = F, tooltip = c("text", "count", "fill")) %>%
      layout(margin=list(r=120, l=70, t=40, b=70), showlegend = input$legend)
    gg$elementId <- NULL # remove widget id warning
    gg
  })
  
  # status table ------------------------------------------------------------
  
  # read in helper function
  source('functions/make_status_table.R')
  
  # make status table
  sdf = make_status_table('data/processed/status.txt')
  
  # render table
  output$status = renderTable({sdf}, striped = TRUE,
                              hover = TRUE,
                              bordered = TRUE, colnames = TRUE,
                              align = 'l',
                              width = '100%')
  
  # session -----------------------------------------------------------------
  
  # Set this to "force" instead of TRUE for testing locally (without Shiny Server)
  session$allowReconnect(TRUE)
  
} # server





