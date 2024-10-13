## Examples

using ErcotMagic, DotEnv

# Load the environment variables
DotEnv.config()

# Get the auth token
token = get_auth_token()

## Just getting some data for various ERCOT API endpoints
params = Dict("deliveryDateFrom" => "2024-02-01", "deliveryDateTo" => "2024-02-25", "settlementPoint" => "HB_NORTH")
da_dat = get_ercot_data(params, ErcotMagic.da_prices)

# Real Time Prices for every five minutes - earliest available is 2023-12-11
params = Dict("deliveryDateFrom" => "2023-12-11", 
                "deliveryDateTo" => "2024-10-10", 
                "settlementPoint" => "HB_NORTH",
                "size" => "1000000")
rt_dat = get_ercot_data(params, ErcotMagic.rt_prices)

## Load Forecast
params = Dict("deliveryDateFrom" => "2024-02-01", "deliveryDateTo" => "2024-02-25")
lf_dat = get_ercot_data(params, ercot_load_forecast)

## Zone Load Forecast
params = Dict("deliveryDateFrom" => "2024-02-21", "deliveryDateTo" => "2024-02-25")
lf_dat = get_ercot_data(params, ErcotMagic.ercot_zone_load_forecast)

## Solar System Forecast
params = Dict("deliveryDateFrom" => "2024-02-21")
lf_dat = get_ercot_data(params, solar_system_forecast)

## Wind System Forecast
params = Dict("deliveryDateFrom" => "2024-03-21")
lf_dat = get_ercot_data(params, wind_system_forecast)

## Energy Only Offers
params = Dict("deliveryDateFrom" => "2024-02-02", 
                "deliveryDateTo" => "2024-02-03", 
                "size" => "100", 
                "sort" => "random()")
eo_dat = get_ercot_data(params, ErcotMagic.sixty_dam_energy_only_offers)

## Generator data 
params = Dict("deliveryDateFrom" => "2024-02-02", 
                "deliveryDateTo" => "2024-02-03", 
                "size" => "100")

## SCED data 
params = Dict("SCEDTimestampFrom" => "2024-02-02T01:00:00", 
                "SCEDTimestampTo" => "2024-02-03T01:00:00", 
                "size" => "100")

sced_dat = get_ercot_data(params, ErcotMagic.sced_data)

## Remove spaces from the column names
gen_dat = rename(gen_dat, replace.(names(gen_dat), " " => "_"))
## Tabulate 