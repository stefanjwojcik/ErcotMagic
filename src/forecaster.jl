## Forecaster - uses recent values to predict future values

using Flux, DotEnv, DataFrames, ProgressMeter, CUDA, ErcotMagic, Statistics
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

