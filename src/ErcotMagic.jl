module ErcotMagic

# Core API page: https://apiexplorer.ercot.com/

using HTTP
using JSON
using DotEnv, DataFrames, JLD
using Pkg.Artifacts

export get_auth_token, 
        ercot_api_call, 
        ercot_api_url, 
        parse_ercot_response, 
        get_ercot_data, 
        trainingdata

DotEnv.config()

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


"""

# A function to retreive the auth token 
```julia-repl
token = get_auth_token()
```

"""
function get_auth_token()
    API_URL = "https://ercotb2c.b2clogin.com/ercotb2c.onmicrosoft.com/B2C_1_PUBAPI-ROPC-FLOW/oauth2/v2.0/token?"
    GRANT_TYPE ="password"
    username=ENV["ERCOTUSER"]
    password=ENV["ERCOTPASS"]
    response_type="id_token"
    scope="openid+fec253ea-0d06-4272-a5e6-b478baeecd70+offline_access"
    client_id="fec253ea-0d06-4272-a5e6-b478baeecd70"

    apicall = API_URL * "grant_type=" * GRANT_TYPE * "&username=" * username * "&password=" * password * "&response_type=" * response_type * "&scope=" * scope * "&client_id=" * client_id
    response = HTTP.post(apicall, 
        headers = ["Content-Type" => "application/x-www-form-urlencoded"]
    )
    return JSON.parse(String(response.body))
end

"""
# Base call to ERCOT API 
- authorization => token_bearer
- headers => Ocp-Apim-Subscription-Key => ENV["ERCOTKEY"]
- url => https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offers
sixty_dam_energy_only_offers = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offers"
response = ercot_api_call(token["id_token"], sixty_dam_energy_only_offers)
"""
function ercot_api_call(token_id, url)
    response = HTTP.get(url, 
        headers = ["Authorization" => "Bearer " * token_id
            "Ocp-Apim-Subscription-Key" => ENV["ERCOTKEY"]
            "Content-Type" => "application/json"
        ]
    )
    return JSON.parse(String(response.body))
end

"""
# Function to formulate a url for ERCOT API based on params in kwargs
params = Dict("deliveryDateFrom" => "2021-08-01", "deliveryDateTo" => "2024-02-25")
params2 = Dict("settlementPointName" => "HB_NORTH")
url = ercot_api_url(params)
# try to cal 
response = ercot_api_call(token["id_token"], url)

## DAM prices
dampricesurl = ercot_api_url(params, da_prices)
response = ercot_api_call(token["id_token"], dampricesurl)

## RT prices
rtpricesurl = ercot_api_url(params, rt_prices)
response = ercot_api_call(token["id_token"], rtpricesurl)

## Two day AS
twodayasurl = ercot_api_url(params, twodayAS)
response = ercot_api_call(token["id_token"], twodayasurl)

## Sixty DAM awards
params = Dict("deliveryDateFrom" => "2021-08-01", "deliveryDateTo" => "2024-02-25")
sixty_dam_awards_url = ercot_api_url(params, sixty_dam_awards)
response = ercot_api_call(token["id_token"], sixty_dam_awards_url)

"""
function ercot_api_url(params, url)
    for (key, value) in params
        url *= key * "=" * value * "&"
    end
    return url
end 

"""
Takes a response object and returns a DataFrame

params = Dict("deliveryDateFrom" => "2024-02-01", "deliveryDateTo" => "2024-02-25")

da_dat = parse_ercot_response(ercot_api_call(token["id_token"], ercot_api_url(params, da_prices)))

#Note: RTD LMP includes all adders
params = Dict("RTDTimestampFrom" => "2024-02-01T00:00:00", "RTDTimestampTo" => "2024-02-01T01:00:00")
rt_dat = parse_ercot_response(ercot_api_call(token["id_token"], ercot_api_url(params, rt_prices)))

"""
function parse_ercot_response(response)
    # data is a vector of vectors, each of them is a row 
    dat = response["data"]
    fields = [response["fields"][x]["label"] for x in 1:length(response["fields"])]
    # iterate over each row and create a dictionary
    datdict = [Dict(fields[i] => dat[j][i] for i in 1:length(fields)) for j in 1:length(dat)]
    return DataFrame(datdict)
end

"""
# Mega function to get the data from ERCOT API

Examples:
params = Dict("deliveryDateFrom" => "2024-02-01", "deliveryDateTo" => "2024-02-25")
da_dat = get_ercot_data(params, da_prices)

# Real Time Prices for every five minutes 
params = Dict("RTDTimestampFrom" => "2024-02-01T00:00:00", 
                "RTDTimestampTo" => "2024-02-01T01:00:00",
                "settlementPoint" => "HB_NORTH")
rt_dat = get_ercot_data(params, rt_prices)

## Load Forecast
params = Dict("deliveryDateFrom" => "2024-02-01", "deliveryDateTo" => "2024-02-25")
lf_dat = get_ercot_data(params, ercot_load_forecast)

## Zone Load Forecast
params = Dict("deliveryDateFrom" => "2024-02-21", "deliveryDateTo" => "2024-02-25")
lf_dat = get_ercot_data(params, ercot_zone_load_forecast)

## Solar System Forecast
params = Dict("deliveryDateFrom" => "2024-02-21")
lf_dat = get_ercot_data(params, solar_system_forecast)

## Wind System Forecast
params = Dict("deliveryDateFrom" => "2024-03-21")
lf_dat = get_ercot_data(params, wind_system_forecast)

"""
function get_ercot_data(params, url)
    token = get_auth_token()
    response = ercot_api_call(token["id_token"], ercot_api_url(params, url))
    return parse_ercot_response(response)
end

## Open Artifact Training Data: utility function using artifacts

function trainingdata()
    training_dataset_path = artifact"training"
    # read in with JLD load 
    dat = JLD.load(training_dataset_path*"/training.jld")
    return dat["alldata"]
end



end # module