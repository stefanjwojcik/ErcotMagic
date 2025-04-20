### Load ERCOT Data for Forecasting and Training

## TODO: Deal with load forecasts 

###################

function add_fiveminute_intervals!(df::DataFrame)
    df.DATETIME = Dates.DateTime.(df.DeliveryDate) .+ Hour.(df.DeliveryHour) .+ Minute.(df.DeliveryInterval .* 5)    
    return df
end

"""
### Process 5 min RT LMP- see RTD indicative LMPs here: https://www.ercot.com/content/cdr/html/rtd_ind_lmp_lz_hb_HB_NORTH.html
params = Dict("deliveryDateFrom" => "2024-02-01", 
                "deliveryDateTo" => "2024-02-02", 
                "settlementPoint" => "HB_NORTH",
                "size" => "1000000")
rt_dat = get_ercot_data(params, ErcotMagic.rt_prices)
outages = get_ercot_data(params, ErcotMagic.ercot_outages)
ErcotMagic.normalize_columnnames!(rt_dat)
rt_dat = ErcotMagic.process_5min_settlements_to_hourly(rt_dat)
"""
function process_5min_settlements_to_hourly(df::DataFrame)
    #df[!, :DATETIME] = Dates.DateTime.(df[!, ep.datekey * "Date"]) .+ Hour.(df[!, ep.datekey * "Hour"])
    df.DATETIME = Dates.DateTime.(df.DeliveryDate) .+ Hour.(df.DeliveryHour) 
    df = combine(groupby(df, [:DATETIME, :SettlementPoint]), :SettlementPointPrice => mean => :RTLMP)
    return df
end

"""
    rtsyslambda = ErcotMagic.batch_retrieve_data(startdate, enddate, "rt_system_lambda") |>
        (data -> ErcotMagic.process_5min_lambda_to_hourly(data))
"""
function process_5min_lambda_to_hourly(df::DataFrame)
    #df[!, :DATETIME] = Dates.DateTime.(df[!, ep.datekey * "Date"]) .+ Hour.(df[!, ep.datekey * "Hour"])
    df.DATETIME = Dates.floor.(DateTime.(df.SCEDTimestamp), Dates.Hour)
    df = combine(groupby(df, [:DATETIME]), :SystemLambda => mean => :RTSystemLambda)
    return df
end


function process_sced_to_hourly(df::DataFrame, timecol=:SCEDTimestamp)
    #df[!, :DATETIME] = Dates.DateTime.(df[!, ep.datekey * "Date"]) .+ Hour.(df[!, ep.datekey * "Hour"])
    df.DATETIME = Dates.DateTime.(df[!, timecol])
    df = combine(groupby(df, :DATETIME), val => mean => :RTLMP)
    return df
end

function sced_to_hourly(df::DataFrame)
    # Ensure :DATETIME is rounded to the hour
    df.DATETIME = Dates.floor.(DateTime.(df.SCEDTimeStamp), Dates.Hour)

    # Aggregate all numeric columns by taking their mean
    numeric_cols = [col for col in names(df) if eltype(df[:, Symbol(col)]) <: Real]  # Select numeric columns
    agg_funcs = [col => mean => col for col in numeric_cols]  # Create aggregation rules

    # Group by :DATETIME and apply aggregation
    df_hourly = combine(groupby(df, :DATETIME), agg_funcs...)
    return df_hourly
end


