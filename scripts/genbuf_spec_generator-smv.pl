#! /usr/bin/perl -w 

###############################################
# perl script to generated LTL specification and
# config file to synthesize a generalized buffer
# between k senders and 2 receivers.
#
# Usage: ./genbuf_generator.pl <num_of_senders> <prefix>
#
# Generated files: prefix.ltl prefix.cfg
# Default prefix is __
#
###############################################
use strict;
use POSIX; # qw(ceil floor);

sub slc {
    my $j = shift;
    my $bits = shift;
    my $assign = "";
    my $val;

    for (my $bit = 0; $bit < $bits; $bit++) {
	$val = $j % 2;
	$assign .= "SLC$bit=$val";
	$assign .= " & " unless ($bit == $bits-1);
	$j = floor($j/2);
    }
    return $assign;
}

###############################################
# MAIN

if(! defined($ARGV[0])) {
    print "Usage: ./genbuf_generator.pl <num_of_senders> <prefix>\n";
    exit;
}

my $prefix = "__";
if( defined($ARGV[1])) {
    $prefix = $ARGV[1];
}

#variables for LTL specification
my $num_senders = $ARGV[0];
my $slc_bits = ceil((log $num_senders)/(log 2));
$slc_bits = 1 if ($slc_bits == 0);
my $num_receivers = 2;
my $guarantees = "";
my @assert;
my $assumptions = "";
my @assume;

#variables for config file
my $input_vars  = "";
my $output_vars = "";
my $env_initial = "";
my $sys_initial = "";
my $env_transitions = "";
my $sys_transitions = "";
my $env_fairness = "";
my $sys_fairness = "";

###############################################
# Communication with senders
#
my ($g, $a);
for (my $i=0; $i < $num_senders; $i++) {
    #variable definition
    $input_vars .= "VAR StoB_REQ$i : boolean;\n";
    $output_vars.= "VAR BtoS_ACK$i : boolean;\n";

    #initial state
    $env_initial .= "INIT StoB_REQ$i=0;\n";
    $sys_initial .= "INIT BtoS_ACK$i=0;\n";
    
    $guarantees .= "\n##########################################\n";
    $guarantees .= "--Guarantees for sender $i\n";
    
    ##########################################
    # Guarantee 1
    $g = "G(StoB_REQ$i=1 -> F(BtoS_ACK$i=1));\t--G1\n";
    $guarantees .= $g; push (@assert, $g);
    # Guarantee 2
    $g = "TRANS ((StoB_REQ$i=0 & next(StoB_REQ$i=1)) -> next(BtoS_ACK$i=0));\t--G2\n";
    $guarantees .= $g; push (@assert, $g);
    $sys_transitions .= $g;
    $sys_fairness .= "StoB_REQ$i=1 <-> BtoS_ACK$i=1,\n";
    
    # Guarantee 3
#    $g = "TRANS (StoB_REQ$i=0 -> (BtoS_ACK$i=1 | next(BtoS_ACK$i=0)));\t--G3\n";
    $g = "TRANS ((BtoS_ACK$i=0 & StoB_REQ$i=0) -> next(BtoS_ACK$i=0));\t--G2\n";
    $guarantees .= $g; push (@assert, $g);
    $sys_transitions .= $g;
    
    # Guarantee 4
    $g = "TRANS ((BtoS_ACK$i=1 & StoB_REQ$i=1) -> next(BtoS_ACK$i=1));\t--G4\n";
    $guarantees .= $g; push (@assert, $g);
    $sys_transitions .= $g;
    
    # Assumption 1
    $a = "TRANS ((StoB_REQ$i=1 & BtoS_ACK$i=0) -> next(StoB_REQ$i=1));\t--A1\n";
    $assumptions .= $a; push (@assume, $a);
    $env_transitions .= $a;
    $a = "TRANS (BtoS_ACK$i=1 -> next(StoB_REQ$i=0));\t--A1\n";
    $assumptions .= $a; push (@assume, $a);
    $env_transitions .= $a;
    
    # Guarantee 5
    for (my $j=$i+1; $j < $num_senders; $j++) {
	$g = "TRANS ((BtoS_ACK$i=0) | (BtoS_ACK$j=0));\t--G5\n";
	$guarantees .= $g; push (@assert, $g);
	$sys_transitions .= $g;
    }
}

###############################################
# Communication with receivers
#
if ($num_receivers != 2) {
    print "Note that the DBW for Guarantee 7 works only for two receivers.\n";
    exit;
}
for (my $j=0; $j < $num_receivers; $j++) {
    #variable definition
    $input_vars .= "VAR RtoB_ACK$j : boolean;\n";
    $output_vars.= "VAR BtoR_REQ$j : boolean;\n";

    #initial state
    $env_initial .= "INIT RtoB_ACK$j=0;\n";
    $sys_initial .= "INIT BtoR_REQ$j=0;\n";
    
    $guarantees .= "\n##########################################\n";
    $guarantees .= "# Guarantees for receiver $j\n";
    
    # Assumption 2
    $a = "TRANS (BtoR_REQ$j=1 -> F(RtoB_ACK$j=1));\t--A2\n";
    $assumptions .= $a; push (@assume, $a);
    $env_fairness .= "BtoR_REQ$j=1 <-> RtoB_ACK$j=1,\n";
    
    # Assumption 3
    $a = "TRANS (BtoR_REQ$j=0 -> next(RtoB_ACK$j=0));\t--A3\n";
    $assumptions .= $a; push (@assume, $a);
    $env_transitions .= $a;
    
    # Assumption 4
    $a = "TRANS ((BtoR_REQ$j=1 & RtoB_ACK$j=1) -> next(RtoB_ACK$j=1));\t--A4\n";
    $assumptions .= $a; push (@assume, $a);
    $env_transitions .= $a;

    # Guarantee 6
    $g = "TRANS ((BtoR_REQ$j=1 & RtoB_ACK$j=0) -> next(BtoR_REQ$j=1));\t--G6\n";
    $guarantees .= $g; push (@assert, $g);
    $sys_transitions .= $g;

    # Guarantee 7
    for (my $k=$j+1; $k < $num_receivers; $k++) {
	$g = "TRANS ((BtoR_REQ$j=0) | (BtoR_REQ$k=0));\t--G7\n";
	$guarantees .= $g; push (@assert, $g);
	$sys_transitions .= $g;
    }
    # G7: rose($j) -> X (no_rose W rose($j+1 mod $num_receivers))
    my $n = ($j + 1)%$num_receivers; #next
    my $rose_j  = "(BtoR_REQ$j=0 & next(BtoR_REQ$j=1))";
    my $nrose_j = "(BtoR_REQ$j=1 | next(BtoR_REQ$j=0))";
    my $rose_n  = "(BtoR_REQ$n=0 & next(BtoR_REQ$n=1))";
    $g = "G(  $rose_j ->\n next(($nrose_j U $rose_n) | \n G($nrose_j)));\t--G7\n";
    $guarantees .= $g; push (@assert, $g);
    #construct DBW for G7 - see below
    
    # Guarantee 6 and 8
    $g = "TRANS (RtoB_ACK$j=1 -> next(BtoR_REQ$j=0));\t--G8\n";
    $guarantees .= $g; push (@assert, $g);
    $sys_transitions .= $g;
}

# DBW for guarantee 7
$output_vars .= "VAR stateG7_0 : boolean;\n";
$output_vars .= "VAR stateG7_1 : boolean;\n";
$sys_initial .= "INIT stateG7_0=0;\n";
$sys_initial .= "INIT stateG7_1=1;\n";
$sys_transitions .= "TRANS ((BtoR_REQ0=1 & BtoR_REQ1=1) -> FALSE);\t--G7\n";
$sys_transitions .= "TRANS ((stateG7_1=0 & BtoR_REQ0=0 & BtoR_REQ1=1) ->";
$sys_transitions .= " next(stateG7_1=1 & stateG7_0=0));--G7\n";
$sys_transitions .= "TRANS ((stateG7_1=1 & BtoR_REQ0=1 & BtoR_REQ1=0) ->";
$sys_transitions .= " next(stateG7_1=0 & stateG7_0=0));--G7\n";
$sys_transitions .= "TRANS ((stateG7_1=0 & BtoR_REQ0=0 & BtoR_REQ1=0) ->";
$sys_transitions .= " next(stateG7_1=0 & stateG7_0=1));--G7\n";
$sys_transitions .= "TRANS ((stateG7_1=1 & BtoR_REQ0=0 & BtoR_REQ1=0) ->";
$sys_transitions .= " next(stateG7_1=1 & stateG7_0=1));--G7\n";
$sys_transitions .= "TRANS ((stateG7_1=0 & stateG7_0=0 & BtoR_REQ0=1 & BtoR_REQ1=0) ->\n";
$sys_transitions .= " next(stateG7_1=0 & stateG7_0=0));\t--G7\n";
$sys_transitions .= "TRANS ((stateG7_1=1 & stateG7_0=0 & BtoR_REQ0=0 & BtoR_REQ1=1) ->\n";
$sys_transitions .= " next(stateG7_1=1 & stateG7_0=0));\t--G7\n";
$sys_transitions .= "TRANS ((stateG7_1=0 & stateG7_0=1 & BtoR_REQ0=1) -> FALSE);\t--G7\n";
$sys_transitions .= "TRANS ((stateG7_1=1 & stateG7_0=1 & BtoR_REQ1=1) -> FALSE);\t--G7\n";

###############################################
# Communication with FIFO and multiplexer
#
#variable definition
$input_vars .= "VAR FULL : boolean;\n";
$input_vars .= "VAR EMPTY : boolean;\n";
$output_vars .= "VAR ENQ : boolean;\n";
$output_vars .= "VAR DEQ : boolean;\n";
$output_vars .= "VAR stateG12 : boolean;\n";

#initial state
$env_initial .= "INIT FULL=0;\n";
$env_initial .= "INIT EMPTY=1;\n";
$sys_initial .= "INIT ENQ=0;\n";
$sys_initial .= "INIT DEQ=0;\n";
$sys_initial .= "INIT stateG12=0;\n";

for (my $bit=0; $bit < $slc_bits; $bit++) {
    $output_vars .= "VAR SLC$bit : boolean;\n";
    $sys_initial .= "INIT SLC$bit=0;\n";
}

$guarantees .= "\n##########################################\n";
$guarantees .= "# Guarantees for FIFO and multiplexer\n";

# Guarantee 9: ENQ and SLC
$guarantees .= "\n##########################################\n";
$guarantees .= "# ENQ <-> Exists i: rose(BtoS_ACKi)\n";
my $roseBtoS  = "";
my $roseBtoSi = "";
for (my $i=0; $i < $num_senders; $i++) {
    $roseBtoSi = "(BtoS_ACK$i=0 & next(BtoS_ACK$i=1))";
    $g = "TRANS ($roseBtoSi -> next(ENQ=1));\t--G9\n";
    $guarantees .= $g; push (@assert, $g);
    $sys_transitions .= $g;
    
    $roseBtoS   .=   "(BtoS_ACK$i=1 | next(BtoS_ACK$i=0))";
    $roseBtoS   .= " &\n   " if ($i < ($num_senders - 1));
    if ($i == 0) {
	$g = "TRANS ($roseBtoSi  -> next(".slc($i, $slc_bits)."));\t--G9\n";
    } else {
	$g = "TRANS ($roseBtoSi <-> next(".slc($i, $slc_bits)."));\t--G9\n";
    }
    $guarantees .= $g; push (@assert, $g);
    $sys_transitions .= $g;
}
$g = "TRANS (($roseBtoS) -> next(ENQ=0));\t--G9\n";
$guarantees .= $g; push (@assert, $g);
$sys_transitions .= $g;

# Guarantee 10
$guarantees .= "\n##########################################\n";
$guarantees .= "# DEQ <-> Exists j: fell(RtoB_ACKj)\n";
my $fellRtoB = "";
for (my $j=0; $j < $num_receivers; $j++) {
    $g = "TRANS ((RtoB_ACK$j=1 & next(RtoB_ACK$j=0)) -> next(DEQ=1));\t--G10\n";
    $guarantees .= $g; push (@assert, $g);
    $sys_transitions .= $g;
    $fellRtoB   .=   "(RtoB_ACK$j=0 | next(RtoB_ACK$j=1))";
    $fellRtoB   .= " &\n   " if ($j < ($num_receivers - 1));
}
$g = "TRANS (($fellRtoB) -> next(DEQ=0));\t--G10\n";
$guarantees .= $g; push (@assert, $g);
$sys_transitions .= $g;

# Guarantee 11
$guarantees .= "\n";
$g = "TRANS ((FULL=1 & DEQ=0) -> ENQ=0);\t--G11\n";
$guarantees .= $g; push (@assert, $g);
$sys_transitions .= $g;

$g = "TRANS (EMPTY=1 -> DEQ=0);\t--G11\n";
$guarantees .= $g; push (@assert, $g);
$sys_transitions .= $g;

# Guarantee 12
$g = "G (EMPTY=0 -> F(DEQ=1));\t--G12\n";
$guarantees .= $g; push (@assert, $g);
$sys_transitions .= "TRANS ((stateG12=0 & EMPTY=1) -> next(stateG12=0));\t--G12\n";
$sys_transitions .= "TRANS ((stateG12=0 & DEQ=1  ) -> next(stateG12=0));\t--G12\n";
$sys_transitions .= "TRANS ((stateG12=0 & EMPTY=0 & DEQ=0) -> next(stateG12=1));\t--G12\n";
$sys_transitions .= "TRANS ((stateG12=1 & DEQ=0  ) -> next(stateG12=1));\t--G12\n";
$sys_transitions .= "TRANS ((stateG12=1 & DEQ=1  ) -> next(stateG12=0));\t--G12\n";
$sys_fairness .= "stateG12=0,\n";

# Assumption 4
$a = "TRANS ((ENQ=1 & DEQ=0) -> next(EMPTY=0));\t--A4\n";
$assumptions .= $a; push (@assume, $a);
$env_transitions .= $a;

$a = "TRANS ((DEQ=1 & ENQ=0) -> next(FULL=0));\t--A4\n";
$assumptions .= $a; push (@assume, $a);
$env_transitions .= $a;

$a  = "TRANS ((ENQ=1 <-> DEQ=1) -> ((FULL=1 <-> next(FULL=1)) &\n";
$a .= "                        (EMPTY=1 <-> next(EMPTY=1))));\t--A4\n";
$assumptions .= $a; push (@assume, $a);
$env_transitions .= $a;

#AT# ###############################################
#AT# # PRINT LTL FILE
#AT# ###############################################
#AT# print "Generating $prefix.ltl\n";
#AT# open (LTL, ">$prefix.ltl");
#AT# 
#AT# print LTL "##########################################\n";
#AT# print LTL "# Assumptions\n";
#AT# print LTL "##########################################\n";
#AT# print LTL $assumptions;
#AT# 
#AT# print LTL "\n##########################################\n";
#AT# print LTL "# Guarantees\n";
#AT# print LTL "##########################################\n";
#AT# print LTL $guarantees;
#AT# 
#AT# close LTL;
#AT# 
#AT# ###############################################
#AT# # PRINT LTL FILE with ASSUMPTIONS
#AT# ###############################################
#AT# print "Generating $prefix-assume.ltl\n";
#AT# open (LTL, ">$prefix-assume.ltl");
#AT# print LTL "##########################################\n";
#AT# print LTL "# Assumptions\n";
#AT# print LTL "##########################################\n";
#AT# $a=0;
#AT# my $stmt = "";
#AT# foreach (@assume) {
#AT#     s/;//;
#AT#     print LTL "\\define A$a $_";
#AT#     $stmt .= " & " unless ($a eq 0);
#AT#     $stmt .= "\\A$a";
#AT#     $a++;
#AT# }
#AT# print LTL "\\define assume ($stmt)\n";
#AT# 
#AT# print LTL "\n##########################################\n";
#AT# print LTL "# Guarantees\n";
#AT# print LTL "##########################################\n";
#AT# foreach (@assert) {
#AT#     print LTL "\\assume -> $_";
#AT# }
#AT# close LTL;
  
###############################################
# PRINT CONFIG FILE
###############################################
print "Generating $prefix.smv\n";
open (CFG, ">$prefix.smv");

print CFG "GAME\n\n";

print CFG "PLAYER_1\n";
print CFG "--###############################################\n";
print CFG "--# Input variable definition\n";
print CFG "--###############################################\n";
print CFG $input_vars;
print CFG "\n";

print CFG "--###############################################\n";
print CFG "--# Environment specification\n";
print CFG "--###############################################\n";
print CFG "--[ENV_INITIAL]\n";
print CFG $env_initial;
print CFG "\n";
print CFG "--[ENV_TRANSITIONS]\n";
print CFG $env_transitions;
print CFG "\n";

print CFG "PLAYER_2\n";
print CFG "--###############################################\n";
print CFG "--# Output variable definition\n";
print CFG "--###############################################\n";
print CFG "--[OUTPUT_VARIABLES]\n";
print CFG $output_vars;
print CFG "\n";

print CFG "--###############################################\n";
print CFG "--# System specification\n";
print CFG "--###############################################\n";
print CFG "--[SYS_INITIAL]\n";
print CFG $sys_initial;
print CFG "\n";
print CFG "--[SYS_TRANSITIONS]\n";
print CFG $sys_transitions;
print CFG "\n";

print CFG "GENREACTIVITY PLAYER_2 (\n";
print CFG "--[ENV_FAIRNESS]\n";
print CFG $env_fairness;
print CFG "1) -> (\n";
print CFG "--[SYS_FAIRNESS]\n";
print CFG $sys_fairness;
print CFG "1)\n";

close CFG;


#AT# ###############################################
#AT# # PRINT CONFIG FILE
#AT# ###############################################
#AT# print "Generating DBW file $prefix-dbw.v\n";
#AT# open (DBW, ">$prefix-dbw.v");
#AT# 
#AT# # DBW for guarantee 7
#AT# print DBW "//Note that the DBW for G7 works only for two receivers.\n";
#AT# print DBW "module DBW7(stateG7_1_n, stateG7_0_n, stateG7_1_p, stateG7_0_p, BtoR_REQ0_p, BtoR_REQ1_p);\n";
#AT# print DBW "\tinput  stateG7_1_p, stateG7_0_p, BtoR_REQ0_p, BtoR_REQ1_p;\n";
#AT# print DBW "\toutput stateG7_1_n, stateG7_0_n;\n";
#AT# print DBW "\twire    stateG7_1_p, stateG7_0_p, BtoR_REQ0_p, BtoR_REQ1_p;\n";
#AT# print DBW "\twire    stateG7_1_n, stateG7_0_n;\n\n";
#AT# 
#AT# print DBW "\tassign  stateG7_1_n = (!stateG7_1_p && !BtoR_REQ0_p &&  BtoR_REQ1_p)||\n";
#AT# print DBW "\t                      ( stateG7_1_p && !BtoR_REQ0_p && !BtoR_REQ1_p)||\n";
#AT# print DBW "\t                      ( stateG7_1_p && !stateG7_0_p && !BtoR_REQ0_p && BtoR_REQ1_p);\n";
#AT# 
#AT# print DBW "\tassign  stateG7_0_n = (!stateG7_1_p && !BtoR_REQ0_p && !BtoR_REQ1_p);\n";
#AT# 
#AT# print DBW "endmodule\n";
#AT# 
#AT# # DBW for guarantee 12
#AT# print DBW "module DBW12(stateG12_n, stateG12_p, EMPTY_p, DEQ_p);\n";
#AT# print DBW "\tinput  stateG12_p, EMPTY_p, DEQ_p;\n";
#AT# print DBW "\toutput stateG12_n;\n";
#AT# print DBW "\twire    stateG12_n, stateG12_p, EMPTY_p, DEQ_p;\n\n";
#AT# 
#AT# print DBW "\tassign  stateG12_n = (!stateG12_p && !DEQ_p && !EMPTY_p)||\n";
#AT# print DBW "\t                     ( stateG12_p && !DEQ_p);\n";
#AT# 
#AT# print DBW "endmodule\n";
#AT# 
#AT# close DBW;
