module ErcotMagic

# Core API page: https://apiexplorer.ercot.com/
# Docs: https://developer.ercot.com/applications/pubapi/user-guide/openapi-documentation/

using HTTP
using JSON
using DotEnv, DataFrames, CSV
using Pkg.Artifacts
using Dates, ProgressMeter, Statistics

export get_auth_token, 
        TokenStorage,
        get_valid_token!,
        ercot_api_call, 
        ercot_api_url, 
        parse_ercot_response, 
        get_ercot_data, 
        trainingdata, 
        nothing_to_zero,
        SCED_gen_data,
        update_sced_data,
        average_sced_prices,
        average_sced_mws,
        update_da_offer_data

DotEnv.config()

nothing_to_zero(x) = isnothing(x) ? 0.0 : x
nothing_to_missing(x) = isnothing(x) ? missing : x

## NEW 
#include("endpoints.jl") ## Contains all the URLS for the Ercot API
#include("client.jl") ## Contains the client functions to get the data from the API
#include("utils.jl") ## Contains the utility functions to process the data 
#include("prices.jl")   # all zonal and system level prices data for DA, RT, and Ancillary Services
#include("load.jl") # all zonal and system level load data
#include("gen.jl") # all zonal and system level generation data for wind, solar, and thermal
#include("awards.jl") #includes ancillary, 60 day generation, and load awards at the asset or node level

## OLD 
include("constants.jl") # Contains all the URLS for the Ercot API 
include("load_data.jl")
include("postprocessing.jl")
include("sceddy.jl") # Contains functions to process SCED data - move to a different package 
include("bq.jl")


## Open Artifact Training Data: utility function using artifacts

function trainingdata()
    training_dataset_path = artifact"training"
    # read in with JLD load 
    dat = JLD.load(training_dataset_path*"/training.jld")
    return dat["alldata"]
end


end # module