using Dates, DataFrames, CSV, ProgressMeter

include("AlpacaClient.jl")
using .AlpacaClient

ids = vcat(CSV.File("Data/s&p500.csv").Symbol, CSV.File("Data/commodities.csv").Symbol)
end_t = Date(now()-Day(1))
start_t = end_t - Year(6)
timeframe = "1Day"

@showprogress for id in ids
	df = get_bars(id, start_t, end_t, timeframe)
	if (df == -1 || df == nothing)
		println(id)
		continue
	else
		for c in eachcol(df[!, [:c, :h, :l, :n, :o, :v, :vw]])
			if any(isnan, c)
				println(id, " === problem with dataframe")
			end
		end
		if isfile("Data/RAW/$id.csv")
			old_df = DataFrame(CSV.File("Data/RAW/$id.csv"))
			old_t = old_df[end, :t]
			idx = findfirst(t -> t == old_t, df[!, :t])+1
			if idx > nrow(df)
				CSV.write("Data/RAW/$id.csv", old_df)
			else
				new_df = vcat(old_df, df[idx:end, :])
				CSV.write("Data/RAW/$id.csv", new_df)
			end
		else
			CSV.write("Data/RAW/$id.csv", df)
		end
		sleep(1)
	end
end