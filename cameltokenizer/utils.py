import os

from camel_tools.utils.charsets import UNICODE_LETTER_CHARSET

TATWEEL = u'\u0640' # 'ـ' Tatweel/Kashida character (esthetic character elongation for improved layout)
ALEF_SUPER = u'\u0670' # ' ' Arabic Letter superscript Alef

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
