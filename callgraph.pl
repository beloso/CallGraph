#! /usr/bin/perl

use strict;
use warnings;
use File::Find;
use Getopt::Long;

my ($roll,$dot,$csv,$project_prefix,$output_file);
GetOptions ('roll' => \$roll, 'prefix=s' => \$project_prefix, 'o=s' => \$output_file, 'dot' => \$dot, 'csv' => \$csv);

my $command     = "javap -v";
my $extension   = "class";
my $temp_dir    = "/tmp";
my $temp_file   = "temp.tmp";

unless ($csv xor $dot){
	die "Please specify dot or csv format.\n";
}

my $input_dir = shift or die "Input folder missing.\n";

&load_files;

if ($dot){
	&dot;
}

if ($csv){
	&csv;
}

my @lines;
my @class_files;
sub load_files{
	my ($result, $class, @aux);
	
	find(\&wanted, $input_dir);

	foreach $class (@class_files) {
		$class=~ s/(.*)\..*/$1/;
		$result= `$command $class 2> /dev/null | grep " = class" 2> /dev/null`;
		$result=~ s/.*\/\/ */\"$class\" -> /g;

		@aux = split /\n/, $result;

		push (@lines,@aux);
	}
}

sub wanted {
	if ($_ = /\.$extension$/)
	{
		push (@class_files, $File::Find::name);
	}
}

sub csv {
	my $_line;
	my $_body;
	
	if ($output_file){
		open(F,">$output_file");
		print F "\"From\" , \"To\" , \"Calls\" \n";
	} else {
		print "\"From\" , \"To\" , \"Calls\" \n";
	}
	
	foreach $_line (@lines){
		$_line=~ s/"$input_dir\//"/g;
		$_line=~ s/\[[A-Z]?//g;
		$_line=~ s/\;//g;
		$_line=~ s/->\s*(.*)/, \"$1\"/g;
		$_line=~ s/\"\"/\"/g;
		$_line=~ s/\$[^\"]*//g;
		$_line=~ s/\"[^\"]*\"\s*,\s*\"\s*\"\s*//g;
	
		if ($roll){
			$_line=~ s/\/[^\"\/]*\"/\"/g;
		}
		
		if (defined $project_prefix){
			if ($_line=~ m{,\s+"$project_prefix}){
				$_body.=$_line."\n";
			}
		} else {
			$_body.=$_line."\n";
		}
	}
	
	open(T,">$temp_dir/$temp_file");
	print T "$_body";
	close T;
	
	$_body= `sort $temp_dir/$temp_file | uniq -c | sort -n`;
	$_body=~ s/\s*(\d+)\s*(.*)/$2 , $1\n/g;
	
	if ($output_file){
		print F "$_body";
		close F;
	} else {
		print "$_body";
	}	
}

sub dot {
	my $_line;
	my $_body;
	
	if ($output_file){
		open(F,">$output_file");
		print F "digraph G\n{\n";
		print F "node [shape=box]\n";
	} else {
		print "digraph G\n{\n";
		print "node [shape=box]\n";
	}
	
	foreach $_line (@lines){
		$_line=~ s/"$input_dir\//"/g;
		$_line=~ s/\[[A-Z]?//g;
		$_line=~ s/\;//g;
		$_line=~ s/->\s*(.*)/-> \"$1\"/g;
		$_line=~ s/\"\"/\"/g;
		$_line=~ s/\$[^\"]*//g;
		$_line=~ s/\"[^\"]*\"\s*->\s*\"\s*\"\s*//g;
	
		if ($roll){
			$_line=~ s/\/[^\"\/]*\"/\"/g;
		}
		
		if (defined $project_prefix){
			if($_line=~ m{->\s+"$project_prefix}){
				$_body.=$_line."\n";
			}
		} else {
			$_body.=$_line."\n";
		}
	}
	
	open(T,">/tmp/$temp_file");
	print T "$_body";
	close T;
	
	$_body= `sort /tmp/$temp_file | uniq -c | sort -n`;
	$_body=~ s/\s*(\d+)\s*(.*)/$2 [label=$1]\n/g;
	
	if ($output_file){
		print F "$_body";
		print F "}\n";
		close F;
	} else {
		print "$_body";
		print "}\n";
	}	
}