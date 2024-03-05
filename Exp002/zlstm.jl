using Flux, JLD2, CUDA, ProgressMeter, DelimitedFiles
using Random: shuffle

const device = CUDA.functional() ? gpu : cpu
const inSize = 8
const SeqL = 128
const FutP = 128
const ROR = 0

function load_data(name, batchsize)
    xdata = []
    ydata = []
    jldopen("cDATA/$name.jld2", "r") do f
        xdata = f["xdata"] 
        ydata = f["ydata"]
    end
    N = size(xdata, 3)
    idxs = shuffle(1:N)
    test_idxs = idxs[1:div(N, 10)]
    train_idxs = idxs[div(N, 10)+1:end]
    return (
        Flux.DataLoader(
            (data=xdata[:, :, train_idxs], label=ydata[:, :, train_idxs]),
            batchsize=batchsize, shuffle=true
        ),
        Flux.DataLoader(
            (data=xdata[:, :, test_idxs], label=ydata[:, :, test_idxs]),
            batchsize=batchsize, shuffle=true
        )
    )
end

function create_model()
    Chain(
        Dense(inSize => inSize^2, celu),
        Dense(inSize^2 => inSize^2, celu),
        Dropout(0.2),
        LSTM(inSize^2 => inSize^2),
        Dropout(0.2),
        Dense(inSize^2 => 1, tanh_fast)
    ) |> device
end

const W = collect(range(0f0, 1f0, length = SeqL))
function loss(model, xs, ys)
    return sum((
        Flux.mse(model(xs[i, :, :] |> device), ys[i, :, :] |> device)
        for i in 1:SeqL
    ) .* W)
end

function train(nepochs, train_loader, test_loader, name)
    model = create_model()
    ps = Flux.params(model)
    opt = AMSGrad()
    losses = zeros(nepochs)
    for epoch in 1:nepochs
        Flux.trainmode!(model)
        @showprogress for (xs, ys) in train_loader
            Flux.reset!(model)
            grads = gradient(() -> loss(model, xs, ys), ps)
            Flux.Optimise.update!(opt, ps, grads)
        end

        Flux.testmode!(model)
        error = 0
        @showprogress for (xs, ys) in test_loader
            Flux.reset!(model)
            error += (loss(model, xs, ys) |> cpu) / size(ys, 2)
        end
        error /= length(test_loader)
        losses[epoch] = error
        println("epoch: $epoch, loss: $error")

        if epoch % 2 == 0
            open("results_$name.csv", "w") do io
                writedlm(io, losses)
            end
        end
    end
end

if ARGS[1] == "sp500"
    train_loader, test_loader = load_data("sp500", 1024)
    train(1000, train_loader, test_loader, "sp500")
elseif ARGS[1]  ==  "etfs"
    train_loader, test_loader = load_data("etfs", 256)
    train(1000, train_loader, test_loader, "etfs")
end