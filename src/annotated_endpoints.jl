"""
## ANNOTATED ENDPOINTS: 
- contains the endpoint name, the date key, and the URL for the API call 
"""
Annotated_Endpoints = Dict(
    ## PRICES 
    "da_prices" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-190-cd/dam_stlmnt_pnt_prices?"),
    "rt_prices" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np6-905-cd/spp_node_zone_hub?"),
    "ancillary_prices" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-188-cd/dam_clear_price_for_cap?"),
    "da_system_lambda" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-523-cd/dam_system_lambda?"),
    "rt_system_lambda" => ("SCEDTimestamp", "https://api.ercot.com/api/public-reports/np6-322-cd/sced_system_lambda?"),
    ## Forecasts 
    "ercot_load_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-566-cd/lf_by_model_study_area?"),
    "ercot_zone_load_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-565-cd/lf_by_model_weather_zone?"),
    "solar_system_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-737-cd/spp_hrly_avrg_actl_fcast?"),
    "wind_system_forecast" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np4-732-cd/wpp_hrly_avrg_actl_fcast?"),
    "ercot_outages" => ("operatingDate", "https://api.ercot.com/api/public-reports/np3-233-cd/hourly_res_outage_cap?"),
    "binding_constraints" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np6-86-cd/shdw_prices_bnd_trns_const?"),
    ## Actuals
    "ercot_actual_load" => ("operatingDay", "https://api.ercot.com/api/public-reports/np6-345-cd/act_sys_load_by_wzn?"),
    "wind_prod_5min" => ("intervalEnding", "https://api.ercot.com/api/public-reports/np4-733-cd/wpp_actual_5min_avg_values?"),
    "solar_prod_5min" => ("intervalEnding", "https://api.ercot.com/api/public-reports/np4-738-cd/spp_actual_5min_avg_values?"),
    ## 60 day offers 
    "sixty_dam_energy_only_offers" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offers?"),
    "sixty_dam_awards" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offer_awards?"),
    "energybids" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_bids?"),
    ## This gives the amount of virtuals awarded by resource and settlement point
    "gen_data" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_gen_res_data?"),
    "twodayAS" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-911-er/2d_agg_as_offers_ecrsm?"),
    "sced_gen_data" => ("SCEDTimestamp", "https://api.ercot.com/api/public-reports/np3-965-er/60_sced_gen_res_data?"),
    "sced_energy_only_offers" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offers?"),
    "sced_gen_as_data" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_gen_res_as_offers?"), 
    "sced_load_data" => ("deliveryDate", "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_load_res_data?")
)
