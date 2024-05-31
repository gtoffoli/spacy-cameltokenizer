import os
import re
from collections import defaultdict
import unicodedata

import pyconll
from camel_tools.utils.charsets import UNICODE_LETTER_CHARSET
from camel_tools.utils.dediac import dediac_ar
from camel_tools.utils.normalize import normalize_alef_ar
from camel_tools.utils.normalize import normalize_alef_maksura_ar
from camel_tools.utils.normalize import normalize_teh_marbuta_ar
from pickle import NONE

TATWEEL = '\u0640' # 'ـ' Tatweel/Kashida character (esthetic character elongation for improved layout)
ALEF_SUPER = '\u0670' # ' ' Arabic Letter superscript Alef
ALEF = 'ا' # u'\u0627'
BA = 'ب' # u'\u0628'
TA = 'ت' # u'\u062A'
TA_MARBUTA = 'ة' # u'\u0629'
LAM = 'ل' # u'\u0644'
ALIF_MAQSURA = 'ى' # u'\u0649'
HAMZA = 'ء' # u'\u0621' 
WAW_WITH_HAMZA = 'ؤ' # u'\u0624'
YAH_WITH_HAMZA = 'ئ' # u'\u0626' 

UNICODE_LETTER_CHARSET = set()
for x in range(0x110000):
    x_chr = chr(x)
    x_cat = unicodedata.category(x_chr)
    if x_cat[0] == 'L':
        UNICODE_LETTER_CHARSET.add(x_chr)
UNICODE_LETTER_CHARSET = frozenset(UNICODE_LETTER_CHARSET)

# customized from camel_tools.utils modules: TATWEEL is not a regular diacritic !!!
# AR_DIAC_CHARSET = frozenset(u'\u064b\u064c\u064d\u064e\u064f\u0650\u0651\u0652\u0670\u0640')
CUSTOM_AR_DIAC_CHARSET = frozenset(u'\u064b\u064c\u064d\u064e\u064f\u0650\u0651\u0652\u0670')
CUSTOM_DIAC_RE_AR = re.compile(u'[' +
                         re.escape(u''.join(CUSTOM_AR_DIAC_CHARSET)) +
                         u']')
def custom_dediac_ar(s):
    """Dediacritize Unicode Arabic string.
    """
    return CUSTOM_DIAC_RE_AR.sub(u'', s)

def normalize_alef_maksura(s):
    # this is not the usual normalization
    return s.replace(ALIF_MAQSURA, ALEF)

def normalize_teh_marbuta(s):
    # this is not the usual normalization
    return s.replace(TA_MARBUTA, TA)

def normalize_with_hamza(s):
    return s.replace(WAW_WITH_HAMZA, HAMZA).replace(YAH_WITH_HAMZA, HAMZA)

def normalize_ar(s):
    # return normalize_alef_ar(normalize_alef_maksura_ar(normalize_teh_marbuta_ar(s)))
    return normalize_with_hamza(normalize_alef_ar(normalize_alef_maksura(normalize_teh_marbuta(s))))

def normalize_ar_1(s): 
    return normalize_with_hamza(normalize_alef_ar(normalize_alef_maksura_ar(normalize_teh_marbuta(s))))

def like(s1, s2):
    if len(s1) > 3 and len(s2) > 3:
        s1 = s1[:-3]
        s2 = s2[:-3]
    return (normalize_ar(s1) == normalize_ar(s2)) or (normalize_ar_1(s1) == normalize_ar_1(s2))

def msa_filter_pattern(in_file, out_file, pattern):
    assert in_file and pattern
    char = None
    n_matches = n_removed = 0
    while 1:
        prev = char
        char = in_file.read(1)          
        if not char: 
            break
        if char==pattern:
            n_matches += 1
            if prev in UNICODE_LETTER_CHARSET or pattern==ALEF_SUPER:
                n_removed += 1
                continue
        if out_file:
            out_file.write(char)
    return n_matches, n_removed

def msa_filter(folder='/_Tecnica/AI/CL/spacy/training/ar', filename='ar_padt-ud-train.conllu', remove=False):
    in_path = os.path.join(folder, filename)
    in_file = open(in_path, 'r', encoding='utf-8')
    i = 1
    for pattern, pat_name in ((TATWEEL, 'TATWEEL'), (ALEF_SUPER, 'ALEF_SUPER')):
        if remove:
            out_path = os.path.join(folder, filename+'.'+str(i))
            out_file = open(out_path, 'w', encoding='utf-8')
        n_matches, n_removed = msa_filter_pattern(in_file, remove and out_file, pattern)
        print(pat_name, '- found:', n_matches, '- removed:', n_removed)
        if pat_name != 'ALEF_SUPER': # check it wasn't the last iteration
            if remove:
                out_file.close()
                in_path = out_path
                in_file = open(in_path, 'r', encoding='utf-8')
                i += 1
            else:
                in_file.seek(0)
    in_file.close()
    if remove:
        out_file.close()

# see https://stackoverflow.com/questions/6314614/match-any-unicode-letter
conllu_filter_patterns = [
    [ALEF_SUPER, ''],
    [TATWEEL, ''],
]

conllu_destructive_merges = {
    "ممن": ['من', 'م'], # mimman (min + man)
    'منا': ['نا', 'م'], # minna (min + na)
    'عما': ['ما', 'ع'], # ʕammā (ʕan + mā)
    'مما': ['ما', 'م'], # mimma (min + ma), offten is CONG
    'ألا': ['لا', 'ع'], # ʕallā (ʕan + la)
}

def ar_padt_fix_conllu(folder='/_Tecnica/AI/CL/spacy/training/ar', folder_from='', filename='ar_padt-ud-train.conllu', fake=False):
    if not folder_from:
        folder_from = folder + '/original'
    for filename in ['ar_padt-ud-train.conllu', 'ar_padt-ud-dev.conllu', 'ar_padt-ud-test.conllu']:
        in_path = os.path.join(folder_from, filename)
        in_file = open(in_path, 'r', encoding='utf-8')
        out_path = os.path.join(folder, filename)
        out_file = open(out_path, 'w', encoding='utf-8')
        i = 0
        span_start = span_end = ''
        merge_to_fix = {}
        while True:
            i += 1
            line = in_file.readline()
            if not line:
                print()
                break
            # leave comments unchanged
            if line[0] == '#' or len(line) < 3:
                out_file.write(line)
                continue
            # filter out a few special characters
            for left, right in conllu_filter_patterns:
                if line.count(left):
                    fixed = ''
                    prev = NONE
                    for c in line:
                        if c == left and prev in UNICODE_LETTER_CHARSET:
                            fixed += right
                        else:
                            fixed += c
                        prev = c
                    line = fixed
            """ the "smart" fix below doesn't improve the scores ? """
            # fix (undo) some destructive merges of arabic particles
            line_list = line.split('\t')
            if len(line_list) > 2 and len(line_list[0].split('-')) == 2:
                span = line_list[0].split('-')
                if span[0].isnumeric() and span[1].isnumeric():
                    if int(span[1]) == int(span[0]) + 1:
                        merge_to_fix = conllu_destructive_merges.get(line_list[1], [])
                        if merge_to_fix:
                            span_start = span[0]
                            span_end = span[1]
                            print(i, span_start, span_end)
            elif len(line_list) > 2 and line_list[0].isnumeric():
                token_id = line_list[0]
                if span_start and token_id > span_start:
                    span_start = span_end = ''
                elif token_id == span_start:
                    line = '\t'.join([token_id, merge_to_fix[0]] + line_list[2:])
                    span_start = ''
                elif not span_start and token_id == span_end:
                    line = '\t'.join([token_id, merge_to_fix[1]] + line_list[2:])
                    span_end = ''
            # remove diacritics from line; this is relevant only for lemmas), which are vocalized
            line = custom_dediac_ar(line)
            out_file.write(line)
        in_file.close()
        out_file.close()

def conllu_dediac(conll_in_path="/_Tecnica/AI/CL/spacy/training/ar/ar_padt-ud-train.conllu"):
    """ in conllu file remove diacritics from sentence text and from token form """
    conll_out_path = conll_in_path.replace('.conllu', '.out.conllu')
    with open(conll_out_path, 'w', encoding='utf-8') as f_out:
        with open(conll_in_path, 'r', encoding='utf-8') as f_in:
            while True:
                line = f_in.readline()
                if not line:
                    break
                if line.startswith('# text = '):
                    text = line.replace('# text = ', '')
                    text = dediac_ar(text)
                    line = '# text = ' + text
                elif len(line) > 1:
                    if line[0].isnumeric():
                        items = line.split('\t')
                        if len(items) >= 3 and not items[0].count('-'):
                            line = line.replace(items[1], dediac_ar(items[1]), 1)
                f_out.write(line)

# def conllu_loop(conll_path="/_Tecnica/AI/CL/spacy/training/ar/ar_padt-ud-train.conllu", \
def conllu_loop(conll_path="/_Tecnica/AI/CL/spacy/training/ar/ar_padt-ud-train.out.conllu", \
                sentence_function=None, token_function=None, pattern=None, data=None, max=0, verbose=0):
    # train = pyconll.load_from_file(conll_path)
    with open(conll_path, 'r', encoding='utf-8') as f:
        source = f.read()
    train = pyconll.load.load_from_string(source)
    n_sents = len(train)
    print(n_sents, 'sentences loaded')
    for i, sentence in enumerate(train, start=1):
        if max and i > max:
            break
        sentence_id = sentence.id
        n_tokens = len(sentence)
        sent = sentence.text
        l_sent = len(sent)
        if verbose >= 2:
            print(i, sentence_id, n_tokens, l_sent, sent)
        elif verbose >= 1:
            print(i,  n_tokens, l_sent)
        if sentence_function:
            # print(i, sentence_id, n_tokens, l_sent, sent)
            sentence_function(sentence, data)
            continue
        k = 0
        for j, token in enumerate(sentence, start=1):
            token_id = token.id
            if token_id.count('-'):
                continue
            if token_function:
                token_function(pattern, token, sentence, k, data)
            form = token.form
            upos = token.upos
            n_chars = len(form)
            k += n_chars
            if j < n_tokens and k < l_sent and sent[k] == ' ':
                is_space = True
                k += 1
            else:
                is_space = False
            if verbose >= 2:
                print(i, j, 'T{}'.format(token_id), n_chars, form, upos, is_space, k)

def pick_prep(pattern, token, sentence, k, preps_dict):
    """ conllu_loop co-routine for function count_preps """
    form = token.form 
    upos = token.upos
    if (len(form) <= 2 and upos == 'CCONJ') or (len(form) <= 2 and upos == 'ADP') or (form == 'س' and upos == 'AUX'):
        preps_dict[form] += 1

def count_preps():
    preps_dict = defaultdict(int)
    conllu_loop(token_function=pick_prep, data=preps_dict)
    sorted_preps = dict(sorted(preps_dict.items(), key=lambda item: item[1], reverse=True))
    return sorted_preps

def discriminate_prefix(pattern, token, sentence, k, data):
    """ conllu_loop co-routine for function analyze_suffix """
    sent = sentence.text
    form = token.form
    if form.startswith(pattern) and sent[k:].startswith(pattern):
        no_dict, yes_dict = data
        if form == pattern and token.upos in ['CCONJ', 'ADP', 'AUX',]:
            next_token = ''
            k = k + len(pattern)
            while k < len(sent) and sent[k].isalnum():
                next_token += sent[k]; k += 1
            if next_token:
                yes_dict[next_token] += 1
        elif len(form) > len(pattern):
            no_dict[form[len(pattern):]] += 1

def analyze_prefix(pattern):
    """ check if """
    no_dict = defaultdict(int)
    yes_dict = defaultdict(int)
    conllu_loop(token_function=discriminate_prefix, pattern=pattern, data=[no_dict, yes_dict])
    no_dict = dict(sorted(no_dict.items(), key=lambda item: item[0]))
    yes_dict = dict(sorted(yes_dict.items(), key=lambda item: item[0]))
    return no_dict, yes_dict

def check_conservative_tokenization(sentence, bad_sents):
    """ conllu_loop co-routine for function count_non_conservative_sents """
    sent = sentence.text.replace(' ', '')
    token_text = ''.join([token.form for token in sentence if not token.id.count('-')])
    diff = len(token_text) - len(sent)
    if diff:
        bad_sents.append(diff)
        print(diff)
        print(sent)
        print(token_text)

def count_non_conservative_sents():
    """ list length diffs for sentences non complying with conservative_tokenization """
    bad_sents = []
    conllu_loop(sentence_function=check_conservative_tokenization, data=bad_sents)
    return bad_sents

def restore_conservative_tokenization(sentence, source_file):
    """ conllu_loop co-routine for function fix_non_conservative_sents """
    sentence_id = sentence.id
    sent = sentence.text
    l_sent = len(sent)
    sentence_text = sent.replace(' ', '')
    token_text = ''.join([token.form for token in sentence if not token.id.count('-')])
    diff = len(token_text) - len(sentence_text)
    if diff:
        # print(diff, sentence_id)
        previous_form = ''
        previous_upos = None
        k = 0
        for j, token in enumerate(sentence, start=1):
            token_id = token.id
            if token_id.count('-'):
                continue
            form = token.form
            upos = token.upos
            # if form == '_' and upos == '_':
            if token_id.count('.'):
                previous_form = ''
                previous_upos = None
                continue
            l_token = len(form)
            if like(form, sent[k : k+l_token]):
                k += l_token
            else:
                # if previous_upos == 'ADP' and previous_form == LAM and form.startswith(ALEF) and normalize_ar(form) == normalize_ar(ALEF+sent[k:k+l_token-1]):
                if previous_upos == 'ADP' and previous_form == LAM and normalize_alef_ar(form).startswith(ALEF) and like(form, ALEF+sent[k:k+l_token-1]):
                    form = form[1:]
                    k += l_token-1
                elif previous_upos == 'ADP' and previous_form == LAM and form.startswith('الل') and like(form[2:], sent[k:k+l_token-2]):
                    form = form[2:]
                    k += l_token-2
                else:
                    print(sentence.id, token_id, l_token, previous_upos, previous_form, upos, form, normalize_ar(form), normalize_ar(sent[k : k+l_token]))
                    k += l_token
            if k < l_sent and sent[k] == ' ':
                is_space = True
                k += 1
            previous_form = form
            previous_upos = upos

def fix_non_conservative_sents():
    """ fix tokenization of sentences non complying with conservative_tokenization """
    fixes = []
    conllu_loop(sentence_function=restore_conservative_tokenization, data=fixes)
   