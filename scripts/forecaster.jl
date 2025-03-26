## Forecaster - uses recent values to predict future values
# Generates Stack, Proxy, and Congest 

using DotEnv, DataFrames, ProgressMeter, CUDA, ErcotMagic, Statistics
using MLJ, XGBoost, Dates
# disallow scalar GPU 
#DotEnv.config()

"""
Generates a surrogate price curve using the following steps:
1. Get actual load, solar, wind, and outages
2. Calculate net load by subtracting solar and wind from load 
3. Get DA price clears
"""
function surrogate_curves(startdate = today() - Day(7), enddate = today() - Day(1))

    addparams = Dict("size" => "1000000")
    ## Actual load
    actual_load = ErcotMagic.batch_retrieve_data(startdate, enddate, "ercot_actual_load", additional_params=addparams)
    ErcotMagic.add_datetime!(actual_load)
    # drop hour ending and DSTFlag 
    select!(actual_load, [:DATETIME, :Total])
    ## Get outages 
    #outages = ErcotMagic.batch_retrieve_data(startdate, enddate, "ercot_outages", additional_params=addparams)
    #ErcotMagic.add_datetime!(outages)
    #outages = ErcotMagic.filter_actuals_by_posted(outages)
    #outages.OUTAGES = outages.TotalResourceMWZoneHouston .+ outages.TotalResourceMWZoneNorth .+ outages.TotalResourceMWZoneSouth .+ outages.TotalResourceMWZoneWest
    #select!(outages, [:DATETIME, :OUTAGES])
    # Solar and Wind Generation
    solar_gen = ErcotMagic.batch_retrieve_data(startdate, enddate, "solar_system_forecast", additional_params=addparams)
    solar_actuals = ErcotMagic.filter_actuals_by_posted(solar_gen)
    select!(solar_actuals, [:DATETIME, :GenerationSystemWide])
    rename!(solar_actuals, :GenerationSystemWide => :SOLAR)
    wind_gen = ErcotMagic.batch_retrieve_data(startdate, enddate, "wind_system_forecast", additional_params=addparams)
    wind_actuals = ErcotMagic.filter_actuals_by_posted(wind_gen)
    select!(wind_actuals, [:DATETIME, :GenerationSystemWide])
    rename!(wind_actuals, :GenerationSystemWide => :WIND)
    ## Net Load = Load - Solar - Wind
    dat = innerjoin(actual_load, solar_actuals, on=:DATETIME)
    dat = innerjoin(dat, wind_actuals, on=:DATETIME)
    dat[!, :NETLOAD] = dat[!, :Total] .- dat[!, :SOLAR] .- dat[!, :WIND] 
    ## DA Lambda price clears 
    lambda_prices = ErcotMagic.batch_retrieve_data(startdate, enddate, "system_lambda", additional_params=addparams)
    ErcotMagic.add_datetime!(lambda_prices)
    select!(lambda_prices, [:DATETIME, :SystemLambda])
    dat = innerjoin(dat, lambda_prices, on=:DATETIME)
    dat.day = Date.(dat.DATETIME)
    return dat
end

"""
    ## Generate a Simple Linear Model of SystemLambda ~ NETLOAD
    # now, train the model on first 150 days, then predict the rest 
    train = dat[1:150, :]
    test = dat[151:end, :]
    model = lm(@formula(SystemLambda ~ NETLOAD), train)
    dat.pred = zeros(size(dat, 1))
    dat.pred[1:150] .= predict(model, train)
    dat.pred[151:end] .= predict(model, test)
    sort!(dat, :DATETIME)
    ## now plot the training and test set over datetime 
    plot(dat.DATETIME, [dat.SystemLambda, dat.pred], label=["actual" "predicted"], xlabel="Date", ylabel="System Clearing Price", title="Price ~ Net Load", legend=:topleft)

"""
function simple_linear_model!(dat)
    model = lm(@formula(SystemLambda ~ NETLOAD), dat)
    dat.net_load_dam_lambda_yhat = predict(model, dat)
end

#################################################
## PROXY DATA 
function get_proxy_data(;kwargs...)
    startdate = get(kwargs, :startdate, today() - Day(7))
    enddate = get(kwargs, :enddate, today() - Day(1))
    addparams = Dict("size" => "1000000")
    out = DataFrame[]
    #last_updated = ErcotMagic.get_last_updated()
    non_sced_endpoints = ErcotMagic.get_non_sced_endpoints()
    for endpoint in non_sced_endpoints
        println("Processing endpoint: ", endpoint)
        try
            dat = ErcotMagic.process_one_endpoint(startdate, enddate, endpoint, additional_params=addparams)
            # Stores the data at endpoint specific location
            push!(out, dat)
        catch e
            println("Error processing endpoint: ", endpoint)
            println(e)
        end
    end
    return out
end 


##################################################

"""
# Function to generate time series cross-validations by day
"""
function generate_time_series_cv(data, datetime_col::Symbol, n_splits=5)
    unique_days = unique(sort(data[:, datetime_col]))
    n_days = length(unique_days)
    test_days_per_split = div(n_days, n_splits)
    splits = []
    for i in 1:n_splits
        train_days = unique_days[1:test_days_per_split*(i-1)]
        test_days = unique_days[test_days_per_split*(i-1)+1:test_days_per_split*i]
        train_indices = findall(row -> row[datetime_col] in train_days, data)
        test_indices = findall(row -> row[datetime_col] in test_days, data)
        push!(splits, (train_indices, test_indices))
    end
    return splits
end

##################################################

"""
# Function to train an XGBoost regression model
"""
function train_xgboost_regression(X_train, y_train, X_val, y_val)
    model = @load XGBoostRegressor verbosity=0
    mach = machine(model, X_train, y_train)
    fit!(mach)
    y_pred = predict(mach, X_val)
    mse = mean((y_pred .- y_val).^2)
    return mach, y_pred, mse
end

##################################################

"""
# Function to train an XGBoost classification model
"""
function train_xgboost_classification(X_train, y_train, X_val, y_val)
    model = @load XGBoostClassifier verbosity=0
    mach = machine(model, X_train, y_train)
    fit!(mach)
    y_pred = predict(mach, X_val)
    accuracy = mean(y_pred .== y_val)
    return mach, y_pred, accuracy
end

##################################################

"""
# Function to backtest the model
"""
function backtest_model(data, target_col::Symbol, datetime_col::Symbol, model_type=:regression, n_splits=5)
    cv_splits = generate_time_series_cv(data, datetime_col, n_splits)
    metrics = []
    for (train_idx, val_idx) in cv_splits
        X_train = data[train_idx, Not(target_col)]
        y_train = data[train_idx, target_col]
        X_val = data[val_idx, Not(target_col)]
        y_val = data[val_idx, target_col]
        
        if model_type == :regression
            mach, y_pred, mse = train_xgboost_regression(X_train, y_train, X_val, y_val)
            push!(metrics, mse)
        elseif model_type == :classification
            mach, y_pred, accuracy = train_xgboost_classification(X_train, y_train, X_val, y_val)
            push!(metrics, accuracy)
        end
    end
    return metrics
end