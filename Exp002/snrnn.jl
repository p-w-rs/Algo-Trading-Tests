using Flux, JLD2, CUDA, ProgressMeter, Random

const device = CUDA.functional() ? gpu : cpu
const inputsize = 7+6

@info "Running model on $device"

function lecun_normal(rng::AbstractRNG, dims::Integer...; gain::Real=1)
  std = Float32(gain) * sqrt(1f0 / sum(Flux.nfan(dims...)))
  randn(rng, Float32, dims...) .* std
end
lecun_normal(dims::Integer...; kwargs...) = lecun_normal(Flux.default_rng_value(), dims...; kwargs...)
lecun_normal(rng::AbstractRNG=Flux.default_rng_value(); init_kwargs...) = (dims...; kwargs...) -> lecun_normal(rng, dims...; init_kwargs..., kwargs...)

Flux.ChainRulesCore.@non_differentiable lecun_normal(::Any...)

function load_data(name, poollength, horizon, batchsize, tbatchsize)
    input, target = (nothing, nothing)
    jldopen("nnDATA/$name-$poollength-$horizon.jld2", "r") do f
        input = f["input"] 
        target = f["target"]
    end
    N = size(input, 3)
    idxs = shuffle(1:N)
    test_idxs = idxs[1:div(N, 10)]
    train_idxs = idxs[div(N, 10)+1:end]
    return (
        Flux.DataLoader(
            (data=input[:, :, train_idxs], label=target[:, train_idxs]),
            batchsize=batchsize, shuffle=true
        ),
        Flux.DataLoader(
            (data=input[:, :, test_idxs], label=target[:, test_idxs]),
            batchsize=tbatchsize, shuffle=true
        )
    )
end

function create_model()
    return Chain(
        Dense(inputsize => 64, selu; init=lecun_normal),
        Dense(inputsize => 32, selu; init=lecun_normal),
        Dense(inputsize => 16, selu; init=lecun_normal),
        Dense(inputsize => 8, selu; init=lecun_normal),
        Dense(64 => 1, identity; init=lecun_normal)
    ) |> device
end

# MSE loss
function loss(model, xs, y)
    ŷ = [model(xs[i, :, :] |> device) for i in 1:size(xs, 1)][end]
    return sum(abs.(tanh.(ŷ) .- (y |> device)))
end

function train(nepochs, train_loader, test_loader, name)
    model = create_model()
    ps = Flux.params(model)
    opt = AMSGrad()
    errors = zeros(nepochs, 2)
    ysVys = []
    for epoch in 1:nepochs
        Flux.trainmode!(model)
        err = 0
        @showprogress for (xs, y) in train_loader
            Flux.reset!(model)
            l = loss(model, xs, y)
            grads = gradient(() -> l, ps)
            Flux.Optimise.update!(opt, ps, grads)
            err += (l |> cpu) / size(y, 2)
        end
        err /= length(train_loader)
        errors[epoch, 1] = err

        err = 0
        ŷs = nothing
        ys = nothing
        Flux.testmode!(model)
        @showprogress for (xs, y) in test_loader
            Flux.reset!(model)
            ŷ = tanh.([model(xs[i, :, :] |> device) for i in 1:size(xs, 1)][end] |> cpu)
            Flux.reset!(model)
            err += (loss(model, xs, y) |> cpu) / size(y, 2)
            if ŷs == nothing
                ŷs = ŷ[1, :]; ys = y[1, :]
            else
                ŷs = vcat(ŷs, ŷ[1, :]); ys = vcat(ys, y[1, :])
            end
        end
        err /= length(test_loader)
        errors[epoch, 2] = err
        
        @info "--------------------------------\nTrain Loss:  $(errors[epoch, 1])\nTest Loss:  $(errors[epoch, 2])"
        idxs = sortperm(ys)
        push!(ysVys, (ŷs[idxs], ys[idxs]))
        jldopen("results_$name.jld2", "w") do f
            f["errors"] = errors
            f["ysVys"] = ysVys
        end
    end
end

if ARGS[1] == "sp500"
    train_loader, test_loader = load_data("sp500", parse(Int, ARGS[2]), parse(Int, ARGS[3]), 256, 1024)
    train(1000, train_loader, test_loader, "sp500")
elseif ARGS[1]  ==  "etfs"
    train_loader, test_loader = load_data("etfs", parse(Int, ARGS[2]), parse(Int, ARGS[3]), 32, 1024)
    train(1000, train_loader, test_loader, "etfs")
end
