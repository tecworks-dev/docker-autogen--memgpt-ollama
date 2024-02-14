Suggested command line (for this early incomplete version):

docker build --tag ollama-litellm-memgpt 
docker run -d --gpus=all -v ollama:/root/.ollama --name litellm -p 37799:37799 -p 11111:11111 ollama-litellm-memgpt ./start.sh

Port 11111 is the litellm api, 37799 is the Jupyter notebook API, password MyJupyter

NOTE: I have the model in start.sh set to vicuna:7b-16k, but litellm doesn't know about this model yet (I'm experimenting with my own branch of litellm)
