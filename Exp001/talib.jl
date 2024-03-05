module TaLib

using PyCall, DataFrames

talib = pyimport("talib")

export SMA, EMA, WILLR, MFI, PPO, SUB

function EMA(df, t, name)
    ind = talib.EMA(df[!, :close], timeperiod=t)
    insertcols!(df, length(propertynames(df))+1, Symbol(name) => ind)
end

function SMA(df, t, name)
    ind = talib.SMA(df[!, :close], timeperiod=t)
    insertcols!(df, length(propertynames(df))+1, Symbol(name) => ind)
end

function WILLR(df)
    ind = talib.WILLR(df[!, :high], df[!, :low], df[!, :close], timeperiod=14)
    insertcols!(df, length(propertynames(df))+1, :willr => (ind.+50)./50)
end

function MFI(df)
    ind = talib.MFI(df[!, :high], df[!, :low], df[!, :close], df[!, :volume], timeperiod=14)
    insertcols!(df, length(propertynames(df))+1, :mfi => (ind.-50)./50)
end

function PPO(df)
    ind = talib.PPO(df[!, :close], fastperiod=12, slowperiod=26)
    insertcols!(df, length(propertynames(df))+1, :ppo => ind ./ 10)
end

function SUB(df)
    for n in propertynames(df)[3:end]
        ind = talib.SUB(df[2:end, n], df[1:end-1, n])
        insertcols!(df, length(propertynames(df))+1, Symbol("Δ$n") => [0.0, ind...])
    end
end

end #module