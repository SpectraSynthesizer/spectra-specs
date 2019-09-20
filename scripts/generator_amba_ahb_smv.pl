#! /usr/bin/perl -w 

# this specification generator is provided by Barbara Jobstmann 
# and adapted for NuSMV by Andrei Tchaltsev

###############################################
# perl script to generated a config file for
# synthesizing an ARM AMBA AHB with an arbitrary
# number of masters.
#
# Usage: ./ahb_spec_generator.pl <num_of_masters>
#
# Authors: Martin Weiglhofer, Barbara Jobstmann
#
###############################################
use strict;
use POSIX; # qw(ceil floor);

###############################################
sub buildStateString {
    my ($state_name, $op, $num_states, $value, $padd_value) = @_;
    my $result = "";
    
    if(! defined $padd_value) {
	$padd_value = "0";
    }
    
    my $bin = reverse sprintf("%b", $value);
    
    for(my $j = 0; $j < $num_states; $j++) {
	if(!($result eq "")) {
	    $result .= $op;
	}
	
	my $bin_val = $padd_value;
	if($j < length($bin)) {
	    $bin_val = substr($bin, $j, 1);
	}
	
	$result .= "(" . $state_name . $j . "=" . $bin_val . ")";
    }
    
    return $result;
}

###############################################
sub buildHMasterString {
    my ($master_bits, $value) = @_;
    return buildStateString("hmaster", "&", $master_bits, $value);
}

###############################################
sub buildNegHMasterString {
    my ($master_bits, $value) = @_;
    
    my $bin = sprintf("%b", $value);
    my $new_val = "";
    for(my $j = 0; $j < length($bin); $j++) {
	if(substr($bin, $j, 1) eq "0") {
	    $new_val .= "1";
	} else {
	    $new_val .= "0";
	}
    }
    
    $bin = reverse $new_val;
    my $result = "";
    for(my $j = 0; $j < $master_bits; $j++) {
	if(!($result eq "")) {
	    $result .= "|";
	}
	
	my $bin_val = "1";
	if($j < length($bin)) {
	    $bin_val = substr($bin, $j, 1);
	}
	
	$result .= "(hmaster" . $j . "=" . $bin_val . ")";
    }
    
    return $result;
}


###############################################
#                MAIN
###############################################

if(! defined($ARGV[0])) {
    print "Usage: ./ahb_spec_generator.pl <num_of_masters>\n";
    exit;
}


my $num_masters = $ARGV[0];
my $master_bits = ceil((log $num_masters)/(log 2));
if($master_bits == 0) {
    $master_bits = 1;
}
my $master_bits_plus_one = ceil((log($num_masters+1))/(log 2));
if($master_bits == 0) {
    $master_bits = 1;
}

my $zero_state_string = buildStateString("stateA1_", "&", $master_bits_plus_one, 0);

my $env_initial = "";
my $sys_initial = "";
my $env_transitions = "";
my $sys_transitions = "";
my $env_fairness = "";
my $sys_fairness = "";
my $input_vars = "";
my $output_vars = "";

###############################################
# ENV_INITIAL and INPUT_VARIABLES
###############################################

$env_initial .= "INIT hready=0;\n";
$input_vars  .= "VAR hready: boolean;\n";

for(my $i = 0; $i < $num_masters; $i++) {
    $env_initial .= "INIT hbusreq" . $i . "=0;\n";
    $env_initial .= "INIT hlock" . $i . "=0;\n";
    $input_vars .= "VAR hbusreq" . $i . " : boolean;\n";
    $input_vars .= "VAR hlock" . $i . " : boolean;\n";
}

$env_initial .= "INIT hburst0=0;\n";
$input_vars .= "VAR hburst0 : boolean;\n";
$env_initial .= "INIT hburst1=0;\n";
$input_vars .= "VAR hburst1 : boolean;\n";

###############################################
# ENV_TRANSITION
###############################################
for(my $i = 0; $i < $num_masters; $i++) {
    $env_transitions .= "-- #Assumption 3:\n";
    $env_transitions .= "TRANS ( hlock$i=1 -> hbusreq$i=1 );\n";
}

###############################################
# ENV_FAIRNESS
###############################################
$env_fairness .= "-- #Assumption 1:\n";
$env_fairness .= "(".$zero_state_string."),\n";
$env_fairness .= "\n-- #Assumption 2:\n";
$env_fairness .= "(hready=1)\n";

###############################################
# SYS_INITIAL + OUTPUT_VARIABLES
###############################################

for(my $i = 0; $i < $master_bits; $i++) {
    $sys_initial .= "INIT hmaster" . $i . "=0;\n";
    $output_vars .= "VAR hmaster" . $i . " : boolean;\n";
}

$sys_initial .= "INIT hmastlock=0;\n";
$output_vars .= "VAR hmastlock : boolean;\n";
$sys_initial .= "INIT start=1;\n";
$output_vars .= "VAR start : boolean;\n";
$sys_initial .= "INIT decide=1;\n";
$output_vars .= "VAR decide : boolean;\n";
$output_vars .= "VAR hlocked : boolean;\n";
$sys_initial .= "INIT hlocked=0;\n";

for(my $i = 0; $i < $num_masters; $i++) {
    my $value = "0";
    if($i == 0) {
	$value = "1";
    }
    $sys_initial .= "INIT hgrant".$i."=".$value.";\n";
    $output_vars .= "VAR hgrant".$i." : boolean;\n";
}

#Assumption 1:
for(my $i = 0; $i < $master_bits_plus_one; $i++) {
    $sys_initial .= "INIT stateA1_" . $i . "=0;\n";
    $output_vars .= "VAR stateA1_" . $i . " : boolean;\n";
}

#Guarantee 2:
for(my $i = 0; $i < $num_masters; $i++) {
    $sys_initial .= "INIT stateG2_" . $i . "=0;\n";
    $output_vars .= "VAR stateG2_" . $i . " : boolean;\n";
}

#Guarantee 3:
$sys_initial .= "INIT stateG3_0=0;\n";
$output_vars .= "VAR stateG3_0 : boolean;\n";
$sys_initial .= "INIT stateG3_1=0;\n";
$output_vars .= "VAR stateG3_1 : boolean;\n";
$sys_initial .= "INIT stateG3_2=0;\n";
$output_vars .= "VAR stateG3_2 : boolean;\n";

#Guarantee 10:
for(my $i = 1; $i < $num_masters; $i++) {
    $sys_initial .= "INIT stateG10_" . $i . "=0;\n";
    $output_vars .= "VAR stateG10_" . $i . " : boolean;\n";
}

###############################################
# SYS_TRANSITION
###############################################

#Assumption 1:
$sys_transitions .= "-- #Assumption 1:\n";
$sys_transitions .= "TRANS ((" . $zero_state_string;
$sys_transitions .= "&((hmastlock=0)|((hburst0=1)|(hburst1=1)))) -> \n";
$sys_transitions .= " next(" . $zero_state_string . "));\n";

for(my $i = 0; $i < $num_masters; $i++) {
    my $i_state_string = buildStateString("stateA1_", "&",
					  $master_bits_plus_one, $i+1);
    my $hmaster = buildHMasterString($master_bits, $i);

    $sys_transitions .= "-- #  Master ".$i.":\n";
    $sys_transitions .= "TRANS ((" . $zero_state_string."&((hmastlock=1)&(";
    $sys_transitions .= $hmaster.")&((hburst0=0)&(hburst1=0)))) ->\n";
    $sys_transitions .= " next(" . $i_state_string . "));\n";
    $sys_transitions .= "TRANS ((".$i_state_string."&(hbusreq".$i."=1)) ->\n";
    $sys_transitions .= " next(" . $i_state_string . "));\n";
    $sys_transitions .= "TRANS ((".$i_state_string."&(hbusreq".$i."=0)) ->\n";
    $sys_transitions .= " next(".$zero_state_string."));\n";
}

#Guarantee 1:
$sys_transitions .= "\n-- #Guarantee 1:\n";
$sys_transitions .= "TRANS ((hready=0) -> next(start=0));\n";

#Guarantee 2:
$sys_transitions .= "\n-- #Guarantee 2:\n";
$zero_state_string = buildStateString("stateG2_", "&", $master_bits_plus_one, 0);
for(my $i = 0; $i < $num_masters; $i++) {
    my $master_state_str = buildHMasterString($master_bits, $i);

    $sys_transitions .= "-- #  Master ".$i.":\n";
    $sys_transitions .= "TRANS (((stateG2_".$i."=0)&(hmastlock=0))->next(stateG2_".$i."=0));\n";
    $sys_transitions .= "TRANS (((stateG2_".$i."=0)&(start=0))    ->next(stateG2_".$i."=0));\n";
    $sys_transitions .= "TRANS (((stateG2_".$i."=0)&(hburst0=1))  ->next(stateG2_".$i."=0));\n";
    $sys_transitions .= "TRANS (((stateG2_".$i."=0)&(hburst1=1))  ->next(stateG2_".$i."=0));\n";
    $sys_transitions .= "TRANS (((stateG2_".$i."=0)&!(".$master_state_str."))->next(stateG2_".$i."=0));\n";
    $sys_transitions .= "TRANS (((stateG2_".$i."=0)&(hmastlock=1)&(start=1)&(hburst0=0)&(hburst1=0)&(".$master_state_str."))->next(stateG2_".$i."=1));\n";
    $sys_transitions .= "TRANS (((stateG2_".$i."=1)&(start=0)&(hbusreq".$i."=1))->next(stateG2_".$i."=1));\n";
    $sys_transitions .= "TRANS (((stateG2_".$i."=1)&(start=1))->FALSE);\n";
    $sys_transitions .= "TRANS (((stateG2_".$i."=1)&(start=0)&(hbusreq".$i."=0))  ->next(stateG2_".$i."=0));\n";
}

#Guarantee 3:
$sys_transitions .= "\n-- #Guarantee 3:\n";
$sys_transitions .= "TRANS (((stateG3_0=0)&(stateG3_1=0)&(stateG3_2=0)&\n";
$sys_transitions .= "  ((hmastlock=0)|(start=0)|((hburst0=1)|(hburst1=0)))) ->\n";
$sys_transitions .= " next((stateG3_0=0)&(stateG3_1=0)&(stateG3_2=0))); \n";
$sys_transitions .= "TRANS (((stateG3_0=0)&(stateG3_1=0)&(stateG3_2=0)&\n";
$sys_transitions .= "  ((hmastlock=1)&(start=1)&((hburst0=0)&(hburst1=1))&(hready=0))) -> \n";
$sys_transitions .= " next((stateG3_0=1)&(stateG3_1=0)&(stateG3_2=0))); \n";
$sys_transitions .= "TRANS (((stateG3_0=0)&(stateG3_1=0)&(stateG3_2=0)&\n";
$sys_transitions .= "  ((hmastlock=1)&(start=1)&((hburst0=0)&(hburst1=1))&(hready=1))) -> \n";
$sys_transitions .= " next((stateG3_0=0)&(stateG3_1=1)&(stateG3_2=0))); \n";
$sys_transitions .= " \n";
$sys_transitions .= "TRANS (((stateG3_0=1)&(stateG3_1=0)&(stateG3_2=0)&((start=0)&(hready=0))) -> \n";
$sys_transitions .= " next((stateG3_0=1)&(stateG3_1=0)&(stateG3_2=0))); \n";
$sys_transitions .= "TRANS (((stateG3_0=1)&(stateG3_1=0)&(stateG3_2=0)&((start=0)&(hready=1))) -> \n";
$sys_transitions .= " next((stateG3_0=0)&(stateG3_1=1)&(stateG3_2=0))); \n";
$sys_transitions .= "\n";
$sys_transitions .= "TRANS (((stateG3_0=1)&(stateG3_1=0)&(stateG3_2=0)&((start=1))) -> FALSE); \n";
$sys_transitions .= "\n";
$sys_transitions .= " \n";
$sys_transitions .= "TRANS (((stateG3_0=0)&(stateG3_1=1)&(stateG3_2=0)&((start=0)&(hready=0))) -> \n";
$sys_transitions .= " next((stateG3_0=0)&(stateG3_1=1)&(stateG3_2=0))); \n";
$sys_transitions .= "TRANS (((stateG3_0=0)&(stateG3_1=1)&(stateG3_2=0)&((start=0)&(hready=1))) -> \n";
$sys_transitions .= " next((stateG3_0=1)&(stateG3_1=1)&(stateG3_2=0))); \n";
$sys_transitions .= "TRANS (((stateG3_0=0)&(stateG3_1=1)&(stateG3_2=0)&((start=1))) -> FALSE); \n";
$sys_transitions .= " \n";
$sys_transitions .= "TRANS (((stateG3_0=1)&(stateG3_1=1)&(stateG3_2=0)&((start=0)&(hready=0))) -> \n";
$sys_transitions .= " next((stateG3_0=1)&(stateG3_1=1)&(stateG3_2=0))); \n";
$sys_transitions .= "TRANS (((stateG3_0=1)&(stateG3_1=1)&(stateG3_2=0)&((start=0)&(hready=1))) -> \n";
$sys_transitions .= " next((stateG3_0=0)&(stateG3_1=0)&(stateG3_2=1))); \n";
$sys_transitions .= "TRANS (((stateG3_0=1)&(stateG3_1=1)&(stateG3_2=0)&((start=1))) -> FALSE); \n";
$sys_transitions .= " \n";
$sys_transitions .= "TRANS (((stateG3_0=0)&(stateG3_1=0)&(stateG3_2=1)&((start=0)&(hready=0))) -> \n";
$sys_transitions .= " next((stateG3_0=0)&(stateG3_1=0)&(stateG3_2=1))); \n";
$sys_transitions .= "TRANS (((stateG3_0=0)&(stateG3_1=0)&(stateG3_2=1)&((start=0)&(hready=1))) -> \n";
$sys_transitions .= " next((stateG3_0=0)&(stateG3_1=0)&(stateG3_2=0)));\n";
$sys_transitions .= "\n";
$sys_transitions .= "TRANS (((stateG3_0=0)&(stateG3_1=0)&(stateG3_2=1)&((start=1))) -> FALSE); \n";


#Guarantee 4 and 5:
$sys_transitions .= "\n-- #Guarantee 4 and 5:\n";
for(my $i = 0; $i < $num_masters; $i++) {
  my $hmaster = buildHMasterString($master_bits, $i);
  $sys_transitions .= "-- #  Master ".$i.":\n";
  $sys_transitions .= "TRANS ((hready=1) -> ((hgrant" . $i . "=1) <-> next(" . $hmaster . ")));\n";
}
$sys_transitions .= "-- #  HMASTLOCK:\n";
$sys_transitions .= "TRANS ((hready=1) -> (hlocked=0 <-> next(hmastlock=0)));\n";

#Guarantee 6.1:
$sys_transitions .= "\n-- #Guarantee 6.1:\n";
for(my $i = 0; $i < $num_masters; $i++) {
  my $hmaster = buildHMasterString($master_bits, $i);
  $sys_transitions .= "-- #  Master ".$i.":\n";
  $sys_transitions .= "TRANS (next(start=0) -> ((" . $hmaster . ") <-> (next(" . $hmaster . "))));\n";
}

#Guarantee 6.2:
$sys_transitions .= "\n-- #Guarantee 6.2:\n";
$sys_transitions .= "TRANS (((next(start=0))) -> ((hmastlock=1) <-> next(hmastlock=1)));\n";

#Guarantee 7:
$sys_transitions .= "\n-- #Guarantee 7:\n";
my $norequest = "";
for(my $i = 0; $i < $num_masters; $i++) {
    $sys_transitions .= "TRANS ((decide=1 & hlock$i=1 & next(hgrant$i=1))->next(hlocked=1));\n";
    $sys_transitions .= "TRANS ((decide=1 & hlock$i=0 & next(hgrant$i=1))->next(hlocked=0));\n";
    
    $norequest .= "hbusreq$i=0";
    $norequest .= " & " if ($i < $num_masters-1);
}
$sys_transitions .= "-- #default master\n";
$sys_transitions .= "TRANS ((decide=1 & ".$norequest.") -> next(hgrant0=1));\n";

#Guarantee 8:
#MW: Note, that this formula changes with respect to the number of grant signals
$sys_transitions .= "\n-- #Guarantee 8:\n";
my $tmp_g8 = "";
for(my $i = 0; $i < $num_masters; $i++) {
  $sys_transitions .= "TRANS ((decide=0)->(((hgrant" . $i . "=0)<->next(hgrant" . $i . "=0))));\n";
}
$sys_transitions .= "TRANS ((decide=0)->(hlocked=0 <-> next(hlocked=0)));\n";

#Guarantee 10:
$sys_transitions .= "\n-- #Guarantee 10:\n";
for(my $i = 1; $i < $num_masters; $i++) {
  my $neghmaster = buildNegHMasterString($master_bits, $i);
  my $hmaster = buildHMasterString($master_bits, $i);

  $sys_transitions .= "-- #  Master ".$i.":\n";
  $sys_transitions .= "TRANS (((stateG10_".$i."=0)&(((hgrant".$i."=1)|(hbusreq".$i."=1))))->next(stateG10_".$i."=0));\n";
  $sys_transitions .= "TRANS (((stateG10_".$i."=0)&((hgrant".$i."=0)&(hbusreq".$i."=0)))->next(stateG10_".$i."=1));\n";
  $sys_transitions .= "TRANS (((stateG10_".$i."=1)&((hgrant".$i."=0)&(hbusreq".$i."=0)))->next(stateG10_".$i."=1));\n";
  $sys_transitions .= "TRANS (((stateG10_".$i."=1)&(((hgrant".$i."=1))&(hbusreq".$i."=0)))->FALSE);\n";
  $sys_transitions .= "TRANS (((stateG10_".$i."=1)&(hbusreq".$i."=1))->next(stateG10_".$i."=0));\n";
}


###############################################
# SYS_FAIRNESS
###############################################
#Guarantee 2:
$sys_fairness .= "\n-- #Guarantee 2:\n";
for(my $i = 0; $i < $num_masters; $i++) {
    $sys_fairness .= "(stateG2_$i=0),\n";
}

#Guarantee 3:
$sys_fairness .= "\n-- #Guarantee 3:\n";
$sys_fairness .= "((stateG3_0=0) & (stateG3_1=0) & (stateG3_2=0)),\n";

#Guarantee 9:
$sys_fairness .= "\n-- #Guarantee 9:\n";
for(my $i = 0; $i < $num_masters; $i++) {
  $sys_fairness .= "((" . buildHMasterString($master_bits, $i) . ") | hbusreq" . $i . "=0),\n";
}
$sys_fairness .= "TRUE\n";

###############################################
# PRINT CONFIG FILE
###############################################

print "GAME\n\n";

print "-- ###############################################\n";
print "-- # Environment specification\n";
print "-- ###############################################\n";

print "\nPLAYER_1\n\n";

print "-- ###############################################\n";
print "-- # Input variable definition\n";
print "-- ###############################################\n";
print "-- [INPUT_VARIABLES]\n";
print $input_vars;
print "\n";

print "-- [ENV_INITIAL]\n";
print $env_initial;
print "\n";
print "-- [ENV_TRANSITIONS]\n";
print $env_transitions;
print "\n";

print "-- ###############################################\n";
print "-- # System specification\n";
print "-- ###############################################\n";

print "\nPLAYER_2\n\n";

print "-- ###############################################\n";
print "-- # Output variable definition\n";
print "-- ###############################################\n";
print "-- [OUTPUT_VARIABLES]\n";
print $output_vars;
print "\n";

print "-- [SYS_INITIAL]\n";
print $sys_initial;
print "\n";
print "-- [SYS_TRANSITIONS]\n";
print $sys_transitions;
print "\n";


print "-- ###############################################\n";
print "-- # PROPERTY\n";
print "-- ###############################################\n";
print "GENREACTIVITY PLAYER_2\n(\n";

print "-- [ENV_FAIRNESS]\n";
print $env_fairness;
print "\n)->(\n";

print "-- [SYS_FAIRNESS]\n";
print $sys_fairness;
print ")\n";
