using Flux, DataFrames, CSV, BSON
using StatsBase: Weights, sample, mean, std, zscore 

include("AlpacaClient.jl")
using .AlpacaClient

ids = vcat(CSV.File("Data/s&p500.csv").Symbol, CSV.File("Data/commodities.csv").Symbol)
all_names = ["c", "h", "l", "n", "o", "t", "v", "vw", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December", "sma", "mlr_bands_col_1", "mlr_bands_col_2", "mlr_bands_col_3", "mlr_lb", "mlr_rsq", "zlema", "mlr_se", "mlr_slope", "mlr_intercept", "donch_col_1", "donch_col_2", "donch_col_3", "wma", "kama", "dema", "cci", "wpr", "ema", "trima", "rsi", "mama_col_1", "mama_col_2", "tema", "macd_col_1", "macd_col_2", "macd_col_3", "momentum", "atr", "hma", "swma", "kst", "psar", "mlr_beta_col_1", "mlr_beta_col_2", "maxima", "minima", "resistance", "mma", "mlr_ub", "mlr", "adx_col_1", "adx_col_2", "adx_col_3", "tr", "bbands_col_1", "bbands_col_2", "bbands_col_3", "support", "alma", "roc", "stoch_col_1", "stoch_col_2", "renko", "keltner_col_1", "keltner_col_2", "keltner_col_3", "aroon_col_1", "aroon_col_2", "aroon_col_3", "smi_col_1", "smi_col_2"]
# Remove date
col_names = ["c", "h", "l", "n", "o", "v", "vw", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December", "sma", "mlr_bands_col_1", "mlr_bands_col_2", "mlr_bands_col_3", "mlr_lb", "mlr_rsq", "zlema", "mlr_se", "mlr_slope", "mlr_intercept", "donch_col_1", "donch_col_2", "donch_col_3", "wma", "kama", "dema", "cci", "wpr", "ema", "trima", "rsi", "mama_col_1", "mama_col_2", "tema", "macd_col_1", "macd_col_2", "macd_col_3", "momentum", "atr", "hma", "swma", "kst", "psar", "mlr_beta_col_1", "mlr_beta_col_2", "maxima", "minima", "resistance", "mma", "mlr_ub", "mlr", "adx_col_1", "adx_col_2", "adx_col_3", "tr", "bbands_col_1", "bbands_col_2", "bbands_col_3", "support", "alma", "roc", "stoch_col_1", "stoch_col_2", "renko", "keltner_col_1", "keltner_col_2", "keltner_col_3", "aroon_col_1", "aroon_col_2", "aroon_col_3", "smi_col_1", "smi_col_2"]
# Remove DayOfWeek Vec and MonthVec and minima and maxima from zscoreing
zcol_names = ["c", "h", "l", "n", "o", "v", "vw", "sma", "mlr_bands_col_1", "mlr_bands_col_2", "mlr_bands_col_3", "mlr_lb", "mlr_rsq", "zlema", "mlr_se", "mlr_slope", "mlr_intercept", "donch_col_1", "donch_col_2", "donch_col_3", "wma", "kama", "dema", "cci", "wpr", "ema", "trima", "rsi", "mama_col_1", "mama_col_2", "tema", "macd_col_1", "macd_col_2", "macd_col_3", "momentum", "atr", "hma", "swma", "kst", "psar", "mlr_beta_col_1", "mlr_beta_col_2", "resistance", "mma", "mlr_ub", "mlr", "adx_col_1", "adx_col_2", "adx_col_3", "tr", "bbands_col_1", "bbands_col_2", "bbands_col_3", "support", "alma", "roc", "stoch_col_1", "stoch_col_2", "renko", "keltner_col_1", "keltner_col_2", "keltner_col_3", "aroon_col_1", "aroon_col_2", "aroon_col_3", "smi_col_1", "smi_col_2"]

namesToIndex = Dict()
for (idx, name) in zip(1:length(col_names), col_names)
    namesToIndex[name] = idx
end
zcol_idxs = [namesToIndex[name] for name in zcol_names]

function z_score(mat, idxs)
    μ = mean(mat[:, idxs], dims=1)
    σ = std(mat[:, idxs], dims=1)
    mat[:, idxs] .= map(x -> isnan(x) ? zero(x) : x, zscore(mat[:, idxs], μ, σ))
    return mat
end

function what_to_buy_by_n(pred, close_prices)
	buy = []
	buy_weight = []
	for (id, p) in zip(ids, pred)
		if p > 0.0
			push!(buy, id)
			push!(buy_weight, p)
		end
	end
	buy_weight = softmax(buy_weight)

	buy_n = zeros(Int, length(buy))
	cash = get_account()["cash"]
	while !all(values(close_prices) .> cash)
		idx = sample(1:length(buy), Weights(buy_weight))
		price = close_prices[buy[idx]]
		if cash >= price
			buy_n[idx] += 1
			cash -= price
		end
	end
	return buy, buy_n
end

function buy(id, qty, limit_price)
	res = limit_order(id, qty, limit_price, "buy")
	while res == -1
		sleep(10)
		res = limit_order(id, qty, limit_price, "buy")
	end
end

function sell(id, qty)
	res = market_order_qty(id, qty, "sell")
	while res == -1
		sleep(10)
		res = market_order_qty(id, qty, "sell")
	end
end

BSON.@load "Tests/model_60_1024.bson" model ps opt
period = 90
batch_size = length(ids)
in_size = length(col_names)
out_size = 1
buy = []
sell = []
sell_n = []

while true
	global buy, sell, sell_n

	# Put in sell order just before the close of the day
	for (id, n) in zip(sell, sell_n)
		sell(id, n)
	end

	run(`julia get_market_data.jl`)
	run(`julia clean_and_indicators.jl`)

	data_frames_raw = []
	data_frames_clean = []
	@info "Loading ID's..."
	for id in ids
		push!(data_frames_raw, DataFrame(CSV.File("Data/RAW/$id.csv")))
	    push!(data_frames_clean, DataFrame(CSV.File("Data/CLEAN/$id.csv")))
	end

	xdata = zeros(Float32, period, in_size, batch_size)
	close_prices = Dict()
	for (i, (df_raw, df_clean)) in enumerate(zip(data_frames_raw, data_frames_clean))
		df_t = df_clean[end-(period-1):end, col_names]

		xs = z_score(Matrix(df_t), zcol_idxs)
		xdata[:, :, i] .= xs
		close_prices[ids[i]] = df_raw.c[end]
	end

	Flux.testmode!(model)
	Flux.reset!(model)
	pred = reshape([model(xdata[i, :, :]) for i in 1:period][end], (batch_size,))
	buy, buy_n = what_to_buy_by_n(pred, close_prices)

	res = cancel_all_orders()
	while res == -1
		sleep(10)
		res = cancel_all_orders()
	end

	# Put in buy orders at end of day
	for (id, n) in zip(buy, buy_n)
		buy(id, n, close_prices[id])
	end

	sell = buy
	sell_n = buy_n
end





