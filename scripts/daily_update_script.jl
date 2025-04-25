## Script to run daily to update the data from the API
using ErcotMagic, Dates, DataFrames 
## This script is used to update the data from the API. It is run daily to get the latest data. The data is then saved in a csv file and pushed to an S3 bucket.

ErcotMagic.bq_auth()

"""
## Gets Hourly Settlement Prices - DA/RT/Ancillaries/Lambdas
"""
function hourly_nodal_prices(; kwargs...)    
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

"""
## Gets net unit output, ancillary awards, and LSL/HSL for all UNITS at a specific node 
"""
function hourly_nodal_volumes(; kwargs...)
    startdate = get(kwargs, :start, Date("2024-06-01"))
    enddate = get(kwargs, :end, Date("2024-06-05"))
    RESOURCE_NODE = get(kwargs, :RESOURCE_NODE, "NOBLESLR_ALL")
    nodetounit = ErcotMagic.bq("SELECT * FROM ercot.nodetounit WHERE RESOURCE_NODE = '$RESOURCE_NODE'")
    unit_stations = nodetounit.UNIT_SUBSTATION .* "_" .* nodetounit.UNIT_NAME
    ## SCED Generation 
    station_data = DataFrame()
    for station in unit_stations 
        ap = Dict("resourceName" => station)
        sced = ErcotMagic.batch_retrieve_data(startdate, enddate, "sced_gen_data", additional_params=ap)
        sced = ErcotMagic.sced_to_hourly(sced)
        ## INCLUDES LSL/HSL/Ancillary Service ECRS/NSRS/REGDN/REGUP/RRS/RRSFFR AWARDS
        sced = select(sced, [:DATETIME, :TelemeteredNetOutput, 
                            :LSL, :HSL, :AncillaryServiceECRS, 
                          :AncillaryServiceNSRS, :AncillaryServiceREGDN, 
                         :AncillaryServiceREGUP, :AncillaryServiceRRS, 
                         :AncillaryServiceRRSFFR])
        sced[!, :ResourceName] .= station
        station_data = vcat(station_data, sced)
    end
    # Aggregate to the Resource Node by grouping by hour
    station_data.SettlementPoint .= RESOURCE_NODE
    return station_data 
end

"""
## Gets the hourly DA virtual ENERGY ONLY OFFERS for a specific node 
"""
function hourly_energy_only_virtuals(; kwargs...)
    startdate = get(kwargs, :start, today() - Day(1))
    enddate = get(kwargs, :end, today())
    RESOURCE_NODE = get(kwargs, :RESOURCE_NODE, "NOBLESLR_ALL")
    ap = Dict("settlementPointName" => RESOURCE_NODE)
    virts = ErcotMagic.batch_retrieve_data(startdate, enddate, "sixty_dam_awards", additional_params=ap)
    select(virts, [:EnergyOnlyOfferAwardinMW, :SettlementPoint, :DATETIME])
    return virts
end

function hourly_production_forecasts(; kwargs...)
    startdate = get(kwargs, :start, today() - Day(1))
    enddate = get(kwargs, :end, today())
    addparams = Dict("size" => "1000000")
    #last_updated = ErcotMagic.get_last_updated()
    production_endpoints = ErcotMagic.get_production_endpoints()
    out = DataFrame[]
    for endpoint in production_endpoints
        println("Processing endpoint: ", endpoint)
        dat = ErcotMagic.process_one_endpoint(startdate, enddate, endpoint, additional_params=addparams)
        push!(out, dat)
    end
    println("Forecast/production data updated successfully")
    return out
end

function actual_production()
    # TK
end

# Function to update the non-SCED data
# This function is used to update the non-SCED data from the API. It is run daily to get the latest data. The data is then saved in a csv file and pushed to a BigQuery table.
function daily_nonsced_update(;kwargs...)

end 

## Now Function to Update the SCED Data 
function daily_sced_update()
    nothing
end