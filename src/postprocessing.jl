## Post-processing the data 

#create three config subtypes: 

# datekey + HourEnding to get the datetime - da prices 
# datekey + DeliveryHour + DeliveryInterval - rt prices 
# datekey + HourEnding - ercot load forecast (need to stack by model) (need to filter by Posted DateTime)
# datekey + HourEnding - ercot load actuals 
# datekey + OperatingDate + HourEnding - ercot outages (need to filter by Posted DateTime) (The total outage column is TotalResource*)
# 

function parse_hour_ending(date::DateTime, hour_ending::String)
    if hour_ending == "24:00"
        return date + Hour(Time("00:00")) + Day(1)
    else
        return date + Hour(Time(hour_ending, "HH:MM"))
    end
end

function parse_hour_ending(date::DateTime, hour_ending::Int64)
    return date + Hour(hour_ending)
end

"""
## Add datetime to the data frame 
"""
function add_datetime!(df::DataFrame, endpoint::String)
    datekey, url = ErcotMagic.ENDPOINTS[endpoint]
    if datekey == "intervalEnding"
        df.DATETIME = DateTime.(df[!, :IntervalEnding])
    elseif datekey == "operatingDate"
        df.DATETIME = DateTime.(df[!, :OperatingDate]) .+ Hour.(df[!, :HourEnding])
    elseif datekey == "operatingDay" 
        df.DATETIME = parse_hour_ending.(DateTime.(df[!, "OperatingDay"]), df[!, :HourEnding])
    elseif datekey == "deliveryDate" && endpoint == "rt_prices"
        df.DATETIME = DateTime.(df[!, :DeliveryDate]) .+ Hour.(df[!, :DeliveryHour]) .+ Minute.(df[!, :DeliveryInterval] .* 5)
    else
        df.DATETIME = parse_hour_ending.(DateTime.(df[!, "DeliveryDate"]), df[!, :HourEnding])
    end
end

"""
# Alternative datetime version that is simpler 
"""
function add_datetime!(df::DataFrame)
    for col in names(df)
        if "DeliveryInterval" ∈ names(df)
            df.DATETIME = DateTime.(df[!, "DeliveryDate"]) .+ Hour.(df[!, "DeliveryHour"]) .+ Minute.(df[!, col] .* 5)
            return 
        elseif "IntervalEnding" ∈ names(df)
            df.DATETIME = DateTime.(df[!, col])
            return
        elseif "OperatingDay" ∈ names(df)
            df.DATETIME = parse_hour_ending.(DateTime.(df[!, col]), df[!, "HourEnding"])
            return
        elseif "DeliveryHour" ∈ names(df)
            df.DATETIME = DateTime.(df[!, "DeliveryDate"]) .+ Hour.(df[!, col])
            return
        elseif "DeliveryDate" ∈ names(df)
            df.DATETIME = parse_hour_ending.(DateTime.(df[!, col]), df[!, "HourEnding"])
            return
        end
    end
end



function detect_date_type(df::DataFrame, column::Symbol)
    date_pattern = r"^\d{4}-\d{2}-\d{2}$"
    datetime_pattern = r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$"
    time_pattern = r"^\d{2}:\d{2}(:\d{2})?$"
    
    for value in df[!, column]
        if occursin(date_pattern, value)
            return "date"
        elseif occursin(datetime_pattern, value)
            return "datetime"
        elseif occursin(time_pattern, value)
            return "time"
        end
    end
    return "unknown"
end