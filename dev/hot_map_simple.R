library(rhandsontable)
library(shiny)
library(leaflet)
library(leaflet.extras)

ui = fluidPage(
  fluidRow(
    column(width = 3,
           h3('Marker coordinates'),
           helpText('Add markers to populate the table below'),
           rHandsontableOutput("hot")
    ),
    column(width = 9,
           leafletOutput("map")
    )
  )
)

server = function(input, output, session) {
  
  # build map
  output$map = renderLeaflet({
    leaflet() %>% 
      addTiles() %>% setView(lng = -65, lat = 45, zoom = 5) %>%
      addDrawToolbar(position = "topleft",
                     polylineOptions = F,
                     polygonOptions = F,
                     circleOptions = F,
                     rectangleOptions = F,
                     markerOptions = drawMarkerOptions(repeatMode = T), 
                     editOptions = editToolbarOptions(),
                     targetGroup = 'grp',
                     singleFeature = F
      )
  })
  
  observeEvent(input$map_draw_all_features,{
    
    # extract lat lons of drawn objects
    f = input$map_draw_all_features
    lng = sapply(f$features, FUN = function(x) x$geometry$coordinates[[1]])
    lat = sapply(f$features, FUN = function(x) x$geometry$coordinates[[2]])
    DF = data.frame(lng, lat)
    
    # construct table
    output$hot = renderRHandsontable({
      rhandsontable(DF, rowHeaders = NULL) %>%
        hot_table(highlightCol = TRUE, highlightRow = TRUE)
      
    })
  })
  
  # update map after editing coordinates - this is where the problem is
  observe({
    if (is.null(input$hot))
      return()
    
    # read in values from table
    DF = hot_to_r(input$hot)
    
    # catch error for blank DF (e.g. after deleting all points)
    if(is.null(DF$lng))
      return()
    
    # replace old positions on map
    leafletProxy("map") %>%
      removeDrawToolbar(clearFeatures=TRUE) %>%
      addDrawToolbar(position = "topleft",
                     polylineOptions = F,
                     polygonOptions = F,
                     circleOptions = F,
                     rectangleOptions = F,
                     markerOptions = drawMarkerOptions(repeatMode = T), 
                     editOptions = editToolbarOptions(),
                     targetGroup = 'grp',
                     singleFeature = F
      ) %>%
      addMarkers(data = DF, lng = ~lng, lat = ~lat, group = 'grp')
  })
}

shinyApp(ui, server)
