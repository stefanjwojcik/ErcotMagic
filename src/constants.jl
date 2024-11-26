## CONSTANTS and Configs for calling ERCOT API

"""
## ERCOT API Configurations
# five min vs hourly 
# posted vs non-posted 
# unstacked vs stacked 
# datekey + hourkey 
"""
mutable struct ErcotAPIConfig
    datekey::String
    hourkey::String
    intervalkey::String
    endpoint::String
    url::String
    posted::Bool
    stacked::Bool
end

## Moving to a single constants dictionary 
const ENDPOINTS = Dict(
    "da_prices" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-190-cd/dam_stlmnt_pnt_prices?"),
    "rt_prices" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np6-905-cd/spp_node_zone_hub?"),
    "ercot_load_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-566-cd/lf_by_model_study_area?"),
    "ercot_zone_load_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-565-cd/lf_by_model_weather_zone?"),
    "ercot_actual_load" => ("operatingDay", "https://api.ercot.com/api/public-reports/np6-345-cd/act_sys_load_by_wzn?"),
    "ercot_outages" => ("operatingDate", "https://api.ercot.com/api/public-reports/np3-233-cd/hourly_res_outage_cap?"),
    "solar_system_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-737-cd/spp_hrly_avrg_actl_fcast?"),
    "wind_system_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-732-cd/wpp_hrly_avrg_actl_fcast?"),
    "sixty_dam_energy_only_offers" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offers?"),
    "sixty_dam_awards" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offer_awards?"),
    "energybids" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_bids?"),
    "gen_data" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_gen_res_data?"),
    "twodayAS" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-911-er/2d_agg_as_offers_ecrsm?"),
    "sced_data" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-965-er/60_sced_gen_res_data?"),
    "wind_prod_5min" => ("intervalEnding", "https://api.ercot.com/api/public-reports/np4-733-cd/wpp_actual_5min_avg_values?"),
    "solar_prod_5min" => ("intervalEnding", "https://api.ercot.com/api/public-reports/np4-738-cd/spp_actual_5min_avg_values?"),
    "binding_constraints" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np6-86-cd/shdw_prices_bnd_trns_const?")
)


"""
## Function to convert the payload to parameters for the API call 
ep = "da_prices"
startdate = Date(2024, 2, 1)
enddate = Date(2024, 2, 10)
params = ErcotMagic.APIparams(ep, startdate, enddate)
"""
function APIparams(endpointname::String, startdate::Date, enddate::Date; settlement_point::String="HB_NORTH", additional_params=Dict())
    datekey, url = ENDPOINTS[endpointname]
    params = Dict(datekey * "From" => string(startdate), 
                 datekey * "To" => string(enddate))
    # IF endpoint contains "forecast", then add "postedDatetimeFrom" and "postedDatetimeTo"
    # 24 hours before the startdate  
    if occursin("prices", endpointname)
        params["settlementPoint"] = settlement_point
    end
    params["size"] = "1000000"
    merge!(params, additional_params)
    return params
end


### Prices URLS
"""
Day Ahead Prices
"""
const da_prices = "https://api.ercot.com/api/public-reports/np4-190-cd/dam_stlmnt_pnt_prices?"

"""
Real Time Prices
"""
const rt_prices = "https://api.ercot.com/api/public-reports/np6-905-cd/spp_node_zone_hub?"

### Load and Load Forecasts URLs
# Hourly system-wide Mid-Term Load Forecasts (MTLFs) for all forecast models with an indicator for which forecast was in use by ERCOT at the time of publication for current day plus the next 7.
"""
Ercot Load Forecast Endpoint
"""
const ercot_load_forecast = "https://api.ercot.com/api/public-reports/np3-566-cd/lf_by_model_study_area?"

"""
Ercot Zone Load Forecast Endpoint
"""
const ercot_zone_load_forecast = "https://api.ercot.com/api/public-reports/np3-565-cd/lf_by_model_weather_zone?"

"""
Ercot Actual System Load 
"""
const ercot_actual_load = "https://api.ercot.com/api/public-reports/np6-345-cd/act_sys_load_by_wzn?"

"""
Ercot Outages
"""
const ercot_outages = "https://api.ercot.com/api/public-reports/np3-233-cd/hourly_res_outage_cap?"

### Gen Forecasts URLS
"""
Solar System Forecast and Production
"""
const solar_system_forecast = "https://api.ercot.com/api/public-reports/np4-737-cd/spp_hrly_avrg_actl_fcast?"

const solar_prod_5min = "https://api.ercot.com/api/public-reports/np4-738-cd/spp_actual_5min_avg_values?"

"""
Wind System Forecast
"""
const wind_system_forecast = "https://api.ercot.com/api/public-reports/np4-732-cd/wpp_hrly_avrg_actl_fcast?"

const wind_prod_5min = "https://api.ercot.com/api/public-reports/np4-733-cd/wpp_actual_5min_avg_values?"

### Energy Only Offers URLS - API hasn't added these data as of 2024-03-25
const sixty_dam_energy_only_offers = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offers?"
const sixty_dam_awards = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offer_awards?"
const energybids = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_bids?"

## Generator data 
const gen_data = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_gen_res_data?"

### Ancillary Services
const twodayAS = "https://api.ercot.com/api/public-reports/np3-911-er/2d_agg_as_offers_ecrsm?"

const sced_data = "https://api.ercot.com/api/public-reports/np3-965-er/60_sced_gen_res_data?"


"""
### Binding Constraints and Shadow PRices 
filters: 
- fromStation, toStation 
- SCEDTimestampFrom, SCEDTimestampTo
"""
const binding_constraints = "https://api.ercot.com/api/public-reports/np6-86-cd/shdw_prices_bnd_trns_const?"