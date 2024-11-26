## Post-processing the data 

#create three config subtypes: 

# datekey + HourEnding to get the datetime - da prices 
# datekey + DeliveryHour + DeliveryInterval - rt prices 
# datekey + HourEnding - ercot load forecast (need to stack by model) (need to filter by Posted DateTime)
# datekey + HourEnding - ercot load actuals 
# datekey + OperatingDate + HourEnding - ercot outages (need to filter by Posted DateTime) (The total outage column is TotalResource*)
# 


function add_datetime!(df::DataFrame, endpoint::String)
    datekey, url = ErcotMagic.ENDPOINTS[endpoint]
    if datekey == "intervalEnding"
        df.DATETIME = DateTime.(df[!, :IntervalEnding])
    elseif datekey == "operatingDate"
        df.DATETIME = DateTime.(df[!, :OperatingDate]) .+ Hour.(df[!, :HourEnding])
    elseif datekey == "deliveryDate" && endpoint == "rt_prices"
        df.DATETIME = DateTime.(df[!, :DeliveryDate]) .+ Hour.(df[!, :DeliveryHour]) .+ Minute.(df[!, :DeliveryInterval] .* 5)
    else
        df.DATETIME = DateTime.(df[!, :DeliveryDate]) .+ Hour.(df[!, :HourEnding])
    end
end

function add_datetime!(df::DataFrame, datekey::String, hourkey::String, intervalkey::String)
    df.DATETIME = Dates.DateTime.(df[datekey]) .+ Hour.(df[hourkey]) .+ Minute.(df[intervalkey] .* 5)
    return df
end
