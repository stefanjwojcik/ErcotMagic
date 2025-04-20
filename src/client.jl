

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
# Mega function to get the data from ERCOT API

Examples:
params = Dict("deliveryDateFrom" => "2024-02-01", "deliveryDateTo" => "2024-02-25", "settlementPoint" => "HB_NORTH")
da_dat = get_ercot_data(params, ErcotMagic.da_prices)

# Real Time Prices for every five minutes 
params = Dict("RTDTimestampFrom" => "2024-02-01T00:00:00", 
                "RTDTimestampTo" => "2024-02-02T01:00:00",
                "settlementPoint" => "HB_NORTH", 
                "size" => "1000000")
rt_dat = get_ercot_data(params, ErcotMagic.rt_prices)

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
    if occursin("binding_constraints", endpointname)
        params = Dict()
        params["SCEDTimestampFrom"] = string(DateTime(startdate))
        params["SCEDTimestampTo"] = string(DateTime(enddate))
    end
    #if occursin("prices", endpointname)
    #    params["settlementPoint"] = settlement_point
    #end
    params["size"] = "1000000"
    merge!(params, additional_params)
    return params
end


"""
### Get multiple days of Data for any endpoint 
startdate = Date(2024, 2, 1)
enddate = Date(2024, 2, 10)

## Gen Forecast 
startdate = Date(2024, 2, 1)
enddate = Date(2024, 2, 4)
gen = ErcotMagic.batch_retrieve_data(startdate, enddate, "solar_prod_5min")

## Load Forecast
load = ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 4), "ercot_load_forecast")

## Actual Load 
actual_load = ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 4), "ercot_actual_load")

## RT LMP 
rt = ErcotMagic.batch_retrieve_data(Date(2023, 12, 13), Date(2024, 2, 4), "rt_prices")

## DA LMP
da = ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 4), "da_prices")

## Ancillary Prices 
anc = ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 4), "ancillary_prices")

## Binding Constraints 
bc = ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 4), "binding_constraints")
"""
function batch_retrieve_data(startdate::Date, enddate::Date, endpoint::String; kwargs...)
    url = get(kwargs, :url, ErcotMagic.ENDPOINTS[endpoint][2])
    batchsize = get(kwargs, :batchsize, 4)
    additional_params = get(kwargs, :additional_params, Dict())
    ###################################
    alldat = DataFrame[]
    # split by day 
    alldays = [x for x in startdate:Day(batchsize):enddate]
    @showprogress for (i, marketday) in enumerate(alldays)
        fromtime = Date(marketday)
        totime = Date(min(marketday + Day(batchsize-1), enddate))
        # update params for the batch 
        params = ErcotMagic.APIparams(endpoint, fromtime, totime, additional_params=additional_params)
        ## GET THE DATA 
        dat = get_ercot_data(params, url)
        if isempty(dat)
            @warn "No data delivered for $(fromtime) to $(totime)"
            continue
        end
        normalize_columnnames!(dat)
        add_datetime!(dat)
        alldat = push!(alldat, dat)
    end
    out = vcat(alldat...)
    return out
end