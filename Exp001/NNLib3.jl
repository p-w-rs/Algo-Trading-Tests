module NNLib

export Network, set_params!

cType = NamedTuple{(:W, :b, :η, :A, :B, :C, :D),Tuple{Array{Float64,2},Array{Float64,1},Array{Float64,2},Array{Float64,2},Array{Float64,2},Array{Float64,2},Array{Float64,2}}}
struct Network
    dims::Vector{Int}
    depth::UnitRange{Int64}
    o::Vector{Vector{Float64}}
    cLayers::Vector{cType}
    n_trainable_params::Int64
    σ::Function
end

function Network(dims::Vector{Int}, σ::Function; type=Float64)
    depth = length(dims)
    cLayers = Vector{cType}()
    o = Vector{Vector{Float64}}()
    n_trainable_params = 0

    for dim in dims
        push!(o, zeros(type, dim))
    end
    
    for (i, from) in enumerate(dims[1:end-1])
        to = dims[i+1]
        W = randn(type, to, from) .* 0.01
        b = zeros(type, to)
        η = randn(type, to, from) .* 0.01
        A = randn(type, to, from) .* 0.01
        B = randn(type, to, from) .* 0.01
        C = randn(type, to, from) .* 0.01
        D = randn(type, to, from) .* 0.01

        push!(cLayers, (W=W, b=b, η=η, A=A, B=B, C=C, D=D))
        #n_trainable_params += (to + (6*(to*from)))
        n_trainable_params += 5*(to*from)
    end

    return Network(dims, 1:depth-1, o, cLayers, n_trainable_params, σ)
end

function set_params!(nn::Network, params::Vector{Float64})
    @assert length(params) == nn.n_trainable_params; idx = 1
    for (i, from) in enumerate(nn.dims[1:end-1])
        to = nn.dims[i+1]
        #W = reshape(params[idx:idx+(to*from)-1], (to, from)); idx += (to*from)
        #b = params[idx:idx+to-1]; idx += to
        W = randn(Float64, to, from) .* 0.01
        b = zeros(Float64, to)
        η = reshape(params[idx:idx+(to*from)-1], (to, from)); idx += (to*from)
        A = reshape(params[idx:idx+(to*from)-1], (to, from)); idx += (to*from)
        B = reshape(params[idx:idx+(to*from)-1], (to, from)); idx += (to*from)
        C = reshape(params[idx:idx+(to*from)-1], (to, from)); idx += (to*from)
        D = reshape(params[idx:idx+(to*from)-1], (to, from)); idx += (to*from)
        nn.cLayers[i] = (W=W, b=b, η=η, A=A, B=B, C=C, D=D)
    end
end

function (nn::Network)(x::Vector{Float64})
    # Signal to input neurons
    nn.o[1] = x

    for i in nn.depth
        # Forward network pass
        nn.o[i+1] = nn.σ.(nn.cLayers[i].W * nn.o[i])

        # Hebbian Learning updates
        W, b, η, A, B, C, D = nn.cLayers[i]
        for w_i in 1:size(W, 1)
            for w_j in 1:size(W, 2)
                W[w_i, w_j] += η[w_i, w_j] * (
                    (A[w_i, w_j] * nn.o[i][w_j] * nn.o[i+1][w_i]) +
                    (B[w_i, w_j] * nn.o[i][w_j]) +
                    (C[w_i, w_j] * nn.o[i+1][w_i]) +
                     D[w_i, w_j]
                )
            end
        end

    end
    
    # Signal from output neurons
    return nn.o[end]
end

end # module
