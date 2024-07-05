# # Introduction to raster data analysis in Julia, Python and R

# ## Dataset




# Julia

# First we have to load the relevant packages.

using YAXArrays # This package is for handling large raster data 
using NetCDF # This package is for opening NetCDF files 
using GLMakie # Plotting package with a focus on interactivity
using DimensionalData # Package to handle named and labeled arrays
using Rasters
using Downloads: download # Standard Library to handle downloads to get the data
using NCDatasets
using GADM # Package for loading state borders
# Now we download the monthly data for the year 1995 to first have a look at the data

url = "http://esgf1.dkrz.de/thredds/fileServer/cosmo-rea/reanalysis/EUR-6km/DWD/ECMWF-ERAINT/REA6/r1i1p1f1/COSMO/v1/mon/atmos/tas/v20230314/tas_EUR-6km_ECMWF-ERAINT_REA6_r1i1p1f1_COSMO_v1_mon_199501-199512.nc"
filename = split(url, "/")[end]
mkpath("data/")
path = download(url, "data/$filename")
# We can now open the data as a Dataset.
# A Dataset is a collection of multiple data cubes which can have different dimensions.

r = Raster(path, key ="tas")

# Subsetting to 
jancube = r[Ti(Near(DateTime(1995,1,15)))]

Rasters.rplot(set(r, :rlat=>Y, :rlon=>X))

heatmap(jancube)
colorrange = (252, 312)
using Proj

ds = open_dataset(path)
datalats = ds.latitude.data[:,:]
datalons = ds.longitude.data[:,:]

newproj = begin
    olonp = 180 - ds.rotated_latitude_longitude.properties["grid_north_pole_longitude"]
    olatp = ds.rotated_latitude_longitude.properties["grid_north_pole_latitude"]
    o_lon_0 = 0.0
    
    p = "+proj=ob_tran +o_proj=latlon +o_lon=90 +o_lat_p=$olatp +lon_0=$olonp"    
end
trans = Proj.Transformation(newproj,"OGC:84")
r = trans.(ds.rlat.val,ds.rlon.val')
lons = first.(r)
lats = last.(r)
datalons .- lons
datalats .- lats
using CairoMakie, GeoMakie

fig = Figure();
mydata = ds.tas[time=Near(DateTime(1995,6,1))].data[:,:]
ga = GeoAxis(
    fig[1, 1]; # any cell of the figure's layout
    dest="+proj=lonlat",
    lonlims = extrema(lons), # the CRS in which you want to plot
    latlims = extrema(lats),
    coastlines = true # plot coastlines from Natural Earth, as a reference.
)
fig
surface!(ga,lons,lats, mydata)
fig
heatmap(lons)

#=
NetCDF raster files for entire Europe, near-surface air temperature:
    1. Subset for Germany (R tip: use scadem package)
    2. Split to two datasets by definition of seasons: 
        a. Summer (April – September) and Winter (October – March)
    3. Start with 1995
    4. Compute average temperature per pixel per year
    5. Compute standard deviation per pixel per year
    6. Load all the files
    7. Repeat calculation until 2019
    8. Plot a time-series for two datasets
Next exercise:
    1. Average temperature per German state for the two resulting datasets

=#