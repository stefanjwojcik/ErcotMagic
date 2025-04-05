## Script to run daily to update the data from the API
using ErcotMagic, Dates, DataFrames 
## This script is used to update the data from the API. It is run daily to get the latest data. The data is then saved in a csv file and pushed to an S3 bucket.

ErcotMagic.bq_auth()

# Idea is to dynamically update the Bigquery Data 
function get_start_date(endpoint::String)
    bq_start_date = ErcotMagic.bq("SELECT MAX(DATETIME(DATETIME)) FROM ercot." * endpoint)
    bq_start_date = isnothing(bq_start_date) ? Date(2023, 12, 13) : Date(bq_start_date[1, 1])
    return bq_start_date + Day(1)
end

## Hourly Settlement Prices - DA/RT/Ancillaries/Lambdas
function hourly_settlement_prices(; kwargs...)    
    startdate = get(kwargs, :start, today() - Day(1))
    enddate = get(kwargs, :end, today())
    # LMPs, SystemLambda, Ancillaries 
    dalmp = ErcotMagic.batch_retrieve_data(startdate, enddate, "da_prices") |> 
        (data -> rename(data, :SettlementPointPrice => :DALMP)) |> 
        (data -> select(data, [:DATETIME, :DALMP, :SettlementPoint]))
    # Get RT data 
    rt = ErcotMagic.batch_retrieve_data(startdate, enddate, "rt_prices") |> 
        (data -> ErcotMagic.process_5min_settlements_to_hourly(data)) |> 
        (data -> select(data, [:DATETIME, :RTLMP, :SettlementPoint])) 
    anc = ErcotMagic.batch_retrieve_data(startdate, enddate, "ancillary_prices")
    ## Convert from Long to wide 
    ancmin = dropmissing(unstack(select(anc, [:AncillaryType, :MCPC, :DATETIME]), :DATETIME, :AncillaryType, :MCPC))
    # System Lambda 
    dasyslambda = ErcotMagic.batch_retrieve_data(startdate, enddate, "da_system_lambda") |> 
        (data -> select(data, [:DATETIME, :SystemLambda])) |> 
        (data -> rename(data, :SystemLambda => :DASystemLambda))
    rtsyslambda = ErcotMagic.batch_retrieve_data(startdate, enddate, "rt_system_lambda") |>
        (data -> ErcotMagic.process_5min_lambda_to_hourly(data))
    # Combine all the data - join by DATETIME
    combined_df = innerjoin(dalmp, rt, on=[:DATETIME, :SettlementPoint])
    combined_df = leftjoin(combined_df, ancmin, on=:DATETIME)
    combined_df = leftjoin(combined_df, dasyslambda, on=:DATETIME)
    combined_df = leftjoin(combined_df, rtsyslambda, on=:DATETIME)
end

function hourly_mw_settlement()
    # TK
end

function hourly_forecasts()
    # TK
end

function actual_production()
    # TK
end

# Function to update the non-SCED data
# This function is used to update the non-SCED data from the API. It is run daily to get the latest data. The data is then saved in a csv file and pushed to a BigQuery table.
function daily_nonsced_update(;kwargs...)
    addparams = Dict("size" => "1000000")
    #last_updated = ErcotMagic.get_last_updated()
    non_sced_endpoints = ErcotMagic.get_non_sced_endpoints()
    for endpoint in non_sced_endpoints
        println("Processing endpoint: ", endpoint)
        try
            # Queries the BigQuery table to get the last updated date
            bq_start_date = get_start_date(endpoint)
            if bq_start_date >= today()
                println("No new data available for endpoint: ", endpoint)
                continue
            end
            dat = ErcotMagic.process_one_endpoint(bq_start_date, today(), endpoint, additional_params=addparams)
            # Stores the data at endpoint specific location
            ErcotMagic.send_to_bq_table(dat, "ercot", endpoint)
        catch e
            println("Error processing endpoint: ", endpoint)
            println(e)
        end
    end
    println("Non-SCED data updated successfully")
end 

## Now Function to Update the SCED Data 
function daily_sced_update()
    nothing
end