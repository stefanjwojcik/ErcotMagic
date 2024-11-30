## Forecaster - uses recent values to predict future values

using DotEnv, DataFrames, ProgressMeter, CUDA, ErcotMagic, Statistics
using MLJ, XGBoost, Dates
# disallow scalar GPU 
#DotEnv.config()

function surrogate_curves()
    
    startdate = today() - Day(7)
    enddate = today() - Day(1)

    addparams = Dict("size" => "1000000")
    ## Actual load
    actual_load = ErcotMagic.batch_retrieve_data(startdate, enddate, "ercot_actual_load", additional_params=addparams)
    ErcotMagic.add_datetime!(actual_load)
    # drop hour ending and DSTFlag 
    select!(actual_load, [:DATETIME, :Total])
    ## Get outages 
    outages = ErcotMagic.batch_retrieve_data(startdate, enddate, "ercot_outages", additional_params=addparams)
    ErcotMagic.add_datetime!(outages)
    outages = ErcotMagic.filter_actuals_by_posted(outages)
    outages.OUTAGES = outages.TotalResourceMWZoneHouston .+ outages.TotalResourceMWZoneNorth .+ outages.TotalResourceMWZoneSouth .+ outages.TotalResourceMWZoneWest
    select!(outages, [:DATETIME, :OUTAGES])
    # Solar and Wind Generation
    solar_gen = ErcotMagic.batch_retrieve_data(startdate, enddate, "solar_system_forecast", additional_params=addparams)
    solar_actuals = ErcotMagic.filter_actuals_by_posted(solar_gen)
    select!(solar_actuals, [:DATETIME, :GenerationSystemWide])
    rename!(solar_actuals, :GenerationSystemWide => :SOLAR)
    wind_gen = ErcotMagic.batch_retrieve_data(startdate, enddate, "wind_system_forecast", additional_params=addparams)
    wind_actuals = ErcotMagic.filter_actuals_by_posted(wind_gen)
    select!(wind_actuals, [:DATETIME, :GenerationSystemWide])
    rename!(wind_actuals, :GenerationSystemWide => :WIND)
    ## Net Load = Load - Solar - Wind - Outages
    dat = innerjoin(actual_load, solar_actuals, on=:DATETIME)
    dat = innerjoin(dat, wind_actuals, on=:DATETIME)
    dat = innerjoin(dat, outages, on=:DATETIME)
    dat[!, :NETLOAD] = dat[!, :Total] .- dat[!, :SOLAR] .- dat[!, :WIND] 
    ## DA price clears 
    lambda_prices = ErcotMagic.batch_retrieve_data(startdate, enddate, "system_lambda", additional_params=addparams)
    ErcotMagic.add_datetime!(lambda_prices)
    select!(lambda_prices, [:DATETIME, :SystemLambda])
    ## RT price clears
    #rtprices = ErcotMagic.batch_retrieve_data(startdate, enddate, "rt_prices", additional_params=addparams)
    #ErcotMagic.add_datetime!(rtprices)
    #select!(rtprices, [:DATETIME, :SettlementPoint, :SettlementPointPrice])
    #rename!(rtprices, :SettlementPointPrice => :RTPRICE)
    dat = innerjoin(dat, lambda_prices, on=:DATETIME)
    dat.day = Date.(dat.DATETIME)

end

"""
## Function to generate realized price curves 
- takes start date, enddate, and additional parameters
-get actual load, solar, wind, system_lambda
- calculate actual net load 

"""
function realized_curves(; kwargs...)
    forecast_endpoints = ["solar_system_forecast", "wind_system_forecast"]
    startdate = today() - Day(7)
    enddate = today() - Day(1)
    addparams = Dict("size" => "1000000")
    ## Actual load
    actual_load = ErcotMagic.batch_retrieve_data(startdate, enddate, "ercot_actual_load", additional_params=addparams)
    ## System Lambda 
    lambda_prices = ErcotMagic.batch_retrieve_data(startdate, enddate, "system_lambda", additional_params=addparams)
    ErcotMagic.add_datetime!.([actual_load, lambda_prices])
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