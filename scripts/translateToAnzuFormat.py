#!/usr/bin/python3.6

'''
Functions for translating SMV format to Anzu
NOTE: 1. Run function from python (no main here).
      2. Used from generate_specs.py
'''
import os
from os.path import isfile, join

'''
Translate SMV format to altl format
'''
def translate_file_altl(in_file, out_file):
    env_vars = []
    sys_vars = []
    env_inis = []
    sys_inis = []
    env_trans = []
    sys_trans = []
    env_just = []
    sys_just = []
    with open(in_file, 'r') as f:
        for line in f:
            line = line.strip()
            if 'VARENV' in line:
                env_var = True
            elif 'VAR' in line:
                env_var = False
            elif 'ext' in line and 'boolean' in line and env_var:
                env_vars.append(line.split(' ')[1].split(':')[0])
            elif 'ext' in line and 'boolean' in line and not env_var:
                sys_vars.append(line.split(' ')[1].split(':')[0])
            elif 'LTLSPECENV' in line:
                env = True;
            elif 'LTLSPEC' in line:
                env = False;
            elif ('G F' in line or 'GF' in line) and env:
                env_just.append(line)
            elif ('G F' in line or 'GF' in line) and not env:
                sys_just.append(line)
            elif ('G (' in line or 'G(' in line) and env:
                env_trans.append(line)
            elif ('G (' in line or 'G(' in line) and not env:
                sys_trans.append(line)
            elif line.split('=')[0] in env_vars:
                env_inis.append(line)
                assert env, 'must be env'
            elif line.split('=')[0] in sys_vars:
                sys_inis.append(line)
                assert not env, 'must be env'

    def fix_line(s):
        lc = s.count('(');
        rc = s.count(')');
        if s.endswith(';') and rc != lc:
            assert False, 'invalid line: ' + s
        elif not s.endswith(';') and rc == lc:
            assert False, 'invalid line: ' + s
        elif lc < rc:
            assert False, 'invalid line: ' + s
        elif lc > rc:
            print(f'fixing line {s}')
            l = [')' for i in range(lc-rc)]
            s = s + ''.join(l) + ';'
        return s

    translate = lambda s: \
                fix_line(s).replace('&','*').replace('|','+').replace('next','X')
    
    env_trans = list(map(translate, env_trans))
    sys_trans = list(map(translate, sys_trans))
    env_just = list(map(translate, env_just))
    sys_just = list(map(translate, sys_just))
    
    with open(out_file, 'w') as f:
        f.write('[INPUT_VARIABLES]\n')
        f.write(';\n'.join(env_vars)+';\n')
        f.write('[OUTPUT_VARIABLES]\n')
        f.write(';\n'.join(sys_vars)+';\n')
        f.write('[ENV_INITIAL]\n')
        f.write('\n'.join(env_inis)+'\n')
        f.write('[ENV_TRANSITIONS]\n')
        f.write('\n'.join(env_trans)+'\n')
        f.write('[ENV_FAIRNESS]\n')
        f.write('\n'.join(env_just)+'\n') 
        f.write('[SYS_INITIAL]\n')
        f.write('\n'.join(sys_inis)+'\n')
        f.write('[SYS_TRANSITIONS]\n')
        f.write('\n'.join(sys_trans)+'\n')
        f.write('[SYS_FAIRNESS]\n')
        f.write('\n'.join(sys_just)+'\n')

'''
Translate SMV format to Anzu format
WARNING: This translation is specific to the given AMBA and Genbuf generators.
and might not handle all edge cases that might exist in other smv specifications
'''
def translate_file_smv(in_file, out_file):
    env_vars = []
    sys_vars = []
    env_inis = []
    sys_inis = []
    env_trans = []
    sys_trans = []
    env_just = []
    sys_just = []
    continue_trans = False
    fair = False
    
    with open(in_file, 'r') as f:
        for line in f:
            line = line.strip()
            if 'INPUT_VARIABLES' in line or 'Input variable definition' in line:
                env_var = True
            elif 'OUTPUT_VARIABLES' in line:
                env_var = False
            elif 'VAR' in line and env_var:
                env_vars.append(line.split(' ')[1].split(':')[0])
            elif 'VAR' in line and not env_var:
                sys_vars.append(line.split(' ')[1].split(':')[0])
            elif 'ENV_INITIAL' in line or 'ENV_TRANSITIONS' in line:
                env = True
            elif 'SYS_INITIAL' in line or 'SYS_TRANSITIONS' in line:
                env = False
            elif 'ENV_FAIRNESS' in line:
                env = True
                fair = True
            elif 'SYS_FAIRNESS' in line:
                env = False
                fair = True
            elif 'INIT' in line and env:
                env_inis.append(line.split(' ')[1])
            elif 'INIT' in line and not env:
                sys_inis.append(line.split(' ')[1])
            elif 'TRANS' in line:
                def f(trans):
                    nonlocal continue_trans
                    trans.append(line.split('TRANS')[1])
                    if not line.endswith(';'):
                        continue_trans = True
                if env:
                    f(env_trans)
                else:
                    f(sys_trans)
            elif continue_trans:
                def f(trans):
                    nonlocal continue_trans
                    if any(var in line for var in env_vars+sys_vars):
                        trans[-1] += line
                        if line.endswith(';'):
                            continue_trans = False
                    else:
                        continue_trans = False
                if env:
                    f(env_trans)
                else:
                    f(sys_trans)
            elif fair and env and any(var in line for var in env_vars+sys_vars):
                env_just.append(line.split(',')[0]) 
            elif fair and not env and any(var in line for var in env_vars+sys_vars):
                sys_just.append(line.split(',')[0])

    def fix_line(s):
        lc = s.count('(');
        rc = s.count(')');
        s = s.split('--')[0].strip()
        if s.endswith(';') and rc != lc:
            assert False, 'invalid line: ' + s
        elif s.endswith(';') and rc == lc:
            s = s[:-1]
        elif lc > rc:
            assert False, 'invalid line: ' + s
        elif lc < rc:
            assert (rc-lc) == 1, 'invalid line: ' + s
            print(f'fixing line {s}')
            s = s[:-1]
            assert s.count('(') == s.count(')'), 'invalid fixed line: ' + s
        return s
    
    translate = lambda s: \
                fix_line(s).replace('&','*').replace('|','+').replace('next','X')
    
    env_trans = list(filter(lambda x: not not x, list(map(translate, env_trans))))
    sys_trans = list(filter(lambda x: not not x, list(map(translate, sys_trans))))
    env_just = list(filter(lambda x: not not x, list(map(translate, env_just))))
    sys_just = list(filter(lambda x: not not x, list(map(translate, sys_just))))

    env_trans = ['G(' + t + ');' for t in env_trans]
    sys_trans = ['G(' + t + ');' for t in sys_trans]
    env_just = ['G(F(' + j +'));' for j in env_just]
    sys_just = ['G(F(' + j + '));' for j in sys_just]
    
    with open(out_file, 'w') as f:
        f.write('[INPUT_VARIABLES]\n')
        f.write(';\n'.join(env_vars)+';\n')
        f.write('[OUTPUT_VARIABLES]\n')
        f.write(';\n'.join(sys_vars)+';\n')
        f.write('[ENV_INITIAL]\n')
        f.write('\n'.join(env_inis)+'\n')
        f.write('[ENV_TRANSITIONS]\n')
        f.write('\n'.join(env_trans)+'\n')
        f.write('[ENV_FAIRNESS]\n')
        f.write('\n'.join(env_just)+'\n') 
        f.write('[SYS_INITIAL]\n')
        f.write('\n'.join(sys_inis)+'\n')
        f.write('[SYS_TRANSITIONS]\n')
        f.write('\n'.join(sys_trans)+'\n')
        f.write('[SYS_FAIRNESS]\n')
        f.write('\n'.join(sys_just)+'\n')

'''
Translate smv format (or altl) to Anzu (.cfg) format
'''
def translate_dir(in_path, out_path, out_file_prefix = '', in_format = 'smv'):
    assert os.path.isdir(in_path), 'not a directory: ' + in_path
    assert os.path.isdir(out_path), 'not a directory: ' + out_path

    if in_format == 'altl':
        translate_file = translate_file_altl
        file_suffix = '.altl'
    elif in_format == 'smv':
        translate_file = translate_file_smv
        file_suffix = '.smv'
    else:
        raise Exception('unknown format')
    
    for in_file in os.listdir(in_path):
        if not isfile(join(in_path, in_file)):
            continue
        if not in_file.endswith(file_suffix):
            continue
        out_file = out_file_prefix + '_' + in_file.split('.')[0] + '.cfg'
        print(out_file)
        translate_file(join(in_path, in_file), join(out_path, out_file))

