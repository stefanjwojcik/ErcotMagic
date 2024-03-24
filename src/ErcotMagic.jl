module ErcotMagic

using HTTP
using JSON
using DotEnv

DotEnv.config()

const da_prices = "https://api.ercot.com/api/public-reports/np4-190-cd/dam_stlmnt_pnt_prices?"
const rt_prices = "https://api.ercot.com/api/public-reports/np6-970-cd/rtd_lmp_node_zone_hub?"
const sixty_dam_energy_only_offers = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offers?"
const sixty_dam_awards = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_only_offer_awards?"
const twodayAS = "https://api.ercot.com/api/public-reports/np3-911-er/2d_agg_as_offers_ecrsm?"
const energybids = "https://api.ercot.com/api/public-reports/np3-966-er/60_dam_energy_bids?"

"""
# A function to retreive the auth token 
token = get_auth_token()
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

end # module