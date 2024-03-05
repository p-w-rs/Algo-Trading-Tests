using Flux, DataFrames, Statistics
using BSON: @load

include("NNLib2.jl")
using .NNLib

include("talib.jl")
using .TaLib

include("data_loader.jl")
using .CrDataLoader

const hour = 4
const day = 24*hour

IN = 6
OUT = 3
HD = IN*OUT*3

raw = get_historic_data(900)
SMA(raw, 7, "sma7"); SMA(raw, 14, "sma14"); WILLR(raw); MFI(raw); PPO(raw); SUB(raw)
proc = raw[40:end, [:close, :sma7, :sma14, :willr, :mfi, :ppo]]
@load "model.genome" genome

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

function eval_model(df, model)
    Flux.reset!(model)
    init_dollars = dollars = 100; 
    crypto_amt = 0; own = 0;
    cidx = 1; eidx = nrow(df);
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
        end
        cidx % (day*7) == 0 && Flux.reset!(model)
        cidx += 1
    end
    value = own == 1 ? (df[end, :close] * crypto_amt) + dollars : dollars
    final_ror = ((value - init_dollars)/init_dollars)
    return final_ror
end

model = make_model(genome)
println(eval_model(proc, model))