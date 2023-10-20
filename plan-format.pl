#!/usr/bin/env perl
#
# copy plan-format.pl and modify to deal with cursor ID reuse
# Cursor parsed, executed and closed
# The next cursor opened may use the same cursor ID
# 2019-09-30 Jared Still jkstill@gmail.com still@pythian.com
#            now correctly handles trace files with cursor handle (ID) reuse
# 2019-10-07 Jared Still jkstill@gmail.com still@pythian.com
#            print IO stats only on lines with an object ID

use strict;
use warnings;

use Data::Dumper;
use Getopt::Long;

sub getLvl($$$$);

my $traceFile='- no file specified';
my $opLineLen=80;
my $help=0;
my $commify=0;

GetOptions (
		"file=s" => \$traceFile,
		"op-line-len=i" => \$opLineLen,
		"commify!" => \$commify,
		"h|help!" => \$help
) or die usage(1);

usage(0) if $help;

unless ( -r $traceFile ) {
	die "cannot find file $traceFile\n";
}

open F,'<',$traceFile || die "cannot open trace file $traceFile - $! \n";

my %sql=();
my %cursorTracking=(); # keep track of cursor reuse
my %cursorUsed=();

# first pass to get the SQL 
# after cursor ID issue fixed, change to read trace file only once
# it will make a difference on really large files
while(<F>) {

	my $line=$_;
	chomp $line;

	next unless $line =~ /^PARSING IN/;

	my @tokens=split(/\s+/,$line);
	my $cursorID = $tokens[3];
	$cursorTracking{$cursorID}++;

	while(<F>) {
		$line = $_;
		chomp $line;
		last if $line =~ /^END OF STMT/;
		push @{$sql{$cursorID}->{$cursorTracking{$cursorID}}}, $line;
	}

	#$q1 =~ /(PARSING IN.*?)END OF STMT/s;
	#print "$1\n";

}

#print Dumper(\%cursorTracking);
#exit;

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

=head2 identify cursors

 We have to deal with possible cursor reuse.
 eg.  STAT line like this
 STAT #1 id=1
 STAT #1 id=2
 STAT #1 id=3
 STAT #1 id=4
 STAT #1 id=1

 Notice that ID started over with id=1 - previous cursor closed and the ID was reused

=cut 

my %tree=();

my $formatSub;
if ($commify) { 
	$formatSub = \&commify;
} else { 
	$formatSub = sub{my ($n) = shift;return $n;};
}

my ($rowsLen, $lioLen, $blocksLen, $secondsLen) = (12,12,12,10);
if ($commify){  ($rowsLen, $lioLen, $blocksLen, $secondsLen) = (15,15,15,13,13); }

foreach my $cursorID ( sort keys %sql ) {

	$cursorUsed{$cursorID}++;

	my @statData = grep(/^STAT $cursorID/,@data);

	my $prevLineID=0;

	#print "Cursor: $cursorID  $cursorUsed{$cursorID}\n";
	my ($dummy,$lineID)=(0,0);

	foreach my $statLine ( @statData ) {
		($dummy,$lineID)=split(/\=/, (split(/\s+/,$statLine))[2]);	

		if ($lineID < $prevLineID ) {
			$cursorUsed{$cursorID}++;
			$prevLineID=0;	
			#print "Cursor: $cursorID  $cursorUsed{$cursorID}\n";
		} else {
			$prevLineID = $lineID;
		}

		#print "   lineID: $lineID\n";

		#
		#push @{$plans{$cursorID}->{i}}, grep(/^STAT $cursorID/,@data);
		push @{$plans{$cursorID}->{$cursorUsed{$cursorID}}}, $statLine;

		# create tree for indentation levels
		my @a = split(/\s+/, $statLine);
		my ($idData, $pidData) = @a[2,4];
		my ($id, $pid);	
		($dummy,$id) = split(/\=/,$idData);
		($dummy,$pid) = split(/\=/,$pidData);
		#print "$cursorID: $id  $pid\n";
		$tree{$cursorID}->{$cursorUsed{$cursorID}}{$id} = $pid;


	}

}

%cursorUsed=();

#print Dumper(\%plans);
#print Dumper(\%tree);
#print Dumper(\%sql);

#print join("\n",sort keys %sql),"\n";
#print Dumper(\%cursorTracking);
#exit;


foreach my $cursorID ( sort keys %sql ) {


	foreach my $cursorChild ( 1 .. $cursorTracking{$cursorID} ) {

		#print "   CursorChild: $cursorChild\n";
		
		if ( not exists $plans{$cursorID}->{$cursorChild} ) {
			warn "\nPlan not found for cursor $cursorID - $cursorChild\n\n";
			next;
		}

		print '#' x 120, "\n";
		print "\nCursor: ${cursorID}-${cursorChild}:\n\n";
		print "SQL:", join("\n", @{$sql{$cursorID}->{$cursorChild}}), "\n\n";

		printf( "%-6s " ,'Line#' );
		printf( "%-${opLineLen}s", substr('Operation' . ' ' x $opLineLen,0,$opLineLen));
		printf( " %${rowsLen}s %${lioLen}s %${blocksLen}s %${blocksLen}s %${secondsLen}s\n", 'Rows', 'LIO', 'Read', 'Written', 'Seconds');
		printf( "%6s %${opLineLen}s %${rowsLen}s %${lioLen}s %${blocksLen}s %${blocksLen}s %${secondsLen}s\n", '=' x 6, '=' x $opLineLen, '=' x $rowsLen, '=' x $lioLen , '=' x  $blocksLen , '=' x $blocksLen , '=' x $secondsLen );

		foreach my $statLine ( @{$plans{$cursorID}->{$cursorChild}} ) {
			my @lineElements = split(/\s+/, $statLine);
	
			my ($d,$lineNumber,$rows,$pid,$objectID);
			($d,$lineNumber) = split(/\=/,$lineElements[2]);
			($d,$rows) = split(/\=/,$lineElements[3]);
			($d,$pid) = split(/\=/,$lineElements[4]);
			($d,$objectID) = split(/\=/,$lineElements[6]);

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
			($d,$microseconds) = split(/\=/,$opStats[4]);

			my $level = getLvl(\%tree,$cursorID,$cursorChild,$lineNumber);

			printf( "%06d " ,$lineNumber );
			printf( "%-${opLineLen}s", (' ' x ($level * 2 )) . $planOp);
			# print IO stats only for line that have an object id


			if ($objectID > 0 ) {
				printf( " %${rowsLen}s %${lioLen}s %${blocksLen}s %${blocksLen}s %${secondsLen}s", $formatSub->($rows), $formatSub->($lio), $formatSub->($blocksRead), $formatSub->($blocksWritten), $formatSub->(sprintf('%10.2f', $microseconds / 1000000)+0));
			} else {
				printf( " %${rowsLen}s %${lioLen}s %${blocksLen}s %${blocksLen}s %${secondsLen}s", $formatSub->($rows), '.', '.', '.', $formatSub->(sprintf('%10.2f', $microseconds / 1000000)+0));
			};

			print "\n";

			#print "stats: $planStats\n";
		}
	}
}


sub getLvl ($$$$){

	my ($treeRef, $cursorID, $cursorChild, $id) = @_;
	my $level=0;
	my $currID = $id;

	#print "getLvl: $id\n";

	while ($treeRef->{$cursorID}{$cursorChild}{$currID} > 0) {
		$currID = $treeRef->{$cursorID}{$cursorChild}{$currID};
		$level++;
	}

	$level;
}

sub usage {

	my $exitVal = shift;
	use File::Basename;
	my $basename = basename($0);
	print qq{
$basename

usage: $basename - format readable execution plans found in Oracle 10046 trace files

   $basename --file <filename> --op-line-len N

--file         10046 tracefile name
--op-line-len  Formatted length of operation lines - defaults to 80
--commify      Add commas to numeric values

examples here:

   $basename --file DWDB_ora_63389.trc --op-line-len 120
};

	exit eval { defined($exitVal) ? $exitVal : 0 };
}


sub commify {
	# wn - working number
	my $wn = shift;
	unless ( $wn =~ /^\-{0,1}[0-9]+\.{0,1}[0-9]*$/ ) { return $wn; }
	1 while $wn =~ s/^(-?\d+)(\d{3})/$1,$2/;
	return $wn;
}

