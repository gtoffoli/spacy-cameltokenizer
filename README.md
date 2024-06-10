# spacy-cameltokenizer

***The cameltokenizer package***

*cameltokenizer* wraps part of the *camel_tools* library and extends it, to perform *morphological tokenization* downstream the standard *spaCy* tokenizer; *cameltokenizer* reconfigures itself, based on the kind of input it gets, in order to work ..
- .. as a complete tokenizer, inside the *training pipeline*, by subclassing the standard *Tokenizer* class;
- .. as an extension of the *processing pipeline*.

***The use context of cameltokenizer***

To support the *Arabic* language (MSA) inside the spaCy framework with a trained language model, which was missing when *cameltokenizer* has been developed, we devised a solution including two packages, besides the *spaCy* distribution:
- the *cameltokenizer* package, which implements a tokenizer extension; it is written in *Cython*, in order to interface spaCy code also written in Cython;
- a package named *ar_core_news_md*, similar to other similarly named language packages;

plus
- some initialization code, which *registers* a pipeline component to be called first, so that it gets its input (a *Doc*), from the standard tokenizer;
- a customization of the *punctuation* module and of *init.py* inside *spacy.lang.ar*.

***How cameltokenizer works***

The model training is based on the *Universal Dependencies Arabic-PADT treebank*. We "cleaned" it in some way, running the function *ar_padt_fix_conllu*, which is defined in the *utils* module; it
- removes the *Tatweel/Kashida* character (it is only typographic stuff) and the *Superscript Alef* character from the sentences;
- removes the *vocalization diacritics* from the sentences and from the tokens text, to improve the *token alignment* when running the spaCy *debug data* command; eventually, we removed them from the lemmas as well, thus obtaining some minor improvements;
- "fixes" the splitting of a few composite *particles*, to avoid cases of "destructive" (non consevative) tokenization.

We think that, without the morphological tokenization, no parsing would be possible at all. For that, we chose the *MorphologicalTokenizer* of *CamelTools*. It mainly looks for prefixed prepositions and suffixed pronouns, not declension and conjugation affixes.
We apply to its input and its output, in a dirty and inefficient way, a lot of small "fixes" aimed at reducing the number of *misaligned tokens*, that is to better match the tokenization done by the annotators of the training set (the .conllu files); possibly, said fixes could result in some *overfitting*.

***Some results***

The use of cameltokenizer ha allowed us to drastically improve the results of the execution of the spacy commands *debug data* and *train*, over those obtained running them with the native tokenizer, even if the *accuracy* evaluated with the spaCy *benchmark* is still disappointing:
- *debug data* - The percentage of *misaligned tokens* is slightly more than 1%; it was over 16% at the start, without the tokenizer extensions;
- *train* - The overall best score in training a *pipeline* with *tagger*, *trainable lemmatizer* and *parser* is 0.88; it was 0.66 at the start;
- *benchmark accuracy* -
TOK      76.06
TAG      61.58
POS      69.39
MORPH    61.70
LEMMA    70.51
UAS      42.17
LAS      38.38
SENT P   16.85
SENT R   6.91
SENT F   9.80
SPEED    19355


*Performances* above are quite worse than those of spaCy language models for most European languages. We won't discuss here why dealing with the Arabic language is more complex. Our intent is just to understand if those performances are acceptable in some *text-analysis* tasks; namely, in tasks related to *linguistic education*.

***Some caveats***

- *cameltokenizer* is work in progress;
- even the time performance is poor; this is mainly due to the heavy task carried out by the *MorphologicalTokenizer*;
- our code needs a lot of cleaning;
- currently, we create manually the package *ar_core_news_md* inside the *site-packages* directory of a Python *virtual environment* and put inside it a *symlink* to the *output/model-best* directory produced by the training pipeline, which contains the individual trained models.

More information on the the problems encountered and on the motivations of some choices can be found in the *discussion* https://github.com/explosion/spaCy/discussions/7146