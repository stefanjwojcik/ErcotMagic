

"""
Get previously posted forecast for a series of dates

Example:
ErcotMagic.get_vintage_forecast(Date(2024, 2, 1), ErcotMagic.solar_system_forecast)
"""
function get_vintage_forecast(date::Date, endpoint::ErcotMagic.EndPoint; kwargs...)
    # Latest acceptable forecast is 7am the prior day 
    postedDatetimeTo = string(DateTime(date - Day(1)) + Hour(7))
    # get the data for the date
    dat = ErcotMagic.get_data(endpoint, date; 
                        postedDatetimeTo=postedDatetimeTo, kwargs...)
    ErcotMagic.normalize_columnnames!(dat)
    ErcotMagic.add_datetime!(dat)
    # filter by posted
    dat = ErcotMagic.filter_forecast_by_posted(dat)
    return select(dat, Not([:DSTFlag, :HourEnding, :DeliveryDate]))
end

"""
 generate a series of dates for the Forecast
dates = [Date(2024, 2, 1) + Day(i) for i in 0:3]
"""
function supply_demand_forecast(;kwargs...)
    startdate = get(kwargs, :startdate, today() - Day(7))
    enddate = get(kwargs, :enddate, today() - Day(1))
    addparams = Dict("size" => "1000000")
    # Solar and Wind generation
    for date in startdate:enddate
        solar_gen = ErcotMagic.get_vintage_forecast(date, ErcotMagic.solar_system_forecast, kwargs...)
        solar_gen = select(solar_gen, [:DATETIME, :PVGRPPSystemWide])
        wind_gen = ErcotMagic.get_vintage_forecast(date, ErcotMagic.wind_system_forecast, kwargs...)
        wind_gen = select(wind_gen, r"DATETIME|^WGRPP")
        load_forecast = ErcotMagic.get_vintage_forecast(date, ErcotMagic.ercot_load_forecast, kwargs...)
        # join the dataframes by DATETIME
        dat = leftjoin(solar_gen, wind_gen, on = :DATETIME)
        # add to the list of dataframes
        push!(dat_list, dat)
    end

    filtered_kwargs = filter_valid_kwargs(ErcotMagic.solar_system_forecast, kwargs)
    dat = ErcotMagic.normalize_columnnames!(ErcotMagic.get_data(ErcotMagic.solar_system_forecast, dates))
    dat = filter_forecast_by_posted(dat)
    solar_gen = ErcotMagic.batch_retrieve_data(startdate, enddate, "solar_system_forecast", additional_params=addparams)
    solar_actuals = ErcotMagic.filter_actuals_by_posted(solar_gen)
    select!(solar_actuals, [:DATETIME, :GenerationSystemWide])
    rename!(solar_actuals, :GenerationSystemWide => :SOLAR)
    wind_gen = ErcotMagic.batch_retrieve_data(startdate, enddate, "wind_system_forecast", additional_params=addparams)
    wind_actuals = ErcotMagic.filter_actuals_by_posted(wind_gen)
    select!(wind_actuals, [:DATETIME, :GenerationSystemWide])
    rename!(wind_actuals, :GenerationSystemWide => :WIND)
    ## Net Load = Load - Solar - Wind
    dat = innerjoin(actual_load, solar_actuals, on=:DATETIME)
    dat = innerjoin(dat, wind_actuals, on=:DATETIME)
    dat[!, :NETLOAD] = dat[!, :Total] .- dat[!, :SOLAR] .- dat[!, :WIND] 
