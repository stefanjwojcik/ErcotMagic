## Examples

using ErcotMagic, DotEnv

startdate, enddate = today()-Day(7), today()-Day(7)
addparams = Dict("size" => "20")
## Get Day Ahead Prices 
daprices = ErcotMagic.batch_retrieve_data(startdate, enddate, "da_prices", additional_params=addparams)
ErcotMagic.add_datetime!(daprices, "da_prices")
