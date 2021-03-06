#!/usr/bin/env perl
# positions2pseudoalignment
# Purpose:  Given a pseudoalign-positions.tsv, converts to various alignment formats

use warnings;
use strict;

use Getopt::Long;
use Bio::AlignIO;
use Bio::SimpleAlign;
use Bio::LocatableSeq;

my ($input,$output,$format,$keep,$reference_name,$verbose);
$verbose = 0;
$keep = 0;
my %valid_formats = ('phylip' => 1,'fasta' => 1);

sub usage
{
	"Usage: $0 -i [pseudoalign-positions.tsv] -o [pseudoalign out] -f [alignment format] [-v]\n".
	"Parameters:\n".
	"\t-i|--input:  Input file (pseudoalign-positions.tsv generated by snp pipeline)\n".
	"\t-o|--output:  Output file name\n".
	"\t-f|--format:  Alignment format (default phylip)\n".
	"\t--keep-all: Keep all positions in alignment\n".
	"\t--reference-name: Use passed name instead of default for reference\n".
	"\t--verbose: Print more information\n";

}

if (!GetOptions('i|input=s' => \$input,
		'o|output=s' => \$output,
		'f|format=s' => \$format,
		'keep-all' => \$keep,
		'reference-name=s' => \$reference_name,
		'v|verbose=s' => \$verbose))
{
	die "Invalid option\n".usage;
}

die "Error: no input file defined\n".usage if (not defined $input);
die "Error: file $input does not exist" if (not -e $input);
die "Error: no output file defined\n".usage if (not defined $output);

$format = 'phylip' if (not defined $format);
die "Error: format $format is not valid".usage if (not defined $valid_formats{$format});

print "Date: ".`date`;
print "Working on $input\n";

open(my $fh, "<$input") or die "Could not open $input: $!";

my $line = readline($fh);
chomp($line);

die "Error: no header line defined in $input" if ($line !~ /^#Chromosome\tPosition\tStatus\tReference/);
my @values = split(/\t/,$line);
my (undef,undef,undef,@strains) = @values;
die "Error: no strains defined in $input" if (@strains <= 0);

# replace reference name
if ($strains[0] eq 'Reference' and defined $reference_name)
{
	$strains[0] = $reference_name;
}

my @data;
my $valid_count=0;
my $invalid_count=0;
while($line = readline($fh))
{
	chomp $line;
	@values = split(/\t/,$line);

	my ($chrom,$pos,$status,@dna) = @values;

	if (scalar(@dna) != scalar(@strains))
	{
		die "Error: line $line does not have same number of entries as header for $input";
	}
	elsif ($status ne 'valid')
	{
		if (not $keep)
		{
			print STDERR "Skipping invalid line: $line\n" if ($verbose);
			$invalid_count++;
		}
		else
		{		
			$valid_count++;
			for (my $i = 0; $i < @dna; $i++)
			{
				$data[$i] = '' if (not defined $data[$i]);
				$dna[$i] = 'N' if ($dna[$i] eq '-'); # replace those positions filtered by coverage with N
				$data[$i] .= $dna[$i];
			}
		}
	}
	else
	{
		$valid_count++;
		for (my $i = 0; $i < @dna; $i++)
		{
			$data[$i] = '' if (not defined $data[$i]);
			$data[$i] .= $dna[$i];
		}
	}
}
close($fh);

# generate seq objects
my $align = Bio::SimpleAlign->new(-source=>"NML Bioinformatics Core SNP Pipeline",-idlength=>30);
for (my $i = 0; $i < @strains; $i++)
{
	my $seq = Bio::LocatableSeq->new(-seq => $data[$i], -id => $strains[$i], -start => 1, -end => length($data[$i]));
	$align->add_seq($seq);
}
$align->sort_alphabetically;

# build alignment
my $io = Bio::AlignIO->new(-file => ">$output", -format => $format);
die "Error: could not create Align::IO object" if (not defined $io);

die "Error: alignment not flush" if (not $align->is_flush);
$io->write_aln($align);
print "Kept $valid_count valid positions\n";
print "Skipped $invalid_count positions\n";
print "Alignment written to $output\n";
