module Coinbase

using PyCall
cbpro = pyimport("coinbasepro")

export authorize, get_last_fill, balance_usd, balance_id, price_volume, buy_crypto_coin, sell_crypto_coin

#ADA
const API_KEY = "6a0be93271a885df50a45b875b4e8b47"
const API_SECRET = "et0vrYf7YbVrudkkCoXYeYxvl4hULKnlAKjgaz3xWX5/QtwIb7vA+u9r3GGeOZy+E9CO2EgY3rryTAC0DCtr5Q=="
const API_PASS = "akukmtnwxvo"

function min_digit(value)
    i = 0
    v = value
    while v < 1
        v *= 10
        i += 1
    end
    return i
end

function cur_digits(value)
    s = split(string(value), ".")
    if length(s) == 2
        return lenght(s[2])
    else
        return 0
    end
end

function authorize()
    auth_client = cbpro.AuthenticatedClient(API_KEY, API_SECRET, API_PASS)
    accounts = auth_client.get_accounts()
end

function get_last_fill(id)
    auth_client = cbpro.AuthenticatedClient(API_KEY, API_SECRET, API_PASS)
    fills = collect(auth_client.get_fills(id))
    if isempty(fills)
        return 0
    end
    last_fill = fills[1]
    if last_fill["side"] == "buy"
        #parse(Float64, last_fill["price"].to_eng_string())
        return 1
    elseif last_fill["side"] == "sell"
        #parse(Float64, last_fill["price"].to_eng_string())
        return 0
    end
end

function balance_usd()
    auth_client = cbpro.AuthenticatedClient(API_KEY, API_SECRET, API_PASS)
    accounts = auth_client.get_accounts()
    for i in 1:length(accounts)
        if accounts[i]["currency"] == "USD"
            return parse(Float64, accounts[i]["balance"].to_eng_string())
        end
    end
    return 0
end

function balance_id(id)
    auth_client = cbpro.AuthenticatedClient(API_KEY, API_SECRET, API_PASS)
    accounts = auth_client.get_accounts()
    id_balance = 0
    for i in 1:length(accounts)
        if accounts[i]["currency"] == split(id, "-")[1]
            id_balance = parse(Float64, accounts[i]["balance"].to_eng_string())
        end
    end
    return id_balance
end

function cur_price(id)
    client = cbpro.PublicClient()
    tic = client.get_product_ticker(id)
    price = parse(Float64, tic["price"].to_eng_string())
    return price
end

function buy_crypto_coin(id, price, usd)
    auth_client = cbpro.AuthenticatedClient(API_KEY, API_SECRET, API_PASS)
    auth_client.place_limit_order(
        product_id=id,
        side="buy",
        price=string(price),
        size=string(floor(usd/price, digits=0)),
        time_in_force="GTT",
        cancel_after="min"
    )
end

function sell_crypto_coin(id, price)
    auth_client = cbpro.AuthenticatedClient(API_KEY, API_SECRET, API_PASS)
    accounts = auth_client.get_accounts()
    id_balance = 0
    for i in 1:length(accounts)
        if accounts[i]["currency"] == split(id, "-")[1]
            id_balance = parse(Float64, accounts[i]["balance"].to_eng_string())
        end
    end
    id_balance <= 0 && return
    
    client = cbpro.PublicClient()
    tic = client.get_product_ticker(id)
    price = parse(Float64, tic["price"].to_eng_string())
    amount = floor(id_balance, digits=min_digit(2.0/price))
    auth_client.place_limit_order(
        product_id=id,
        side="sell",
        price=string(price),
        size=string(floor(amount, digits=0)),
        time_in_force="GTT",
        cancel_after="min"
    )
end

end # module