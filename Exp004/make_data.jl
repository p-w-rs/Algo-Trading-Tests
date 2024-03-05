include("coinbase.jl")
using .CoinbaseAPI

product_id = ARGS[1]
period = parse(Int64, ARGS[2])
get_data(product_id)
make_batches(product_id, period)
