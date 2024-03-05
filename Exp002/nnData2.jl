using DataFrames, CSV, JLD2, ProgressMeter

const inSize = 7+6
const SeqL = 128
const FutP = 128
const ROR = 0

function clean_data(symbolList, name)
    N = 0
    @showprogress for symbol in symbolList
        df = DataFrame(CSV.File("rDATA/$symbol.csv"))
        for i in 1:nrow(df)-(SeqL+FutP-1)
            N += 1
        end
    end

    xdata = zeros(Float32, SeqL, inSize, N)
    ydata = zeros(Float32, SeqL, 1, N)
    n = 1
    @showprogress for symbol in symbolList
        df = DataFrame(CSV.File("rDATA/$symbol.csv"))
        for i in 1:nrow(df)-(SeqL+FutP-1)
            xdata[:, :, n] .= Matrix(df[i:i+SeqL-1, :])
            for (idx, j) in enumerate(i+1:i+SeqL)
                init = df[j-1, "close"]
                rors = ((df[j:j+FutP-1, "close"] .- init)./init).*100
                ydata[idx, 1, n] = (sum(rors .> ROR) - sum(rors .<= ROR))/FutP
            end
            n += 1
        end
    end

    jldopen("nnDATA/$name.jld2", "w") do f
        f["xdata"] = xdata
        f["ydata"] = ydata
    end
end

if ARGS[1] == "sp500"
    SP500 = DataFrame(CSV.File("sp500.csv"; delim='|'))[!, "Symbol"]
    clean_data(SP500, "sp500")
elseif ARGS[1]  ==  "etfs"
    ETFs = DataFrame(CSV.File("etfs.csv"; delim='|'))[!, "Symbol"]
    clean_data(ETFs, "etfs")
end
