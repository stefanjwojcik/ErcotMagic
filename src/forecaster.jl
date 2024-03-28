## Forecaster - uses recent values to predict future values

using Flux, DotEnv, DataFrames

DotEnv.config()

# Create a deep neural network that takes in a vector 500 values long and outputs a single value
# This model will be recursive in nature, taking in the last 500 values to predict the next value

function create_forecaster()
    return Chain(
        LSTM(500, 100),
        LSTM(100, 50),
        Dense(50, 1)
    )
end

# Function to train the forecaster
function train_forecaster(model, data, epochs)
    loss(x) = Flux.mse(model(x), x)
    opt = ADAM()
    for i in 1:epochs
        Flux.train!(loss, Flux.params(model), [(data,)], opt)
        ## return the loss ever 100 epochs 
        if i % 100 == 0
            println("Epoch: ", i, " Loss: ", loss(data))
        end
    end
end

## Get the data from ERCOT API
rt = get_ercot_data(Dict("RTDTimestampFrom" => "2024-02-01T00:00:00", 
                "RTDTimestampTo" => "2024-02-01T01:00:00",
                "settlementPoint" => "HB_NORTH"), ErcotMagic.rt_prices)