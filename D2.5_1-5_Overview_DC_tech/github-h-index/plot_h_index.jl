import CairoMakie
import PlotlyBase
using CSV, DataFrames

# Language categories
const LANGUAGE_COLORS = Dict(
    "Julia"      => "#9558B2",
    "R"          => "#276DC1",
    "Python"     => "#44B85D",
    "C/C++/Java" => "#F34B7D",
    "Rust"       => "#DEA584",
    "JavaScript" => "#F1E05A",
    "Spec/Docs"  => "#BBBBBB",
)

# Hardcoded owner/repo → language classification (108 repos)
const CLASSIFY_LANGUAGE = Dict{String,String}(
    # ── Julia (26) ──
    "juliageo/geointerface.jl"         => "Julia",
    "juliageo/geometryops.jl"          => "Julia",
    "juliageo/geojson.jl"              => "Julia",
    "juliageo/ncdatasets.jl"           => "Julia",
    "juliageo/proj.jl"                 => "Julia",
    "juliageo/gdal.jl"                 => "Julia",
    "juliageo/discreteglobalgrids.jl"  => "Julia",
    "juliageo/geoparquet.jl"           => "Julia",
    "juliageo/geoarrow.jl"             => "Julia",
    "juliaio/diskarrays.jl"            => "Julia",
    "juliaio/zarr.jl"                  => "Julia",
    "juliadatacubes/yaxarrays.jl"      => "Julia",
    "juliadatacubes/yaxarraybase.jl"   => "Julia",
    "juliadatacubes/pyramidscheme.jl"  => "Julia",
    "makieorg/makie.jl"                => "Julia",
    "makieorg/geomakie.jl"             => "Julia",
    "makieorg/tyler.jl"                => "Julia",
    "yeesian/archgdal.jl"              => "Julia",
    "rafaqz/rasters.jl"                => "Julia",
    "rafaqz/dimensionaldata.jl"        => "Julia",
    "meggart/sphericalspatialtrees.jl" => "Julia",
    "evetion/geodataframes.jl"         => "Julia",
    "evetion/flatgeobuf.jl"            => "Julia",
    "deltares/geomorphometry.jl"       => "Julia",
    "paleolimbot/geos"                 => "Julia",
    "geocompx/geocompjl"               => "Julia",
    # ── R (34) ──
    "appelmar/gdalcubes"               => "R",
    "brazil-data-cube/rstac"           => "R",
    "r-spatial/mapedit"                => "R",
    "r-spatial/mapview"                => "R",
    "r-spatial/sf"                     => "R",
    "r-spatial/geoarrowwidget"         => "R",
    "r-spatial/s2"                     => "R",
    "r-spatial/stars"                  => "R",
    "r-spatial/gstat"                  => "R",
    "r-spatialecology/landscapemetrics"=> "R",
    "r-spatialecology/shar"            => "R",
    "r-spatialecology/belg"            => "R",
    "r-spatialecology/vectormetrics"   => "R",
    "ropensci/landscapetools"          => "R",
    "ropenspain/spanishoddata"         => "R",
    "r-lidar/lidr"                     => "R",
    "r-lidar/lasr"                     => "R",
    "rspatial/terra"                   => "R",
    "nowosad/supercells"               => "R",
    "edzer/sp"                         => "R",
    "flowmapblue/flowmapblue.r"        => "R",
    "sjewo/cartogram"                  => "R",
    "open-eo/openeo-r-client"          => "R",
    "geocompx/geocompr"                => "R",
    "geocompx/tmap"                    => "R",
    "cityriverspaces/rcrisp"           => "R",
    "cityriverspaces/visor"            => "R",
    "cityriverspaces/rcoins"           => "R",
    "cidree/duckspatial"               => "R",
    "cidree/duckh3"                    => "R",
    "e-kotov/gridmaker"                => "R",
    "e-kotov/osrm.backend"             => "R",
    "e-kotov/r5r"                      => "R",
    "e-kotov/r5rgui"                   => "R",
    "e-kotov/sx"                       => "R",
    "e-kotov/zeroserve"                => "R",
    "marcosci/layer"                   => "R",
    # ── Python (29) ──
    "geopandas/geopandas"              => "Python",
    "geopandas/pyogrio"                => "Python",
    "shapely/shapely"                  => "Python",
    "pysal/pysal"                      => "Python",
    "pydata/xarray"                    => "Python",
    "xarray-contrib/cupy-xarray"       => "Python",
    "xarray-contrib/xskillscore"       => "Python",
    "xarray-contrib/xvec"              => "Python",
    "pangeo-data/climpred"             => "Python",
    "genericmappingtools/pygmt"        => "Python",
    "openlandmap/scikit-map"           => "Python",
    "geoarrow/geoarrow-python"         => "Python",
    "open-eo/openeo-python-client"     => "Python",
    "geocompx/geocompy"                => "Python",
    "movingpandas/movingpandas"        => "Python",
    "benbovy/spherely"                 => "Python",
    "weiji14/cog3pio"                  => "Python",
    "developmentseed/lonboard"         => "Python",
    "developmentseed/obstore"          => "Python",
    "developmentseed/async-geotiff"    => "Python",
    "yunusserhat/geoai-vlm"            => "Python",
    "yunusserhat/sppt-python"          => "Python",
    "gatorlab-geo/dggs-bench"          => "Python",
    "nismod/snkit"                     => "Python",
    "nismod/snail"                     => "Python",
    "nismod/infra-risk-vis"            => "Python",
    "nismod/open-gira"                 => "Python",
    "open-earth-monitor/globalearthpoint" => "Python",
    "sajed-s/sron"                     => "Python",
    "xcube-dev/xcube"                  => "Python",
    "SciTools/iris"                    => "Python",
    "opendatacube/datacube-core"       => "Python",
    # ── C/C++/Java (8) ──
    "postgis/postgis"                  => "C/C++/Java",
    "libgeos/geos"                     => "C/C++/Java",
    "valhalla/valhalla"                => "C/C++/Java",
    "qgis/qgis"                        => "C/C++/Java",
    "geoserver/geoserver"              => "C/C++/Java",
    "apache/sedona"                    => "C/C++/Java",
    "apache/arrow"                     => "C/C++/Java",
    "apache/parquet-format"            => "C/C++/Java",
    # ── Rust (3) ──
    "georust/geotiff"                  => "Rust",
    "geoarrow/geoarrow-rs"             => "Rust",
    "developmentseed/async-tiff"       => "Rust",
    # ── JavaScript (3) ──
    "geoarrow/deck.gl-geoarrow"        => "JavaScript",
    "developmentseed/deck.gl-raster"   => "JavaScript",
    "samherniman/indoor_co2_visuals"   => "JavaScript",
    "msoechting/lexcube"               => "JavaScript",
    # ── Spec/Docs (5) ──
    "geoarrow/geoarrow"                => "Spec/Docs",
    "zarr-developers/geozarr-spec"     => "Spec/Docs",
    "open-eo/openeo-api"               => "Spec/Docs",
    "geocompx/geocompx.org"            => "Spec/Docs",
    "geocompx/docker"                  => "Spec/Docs",
    "zarr-developers/zarr-spec"        => "Spec/Docs",
    "radiantearth/stac-spec"           => "Spec/Docs",
)

function load_results(path = "results.csv")
    df = CSV.read(path, DataFrame)
    dropmissing!(df, [:stars, :total_commits, :h_index])
    df.language = [get(CLASSIFY_LANGUAGE, repo, "Other") for repo in df.repo]
    return df
end

function shortlabel(repo::AbstractString)
    parts = split(repo, '/')
    length(parts) == 2 ? String(parts[2]) : repo
end

function make_static_plots(df::DataFrame; outdir = ".")
    mkpath(outdir)
    CM = CairoMakie

    languages = sort(unique(df.language))

    fig1 = CM.Figure(size = (700, 500))
    ax1 = CM.Axis(fig1[1, 1];
                  xlabel = "GitHub Stars",
                  ylabel = "h-index",
                  xscale = log10,
                  title = "h-index vs stars")
    for lang in languages
        subset = df[df.language .== lang, :]
        c = get(LANGUAGE_COLORS, lang, "#AAAAAA")
        CM.scatter!(ax1, subset.stars, subset.h_index;
                    color = c, markersize = 6, strokewidth = 0.5, label = lang)
    end
    for row in eachrow(df)
        CM.text!(ax1, shortlabel(row.repo);
                 position = (row.stars, row.h_index),
                 fontsize = 5, offset = (5, 0), color = :gray30)
    end
    CM.Legend(fig1[1, 2], ax1)
    CM.save(joinpath(outdir, "h_index_vs_stars.png"), fig1; px_per_unit = 2)
    CM.save(joinpath(outdir, "h_index_vs_stars.svg"), fig1)

    fig2 = CM.Figure(size = (700, 500))
    ax2 = CM.Axis(fig2[1, 1];
                  xlabel = "Total Commits (5 yr)",
                  ylabel = "h-index",
                  xscale = log10,
                  title = "Commits vs h-index")
    for lang in languages
        subset = df[df.language .== lang, :]
        c = get(LANGUAGE_COLORS, lang, "#AAAAAA")
        CM.scatter!(ax2, subset.total_commits, subset.h_index;
                    color = c, markersize = 6, strokewidth = 0.5, label = lang)
    end
    for row in eachrow(df)
        CM.text!(ax2, shortlabel(row.repo);
                 position = (row.total_commits, row.h_index),
                 fontsize = 5, offset = (5, 0), color = :gray30)
    end
    CM.Legend(fig2[1, 2], ax2)
    CM.save(joinpath(outdir, "commits_vs_h_index.png"), fig2; px_per_unit = 2)
    CM.save(joinpath(outdir, "commits_vs_h_index.svg"), fig2)
end

function _hover_text(df)
    ["$(row.repo) [$(row.language)]<br>★$(row.stars) | h=$(row.h_index) | $(row.total_commits) commits"
     for row in eachrow(df)]
end

function make_interactive_plots(df::DataFrame; outdir = ".")
    mkpath(outdir)
    hover = _hover_text(df)
    languages = sort(unique(df.language))
    PB = PlotlyBase

    p1 = PB.Plot()
    for lang in languages
        subset = df[df.language .== lang, :]
        c = get(LANGUAGE_COLORS, lang, "#AAAAAA")
        h = hover[df.language .== lang]
        push!(p1.data, PB.scatter(; x = subset.stars, y = subset.h_index,
                                  mode = "markers",
                                  marker = PB.attr(size = 8, color = c),
                                  name = lang,
                                  text = h, hoverinfo = "text"))
    end
    p1.layout = PB.Layout(; xaxis = PB.attr(title = "GitHub Stars", type = "log"),
                          yaxis = PB.attr(title = "h-index"),
                          title = "h-index vs stars",
                          width = 700, height = 500)
    open(joinpath(outdir, "h_index_vs_stars.html"), "w") do io
        PB.to_html(io, p1; include_plotlyjs = "cdn", default_width = "700px", default_height = "500px")
    end

    p2 = PB.Plot()
    for lang in languages
        subset = df[df.language .== lang, :]
        c = get(LANGUAGE_COLORS, lang, "#AAAAAA")
        h = hover[df.language .== lang]
        push!(p2.data, PB.scatter(; x = subset.total_commits, y = subset.h_index,
                                  mode = "markers",
                                  marker = PB.attr(size = 8, color = c),
                                  name = lang,
                                  text = h, hoverinfo = "text"))
    end
    p2.layout = PB.Layout(; xaxis = PB.attr(title = "Total Commits (5 yr)", type = "log"),
                          yaxis = PB.attr(title = "h-index"),
                          title = "Commits vs h-index",
                          width = 700, height = 500)
    open(joinpath(outdir, "commits_vs_h_index.html"), "w") do io
        PB.to_html(io, p2; include_plotlyjs = "cdn", default_width = "700px", default_height = "500px")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    csvpath = length(ARGS) >= 1 ? ARGS[1] : "results.csv"
    outdir  = length(ARGS) >= 2 ? ARGS[2] : "."
    df = load_results(csvpath)
    println("Loaded $(nrow(df)) repos from $csvpath")
    make_static_plots(df; outdir)
    println("Static plots written to $outdir")
    make_interactive_plots(df; outdir)
    println("Interactive plots written to $outdir")
end
