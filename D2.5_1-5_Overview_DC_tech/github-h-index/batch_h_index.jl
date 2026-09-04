include("compute-h-index.jl")

using GitHub, CSV, DataFrames

"""
    parse_github_url(raw) -> Union{String,Nothing}

Extract `"owner/repo"` from a GitHub URL string.  Handles bare `github.com/…`
(no protocol), trailing slashes, sub-paths (`/tree/…`, `/blob/…`, `/issues/…`),
trailing annotations like `(minor contributor)`, and leading/trailing whitespace.
Returns `nothing` when no valid owner/repo can be extracted.
"""
function parse_github_url(raw::AbstractString)
    s = strip(raw)
    s = replace(s, r"\s*\(.*$" => "")           # strip parenthetical annotations
    s = strip(s, '/')
    m = match(r"github\.com/([^/\s]+/[^/\s]+)", s)
    m === nothing && return nothing
    return lowercase(m.captures[1])
end

"""
    read_repos(path) -> Vector{String}

Read a file of GitHub URLs (one per line), parse and deduplicate them.
Returns sorted unique `"owner/repo"` strings.
"""
function read_repos(path::AbstractString)
    seen = Set{String}()
    for line in eachline(path)
        repo = parse_github_url(line)
        repo === nothing && continue
        push!(seen, repo)
    end
    return sort(collect(seen))
end

"""
    batch_main(repos; years=5, auth=nothing, skip_bots=true, output="results.csv")

Process a list of `"owner/repo"` strings.  For each repository, fetch the current
star count and weekly contributor statistics over the past `years` years.  Writes
a CSV file with columns `repo,stars,total_commits,h_index,n_contributors,error`.

Returns a `DataFrame`.
"""
function batch_main(repos::AbstractVector{<:AbstractString};
                    years::Integer = 5,
                    auth = nothing,
                    skip_bots::Bool = true,
                    output::AbstractString = "results.csv",
                    max_wait::Real = 60)
    since = today() - Year(years)
    n = length(repos)
    df = DataFrame(repo = String[],
                   stars = Union{Int,Nothing}[],
                   total_commits = Union{Int,Nothing}[],
                   h_index = Union{Int,Nothing}[],
                   n_contributors = Union{Int,Nothing}[],
                   error = String[])
    for (i, repo) in enumerate(repos)
        _kg_progress("[$i/$n] $repo")
        _kg_cancelled() && break
        stars = nothing
        total_commits = nothing
        h = nothing
        n_contrib = nothing
        err = ""
        # --- stars ---
        try
            r = GitHub.repo(repo; _auth_kw(auth)...)
            stars = r.stargazers_count
        catch e
            err = sprint(showerror, e)
        end
        # --- weekly contributor stats ---
        if isempty(err)
            try
                wc = fetch_weekly_commit_counts(repo; since, auth, skip_bots, max_wait)
                total_commits = sum(values(wc); init = 0)
                h = h_index(wc)
                n_contrib = length(wc)
            catch e
                err = sprint(showerror, e)
            end
        end
        push!(df, (repo = repo, stars = stars, total_commits = total_commits,
                   h_index = h, n_contributors = n_contrib, error = err))
        status = isempty(err) ? "★$(stars) h=$(h) commits=$(total_commits)" : "ERROR: $(err)"
        println("  [$i/$n] $repo — $status")
        sleep(0.2)
    end
    CSV.write(output, df)
    _kg_stash(:results, df)
    return df
end

if abspath(PROGRAM_FILE) == @__FILE__
    listpath = length(ARGS) >= 1 ? ARGS[1] : "repository_list.txt"
    outpath  = length(ARGS) >= 2 ? ARGS[2] : "results.csv"
    auth = isempty(get(ENV, "GITHUB_TOKEN", "")) ? nothing : github_auth()
    repos = read_repos(listpath)
    println("Parsed $(length(repos)) unique repositories from $listpath")
    df = batch_main(repos; auth, output = outpath)
    println("Results written to $outpath ($(nrow(df)) rows)")
end
