## Runtests 

using Test, ErcotMagic, DataFrames


## FUNCTIONS FROM ErcotMagic.jl and constants.jl
@testset "Auth and Simple Data Pulls" begin 
    startdate, enddate = string(today()-Day(7)), string(today()-Day(7))
    @test typeof(ErcotMagic.get_auth_token()) <: Dict
    @test typeof(ErcotMagic.ercot_api_url(Dict(), ErcotMagic.da_prices)) == String
    @test typeof(ErcotMagic.ercot_api_call(ErcotMagic.get_auth_token()["id_token"], ErcotMagic.ercot_api_url(Dict(), ErcotMagic.da_prices))) <: Dict
    @test typeof(ErcotMagic.get_ercot_data(Dict("deliveryDateFrom" => startdate, "deliveryDateTo" => enddate, "settlementPoint" => "HB_NORTH"), ErcotMagic.da_prices)) == DataFrame
end

@testset "Parsing Data" begin 
    response = ErcotMagic.ercot_api_call(ErcotMagic.get_auth_token()["id_token"], ErcotMagic.ercot_api_url(Dict("deliveryDateFrom" => "2024-02-01", "deliveryDateTo" => "2024-02-01", "settlementPoint" => "HB_NORTH"), ErcotMagic.da_prices))
    @test typeof(ErcotMagic.parse_ercot_response(response)) == DataFrame
end
#############

## FUNCTIONS FROM load_data.jl

@testset "load data in batches" begin 
    startdate, enddate = today()-Day(7), today()-Day(7)
    @test typeof(ErcotMagic.batch_retrieve_data(startdate, enddate, "da_prices")) == DataFrame
end

@testset "adding dates to data from all the endpoints" begin 
    startdate, enddate = today()-Day(7), today()-Day(7)
    addparams = Dict("size" => "20")
    ## 
    daprices = ErcotMagic.batch_retrieve_data(startdate, enddate, "da_prices", additional_params=addparams)
    @test nrow(daprices) > 0

    ErcotMagic.add_datetime!(daprices, "da_prices")
    rtprices = ErcotMagic.batch_retrieve_data(startdate, enddate, "rt_prices", additional_params=addparams)
    @test nrow(rtprices) > 0 
    elf = ErcotMagic.batch_retrieve_data(startdate, enddate, "ercot_load_forecast", additional_params=addparams)
    @test nrow(elf) > 0
    ezlf = ErcotMagic.batch_retrieve_data(startdate, enddate, "ercot_zone_load_forecast", additional_params=addparams)
    @test nrow(ezlf) > 0 
    eal = ErcotMagic.batch_retrieve_data(startdate, enddate, "ercot_actual_load", additional_params=addparams)
    @test nrow(eal) >0 
    eo = ErcotMagic.batch_retrieve_data(startdate, enddate, "ercot_outages", additional_params=addparams)
    @test nrow(eo) > 0
    ssf = ErcotMagic.batch_retrieve_data(startdate, enddate, "solar_system_forecast", additional_params=addparams)
    @test nrow(ssf) > 0 
    wsf = ErcotMagic.batch_retrieve_data(startdate, enddate, "wind_system_forecast", additional_params=addparams)
    @test nrow(wsf) > 0
    wp5m = ErcotMagic.batch_retrieve_data(startdate, enddate, "wind_prod_5min", additional_params=addparams)
    @test nrow(wp5m) > 0 
    sp5m = ErcotMagic.batch_retrieve_data(startdate, enddate, "solar_prod_5min", additional_params=addparams)
    @test nrow(sp5m) > 0 
end

@testset "adding dates to data from all the endpoints" begin 
    endpoints = ["da_prices", "rt_prices", "ercot_load_forecast", "ercot_zone_load_forecast", "ercot_actual_load", "ercot_outages", "solar_system_forecast", "wind_system_forecast", "wind_prod_5min", "solar_prod_5min"]
    startdate, enddate = today()-Day(7), today()-Day(7)
    addparams = Dict("size" => "20")
    dataframearray = DataFrame[]
    for ep in endpoints
        dat = ErcotMagic.batch_retrieve_data(startdate, enddate, ep, additional_params=addparams)
        push!(dataframearray, dat)
        @test nrow(dat) > 0
        ErcotMagic.add_datetime!(dat)
        @test "DATETIME" ∈ names(dat)
    end
end

@testset "Filtering Methods for Forecasts" begin 
    startdate, enddate = today()-Day(7), today()
    addparams = Dict("size" => "1000000")
    ## 
    endpoints = ["ercot_load_forecast", "ercot_zone_load_forecast", "ercot_outages", "solar_system_forecast", "wind_system_forecast"]
    dataframearray = DataFrame[]
    for ep in endpoints
        dat = ErcotMagic.batch_retrieve_data(startdate, enddate, ep, additional_params=addparams)
        push!(dataframearray, dat)
        @test nrow(dat) > 0
        ErcotMagic.add_datetime!(dat)
        @test "DATETIME" ∈ names(dat)
        # Calculate the difference between posted and DATETIME 
        dat = ErcotMagic.filter_forecast_by_posted(dat)
        dat.daysdiff = Dates.value.(dat.DATETIME .- DateTime.(dat.Posted)) ./ (24*60*60_000)
        @test all(x -> 1.0 <= x <= 1.5, dat.daysdiff)
    end
end
