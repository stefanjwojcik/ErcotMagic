## Experiments:: 

# Plot the predictions
using Plots
include("src/forecaster.jl")

"""
## Recipe for plotting ExperimentResults 
plot(expResults1, Y_val)
"""
@recipe function f(er::ExperimentResults, actuals, invtransform=nothing)
    # Get the predictions
    preds = first.(cpu(er.predictions))
    # Inverse transform the predictions
    if invtransform != nothing
        preds = invtransform.(preds)
    end
    ## Plot the predictions
    time = 1:length(preds)
    label --> ["Predictions" "Actuals"]
    return time, [preds, actuals]
end

"""
# Function to evaluate the model
# m: The model
m = Chain(
    Dense(seq_len, seq_len, tanh), # Notice the k inputs
    Dense(seq_len, 1, identity)
) |> gpu
train_forecaster(m, cu.(X_tr), cu.(Y_tr), 10)
X_val, Y_val = process_data(dat_valid, 60)
finalEval(m, X_val, Y_val)
"""
function finalEval(m, X_val, Y_val, normalize=false)
    if normalize
        X_val = [batch_normalize(x) for x in X_val]
    end
    X_val, Y_val = cu.(X_val), cu.(Y_val)
    preds = m.(X_val)
    mse = Flux.Losses.mse(first.(cpu(preds)), Y_val)
    return ExperimentResults(m, preds, mse)
end

######### EXPERIMENT 0: Simple Model/No Transformation #########
"""
Experiment 0: Simple Model
alldata = dat_train, dat_valid
seq_len = 60
expResults0 = experiment0(alldata, 60, 200, 0.0, true)
p0 = plot(expResults0, Y_val)
"""
function experiment0(alldata, seq_len=60, n_epochs=1000, penalty=0.0, normalize=true)
    # Unpack alldata
    X_train, X_valid = alldata
    # Process the data
    X_tr, Y_tr = process_data(X_train, seq_len, normalize)
    # Create a model
    m = Chain(
        Dense(seq_len, 30, tanh), # Notice the k inputs
        Dense(30, 30, tanh),
        Dense(30, 1, identity)
    ) |> gpu
    # Train the model
    train_forecaster(m, cu.(X_tr), cu.(Y_tr), n_epochs, penalty)
    # predict on validation data
    X_valid, Y_valid = process_data(X_valid, seq_len, normalize)
    finalEval(m, X_valid, Y_valid, normalize)
end


######### EXPERIMENT 1: Simple Model #########

"""
Experiment 1: Simple Model
alldata = asinh.(dat_train), asinh.(dat_valid)
seq_len = 60
expResults1 = experiment1(alldata, 60, 1000, 0.0, true)
p1 = plot(expResults1, Y_val, sinh)
"""
function experiment1(alldata, seq_len=60, n_epochs=1000, penalty=0.0, normalize=true)
    # Unpack alldata
    X_train, X_valid = alldata
    # Process the data
    X_tr, Y_tr = process_data(X_train, seq_len, normalize)
    # Create a model
    m = Chain(
        Dense(seq_len, 30, tanh), # Notice the k inputs
        Dense(30, 30, tanh),
        Dense(30, 1, identity)
    ) |> gpu
    # Train the model
    train_forecaster(m, cu.(X_tr), cu.(Y_tr), n_epochs, penalty)
    # predict on validation data
    X_valid, Y_valid = process_data(X_valid, seq_len, normalize)
    finalEval(m, X_valid, Y_valid, normalize)
end

"""
Experiment 2: Adding Mean and Standard Deviation
alldata = dat_train, dat_valid
expResults2 = experiment2(alldata, 60, 100, 0.0)
p2 = plot(expResults2, Y_val)
"""
function experiment2(alldata, seq_len=60, n_epochs=100, penalty=0.0, normalize=true)
    # Unpack alldata
    X_trainraw, X_valraw = alldata
    # Process the data
    X_tr, Y_tr = process_data(X_trainraw, seq_len, normalize)
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
    X_val, Y_val = process_data(X_valraw, seq_len, normalize)
    # add the moving mean and moving standard deviation by batch
    for i in 1:length(X_val)
        push!(X_val[i], mean(X_val[i]))
        push!(X_val[i], std(X_val[i]))
    end
    # Train the model
    train_forecaster(m, cu.(X_tr), cu.(Y_tr), n_epochs, penalty)
    finalEval(m, X_val, Y_val)
end

"""
Experiment 3: Going Deeper Layers
alldata = dat_train, dat_valid
expResults3 = experiment3(alldata, 60, 100)
p3 = plot(expResults3, Y_val)
"""
function experiment3(alldata, seq_len=60, n_epochs=10000, penalty=0.0, normalize=true)
    # Unpack alldata
    X_tr, X_val = alldata
    # Process the data
    X_tr, Y_tr = process_data(X_tr, seq_len, normalize)
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
    X_val, Y_val = process_data(X_val, seq_len, normalize)
    # add the moving mean and moving standard deviation by batch
    for i in 1:length(X_val)
        push!(X_val[i], mean(X_val[i]))
        push!(X_val[i], std(X_val[i]))
    end
    # Train the model
    train_forecaster(m, cu.(X_tr), cu.(Y_tr), n_epochs)
    # predict on validation data
    finalEval(m, X_val, Y_val)
end

"""
Experiment 4: Adding Regularization
alldata = dat_train, dat_valid
expResults4 = experiment4(alldata, 60, 100, 5.1)
p4 = plot(expResults4, Y_val)
"""
function experiment4(alldata, seq_len=60, n_epochs=10000, penalty=0.1, normalize=true)
    # Unpack alldata
    X_tr, X_val = alldata
    # Process the data
    X_tr, Y_tr = process_data(X_tr, seq_len, normalize)
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
    X_val, Y_valid = process_data(X_val, seq_len, normalize)
    # add the moving mean and moving standard deviation by batch
    for i in 1:length(X_val)
        push!(X_val[i], mean(X_val[i]))
        push!(X_val[i], std(X_val[i]))
    end
    # Train the model
    train_forecaster(m, cu.(X_tr), cu.(Y_tr), n_epochs, penalty)
    # predict on validation data
    finalEval(m, X_val, Y_valid)
end


"""
Experiment 5: Hyperbolic Sine Transformation
alldata = asinh.(dat_train), asinh.(dat_valid)
expResults5 = experiment5(alldata, 60, 400, 0.1)
p5 = plot(expResults5, Y_val)
"""
function experiment5(alldata, seq_len=60, n_epochs=10000, penalty=0.1, normalize=true)
    # Unpack alldata
    X_tr, X_val = alldata
    # Process the data
    X_tr, Y_tr = process_data(X_tr, seq_len, normalize)
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
        Dense(seq_len + 2, 1, identity)
    ) |> gpu
    # Generate validation data
    X_val, Y_valid = process_data(X_val, seq_len, normalize)
    # add the moving mean and moving standard deviation by batch
    for i in 1:length(X_val)
        push!(X_val[i], mean(X_val[i]))
        push!(X_val[i], std(X_val[i]))
    end
    # Train the model
    train_forecaster(m, cu.(X_tr), cu.(Y_tr), n_epochs, penalty)
    # predict on validation data
    finalEval(m, X_val, Y_valid)
end
