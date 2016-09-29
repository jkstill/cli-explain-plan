#!/usr/bin/env perl
#

use strict;
use warnings;

use Data::Dumper;

sub getLvl($$$);

my $traceFile='DWDB_ora_63389.trc';

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

my @data=<F>;
chomp @data;

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

	print "$cursorID: $id  $pid\n";

	$tree{$cursorID}->{$id} = $pid;

}

#print Dumper(\%plans);

foreach my $cursorID ( keys %sql ) {
	if ( not exists $plans{$cursorID} ) {
		warn "\nPlan not found for cursor $cursorID\n\n";
		next;
	}

	print '#' x 120, "\n";
	print "\nCursor: $cursorID:\n\n";
	print "SQL:", join("\n", @{$sql{$cursorID}}), "\n\n";

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

		#print "indent: $indent\n";
		#printf( "%04d %s %s \n", $lineNumber, ' ' x ($indent * 2 ), $planOp);
		
		my $level = getLvl(\%tree,$cursorID,$lineNumber);

		printf( "%04d "  ,$lineNumber );
		print ' ' x ($level * 2 ), "$planOp\n";
		#print $lineNumber, ' ' x ($indent * 2 ), $planLine, "\n";

	}
}


sub getLvl {

	my ($treeRef, $cursorID, $id) = @_;
	my $level=1;
	my $currID = $id;

	#print "getLvl: $id\n";

	while ($treeRef->{$cursorID}{$currID} > 0) {
		$currID = $treeRef->{$cursorID}{$currID};
		$level++;
	}

	$level;
}

