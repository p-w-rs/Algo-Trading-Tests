module CrDataLoader

using DataFrames, CSV, Dates, HTTP, JSON, ProgressMeter

export return_data, get_historic_data, get_immidiate_data

id = "ADA-USD"
vol_div = 1623034800

function unix2float(unixtime)
    t = unix2datetime(unixtime)
    h = Dates.Hour(t).value
    m = Dates.Minute(t).value / 60
    return (h+m)/24
end

function get_immidiate_data(granularity)
    @info "Loading $id data..."
    unixtime, time, low, high, open, close, volume =
        Vector{Int}(), Vector{Float64}(), Vector{Float64}(), Vector{Float64}(), Vector{Float64}(), Vector{Float64}(), Vector{Float64}()
    url = "https://api.pro.coinbase.com/products/$id/candles?granularity=$granularity"
    json = JSON.Parser.parse(String(HTTP.get(url).body))
    println("Done")
    time = unix2float(json[1][1])
    return [time, json[1][2:end-1]..., json[1][end]/vol_div]
end

function get_historic_data(granularity)
    @info "Loading $id data..."
    unixtime, time, low, high, open, close, volume =
        Vector{Int}(), Vector{Float64}(), Vector{Float64}(), Vector{Float64}(), Vector{Float64}(), Vector{Float64}(), Vector{Float64}()
        
    url = "https://api.pro.coinbase.com/products/$id/candles?granularity=$granularity"
    json = JSON.Parser.parse(String(HTTP.get(url).body))
    for i in 1:length(json)
        ut, l, h, o, c, v = json[i]
        push!(unixtime,  ut); push!(time, unix2float(ut)); push!(low, l); push!(high,  h); push!(open, o); push!(close, c); push!(volume, v)
    end
    sleep(0.25)

    iters = round(Int, (Dates.Second(Dates.Day(30)).value/granularity)/300)
    @showprogress for _ in 1:iters
        stop = unix2datetime(unixtime[end])
        start = stop - Dates.Second(granularity*300)
        url = "https://api.pro.coinbase.com/products/$id/candles?granularity=$granularity&start=$start&end=$stop"
        json = JSON.Parser.parse(String(HTTP.get(url).body))
        for i in 2:length(json)
            ut, l, h, o, c, v = json[i]
            push!(unixtime,  ut); push!(time, unix2float(ut)); push!(low, l); push!(high,  h); push!(open, o); push!(close, c); push!(volume, v)
        end
        sleep(0.25)
    end
    df = sort(DataFrames.DataFrame(
        unixtime=unixtime, time=time, low=low, high=high, open=open, close=close, volume=(volume./vol_div)
    ))
    CSV.write("$id.csv", df)
    println("Done")
    return df
end

function return_data()
    @info "Loading $id data..."
    df = DataFrames.DataFrame(CSV.File("$id.csv"))
    println("Done")
    return df
end

end #module

