using Flux, CUDA, JLD2, BSON
using Flux: mae, mse
using Random: shuffle
@assert CUDA.functional(true)

p = parse(Int, ARGS[1])
b = parse(Int, ARGS[2])

function load_data()
    global p, b
    stats, xtrain, ytrain, xtest, ytest = (nothing, nothing, nothing, nothing, nothing)
    jldopen("Data/BATCHES_$(p)_$(b).jld2", "r") do file
        stats = file["stats"]
        xtrain = file["train/xtrain"]
        ytrain = file["train/ytrain"]
        xtest = file["test/xtest"]
        ytest = file["test/ytest"]
    end
    period, batch_size, in_size, out_size = stats
    return stats, xtrain, ytrain, xtest, ytest
end

function train_loss(ŷs, ys, weights, period)
    return sum([mse(ŷs[i], ys[i]) for i in 1:period] .* weights)
end

function test_loss(model, xtest, ytest, period)
    test_ls = 0.0
    for idx in 1:length(xtest)
        Flux.reset!(model)
        test_ls += mae([model(xtest[idx][i] |> gpu) for i in 1:period][end], ytest[idx][end] |> gpu) |> cpu
    end
    test_ls = test_ls/length(xtest)
end

function baseline_loss(ytest)
    base_ls = 0.0
    for idx in 1:length(ytest)
        base_ls += mae(ytest[idx][end-1], ytest[idx][end])
    end
    return base_ls / length(ytest)
end

function train_model()
    stats, xtrain, ytrain, xtest, ytest = load_data()
    period, batch_size, in_size, out_size = stats
    weights = Float32.([i^4 for i in 1:period] ./ period^2)

    model = Chain(
        LSTM(in_size, 512),
        Dropout(0.2),
        LSTM(512, 256),
        Dropout(0.2),
        Dense(256, out_size)
    ) |> gpu
    ps = Flux.params(model)
    opt = NADAM()

    Flux.testmode!(model)
    trace = [(0, test_loss(model, xtest, ytest, period))]
    base_loss = baseline_loss(ytest)
    best_loss = Inf
    println("Epoch 0 => Avg Test Loss: $(trace[end][2]), Base Loss: $base_loss")
    for e in 1:1000
        Flux.trainmode!(model)
        for idx in shuffle(1:length(xtrain))
            Flux.reset!(model)
            gs = gradient(() -> train_loss([model(xtrain[idx][i] |> gpu) for i in 1:period], ytrain[idx] |> gpu, weights, period), ps)
            Flux.Optimise.update!(opt, ps, gs)
        end

        Flux.testmode!(model)
        push!(trace, (e, test_loss(model, xtest, ytest, period)))
        println("Epoch $e => Avg Test Loss: $(trace[end][2]), Base Loss: $base_loss")

        if trace[end][2] < best_loss
            best_loss = trace[end][2]
            let model = cpu(model)
                BSON.@save "Tests/model_$(p)_$(b).bson" model ps opt
                BSON.@save "Tests/trace_$(p)_$(b).bson" trace
            end
        end
    end
    BSON.@save "Tests/trace_$(p)_$(b).bson" trace
end

train_model()





