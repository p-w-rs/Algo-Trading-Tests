using Flux, JLD2, BSON
using Flux: mae, mse
using Random: shuffle
using ProgressMeter

function load_data()
    train_loader, test_loader = (nothing, nothing)
    jldopen("Data/$(ARGS[1])_$(ARGS[2]).jld2", "r") do file
        xdata = file["data/xdata"]
        ydata = file["data/ydata"]
        n = size(xdata, 3)
        idxs = shuffle(1:n)
        tr_idxs = idxs[1:Int(round(n*0.8))]
        ts_idxs = idxs[length(tr_idxs)+1:end]
        train_loader = Flux.Data.DataLoader(
        	(xdata[:, :, tr_idxs], ydata[:, :, tr_idxs]),
        	batchsize=64, shuffle=true
        )
        test_loader = Flux.Data.DataLoader(
        	(xdata[:, :, ts_idxs], ydata[:, :, ts_idxs]),
        	batchsize=64, shuffle=true
        )
    end
    return train_loader, test_loader
end

function create_model()
	return Chain(
		LSTM(5, 128),
        LSTM(128, 128),
        LSTM(128, 128),
        Dense(128, 5)
	)
end

function loss(data_loader, model)
    ls = 0.0
    n = 0
    period = parse(Int64, ARGS[2])
    @showprogress for (xs, ys) in data_loader
        Flux.reset!(model)
    	yŝ = similar(ys)
    	for i in 1:period
    		yŝ[i, :, :] .= model(xs[i, :, :])
    	end
        ls += mae(yŝ, ys)
        n += 1
    end
    return ls / n
end

function train()
    train_loader, test_loader = load_data()
    model = create_model()
    ps = Flux.params(model)
    opt = NADAM()

    period = parse(Int64, ARGS[2])
    for epoch in 1:1000
        @showprogress for (xs, ys) in train_loader
        	Flux.reset!(model)
        	yŝ = similar(ys)
        	for i in 1:period
        		yŝ[i, :, :] .= model(xs[i, :, :])
        	end
            gs = gradient(() -> mse(yŝ, ys), ps)
            Flux.Optimise.update!(opt, ps, gs)
        end
        
        #train_loss = loss(train_loader, model)
        test_loss = loss(test_loader, model)
        println("Epoch=$epoch")
        #println("  train_loss = $train_loss")
        println("  test_loss = $test_loss")
    end
end

train()