using GitHub
using Dates
using JSON

const _KAIMONGATE = let pkgid = Base.identify_package("KaimonGate")
    pkgid === nothing ? nothing : Base.require(pkgid)
end

_kg_progress(msg) = _KAIMONGATE === nothing ? nothing : _KAIMONGATE.progress(msg)
_kg_cancelled() = _KAIMONGATE === nothing ? false : _KAIMONGATE.is_cancelled()
_kg_stash(key, value) = _KAIMONGATE === nothing ? nothing : _KAIMONGATE.stash(String(key), value)

_auth_kw(auth) = auth === nothing ? NamedTuple() : (; auth)

"""
    github_auth() -> GitHub.OAuth2

Authenticate with the token in `ENV["GITHUB_TOKEN"]`, erroring when unset.
Anonymous access is limited to 60 requests/hour; a token raises this to 5000.
"""
function github_auth()
    token = get(ENV, "GITHUB_TOKEN", "")
    isempty(token) && error("ENV[\"GITHUB_TOKEN\"] is not set; create a personal access token at https://github.com/settings/tokens (no scopes required for reading public repositories)")
    return GitHub.authenticate(token)
end

iso8601(dt::DateTime) = Dates.format(dt, dateformat"yyyy-mm-dd\THH:MM:SS\Z")

"""
    contributor_key(commit) -> String

Identity key for a commit: `"@login"` when the author email is linked to a
GitHub account, otherwise the git identity `"Name <email>"`.
"""
function contributor_key(c::GitHub.Commit)
    if c.author !== nothing && c.author.login !== nothing
        return "@" * c.author.login
    end
    git_author = c.commit === nothing ? nothing : c.commit.author
    if git_author !== nothing && !(git_author.name === nothing && git_author.email === nothing)
        return "$(something(git_author.name, "")) <$(something(git_author.email, ""))>"
    end
    return "<unknown>"
end

"""
    fetch_commit_counts(repo; since, until = today(), auth = nothing,
                        per_page = 100, skip_bots = false, budget = nothing)
    -> Dict{String,Int}

Number of commits per contributor on `repo`'s default branch between `since`
and `until` (inclusive dates), via paginated requests to
`GET /repos/{owner}/{repo}/commits` with `since`/`until` parameters.
Contributors are keyed by [`contributor_key`](@ref).

With `budget::Integer`, error before spending more than that many requests if
the first page's `Link: rel="last"` header shows the history spans more pages
than the budget allows; this fails fast instead of exhausting the rate limit
partway through.
"""
function fetch_commit_counts(repo::AbstractString;
                             since::Date,
                             until::Date = today(),
                             auth = nothing,
                             per_page::Integer = 100,
                             skip_bots::Bool = false,
                             budget::Union{Integer, Nothing} = nothing)
    since <= until || throw(ArgumentError("since ($since) is after until ($until)"))
    params = Dict(
        "since" => iso8601(DateTime(since)),
        "until" => iso8601(DateTime(until) + Day(1) - Second(1)),
        "per_page" => string(per_page),
    )
    counts = Dict{String, Int}()
    next = ""
    npages = 0
    while true
        page, page_data = isempty(next) ?
            GitHub.commits(repo; params, page_limit = 1, _auth_kw(auth)...) :
            GitHub.commits(repo; start_page = next, page_limit = 1)
        npages += 1
        if npages == 1 && haskey(page_data, "last")
            m = match(r"[?&]page=(\d+)", page_data["last"])
            estimated_pages = m === nothing ? npages : parse(Int, m.captures[1])
            if budget !== nothing && estimated_pages > budget
                error("$repo has about $estimated_pages pages of commits in $(since)..$(until), but only $budget API requests remain; set GITHUB_TOKEN to raise the rate limit, or narrow the time window")
            end
        end
        for c in page
            key = contributor_key(c)
            skip_bots && occursin("[bot]", key) && continue
            counts[key] = get(counts, key, 0) + 1
        end
        _kg_progress("page $npages: $(length(page)) commits, $(length(counts)) distinct contributors so far")
        _kg_cancelled() && error("cancelled after $npages pages")
        haskey(page_data, "next") || break
        next = page_data["next"]
    end
    _kg_stash(:commit_counts, counts)
    return counts
end

"""
    fetch_weekly_commit_counts(repo; since, auth = nothing, skip_bots = false,
                               max_wait = 60) -> Dict{String,Int}

Number of commits per contributor on `repo`'s default branch for weeks starting
on or after `since`, from `GET /repos/{owner}/{repo}/stats/contributors`.
Weekly granularity. GitHub computes the report lazily, answering HTTP 202 until
it is ready; requests are repeated every 5 seconds for up to `max_wait` seconds
before erroring. The report can be stale or incomplete for very large
repositories, so treat the result as a cross-check rather than ground truth.
"""
function fetch_weekly_commit_counts(repo::AbstractString;
                                    since::Date,
                                    auth = nothing,
                                    skip_bots::Bool = false,
                                    max_wait::Real = 60)
    deadline = time() + max_wait
    r = GitHub.stats(repo, "contributors"; _auth_kw(auth)...)
    while r.status != 200 && time() < deadline
        _kg_progress("/stats/contributors returned HTTP $(r.status); waiting for GitHub to finish computing it")
        sleep(5)
        r = GitHub.stats(repo, "contributors"; _auth_kw(auth)...)
    end
    r.status != 200 && error("/stats/contributors returned HTTP $(r.status) after waiting $(max_wait)s")
    payload = JSON.parse(String(r.body))
    cutoff = datetime2unix(DateTime(since))
    counts = Dict{String, Int}()
    for entry in payload
        author = get(entry, "author", nothing)
        key = author === nothing ? "<unknown>" : "@" * author["login"]
        skip_bots && occursin("[bot]", key) && continue
        n = sum(w["c"] for w in entry["weeks"] if w["w"] >= cutoff; init = 0)
        n > 0 && (counts[key] = n)
    end
    return counts
end

"""
    h_index(counts) -> Int

The largest `h` such that at least `h` values in `counts` are `>= h`.
"""
function h_index(counts)
    sorted = sort(collect(values(counts)); rev = true)
    h = 0
    for (i, n) in enumerate(sorted)
        n >= i || break
        h = i
    end
    return h
end

"""
    contribution_table(counts) -> Vector{@NamedTuple{contributor::String, ncommits::Int}}

Contributor counts sorted by decreasing commit number.
"""
function contribution_table(counts)
    return sort([(contributor = k, ncommits = v) for (k, v) in counts];
                by = t -> t.ncommits, rev = true)
end

"""
    main(repo; years = 5, auth = nothing, skip_bots = false, crosscheck = true,
         budget = nothing)

Fetch per-contributor commit counts for `repo` (`"owner/name"`) over the last
`years` years and compute the contributor h-index. With `crosscheck = true`,
also fetch the `/stats/contributors` weekly report for comparison. Pass
`auth = github_auth()` for anything beyond very small repositories.
`budget` caps how many API requests the commit history may span; see
[`fetch_commit_counts`](@ref).
Returns a `NamedTuple` with fields `repo, since, until, table, h_index,
total_commits, weekly_counts, weekly_h_index, weekly_total_commits, weekly_error`;
on cross-check failure the error message is recorded in `weekly_error`.
"""
function main(repo::AbstractString;
              years::Integer = 5,
              auth = nothing,
              do_counts = true, 
              skip_bots::Bool = false,
              crosscheck::Bool = true,
              budget::Union{Integer, Nothing} = nothing)
    since = today() - Year(years)
    table, hindex, total_commits = if do_counts 
        counts = fetch_commit_counts(repo; since, auth, skip_bots, budget) 
        table = contribution_table(counts)
        total_commits = sum(values(counts); init = 0)
        hindex = h_index(counts)
        table, hindex,total_commits
    else
        nothing, nothing, nothing
    end
    weekly = nothing
    weekly_error = nothing
    if crosscheck
        try
            weekly = fetch_weekly_commit_counts(repo; since, auth, skip_bots)
        catch err
            weekly_error = sprint(showerror, err)
        end
    end

    return (repo = repo,
            since = since,
            until = today(),
            table = table,
            h_index = hindex,
            total_commits = total_commits,
            weekly_counts = weekly,
            weekly_h_index = weekly === nothing ? nothing : h_index(weekly),
            weekly_total_commits = weekly === nothing ? nothing : sum(values(weekly); init = 0),
            weekly_error = weekly_error)
end

function run_cli(args)
    isempty(args) && throw(ArgumentError("usage: julia compute-h-index.jl <owner/repo> [years]"))
    repo = args[1]
    years = length(args) >= 2 ? parse(Int, args[2]) : 5
    auth = nothing
    if isempty(get(ENV, "GITHUB_TOKEN", ""))
        println(stderr, "note: ENV[\"GITHUB_TOKEN\"] is not set; proceeding anonymously (60 requests/hour)")
    else
        auth = github_auth()
    end
    remaining = GitHub.rate_limit(; _auth_kw(auth)...)["resources"]["core"]["remaining"]
    result = main(repo; years, auth, budget = max(remaining - 2, 0), do_counts=false)
    if result.table !== nothing
        println("$(result.repo): $(result.total_commits) commits by $(length(result.table)) contributors, $(result.since) through $(result.until)")
        foreach(result.table) do t
            println(lpad(t.ncommits, 6), "  ", t.contributor)
        end
        println("h-index: ", result.h_index)
    end
    if result.weekly_counts !== nothing
        println("cross-check via /stats/contributors: h-index $(result.weekly_h_index), total $(result.weekly_total_commits)")
    elseif result.weekly_error !== nothing
        println(stderr, "cross-check failed: ", result.weekly_error)
    end
    return result
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_cli(ARGS)
end
