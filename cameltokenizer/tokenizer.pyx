# cython: embedsignature=True, binding=True
# distutils: language=c++

import pickle
import attr

from camel_tools.disambig.mle import MLEDisambiguator
from camel_tools.tokenizers.morphological import MorphologicalTokenizer
from camel_tools.utils.normalize import normalize_unicode
from camel_tools.utils.dediac import dediac_ar

cimport cython
from cymem.cymem cimport Pool
"""
import sys, os
path_this = os.path.dirname(os.path.abspath(__file__))
path_spacy = os.path.abspath(os.path.join(path_this, '..', '..', 'spaCy'))
sys.path.append(path_this)
sys.path.append(path_spacy)
"""
import spacy

from spacy.language import Language
from spacy.tokenizer cimport Tokenizer
from spacy.tokens.doc cimport Doc
from spacy.lang.ar import Arabic
from spacy.lang.ar.stop_words import STOP_WORDS
from spacy import util
from spacy.scorer import Scorer
from spacy.training import validate_examples

from cameltokenizer.utils import ALEF
from cameltokenizer.female_first_names_in_arabic import female_first_names_in_arabic
from cameltokenizer.male_first_names_in_arabic import male_first_names_in_arabic
from cameltokenizer.last_names_in_arabic import last_names_in_arabic
from cameltokenizer.function_words import ADVERBS, CONJUNCTIONS, PREPOSITIONS, PRONOUNS, NOUNS # only non splittable words
cdef class CamelTokenizer(Tokenizer):

    def __init__(self, Vocab vocab, rules=None, prefix_search=None,
                 suffix_search=None, infix_finditer=None, token_match=None,
                 url_match=None, faster_heuristics=True):
        self.nlp = Arabic()
        self.native_tokenizer = self.nlp.tokenizer
        self.vocab = vocab
        mle_msa = MLEDisambiguator.pretrained('calima-msa-r13')
        self.atb_tokenizer = MorphologicalTokenizer(disambiguator=mle_msa, scheme='atbtok', split=False)
        self.count = 0

    def __call__(self, text_or_doc):
        verbose = True
        no_morpho = False
        self.count += 1
        # print self.count ,
        if isinstance(text_or_doc, str): # used in training pipeline
            text = text_or_doc
            doc = self.native_tokenizer(text)
        else: # used as post-tokenire component in production pipeline
            doc = text_or_doc
            text = doc.text
        raw_tokens = [t.text for t in doc if t.text]
        raw_tokens, fix_map = self.fix_raw_tokens(raw_tokens)
        n_raw_tokens = len(raw_tokens)
        raw_tokens_text = ''.join(raw_tokens)
        words = []
        spaces = []
        if no_morpho:
            split_tokens = [[token] for token in raw_tokens]
            split_tokens = self.improve_morphological_tokenization(split_tokens, text)
            alignments = zip(raw_tokens, split_tokens)
        else:
            morphos = self.atb_tokenizer.tokenize(raw_tokens)
            alignments = self.split_align_tokens(raw_tokens, morphos, text)
            if not alignments:
                return doc
        cdef Pool mem = Pool()
        for i, alignment in enumerate(alignments):
            raw_token, split_tokens = alignment
            n_segments = len(split_tokens)
            for j, segment in enumerate(split_tokens):
                self.vocab.get(mem, segment)
                words.append(segment)
                if j+1 == n_segments:
                    i_raw = fix_map.get(i, None)
                    if i_raw is not None:
                        spaces.append(doc[i_raw].whitespace_)
                    else:
                        spaces.append('')
                else:
                    spaces.append('')
        morpho_doc = Doc(self.vocab, words=words, spaces=spaces)
        if verbose:
            doc_text = doc.text
            morpho_doc_text = morpho_doc.text
            if len(morpho_doc_text) != len(doc_text) or morpho_doc_text != doc_text:
                print(self.count , '---', len(morpho_doc_text), len(doc_text))
                print(doc_text)
                print(morpho_doc_text)
        return morpho_doc

    def normalize(self, s):
        return dediac_ar(s)

    def fix_raw_tokens(self, tokens):
        """ handle problems possibly occurring also in other spaCy tokenizers """
        n_tokens = len(tokens)
        fixed = []
        fix_map = {}
        j = 0
        for i, token in enumerate(tokens):
            if token.endswith(')-') and len(token) >2 and token.replace(')-', '').isalpha():
                fixed.extend([token.replace(')-', ''), ')', '-'])
                j += 3
            elif token.endswith('".') and len(token) >2:
                fixed.extend([token.replace('".', ''), '"', '.'])
                j += 3
            elif token.endswith(').') and len(token) >2:
                fixed.extend([token.replace(').', ''), ')', '.'])
                j += 3
            elif token.endswith('.') and len(token) >= 2  and token[:-1].isdecimal(): # and i+1 == n_tokens:
                fixed.extend([token[:-1], '.'])
                j += 2
            elif token.startswith('و') and len(token) >= 2 and token[1] in ['(', '"']:
                fixed.extend(['و', token[1:]])
                j += 2
            elif token.startswith('و') and len(token) >= 2 and token[1:].isdecimal():
                fixed.extend(['و', token[1:]])
                j += 2
            elif token.startswith('و"') and len(token) > 2 and token[2:].isalpha():
                fixed.extend(['و', '"', token[2:]])
                j += 3
            elif (token.startswith('ب') or token.startswith('ل'))and len(token) >= 2 and token[1:].isdecimal():
                fixed.extend([token[0], token[1:]])
                j += 2
            elif token.startswith('ال') and len(token) >= 2 and token[2:].isdecimal():
                fixed.extend(['ال', token[2:]])
                j += 2
            elif token == 'غ.':
                fixed.extend(['غ', '.'])
                j += 2
            else:
                fixed.append(token)
                j += 1
            fix_map[j-1] = i
        return fixed, fix_map

    def split_align_tokens(self, raw_tokens, tokens, text):
        split_tokens = []
        for i, token in enumerate(tokens):
            raw_token = raw_tokens[i]
            if not token.count('_'):
                split_tokens.append([raw_token])
            else:
                token = dediac_ar(token)
                if token.replace('+_', '').replace('_+', '') == raw_token:
                    token = token.replace('+_', '_').replace('_+', '_')
                    split_tokens.append(token.split('_'))
                else:
                    split_tokens.append([raw_token])
        split_tokens = self.improve_morphological_tokenization(split_tokens, text)
        return zip(raw_tokens, split_tokens)

    def improve_morphological_tokenization(self, split_tokens, text):
        """ fix a few cases of over-splitting or "destructive" splitting;
            split some more prefixes and suffixes """
        fixed_split_tokens = []
        for split_token in split_tokens:
            n_segments = len(split_token)
            segment = split_token[0]
                
            if n_segments == 2:
                if segment == 'عند' and split_token[1] == 'ما':
                    split_token = ['عندما']
                elif split_token[0] == 'من' and split_token[1] == 'من': # mimman (min + man)
                    split_token = ['من', 'م']
                elif split_token[0] == 'من' and split_token[1] == 'نا': # minna (min + na)
                    split_token = ['نا', 'م']
                elif split_token[0] == 'عن' and split_token[1] == 'ما': # ʕammā (ʕan + mā)
                    split_token = ['ما', 'ع']
                elif split_token[0] == 'من' and split_token[1] == 'ما': # mimma (min + ma), offten is CONG
                    split_token = ['ما', 'م']
                elif split_token[0] == 'عن' and split_token[1] == 'لا': # ʕallā (ʕan + la)
                    split_token = ['لا', 'ع']
            elif n_segments == 1 and len(segment) > 3:
                if segment.startswith('ولف') or segment.startswith('وال') or segment.startswith('وار'):
                    split_token = ['و', segment[1:]] # ++
                elif segment.startswith('واع') and not segment.startswith('واعد'): #
                    split_token = ['و', segment[1:]]
                elif segment.startswith('وان') and segment[1:] not in ['وانغ', 'انغ']: #
                    split_token = ['و', segment[1:]]
                elif segment.startswith('لال'):
                    split_token = ['ل', segment[1:]] # +++++ ok
                elif segment.startswith('لل'):
                    split_token = ['ل', segment[1:]] # ALEF ellipsis
                elif segment.startswith('باست'):
                    split_token = ['ب', segment[1:]]
                elif segment.startswith('لاست') or segment.startswith('للخ') or segment.startswith('لال'): # or new
                    split_token = ['ل', segment[1:]] # 14 in train
                elif segment.startswith('بإع') or segment.startswith('بم'):
                    split_token = ['ب', segment[1:]]
                elif segment.startswith('لإع'):
                    split_token = ['ل', segment[1:]] # 63 in train
                elif segment.startswith('ان') and segment[2:] in PRONOUNS: #
                    split_token = ['لان', segment[3:]]
                elif segment.startswith('لان') and segment[3:] in PRONOUNS: # because + pronoun
                    split_token = ['لان', segment[3:]]
                    print(7)
                elif segment.count('،') == 1:
                    parts = segment.split('،')
                    if parts[0].isalpha() and parts[1].isalpha():
                        split_token = [parts[0], '،', parts[1]] # 14 in train
                elif segment.endswith('ةه') or segment.endswith('ىه'):
                    split_token = [segment[:-1], 'ه'] # +
                elif segment.endswith('ةهم') or segment.endswith('يهم') or segment.endswith('ةها'):
                    split_token = [segment[:-2], segment[-2:]] # +++
                elif segment.endswith('ىها') or segment.endswith('عها'):
                    split_token = [segment[:-2], segment[-2:]] # +
                elif segment.endswith('يها'):
                    split_token = [segment[:-2], segment[-2:]] # +
                elif segment.endswith('ينا'):
                    split_token = [segment[:-2], segment[-2:]] # no ? mainly foreign words
                elif segment.endswith('اها'):
                    split_token = [segment[:-2], segment[-2:]] # 54 in train
                elif segment.endswith('اةي'):
                    split_token = [segment[:-1], segment[-1:]] # 18 in train
                elif segment.endswith('ليه'):
                    split_token = [segment[:-1], segment[-1:]] # +
                elif segment.endswith('يهما'):
                    split_token = [segment[:-3], segment[-3:]] # 63 in train
                elif segment.endswith('ةهما'):
                    split_token = [segment[:-3], segment[-3:]] # 63 in train
                elif segment.endswith('اتنا'):
                    split_token = [segment[:-2], segment[-2:]]
                elif segment.endswith('اتهم'):
                    split_token = [segment[:-2], segment[-2:]]

            if len(split_token) > 1:
                token = ''.join(split_token)
                if token in ADVERBS or \
                   token in CONJUNCTIONS or \
                   token in PREPOSITIONS or \
                   token in PRONOUNS or \
                   token in NOUNS or \
                   token in female_first_names_in_arabic or \
                   token in male_first_names_in_arabic or \
                   token in last_names_in_arabic:
                    # print(token, split_token)
                    split_token = [token]

            fixed_split_tokens.append(split_token)
        return fixed_split_tokens

    # redefinition of 4 methods; see https://support.prodi.gy/t/saving-custom-tokenizer/395/2

    # see: https://stackoverflow.com/questions/41658015/object-has-no-attribute-dict-in-python3
    def to_bytes(self, *, exclude=tuple()):
        # return pickle.dumps(self.__dict__)
        return pickle.dumps('')
 
    def from_bytes(self, bytes_data, *, exclude=tuple()):
        data = {}
        # self.__dict__.update(pickle.loads(data))

    def to_disk(self, path, **kwargs):
        with open(path, 'wb') as file_:
            file_.write(self.to_bytes())

    def from_disk(self, path, *, exclude=tuple()):
        with open(path, 'rb') as file_:
            self.from_bytes(file_.read())

# the registration below is used only by the training pipeline

@spacy.registry.tokenizers("cameltokenizer")
def define_cameltokenizer():

    def create_cameltokenizer(nlp):
        # return CamelTokenizer(nlp)
        return CamelTokenizer(nlp.vocab)

    return create_cameltokenizer
