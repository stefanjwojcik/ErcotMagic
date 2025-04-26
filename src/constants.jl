## CONSTANTS and Configs for calling ERCOT API

@kwdef mutable struct EndPoint
    endpoint::String
    summary::String
    parameters::Vector{String}
    datekey::Vector{String}=String[]
end

function parse_github_openapi_spec(; kwargs...)
    download_spec = get(kwargs, :download_spec, false)
    if download_spec 
        # OpenAPI spec for the ERCOT API
        open_spec_url = "https://raw.githubusercontent.com/ercot/api-specs/refs/heads/main/pubapi/pubapi-apim-api.json"
        # Load the Open API spec
        open_spec = download(open_spec_url) |> JSON.parsefile
    else 
        open_spec = JSON.parsefile("artifacts/pubapi-apim-api.json")
    end
    allkeys = collect(keys(open_spec["paths"]))
    return open_spec, allkeys
end

function parse_endpoints_summaries(allkeys, open_spec)
    endpoints = [open_spec["servers"][1]["url"]*x*"?" for x in allkeys]
    summaries = [open_spec["paths"][x]["get"]["summary"] for x in allkeys]
    return endpoints, summaries
end

function extract_named_parameters(allkeys, open_spec)
    # Extract named parameters 
    paramslist = Vector{String}[] # vector of vectors of strings
    for x in allkeys 
        prms = open_spec["paths"][x]["get"]["parameters"]# get dicts
        prms = [prms[i]["name"] for i in 1:length(prms)] # extract named parameters
        push!(paramslist, prms)
    end
    return paramslist
end    

"""
# Retrieves a list of possible date keys for filtering
- Checks for keywords in the parameter names
"""
function get_date_keys(paramsvec::Vector{String})
    # Keywords to check for in the parameter names
    keywords = ["date", "time", "delivery", "day"]
    # Find parameters that match any of the keywords
    found_params = filter(param -> any(contains(lowercase(param), kw) for kw in keywords), paramsvec)
    # Remove "To" and "From" from the matching parameters
    found_params = replace.(found_params, "To" => "", "From" => "")
    # Remove duplicates
    found_params = unique(found_params)
end

# Returns all endpoints from the OpenAPI spec in ErcotSpec format
# Iterates through Annotated_Endpoints and creates a constant for each endpoint
function parse_all_endpoints(Annotated_Endpoints)
    # OpenAPI spec for the ERCOT API
    open_spec, allkeys = parse_github_openapi_spec()
    # drop / and /version from allkeys 
    allkeys = filter(x -> x != "/" && x != "/version", allkeys)
    # Extract endpoints and summaries from the OpenAPI spec
    endpoints, summaries = parse_endpoints_summaries(allkeys, open_spec)
    # Get all named parameters 
    params = extract_named_parameters(allkeys, open_spec)
    # Get all date keys
    datekeys = [get_date_keys(params[i]) for i in 1:length(params)]
    # Create a vector of ErcotSpec objects -> should this be a dictionary of specs? 
    all_open_endpoints = Dict()
    for i in 1:length(allkeys)
        # Create a new ErcotSpec object and push it to the vector
        all_open_endpoints[endpoints[i]] = EndPoint(endpoint=endpoints[i], 
                                    summary=summaries[i], 
                                    parameters=params[i], 
                                    datekey=datekeys[i])
    end
    # Now, define the annotated endpoints as constants
    for (name, (datekey, url)) in Annotated_Endpoints
        # Find the corresponding ErcotSpec object in the vector
        try
            newep = all_open_endpoints[url]
            newep.datekey = [datekey]
            @eval global const $(Symbol(name)) = $newep
        catch 
            @warn "Endpoint $name not found in the OpenAPI spec"
        end
    end
end


"""
Function to list non-SCED endpoints for convenience
"""
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

"""
## Forecast endpoints 
"""
function get_production_endpoints()
    return ["ercot_load_forecast", 
    "ercot_zone_load_forecast", 
    "ercot_actual_load", 
    "ercot_outages", 
    "solar_system_forecast", 
    "wind_system_forecast"]
end

### ****************** DEPRECATED ******************

"""
## Function to convert the payload to parameters for the API call 
Takes in the endpoint name, start date, end date, and any additional parameters 

ep = "da_prices"
startdate = Date(2024, 2, 1)
enddate = Date(2024, 2, 10)
params = ErcotMagic.APIparams(ep, startdate, enddate)
"""
function APIparams(endpointname::String, startdate::Date, enddate::Date; additional_params=Dict())
    datekey, url = ENDPOINTS[endpointname]
    # IF endpoint contains "forecast", then add "postedDatetimeFrom" and "postedDatetimeTo"
    # 24 hours before the startdate  
    params = Dict()
    if datekey == "SCEDTimestamp"
        params[datekey * "From"] = string(DateTime(startdate))
        params[datekey * "To"] = string(DateTime(enddate))
    else 
        params[datekey * "From"] = string(startdate)
        params[datekey * "To"] = string(enddate)
    end
    #if occursin("prices", endpointname)
    #    params["settlementPoint"] = settlement_point
    #end
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