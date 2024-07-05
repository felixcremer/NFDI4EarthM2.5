# Intialization
library("rnaturalearth")
library("rnaturalearthdata")
library( "sf")
library( "raster")
library("stars")
library("lubridate")

# Set working directory and Destination Folder for file Downloads
setwd("~/COSMO")
destfile <- getwd()

# URL of DKRZ folder containing COSMO-REA Dataset files



# Download files to specified destination folder
l1 <- format(seq(as.Date("1995-01-01"), as.Date("2018-01-01"), by="year"), format = "%Y%m")
l2 <- format(seq(as.Date("1995-12-01"), as.Date("2018-12-01"), by="year"), format = "%Y%m")

for (i in 1:length(l1)) {
  x <- paste0(baseurl,l1[i],"-",l2[i],".nc")
  print(x)
  #download.file(x, paste0(destfile,"\\", basename(x)), mode = "wb") #download files
  urlList[i] <- x
  i = i + 1
}

## Read first file in COSMO-REA time-series (1995)
file = paste0(destfile, "/", basename(urlList[1]))
m = read_mdim(file, "tas", curvilinear = c("longitude", "latitude"))
plot(m[,,,1], downsample = 5, axes = TRUE, reset = FALSE) # downsample to save time
maps::map(add = TRUE)

# Warp curvilinear grid to regular grid in lon/lat
if (file.exists("out2.nc")) {
  file.remove("out2.nc")
}
gdal_utils("warp", file, "out2.nc")
m2 = read_mdim("out2.nc")                                 # now has time over bands, caused by "warp"
plot(m2, axes = TRUE, reset = FALSE)                      # fast: regular grid
maps::map(add = TRUE)

# Add time dimension and crs to re-gridded dataset
t = st_get_dimension_values(m, "time")
merge(m2, name = "time") |>
  st_set_dimensions("time", values = t) |>
  setNames("tas") -> m3
m3 <- st_set_crs(m3, st_crs(4326))
m3

## Repeat for every file in COSMO-REA time-series
for (i in 2:length(urlList)){
  file <- paste0(destfile, "/", basename(urlList[i]))
  a = read_mdim(file, "tas", curvilinear = c("longitude", "latitude"))
  
  if (file.exists("out2.nc")) {
    file.remove("out2.nc")
  }
  
  gdal_utils("warp", file, "out2.nc")
  b = read_mdim("out2.nc")                                 # now has time over bands, caused by "warp"
  i = i + 1
  t = st_get_dimension_values(a, "time")
  merge(b, name = "time") |>
    st_set_dimensions("time", values = t) |>
    setNames("tas") -> c
  c <- st_set_crs(c, st_crs(4326))
  m3 = c(m3,c, along = 3)
}

# Subset for Germany
germany <- ne_countries(type = "countries", country = "Germany", scale = "medium", returnclass = "sf")
m3_DEU <- m3[germany]
plot(m3_DEU)

# Split dataset into two by season
# Definition: Summer (April - September) & Winter (October - March)
a = seq(from = 4, to = 288, by = 12)
b = seq(from = 9, to = 288, by = 12)
winter <- m3_DEU[,,,4:9]

c = seq(from = 1, to = 288, by = 12)
d = seq(from = 3, to = 288, by = 12)
e = seq(from = 10, to = 288, by = 12)
f = seq(from = 12, to = 288, by = 12)
summer <- c(m3_DEU[,,,1:3], m3_DEU[,,,10:12])
## summer <- setdiff(m3_DEU, winter) # too slow

for ( i in 2:length(a)){
  x <- a[i]
  y <- b[i]
  obj <- m3_DEU[,,,x:y]
  winter <- c(winter,obj)
  w <- c[i]
  x <- d[i]
  y <- e[i]
  z <- f[i]
  obj <- c(m3_DEU[,,,w:x],m3_DEU[,,,y:z])
  summer <- c(summer, obj)
  i = i+1
}

## Compute average air temperature for each pixel per year
#For the whole year
#mean_tas <- aggregate(m3_DEU, by = "year", FUN = mean)
#For summer
summer_mean_tas <- aggregate(summer, by = "year", FUN = mean)
plot(summer_mean_tas)
# For winter
winter_mean_tas <- aggregate(winter, by = "year", FUN = mean)
plot(winter_mean_tas)

## Compute standard deviation of air temperature for each pixel per year 
#For the whole year
#sd_tas <- aggregate(m3_DEU, by = "year", FUN = sd)
#For summer 
summer_sd_tas <- aggregate(summer, by = "year", FUN = sd)
plot(summer_sd_tas)
#For winter
winter_sd_tas <- aggregate(winter, by = "year", FUN = sd)
plot(winter_sd_tas)