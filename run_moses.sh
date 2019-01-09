#!/bin/bash

# default argv
MODE="${1:-train}"
DATA_PATH="${2:-`pwd`}"

container=justheuristic/vsyo_ty_moses:latest 

if [ "$MODE" == "train" ]; then
    docker run -it -v `realpath $DATA_PATH`:/home/moses/shared $container /home/moses/shared/src/train_and_translate.sh
elif [ "$MODE" == "translate" ]; then
    docker run -it -v `realpath $DATA_PATH`:/home/moses/shared $container /home/moses/shared/src/translate.sh 
elif [ "$MODE" == "bash" ]; then
    docker run -it -v `realpath $DATA_PATH`:/home/moses/shared $container bash
elif [ "$MODE" == "jupyter" ]; then
    docker run -it -v `realpath $DATA_PATH`:/home/moses/shared -p 8080:8888 $container /home/moses/shared/src/run_jupyter.sh
else
    echo "unknown mode: $MODE";
fi
