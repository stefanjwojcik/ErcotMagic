## Script to run daily to update the data from the API
using ErcotMagic 
## This script is used to update the data from the API. It is run daily to get the latest data. The data is then saved in a csv file and pushed to an S3 bucket.

function daily_update()
    startdate = today() - Day(7)
    enddate = today() - Day(1)
    addparams = Dict("size" => "1000000")
    last_updated = ErcotMagic.get_last_updated()
    non_sced_endpoints = ErcotMagic.get_non_sced_endpoints()
    ## Non-SCED Endpoints 
    
    for endpoint in endpoints
        data = ErcotMagic.batch_retrieve_data(startdate, enddate, endpoint, additional_params=addparams)
        ErcotMagic.add_datetime!(data, endpoint)
        ErcotMagic.save_to_csv(data, endpoint)
        ErcotMagic.upload_csv_to_s3("ercotmagic", "$endpoint$last_updated.csv", "$endpoint$last_updated.csv")
    end
end 