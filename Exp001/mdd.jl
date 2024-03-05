using Flux, Dates
using BSON: @load

include("data_loader.jl")
using .CrDataLoader

include("talib.jl")
using .TaLib

include("coinbase.jl")
using .Coinbase

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

const hour = 4
const day = hour*24

own = try
    get_last_fill("ADA-USD")
catch err
    println("Error getting last fill: $err")
end

amount = try
    floor(balance_usd(), digits=0)
catch err
    println("Error getting balance: $err")
end

@load "model.genome" genome
model = make_model(genome); Flux.reset!(model)
t = floor(now(), Dates.Hour) + Dates.Minute(15);
while t <= now()
    global t += Dates.Minute(15)
end
reset_t = t; println(t)
while t >= now()
    sleep(1)
end

# Starting at $100
while true # run forever
    global own, amount, model, t, reset_t
    data = try
        get_historic_data(900)
    catch err
        println("Error getting data: $err")
        sleep(10)
        continue
    end
    SMA(data, 7, "sma7"); SMA(data, 14, "sma14"); WILLR(data); MFI(data); PPO(data); SUB(data)
    x = Vector{Float32}(data[end, [:close, :sma7, :sma14, :willr, :mfi, :ppo]])
    y = model(x)
    
    @info "Buying and Selling -- $(now())"
    if argmax(y) == 1 && own == 0
        println("Buying -- $(now())")
        try
            buy_crypto_coin("ADA-USD", data[end, :close], amount)
            own = 1
        catch err
            println("Failed to buy: $err")
            own = 0
            continue
        end
    elseif argmax(y) == 2 && own == 1
        println("Selling -- $(now())")
        try
            sell_crypto_coin("ADA-USD", data[end, :close])
            own = 0
        catch err
            println("Failed to sell: $err")
            own = 1
            continue
        end
    end
    println("Done")
    
    amount = try
        floor(balance_usd(), digits=0)
    catch err
        println("Error getting balance: $err")
    end
    
    if own == 0
        open("history.csv", "a") do io
            write(io, "$amount\n")
        end
    end

    if reset_t + Dates.Day(7) <= now()
        reset_t = now()
        Flux.reset!(model)
    end

    t += Dates.Minute(15)
    while t >= now()
        sleep(5)
    end
end