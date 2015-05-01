#!/usr/bin/env perl
# filter-positions.pl
# Purpose:  Given a pseudoalign-positions.tsv and a file defining ranges to filter,
# filter out snps lying in these ranges.

use warnings;
use strict;

use Getopt::Long;

my ($input,$output,$bad_positions,$verbose);
my %banned;
$verbose = 0;

sub usage
{
	"Usage: $0 -i [pseudoalign-positions.tsv] -p [bad positions] -o [valid-positions.tsv] [-v]\n".
	"Parameters:\n".
	"\t-i|--input:  Input file (pseudoalign-positions.tsv generated by snp pipeline)\n".
	"\t-p|--bad-positions: Positions file to filter, in BED or GFF format\n".
	"\t-o|--output:  Output base file name\n";
}

sub is_banned
{
	my ($chrom,$pos) = @_;

	return (exists $banned{"${chrom}_$pos"});
}

sub build_banned_snps
{
	my ($banned_file) = @_;

	open(my $fh, "<$banned_file") or die "Could not open $banned_file: $!";

	while(my $line = readline($fh))
	{
		chomp $line;
		my ($sub_line) = ($line =~ /^([^#]*)/);
		#determine if the line is formatted as GFF or BED, 
		#and parse as appropriate
		my @checkFormat = split(/\t/, $sub_line);
		my ($chrom, $source, $feature, $start, $end, $score, 
		   $strand, $frame, $group);
		if($checkFormat[1] =~ /^\d+$/){
			($chrom,$start,$end) = split(/\t/,$sub_line);
		}
		elsif($checkFormat[3] =~ /^\d+$/){
			($chrom, $source, $feature, $start, $end, $score, 
		   $strand, $frame, $group) = split(/\t/,$sub_line);
		}
		next if (not defined $chrom or $chrom eq '');
		next if ($start !~ /^\d+$/);
		next if ($end !~ /^\d+$/);
	
		# swap in case start/end are reversed
		my $real_start = ($start < $end) ? $start : $end;
		my $real_end = ($start < $end) ? $end : $start;

		for (my $i = $real_start; $i < $real_end; $i++)
		{
			$banned{"${chrom}_${i}"} = 1;
		}
	}

	close($fh);
}

# MAIN
if (!GetOptions('i|input=s' => \$input,
		'p|bad-positions=s' => \$bad_positions,
		'o|output=s' => \$output))
{
	die "Invalid option\n".usage;
}

die "Error: no input file defined\n".usage if (not defined $input);
die "Error: file $input does not exist" if (not -e $input);
die "Error: no bad positions file defined\n".usage if (not defined $bad_positions);
die "Error: bad positions file $bad_positions does not exist\n".usage if (not -e $bad_positions);
die "Error: no output base defined\n".usage if (not defined $output);
my $valid_output = "$output-valid.tsv";
my $invalid_output = "$output-invalid.tsv";

print "Date: ".`date`;
print "Working on $input\n";
print "Using bad positions from $bad_positions\n";

build_banned_snps($bad_positions);

open(my $fh, "<$input") or die "Could not open $input: $!";
open(my $ofh, ">$valid_output") or die "Could not open $valid_output: $!";
open (my $fil_h, ">$invalid_output") or die "Could not open file $invalid_output: $!";

my $line = readline($fh);
chomp($line);

die "Error: no header line defined in $input" if ($line !~ /^#Chromosome\tPosition\tStatus\tReference/);
my (undef,undef,undef,@strains) = split(/\t/,$line);
die "Error: no strains defined in $input" if (@strains <= 0);

# print header
print $ofh "$line\n";
print $fil_h "$line\n";

my $valid_count=0;
my $filtered_count=0;
while(my $line = readline($fh))
{
	chomp $line;
	my @values = split(/\t/,$line);

	my ($chrom,$pos,$status,@dna) = @values;

	if (scalar(@dna) != scalar(@strains))
	{
		die "Error: line $line does not have same number of entries as header for $input";
	}
	elsif (is_banned($chrom,$pos))
	{
		$filtered_count++;
		print $fil_h "$line\n";
	}
	else
	{
		$valid_count++;
		print $ofh "$line\n";
	}
}
close($fh);
close($ofh);

print "Removed $filtered_count sites\n";
print "Kept $valid_count sites\n";
print "Removed SNPs from ".scalar(keys %banned)." bp of the genome.\n";
print "Valid file in $valid_output\n";
print "Invalid file in $invalid_output\n";
