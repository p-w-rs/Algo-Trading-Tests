using Flux, JLD2, CUDA, ProgressMeter, Random, Plots

const device = CUDA.functional() ? gpu : cpu
const inputsize = 7+6
const poollength = 128
const horizon = 128

errors = nothing
ysVys = nothing
jldopen("results_etfs.jld2", "r") do f
    global errors, ysVys
    errors = f["errors"]
    ysVys = f["ysVys"]
end

for i in 1:length(ysVys)
    ŷs, ys = ysVys[i]
    train_err = errors[i, 1]
    test_err = errors[i, 2]
    p1 = plot(ŷs, label="Predict")
    p1 = plot!(ys, label="Data", title="Train Loss $train_err\nTest Loss $test_err")
    display(plot(p1))
    sleep(1)
end
