make_status_table = function(sfile='status.txt'){
  ## make table to show status of platform data processing
    
  # read in data
  tab = read.csv(file = sfile, header = FALSE, stringsAsFactors = FALSE)
  
  # rename columns
  colnames(tab) = c('file', 'status')
  
  # trim white space
  tab$status = trimws(tab$status)
  
  # function to extract timestamp
  gs=function(pattern){
    tab$status[grepl(pattern = pattern, x = tab$file)]
  }
  
  # data source
  data.source = c('TC Dash7 Tracks', 
                  'TC Dash7 Sightings',
                  'TC Dash8 Tracks', 
                  'TC Dash8 Sightings',
                  'DFO Twin Otter Tracks', 
                  'DFO Twin Otter Sightings', 
                  'DFO Cessna Tracks', 
                  'DFO Cessna Sightings', 
                  'DFO Partenavia Tracks', 
                  'DFO Partenavia Sightings', 
                  'NOAA Twin Otter Tracks', 
                  'NOAA Twin Otter Sightings',
                  'Dal/WHOI Acoustic Detections',
                  'Opportunistic Sightings')
  
  # status                
  status = c(gs('2018_tc_dash7_tracks'), 
             gs('2018_tc_dash7_sightings'),
             gs('2018_tc_dash8_tracks'), 
             gs('2018_tc_dash8_sightings'),
             gs('2018_dfo_twin_otter_tracks'), 
             gs('2018_dfo_twin_otter_sightings'), 
             gs('2018_dfo_cessna_tracks'), 
             gs('2018_dfo_cessna_sightings'),
             gs('2018_dfo_partenavia_tracks'), 
             gs('2018_dfo_partenavia_sightings'), 
             gs('2018_noaa_twin_otter_tracks'), 
             gs('2018_noaa_twin_otter_sightings'), 
             gs('live_dcs'), 
             gs('2018_opportunistic'))
  
  # make data frame
  sdf = data.frame(data.source,status)
  
  # convert column types
  sdf$data.source = as.character(sdf$data.source)
  sdf$status = as.character(sdf$status)
  
  # sort with last updated at top
  sdf = sdf[order(sdf$status, decreasing = TRUE),]
  
  # adjust column names
  colnames(sdf) = c('Platform', 'Last processed [ADT]')
  
  return(sdf)
}
