In this folder there are several scripts for translating between different formats:

The main script is generate_specs.py:
-------------------------------------
 1. It calls all the other scripts: generating specifications of different sizes 
    and then translating to different formats
 2. Has various functions to call different specification generators
	and different translators.
 3. Runs from python3.6 (no main)
 4. See more details in the script
 
Translation scripts:
--------------------
 1. translateFromAnzuToSpectra.py: translates .cfg files to Spectra format
 2. translateToAnzuFormat.py: translates .smv files (SMV format) to .cfg files (Anzu format)
 3. translateFromRatsyFormatToSlugsFormat.py: this script was taken from the Slugs 
	repository (in github), and translates .cfg files to .slugsin files (Slugs format).
	Note that slugs_parser.py is needed by this script.
 4. convert_anzu_input_to_ratsy.py: translates .cfg files to .rat files (RATSY format).
	This script was taken from the website of RATSY
	
Generator scripts:
------------------
 1. amba_ahb_spec_generator.pl and genbuf_spec_generator.pl:
	Generators from RATSY.
	The AMBA generator seems to generate the original version of the AMBA specifications.
 2. generator_amba_ahb_smv.pl and genbuf_spec_generator-smv.pl:
    Generators from vmcai08 (https://es-static.fbk.eu/people/roveri/tests/vmcai08/)
    The AMBA generator seems to generate some other AMBA version (with more variables and safeties).
	NOTE: this AMBA version is the one that are used for Spectra tests and in the Spectra reporitory.
 3. generator_amba_ahb_smv-unreal.pl and genbuf_spec_generator-smv-unreal.pl
    Modified versions of the generatores from 2.
	Added an option for 'unrealizability' as described in vmcai08.
	
Note on the different AMBA specifications:
------------------------------------------
The generators from RATSY (1):
    The AMBA generator generates (for any number of masters):
        - A single variable stateG2 for guarantee 1
        - 2 variable stateA1_0 and stateA1_1 for assumption 1 
		
The generators from vmcai08 (2):
    The AMBA generator generates (for n masters):
        - n variables of stateG2 for guarantee 1: stateG2_0, stateG2_1,..., stateG2_(n-1)
        - Number of bits representing n is k:
            k variables of stateA1 for assumption 1: stateA1_0, stateA1_1,..., stateA1_(k-1)
		- All these variablea are used in additional safeties.
