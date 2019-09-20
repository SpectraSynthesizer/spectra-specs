#!/usr/bin/python3.6
'''
Functions for translating Anzu format to Spectra format
NOTE: 1. Run function from python (no main here).
'''
import os
from os.path import isfile, join

'''
Translate Anzu (.cfg) format to Spectra format
Parameters: in_file - input file in Anzu (.cfg) format
            out_file - output file name for the Spectra format
'''
def translate_file(in_file, out_file):
    names  = {'env var' : 'INPUT_VARIABLES',
              'sys var' : 'OUTPUT_VARIABLES',
              'env ini' : 'ENV_INITIAL',
              'sys ini' : 'SYS_INITIAL',
              'env trans' : 'ENV_TRANSITIONS',
              'sys trans' : 'SYS_TRANSITIONS',
              'env just' : 'ENV_FAIRNESS',
              'sys just' : 'SYS_FAIRNESS'}
    d = {'env var': [],
         'sys var': [],
         'env ini' : [],
         'sys ini' : [],
         'env trans' : [],
         'sys trans': [],
         'env just' : [],
         'sys just' : []}
    
    with open(in_file, 'r') as f:
        l = ''
        for line in f:
            line = line.strip()
            if not line or line[0] == '#':
                l = ''
                continue
            new_l = False
            for key, val in d.items():
                if names[key] in line:
                    curr_k = key
                    new_l = True
            if not new_l and curr_k:
                if ('trans' in curr_k or 'just' in curr_k) and (line[0] != 'G'):
                    d[curr_k][-1] = d[curr_k][-1] + line
                else:
                    d[curr_k].append(line)

    for k, v in d.items():
        l = []
        for s in v:
            s = s.split('#')[0].strip()
            assert s.endswith(';'), s
            s = s.replace('*', '&').replace('+','|').replace('X','next')
            s = s.replace('G(F','GF(')
            s = s.replace('=0', '=false').replace('=1','=true')
            l.append(s)
        d[k] = l
        
    with open(out_file, 'w') as f:
        module = os.path.split(in_file)[1].split('.')[0]
        f.write(f'module {module}\n')
        for v in d['env var']:
            f.write(f'\tenv boolean {v}\n')
        for v in d['sys var']:
            f.write(f'\tsys boolean {v}\n')

        def _write(t):
            def func(v):
                f.write(f'{t}\n')
                f.write(f'\t{v}\n')
            return func;
        write_assump = _write('assumption')
        write_guar = _write('guarantee')

        for v in d['env ini']:
            write_assump(v)
        for v in d['env trans']:
            write_assump(v)
        for v in d['env just']:
            write_assump(v)
        for v in d['sys ini']:
            write_guar(v)
        for v in d['sys trans']:
            write_guar(v)
        for v in d['sys just']:
            write_guar(v)
            

'''
Translate Anzu (.cfg) format to Spectra format

'''
def translate_dir(in_path, out_path, out_file_prefix = ''):
    assert os.path.isdir(in_path), 'not a directory: ' + in_path
    assert os.path.isdir(out_path), 'not a directory: ' + out_path

    for in_file in os.listdir(in_path):
        if not isfile(join(in_path, in_file)):
            continue
        if not in_file.endswith('.cfg'):
            continue
        out_file = out_file_prefix + '_' + in_file.split('.')[0] + '.spectra'
        print(out_file)
        translate_file(join(in_path, in_file), join(out_path, out_file))
