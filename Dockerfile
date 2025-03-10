# docker build -f Dockerfile -t img . && \
# docker run -it --rm -v ~/logdir/docker:/logdir img \
#   python main.py --logdir /logdir/{timestamp} --configs minecraft debug --task minecraft_diamond_k

# System
FROM ghcr.io/nvidia/driver:56b85890-550.90.07-ubuntu22.04
# FROM ghcr.io/nvidia/driver:dbcd761b-550.90.12-ubuntu24.04  # DMLab build fails on Ubuntu 24
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/San_Francisco
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1
ENV PIP_ROOT_USER_ACTION=ignore
RUN apt-get update && apt-get install -y \
  ffmpeg git vim curl software-properties-common grep \
  libglew-dev x11-xserver-utils xvfb wget \
  && apt-get clean

# Python
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt-get update && apt-get install -y python3.11-dev python3.11-venv && apt-get clean
RUN python3.11 -m venv /venv --upgrade-deps
ENV PATH="/venv/bin:$PATH"
RUN pip install --upgrade pip setuptools

# Envs
# RUN wget -O - https://gist.github.com/danijar/ca6ab917188d2e081a8253b3ca5c36d3/raw/install-dmlab.sh | sh
RUN pip install ale_py autorom[accept-rom-license]
RUN pip install procgen_mirror
RUN pip install crafter
RUN pip install dm_control
RUN pip install memory_maze
ENV MUJOCO_GL=egl
RUN apt-get update && apt-get install -y openjdk-8-jdk && apt-get clean
RUN pip install https://github.com/danijar/minerl/releases/download/v0.4.4-patched/minerl_mirror-0.4.4-cp311-cp311-linux_x86_64.whl
# RUN pip install git+https://github.com/minerllabs/minerl@7f2a2cba6ca6
RUN chown -R 1000:root /venv/lib/python3.11/site-packages/minerl
RUN git clone https://github.com/eilab-gt/NovGrid.git
RUN cd NovGrid && pip install -e .
# Requirements
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt
# RUN pip install -r requirements.txt -f https://storage.googleapis.com/jax-releases/jax_nightly_releases.html

# Source
RUN mkdir /app
WORKDIR /app
COPY . .
RUN chown -R 1000:root .

# Cloud
ENV GCS_RESOLVE_REFRESH_SECS=60
ENV GCS_REQUEST_CONNECTION_TIMEOUT_SECS=300
ENV GCS_METADATA_REQUEST_TIMEOUT_SECS=300
ENV GCS_READ_REQUEST_TIMEOUT_SECS=300
ENV GCS_WRITE_REQUEST_TIMEOUT_SECS=600

ENV JAX_TRACEBACK_FILTERING=off

# Wandb
ENV WANDB_PROJECT=fixed-beta-dreamer

# # NovGrid
# ENTRYPOINT ["python", \
#             "dreamerv3/main.py", \ 
#             "--logdir", "dreamer/novgrid_custom_cart_pole", \
#             "--configs", "novgrid", \ 
#             "--task", "novgrid_custom_cart_pole", \
#             "--logger.outputs", "wandb"]

# # Acrobot
# ENTRYPOINT ["python", \
#             "dreamerv3/main.py", \ 
#             "--logdir", "dreamer/gym_Acrobot-v1", \
#             "--configs", "gym", \ 
#             "--task", "gym_Acrobot-v1", \
#             "--logger.outputs", "wandb"]

# # CartPole
# ENTRYPOINT ["python", \
#             "dreamerv3/main.py", \ 
#             "--logdir", "dreamer/rs/gym_CartPole-v1", \
#             "--configs", "gym", \ 
#             "--task", "gym_CartPole-v1", \
#             "--logger.outputs", "wandb"]

# CartPole DMC
ENTRYPOINT ["python", \
            "dreamerv3/main.py", \ 
            "--logdir", "dreamer/dmc_cartpole_balance", \
            "--configs", "dmc_proprio", \ 
            "--task", "dmc_cartpole_balance", \
            "--logger.outputs", "wandb"]

  
# # Walker
# ENTRYPOINT ["python", \
#             "dreamerv3/main.py", \ 
#             "--logdir", "dreamer/vanilla/dmc_walker_walk", \
#             "--configs", "dmc_proprio", \ 
#             "--task", "dmc_walker_walk", \
#             "--logger.outputs", "wandb"]
