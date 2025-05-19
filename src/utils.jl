
function kwargs_to_string(params::Dict)
    # Convert the dictionary to a string representation
    return Dict(string(k) => string(v) for (k, v) in params)
end

function normalize_columnnames!(df::DataFrame)
    #rename 
    rename!(df, replace.(names(df), " " => ""))
    rename!(df, replace.(names(df), "-" => "_"))
    return df
end

function parse_hour_ending(date::DateTime, hour_ending::String)
    if hour_ending == "24:00"
        return date + Hour(Time("00:00")) + Day(1) - Hour(1)
    else
        return date + Hour(Time(hour_ending, "HH:MM")) - Hour(1)
    end
end

function parse_hour_ending(date::DateTime, hour_ending::Int64)
    return date + Hour(hour_ending) - Hour(1)
end

"""
## Function to convert the payload to parameters for the API call 
Takes in the endpoint name, start date, end date, and any additional parameters 

ep = "da_prices"
startdate = Date(2024, 2, 1)
enddate = Date(2024, 2, 10)
params = ErcotMagic.APIparams(ep, startdate, enddate)
"""
function dateparams!(endpoint::EndPoint, date::Date, params::Dict)
    # IF endpoint contains "forecast", then add "postedDatetimeFrom" and "postedDatetimeTo"
    # 24 hours before the startdate  
    if endpoint.datekey == ["SCEDTimestamp"]
        params[string(endpoint.datekey[1]) * "From"] = string(DateTime(date))
        params[string(endpoint.datekey[1]) * "To"] = string(DateTime(date) + Day(1))
    else 
        params[string(endpoint.datekey[1]) * "From"] = string(date)
        params[string(endpoint.datekey[1]) * "To"] = string(date)
    end
end


"""
# Adding Datetimes to output data 
"""
function add_datetime!(df::DataFrames.DataFrame)
    if "DeliveryInterval" ∈ names(df)
        df.DATETIME = DateTime.(df[!, "DeliveryDate"]) .+ Hour.(df[!, "DeliveryHour"]) .+ Minute.(df[!, "DeliveryInterval"] .* 5)
        return 
    elseif "IntervalEnding" ∈ names(df)
        df.DATETIME = DateTime.(df[!, "IntervalEnding"])
        return
    elseif "OperatingDay" ∈ names(df)
        df.DATETIME = parse_hour_ending.(DateTime.(df[!, "OperatingDay"]), df[!, "HourEnding"])
        return
    elseif "OperatingDate" ∈ names(df)
        df.DATETIME = parse_hour_ending.(DateTime.(df[!, "OperatingDate"]), df[!, "HourEnding"])
        return
    elseif "DeliveryHour" ∈ names(df)
        df.DATETIME = DateTime.(df[!, "DeliveryDate"]) .+ Hour.(df[!, "DeliveryHour"])
        return
    elseif "DeliveryDate" ∈ names(df)
        df.DATETIME = parse_hour_ending.(DateTime.(df[!, "DeliveryDate"]), df[!, "HourEnding"])
        return
    elseif "SCEDTimestamp" ∈ names(df) 
        df.DATETIME = DateTime.(df[!, "SCEDTimestamp"])
        return
    elseif "SCEDTimeStamp" ∈ names(df) 
        df.DATETIME = DateTime.(df[!, "SCEDTimeStamp"])
        return
    else
        @warn "No datetime columns found in the DataFrame"
        return
    end
end

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

function impute_using_moving_average(vec::Vector{Union{Missing, Float64}}, window::Int=4)
    # Create a copy of the vector to avoid modifying the original
    vec_copy = copy(vec)

    # Iterate over the vector and replace missing values with the moving average
    for i in 1:length(vec_copy)
        if ismissing(vec_copy[i])
            # Calculate the moving average of the surrounding values
            start_idx = max(1, i - window)
            end_idx = min(length(vec_copy), i + window)
            surrounding_values = vec_copy[start_idx:end_idx]
            non_missing_values = filter(!ismissing, surrounding_values)
            if !isempty(non_missing_values)
                vec_copy[i] = mean(non_missing_values)
            end
        end
    end

    return vec_copy
end

"""
## Function to find missing values in a DataFrame and impute them using moving average


"""
function find_missing_and_impute(df::DataFrame, window::Int=4)
    # Find all columns with missing values
    cols_with_union_missing = [col for col in names(df) if eltype(df[!, col]) == Union{Missing, Float64}]

    # Impute missing values in each column
    for col in cols_with_union_missing
        df[!, col] = impute_using_moving_average(df[!, col], window)
        # Parse back to Float64
        df[!, col] = convert.(Float64, df[:, col])
    end
    return df
end

function to_hourly(df::DataFrame, datecol::Symbol)
    # Ensure :DATETIME is rounded to the hour
    df.DATETIME = Dates.floor.(DateTime.(df[:, datecol]), Dates.Hour)

    # Aggregate all numeric columns by taking their mean
    numeric_cols = [col for col in names(df) if eltype(df[:, Symbol(col)]) <: Real]  # Select numeric columns
    agg_funcs = [col => mean => col for col in numeric_cols]  # Create aggregation rules

    # Group by :DATETIME and apply aggregation
    df_hourly = combine(groupby(df, :DATETIME), agg_funcs...)
    return df_hourly
end

function add_sced_hourly_column!(df::DataFrame; timecol::Symbol=:SCEDTimestamp)
    df.DATETIME = Dates.floor.(DateTime.(df[:, timecol]), Dates.Hour)
end