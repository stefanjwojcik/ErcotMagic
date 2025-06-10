module ErcotMagic

# Core API page: https://apiexplorer.ercot.com/
# Docs: https://developer.ercot.com/applications/pubapi/user-guide/openapi-documentation/

using HTTP
using JSON
using DotEnv, DataFrames, CSV
using Pkg.Artifacts
using Dates, ProgressMeter, Statistics

## Generate Endpoints from OpenAPI spec 
include("utils.jl") # Contains utility functions for the module
include("annotated_endpoints.jl") # Annotated list of endpoints
include("constants.jl") # Contains all the URLS for the Ercot API 
include("tokenstorage.jl")

# A way to easily surface all annotated endpoints
parse_all_endpoints(Annotated_Endpoints)
global const eps = collect(keys(Annotated_Endpoints))

export get_auth_token, 
        ercot_api_call, 
        ercot_api_url, 
        parse_ercot_response, 
        get_data, 
        trainingdata, 
        nothing_to_zero,
        SCED_gen_data,
        update_sced_data,
        average_sced_prices,
        average_sced_mws,
        update_da_offer_data

# Load environment variables from .env file
DotEnv.load!()

nothing_to_zero(x) = isnothing(x) ? 0.0 : x
nothing_to_missing(x) = isnothing(x) ? missing : x

"""
Provides a way to define an ERCOT API endpoint with its URL, summary, parameters, and notes.
"""
@kwdef mutable struct ErcotSpec
    endpoint::String
    summary::String
    parameters::Vector{String}
    notes::String="" # my notes on what the endpoint does
end



"""
# A function to retreive the auth token from the ERCOT API
This function retrieves an authentication token from the ERCOT API using the Resource Owner Password Credentials (ROPC) flow. It constructs a URL with the necessary parameters, sends a POST request, and returns the parsed JSON response containing the token.

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

Assembles the URL for the ERCOT API call, including the authorization token and headers. It sends a GET request to the specified URL and returns the parsed JSON response.

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

Does not actually return any data 

- See ercotapicall.jl for some examples
"""
function ercot_api_url(params, url)
    for (key, value) in params
        url *= string(key) * "=" * value * "&"
    end
    return url
end 

"""
Parses the response from the ERCOT API call and converts it into a DataFrame.

- See ercotapicall.jl for some examples
"""
function parse_ercot_response(response; verbose=false)
    # data is a vector of vectors, each of them is a row 
    dat = response["data"]
    # get number of records 
    if verbose
        println("Number of records: ", length(dat))
    end
    fields = [response["fields"][x]["label"] for x in 1:length(response["fields"])]
    # iterate over each row and create a dictionary
    datdict = [Dict(fields[i] => dat[j][i] for i in 1:length(fields)) for j in 1:length(dat)]
    return DataFrame(datdict)
end

"""
Filter kwargs to include only those that are valid for the given endpoint
"""
function filter_valid_kwargs(endpoint::ErcotMagic.EndPoint, kwargs)
    # Extract parameter names from the endpoint definition
    # Assuming endpoint.parameters is a vector or collection of parameter information
    valid_param_names = Symbol[]
    
    # This part depends on how parameters are stored in your EndPoint struct
    # For example, if endpoint.parameters is an array of named tuples or structs:
    if hasproperty(endpoint, :parameters) && !isnothing(endpoint.parameters)
        for param in endpoint.parameters
            push!(valid_param_names, Symbol(param))
        end
    end
    
    # Filter kwargs to include only those whose keys are in valid_param_names
    return Dict(k => v for (k, v) in kwargs if k in valid_param_names)
end

"""
# Retrieve and parse the data from ERCOT API for a specific date, regardless of the date key
- automatically will determine the date key based on the endpoint
Examples:
```julia
using ErcotMagic
using Dates

# Day-Ahead Prices
da_dat = get_data(ErcotMagic.da_prices, Date(2024, 2, 1), settlementPoint="AEEC")

# Day-Ahead System Lambda
da_system_lambda_dat = get_data(ErcotMagic.da_system_lambda, Date(2024, 2, 1))

# Ancillary Prices - get and convert from long to wide format
ancillary_prices_dat = get_data(ErcotMagic.ancillary_prices, Date(2024, 2, 1))
ErcotMagic.ancillary_long_to_wide(ancillary_prices_dat)

# Real Time Prices 
rt_prices_dat = get_data(ErcotMagic.rt_prices, Date(2024, 2, 1), settlementPoint="AEEC")

# Real Time System Lambda
rt_system_lambda_dat = get_data(ErcotMagic.rt_system_lambda, Date(2024, 2, 1))

```
"""
function get_data(endpoint::EndPoint, date::Date; kwargs...)
    filtered_kwargs = filter_valid_kwargs(endpoint, kwargs)
    params = kwargs_to_string(Dict(filtered_kwargs))
    # add the datekey 
    dateparams!(endpoint, date, params)
    token = get_valid_token!()
    response = ercot_api_call(token, ercot_api_url(params, endpoint.endpoint))
    return normalize_columnnames!(parse_ercot_response(response))
end

"""
# Vectorized dates version of the get_data function 

- Takes in a vector of dates and returns a DataFrame
- Automatically determines the date key based on the endpoint
Examples:

```julia
# Day-Ahead Prices
da_dat = ErcotMagic.get_data(ErcotMagic.da_prices, [Date(2024, 2, 1), Date(2024, 2, 2)], settlementPoint="AEEC")
```
"""
function get_data(endpoint::EndPoint, dates::Vector{Date}; kwargs...)
    dat = DataFrame()
    for d in dates
        dat = vcat(dat, get_data(endpoint, d; kwargs...))
    end
    return dat
end

## Open Artifact Training Data: utility function using artifacts

function trainingdata()
    training_dataset_path = artifact"training"
    # read in with JLD load 
    dat = JLD.load(training_dataset_path*"/training.jld")
    return dat["alldata"]
end

#include("prices.jl") # Contains functions to process prices data
#include("sceddy.jl") # Contains functions to process SCED data
#include("batch_retrieve.jl")
include("postprocessing.jl")
include("load.jl")
#include("bq.jl")

end # module