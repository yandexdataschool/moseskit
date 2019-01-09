#!/bin/bash

lang_src=en
lang_dst=ru
min_len=1
max_len=100

lm_order=5
# ^-- the N for N-gram language model

train=true
# ^-- if false, reuses pre-trained model

tokenize=true
# ^-- if false, assumes data is already tokenized

use_srilm=true
# ^-- if true, uses srilm (with some extra features like mixing several lms). otherwise uses kenlm (default for moses)

prune_pt=true
# ^-- if true, prunes phrase table after training (but before tuning). max_len must be < 256
# this saves a lot of RAM during translation but slightly decreases model quality

tuning_lines=4000
# ^-- takes this many random lines from train to tune weights of translation table Vs language movel Vs etc.

num_threads=24
# ^-- uses this many CPU cores when training

giza_parts=20
sort_buffer_size=10G
seed=42

shared=/home/moses/shared
#^-- container's path to directory shared with host

# train data
train_raw_src=$shared/data/train.raw.$lang_src
train_raw_dst=$shared/data/train.raw.$lang_dst


# output paths to metadata and trained model files
data_path=$shared/data
model_path=$shared/model

#################################################
#                END OF CONFIG                  #
#################################################
mkdir -p $data_path $model_path

#cast to abspaths just in case user defined relative paths
data_path=`realpath $data_path`
model_path=`realpath $model_path`

cd /home/moses/mosesdecoder

# prepare data : tokenize, lowercase, etc
function preprocess {
    cat $inp | iconv -c --from UTF-8 --to UTF-8 | \
        ./scripts/tokenizer/lowercase.perl | \
        ./scripts/tokenizer/tokenizer.perl -l $lang -threads $num_threads \
      > $out
}
get_random_source(){
    openssl enc -aes-256-ctr -pass pass:"$1" -nosalt </dev/zero 2>/dev/null
}

if [ "$tokenize" = true ] ; then
    inp=$train_raw_src out=$data_path/train.tok.$lang_src lang=$lang_src preprocess
    inp=$train_raw_dst out=$data_path/train.tok.$lang_dst lang=$lang_dst preprocess

    # prune too short / too long sentence pairs
    ./scripts/training/clean-corpus-n.perl \
        $data_path/train.tok $lang_src $lang_dst $data_path/train.clean $min_len $max_len
    
    shuf -o $data_path/train.shuf.$lang_src --random-source=<(get_random_source $seed ) $data_path/train.clean.$lang_src
    shuf -o $data_path/train.shuf.$lang_dst --random-source=<(get_random_source $seed ) $data_path/train.clean.$lang_dst

    # split into pt training and tuning
    read train_lines filename <<< $(wc -l $data_path/train.clean.$lang_src)
    main_train_lines=`expr $train_lines - $tuning_lines`

    head -n $main_train_lines $data_path/train.shuf.$lang_src > $data_path/train.main.$lang_src
    tail -n $tuning_lines $data_path/train.shuf.$lang_src > $data_path/train.tuning.$lang_src
    head -n $main_train_lines $data_path/train.shuf.$lang_dst > $data_path/train.main.$lang_dst
    tail -n $tuning_lines $data_path/train.shuf.$lang_dst > $data_path/train.tuning.$lang_dst

fi    

if [ "$train" = true ] ; then
    # clean files to prevent reusing cached results from other corpora
    rm -rf ./corpus ./giza.* ./mert-work &> /dev/null

    # train language model
    lm_raw_path=$model_path/lm.arpa
    lm_path=$model_path/lm.binary
    
    if [ "$use_srilm" = true ] ; then
        /home/moses/srilm/lm/bin/i686-m64/ngram-count -text $data_path/train.main.$lang_dst -lm $lm_raw_path -interpolate -kndiscount
    else
        # kenlm
        ./bin/lmplz -o $lm_order -S 80% -T /tmp < $data_path/train.main.$lang_dst > $lm_raw_path
    fi
    ./bin/build_binary trie $lm_raw_path $lm_path && rm $lm_raw_path
    

    # train phrase table, create base config for mosesdecoder
    ./scripts/training/train-model.perl \
	-first-step 1 -last-step 9 \
	 -external-bin-dir /home/moses/mosesdecoder/tools \
	 -model-dir $model_path \
	 -lm 0:$lm_order:$lm_path \
	 -mgiza -mgiza-cpus $num_threads -sort-buffer-size $sort_buffer_size -sort-compress gzip -cores $num_threads -dont-zip \
	 -corpus $data_path/train.main \
	 -f $lang_src -e $lang_dst \
	 -alignment grow-diag-final-and -max-phrase-length 5 -parts 20 \
	 -reordering hier-mslr-bidirectional-fe \
	 -score-options ' --GoodTuring --CountBinFeature 1 2 3 4 6 10' -input-factor-max 0 -alignment-factors 0-0 \
	 -translation-factors 0-0 -reordering-factors 0-0 -decoding-steps t0

    # prune phrase table
    if [ "$prune_pt" = true ] ; then
        mkdir -p $data_path/sigtest_vocs
        cd $data_path/sigtest_vocs
        sigtest_binary=/home/moses/mosesdecoder/contrib/sigtest-filter/SALM/Bin/Linux/
        ln -s $data_path/train.main.$lang_dst $data_path/sigtest_vocs/$lang_dst
        ln -s $data_path/train.main.$lang_src $data_path/sigtest_vocs/$lang_src

        $sigtest_binary/Index/IndexSA.O64 $data_path/sigtest_vocs/$lang_dst
        $sigtest_binary/Index/IndexSA.O64 $data_path/sigtest_vocs/$lang_src
        gunzip -c $model_path/phrase-table.gz | /home/moses/mosesdecoder/contrib/sigtest-filter/filter-pt -f $lang_src -e $lang_dst -l a+e -n 30 > phrase-table.pruned
        gzip < phrase-table.pruned > $model_path/phrase-table.gz && rm -r $data_path/sigtest_vocs
        cd /home/moses/mosesdecoder
        
    fi

    # tune trained model
    ./scripts/training/mert-moses.pl \
         $data_path/train.tuning.$lang_src $data_path/train.tuning.$lang_dst \
        /home/moses/mosesdecoder/bin/moses $model_path/moses.ini --mertdir /home/moses/mosesdecoder/bin \
        --rootdir /home/moses/mosesdecoder/scripts --batch-mira --return-best-dev \
        --batch-mira-args "-J 300" --decoder-flags "-threads $num_threads -v 0"
    cp mert-work/moses.ini $model_path/moses.ini

fi
    
# chmod to prevent access problems from outside the container
chmod -R 777 $data_path
chmod -R 777 $model_path

