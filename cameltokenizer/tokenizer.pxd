from cymem.cymem cimport Pool

"""
import sys, os
path_this = os.path.dirname(os.path.abspath(__file__))
path_spacy = os.path.abspath(os.path.join(path_this, '..', '..', 'spaCy'))
sys.path.append(path_this)
sys.path.append(path_spacy)
import spacy
"""
from spacy.tokenizer cimport Tokenizer
from spacy.vocab cimport Vocab

cdef class CamelTokenizer(Tokenizer):
    cdef object nlp
    cdef Tokenizer native_tokenizer
    cdef object atb_tokenizer
    cdef int count
