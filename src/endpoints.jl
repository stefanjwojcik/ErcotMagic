## CONSTANTS and Configs for calling ERCOT API

## Moving to a single constants dictionary 
const ENDPOINTS = Dict(
    "da_prices" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-190-cd/dam_stlmnt_pnt_prices?"),
    "rt_prices" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np6-905-cd/spp_node_zone_hub?"),
    "ancillary_prices" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-188-cd/dam_clear_price_for_cap?"),
    "da_system_lambda" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-523-cd/dam_system_lambda?"),
    "rt_system_lambda" => ("SCEDTimestamp", "https://api.ercot.com/api/public-reports/np6-322-cd/sced_system_lambda?"),
    "ercot_load_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-566-cd/lf_by_model_study_area?"),
    "ercot_zone_load_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-565-cd/lf_by_model_weather_zone?"),
    "ercot_actual_load" => ("operatingDay", "https://api.ercot.com/api/public-reports/np6-345-cd/act_sys_load_by_wzn?"),
    "ercot_outages" => ("operatingDate", "https://api.ercot.com/api/public-reports/np3-233-cd/hourly_res_outage_cap?"),
    "solar_system_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-737-cd/spp_hrly_avrg_actl_fcast?"),
    "wind_system_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-732-cd/wpp_hrly_avrg_actl_fcast?"),
    "wind_prod_5min" => ("intervalEnding", "https://api.ercot.com/api/public-reports/np4-733-cd/wpp_actual_5min_avg_values?"),
    "solar_prod_5min" => ("intervalEnding", "https://api.ercot.com/api/public-reports/np4-738-cd/spp_actual_5min_avg_values?"),
    "binding_constraints" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np6-86-cd/shdw_prices_bnd_trns_const?"),
    "sixty_dam_energy_only_offers" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offers?"),
    "sixty_dam_awards" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offer_awards?"),
    "energybids" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_bids?"),
    ## This gives the amount of virtuals awarded 
    "gen_data" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_gen_res_data?"),
    "twodayAS" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-911-er/2d_agg_as_offers_ecrsm?"),
    "sced_gen_data" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-965-er/60_sced_gen_res_data?"),
    "sced_energy_only_offers" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offers?"),
    "sced_gen_as_data" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_gen_res_as_offers?"), 
    "sced_load_data" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_load_res_data?")
)

function get_non_sced_endpoints()
    return  ["da_prices", 
    "rt_prices", 
    "ercot_load_forecast", 
    "ercot_zone_load_forecast", 
    "ercot_actual_load", 
    "ercot_outages", 
    "solar_system_forecast",
    "wind_system_forecast",
    "system_lambda", 
    "binding_constraints"]
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
const ancillary_prices = "https://api.ercot.com/api/public-reports/np4-188-cd/dam_clear_price_for_cap?"

const twodayECRSclears = "https://api.ercot.com/api/public-reports/np3-911-er/2d_cleared_dam_as_ecrsm?"

const sced_gen_data = "https://api.ercot.com/api/public-reports/np3-965-er/60_sced_gen_res_data?"

const sced_load_as = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_load_res_as_offers?"

const sced_gen_as = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_gen_res_as_offers?"

"""
### Binding Constraints and Shadow PRices 
filters: 
- fromStation, toStation 
- SCEDTimestampFrom, SCEDTimestampTo
"""
const binding_constraints = "https://api.ercot.com/api/public-reports/np6-86-cd/shdw_prices_bnd_trns_const?"