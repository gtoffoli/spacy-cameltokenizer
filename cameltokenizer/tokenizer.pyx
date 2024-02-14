# cython: embedsignature=True, binding=True
# distutils: language=c++

from camel_tools.disambig.mle import MLEDisambiguator
from camel_tools.tokenizers.morphological import MorphologicalTokenizer

cimport cython
from cymem.cymem cimport Pool

import spacy
from spacy.language import Language
from spacy.vocab import Vocab
from spacy.tokenizer import Tokenizer
from spacy.tokens.doc cimport Doc
from spacy.lang.ar import Arabic
from spacy import util
from spacy.scorer import Scorer
from spacy.training import validate_examples


cdef class CamelTokenizer:

    def __init__(self, object nlp, config=None):
        print("__init__ CamelTokenizer")
        self.config = config
        self.nlp = nlp
        self.vocab = self.nlp.vocab
        self.count = 0

    def __call__(self, doc):
        self.count += 1
        print([[j+1, t.text, len(t.whitespace_)] for j, t in enumerate(doc)])
        raw_tokens = [t.text for t in doc if t.text]
        n_raw_tokens = len(raw_tokens)
        raw_tokens_text = ''.join(raw_tokens)
        words = []
        spaces = []
        # morphos = self.atb_tokenizer.tokenize(raw_tokens)
        morphos = self.config['atb_tokenizer'].tokenize(raw_tokens)
        n_morphos = len(morphos)
        i_raw = 0 # index of token in simple tokenization
        raw_token = doc[i_raw]
        raw_text = raw_token.text
        raw_idx = raw_token.idx
        raw_len = len(raw_text)
        raw_space = raw_token.whitespace_

        cdef Pool mem = Pool()
        morphos_chars = 0
        i_morpho = 0 # morpho index
        l_morphos = 0
        for morpho in morphos:
            assert len(morpho) > 0
            if morpho and len(morpho) > 1:
                if morpho[0] == '+' and not raw_text[l_morphos] == '+':
                    morpho = morpho[1:]
                elif morpho[-1] == '+' and not raw_text[l_morphos+len(morpho)-1] == '+':
                    morpho = morpho[:-1]
            l_morpho = len(morpho)
            try: # questo va sostituito con un test; eventualmente va bloccato uno splitting
                assert l_morpho <= raw_len
            except:
                print('!', morphos_chars, l_morphos, raw_len, i_raw, raw_text, morpho)
            morpho_source = raw_tokens_text[morphos_chars : morphos_chars+l_morpho]
            assert l_morpho > 0
            self.vocab.get(mem, morpho_source)
            words.append(morpho_source)
            morphos_chars += l_morpho
            l_morphos += l_morpho
            i_morpho += 1
            if l_morphos == raw_len:
                spaces.append(raw_space)
            else:
                spaces.append('')

            if l_morphos > raw_len: # anche questo test va rivisto
                print('!!!', morphos_chars, l_morphos, raw_len, i_raw, raw_text, morpho)
                break
                     
            if l_morphos == raw_len:
                l_morphos = 0
                i_raw += 1
                if i_raw < n_raw_tokens:
                    raw_token = doc[i_raw]
                    raw_text = raw_token.text
                    raw_idx = raw_token.idx
                    raw_len = len(raw_text)
                    raw_space = raw_token.whitespace_
        if False: # self.count == 6221:
            tokens_chars = 0
            token_list = []
            for token in doc:
                token_list.append([tokens_chars, len(token.text), token.text])
                tokens_chars += len(token.text)
            print(token_list)
            morphos_chars = 0
            morpho_list = []
            for morpho in morphos:
                morpho_list.append([morphos_chars, len(morpho), morpho])
                morphos_chars += len(morpho)
            print(morpho_list)
            words_chars = 0
            word_list = []
            for word in words:
                word_list.append([words_chars, len(word), word])
                words_chars += len(word)
            print(word_list)
        morpho_doc = Doc(self.vocab, words=words, spaces=spaces)
        if False: # self.count == 6221:
            print([[token.idx, len(token.text), token.text] for token in morpho_doc])
        doc_text = doc.text
        morpho_doc_text = morpho_doc.text
        # print('---', self.count, len(text), len(doc_text), len(morpho_doc_text))
        # print self.count ,
        if morpho_doc_text != doc_text:
            print(doc_text)
            print(morpho_doc_text)
        # print([[i+1, t.text, len(t.whitespace_)] for i, t in enumerate(morpho_doc)])
        return morpho_doc

@Language.factory("cameltokenizer",)
def create_cameltokenizer(nlp, name):
    mle_msa = MLEDisambiguator.pretrained('calima-msa-r13')
    atb_tokenizer = MorphologicalTokenizer(disambiguator=mle_msa, scheme='atbtok', split=True)
    return CamelTokenizer(nlp, config = {'atb_tokenizer': atb_tokenizer})
