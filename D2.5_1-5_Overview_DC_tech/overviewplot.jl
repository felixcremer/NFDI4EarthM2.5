using Makie
using GLMakie
using DataFrames

software = [
    ("HDF5", 1., 1.5),
    ("COG", 1, 3.1),
    ("NetCDF", 1., 1.2),
    ("Tile DB", 1.5, 3),
    ("Zarr", 1., 3),
    ("EarthDataLab.jl", 2., 2.4),
    ("Rasters.jl", 2., 1.5),
    ("Rasdaman", 1.5, 2),
    ("OpenEO", 2.7, 3),
    ("xarray", 2, 3),
    ("xcube", 2, 2.5),
    ("Iris", 2, 1),
    ("OpenDataCube", 2, 1.8),
    ("stars", 2, 1.4),
    ("terra", 2, 1.3),
    ("Google Earth Engine", 3, 2.8),
    ("DIAS", 3.1, 3),
    ("EOSC", 2.9, 3),
    ("STAC", 1, 2.8),
    ]


df = DataFrame(Name=String[], type=Float64[], scalability=Float64[])
push!.(Ref(df), software);
df

# planar plot 


# Radial plot


f = Figure()

ax1 = Axis(f[1,1], ylabel="Cloud Readiness", backgroundcolor = :gainsboro)
ax1.ylabelsize=30
ax1.xticklabelsize=30
text!(ax1, df.type, df.scalability, text=df.Name, align=(:center, :bottom), textsize=30)
ax1.xticks = ([1,2,3], ["Data Formats", "Analysis Software", "Cloud Services"])
hideydecorations!(ax1, label=false, grid=false)




Axis(f[1, 2], aspect = DataAspect(), backgroundcolor = :gray50)

scatter!(Point2f(0, 0))
text!(0, 0, text = "center", align = (:center, :center), textsize=30)


circlepoints = [(cos((r.type)* 2π / 3), sin((r.type)*2π / 3)) .* r.scalability for r in eachrow(df)]
scatter!(circlepoints)
text!(
    circlepoints,
    text = df.Name,
    #rotation = LinRange(0, 2pi, 16)[1:end-1],
    align = (:center, :baseline),
    #color = cgrad(:Spectral)[LinRange(0, 1, 15)]
)
