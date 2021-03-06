## proc_2018_noaa_twin_otter_sightings ##
# Process sightings data from NOAA Twin Otter survey plane

# user input --------------------------------------------------------------

# data directory
data_dir = 'data/raw/2018_noaa_twin_otter/edit_data/'

# output file name
ofile = '2018_noaa_twin_otter_sightings.rds'

# output directory
output_dir = 'data/interim/'

# setup -------------------------------------------------------------------

# libraries
library(lubridate, quietly = T, warn.conflicts = F)
suppressMessages(library(rgdal, quietly = T, warn.conflicts = F))
library(tools, quietly = T, warn.conflicts = F)

# functions
source('functions/config_data.R')

# list files to process
flist = list.files(data_dir, pattern = '.sig$', full.names = T, recursive = T)

# list to hold loop output
SIG = list()

# read and format data ----------------------------------------------------

# read files
for(i in seq_along(flist)){
  
  # skip empty files
  if (file.size(flist[i]) == 0) next
  
  # read in data
  tmp = read.table(flist[i], sep = ',')
  
  # assign column names
  colnames(tmp) = c('transect', 'unk1', 'unk2', 'time', 'observer', 'declination', 'species', 'number', 'confidence', 'bearing', 'unk5', 'unk6', 'comments', 'side', 'lat', 'lon', 'calf', 'unk7', 'unk8', 'unk9', 'unk10')
  
  # time format
  tformat = '%d/%m/%Y %H:%M'
  
  # remove final estimates
  tmp = tmp[!grepl(pattern = 'fin est', x = tmp$comments, ignore.case = TRUE),]
  
  # if they exist, only include actual positions
  if(nrow(tmp[grepl(pattern = 'ap', x = tmp$comments, ignore.case = TRUE),])>0){
    tmp = tmp[grepl(pattern = 'ap', x = tmp$comments, ignore.case = TRUE),]
  }
  
  # select important columns
  tmp = tmp[,c('time', 'lat', 'lon', 'species', 'number')]
  
  # remove columns without timestamp
  tmp = tmp[which(!is.na(tmp$time)),]
  
  # add timestamp
  tmp$time = as.POSIXct(tmp$time, format = tformat, tz="UTC", usetz=TRUE)
  
  # fix blank species rows
  tmp$species = as.character(tmp$species)
  tmp$species[tmp$species==""] = NA
  
  # add species identifiers
  tmp$species = toupper(tmp$species)
  tmp$species[tmp$species == 'EG'] = 'right'
  tmp$species[tmp$species == 'MN'] = 'humpback'
  tmp$species[tmp$species == 'BB'] = 'sei'
  tmp$species[tmp$species == 'BP'] = 'fin'
  tmp$species[tmp$species == 'FS'] = 'fin/sei'
  tmp$species[tmp$species == 'BA'] = 'minke'
  tmp$species[tmp$species == 'BM'] = 'blue'
  tmp$species[tmp$species == 'UW'] = 'unknown whale'
  
  # add metadata
  tmp$date = as.Date(tmp$time)
  tmp$yday = yday(tmp$date)
  tmp$year = year(tmp$date)
  tmp$score = 'sighted'
  tmp$platform = 'plane'
  tmp$name = 'noaa_twin_otter'
  tmp$id = paste(tmp$date, tmp$platform, tmp$name, sep = '_')
  
  # add to list
  SIG[[i]] = tmp
  
  # catch null error
  if(is.null(SIG[[i]])){stop('Sightings in ', flist[i], ' not processed correctly!')}
  
}

# combine and save --------------------------------------------------------

# catch errors
# if(length(SIG)!=length(flist)){stop('Not all sightings were processed!')}

# combine all flights
SIGS = do.call(rbind, SIG)

# config flight data
sig = config_observations(SIGS)

# save
saveRDS(sig, paste0(output_dir, ofile))
