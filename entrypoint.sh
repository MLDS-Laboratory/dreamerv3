#!/bin/bash

# Build the Docker image
docker build -t img .

# Run the Docker container with the necessary arguments
docker run --env-file .env --rm --gpus "device=0" -v "$PWD:/app" -v "$PWD/logdir:/app/logdir" img 