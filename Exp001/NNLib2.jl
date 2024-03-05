module NNLib

export Network, set_params!, reset!

cType = NamedTuple{(:W, :b, :η, :A, :B),Tuple{Array{Float64,2},Array{Float64,1},Array{Float64,2},Array{Float64,2},Array{Float64,2}}}
struct Network
    dims::Vector{Int}
    depth::UnitRange{Int64}
    x::Vector{Vector{Float64}}
    o::Vector{Vector{Float64}}
    cMatrix::Matrix{cType}
    n_trainable_params::Int64
    σ::Function
end

function Network(dims::Vector{Int}, σ::Function; type=Float64)
    depth = length(dims)
    cMatrix = Matrix{cType}(undef, depth, depth)
    x = Vector{Vector{Float64}}(undef, depth)
    o = Vector{Vector{Float64}}(undef, depth)
    n_trainable_params = 0
    
    for (i, from) in enumerate(dims)
        x[i] = zeros(type, from); o[i] = zeros(type, from);
        for (j, to) in enumerate(dims)
            i == j && continue # a neurons doesn't connect directly to itself
            W = randn(type, to, from) .* 0.01
            b = zeros(type, to)
            η = randn(type, to, from) .* 0.01
            A = randn(type, to, from) .* 0.01
            B = randn(type, to, from) .* 0.01

            cMatrix[i, j] = (W=W, b=b, η=η, A=A, B=B)
            n_trainable_params += (to + (3*(to*from)))
        end
    end

    return Network(dims, 1:depth, x, o, cMatrix, n_trainable_params, σ)
end

function set_params!(nn::Network, params::Vector{Float64})
    @assert length(params) == nn.n_trainable_params; idx = 1
    for (i, from) in enumerate(nn.dims)
        nn.x[i] = zeros(Float64, from); nn.o[i] = zeros(Float64, from);
        for (j, to) in enumerate(nn.dims)
            i == j && continue
            W = randn(Float64, to, from) .* 0.01
            b = params[idx:idx+to-1]; idx += to
            η = reshape(params[idx:idx+(to*from)-1], (to, from)); idx += (to*from)
            A = reshape(params[idx:idx+(to*from)-1], (to, from)); idx += (to*from)
            B = reshape(params[idx:idx+(to*from)-1], (to, from)); idx += (to*from)

            nn.cMatrix[i, j] = (W=W, b=b, η=η, A=A, B=B)
        end
    end
end

function reset!(nn::Network)
    for (i, from) in enumerate(nn.dims)
        nn.x[i] = zeros(Float64, from); nn.o[i] = zeros(Float64, from);
        for (j, to) in enumerate(nn.dims)
            i == j && continue
            nn.cMatrix[i, j].W .= randn(Float64, to, from) .* 0.01
        end
    end
end

function (nn::Network)(x::Vector{Float64})
    # Signal to input neurons
    nn.x[1] .+= x

    # Forward network pass
    for i in nn.depth
        nn.o[i] .= nn.x[i]; nn.x[i] .= 0.0;
        for j in setdiff(nn.depth, i)
            nn.x[j] .+= nn.σ.((nn.cMatrix[i, j].W * nn.o[i]) .+ nn.cMatrix[i, j].b)
        end
    end

    # Hebbian Learning updates
    for i in nn.depth
        for j in setdiff(nn.depth, i)
            W, b, η, A, B = nn.cMatrix[i, j]
            for w_i in 1:size(nn.cMatrix[i, j].W, 1)
                for w_j in 1:size(nn.cMatrix[i, j].W, 2)
                    W[w_i, w_j] += η[w_i, w_j] * (
                        (A[w_i, w_j] * nn.o[i][w_j] * nn.o[j][w_i]) + (B[w_i, w_j] * W[w_i, w_j])
                    )
                end
            end
        end
    end
    
    # Signal from output neurons
    return nn.o[end]
end

end # module
