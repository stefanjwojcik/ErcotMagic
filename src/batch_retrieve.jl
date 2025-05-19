### Load ERCOT Data for Forecasting and Training

###################



### Get multiple days of Data 

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

## Sced Production 
ap = Dict("resourceType" => "PVGR")
#ap = Dict("resourceName" => "NOBLESLR_SOLAR1")
sced = ErcotMagic.batch_retrieve_data(Date(2024, 2, 1), Date(2024, 2, 2), "sced_gen_data", additional_params=ap)
"""
function batch_retrieve_data(startdate::Date, enddate::Date, endpoint::ErcotMagic.EndPoint; kwargs...)
    url = get(kwargs, :url, endpoint.endpoint)
    batchsize = get(kwargs, :batchsize, 4)
    additional_params = get(kwargs, :additional_params, Dict())
    ###################################
    alldat = DataFrame[]
    # split by day 
    alldays = [x for x in startdate:Day(batchsize):enddate]
    @showprogress for (i, marketday) in enumerate(alldays)
        fromtime = Date(marketday)
        # TODO: This needs to be refactored - 
        totime = Date(min(marketday + Day(batchsize-1), enddate))
        # update params for the batch 
        params = ErcotMagic.APIparams(endpoint, fromtime, totime, additional_params=additional_params)
        ## GET THE DATA 
        dat = get_ercot_data(params, url)
        if isempty(dat)
            @warn "No data delivered for $(fromtime) to $(totime)"
        else 
            normalize_columnnames!(dat)
            add_datetime!(dat)
            alldat = push!(alldat, dat)    
        end
    end
    out = vcat(alldat...)
    return out
end
