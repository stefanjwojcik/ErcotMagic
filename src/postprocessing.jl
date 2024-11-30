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
# Alternative datetime version that is simpler 
"""
function add_datetime!(df::DataFrame)
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
    end
end

"""
# Filter by Posted or PostedDateTime for Forecast data in order to get the latest forecast
"""
function filter_forecast_by_posted(df::DataFrame, days_back=1)
    if "DATETIME" ∉ names(df)
        @warn "No DATETIME column in the DataFrame, attempting to add"
        add_datetime!(df)
    end
    if "Posted" ∈ names(df)
        df = filter(row -> DateTime(row.Posted) .<= (row.DATETIME - Day(days_back)) , df)
        # Now, group by the DATETIME and get the latest forecast
        df = combine(groupby(df, :DATETIME), val -> first(val, 1))
        nrow(df) == 0 && @warn "No data found for the specified date range"
        return df
    end
end

"""
# Filter by Posted or PostedDateTime for Forecast data in order to get actuals 

ssf = ErcotMagic.batch_retrieve_data(today() - Day(7), today() - Day(1), "solar_system_forecast")
hi = ErcotMagic.filter_forecast_by_posted(ssf)
"""
function filter_actuals_by_posted(df::DataFrame, days_back=1)
    if "DATETIME" ∉ names(df)
        @warn "No DATETIME column in the DataFrame, attempting to add"
        add_datetime!(df)
    end
    if "Posted" ∈ names(df)
        df = filter(row -> DateTime(row.Posted) .>= row.DATETIME, df)
        # Now, group by the DATETIME and get the latest forecast
        df = combine(groupby(df, :DATETIME), val -> first(val, 1))
        nrow(df) == 0 && @warn "No data found for the specified date range"
        return df
    end
end
