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
"""
function batch_retrieve_data(startdate::Date, enddate::Date, endpoint::String; kwargs...)
    url = get(kwargs, :url, ErcotMagic.ENDPOINTS[endpoint][2])
    batchsize = get(kwargs, :batchsize, 4)
    additional_params = get(kwargs, :additional_params, Dict())
    ###################################
    alldat = DataFrame[]
    # split by day 
    alldays = [x for x in startdate:Day(batchsize):enddate]
    @showprogress for (i, marketday) in enumerate(alldays)
        fromtime = Date(marketday)
        totime = Date(min(marketday + Day(batchsize-1), enddate))
        # update params for the batch 
        params = ErcotMagic.APIparams(endpoint, fromtime, totime, additional_params=additional_params)
        ## GET THE DATA 
        dat = get_ercot_data(params, url)
        if isempty(dat)
            @warn "No data delivered for $(fromtime) to $(totime)"
            continue
        end
        normalize_columnnames!(dat)
        add_datetime!(dat)
        alldat = push!(alldat, dat)
    end
    out = vcat(alldat...)
    return out
end

