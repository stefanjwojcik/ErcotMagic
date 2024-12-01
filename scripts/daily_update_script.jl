## Script to run daily to update the data from the API
using ErcotMagic 
## This script is used to update the data from the API. It is run daily to get the latest data. The data is then saved in a csv file and pushed to an S3 bucket.

function generate_plan()
    # Get files in the ercotmagic bucket
    files = ErcotMagic.awsfiles()
    # Get the last updated date for each file 
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