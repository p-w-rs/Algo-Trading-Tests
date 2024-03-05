module CoinbaseAPI

using PyCall, HTTP, JSON, StringEncodings, DataFrames, CSV, JLD2, Dates

export get_accounts, get_account, get_orders, get_order,
	   cancel_orders, cancel_order, limit_order, market_order,
	   get_products, get_stats, get_tick, get_candles, get_15min_candles,
	   get_data, make_batches

############################################# ===== CONSTANTS ===== ##############################################
const API_URL = "https://api.exchange.coinbase.com"
const API_SECRET = "IvEgf/ovH4KEXxd023CrvfFn6201WNNrSrHhE3+3Dzeq+ZZifVgpGzZxCoVsHtbaQerbRgHuCyTThBR0axYA1A=="
const API_KEY = "a656e17b3cf43881536fee22ebf1f80e"
const API_PASSPHRASE = "i1vz7ad6je9"

############################################# ===== HELPERS ===== ##############################################
py"""
import time
import base64
import hashlib
import hmac

def auth_headers(method, path, body, api_secret, api_key, api_passphrase):
    timestamp = str(time.time())
    message = timestamp + method + path + body
    message = message.encode("ascii")
    hmac_key = base64.b64decode(api_secret)
    signature = hmac.new(hmac_key, message, hashlib.sha256)
    signature_b64 = base64.b64encode(signature.digest())
    headers = {
            "CB-ACCESS-SIGN": signature_b64,
            "CB-ACCESS-TIMESTAMP": timestamp,
            "CB-ACCESS-KEY": api_key,
            "CB-ACCESS-PASSPHRASE": api_passphrase,
            "Content-Type": "application/json",
            "Accept": "application/json"
        }
    return headers
"""


############################################# ===== ACCOUNTS ===== ##############################################
function get_accounts()
	method = "GET"
	path = "/accounts"
	headers = py"auth_headers"(method, path, "", API_SECRET, API_KEY, API_PASSPHRASE)
	try
		r = HTTP.request(method, "$(API_URL)$(path)", headers)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function get_account(id)
	method = "GET"
	path = "/accounts/$id"
	headers = py"auth_headers"(method, path, "", API_SECRET, API_KEY, API_PASSPHRASE)
	try
		r = HTTP.request(method, "$(API_URL)$(path)", headers)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end



############################################# ===== ORDERS ===== ##############################################
function get_orders()
	method = "GET"
	path = "/orders?status=pending&status=open&status=done"
	headers = py"auth_headers"(method, path, "", API_SECRET, API_KEY, API_PASSPHRASE)
	try
		r = HTTP.request(method, "$(API_URL)$(path)", headers)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function get_orders(type)
	method = "GET"
	path = "/orders?status=$type"
	headers = py"auth_headers"(method, path, "", API_SECRET, API_KEY, API_PASSPHRASE)
	try
		r = HTTP.request(method, "$(API_URL)$(path)", headers)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function get_order(order_id)
	method = "GET"
	path = "/orders/$order_id"
	headers = py"auth_headers"(method, path, "", API_SECRET, API_KEY, API_PASSPHRASE)
	try
		r = HTTP.request(method, "$(API_URL)$(path)", headers)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function cancel_orders()
	method = "DELETE"
	path = "/orders"
	headers = py"auth_headers"(method, path, "", API_SECRET, API_KEY, API_PASSPHRASE)
	try
		r = HTTP.request(method, "$(API_URL)$(path)", headers)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function cancel_orders(product_id)
	method = "DELETE"
	path = "/orders?product_id=$product_id"
	headers = py"auth_headers"(method, path, "", API_SECRET, API_KEY, API_PASSPHRASE)
	try
		r = HTTP.request(method, "$(API_URL)$(path)", headers)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function cancel_order(order_id)
	method = "DELETE"
	path = "/orders/$order_id"
	headers = py"auth_headers"(method, path, "", API_SECRET, API_KEY, API_PASSPHRASE)
	try
		r = HTTP.request(method, "$(API_URL)$(path)", headers)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function limit_order(product_id, price, size, side; time_in_force="GTT", cancel_after="day")
	#time_in_force = GTC, GTT, IOC, or FOK
	#cancel_after = min, hour, day (requires GTT)
	method = "POST"
	path = "/orders"
	order = Dict("product_id" => product_id, "price" => price, "size" => size, "side" => side, "type" => "limit", "post_only" => "false")
	if length(time_in_force) > 0
		order["time_in_force"] = time_in_force
	end
	if length(cancel_after) > 0
		order["cancel_after"] = cancel_after
	end
	headers = py"auth_headers"(method, path, JSON.json(order), API_SECRET, API_KEY, API_PASSPHRASE)
	try
		r = HTTP.request(method, "$(API_URL)$(path)", headers, JSON.json(order))
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function market_order(product_id, funds, side; time_in_force="GTT", cancel_after="day")
	#time_in_force = GTC, GTT, IOC, or FOK
	#cancel_after = min, hour, day (requires GTT)
	method = "POST"
	path = "/orders"
	order = Dict("product_id" => product_id, "funds" => funds, "side" => side, "type" => "market", "post_only" => "false")
	if length(time_in_force) > 0
		order["time_in_force"] = time_in_force
	end
	if length(cancel_after) > 0
		order["cancel_after"] = cancel_after
	end
	headers = py"auth_headers"(method, path, JSON.json(order), API_SECRET, API_KEY, API_PASSPHRASE)
	try
		r = HTTP.request(method, "$(API_URL)$(path)", headers, JSON.json(order))
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end





############################################# ===== MARKET DATA ===== ##############################################
function get_products()
	headers = Dict("Content-Type" => "application/json", "Accept" => "application/json")
	try
		r = HTTP.request("GET", "$(API_URL)/products", headers)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function get_stats(product_id)
	headers = Dict("Content-Type" => "application/json", "Accept" => "application/json")
	try
		r = HTTP.request("GET", "$(API_URL)/products/$product_id/stats", headers)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function get_tick(product_id)
	headers = Dict("Content-Type" => "application/json", "Accept" => "application/json")
	try
		r = HTTP.request("GET", "$(API_URL)/products/$product_id/ticker", headers)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

TimeToSec = Dict("1Min" => 60, "5Min" => 300, "15Min" => 900, "1Hour" => 3600, "6Hour" => 21600, "1Day" => 86400)
function get_candles(product_id, granularity, start_t, end_t)
	headers = Dict("Content-Type" => "application/json", "Accept" => "application/json")
	query = "granularity=$(TimeToSec[granularity])&start=$start_t&end=$end_t"
	try
		r = HTTP.request("GET", "$(API_URL)/products/$product_id/candles?$query", headers)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

# "ADA-USD"
function get_15min_candles(product_id)
	end_t = floor(now(UTC), Dates.Hour)
	start_t = end_t - Year(2)
	cur_end = end_t
	cur_start = cur_end - Hour(60)
	K = 1
	candles = get_candles(product_id, "15Min", cur_start, cur_end)
	for i in 1:length(candles)-1
		diff = candles[i][1] - candles[i+1][1]
		if diff != 900
			println("problem in candles $K, diff= $diff")
		end
	end
	K += 1
	(candles == -1 || length(candles) == 0) && return -1
	while(cur_start > start_t)
		cur_end = cur_start
		cur_start = cur_end - Hour(60)
		c = get_candles(product_id, "15Min", cur_start, cur_end)
		for i in 1:length(c)-1
			diff = c[i][1] - c[i+1][1]
			if diff != 900
				println("problem in candles $K, diff= $diff")
			end
		end
		K += 1
		(c == -1 || length(c) == 0) && break
		if c[1][1] == candles[end][1]
			candles = vcat(candles, c[2:end])
		else
			idx = findfirst(row -> row[1] == candles[end][1], c)
			(idx == nothing) && break
			candles = vcat(candles, c[idx+1:end])
		end
		sleep(0.2)
	end
	candles = permutedims(hcat(reverse(candles)...))
	df = DataFrame(candles, ["timestamp", "low", "high", "open", "close", "volume"])
	for i in 1:nrow(df)-1
		diff = df[i+1, :timestamp] - df[i, :timestamp]
		if diff != 900
			println("problem in dataframe @ $i, diff = $diff")
			#return -1
		end
	end
	return df
end

function decimals(_x)
	x = _x
	n = 0
	while x > 1.0
		n += 1
		x /= 10
	end
	return n
end

# "ADA-USD"
function get_data(product_id)
	df = get_15min_candles(product_id)
	mxp = maximum(df[!, :high])
	ndp = decimals(mxp)
	mxv = maximum(df[!, :volume])
	ndv = decimals(mxv)
	d = (ndv - ndp) 
	if d > 0
		df[!, :volume] ./= 10^d
	else
		d = 0
	end
	CSV.write("DATA/$product_id.csv", df)
	open("DATA/$product_id.exp", "w") do f
		write(f, string(d))
	end
end

# "ADA-USD"
function make_batches(product_id, period)
	df = DataFrame(CSV.File("DATA/$product_id.csv"))
	in_size = out_size = 5
	nsamples = length(period:nrow(df)-1)
	xdata = zeros(Float32, period, in_size, nsamples)
	ydata = zeros(Float32, period, out_size, nsamples)
	
	for (i, idx) in enumerate(period:nrow(df)-1)
		xs = Matrix{Float32}(df[idx-period+1:idx, 2:end])
		ys = Matrix{Float32}(df[idx-period+2:idx+1, 2:end])
		xdata[:, :, i] .= xs
		ydata[:, :, i] .= ys
    end

	jldopen("Data/$(product_id)_$(period).jld2", "w") do file
	    file["data/xdata"] = xdata
	    file["data/ydata"] = ydata
	end
end

end # module