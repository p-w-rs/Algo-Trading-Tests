using Flux, BlackBoxOptim, DataFrames, Statistics
using BSON: @save

include("data_loader.jl")
using .CrDataLoader

const hour = 1
const day = hour*24
const week = day*7

df = get_historic_data(3600)
rors = []
train_idx = []
for i in 1:32
    idx = rand(1:(nrow(df)-week)+1)
    push!(train_idx, idx)
end

val_idx = []
for i in 1:32
    idx = rand(1:(nrow(df)-week)+1)
    while idx in train_idx
        idx = rand(1:(nrow(df)-week)+1)
    end
    push!(val_idx, idx)
end

IN = 6
OUT = 3
HD = IN*OUT*3

function make_model(genome)
    model = Chain(LSTM(IN, HD), LSTM(HD, HD), LSTM(HD, HD), LSTM(HD, OUT))
    i = 1
    for layer in model
        s = size(layer.cell.Wi)
        len = prod(s)
        layer.cell.Wi .= reshape(genome[i:i+len-1], s)
        i += len

        s = size(layer.cell.Wh)
        len = prod(s)
        layer.cell.Wh .= reshape(genome[i:i+len-1], s)
        i += len
    end
    return model
end

_model = Chain(LSTM(IN, HD), LSTM(HD, HD), LSTM(HD, HD), LSTM(HD, OUT))
dims = 0
for layer in _model.layers
    global dims
    dims += length(layer.cell.Wi)
    dims += length(layer.cell.Wh)
end

function eval_model(df, model)
    global rors; Flux.reset!(model);
    cidx = 1; eidx = nrow(df);
    own = 0; price = 0;
    while cidx <= eidx
        x = Vector{Float32}(df[cidx, 2:end])
        y = model(x)

        if argmax(y) == 1 && own == 0
            price = df[cidx, :close]
            own = 1
        elseif argmax(y) == 2 && own == 1
            ror = (df[cidx, :close] - price)/price
            push!(rors, ror)
            own = 0
        end
        cidx += 1
    end
end

best_val = typemin(Float64)
best_agg = typemin(Float64)
function callback(oc)
    global best_val, best_agg
    global rors = []
    genome = best_candidate(oc)
    model = make_model(genome)
    eval_model(df[nrow(df)-(day*30)+1:nrow(df), :], model)
    #for idx in val_idx
    #    eval_model(df[idx:idx+week-1, :], model)
    #end
    f = [mean(rors)*100, minimum(rors)*100, length(rors)/15, sum(rors.*100)]
    println(f[1], " ", f[2], " ", f[3], " ", f[4])
    if (f[1]*f[3]) + (f[2]/f[3]) > best_val && f[4] > best_agg
        best_val = (f[1]*f[3]) + (f[2]/f[3]); best_agg = f[4];
        @save "model.bson" model
    end
end

function fitness(genome)
    global rors = []
    model = make_model(genome)
    eval_model(df[1:nrow(df)-(day*30), :], model)
    #for idx in train_idx
    #    eval_model(df[idx:idx+week-1, :], model)
    #end
    if length(rors) < 30
        return -1000.0, -1000.0, 0.0, -1000.0
    end
    return mean(rors)*100, minimum(rors)*100, length(rors)/30, sum(rors.*100)
end

@info "Optimizing model..."
function weightedfitness(f)
    return (f[1]*f[3]) + f[2]
end

res = bboptimize(fitness; Method=:borg_moea,
    SearchRange=(-1.0, 1.0), NumDimensions=dims, MaxSteps=6000,
    FitnessScheme=ParetoFitnessScheme{4}(is_minimizing=false, aggregator=weightedfitness),
    TraceMode=:verbose, CallbackFunction=callback, CallbackInterval=5.0, RestartCheckPeriod=300)




