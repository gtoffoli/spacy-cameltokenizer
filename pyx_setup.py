import os
from setuptools import setup
from Cython.Build import cythonize
import numpy

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
pyx_path = os.path.join(BASE_DIR, "cameltokenizer", "tokenizer.pyx")

setup(
    name='CamelTokenizer class',
    ext_modules=cythonize(pyx_path),
    include_dirs=[numpy.get_include()]
)