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
normalize_columnnames!(rt_dat)
rt_dat = process_5min_settlements_to_hourly(rt_dat)
"""
function process_5min_settlements_to_hourly(df::DataFrame, val=:SettlementPointPrice)
    df.DATETIME = Dates.DateTime.(df.DeliveryDate) .+ Hour.(df.DeliveryHour) 
    df = combine(groupby(df, :DATETIME), val => mean => :RTLMP)
    return df
end

### Get multiple days of Data 

"""
### Get multiple days of Real-Time data 
using ErcotMagic, DataFrames, Dates
startdate = Date(2022, 2, 1)
enddate = Date(2024, 2, 1)
ex = ErcotMagic.realtime_lmp_long(startdate, enddate)
"""
function realtime_lmp_long(startdate::Date, enddate::Date; settlementPoint="HB_NORTH", hourly_avg=true, batchsize=45)
    settlementPoint = 
    alldat = DataFrame[]
    # split by day 
    alldays = [x for x in startdate:Day(batchsize):enddate]
    for marketday in alldays 
        fromtime = DateTime(marketday)
        totime = DateTime(min(marketday + Day(batchsize-1), enddate))
        params = Dict("deliveryDateFrom" => string(fromtime), 
                "deliveryDateTo" => string(totime),
                "settlementPoint" => settlementPoint, 
                "size" => "1000000")
        rt_dat = get_ercot_data(params, ErcotMagic.rt_prices)
        normalize_columnnames!(rt_dat)
        if hourly_avg
            rt_dat = process_5min_settlements_to_hourly(rt_dat)
        end
        alldat = push!(alldat, rt_dat)
    end
    out = vcat(alldat...)
    return out
end

"""
### Get multiple days of Day-Ahead data
startdate = Date(2024, 2, 1)
enddate = Date(2024, 2, 10)
ex = dayahead_lmp_long(Date(2024, 2, 1), Date(2024, 2, 4))
"""
function dayahead_lmp_long(startdate::Date, enddate::Date, settlementPoint="HB_NORTH")
    alldat = DataFrame[]
    # split by day 
    alldays = [x for x in startdate:Day(1):enddate]
    for marketday in alldays 
        fromtime = string(marketday)
        totime = string(marketday + Day(1))
        params = Dict(
                "deliveryDateFrom" => fromtime, 
                "deliveryDateTo" => totime,
                "settlementPoint" => settlementPoint, 
                "size" => "1000000")
        da_dat = get_ercot_data(params, ErcotMagic.da_prices)
        alldat = push!(alldat, da_dat)
    end
    out = vcat(alldat...)
    return out
end


"""
## Load and gen take similar params 
"""
function load_gen_forecast_long(startdate::Date, enddate::Date, url)
    alldat = DataFrame[]
    # split by day 
    alldays = [x for x in startdate:Day(1):enddate]
    for marketday in alldays 
        fromtime = string(marketday)
        params = Dict("deliveryDateFrom" => fromtime, 
                "deliveryDateTo" => fromtime)
        lf_dat = get_ercot_data(params, url)
        alldat = push!(alldat, lf_dat)
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