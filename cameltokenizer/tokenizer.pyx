# cython: embedsignature=True, binding=True
# distutils: language=c++

from camel_tools.disambig.mle import MLEDisambiguator
from camel_tools.tokenizers.morphological import MorphologicalTokenizer
from camel_tools.utils.normalize import normalize_unicode
from camel_tools.utils.dediac import dediac_ar

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

    def __init__(self, object nlp):
        # self.nlp = nlp
        self.nlp = Arabic()
        self.native_tokenizer = self.nlp.tokenizer
        self.vocab = self.nlp.vocab
        mle_msa = MLEDisambiguator.pretrained('calima-msa-r13')
        self.atb_tokenizer = MorphologicalTokenizer(disambiguator=mle_msa, scheme='atbtok', split=False)
        self.count = 0

    def __call__(self, text, verbose=False):
        self.count += 1
        # print self.count ,
        doc = self.native_tokenizer(text)
        raw_tokens = [t.text for t in doc if t.text]
        raw_tokens, fix_map = self.fix_raw_tokens(raw_tokens)
        n_raw_tokens = len(raw_tokens)
        raw_tokens_text = ''.join(raw_tokens)
        words = []
        spaces = []
        morphos = self.atb_tokenizer.tokenize(raw_tokens)
        alignments = self.split_align_tokens(raw_tokens, morphos)
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
                    if i_raw:
                        spaces.append(doc[i_raw].whitespace_)
                    else:
                        spaces.append('')
                else:
                    spaces.append('')
        morpho_doc = Doc(self.vocab, words=words, spaces=spaces)
        if verbose:
            doc_text = doc.text
            morpho_doc_text = morpho_doc.text
            if morpho_doc_text != doc_text:
                print(doc_text)
                print(morpho_doc_text)
        return morpho_doc

    def normalize(self, s):
        # return dediac_ar(normalize_unicode(s))
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
            elif token.endswith('".') and len(token) >2: # and i+1 == n_tokens:
                fixed.extend([token.replace('".', ''), '"', '.'])
                j += 3
            elif token.endswith(').') and len(token) >2: # and i+1 == n_tokens:
                fixed.extend([token.replace(').', ''), ')', '.'])
                j += 3
            elif token.endswith('.') and len(token) >= 2  and token[:-1].isdecimal(): # and i+1 == n_tokens:
                fixed.extend([token[:-1], '.'])
                j += 2
            elif token.startswith('و') and len(token) >= 2 and token[1] in ['(', '"']:
                fixed.extend(['و', token[1:]])
                j += 2
            elif (token.startswith('ب') or token.startswith('ل'))and len(token) >= 2 and token[1:].isdecimal():
                fixed.extend([token[0], token[1:]])
                j += 2
            else:
                fixed.append(token)
                j += 1
            fix_map[j-1] = i
        return fixed, fix_map

    def split_align_tokens(self, raw_tokens, tokens):
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
            split_tokens = self.improve_morphological_tokenization(split_tokens)
        return zip(raw_tokens, split_tokens)

    def improve_morphological_tokenization(self, split_tokens):
        """ fix a few cases of over-splitting; split some more prefixes and suffixes """
        fixed_split_tokens = []
        for split_token in split_tokens:
            n_segments = len(split_token)
            segment = split_token[0]
            if n_segments == 2 and segment == 'عند' and split_token[1] == 'ما':
                split_token = ['عندما']
            elif n_segments == 1:
                if segment.startswith('لال'):
                    split_token = ['ل', segment[1:]]
                elif segment.count('،') == 1:
                    parts = segment.split('،')
                    if parts[0].isalpha() and parts[1].isalpha():
                        split_token = [parts[0], '،', parts[1]]
                elif segment.endswith('ةه') or segment.endswith('ىه'):
                    split_token = [segment[:-1], 'ه']
                elif segment.endswith('zzz'):
                    split_token = [segment[:-1], segment[-1:]]
                elif segment.endswith('ةهم') or segment.endswith('يهم') or segment.endswith('ةها'):
                    split_token = [segment[:-2], segment[-2:]]
                elif segment.endswith('ىها'):
                    split_token = [segment[:-2], segment[-2:]]
                elif segment.endswith('يها'):
                    split_token = [segment[:-2], segment[-2:]]
                elif segment.endswith('ينا'):
                    split_token = [segment[:-2], segment[-2:]]
                elif segment.endswith('اها'):
                    split_token = [segment[:-2], segment[-2:]]
                elif segment.endswith('اةي'):
                    split_token = [segment[:-1], segment[-1:]]
                elif segment.endswith('ليه'):
                    split_token = [segment[:-1], segment[-1:]]
                elif segment.endswith('يهما'):
                    split_token = [segment[:-3], segment[-3:]]
                elif segment.endswith('ةهما'):
                    split_token = [segment[:-3], segment[-3:]]
                elif segment.endswith('اتنا'):
                    split_token = [segment[:-2], segment[-2:]]
                elif segment.endswith('اتهم'):
                    split_token = [segment[:-2], segment[-2:]]
            fixed_split_tokens.append(split_token)
        return fixed_split_tokens

    def score(self, examples, **kwargs):
        validate_examples(examples, "Tokenizer.score")
        return Scorer.score_tokenization(examples)

    def pipe(self, texts, batch_size=1000):
        """Tokenize a stream of texts.

        texts: A sequence of unicode texts.
        batch_size (int): Number of texts to accumulate in an internal buffer.
        Defaults to 1000.
        YIELDS (Doc): A sequence of Doc objects, in order.

        DOCS: https://spacy.io/api/tokenizer#pipe
        """
        for text in texts:
            yield self(text)

    def to_disk(self, path, **kwargs):
        """Save the current state to a directory.

        path (str / Path): A path to a directory, which will be created if
            it doesn't exist.
        exclude (list): String names of serialization fields to exclude.

        DOCS: https://spacy.io/api/tokenizer#to_disk
        """
        path = util.ensure_path(path)
        with path.open("wb") as file_:
            file_.write(self.to_bytes(**kwargs))

    def to_bytes(self, *, exclude=tuple()):
        """Serialize the current state to a binary string.

        exclude (list): String names of serialization fields to exclude.
        RETURNS (bytes): The serialized form of the `Tokenizer` object.

        DOCS: https://spacy.io/api/tokenizer#to_bytes
        """
        serializers = {
            "vocab": lambda: self.vocab.to_bytes(exclude=exclude),
        }
        return util.to_bytes(serializers, exclude)

@spacy.registry.tokenizers("cameltokenizer")
def define_cameltokenizer():

    def create_cameltokenizer(nlp):
        return CamelTokenizer(nlp)

    return create_cameltokenizer
