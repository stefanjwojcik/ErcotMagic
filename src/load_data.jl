### Load ERCOT Data for Forecasting and Training

## TODO: Deal with load forecasts 

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
outages = get_ercot_data(params, ErcotMagic.ercot_outages)
ErcotMagic.normalize_columnnames!(rt_dat)
rt_dat = ErcotMagic.process_5min_settlements_to_hourly(rt_dat)
"""
function process_5min_settlements_to_hourly(df::DataFrame, ep::String)
    #df[!, :DATETIME] = Dates.DateTime.(df[!, ep.datekey * "Date"]) .+ Hour.(df[!, ep.datekey * "Hour"])
    df.DATETIME = Dates.DateTime.(df.DeliveryDate) .+ Hour.(df.DeliveryHour) 
    df = combine(groupby(df, :DATETIME), val => mean => :RTLMP)
    return df
end

### Get multiple days of Data 

"""
### Get multiple days of Data for any endpoint 
startdate = Date(2024, 2, 1)
enddate = Date(2024, 2, 10)

## Gen Forecast 
startdate = Date(2024, 2, 1)
enddate = Date(2024, 2, 4)
gen = ErcotMagic.batch_retrieve_data(startdate, enddate, "solar_prod_5min")

## Load Forecast
load = ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 4), "ercot_load_forecast")

## Actual Load 
actual_load = ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 4), "ercot_actual_load")

## RT LMP 
rt = ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 4), "rt_prices")
"""
function batch_retrieve_data(startdate::Date, enddate::Date, endpoint::String; kwargs...)
    url = get(kwargs, :url, ErcotMagic.ENDPOINTS[endpoint][2])
    batchsize = get(kwargs, :batchsize, 4)
    additional_params = get(kwargs, :additional_params, Dict())
    ###################################
    alldat = DataFrame[]
    # split by day 
    alldays = [x for x in startdate:Day(batchsize):enddate]
    @showprogress for (i, marketday) in enumerate(alldays)
        fromtime = Date(marketday)
        totime = Date(min(marketday + Day(batchsize-1), enddate))
        # update params for the batch 
        params = ErcotMagic.APIparams(endpoint, fromtime, totime, additional_params=additional_params)
        ## GET THE DATA 
        dat = get_ercot_data(params, url)
        if isempty(dat)
            @warn "No data delivered for $(fromtime) to $(totime)"
            continue
        end
        normalize_columnnames!(dat)
        alldat = push!(alldat, dat)
    end
    out = vcat(alldat...)
    return out
end

"""
### Get forecast data in batches 
"""

"""
## Create prediction frame
"""
function create_prediction_frame(prediction_date::Date; kwargs...)
    start_date = Date(2024, 2, 1)
    end_date = Date(2024, 2, 4)
    # Get the data for the prediction date
    # additional params for loads - need posted datetime 
    addparams = Dict("postedDatetimeFrom" => "$(start_date)T00:00:00Z", 
                     "postedDatetimeTo" => "$(end_date)T23:59:59Z")
    load_forecast = ErcotMagic.batch_retrieve_data(start_date, end_date, url=ErcotMagic.ercot_load_forecast)
    solargen_forecast = ErcotMagic.batch_retrieve_data(start_date, end_date, url=ErcotMagic.solar_system_forecast)
    windgen_forecast = ErcotMagic.batch_retrieve_data(start_date, end_date, url=ErcotMagic.wind_system_forecast)
    
    # Net Load = Load - Solar - Wind
    load_forecast.netload = load_forecast.LoadMW .- solargen_forecast.MW .- windgen_forecast.MW
    
    
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

