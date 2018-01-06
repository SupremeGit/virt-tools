#!/usr/bin/perl
#virt-move.pl
#Copyright John Sincock, 2017
#
#Update paths in VM xml configs,
#
#Could currently be replaced with a single line perl regex, but may add more features later.
#
#Usage:
#cat /etc/libvirt/qemu/vm.xml | virt-move.pl "/oldpath/" "/newpath/" > vm_fixed.xml

use strict;
use warnings;

my $num_of_params = @ARGV;
my @lines;                    #holds all lines of file
my $path_to_file;             #path to input file, if we're not using stdin
my $use_stdin=1;              #are we reading input from file (false) or stdin (true).
my $old_path="/data-ssd/";
my $new_path="/mnt/6Tb-linux/";

sub usage {
    warn "\n";
    warn "usage> ./virt-move.pl \n";
    exit 1;
}

$use_stdin = 1;
#if ( $num_of_params == 0 ) { usage; exit 1; }
if ( $num_of_params == 1 ) {
    $new_path ="$ARGV[0]";
}
if ( $num_of_params == 2 ) {
    $old_path="$ARGV[0]";
    $new_path="$ARGV[1]";
}
if ( $num_of_params == 3 ) {
    $use_stdin = 0;
    $path_to_file="$ARGV[0]";
    $old_path="$ARGV[1]";
    $new_path="$ARGV[2]";
}
if ( $use_stdin == 1 ) { 
    warn "Reading from stdin:\n";
} else {
    warn "Reading from file:<$path_to_file>\n";
}
warn "Old storage path:<$old_path> \n";
warn "New storage path:<$new_path> \n";

sub read_file {
    my $handle;
    if ( $use_stdin == 0 ) {
	warn "Reading $path_to_file:\n";
	open $handle, '<', $path_to_file;
    }
    else {
	warn "Reading STDIN:\n";
	$handle="STDIN";
    }
    chomp(@lines = <$handle>);
    close $handle;
    #warn "Reading input done.\n";
}

sub dump_to_file {
    foreach my $line (@lines) {
	print "$line\n";
    }
}

sub filter {
    warn "Replacing old path <$old_path> with new path:<$new_path> \n";
    foreach my $line (@lines) {
	$line =~ s/$old_path/$new_path/ig;
	print "$line\n";
    }
}

read_file;
filter
#dump_to_file;
warn "Done.\n";




    


