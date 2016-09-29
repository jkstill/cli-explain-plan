#!/usr/bin/env perl
#

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;

sub getLvl($$$);

my $traceFile='- no file specified';

GetOptions ("file=s" => \$traceFile) or die "usage: $0 --file <filename>\n";

unless ( -r $traceFile ) {
	die "cannot find file $traceFile\n";
}

open F,'<',$traceFile || die "cannot open trace file $traceFile - $! \n";

my %sql=();

# first pass to get the SQL 
while(<F>) {

	my $line=$_;
	chomp $line;

	next unless $line =~ /^PARSING IN/;

	my @tokens=split(/\s+/,$line);
	my $cursorID = $tokens[3];

	while(<F>) {
		$line = $_;
		chomp $line;
		last if $line =~ /^END OF STMT/;
		push @{$sql{$cursorID}}, $line;
	}

	#$q1 =~ /(PARSING IN.*?)END OF STMT/s;
	#print "$1\n";

}

#foreach my $cursorID ( keys %sql ) {
#	print "\n\nCursor: $cursorID\n";
#	foreach my $el ( @{$sql{$cursorID}} ) {
#		print "$el\n";
#	}
#}


# now get the STAT lines

open F,'<',$traceFile || die "cannot open trace file $traceFile - $! \n";

# this method takes too much memory for large files
# easier and faster to just scan the file again
# on a 3.6 million line file this method took minutes before the OS killed it
# the loop takes a second or so
#my @data=grep(!/(?:WAIT #|FETCH #|\*\*\*|^$)/,<F>);
# further test with file slurp
# using a direct grep without the 'not' is much faster, 
# but still not as fast as the loop
# @data=grep(/^STAT #/,<F>);
#

my @data=();

while(<F>) {
	next unless /^STAT #/;
	chomp $_;
	push @data, $_;
}

#print Dumper(\@data);
#exit;

my %plans=();

foreach my $cursorID ( keys %sql ) {
	push @{$plans{$cursorID}}, grep(/^STAT $cursorID/,@data);
}

# create tree for indentation levels
my @stat=grep(/^STAT #/,@data);
my %tree=();

foreach my $line (@stat) {

	my @a = split(/\s+/, $line);
	my ($cursorID,$idData, $pidData) = @a[1,2,4];
	my ($id, $pid, $dummy);	
	($dummy,$id) = split(/\=/,$idData);
	($dummy,$pid) = split(/\=/,$pidData);

	#print "$cursorID: $id  $pid\n";

	$tree{$cursorID}->{$id} = $pid;

}

#print Dumper(\%plans);
#print Dumper(\%sql);
#exit;

foreach my $cursorID ( sort keys %sql ) {
	if ( not exists $plans{$cursorID} ) {
		warn "\nPlan not found for cursor $cursorID\n\n";
		next;
	}

	print '#' x 120, "\n";
	print "\nCursor: $cursorID:\n\n";
	print "SQL:", join("\n", @{$sql{$cursorID}}), "\n\n";

	printf( "%-6s "  ,'Line#' );
	printf( "%-80s", substr('Operation' . ' ' x 80,0,80));
	printf( " %12s  %9s %9s %9s %-9s\n", 'Rows', 'LIO', 'Read', 'Written', 'Seconds');
	printf( "%6s %80s %12s  %9s %9s %9s %-9s\n", '=' x 6, '=' x 80, '=' x 12, '=' x 9 , '=' x 9 , '=' x 9 , '=' x 9 );

	foreach my $statLine ( @{$plans{$cursorID}} ) {
		my @lineElements = split(/\s+/, $statLine);

		my ($d,$lineNumber) = split(/\=/,$lineElements[2]);
		my ($c,$rows) = split(/\=/,$lineElements[3]);
		my ($e,$pid) = split(/\=/,$lineElements[4]);

		for (0 .. 6) { shift @lineElements }

		my $planLine = join(' ', @lineElements);
		$planLine =~ s/^op='(.*)'$/$1/;
		my $planOp = $planLine;
		$planOp =~ s/(.*)\s+\(.*\)/$1/;
		my $planStats = $planLine;
		$planStats =~ s/(.*)\s+(\(.*\))/$2/;
		# remove parens
		$planStats =~ s/[\(\)]//go;

		my ($lio, $blocksRead, $blocksWritten, $microseconds);
		my @opStats=split(/\s+/,$planStats);

		($d,$lio) = split(/\=/,$opStats[0]);
		($d,$blocksRead) = split(/\=/,$opStats[1]);
		($d,$blocksWritten) = split(/\=/,$opStats[2]);
		($d,$microseconds) = split(/\=/,$opStats[3]);

		my $level = getLvl(\%tree,$cursorID,$lineNumber);

		printf( "%06d "  ,$lineNumber );
		printf( "%-80s", (' ' x ($level * 2 )) . $planOp);
		printf( " %12d  %9d %9d %9d %6.2f", $rows, $lio, $blocksRead, $blocksWritten, $microseconds / 1000000);

		print "\n";

		#print "stats: $planStats\n";

	}
}


sub getLvl ($$$){

	my ($treeRef, $cursorID, $id) = @_;
	my $level=0;
	my $currID = $id;

	#print "getLvl: $id\n";

	while ($treeRef->{$cursorID}{$currID} > 0) {
		$currID = $treeRef->{$cursorID}{$currID};
		$level++;
	}

	$level;
}

