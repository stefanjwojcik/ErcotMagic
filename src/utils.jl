### Load ERCOT Data for Forecasting and Training

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


## Post-processing the data 

#create three config subtypes: 

# datekey + HourEnding to get the datetime - da prices 
# datekey + DeliveryHour + DeliveryInterval - rt prices 
# datekey + HourEnding - ercot load forecast (need to stack by model) (need to filter by Posted DateTime)
# datekey + HourEnding - ercot load actuals 
# datekey + OperatingDate + HourEnding - ercot outages (need to filter by Posted DateTime) (The total outage column is TotalResource*)
# 
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
    elseif "SCEDTimestamp" ∈ names(df)
        df.DATETIME = DateTime.(df[!, "SCEDTimestamp"])
        return
    else
        @warn "No datetime columns found in the DataFrame"
        return
    end
end

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
        data = data #ErcotMagic.stack_and_label(data, endpoint)
    end
    ## 
    return data
end

################# FILTERING FUNCTIONS ####################

"""
# Filter by Posted or PostedDateTime for Forecast data in order to get the latest forecast
"""
function filter_forecast_by_posted(df::DataFrame, days_back=1)
    if "DATETIME" ∉ names(df)
        @warn "No DATETIME column in the DataFrame, attempting to add"
        add_datetime!(df)
    end
    if "Posted" ∈ names(df) && sum(ismissing, df.Posted) == 0
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

######### SCED UTILITY FUNCTIONS  


"""
### Bulk downloading pure SCED AS Load Data 
as_data = ErcotMagic.SCED_as()
ErcotMagic.normalize_columnames!(as_data)
"""
function SCED_load_as(; kwargs...)
    from = get(kwargs, :from, today() - Dates.Day(89) )
    to = get(kwargs, :to, from + Dates.Day(2))
    params = Dict("deliveryDateFrom" => string(from), 
                "deliveryDateTo" => string(to), 
                "size" => "1000000") #  
    get_ercot_data(params, ErcotMagic.sced_load_as)
end

function SCED_gen_as(; kwargs...)
    from = get(kwargs, :from, today() - Dates.Day(89) )
    to = get(kwargs, :to, from + Dates.Day(2))
    params = Dict("deliveryDateFrom" => string(from), 
                "deliveryDateTo" => string(to), 
                "size" => "1000000") #  
    get_ercot_data(params, ErcotMagic.sced_gen_as)
end

### Bulk downloading pure Generation Resource SCED  data 
function SCED_gen_data(; kwargs...)
    from = get(kwargs, :from, today() - Dates.Day(89) )
    to = get(kwargs, :to, from + Dates.Day(2))
    resourceName = get(kwargs, :resourceName, "NOBLESLR_SOLAR1")
    addparams = get(kwargs, :addparams, Dict())
    params = Dict("size" => "1000000", 
                "SCEDTimestampFrom" => string(DateTime(from)),
                "SCEDTimestampTo" => string(DateTime(to)),
                "resourceName" => resourceName,
                #"resourceType" => "PVGR", 
                #"submittedTPOPrice1From" => "-40", # wind comes at -40
                #"submittedTPOPrice1To" => "4000", 
                #"submittedTPOMW1From" => "2", #minimum volumetric bid 
                #"submittedTPOMW1To" => "10000"
    ) 
    merge!(params, addparams)
    get_ercot_data(params, ErcotMagic.sced_gen_data)
end

"""
# Bulk downloads SCED data (it's only available after 60 days, and 30 days are posted at a time)
## Focuses on on-peak offers (he 7-22)
"""
function update_sced_data()
    ## starting Date(today()) - Dates.Day(89)
    startdate = Date(today()) - Dates.Day(89)
    enddate = Date(today()) - Dates.Day(60)
    @showprogress for offerday in startdate:enddate
        try
            ## does this data exist? if so skip
            isfile("data/SCED_gen_data_"*string(offerday)*".csv") && continue
            dat = SCED_gen_data(from=DateTime(offerday) + Dates.Hour(7), 
                            to=DateTime(offerday)+Dates.Hour(22))
            dat = ErcotMagic.nothing_to_missing.(dat)
            CSV.write("data/SCED_gen_data_"*string(offerday)*".csv", dat)
        catch e
            println("Error on date: ", i)
            println(e)
        end
    end
end

"""
# Function takes in on-peak SCED data, obtains the average price for the first segment by resource 
"""
function average_sced_prices(dat)
    ## Remove spaces from the column names
    dat = rename(dat, replace.(names(dat), " " => "_"))
    ## Remove dashes from the column names
    dat = rename(dat, replace.(names(dat), "-" => "_"))
    ## group by Resource_Name, Resource_Type,  
    dat = combine(groupby(dat, [:Resource_Name, :Resource_Type, :HSL]), :Submitted_TPO_Price1 => mean)
    return dat
end

"""
# Function takes in on-peak SCED data, obtains the average MW's across all TPO segments
"""
function average_sced_mws(dat)
    # lambda function to deal with nothing values 
    ## Remove spaces from the column names
    dat = rename(dat, replace.(names(dat), " " => "_"))
    ## Remove dashes from the column names
    dat = rename(dat, replace.(names(dat), "-" => "_"))
    # Add all TPO MW's together
    datmw = select(dat, r"Submitted_TPO_MW")
    datmw = nothing_to_zero.(datmw)
    # get rowwise max of tpo cols 
    dat.total_TPO_MW = maximum.(eachrow(datmw))
    ## group by Resource_Name, Resource_Type,  
    dat = combine(groupby(dat, [:Resource_Name, :Resource_Type, :HSL]), :total_TPO_MW => mean)
    return dat
end

function DA_energy_offers(; kwargs...)
    # From/To Dates are individual days
    from = get(kwargs, :from, Date(today()) - Dates.Day(89) )
    to = get(kwargs, :to, from + Dates.Day(1))
    onpeak = get(kwargs, :onpeak, true)
    if onpeak
        hefrom = 7
        heto = 22
    else
        hefrom = 0
        heto = 24
    end
    params = Dict("deliveryDateFrom" => string(from), 
                "deliveryDateTo" => string(to), 
                "hourEndingFrom" => string(hefrom),
                "hourEndingTo" => string(heto),
                "size" => "1000000", 
                "energyOnlyOfferMW1From" => "5", 
                "energyOnlyOfferMW1To" => "10000",
                "energyOnlyOfferPrice1From" => "-40",
                "energyOnlyOfferPrice1To" => "4000")
    get_ercot_data(params, ErcotMagic.sixty_dam_energy_only_offers)
end

"""
# Function to update the DA offer data
## Focuses on on-peak offers (he 7-22)

DEPRECATED
"""
function update_da_offer_data()
    ## starting Date(today()) - Dates.Day(89)
    startdate = Date(today()) - Dates.Day(89)
    enddate = Date(today()) - Dates.Day(60)
    @showprogress for offerday in startdate:enddate
        try
            # check if already exists 
            isfile("data/DA_energy_offers_"*string(offerday)*".csv") && continue
            dat = DA_energy_offers(from=offerday, to=offerday+Dates.Day(1), onpeak=true)
            #transform nothing to missing 
            dat = ErcotMagic.nothing_to_missing.(dat)
            CSV.write("data/DA_energy_offers_"*string(offerday)*".csv", dat)
        catch e
            println("Error on date: ", offerday)
            println(e)
        end
    end
end

function average_da_mws(dat)
    dat = rename(dat, replace.(names(dat), " " => "_"))
    ## Remove dashes from the column names
    dat = rename(dat, replace.(names(dat), "-" => "_"))
    # Add all TPO MW's together
    datmw = select(dat, r"Energy_Only_Offer_MW")
    datmw = coalesce.(datmw, 0.0)
    # get rowwise max of tpo cols 
    dat.avg_max_DA_mw_offer = maximum.(eachrow(datmw))
    ## group by Resource_Name, Resource_Type,  
    dat = combine(groupby(dat, [:Settlement_Point, :QSE]), :avg_max_DA_mw_offer => mean)
end
