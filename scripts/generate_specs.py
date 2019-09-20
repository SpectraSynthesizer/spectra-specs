#!/usr/bin/python3.6
'''
Functions for easily translating generated AMBA and GenBuf specifications
NOTE: 1. Run function from python (no main here).
      2. Set the paths to perl and python2.7 (perl_path and py2_path below),
         since the generators are written in perl and Slugs and Ratsy trunslators
         written in python2
'''
import subprocess
import os.path
from subprocess import Popen, PIPE, STDOUT
from translateFromAnzuToSpectra import translate_file as spectra_trans
from translateToAnzuFormat import translate_file_smv

#Path to the perl executable
perl_path = 'C:/Strawberry/perl/bin'
perl_exe = 'perl.exe'
perl_exe = os.path.join(perl_path, perl_exe)

#Path to the python2.7 executable
py2_path = 'C:/Python27'
py2_exe = 'python.exe'
py2_exe = os.path.join(py2_path, py2_exe)

def gen_amba(script, filename, num, unreal = ''):
    cmd = [perl_exe, script, str(num)]
    if unreal:
        cmd.append(unreal)
    with open(filename, 'w') as f:
        p = Popen(cmd, stdout=f, stderr=f, shell=True)
        rc = p.wait()
        assert rc == 0, f'Failed to generate {filename}'
        
def gen_genbuf(script, filename, num, unreal = ''):
    cmd = [perl_exe, script, str(num), filename]
    if unreal:
        cmd.append(unreal)
    with open('tmp.txt', 'w') as f:
        p = Popen(cmd, stdout=f, stderr=f, shell=True)
        rc = p.wait()
        assert rc == 0, f'Failed to generate {filename}'
        
class SpecGen:
    def __init__(self, filename, out_dir, num):
        self.filename = filename
        self.out_dir = out_dir
        self.file_cfg = f'{filename}.cfg'
        self.file_smv = f'{filename}.smv'
        self.file_spectra = f'{filename}.spectra'
        self.file_slugsin = f'{filename}.slugsin'
        self.file_rat = f'{filename}.rat'
        self.num = num

    def join(self, file):
        return os.path.join(self.out_dir, file)
    '''
    These generators are from RATSY
    The AMBA generator generates (for any number of masters):
        - A single variable stateG2 for guarantee 1
        - 2 variable stateA1_0 and stateA1_1 for assumption 1 
    (seems like the original version of the AMBA specs)
    '''
    def gen_amba_cfg(self):
        gen_amba('amba_ahb_spec_generator.pl', self.join(self.file_cfg), self.num)

    def gen_genbuf_cfg(self):
        gen_genbuf('genbuf_spec_generator.pl', self.join(self.filename), self.num)

    '''
    The smv generators are from https://es-static.fbk.eu/people/roveri/tests/vmcai08/
    The AMBA version generates (for n masters):
        - n variables of stateG2 for guarantee1: stateG2_0, stateG2_1,..., stateG2_(n-1)
        - Number of bits representing n is k:
            k variables of stateA1 for assumption 1: stateA1_0, stateA1_1,..., stateA1_(k-1)
        - All these variablea are used in additional safeties.
    This Genbuf generator generates same spec as RATSY
    These versions are the ones that were used for Spectra tests (and are in the repository)
    '''
    def gen_amba_smv(self):
        gen_amba('generator_amba_ahb_smv.pl', self.join(self.file_smv), self.num)

    def gen_amba_unreal_smv(self, unreal):
        gen_amba('generator_amba_ahb_smv-unreal.pl', self.join(self.file_smv), self.num, unreal)
        
    ''' This generator generates same spec as RATSY'''
    def gen_genbuf_smv(self):
        gen_genbuf('genbuf_spec_generator-smv.pl', self.join(self.filename), self.num)

    def gen_genbuf_unreal_smv(self, unreal):
        gen_genbuf('genbuf_spec_generator-smv-unreal.pl', self.join(self.filename), self.num, unreal)

    def cfg_to_slugs(self):
        cmd = [py2_exe, 'translateFromRatsyFormatToSlugsFormat.py', self.join(self.file_cfg)]
        with open(self.join(self.file_slugsin), 'w') as f:
            p = Popen(cmd, stdout=f, stderr=f, shell=True)
            rc = p.wait()
            assert rc == 0, f'Failed to generate {ofile}'
    def cfg_to_ratsy(self):
        cmd = [py2_exe, 'convert_anzu_input_to_ratsy.py', '-i', self.join(self.file_cfg), '-o', self.join(self.file_rat)]
        with open('tmp.txt', 'w') as f:
            p = Popen(cmd, stdout=f, stderr=f, shell=True)
            rc = p.wait()
            assert rc == 0, f'Failed to generate {ofile}'

    def cfg_to_spectra(self):
        spectra_trans(self.join(self.file_cfg), self.join(self.file_spectra))

    def smv_to_cfg(self):
        translate_file_smv(self.join(self.file_smv), self.join(self.file_cfg))

'''
Realizable AMBA specification (according to vmcai08 version)
Params: out_dir - directory for output files
        num - number of masters
'''
def gen_amba_specs(out_dir, num):
    filename = f'amba_ahb_{num:02}'
    sg = SpecGen(filename, out_dir, num)
    sg.gen_amba_smv()
    sg.smv_to_cfg()
    sg.cfg_to_spectra()
    sg.cfg_to_slugs()
    sg.cfg_to_ratsy()

'''
Realizable Genbuf specification
Params: out_dir - directory for output files
        num - number of senders
'''
def gen_genbuf_specs(out_dir, num):
    filename = f'genbuf_{num:02}'
    sg = SpecGen(filename, out_dir, num)
    sg.gen_genbuf_smv()
    sg.smv_to_cfg()
    sg.cfg_to_spectra()
    sg.cfg_to_slugs()
    sg.cfg_to_ratsy()

'''
Unrealizable AMBA specification (according to vmcai08):
w_guar_fairness: The same as AMBA but with one additional player 2 fairness conditions.
w_guar_trans: The same as AMBA but with one additional player 2 transition relation.
wo_ass_fairness: The same as AMBA but without one player 1 fairness conditions.
Params: out_dir - directory for output files
        num - number of masters
        unreal - one of the strings described above
'''
def gen_unreal_amba_specs(out_dir, num, unreal):
    assert unreal == 'w_guar_fairness' or unreal == 'w_guar_trans' or unreal == 'wo_ass_fairness'
    filename = f'amba_ahb_{unreal}_{num:02}'
    sg = SpecGen(filename, out_dir, num)
    sg.gen_amba_unreal_smv(unreal)
    sg.smv_to_cfg()
    sg.cfg_to_spectra()
    sg.cfg_to_slugs()
    sg.cfg_to_ratsy()

'''
Unrealizable Genbuf specification (according to vmcai08):
w_guar_fairness: The same as Genbuf but with one additional player 2 fairness conditions.
w_guar_trans: The same as Genbuf but with one additional player 2 transition relation.
wo_ass_fairness: The same as Genbuf but without one player 1 fairness conditions.
Params: out_dir - directory for output files
        num - number of senders
        unreal - one of the strings described above
'''
def gen_unreal_genbuf_specs(out_dir, num, unreal):
    assert unreal == 'w_guar_fairness' or unreal == 'w_guar_trans' or unreal == 'wo_ass_fairness'
    filename = f'genbuf_{unreal}_{num:02}'
    sg = SpecGen(filename, out_dir, num)
    sg.gen_genbuf_unreal_smv(unreal)
    sg.smv_to_cfg()
    sg.cfg_to_spectra()
    sg.cfg_to_slugs()
    sg.cfg_to_ratsy()
    
        
