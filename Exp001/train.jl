using Flux, BlackBoxOptim, DataFrames, Statistics, LinearAlgebra
using BSON: @save

include("NNLib2.jl")
using .NNLib

include("talib.jl")
using .TaLib

include("data_loader.jl")
using .CrDataLoader

const hour = 4
const day = 24*hour

raw = get_historic_data(900)
SMA(raw, 7, "sma7"); SMA(raw, 14, "sma14"); WILLR(raw); MFI(raw); PPO(raw); SUB(raw)
proc = raw[40:end, [:close, :sma7, :sma14, :willr, :mfi, :ppo]]

train_idxs = []
for i in 1:14
    push!(train_idxs, rand(1:nrow(proc)-(day*7)))
end

val_idxs = []
for i in 1:14
    push!(val_idxs, rand(1:nrow(proc)-(day*7)))
end

IN = 6
OUT = 3
HD = IN*OUT*3

function make_model(genome)
    model = Chain(
        LSTM(IN, HD), LSTM(HD, HD), LSTM(HD, OUT)
    )
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

        len = size(layer.cell.b, 1)
        layer.cell.b .= genome[i:i+len-1]
        i += len
    end
    return model
end
_model = Chain(LSTM(IN, HD), LSTM(HD, HD), LSTM(HD, OUT))
dims = 0
for layer in _model
    global dims += length(layer.cell.Wi)
    global dims += length(layer.cell.Wh)
    global dims += length(layer.cell.b)
end

function eval_model(df, model)
    Flux.reset!(model)
    init_dollars = dollars = 100; 
    crypto_amt = 0; own = 0;
    cidx = 1; eidx = nrow(df);
    rors = []
    while cidx <= eidx
        x = Vector{Float32}(df[cidx, :])
        y = model(x)

        if argmax(y) == 1 && own == 0
            price = df[cidx, :close]
            penalty = dollars * 0.002
            crypto_amt = (dollars - penalty) / price
            dollars = 0
            own = 1
        elseif argmax(y) == 2 && own == 1
            price = df[cidx, :close]
            penalty = (price * crypto_amt) * 0.002
            dollars = (price * crypto_amt) - penalty
            crypto_amt = 0
            own = 0
            ror = (dollars - init_dollars)/init_dollars
            init_dollars = dollars
            push!(rors, ror)
        end

        cidx += 1
    end
    #value = own == 1 ? (df[end, :close] * crypto_amt) + dollars : dollars
    #final_ror = ((value - init_dollars)/init_dollars)
    isempty(rors) && return [0.0]
    return rors
end

#=best = typemin(Float64)
function callback(oc)
    global best
    genome = best_candidate(oc)
    model = make_model(genome)
    rors = eval_model(proc, model)
    if sum(rors) > best
        println(sum(rors))
        best = sum(rors)
        @save "model.genome" genome
    end
end=#

best = typemin(Float64)
function callback(oc)
    global best
    genome = best_candidate(oc)
    means = []; mins = []
    model = make_model(genome)
    for idx in val_idxs
        rors = eval_model(proc[idx:idx+(day*7)-1, :], model)
        push!(means, mean(rors)); push!(mins, minimum(rors))
    end
    if (mean(means)+minimum(mins)) > best
        best = (mean(means)+minimum(mins))
        @save "model.genome" genome
    end
end

function fitness(genome)
    means = []; mins = []
    model = make_model(genome)
    for idx in train_idxs
        rors = eval_model(proc[idx:idx+(day*7)-1, :], model)
        push!(means, mean(rors)); push!(mins, minimum(rors))
    end
    return -(mean(means)+minimum(mins))
end

@info "Optimizing model..."
res = bboptimize(fitness; Method=:adaptive_de_rand_1_bin_radiuslimited,
    SearchRange=(-1.0, 1.0), NumDimensions=dims, MaxSteps=20000,
    TraceMode=:verbose, CallbackFunction=callback, CallbackInterval=0.0)

#res = bboptimize(fitness; Method=:borg_moea,
#    SearchRange=(-1.0, 1.0), NumDimensions=dims, MaxSteps=20000,
#    FitnessScheme=ParetoFitnessScheme{2}(is_minimizing=true, aggregator=weightedfitness),
#    TraceMode=:verbose, CallbackFunction=callback, CallbackInterval=5.0, RestartCheckPeriod=1000)






