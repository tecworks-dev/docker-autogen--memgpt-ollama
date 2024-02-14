#! /bin/bash

# Start ollama
cd /workspace
ollama serve &
sleep 2
ollama pull vicuna:7b-16k

# Start litellm, which wants its own venv so the openai module
# doesn't conflict with MemGPTs.
cd /app
. ./venv/bin/activate
hash -r
pip install -r requirements.txt fastapi tomli tomli_w backoff pyyaml
litellm --config /workspace/ollama.yaml --port ${LITELLM_PORT} &
deactivate

# Start jupyter notebook
cd /workspace
. /workspace/venv/bin/activate
#jupyter notebook --ip 0.0.0.0 --port ${JUPYTER_PORT} --allow-root --NotebookApp.token='' --NotebookApp.password='MyLlms' &

#wait
