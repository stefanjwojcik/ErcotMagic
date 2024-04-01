## Forecaster - uses recent values to predict future values

using Flux, DotEnv, DataFrames, ProgressMeter, CUDA

DotEnv.config()

# Create a struct with experiment results 
mutable struct ExperimentResults
    model::Any
    predictions::Any
    mse::Any
end 

"""
# A Batching system for time series data
# Create batches of a time series, X is the time series, s is the sequence length, r is the step size
# If you start with a univariate time series of size 1 x T, you will get s x (T - s) / r batches
"""
function process_data(X, seq_len=60)
    # X_tr is a list of sequences of length seq_len
    X_tr = [(X[i:i+seq_len-1]) for i in 1:length(X)-seq_len]
    # Y is the next value in the time series
    Y_tr = [X[i+seq_len] for i in 1:length(X)-seq_len]
    return X_tr, Y_tr
end

##################################################

# Function to train the forecaster
function train_forecaster(model, X_tr, Y_tr, epochs)
    opt = ADAM()
    θ = Flux.params(m) # Keep track of the parameters
    for i in 1:epochs
     # Compute gradients
        ∇ = gradient(θ) do 
            # Warm up model
            model(X_tr[1])
            # Compute MSE loss on rest of sequence
            Flux.Losses.mse.([model(x) for x ∈ X_tr[2:end]], Y_tr[2:end]) |> mean
        end
    Flux.update!(opt, θ, ∇)
    end
end


##### TRAINING DATA 
## Get the data from ERCOT API and train the forecaster
params = Dict("RTDTimestampFrom" => "2024-02-01T00:00:00", 
                "RTDTimestampTo" => "2024-02-02T01:00:00",
                "settlementPoint" => "HB_NORTH")
rt_dat = get_ercot_data(params, ErcotMagic.rt_prices)
## Convert to Float32
dat_train = Float32.(rt_dat.LMP)

# Process the data
#X_train, Y_train = process_data(X_tr, seq_len)

###### VALIDATION DATA ######
## Download the next day's data for validation 
params = Dict("RTDTimestampFrom" => "2024-02-02T00:00:00", 
                "RTDTimestampTo" => "2024-02-03T01:00:00",
                "settlementPoint" => "HB_NORTH")
rt_datval = get_ercot_data(params, ErcotMagic.rt_prices)
dat_valid = Float32.(rt_datval.LMP)

### Validation data 
#X_val, Y_val = process_data(dat_valid, seq_len)

# Plot the predictions
using Plots
function plot_ts(m, X_tr, Y_tr)
    ŷ = [m(x)[1] for x ∈ X_tr]
    plot([ŷ, Y_tr], label=["Predictions" "Actuals"])
end

function finalEval(m, X_valid)
    X_val = cu.(X_valid)
    preds = [m(x)[1] for x ∈ X_val]
    mse = Flux.Losses.mse(preds, Y_val)
    return ExperimentResults(m, preds, mse)
end

######### EXPERIMENT 1: Simple Model #########

"""
Experiment 1: Simple Model
alldata = dat_train, dat_valid
seq_len = 60
expResults1 = experiment1(alldata, 60, 100)
"""
function experiment1(alldata, seq_len=60, n_epochs=10000)
    # Unpack alldata
    X_train, X_valid = alldata
    # Process the data
    X_tr, Y_tr = process_data(X_train, seq_len)
    # Create a model
    m = Chain(
        Dense(seq_len, seq_len, tanh), # Notice the k inputs
        Dense(seq_len, seq_len, tanh),
        Dense(seq_len, 1, identity)
    ) |> gpu
    # Train the model
    train_forecaster(m, cu.(X_tr), cu.(Y_tr), n_epochs)
    # predict on validation data
    X_valid, Y_valid = process_data(X_valid, seq_len)
    finalEval(m, X_valid)
end

"""
Experiment 2: Adding Mean and Standard Deviation
alldata = dat_train, dat_valid
expResults2 = experiment2(alldata, 60, 100)
"""
function experiment2(alldata, seq_len=60, n_epochs=10000)
    # Unpack alldata
    X_tr, X_val = alldata
    # Process the data
    X_tr, Y_tr = process_data(X_tr, seq_len)
    # add the moving mean and moving standard deviation by batch
    for i in 1:length(X_tr)
        push!(X_tr[i], mean(X_tr[i]))
        push!(X_tr[i], std(X_tr[i]))
    end    
    # Create a model
    m = Chain(
        Dense(seq_len + 2, seq_len + 2, tanh), # Notice the k inputs
        Dense(seq_len + 2, seq_len + 2, tanh),
        Dense(seq_len + 2, 1, identity)
    ) |> gpu
    # Generate validation data
    X_val, Y_val = process_data(X_val, seq_len)
    # add the moving mean and moving standard deviation by batch
    for i in 1:length(X_val)
        push!(X_val[i], mean(X_val[i]))
        push!(X_val[i], std(X_val[i]))
    end
    # Train the model
    train_forecaster(m, cu.(X_tr), cu.(Y_tr), n_epochs)
    finalEval(m, X_val)
end

"""
Experiment 3: Going Deeper Layers
alldata = dat_train, dat_valid
expResults3 = experiment3(alldata, 60, 100)
"""
function experiment3(alldata, seq_len=60, n_epochs=10000)
    # Unpack alldata
    X_tr, X_val = alldata
    # Process the data
    X_tr, Y_tr = process_data(X_tr, seq_len)
    # add the moving mean and moving standard deviation by batch
    for i in 1:length(X_tr)
        push!(X_tr[i], mean(X_tr[i]))
        push!(X_tr[i], std(X_tr[i]))
    end    
    # Create a model
    m = Chain(
        Dense(seq_len + 2, seq_len + 2, tanh), # Notice the k inputs
        Dense(seq_len + 2, seq_len + 2, tanh),
        Dense(seq_len + 2, seq_len + 2, tanh),
        Dense(seq_len + 2, seq_len + 2, tanh),
        Dense(seq_len + 2, 1, identity)
    ) |> gpu
    # Generate validation data
    X_val, Y_val = process_data(X_val, seq_len)
    # add the moving mean and moving standard deviation by batch
    for i in 1:length(X_val)
        push!(X_val[i], mean(X_val[i]))
        push!(X_val[i], std(X_val[i]))
    end
    # Train the model
    train_forecaster(m, cu.(X_tr), cu.(Y_tr), n_epochs)
    # predict on validation data
    finalEval(m, X_val)
end

"""
Experiment 4: Adding Regularization
"""
function experiment4(alldata, seq_len=60, n_epochs=10000)
    # Unpack alldata
    X_tr, X_val = alldata
    # Process the data
    X_tr, Y_tr = process_data(X_tr, seq_len)
    # add the moving mean and moving standard deviation by batch
    for i in 1:length(X_tr)
        push!(X_tr[i], mean(X_tr[i]))
        push!(X_tr[i], std(X_tr[i]))
    end    
    # Create a model
    m = Chain(
        Dense(seq_len + 4, seq_len + 4, tanh), # Notice the k inputs
        Dense(seq_len + 4, seq_len + 4, tanh),
        Dense(seq_len + 4, seq_len + 4, tanh),
        Dense(seq_len + 4, seq_len + 4, tanh),
        Dense(seq_len + 4, 1, identity)
    ) 
    # Generate validation data
    X_val, Y_val = process_data(X_val, seq_len)
    # add the moving mean and moving standard deviation by batch
    for i in 1:length(X_val)
        push!(X_val[i], mean(X_val[i]))
        push!(X_val[i], std(X_val[i]))
    end
    # Train the model
    train_forecaster(m, cu.(X_tr), cu.(Y_tr), n_epochs)
    # predict on validation data
    finalEval(m, X_valid, seq_len)
end
