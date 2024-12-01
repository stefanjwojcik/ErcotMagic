## Script to run daily to update the data from the API
using ErcotMagic 
## This script is used to update the data from the API. It is run daily to get the latest data. The data is then saved in a csv file and pushed to an S3 bucket.

function generate_plan()
    # Get files in the ercotmagic bucket
    files = ErcotMagic.awsfiles()
    # Get the last updated date for each file 
\end 

function process_one_endpoint(startdate, enddate, endpoint, addparams; type="forecast", last_updated=::String)
    data = ErcotMagic.batch_retrieve_data(startdate, enddate, endpoint, additional_params=addparams)
    ErcotMagic.add_datetime!(data, endpoint)
    if type == "forecast"
        data = ErcotMagic.filter_forecast_by_posted(data)
    elseif type == "actuals"
        data = ErcotMagic.filter_actuals_by_posted(data)
    end
    fileout = tempname() * ".csv"
    CSV.write(fileout, data)
    ErcotMagic.upload_csv_to_s3("ercotmagic", fileout, "$endpoint$last_updated.csv")
    @info "Data for $endpoint uploaded to S3"
end


function daily_update()
    startdate = today() - Day(7)
    enddate = today() - Day(1)
    addparams = Dict("size" => "1000000")
    last_updated = ErcotMagic.get_last_updated()
    non_sced_endpoints = ErcotMagic.get_non_sced_endpoints()
    ## Non-SCED Endpoints 
    
    for endpoint in endpoints
    end
end 