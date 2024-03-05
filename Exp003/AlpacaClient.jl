module AlpacaClient

export get_account, market_order, list_all_orders, list_open_orders, list_closed_orders, cancel_all_orders, cancel_order, get_bars

using HTTP, JSON, StringEncodings, DataFrames, Dates

############################################# ===== CONSTANTS ===== ##############################################
const APCA_API_ORDER_URL = "https://paper-api.alpaca.markets/v2"
const APCA_API_MARKET_URL = "https://data.alpaca.markets/v2"
const APCA_API_KEY_ID = "PKQD0KDACTOF27CDJGPT"
const APCA_API_SECRET_KEY = "YKHfm0CxdFQuf16tD1H9Rve7LTYRoRT5jAZSvlzy"

const STD_HEADERS = Dict(
	"APCA-API-KEY-ID" => "$APCA_API_KEY_ID",
	"APCA-API-SECRET-KEY" => "$APCA_API_SECRET_KEY",
	"Connection" => "close"
)

############################################# ===== HELPERS ===== ##############################################
function convert_to_num(x)
	ret = tryparse(Int64, x)
	if isa(ret, Number)
		return ret
	end
	ret = tryparse(Float64, x)
	if isa(ret, Number)
		return ret
	end
	return x
end



############################################# ===== BASIC ===== ##############################################
function get_account()
	try
		r = HTTP.request("GET", "$APCA_API_ORDER_URL/account", STD_HEADERS)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end



############################################# ===== ORDERS ===== ##############################################
### MAKING ORDERS ###
function market_order_notional(id, dollars, side)
	order = Dict("symbol" => id, "notional" => "$dollars", "side" => side, "type" => "market", "time_in_force" => "day")
	try
		r = HTTP.request("POST", "$APCA_API_ORDER_URL/orders", STD_HEADERS, JSON.json(order))
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function market_order_qty(id, qty, side)
	order = Dict("symbol" => id, "notional" => "$dollars", "side" => side, "type" => "market", "time_in_force" => "day")
	try
		r = HTTP.request("POST", "$APCA_API_ORDER_URL/orders", STD_HEADERS, JSON.json(order))
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function limit_order(id, qty, limit_price, side)
	order = Dict("symbol" => id, "qty" => "$qty", "limit_price" => "$limit_price", "side" => side, "type" => "limit", "time_in_force" => "day")
	try
		r = HTTP.request("POST", "$APCA_API_ORDER_URL/orders", STD_HEADERS, JSON.json(order))
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

### GETTING ORDERS ###
function get_orders(id)
	try
		r = HTTP.request("GET", "$APCA_API_ORDER_URL/orders", STD_HEADERS; query="symbols=$id")
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function list_all_orders()
	try
		r = HTTP.request("GET", "$APCA_API_ORDER_URL/orders", STD_HEADERS)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function list_open_orders()
	try
		r = HTTP.request(
			"GET", "$APCA_API_ORDER_URL/orders", STD_HEADERS;
			query="status=open"
		)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function list_closed_orders()
	try
		r = HTTP.request(
			"GET", "$APCA_API_ORDER_URL/orders", STD_HEADERS;
			query="status=closed"
		)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

### CANCEL ORDERS ###
function cancel_all_orders()
	try
		r = HTTP.request("DELETE", "$APCA_API_ORDER_URL/orders", STD_HEADERS)
		return JSON.parse(decode(r.body, "UTF-8"))
	catch err
		println(err)
		return -1
	end
end

function cancel_order(id)
	try
		r = HTTP.request("DELETE", "$APCA_API_ORDER_URL/orders/$id", STD_HEADERS)
		return r.status #should be 204 for success 422 for failure
	catch err
		println(err)
		return -1
	end
end



############################################# ===== HELPERS ===== ##############################################
### Getting Bar Data ###
function get_bars(id, start_t, end_t, timeframe; limit=10000)
	# id is the stock tag (i.e. AAPL)
	# start_t is the first date to get data from as a RFC-3339 string
	# end_t is the last date to get data from as a RFC-3339 string
	# timeframe can be 1Min, 15Min, 1Hour, 1Day
	# limit can be 1-10000
	query = "start=$start_t&end=$end_t&limit=$limit&timeframe=$timeframe"
	try
		r = HTTP.request(
			"GET", "$APCA_API_MARKET_URL/stocks/$id/bars", STD_HEADERS;
			query=query
		)
		js = JSON.parse(decode(r.body, "UTF-8"))
		bars = js["bars"]
		while js["next_page_token"] != nothing
			query_w_token = query * "&page_token=$(js["next_page_token"])"
			r = HTTP.request(
				"GET", "$APCA_API_MARKET_URL/stocks/$id/bars", STD_HEADERS;
				query=query_w_token
			)
			js = JSON.parse(decode(r.body, "UTF-8"))
			bars = vcat(bars, js["bars"])
		end
		return reduce(vcat, DataFrame.(bars))
	catch err
		println(err)
		return -1
	end
end

end # module