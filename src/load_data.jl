### Load ERCOT Data for Forecasting and Training

### Prices URLS
"""
Day Ahead Prices
"""
const da_prices = "https://api.ercot.com/api/public-reports/np4-190-cd/dam_stlmnt_pnt_prices?"

"""
Real Time Prices
"""
const rt_prices = "https://api.ercot.com/api/public-reports/np6-970-cd/rtd_lmp_node_zone_hub?"

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

### Get multiple days of Data 

"""
### Get multiple days of Real-Time data 
startdate = Date(2024, 2, 1)
enddate = Date(2024, 2, 10)
ex = realtime_lmp_long(Date(2024, 2, 1), Date(2024, 2, 4))
"""
function realtime_lmp_long(startdate::Date, enddate::Date, settlementPoint="HB_NORTH")
    alldat = DataFrame[]
    # split by day 
    alldays = [x for x in startdate:Day(1):enddate]
    for marketday in alldays 
        fromtime = DateTime(marketday)
        totime = DateTime(marketday + Day(1))
        params = Dict("RTDTimestampFrom" => string(fromtime), 
                "RTDTimestampTo" => string(totime),
                "settlementPoint" => settlementPoint, 
                "size" => "1000000")
        rt_dat = get_ercot_data(params, ErcotMagic.rt_prices)
        alldat = push!(alldat, rt_dat)
    end
    out = vcat.(alldat)
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

