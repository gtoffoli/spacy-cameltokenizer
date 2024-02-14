from cymem.cymem cimport Pool

from spacy.tokens.doc cimport Doc
from spacy.vocab cimport Vocab

cdef class CamelTokenizer:
    cdef readonly Vocab vocab
    cdef object config
    cdef int count
    cdef object nlp
    cdef object native_tokenizer
    cdef object atb_tokenizer
    cdef object Arabic
