#!/bin/bash

#SBATCH --job-name="lstm_sp"
#SBATCH --output=job_%j.out
#SBATCH --mail-type=ALL
#SBATCH --mail-user=powersj@msoe.edu
#SBATCH --partition=teaching
#SBATCH --nodes=1
#SBATCH --gres=gpu:t4:1
#SBATCH --cpus-per-gpu=16
#SBATCH --mem=96GB

## SCRIPT START

julia snrnn.jl sp500

## SCRIPT END