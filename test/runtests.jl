## Runtests 

using Test, ErcotMagic, DataFrames


## FUNCTIONS FROM ErcotMagic.jl and constants.jl
@testset "Auth and Simple Data Pulls" begin 
    @test typeof(ErcotMagic.get_auth_token()) <: Dict
    @test typeof(ErcotMagic.ercot_api_url(Dict(), ErcotMagic.da_prices)) == String
    @test typeof(ErcotMagic.ercot_api_call(ErcotMagic.get_auth_token()["id_token"], ErcotMagic.ercot_api_url(Dict(), ErcotMagic.da_prices))) <: Dict
    @test typeof(ErcotMagic.get_ercot_data(Dict("deliveryDateFrom" => "2024-02-01", "deliveryDateTo" => "2024-02-01", "settlementPoint" => "HB_NORTH"), ErcotMagic.da_prices)) == DataFrame
end

@testset "Parsing Data" begin 
    response = ErcotMagic.ercot_api_call(ErcotMagic.get_auth_token()["id_token"], ErcotMagic.ercot_api_url(Dict("deliveryDateFrom" => "2024-02-01", "deliveryDateTo" => "2024-02-01", "settlementPoint" => "HB_NORTH"), ErcotMagic.da_prices))
    @test typeof(ErcotMagic.parse_ercot_response(response)) == DataFrame
end
#############

## FUNCTIONS FROM load_data.jl

@testset "load data in batches" begin 
    @test typeof(ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 1), "da_prices")) == DataFrame
end