#!/usr/bin/perl -w

# takes a Verilog module file and generates a new wrapper file that allows for
# redefining the base module's parameters via `defines (used for testbenches)

use IO::File;
use Getopt::Long;
use Verilog::Netlist;
use Verilog::Getopt;

my $vopt = new Verilog::Getopt();
my $inputv;
my $outputv;
my $prefix = "PARAM_";
my $suffix = "_tbwrapper";

@ARGV = $vopt->parameter(@ARGV);

if (! GetOptions(
        "i=s" => \$inputv,
        "o=s" => \$outputv,
        "define-prefix=s" => \$prefix,
        "module-suffix=s" => \$suffix
    )) {
        die "bad usage";
}

my $nl = new Verilog::Netlist(options => $vopt);

$nl->read_file(filename=>$inputv);

my $fh = IO::File->new;
if ($outputv) {
    $fh->open(">$outputv") or die "failed to open output file";
} else {
    $fh->open(">-") or die "failed to open stdout";
}

my @mods = $nl->top_modules_sorted;

if(scalar(@mods) != 1) {
    die "verilog file must contain only 1 module declaration\n";
}

my $mod = $mods[0];

print $fh "module ",$mod->name,$suffix," (\n";

# ** top ports **

my @ports = $mod->ports_ordered;
$n = $#ports;
foreach my $port (@ports) {
    my $last = ",";
    if(!$n--) { $last = ""; }

    print $fh "    ",$port->name,$last,"\n";
}

print $fh ");\n\n";
print $fh "`include \"dlsc_clog2.vh\"\n";

# ** parameters **

print $fh "\n\n// ** parameters **\n\n";

my @nets = $mod->nets;
my @params_unsorted;

foreach my $net (@nets) {
    next if ($net->decl_type ne "parameter");
    push(@params_unsorted,$net);
}

my @params = sort {$a->lineno() <=> $b->lineno()} @params_unsorted;

foreach my $param (@params) {
    print $fh "`ifdef ",$prefix,$param->name,"\n";
    print $fh "    ",$param->decl_type," ",$param->data_type," ",$param->name," = `",$prefix,$param->name,";\n";
    print $fh "`else\n";
    print $fh "    ",$param->decl_type," ",$param->data_type," ",$param->name," = ",$param->value,";\n";
    print $fh "`endif\n";
}

# ** port directions **

print $fh "\n\n// ** ports **\n\n";

foreach my $port (@ports) {
    if($port->direction eq "in")    { print $fh "input  "; }
    if($port->direction eq "out")   { print $fh "output "; }
    if($port->direction eq "inout") { print $fh "inout  "; }
    
    my $datatype = $port->data_type;
    $datatype =~ s/^(reg|logic)\s*//;

    print $fh $datatype," ",$port->name,";\n";
}

# ** port wires **

print $fh "\n\n// ** wires **\n\n";

foreach my $port (@ports) {
    my $datatype = $port->data_type;
    $datatype =~ s/^(reg|logic)\s*//;

    print $fh "wire ",$datatype," ",$port->name,";\n";
}

# ** module instance **

print $fh "\n\n// ** module instance **\n\n";

print $fh $mod->name," #(\n";

$n = $#params;
foreach my $param (@params) {
    my $last = ",";
    if(!$n--) { $last = ""; }

    print $fh "    .",$param->name," ( ",$param->name," )",$last,"\n";
}

print $fh ") ",$mod->name,"_inst (\n";

$n = $#ports;
foreach my $port (@ports) {
    my $last = ",";
    if(!$n--) { $last = ""; }

    print $fh "    .",$port->name," ( ",$port->name," )",$last,"\n";
}

print $fh ");\n\n";


print $fh "`include \"dlsc_dpi.vh\"\n\n";

print $fh "endmodule\n\n";

exit(0);

