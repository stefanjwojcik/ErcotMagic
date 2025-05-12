## Prices Data 

function ancillary_long_to_wide(dat::DataFrame)
    # Convert the long format DataFrame to wide format
    dat_wide = unstack(dat, :AncillaryType, :MCPC)
    return dat_wide
end

"""
## Get all prices data 

prcs = get_hourly_prices([Date(2024, 2, 1), Date(2024, 2, 2)])

"""
function get_hourly_prices(dates::Vector{Date}; kwargs...)
    ## Define endpoints 
    pricesendpoints = ErcotMagic.EndPoint[
                ErcotMagic.da_prices,
                ErcotMagic.da_system_lambda,
                ErcotMagic.ancillary_prices,
        ]
    out = DataFrame[]
    for ep in pricesendpoints
        dat = ErcotMagic.normalize_columnnames!(ErcotMagic.get_data(ep, dates; kwargs...))
        ErcotMagic.add_datetime!(dat)
        if ep.summary == "DAM Clearing Prices for Capacity"
            # Convert the long format DataFrame to wide format
            dat = ErcotMagic.ancillary_long_to_wide(dat)
        elseif ep.summary == "SCED System Lambda"
            # Convert the long format DataFrame to wide format
            ErcotMagic.add_sced_hourly_column!(dat)
        end
        push!(out, dat)
    end
    # join all the dataframes by DATETIME against the
    # Combine all DataFrames into one
    return out
end

"""
## Get five min prices data 

prcs = get_five_min_prices([Date(2024, 2, 1), Date(2024, 2, 2)])
"""
function get_five_min_prices(dates::Vector{Date}; kwargs...)    # NODAL RT 
    rt_nodal = ErcotMagic.normalize_columnnames!(ErcotMagic.get_data(ErcotMagic.rt_prices, dates; kwargs...))
    ErcotMagic.add_datetime!(rt_nodal)
    select!(rt_nodal, Not([:DSTFlag, :DeliveryInterval, :DeliveryDate, :DeliveryHour]))
    # SYSTEM LAMBDA RT 
    rt_system_lambda = ErcotMagic.normalize_columnnames!(ErcotMagic.get_data(ErcotMagic.rt_system_lambda, dates; kwargs...))
    select!(rt_system_lambda, Not([:RepeatHourFlag]))
    rt_system_lambda.DATETIME = Dates.floor.(DateTime.(rt_system_lambda[:, :SCEDTimestamp]), Dates.Minute)
    ##### Join on 5 min intervals
    dat = leftjoin(rt_nodal, rt_system_lambda, on = :DATETIME)
    return dat
end

function join_all_prices(fiveminprices::DataFrame, hourlyprices::DataFrame; kwargs...)
    agg = get(kwargs, :agg, "5min")
    if agg == "5min"
        # join on DATETIME
        out = leftjoin(hourlyprices, fiveminprices, on = :DATETIME)

    else 
        # aggregate fivemin prices to hourly
        fiveminprices = ErcotMagic.to_hourly(fiveminprices, :DATETIME)
        # join on DATETIME
        out = leftjoin(hourlyprices, fiveminprices, on = :DATETIME)
    end
    return out 
end