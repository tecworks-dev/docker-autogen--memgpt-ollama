# Work in progress. V0.1
# ALL THE THINGS.
ARG     APT_PROXY         #=http://apt-cacher-ng.lan:3142/
ARG     PIP_INDEX_URL     #=http://devpi.lan:3141/root/pypi/+simple
ARG     PIP_TRUSTED_HOST  #=devpi.lan
ARG     JUPYTER_PORT=37799
ARG     LITELLM_PORT=11111

FROM    nvidia/cuda:11.8.0-devel-ubuntu22.04 as build-llama

ARG     APT_PROXY
ENV     APT_PROXY=$APT_PROXY
ARG     TARGETARCH=amd64
ENV     GOARCH=$TARGETARCH
ARG     GOFLAGS="'-ldflags=-w -s'"
ENV     GOFLAGS=$GOFLAGS

ADD     https://dl.google.com/go/go1.21.3.linux-$TARGETARCH.tar.gz /tmp/go1.21.3.tar.gz
WORKDIR /go/src/github.com/jmorganca/ollama
RUN     if [ -z "${APT_PROXY}" ]; then echo "Acquire::Http::Proxy {\"${APT_PROXY}\";}" >/etc/apt/apt.conf.d/02-proxy ; fi; \
        apt update && \
        apt upgrade -qy && \
        apt install -qy \
            git cmake build-essential \
            && \
        apt autoclean && \
        rm -rf /var/lib/apt/lists/* && \
        mkdir -p /usr/local && \
        tar xz -C /usr/local </tmp/go1.21.3.tar.gz && rm /tmp/go1.*.tar.gz && \
        mkdir -p /go/src/github.com/jmorganca && \
        cd /go/src/github.com/jmorganca && \
        git clone --recurse-submodules https://github.com/jmorganca/ollama.git

RUN     /usr/local/go/bin/go generate ./... && \
        /usr/local/go/bin/go build .

################################################################################
# Create a final stage for running your application.
#
# The following commands copy the output from the "build" stage above and tell
# the container runtime to execute it when the image is run. Ideally this stage
# contains the minimal runtime dependencies for the application as to produce
# the smallest image possible. This often means using a different and smaller
# image than the one used for building the application, but for illustrative
# purposes the "base" image is used here.
FROM    ubuntu:22.04 as packages
ARG     APT_PROXY
RUN     if [ -z "${APT_PROXY}" ]; then echo "Acquire::Http::Proxy {\"${APT_PROXY}\";}" >/etc/apt/apt.conf.d/02-proxy ; fi; \
        apt update && \
        apt upgrade -qy && \
        apt install -qy \
            vim git curl wget python3 python-is-python3 python3-venv python3-pip  \
            && \
        apt autoclean && \
        rm -rf /var/lib/apt/lists/* && \
        rm -f /etc/apt/apt.conf.d/02-proxy

WORKDIR /workspace
ARG     PIP_INDEX_URL
ENV     PIP_INDEX_URL=$PIP_INDEX_URL
ARG     PIP_TRUSTED_HOST
ENV     PIP_TRUSTED_HOST=$PIP_TRUSTED_HOST
RUN     python -m venv venv && \
        . venv/bin/activate && \
        pip install --no-cache pyautogen pymemgpt jupyter numpy pandas pyyaml && \
        deactivate

FROM    packages AS litellm_prep
ARG     PIP_INDEX_URL
ENV     PIP_INDEX_URL=$PIP_INDEX_URL
ARG     PIP_TRUSTED_HOST
ENV     PIP_TRUSTED_HOST=$PIP_TRUSTED_HOST
RUN     git clone https://github.com/BerriAI/litellm.git /app && rm -rf /app/dist
WORKDIR /app
RUN     if [ -z "${PIP_INDEX_URL}" ]; then pip config set global.index-url "${PIP_INDEX_URL}"; fi; \
        if [ -z "${PIP_TRUSTED_HOST}" ]; then pip config set global.trusted-host "${PIP_TRUSTED_HOST}"; fi; \
        python -m venv venv && \
        . venv/bin/activate && \
        pip install --no-cache -r requirements.txt pyyaml && \
        deactivate

FROM    litellm_prep as final
ARG     JUPYTER_PORT
ENV     JUPYTER_PORT=$JUPYTER_PORT
ARG     LITELLM_PORT
ENV     LITELLM_PORT=$LITELLM_PORT

WORKDIR /workspace

COPY    --from=build-llama /go/src/github.com/jmorganca/ollama/ollama /usr/bin/ollama
COPY    start.sh .
COPY    ollama.yaml .
RUN     chmod +x start.sh

EXPOSE  $JUPYTER_PORT
EXPOSE  $LITELLM_PORT
