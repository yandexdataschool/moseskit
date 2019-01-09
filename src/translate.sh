#!/bin/bash

lang_src=en
lang_dst=ru

num_threads=24

shared=/home/moses/shared
#^-- container's path to directory shared with host

# paths to translate files and trained model files
data_path=$shared/to_translate/
model_path=$shared/model

#################################################
#                END OF CONFIG                  #
#################################################
#cast to abspaths just in case user defined relative paths
data_path=`realpath $data_path`
model_path=`realpath $model_path`

cd /home/moses/mosesdecoder

# prepare data : tokenize, lowercase, etc
function preprocess {
    cat $inp | iconv -c --from UTF-8 --to UTF-8 | \
        ./scripts/tokenizer/lowercase.perl | \
        ./scripts/tokenizer/tokenizer.perl -l $lang \
      > $out
}

for src_file in $data_path/*.$lang_src
do
    translated_file=$src_file.translated.$lang_dst
    inp=$src_file out=$src_file.tok lang=$lang_src preprocess

    ./bin/moses -f $model_path/moses.ini \
            -threads $num_threads -mp -search-algorithm 1 -cube-pruning-pop-limit 1000 -s 1000 \
            -feature-overwrite 'TranslationModel0 table-limit=100' -max-trans-opt-per-coverage 100 \
            < $src_file.tok > $translated_file

done

chmod -R 777 $data_path

