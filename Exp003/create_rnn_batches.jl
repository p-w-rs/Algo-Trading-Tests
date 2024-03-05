using CSV, DataFrames, JLD2, ProgressMeter

using StatsBase: mean, std, zscore
using Random: shuffle

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

period = parse(Int, ARGS[1])
batch_size = parse(Int, ARGS[2])
in_size = length(col_names)
out_size = 1

function z_score(mat, idxs)
    μ = mean(mat[:, idxs], dims=1)
    σ = std(mat[:, idxs], dims=1)
    mat[:, idxs] .= map(x -> isnan(x) ? zero(x) : x, zscore(mat[:, idxs], μ, σ))
    return mat
end

ids = vcat(CSV.File("Data/s&p500.csv").Symbol, CSV.File("Data/commodities.csv").Symbol)
data_frames = []
@info "Loading ID's..."
for id in ids
    push!(data_frames, DataFrame(CSV.File("Data/CLEAN/$id.csv")))
end

gidx = 0
for (id, df) in zip(ids, data_frames)
    for idx in 1:nrow(df)-period - 1
        global gidx += 1
    end
end

xdata = zeros(Float32, period, in_size, gidx)
ydata = zeros(Float32, period, gidx)
gidx = 0
@info "Cleaning and Scaling Data..."
for (id, df) in zip(ids, data_frames)
    for idx in 1:nrow(df)-period - 1
        global gidx += 1
        df_t0 = df[idx:idx+period - 1, col_names]
        df_t1 = df[idx+1:idx+period, col_names]
        
        xs = z_score(Matrix(df_t0), zcol_idxs)
        ys = (df_t1.c .- df_t0.c) ./ df_t0.c

        xdata[:, :, gidx] .= xs
        ydata[:, gidx] .= ys
    end
end

idxs = shuffle(1:gidx)
n = length(idxs); n2 = Int(floor(n*0.2)); n_split = n - n2;
trainidxs = idxs[1:n_split]
testidxs = idxs[n_split+1:end]

xtrain = [[zeros(Float32, in_size, batch_size) for _ in 1:period] for _ in 1:batch_size:length(trainidxs)]
ytrain = [[zeros(Float32, 1, batch_size) for _ in 1:period] for _ in 1:batch_size:length(trainidxs)]
gidx = 0
@info "Creating train batches..."
for i_idx in 1:batch_size:length(trainidxs)
    global gidx += 1
    e_idx = i_idx+batch_size-1 > length(trainidxs) ? length(trainidxs) : i_idx+batch_size-1
    local idxs = trainidxs[i_idx:e_idx]
    for i in 1:period
        if length(idxs) < batch_size
            xtrain[gidx][i] = zeros(Float32, in_size, length(idxs))
            ytrain[gidx][i] = zeros(Float32, 1, length(idxs))
        end
        xtrain[gidx][i][:, 1:length(idxs)] .= xdata[i, :, idxs] 
        ytrain[gidx][i][1, 1:length(idxs)] .= ydata[i, idxs]
    end
end


xtest = [[zeros(Float32, in_size, batch_size) for _ in 1:period] for _ in 1:batch_size:length(testidxs)]
ytest = [[zeros(Float32, 1, batch_size) for _ in 1:period] for _ in 1:batch_size:length(testidxs)]
gidx = 0
@info "Creating test batches..."
for i_idx in 1:batch_size:length(testidxs)
    global gidx += 1
    e_idx = i_idx+batch_size-1 > length(testidxs) ? length(testidxs) : i_idx+batch_size-1
    local idxs = testidxs[i_idx:e_idx]
    for i in 1:period
        if length(idxs) < batch_size
            xtest[gidx][i] = zeros(Float32, in_size, length(idxs))
            ytest[gidx][i] = zeros(Float32, 1, length(idxs))
        end
        xtest[gidx][i][:, 1:length(idxs)] .= xdata[i, :, idxs] 
        ytest[gidx][i][1, 1:length(idxs)] .= ydata[i, idxs]
    end
end


@info "Writing train/test batches..."
jldopen("Data/BATCHES_$(period)_$(batch_size).jld2", "w") do file
    stats = (period, batch_size, in_size, out_size)
    file["stats"] = stats
    file["train/xtrain"] = xtrain
    file["train/ytrain"] = ytrain
    file["test/xtest"] = xtest
    file["test/ytest"] = ytest
end


