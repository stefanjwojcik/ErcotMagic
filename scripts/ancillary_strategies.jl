## Estimate the Ancillary strategies for each asset 
## Get load/gen AS bids/offers 
# Get the ancillary prices for the given date range
# Determine which assets cleared ancillary services 
using ErcotMagic, Dates, DataFrames 

start_date = Date(2024, 12, 4)
end_date = Date(2024, 12, 5)

# Get the gen ancillary data 
sgas = ErcotMagic.SCED_gen_data(from=start_date, to=end_date, addparams=Dict("resourceName" => "NOBLESLR_BESS1"))
ErcotMagic.normalize_columnnames!(sgas)
# Filter to Noble BESS 
hi = select(sgas, r"Ancillary")

# Get the load ancillary data
sced_load = ErcotMagic.SCED_load_as(from=start_date, to=end_date)
# Filter to Noble BESS
ErcotMagic.normalize_columnnames!(sced_load)
sced_load_noble = filter(:LoadResourceName => x -> contains(x, r"NOBLESLR_BESS1"), sced_load)


# Price clears fors for a given date range
anc = ErcotMagic.batch_retrieve_data(start_date, end_date, "ancillary_prices")

# Get generation awards in SCED - actual awards 
sced_gen_awards = ErcotMagic.batch_retrieve_data(start_date, end_date, "gen_data", addparams=Dict("resourceName" => "NOBLESLR_BESS1"))

filter(:ResourceName => x -> contains(x, r"NOBLESLR_BESS1"), sced_gen_awards)

filter(:ResourceName => x -> contains(x, r"NOBLESLR_SOLAR1"), sced_gen_awards)

function coalescenothing!(df::DataFrame)
    # Convert all columns to allow `missing`
    allowmissing!(df)

    # Replace `nothing` with `missing` in all columns
    foreach(col -> replace!(col, nothing => missing), eachcol(df))
end

############
