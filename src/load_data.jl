### Load ERCOT Data for Forecasting and Training


###################

function normalize_columnnames!(df::DataFrame)
    #rename 
    rename!(df, replace.(names(df), " " => ""))
    return df
end

function add_fiveminute_intervals!(df::DataFrame)
    df.DATETIME = Dates.DateTime.(df.DeliveryDate) .+ Hour.(df.DeliveryHour) .+ Minute.(df.DeliveryInterval .* 5)    
    return df
end

"""
### Process 5 min RT LMP- see RTD indicative LMPs here: https://www.ercot.com/content/cdr/html/rtd_ind_lmp_lz_hb_HB_NORTH.html
params = Dict("deliveryDateFrom" => "2024-02-01", 
                "deliveryDateTo" => "2024-02-02", 
                "settlementPoint" => "HB_NORTH",
                "size" => "1000000")
rt_dat = get_ercot_data(params, ErcotMagic.rt_prices)
ErcotMagic.normalize_columnnames!(rt_dat)
rt_dat = ErcotMagic.process_5min_settlements_to_hourly(rt_dat)
"""
function process_5min_settlements_to_hourly(df::DataFrame, val=:SettlementPointPrice)
    df.DATETIME = Dates.DateTime.(df.DeliveryDate) .+ Hour.(df.DeliveryHour) 
    df = combine(groupby(df, :DATETIME), val => mean => :RTLMP)
    return df
end

### Get multiple days of Data 

"""
### Get multiple days of Data for any endpoint 
startdate = Date(2024, 2, 1)
enddate = Date(2024, 2, 10)

## DA LMP
ex = dayahead_lmp_long(Date(2024, 2, 1), Date(2024, 2, 4))

## Gen Forecast 
gen = ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 4), url=ErcotMagic.solar_system_forecast)

## Load Forecast
load = ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 4), url=ErcotMagic.ercot_load_forecast)

## RT LMP 
addparams = Dict("settlementPoint" => "HB_NORTH")
rt = ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 4), url=ErcotMagic.rt_prices, hourly_avg=true, additional_params=addparams)
"""
function batch_retrieve_data(startdate::Date, enddate::Date; kwargs...)
    url = get(kwargs, :url, ErcotMagic.da_prices)
    additional_params = get(kwargs, :additional_params, Dict())
    hourly_avg = get(kwargs, :hourly_avg, false)
    batchsize = get(kwargs, :batchsize, 45)
    ###################################
    alldat = DataFrame[]
    # split by day 
    alldays = [x for x in startdate:Day(batchsize):enddate]
    @showprogress for (i, marketday) in enumerate(alldays)
        fromtime = Date(marketday)
        totime = Date(min(marketday + Day(batchsize-1), enddate))
        params = Dict("deliveryDateFrom" => string(fromtime), 
                      "deliveryDateTo" => string(totime))
        merge!(params, additional_params)
        ## GET THE DATA 
        dat = get_ercot_data(params, url)
        if isempty(dat)
            @warn "No data delivered for $(fromtime) to $(totime)"
            continue
        end
        normalize_columnnames!(dat)
        if hourly_avg
            rt_dat = process_5min_settlements_to_hourly(dat)
        end
        alldat = push!(alldat, dat)
    end
    out = vcat(alldat...)
    return out
end


"""
## Create prediction frame
"""
function create_prediction_frame(prediction_date::Date)
    # Get the data for the prediction date
    load_forecast = load_gen_forecast_long(prediction_date, prediction_date, ercot_load_forecast)
    gen_forecast = load_gen_forecast_long(prediction_date, prediction_date, solar_system_forecast)
    wind_forecast = load_gen_forecast_long(prediction_date, prediction_date, wind_system_forecast)
    
    # Assume weather data is available in a local CSV file
    weather_data = CSV.read("weather_data.csv", DataFrame)
    weather_data = filter(row -> row.date == prediction_date, weather_data)
    
    # Get lagged outcomes data
    startdate = prediction_date - Day(7)
    enddate = prediction_date - Day(1)
    outcomes_data = create_outcomes_df(startdate, enddate)
    
    # Merge the data
    prediction_frame = innerjoin(load_forecast, gen_forecast, on = [:timestamp], makeunique=true)
    prediction_frame = innerjoin(prediction_frame, wind_forecast, on = [:timestamp], makeunique=true)
    prediction_frame = innerjoin(prediction_frame, weather_data, on = [:timestamp], makeunique=true)
    prediction_frame = innerjoin(prediction_frame, outcomes_data, on = [:timestamp], makeunique=true)
    
    return prediction_frame
end

################################
function fetch_ercot_data(startdate::Date, enddate::Date; 
    endpoint::Symbol, 
    settlementPoint::String="HB_NORTH", 
    hourly_avg::Bool=true, 
    batchsize::Int=45, 
    extra_params::Dict=Dict(), 
    process_func::Function=identity)
    alldat = DataFrame[]
    alldays = [x for x in startdate:Day(batchsize):enddate]
    @showprogress for (i, marketday) in enumerate(alldays)
    fromtime = Date(marketday)
    totime = Date(min(marketday + Day(batchsize-1), enddate))
    params = Dict("deliveryDateFrom" => string(fromtime), 
        "deliveryDateTo" => string(totime),
        "settlementPoint" => settlementPoint, 
        "size" => "1000000")
    merge!(params, extra_params)
    data = get_ercot_data(params, endpoint)
    if isempty(data)
    @warn "No data delivered for $(fromtime) to $(totime)"
    continue
    end
    normalize_columnnames!(data)
    data = process_func(data)
    alldat = push!(alldat, data)
    end
    out = vcat(alldat...)
    return out
end

# Example usage for real-time LMP
function realtime_lmp_long(startdate::Date, enddate::Date; kwargs...)
process_func = kwargs[:hourly_avg] ? process_5min_settlements_to_hourly : identity
return fetch_ercot_data(startdate, enddate; 
      endpoint=ErcotMagic.rt_prices, 
      settlementPoint=kwargs[:settlementPoint], 
      hourly_avg=kwargs[:hourly_avg], 
      batchsize=kwargs[:batchsize], 
      process_func=process_func)
end

# Example usage for day-ahead prices
function day_ahead_prices(startdate::Date, enddate::Date; kwargs...)
return fetch_ercot_data(startdate, enddate; 
      endpoint=ErcotMagic.da_prices, 
      settlementPoint=kwargs[:settlementPoint], 
      batchsize=kwargs[:batchsize])
end