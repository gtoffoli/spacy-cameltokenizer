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
        print("__init__ CamelTokenizer")
        # self.nlp = nlp
        self.nlp = Arabic()
        self.native_tokenizer = self.nlp.tokenizer
        self.vocab = self.nlp.vocab
        mle_msa = MLEDisambiguator.pretrained('calima-msa-r13')
        self.atb_tokenizer = MorphologicalTokenizer(disambiguator=mle_msa, scheme='atbtok', split=True)
        self.count = 0

    def __call__(self, text, verbose=False):
        self.count += 1
        print self.count ,
        doc = self.native_tokenizer(text)
        raw_tokens = [t.text for t in doc if t.text]
        n_raw_tokens = len(raw_tokens)
        raw_tokens_text = ''.join(raw_tokens)
        words = []
        spaces = []
        morphos = self.atb_tokenizer.tokenize(raw_tokens)
        n_morphos = len(morphos)
        if verbose:
            print(n_raw_tokens, n_morphos)
            print(raw_tokens)
            print(morphos)
        alignments = self.align_tokens(raw_tokens, morphos, verbose=verbose, doc_count=self.count)
        if not alignments:
            return doc
        cdef Pool mem = Pool()
        for i, alignment in enumerate(alignments):
            if verbose:
                print(i, alignment)
            raw_token, morpho_segments = alignment
            n_segments = len(morpho_segments)
            for j, segment in enumerate(morpho_segments):
                self.vocab.get(mem, segment)
                words.append(segment)
                if j+1 == n_segments:
                    spaces.append(doc[i].whitespace_)
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

    def fix_morpho(self, word) -> list:
        if word == 'إف':
            return ['إ' ,'ف']
        else:
            return [word]

    def normalize(self, s):
        return dediac_ar(normalize_unicode(s))

    def align_tokens(self, raw_tokens, splitted_words, verbose=False, doc_count=0, log_count=91):
        """
        words = []
        for word in splitted_words:
            words.extend(self.fix_morpho(word))
        splitted_words = words
        """
        n_raw = len(raw_tokens)
        n_splitted = len(splitted_words)
        if verbose:
            print(n_raw, n_splitted)
        morpho_segments = []
        i_raw = i_morpho = 0
        total_raw_len = total_output_len = 0
        for raw_token in raw_tokens:
            if i_morpho >= n_splitted:
                break
            raw_len = len(raw_token)
            total_raw_len += raw_len
            splitted_word = splitted_words[i_morpho]
            if self.normalize(splitted_word) == self.normalize(raw_token) or (splitted_word.count('NOAN') and not splitted_words[i_morpho+1].startswith('+')):
                morpho_segments.append([raw_token])
                total_output_len += raw_len
                if doc_count==log_count:
                    if splitted_word == raw_token and total_output_len == total_raw_len:
                        print('+', i_raw, i_morpho, raw_token, splitted_word)
                    else:
                        print('-', i_raw, i_morpho, raw_token, splitted_word)
                i_morpho += 1
            else:
                done = False
                word_segments = []
                word = ''
                word_len = 0
                while not done:
                    if i_morpho >= n_splitted:
                        if word_segments:
                            morpho_segments.append(word_segments)
                            done = True
                            continue
                    splitted_word = segment = splitted_words[i_morpho] # .strip()
                    segment_len = len(segment)
                    if doc_count==log_count:
                        print('.', i_raw, i_morpho, raw_token, splitted_word, segment, word_segments)
                    if segment_len>1 and segment.endswith('+'): # and len(word_segments)<2:
                        segment = segment[:-1]
                        segment_len -= 1
                        case = 'prefix'
                    elif segment_len>1 and segment.startswith('+') and word_len>0:
                        segment = segment[1:]
                        segment_len -= 1
                        case = 'suffix'
                    else:
                        case = 'body'
                    word_segments.append(segment)
                    word += segment 
                    word_len += segment_len
                    total_output_len += segment_len
                    i_morpho += 1
                    if word.count('NOAN'):
                        total_output_len -= word_len
                        morpho_segments.append([raw_token])
                        total_output_len += raw_len
                        case = 'NOAN'
                        if splitted_words[i_morpho+1].startswith('+'):
                            i_morpho += 1
                        done = True
                    elif word_len > raw_len:
                        if case == 'prefix':
                            i_morpho -= 1
                        total_output_len -= word_len
                        morpho_segments.append([raw_token])
                        total_output_len += raw_len
                        done = True
                    elif word_len == raw_len and not case == 'prefix':
                        if self.normalize(word) == self.normalize(raw_token):
                            morpho_segments.append(word_segments)
                        else:
                            restored_word_segments = []
                            offset = 0
                            for segment in word_segments:
                                restored_word_segments.append(raw_token[offset:offset+len(segment)])
                                offset += len(segment)
                            morpho_segments.append(restored_word_segments)
                        done = True
                    elif word_len >= raw_len:
                        total_output_len -= word_len
                        morpho_segments.append([raw_token])
                        total_output_len += raw_len
                        done = True
                    if done:
                        if doc_count==log_count:
                            if total_output_len == total_raw_len:
                                print('++', i_raw, i_morpho, raw_token, word)
                            else:
                                print('--', i_raw, i_morpho, raw_token, word)
            if total_output_len != total_raw_len: # only diagnostic
                raw_tokens_text = ''.join(raw_tokens[:i_raw])
                morpho_segments_text = ''
                for segments in morpho_segments:
                    for segment in segments:
                        morpho_segments_text += segment
                print(splitted_words)
                print('--- no alignment', doc_count, case, n_raw, n_splitted, i_raw, i_morpho, total_raw_len, total_output_len, raw_len, word_len, raw_token, splitted_word, segment, word, word_segments, morpho_segments)
                i = 0
                while i < i_raw and i < len(morpho_segments):
                    print(i, raw_tokens[i], morpho_segments[i])
                    i += 1
                return None
            i_raw += 1 
            if verbose:
                print(i_raw, i_morpho, raw_token)
        return zip(raw_tokens, morpho_segments)

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
