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


function add_datetime!(df::DataFrame, endpoint::String)
    datekey, url = ErcotMagic.ENDPOINTS[endpoint]
    if datekey == "intervalEnding"
        df.DATETIME = DateTime.(df[!, :IntervalEnding])
    elseif datekey == "operatingDate"
        df.DATETIME = DateTime.(df[!, :OperatingDate]) .+ Hour.(df[!, :HourEnding])
    elseif datekey == "deliveryDate" && endpoint == "rt_prices"
        df.DATETIME = DateTime.(df[!, :DeliveryDate]) .+ Hour.(df[!, :DeliveryHour]) .+ Minute.(df[!, :DeliveryInterval] .* 5)
    else
        df.DATETIME = parse_hour_ending.(DateTime.(df[!, "DeliveryDate"]), df[!, :HourEnding])
    end
end

function add_datetime!(df::DataFrame, datekey::String, hourkey::String, intervalkey::String)
    df.DATETIME = Dates.DateTime.(df[datekey]) .+ Hour.(df[hourkey]) .+ Minute.(df[intervalkey] .* 5)
    return df
end
