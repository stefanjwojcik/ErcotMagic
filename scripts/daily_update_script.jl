## Script to run daily to update the data from the API
using ErcotMagic 
## This script is used to update the data from the API. It is run daily to get the latest data. The data is then saved in a csv file and pushed to an S3 bucket.

function daily_nonsced_update(;kwargs...)
    startdate = get(kwargs, :startdate, today() - Day(1))
    enddate = get(kwargs, :enddate, today() - Day(1))
    enddate = today() - Day(1)
    addparams = Dict("size" => "1000000")
    #last_updated = ErcotMagic.get_last_updated()
    non_sced_endpoints = ErcotMagic.get_non_sced_endpoints()
    ## Non-SCED Endpoints 
    datout = DataFrame[]
    for endpoint in non_sced_endpoints
        println("Processing endpoint: ", endpoint)
        try
            dat = ErcotMagic.process_one_endpoint(startdate, enddate, endpoint, additional_params=addparams)
            push!(datout, dat)
        catch e
            println("Error processing endpoint: ", endpoint)
            println(e)
        end
    end
    return vcat(datout...)
end 

## Now Function to Update the SCED Data 
function daily_sced_update()
end