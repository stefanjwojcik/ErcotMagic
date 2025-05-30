## Prices Data 

"""
Convert the long format DataFrame to wide format for ancillary prices
"""
function ancillary_long_to_wide(dat::DataFrame)
    # Convert the long format DataFrame to wide format
    dat_wide = unstack(dat, :AncillaryType, :MCPC)
    return dat_wide
end

"""
Get hourly DA prices for a single endpoint and a single date.
Example:
    df = get_single_hourly_da_price(ErcotMagic.da_prices, Date(2024, 2, 1); settlementPoint="AEEC")
"""
function get_single_hourly_da_price(endpoint::ErcotMagic.EndPoint, date::Date; kwargs...)
    colstodrop = [:DeliveryDate, :DSTFlag, :HourEnding]
    filtered_kwargs = filter_valid_kwargs(endpoint, kwargs)
    dat = ErcotMagic.normalize_columnnames!(ErcotMagic.get_data(endpoint, [date]; filtered_kwargs...))
    ErcotMagic.add_datetime!(dat)
    if endpoint.summary == "DAM Clearing Prices for Capacity"
        dat = ErcotMagic.ancillary_long_to_wide(dat)
    elseif endpoint.summary == "SCED System Lambda"
        ErcotMagic.add_sced_hourly_column!(dat)
    end
    return select(dat, Not(colstodrop))
end

"""
## Get all DA prices data 

hourlyprices = ErcotMagic.get_hourly_da_prices([Date(2024, 2, 1), Date(2024, 2, 2)]; settlementPoint="AEEC")

"""
function get_all_hourly_da_prices(dates::Vector{Date}; kwargs...)
    colstodrop = [:DeliveryDate, :DSTFlag, :HourEnding]
    ## Define endpoints 
    pricesendpoints = ErcotMagic.EndPoint[
                ErcotMagic.da_prices,
                ErcotMagic.da_system_lambda,
                ErcotMagic.ancillary_prices,
        ]
    out = DataFrame[]
    for ep in pricesendpoints
        # check to ensure kwargs exist 
        filtered_kwargs = filter_valid_kwargs(ep, kwargs)
        dat = ErcotMagic.normalize_columnnames!(ErcotMagic.get_data(ep, dates; filtered_kwargs...))
        ErcotMagic.add_datetime!(dat)
        if ep.summary == "DAM Clearing Prices for Capacity"
            # Convert the long format DataFrame to wide format
            dat = ErcotMagic.ancillary_long_to_wide(dat)
        elseif ep.summary == "SCED System Lambda"
            # Convert the long format DataFrame to wide format
            ErcotMagic.add_sced_hourly_column!(dat)
        end
        push!(out, select(dat, Not(colstodrop)))
    end
    # join all the dataframes by DATETIME against the nodal prices
    df = out[1] |> 
        (data -> leftjoin(data, out[2], on = :DATETIME)) |>
        (data -> leftjoin(data, out[3], on = :DATETIME))
    rename!(df, :SettlementPointPrice => :DA_SettlementPointPrice)
    rename!(df, :SystemLambda => :DA_SystemLambda)
    # Combine all DataFrames into one
    return df
end

"""
## Get five min prices data 

fiveminprices = get_five_min_rt_prices([Date(2024, 2, 1), Date(2024, 2, 2)]; settlementPoint="AEEC")
"""
function get_five_min_rt_prices(dates::Vector{Date}; kwargs...)    # NODAL RT 
    filtered_kwargs = filter_valid_kwargs(ErcotMagic.rt_prices, kwargs)
    # NODAL RT
    rt_nodal = ErcotMagic.normalize_columnnames!(ErcotMagic.get_data(ErcotMagic.rt_prices, dates; filtered_kwargs...))
    ErcotMagic.add_datetime!(rt_nodal)
    select!(rt_nodal, Not([:DSTFlag, :DeliveryInterval, :DeliveryDate, :DeliveryHour]))
    # SYSTEM LAMBDA RT 
    filtered_kwargs = filter_valid_kwargs(ErcotMagic.rt_system_lambda, kwargs)
    rt_system_lambda = ErcotMagic.normalize_columnnames!(ErcotMagic.get_data(ErcotMagic.rt_system_lambda, dates; filtered_kwargs...))
    rt_system_lambda.DATETIME = Dates.floor.(DateTime.(rt_system_lambda[:, :SCEDTimestamp]), Dates.Minute)
    select!(rt_system_lambda, Not([:RepeatHourFlag, :SCEDTimestamp]))
    ##### Join on 5 min intervals
    dat = leftjoin(rt_nodal, rt_system_lambda, on = :DATETIME)
    ## rename SettlementPointPrice to RT_SettlementPointPrice
    rename!(dat, :SettlementPointPrice => :RT_SettlementPointPrice)
    rename!(dat, :SystemLambda => :RT_SystemLambda)
    return dat
end

"""
## Get hourly prices data

join_all_prices(fiveminprices, hourlyprices)
"""
function join_all_prices(fiveminprices::DataFrame, hourlyprices::DataFrame; kwargs...)
    agg = get(kwargs, :agg, "5min")
    if agg == "5min"
        # create hourly column for five min prices to join on
        fiveminprices.DATETIME5 = copy(fiveminprices.DATETIME)
        fiveminprices.DATETIME = Dates.floor.(DateTime.(fiveminprices[:, :DATETIME]), Dates.Hour)
        # join on DATETIME
        out = leftjoin(fiveminprices, hourlyprices, on = [:DATETIME, :SettlementPoint])

    elseif agg == "hourly"
        # aggregate fivemin prices to hourly
        fiveminprices = ErcotMagic.find_missing_and_impute(fiveminprices)
        fiveminprices = ErcotMagic.to_hourly(fiveminprices, :DATETIME)
        # join on DATETIME
        out = leftjoin(hourlyprices, fiveminprices, on = :DATETIME)
    else 
        error("agg must be either '5min' or 'hourly'")
    end
    return out 
end