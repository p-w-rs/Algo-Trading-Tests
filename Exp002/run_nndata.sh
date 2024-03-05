#!/bin/bash

#SBATCH --job-name="lstm_etfs"
#SBATCH --output=job_%j.out
#SBATCH --mail-type=ALL
#SBATCH --mail-user=powersj@msoe.edu
#SBATCH --partition=teaching
#SBATCH --nodes=1
#SBATCH --gres=gpu:t4:1
#SBATCH --cpus-per-gpu=40
#SBATCH --mem=64GB

## SCRIPT START

julia nnData.jl etfs 96 96
julia nnData.jl etfs 96 72
julia nnData.jl etfs 96 48
julia nnData.jl etfs 96 24

julia nnData.jl sp500 96 96
julia nnData.jl sp500 96 72
julia nnData.jl sp500 96 48
julia nnData.jl sp500 96 24

## SCRIPT END