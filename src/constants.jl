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
        catch e 
            print("Error: $e")
            #@warn "Endpoint $name not found in the OpenAPI spec"
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



