## Prices Data 

"""
params = Dict("deliveryDateFrom" => "2024-02-01", 
                "deliveryDateTo" => "2024-02-02")
anc = get_ercot_data(params, ErcotMagic.ancillary_prices)

"""
function get_prices(dates::Vector{Date})
    pricesendpoints = ErcotMagic.EndPoint[
                ErcotMagic.da_prices,
                ErcotMagic.da_system_lambda,
                ErcotMagic.ancillary_prices,
                ErcotMagic.rt_prices,
                ErcotMagic.rt_system_lambda,
        ]
    for ep in pricesendpoints
    # Get the data for each endpoint
    for day in dates
        params = Dict("deliveryDateFrom" => string(startdate), 
                      "deliveryDateTo" => string(enddate))
        # Get the data for the endpoint
        data = get_ercot_data(params, ep)
        # Process the data
        ErcotMagic.postprocess_endpoint_data!(data)
        # Save the data to a CSV file
        filename = string(ep.endpoint, "_", startdate, ".csv")
        CSV.write(filename, data)
    end
end