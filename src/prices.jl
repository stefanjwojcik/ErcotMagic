## Prices Data 

function ancillary_long_to_wide(dat::DataFrame)
    # Convert the long format DataFrame to wide format
    dat_wide = unstack(dat, :AncillaryType, :MCPC)
    return dat_wide
end

"""
## Get all prices data 

prcs = get_prices([Date(2024, 2, 1), Date(2024, 2, 2)])

"""
function get_prices(dates::Vector{Date}; kwargs...)
    pricesendpoints = ErcotMagic.EndPoint[
                ErcotMagic.da_prices,
                ErcotMagic.da_system_lambda,
                ErcotMagic.ancillary_prices,
                ErcotMagic.rt_prices,
                ErcotMagic.rt_system_lambda
        ]
    out = DataFrame[]
    for ep in pricesendpoints
        dat = ErcotMagic.normalize_columnnames!(ErcotMagic.get_data(ep, dates; kwargs...))
        if ep.summary == "DAM Clearing Prices for Capacity"
            # Convert the long format DataFrame to wide format
            dat = ErcotMagic.ancillary_long_to_wide(dat)
        end
        push!(out, dat)
    end
    # Combine all DataFrames into one
    return out
end

