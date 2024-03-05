#!/bin/bash

#SBATCH --job-name="lstm_etfs"
#SBATCH --output=job_%j.out
#SBATCH --mail-type=ALL
#SBATCH --mail-user=powersj@msoe.edu
#SBATCH --partition=teaching
#SBATCH --nodes=1
#SBATCH --gres=gpu:t4:1
#SBATCH --cpus-per-gpu=16
#SBATCH --mem=64GB

## SCRIPT START

julia snrnn.jl etfs

## SCRIPT END