## Forecaster - uses recent values to predict future values

using Flux, DotEnv, DataFrames, ProgressMeter, CUDA, ErcotMagic, Statistics
using MLJ, XGBoost
# disallow scalar GPU 
CUDA.allowscalar(false)

DotEnv.config()

# Create a struct with experiment results 
mutable struct ExperimentResults
    model::Any
    predictions::Any
    mse::Any
end 

"""
#usage 
X = [1, 2, 3, 4, 5]
bnorm = batch_normalize(X)
"""
function batch_normalize(X)
    X = (X .- mean(X)) ./ std(X)
end

"""
X = [1, 2, 3, 4, 5]
bnorm = batch_normalize(X)
bdenorm = batch_denormalize(bnorm, mean(X), std(X))
"""
function batch_denormalize(X)
    X = X .* std(X) .+ mean(X)
end


"""
# A Batching system for time series data
# Create batches of a time series, X is the time series, s is the sequence length, r is the step size
# If you start with a univariate time series of size 1 x T, you will get s x (T - s) / r batches
"""
function process_data(Xraw, seq_len=60, normalize=false)
    # X_tr is a list of sequences of length seq_len
    X = [(Xraw[i:i+seq_len-1]) for i in 1:length(Xraw)-seq_len]
    # Y is the next value in the time series
    Y = [Xraw[i+seq_len] for i in 1:length(Xraw)-seq_len]
    if normalize
        X = [batch_normalize(x) for x in X]
    end
    return X, Y
end

##################################################

"""
# Function to train the forecaster
# model: The model to train
m = Chain(
    Dense(seq_len, seq_len, tanh), # Notice the k inputs
    Dense(seq_len, seq_len, tanh),
    Dense(seq_len, 1, identity)
) |> gpu
X_tr, Y_tr = process_data(dat_train, 60, true)
train_forecaster(m, cu.(X_tr), cu.(Y_tr), 10, 0.0)
"""
function train_forecaster(model, X_tr, Y_tr, epochs, penalty_weight=0.0)
    opt = ADAM()
    penalty() = [sum(abs2, m.weight) + sum(abs2, m.bias) for m in model.layers[1:end-1]] |> sum
    θ = Flux.params(model) # Keep track of the parameters
    @showprogress for i in 1:epochs
     # Compute gradients
        ∇ = gradient(θ) do 
            # Warm up model
            model(X_tr[1])
            # Compute MSE loss on rest of sequence
            if penalty == 0.0
                Flux.Losses.mse.([model(x) for x ∈ X_tr[2:end]], Y_tr[2:end]) |> mean
            else
                (Flux.Losses.mse.([model(x) for x ∈ X_tr[2:end]], Y_tr[2:end]) |> mean) + penalty() * penalty_weight
            end
        end
    Flux.update!(opt, θ, ∇)
    end
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