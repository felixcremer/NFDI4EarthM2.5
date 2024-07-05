using YAXArrays, Proj
using NetCDF
using Statistics
ds = open_dataset("data/tas_EUR-6km_ECMWF-ERAINT_REA6_r1i1p1f1_COSMO_v1_mon_199501-199512.nc")

olonp = 180 - ds.rotated_latitude_longitude.properties["grid_north_pole_longitude"]
olatp = ds.rotated_latitude_longitude.properties["grid_north_pole_latitude"]
o_lon_0 = 0.0

p = "+proj=ob_tran +o_proj=latlon +o_lon=0 +o_lat_p=$olatp +lon_0=$olonp"

t = Proj.Transformation(p,"OGC:84")
#Compute lons and lats from rotated grid
lonlat_proj =t.(ds.rlon.val,ds.rlat.val')
longitude_computed = first.(lonlat_proj)
latitude_computed = last.(lonlat_proj)

data = ds.tas[:,:,1].data
using GeoMakie, GLMakie
fig = Figure();
#Either plot directly using our projection
ga1 = GeoAxis(
    fig[1, 1]; # any cell of the figure's layout
    dest = p, # the CRS in which you want to plot
    coastlines = true
)
fig
# Or use the computed longitudes and latitudes for the plot
ga2 = GeoAxis(
    fig[1, 2]; # any cell of the figure's layout
    dest = "+proj=moll", # the CRS in which you want to plot
)

surface!(ga1, longitude_computed,latitude_computed,data)#,lonlims=extrema(longitude_computed),latlims=extrema(latitude_computed))
surface!(ga2, longitude_computed, latitude_computed, data)
fig


#Test the results, there are some deviations from the lons and lats provided in the dataset
wraplon(x) = x<-180.0 ? x+360 : x>180.0 ? x-360 : x
wrapmean(x) = mean(wraplon,x) 
centerlons = mapslices(wrapmean,ds.vertices_longitude,dims="vertices")
centerlats = mapslices(mean,ds.vertices_latitude,dims="vertices")

centerlons.data

lon_error = centerlons.data[:,:].- first.(lonlat_proj)

lat_error = centerlats.data[:,:] .- last.(lonlat_proj)

lon_error

using CairoMakie, Makie
heatmap(clamp.(lon_error,-0.001,0.001))
heatmap(clamp.(lat_error,-0.001,0.001))

fig = Figure()

for i in 0:6
    for j in 0:6
        olonp = 60 * i
        olatp = 60 * j
        p = "+proj=ob_tran +o_proj=latlon +o_lon_p=$olonp +o_lat_p=$olatp +lon_0=180.0"
        ga2 = GeoAxis(
    fig[i, j]; # any cell of the figure's layout
    dest = p, # the CRS in which you want to plot
    coastlines = true, title="Lon: $olonp Lat: $olatp"
)
    end
end

