#!/bin/bash

# Build the Docker image
docker build -t img .

# Run the Docker container with the necessary arguments
docker run --env-file .env --rm --gpus "device=0" img 