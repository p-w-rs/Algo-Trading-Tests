using DataFrames, CSV, JLD2, StatsBase, ProgressMeter

const inputsize = 7+6
const ROR = 0

function prep_data(symbolList, name, poollength, horizon)
    N = 0
    @showprogress for symbol in symbolList
        df = DataFrame(CSV.File("csvDATA/$symbol.csv"))
        for i in poollength:nrow(df)-horizon
            N += 1
        end
    end

    input = zeros(Float32, poollength, inputsize, N)
    target = zeros(Float32, 1, N)
    n = 1
    @showprogress for symbol in symbolList
        df = DataFrame(CSV.File("csvDATA/$symbol.csv"))
        for i in poollength:nrow(df)-horizon
            mat1 = Matrix(df[i-(poollength-1):i, [1, 2, 3, 4, 11, 12, 13]])
            mat2 = Matrix(df[i-(poollength-1):i, [5, 6, 7, 8, 9, 10]])
            dt = fit(ZScoreTransform, mat1, dims=1)
            input[:, 1:7, n] .= StatsBase.transform(dt, mat1)
            input[:, 8:13, n] .= mat2
            if any(isnan, input[:, :, n])
                println("Oh no on: $symbol, $n")
            end
            init = df[i, "close"]
            j = i+1
            rors = ((df[j:j+(horizon-1), "close"] .- init)./init).*100
            target[1, n] = (sum(rors .> ROR) - sum(rors .<= ROR))/horizon
            n += 1
        end
    end

    jldopen("nnDATA/$name-$poollength-$horizon.jld2", "w") do f
        f["input"] = input
        f["target"] = target
    end
end

if ARGS[1] == "sp500"
    SP500 = DataFrame(CSV.File("sp500.csv"; delim='|'))[!, "Symbol"]
    prep_data(SP500, "sp500", parse(Int, ARGS[2]), parse(Int, ARGS[3]))
elseif ARGS[1]  ==  "etfs"
    ETFs = DataFrame(CSV.File("etfs.csv"; delim='|'))[!, "Symbol"]
    prep_data(ETFs, "etfs", parse(Int, ARGS[2]), parse(Int, ARGS[3]))
end
