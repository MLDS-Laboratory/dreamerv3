#!/bin/bash

trap 'pkill -f "taskset.*dreamerv3/main.py"' EXIT SIGINT SIGTERM

declare -A envs=(
    [dmc_proprio]=dmc_cartpole_balance
)
betas=(-0.010 -0.005 -0.001 0.000 0.001 0.005 0.010)
seeds=(21 42 63 84 105)
steps=100000

MAX_PARALLEL=2
AVAILABLE_GPUS=(0 1)
gpu_index=0

for configs in "${!envs[@]}"; do
    for beta in "${betas[@]}"; do
        for seed in "${seeds[@]}"; do
            CUDA_DEVICE=${AVAILABLE_GPUS[$gpu_index]}
            LEAST_UTILIZED_CPU=$(mpstat -P ALL 1 1 | awk '$2 ~ /^[0-9]+$/ {print $2,$12}' | sort -k2 -nr | head -1 | awk '{print $1}')
            gpu_index=$(( (gpu_index + 1) % ${#AVAILABLE_GPUS[@]} ))

            echo "Launching: seed=$seed, beta=$beta, env=$env_id on CPU=$LEAST_UTILIZED_CPU and GPU=$CUDA_DEVICE"

            CUDA_VISIBLE_DEVICES=$CUDA_DEVICE \
            nohup taskset -c "$LEAST_UTILIZED_CPU" \
            python dreamerv3/main.py \
            --configs "$configs" \
            --task "${envs[$configs]}" \
            --logdir "${envs[$configs]}/$beta/$seed" \
            --seed $seed \
            --run.steps $steps \
            --agent.beta $beta \
            --logger.outputs "wandb" &
            
            while (( $(jobs -r | wc -l) >= MAX_PARALLEL )); do
                sleep 1
            done
        done
    done
done



