

"""
Get previously posted forecast for a series of dates

Example:Solar Forecast 
get_vintage_forecast(Date(2024, 2, 1), ErcotMagic.solar_system_forecast)

Wind Forecast 
get_vintage_forecast(Date(2024, 2, 1), ErcotMagic.wind_system_forecast)

Load Forecast 
get_vintage_forecast(Date(2024, 2, 1), ErcotMagic.ercot_zone_load_forecast)
"""
function get_vintage_forecast(date::Date, endpoint::ErcotMagic.EndPoint; kwargs...)
    # Latest acceptable forecast is 7am the prior day 
    postedDatetimeTo = string(DateTime(date - Day(1)) + Hour(7))
    # get the data for the date
    dat = ErcotMagic.get_data(endpoint, date; 
                        postedDatetimeTo=postedDatetimeTo, kwargs...)
    ErcotMagic.normalize_columnnames!(dat)
    ErcotMagic.add_datetime!(dat)
    ## If load forecast, Split by Model, filter by forecast, then 
    if endpoint == ErcotMagic.ercot_zone_load_forecast
        # Select SystemTotal for load 
        dat = select(dat, r"DATETIME|Model|SystemTotal|Posted") 
        # Split by Model
        dat = groupby(dat, :Model)
        datout = DataFrame()
        for group in dat
            # Filter by PostedDateTime
            group = ErcotMagic.filter_forecast_by_posted(DataFrame(group))
            # Add Model column
            datout = vcat(datout, group)
        end
        # unstack
        datout = unstack(datout, :DATETIME, :Model, :SystemTotal)
        # Look at all the E* models and take the median load value 
        datout.MedianLoadForecast = [median(x) for x in eachrow(datout[!, r"^E\d+|^A\d+|^M|^X"])]
        return select(datout, [:DATETIME, :MedianLoadForecast])
    else 
        # filter by posted
        datout = ErcotMagic.filter_forecast_by_posted(dat)
        return select(datout, Not([:DSTFlag, :HourEnding, :DeliveryDate]))
    end
end

"""
 generate a series of dates for the Forecast
dates = [Date(2024, 2, 1) + Day(i) for i in 0:3]
sdf = supply_demand_forecast()
"""
function supply_demand_forecast(; kwargs...)
    date = get(kwargs, :date, today() + Day(1))
    solar_gen = get_vintage_forecast(date, ErcotMagic.solar_system_forecast; kwargs...)
    solar_gen = select(solar_gen, r"DATETIME|COPHSLSystemWide")
    # rename COPHSLSystemWide to SolarHSL 
    rename!(solar_gen, :COPHSLSystemWide => :SolarHSLSystemWide)
    wind_gen = get_vintage_forecast(date, ErcotMagic.wind_system_forecast; kwargs...)
    wind_gen = select(wind_gen, r"DATETIME|COPHSL")
    # rename COPHSLSystemWide to WindHSL
    rename!(wind_gen, :COPHSLSystemWide => :WindHSLSystemWide)
    load_forecast = get_vintage_forecast(date, ErcotMagic.ercot_zone_load_forecast; kwargs...)
    # join the dataframes by DATETIME
    dat = leftjoin(solar_gen, wind_gen, on = :DATETIME, makeunique=true)
    dat = leftjoin(dat, load_forecast, on = :DATETIME)
    ## Use SystemWide data to generate total renewables 
    #dat.Renewables = [sum(x) for x in eachrow(dat[!, r"^PVGRPPSystemWide|^WGRPPSystemWide"])]
    dat.Renewables = [sum(x) for x in eachrow(dat[!, r"HSLSystemWide"])]
    ## Use Median Load minus Renewables to get the Supply Demand Balance
    dat.NetLoad = dat.MedianLoadForecast .- dat.Renewables
    return dat
end