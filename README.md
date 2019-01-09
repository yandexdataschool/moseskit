# Moseskit
_We went through the hell of tuning Moses so that you don't have to_

Pet project: train [Moses](www.statmt.org/moses/) phrase-based machine translation without the pain of configuring it. Docker-powered.

# Installation

1. Clone the repo or download archive:
```(bash)
wget https://github.com/yandexdataschool/moseskit/archive/master.zip -O moseskit.zip ; unzip moseskit.zip ; mv moseskit-master moseskit
```
2. Install [Docker](https://docs.docker.com/install/) and make sure your user can run containers.

__That's all!__

Test your installation with `cd moseskit` and `./run_moses.sh`. Use `sudo ./run_moses.sh` if your docker is only available for root user.

The script you've just launched trains phrase-based machine translation components and translates a small chunk of data. It may take half an hour to run. It's a perfect time to get a drink.

# Usage

Moseskit supports a few modes:

* __`./run_moses.sh`__ - trains MT model components on parallel data, then translates new lines:
  * Config file with parameters: `./src/train_and_translate.sh`
  * Input parallel data: `./data/train.raw.{source_language}` and `./data/train.raw.{target_language}`
  * Saves model files to `./model`. The final package includes lanuage model, 
  * Translates `dev.raw.{source_language}` into `dev.translated.*`
  * Data doesn't need to be tokenized before being fed into moses

* __`./run_moses.sh train`__ - trains MT model components. Same as `train_and_translate` but doesn't translate
  * Config file with parameters: `./src/train.sh`
  * Essentially the same as `train_and_translate` but without translating dev
  * Follows [this guide](http://www.statmt.org/moses/?n=FactoredTraining.HomePage) with some advice from the saints of phrase-based MT

* __`./run_moses.sh translate`__ - translates several input files using a trained model.
  * Config file with parameters: `./src/translate.sh`
  * Translates all files under `./to_translate/*.{source_language}` into `./to_translate/*.{target_language}`
  * One can use `translate` mode only after running `train` or `train_and_translate` or otherwise obtaining pre-trained model files under `./model`.
  * Data doesn't need to be tokenized before being fed into moses

* __`./run_moses bash`__ - runs an iterative bash shell in single-run container
  * moseskit directory contents are available under `/home/moses/shared`. E.g. `/home/moses/shared/data`.
  * One can run other commands interactively, e.g. `/home/moses/shared/src/train_and_translate.sh`
  * Your container will be removed once you exit it. To counteract, remove `--rm` flag from [this line](https://github.com/yandexdataschool/moseskit/blob/master/run_moses.sh#L16).

 
# Config

Each mode except `bash` has it's own config file where you can change script parameters. For instance, if you go to `./src/train_and_translate.sh`, you'll see some options at the top of the file, e.g.

* `lang_src=en` and `lang_dsr=ru` - source and target languages. The default values correspond to english-to-russian direction. __Change this to whichever languages you want to translate__.
* `num_threads=24` - change to the number of spare CPU cores you can allocate for model training and translation
* `lm_order` - the __N__ for N-gram language model


# Tips

* All meaningful parameters are commented with `# ^--`-style comments. All undocumented parameters are to be treated carefully and with [this guide](http://www.statmt.org/moses/?n=FactoredTraining.HomePage) in mind.
* If you have a lot of data in target language but only a few parallel lines, you can train language model on larger non-parallel corpora (e.g. manually using `./run_moses.sh bash`) and manually `./model/lm.binary` with your model.
* Phrase-Based vs Neural machine translation: 
   * Use phrase-based if you have <=100k lines of parallel data, neural machine translation for much larger corpora.
   * Use phrase-based machine translation if you want to prioritize adequacy (every word is translated) and neural machine translation if you want higher fluency (more natural-sounding translations)
   * One can also combine neural and phrase-based machine translation in numerous ways: ensembling, stacking, etc.


# Send your thanks (or condemnations) to

[Elena Voita](https://research.yandex.com/lib/people/610744), [Rico Senrich](https://github.com/rsennrich), [Fedor Ratnikov](https://github.com/justheuristic), [Standa Kuřík](https://github.com/skurik) and of course the [Moses](www.statmt.org/moses) developers.
