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
        # self.atb_tokenizer = MorphologicalTokenizer(disambiguator=mle_msa, scheme='atbtok', split=True)
        self.atb_tokenizer = MorphologicalTokenizer(disambiguator=mle_msa, scheme='atbtok', split=False)
        self.count = 0

    def __call__(self, text, verbose=False):
        self.count += 1
        # print self.count ,
        doc = self.native_tokenizer(text)
        raw_tokens = [t.text for t in doc if t.text]
        n_raw_tokens = len(raw_tokens)
        raw_tokens_text = ''.join(raw_tokens)
        words = []
        spaces = []
        morphos = self.atb_tokenizer.tokenize(raw_tokens)
        n_morphos = len(morphos)
        alignments = self.split_align_tokens(raw_tokens, morphos)
        if not alignments:
            return doc
        cdef Pool mem = Pool()
        for i, alignment in enumerate(alignments):
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

    def normalize(self, s):
        # return dediac_ar(normalize_unicode(s))
        return dediac_ar(s)

    def split_align_tokens(self, raw_tokens, tokens):
        morpho_segments = []
        for i, token in enumerate(tokens):
            raw_token = raw_tokens[i]
            if not token.count('_'):
                morpho_segments.append([raw_token])
            else:
                token = dediac_ar(token)
                if token.replace('+_', '').replace('_+', '') == raw_token:
                    token = token.replace('+_', '_').replace('_+', '_')
                    morpho_segments.append(token.split('_'))
                else:
                    morpho_segments.append([raw_token])
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
