
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
# Alternative datetime version that is simpler 
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
