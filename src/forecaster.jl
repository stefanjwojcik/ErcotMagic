## Forecaster - uses recent values to predict future values

using DotEnv, DataFrames, ProgressMeter, CUDA, ErcotMagic, Statistics
using MLJ, XGBoost
# disallow scalar GPU 
DotEnv.config()

function load_da_example()
    ## GET DA LMP for HB_NORTH
    da_dat = ErcotMagic.series_long(Date(2023, 12, 11), Date(2024, 10, 12), settlementPoint="HB_NORTH", series=ErcotMagic.da_prices, hourly_avg=false)
    rename!(da_dat, Dict(:SettlementPointPrice => :DALMP))
    da_dat.DATETIME = Dates.DateTime.(da_dat.DeliveryDate) .+ Hour.(parse_hour_ending_string.(da_dat.HourEnding))

    return da_dat
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