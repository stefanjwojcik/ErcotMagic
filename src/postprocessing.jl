## Post-processing the data 

#create three config subtypes: 

# datekey + HourEnding to get the datetime - da prices 
# datekey + DeliveryHour + DeliveryInterval - rt prices 
# datekey + HourEnding - ercot load forecast (need to stack by model) (need to filter by Posted DateTime)
# datekey + HourEnding - ercot load actuals 
# datekey + OperatingDate + HourEnding - ercot outages (need to filter by Posted DateTime) (The total outage column is TotalResource*)
# 

"""
## Remove alternative datetime columns 
- Removes the alternative datetime columns from the DataFrame
- Adds 'Posted' column if not present 
"""
function standardize_datetime_cols!(df::DataFrame)
    alt_date_cols = ["DeliveryDate", "DeliveryHour", "DeliveryInterval", "IntervalEnding", "OperatingDay", "OperatingDate", "HourEnding", "SCEDTimestamp"]
    for col in alt_date_cols
        if col ∈ names(df)
            select!(df, Not(col))
        end
    end
    if "Posted" ∉ names(df)
        df.Posted .= missing
    end
    if "DSTFlag" ∉ names(df)
        df.DSTFlag .= missing
    end
    nothing
end

"""
# Postprocess the endpoint data
actual_load = ErcotMagic.batch_retrieve_data(today() - Day(7), today() - Day(1), "ercot_actual_load")
ErcotMagic.postprocess_endpoint_data!(actual_load)

ssf = ErcotMagic.batch_retrieve_data(today() - Day(7), today() - Day(1), "solar_system_forecast")
ErcotMagic.postprocess_endpoint_data!(ssf)
"""
function postprocess_endpoint_data!(df::DataFrame)
    normalize_columnnames!(df)
    add_datetime!(df)
    standardize_datetime_cols!(df)
    nothing
end

## DEPRECATED 
function stack_and_label(df::DataFrame, endpoint::String; id_cols = Not([:DATETIME, :Posted, :DSTFlag]))
    @assert "DATETIME" ∈ names(df) "DATETIME column not found in the DataFrame"
    df = stack(df, id_cols)
    df.endpoint .= endpoint
    return df
end

"""
## Function to process one endpoint - get and standardize the data

addparams = Dict("size" => "1000000")
actual_load = ErcotMagic.process_one_endpoint(startdate, enddate, "ercot_actual_load", additional_params=addparams)

ssf = ErcotMagic.process_one_endpoint(startdate, enddate, "solar_system_forecast", additional_params=addparams)

constraints = ErcotMagic.process_one_endpoint(startdate, enddate, "binding_constraints", additional_params=addparams)

"""
function process_one_endpoint(startdate::Date, enddate::Date, endpoint::String; additional_params::Dict=Dict())
    data = ErcotMagic.batch_retrieve_data(startdate, enddate, endpoint, additional_params=additional_params)
    ErcotMagic.postprocess_endpoint_data!(data) ## standardize dates
    actuals, forecasts = ErcotMagic.actuals_and_forecasts(data) # cleaves actuals and forecast values 
    ## Actuals and forecasts are not nothing, then "stack and label" 
    if !isnothing(actuals) && !isnothing(forecasts)
        actuals = ErcotMagic.stack_and_label(actuals, endpoint .* "_actuals")
        forecasts = ErcotMagic.stack_and_label(forecasts, endpoint .* "_forecasts")
        data = vcat(actuals, forecasts)
    else 
        # Stack the values on top and label by the endpoint 
        data = ErcotMagic.stack_and_label(data, endpoint)
    end
    ## 
    return data
end

################# FILTERING FUNCTIONS ####################

"""
# Filter by Posted or PostedDateTime for Forecast data in order to get the latest forecast

date = Date(2024, 2, 1) 
dat = ErcotMagic.get_data(ErcotMagic.solar_system_forecast, date; postedDatetimeTo="2024-02-01T00:00:00") 
dat |> 
    ErcotMagic.normalize_columnnames! |> 
    ErcotMagic.add_datetime! 


"""
function filter_forecast_by_posted(df::DataFrame, days_back=1, morninghour=7)
    if "DATETIME" ∉ names(df)
        @warn "No DATETIME column in the DataFrame, attempting to add"
        add_datetime!(df)
    end
    if "Posted" ∈ names(df) && sum(ismissing, df.Posted) == 0
        df = filter(row -> DateTime(row.Posted) .<= (row.DATETIME - Day(days_back) + Hour(morninghour)) , df)
        # Now, group by the DATETIME and get the latest forecast
        df = combine(groupby(df, :DATETIME), val -> first(val, 1))
        nrow(df) == 0 && @warn "No data found for the specified date range"
        return df
    end
end

"""
# Filter by Posted or PostedDateTime for Forecast data in order to get actuals 

ssf = ErcotMagic.batch_retrieve_data(today() - Day(7), today() - Day(1), "solar_system_forecast")
hi = ErcotMagic.filter_actuals_by_posted(ssf)
"""
function filter_actuals_by_posted(df::DataFrame, days_back=1)
    if "DATETIME" ∉ names(df)
        @warn "No DATETIME column in the DataFrame, attempting to add"
        add_datetime!(df)
    end
    if "Posted" ∈ names(df) && sum(ismissing, df.Posted) == 0
        df = filter(row -> DateTime(row.Posted) .>= row.DATETIME, df)
        # Now, group by the DATETIME and get the latest forecast
        df = combine(groupby(df, :DATETIME), val -> first(val, 1))
        nrow(df) == 0 && @warn "No data found for the specified date range"
        return df
    else 
        return nothing 
    end
end

"""
# Filter the DataFrame to get the actuals and forecasts
actual_load = ErcotMagic.batch_retrieve_data(today() - Day(7), today() - Day(1), "ercot_actual_load")
a, f = ErcotMagic.actuals_and_forecasts(actual_load)

ssf = ErcotMagic.batch_retrieve_data(today() - Day(7), today() - Day(1), "solar_system_forecast")
a, f = ErcotMagic.actuals_and_forecasts(ssf)
"""
function actuals_and_forecasts(df::DataFrame)
    forecasts, actuals = filter_forecast_by_posted(df), filter_actuals_by_posted(df)
    if any(isnothing, [forecasts, actuals])
        return nothing, nothing 
    else
        return actuals, forecasts
    end
end