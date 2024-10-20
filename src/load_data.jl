### Load ERCOT Data for Forecasting and Training

### Prices URLS
"""
Day Ahead Prices
"""
const da_prices = "https://api.ercot.com/api/public-reports/np4-190-cd/dam_stlmnt_pnt_prices?"

"""
Real Time Prices
"""
const rt_prices = "https://api.ercot.com/api/public-reports/np6-905-cd/spp_node_zone_hub?"

### Load Forecasts URLs
# Hourly system-wide Mid-Term Load Forecasts (MTLFs) for all forecast models with an indicator for which forecast was in use by ERCOT at the time of publication for current day plus the next 7.
"""
Ercot Load Forecast Endpoint
"""
const ercot_load_forecast = "https://api.ercot.com/api/public-reports/np3-566-cd/lf_by_model_study_area?"

"""
Ercot Actual System Load 
"""
const ercot_actual_load = "https://api.ercot.com/api/public-reports/np6-345-cd/act_sys_load_by_wzn?"

"""
Ercot Outages
"""
const ercot_outages = "https://api.ercot.com/api/public-reports/np3-233-cd/hourly_res_outage_cap?"

"""
Ercot Zone Load Forecast Endpoint
"""
const ercot_zone_load_forecast = "https://api.ercot.com/api/public-reports/np3-565-cd/lf_by_model_weather_zone?"

### Gen Forecasts URLS
"""
Solar System Forecast
"""
const solar_system_forecast = "https://api.ercot.com/api/public-reports/np4-737-cd/spp_hrly_avrg_actl_fcast?"

"""
Wind System Forecast
"""
const wind_system_forecast = "https://api.ercot.com/api/public-reports/np4-732-cd/wpp_hrly_avrg_actl_fcast?"

### Energy Only Offers URLS - API hasn't added these data as of 2024-03-25
const sixty_dam_energy_only_offers = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offers?"
const sixty_dam_awards = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offer_awards?"
const energybids = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_bids?"

## Generator data 
const gen_data = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_gen_res_data?"

### Ancillary Services
const twodayAS = "https://api.ercot.com/api/public-reports/np3-911-er/2d_agg_as_offers_ecrsm?"

const sced_data = "https://api.ercot.com/api/public-reports/np3-965-er/60_sced_gen_res_data?"

###################

function normalize_columnnames!(df::DataFrame)
    #rename 
    rename!(df, replace.(names(df), " " => ""))
    return df
end

function add_fifteenmin_intervals!(df::DataFrame)
    df.DATETIME = Dates.DateTime.(df.DeliveryDate) .+ Hour.(df.DeliveryHour) .+ Minute.(df.DeliveryInterval .* 15)    
end

"""
### Process 15 min RT LMP- see RTD indicative LMPs here: https://www.ercot.com/content/cdr/html/rtd_ind_lmp_lz_hb_HB_NORTH.html
params = Dict("deliveryDateFrom" => "2024-02-01", 
                "deliveryDateTo" => "2024-02-02", 
                "settlementPoint" => "HB_NORTH",
                "size" => "1000000")
rt_dat = get_ercot_data(params, ErcotMagic.rt_prices)
normalize_columnnames!(rt_dat)
rt_dat = process_5min_settlements_to_hourly(rt_dat)
"""
function process_15min_settlements_to_hourly(df::DataFrame, val=:SettlementPointPrice)
    df.DATETIME = Dates.DateTime.(df.DeliveryDate) .+ Hour.(df.DeliveryHour) 
    df = combine(groupby(df, :DATETIME), val => mean => val)
    return df
end

### Get multiple days of Data 

"""
### Get multiple days of Real-Time data 
using ErcotMagic, DataFrames, Dates
startdate = Date(2023, 12, 11)
enddate = Date(2023, 12, 12)

## GET RT LMP for HB_NORTH
rt_dat = ErcotMagic.series_long(startdate, enddate, series=ErcotMagic.rt_prices, hourly_avg=true)
rename!(rt_dat, Dict(:SettlementPointPrice => :RTLMP))

## GET DA LMP for HB_NORTH
da_dat = ErcotMagic.series_long(startdate, enddate, series=ErcotMagic.da_prices, hourly_avg=true)

## GET SYSTEM LOAD 
load_dat = ErcotMagic.series_long(startdate, enddate, series=ErcotMagic.ercot_zone_load_forecast, hourly_avg=false)
"""
function series_long(startdate::Date, enddate::Date; kwargs...)
    settlementPoint = get(kwargs, :settlementPoint, nothing)
    hourly_avg = get(kwargs, :hourly_avg, false)
    series = get(kwargs, :series, ErcotMagic.rt_prices)
    # split by day
    params = Dict("size" => "1000000")
    # if series is ercot_actual_load, then operatingDayFrom and operatingDayTo are used
    if series == ercot_actual_load
        params["operatingDayFrom"] = string(startdate)
        params["operatingDayTo"] = string(enddate)
    else 
        params["deliveryDateFrom"] = string(startdate)
        params["deliveryDateTo"] = string(enddate)
    end
    if settlementPoint !== nothing
        params["settlementPoint"] = settlementPoint
    end
    dat = get_ercot_data(params, series)
    if nrow(dat) == 0
        @warn "No data found for $series"
        return DataFrame()
    end
    normalize_columnnames!(dat)
    if hourly_avg
        dat = process_15min_settlements_to_hourly(dat)
    end
    return dat
end

function parse_hour_ending_string(x::String)
    try 
        x_s = split(x, ":")
        parse(Int, x_s[1])
    catch e
        println("Error parsing: ", x)
        return 0
    end
end

## Function in process -- get and process all relevant data 
function ercot_data(;kwargs...)
    redownload = get(kwargs, :redownload, false)
    startdate = prediction_date - Day(365)
    enddate = prediction_date - Day(1)
    # Check for existing data in AWS 
    predframe = download_csv_from_s3("ercotmagic", "prediction_frame.csv", "prediction_frame.csv")
    predframe_exists = nrow(predframe) > 0
    if predframe_exists
        # Check the latest date in the prediction frame
        latest_date = maximum(predframe.DATETIME)
        # 
        if latest_date <= latest_date
            startdate = startdate
        else
            # Set the start date to the day after the latest date in the prediction frame
            startdate = latest_date + Day(1)
        end
    end

        ## Pricing Data 
    ## GET RT LMP for HB_NORTH
    rt_dat = ErcotMagic.series_long(startdate, enddate, series=ErcotMagic.rt_prices, hourly_avg=true)
    rename!(rt_dat, Dict(:SettlementPointPrice => :RTLMP))

    ## GET DA LMP for HB_NORTH
    da_dat = ErcotMagic.series_long(startdate, enddate, series=ErcotMagic.da_prices, hourly_avg=true)
    rename!(da_dat, Dict(:SettlementPointPrice => :DALMP))

    ## GET SYSTEM LOAD Forecast 
    load_for_dat = ErcotMagic.series_long(startdate, enddate, series=ErcotMagic.ercot_zone_load_forecast, hourly_avg=false)
    ## select SystemTotal, Model, InUseFlag, DeliveryDate, HourEnding 
    load_for_dat = select(load_dat, [:SystemTotal, :Model, :InUseFlag, :DeliveryDate, :HourEnding])
    # Identify the official system forecast 
    model_in_use = load_for_dat[load_for_dat.InUseFlag .== true, [:SystemTotal, :DATETIME]]
    # Sum model_in_use by DATETIME
    model_in_use = combine(groupby(model_in_use, :DATETIME), :SystemTotal => mean => :TotalLoadOfficial)
    load_for_dat.DATETIME = Dates.DateTime.(load_for_dat.DeliveryDate) .+ Hour.(parse_hour_ending_string.(load_for_dat.HourEnding))
    # unstack Model so that we have a column for each model
    load_for_dat = unstack(load_for_dat, :DATETIME, :Model, :SystemTotal, combine=mean)
    # Actual loads 
    load_act_dat = ErcotMagic.series_long(startdate, enddate, series=ErcotMagic.ercot_actual_load, hourly_avg=false)

    # Get the data for the prediction date
    solar_forecast = ErcotMagic.series_long(startdate, enddate, series=ErcotMagic.solar_system_forecast, hourly_avg=false)
    wind_forecast = ErcotMagic.series_long(startdate, enddate, series=ErcotMagic.wind_system_forecast, hourly_avg=false)
end 


"""
## Create prediction frame

"""
function create_prediction_frame(prediction_date::Date; kwargs...)
    rt_dat = ErcotMagic.series_long(startdate, enddate, series=ErcotMagic.rt_prices, hourly_avg=true)
    rename!(rt_dat, Dict(:SettlementPointPrice => :RTLMP))
    return rt_dat
end