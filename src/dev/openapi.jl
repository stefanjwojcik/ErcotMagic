using JSON

### Parse the Open API spec for the ERCOT API 
open_spec_url = "https://raw.githubusercontent.com/ercot/api-specs/refs/heads/main/pubapi/pubapi-apim-api.json"

# Load the Open API spec
open_spec = download(open_spec_url) |> JSON.parsefile

# Get a valid server path 
ercot_api_url = open_spec["servers"][1]["url"]

mutable struct ErcotSpec
    openapi::String
    servers::Vector{Url}
    paths::Vector{Path}
    tags::Vector{Tags}
end

mutable struct Url
    url::String
end

mutable struct Path
    path::String
    method::String
    spec::Spec
end

mutable struct Spec
    summary::String
    parameters::String
    responses::String
    operationId::String
    operationId::Vector{String}
    description::String
end
