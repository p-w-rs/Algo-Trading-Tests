using CSV, DataFrames, Dates, Indicators, ProgressMeter

AllInd = Dict([
	# Moving Averages
	alma => [:c],
	dema => [:c],
	ema => [:c],
	hma => [:c],
	kama => [:c],
	mama => [:c],
	mma => [:c],
	sma => [:c],
	swma => [:c],
	tema => [:c],
	trima => [:c],
	wma => [:c],
	zlema => [:c],

	# Momentum Indicators
	adx => [:h, :l, :c],
	aroon => [:h, :l],
	cci => [:h, :l, :c],
	donch => [:h, :l],
	kst => [:c],
	macd => [:c],
	momentum => [:c],
	psar => [:h, :l],
	roc => [:c],
	rsi => [:c],
	smi => [:h, :l, :c],
	stoch => [:h, :l, :c],
	wpr => [:h, :l, :c],

	# Volatility Indicators
	atr => [:h, :l, :c],
	bbands => [:c],
	keltner => [:h, :l, :c],
	tr => [:h, :l, :c],

	# Regressions
	mlr => [:c],
	mlr_bands => [:c],
	mlr_beta => [:c],
	mlr_intercept => [:c],
	mlr_lb => [:c],
	mlr_rsq => [:c],
	mlr_se => [:c],
	mlr_slope => [:c],
	mlr_ub => [:c],

	# Trendlines
	maxima => [:c],
	minima => [:c],
	resistance => [:c],
	support => [:c],

	# Patterns
	renko => [:h, :l, :c]
])

DayToVec = Dict()
days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
for(idx, day) in zip(1:5, days)
	DayToVec[day] = zeros(Int, 5)
	DayToVec[day][idx] = 1
end

MonthToVec = Dict()
months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
for (idx, month) in zip(1:12, months)
	MonthToVec[month] = zeros(Int, 12)
	MonthToVec[month][idx] = 1
end

ids = vcat(CSV.File("Data/s&p500.csv").Symbol, CSV.File("Data/commodities.csv").Symbol)
data_frames = []
@showprogress for id in ids
    push!(data_frames, DataFrame(CSV.File("Data/RAW/$id.csv")))
end

@showprogress for (id, df) in zip(ids, data_frames)
	t = df[!, :t]
	dates = map(s -> DateTime(parse.(Int, split(s, ['-', ':', 'T', 'Z'])[1:end-1])...), t)
	
	vecs = map(dt -> DayToVec[Dates.format(dt, "E")], dates)
	onehot_df = DataFrame(hcat(vecs...)', Symbol.(days))
	df = hcat(df, onehot_df)

	vecs = map(dt -> MonthToVec[Dates.monthname(dt)], dates)
	onehot_df = DataFrame(hcat(vecs...)', Symbol.(months))
	df = hcat(df, onehot_df)
	
	for indF in keys(AllInd)
		cols = AllInd[indF]
		ind = indF(Matrix(df[!, cols]))
		ind = map(x -> isnan(x) ? zero(x) : x, ind)
		if length(size(ind)) == 1 || size(ind)[2] == 1
			name = string(indF)
			df = hcat(df, DataFrame(ind[:,:], [name]))
		elseif typeof(ind) == Matrix{Float64}
			names = [string(indF)*"_col_$i" for i in 1:size(ind)[2]]
			df = hcat(df, DataFrame(ind, names))
		end
	end
	CSV.write("Data/CLEAN/$id.csv", df)
end