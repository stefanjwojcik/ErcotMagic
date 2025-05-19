

"""
 generate a series of dates for the Forecast
dates = [Date(2024, 2, 1) + Day(i) for i in 0:14]
"""
function supply_demand_forecast(;kwargs...)
    startdate = get(kwargs, :startdate, today() - Day(7))
    enddate = get(kwargs, :enddate, today() - Day(1))
    addparams = Dict("size" => "1000000")
    # SOlar and Wind generation
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
