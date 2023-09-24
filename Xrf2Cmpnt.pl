#!/usr/bin/perl
# You should probably use the related bash script to call this script, but you can use: 
my $USAGE = "Usage: $0 [--configfile Xrf2Cmpnt.ini] [--section Xrf2Cmpnt] [--debug] [--checkini]";
# debug -- dump debugging information
# checkini -- quit after processing configfile

use 5.016;
use strict;
use warnings;
use English;
use Data::Dumper qw(Dumper);
use utf8;

use open qw/:std :utf8/;
use XML::LibXML;

use File::Basename;
my $scriptname = fileparse($0, qr/\.[^.]*/); # script name without the .pl

use Getopt::Long;
GetOptions (
	'configfile:s'   => \(my $configfile = "$scriptname.ini"), # ini filename
	'section:s'   => \(my $inisection = "Xrf2Cmpnt"), # section of ini file to use
	'debug'       => \(my $debug = 0),
	'checkini'       => \(my $checkini = 0),
	) or die $USAGE;

use Config::Tiny;
 # ; Xrf2Cmpnt.ini file looks like:
 # [Xrf2Cmpnt]
 # FwdataIn=FwProject-before.fwdata
 # FwdataOut=FwProject.fwdata
 # xrefAbbrev=EC-2,SC-1-2,SC-2-2,SC-3-2, SC-4-2,EC-3,SC-1-3,SC-2-3,EC-4
 # LogFile=Xrf2Cmpnt-log.txt

my $config = Config::Tiny->read($configfile, 'crlf');

die "Couldn't find the INI file:$configfile\nQuitting" if !$config;
my $infilename = $config->{$inisection}->{FwdataIn};
my $outfilename = $config->{$inisection}->{FwdataOut};
my $logfilename = $config->{$inisection}->{LogFile};
my @xrfabrv = split(/\ *,\ */, $config->{$inisection}->{xrefAbbrev});
my $lockfile = $infilename . '.lock' ;
die "A lockfile exists: $lockfile\
Don't run $0 when FW is running.\
Run it on a copy of the project, not the original!\
I'm quitting" if -f $lockfile ;


open(LOGFILE, '>:encoding(UTF-8)', "$logfilename");

=pod
# Log file looks like: ????
# <?xml version="1.0" encoding="UTF-8" ?>

=cut

say "config:". Dumper($config) if $checkini;

say STDERR "Loading fwdata file: $infilename";
my $fwdatatree = XML::LibXML->load_xml(location => $infilename);

my %rthash;
foreach my $rt ($fwdatatree->findnodes(q#//rt#)) {
	my $guid = $rt->getAttribute('guid');
	$rthash{$guid} = $rt;
	}
my @mbrs;
for my $xrefAbbrev (@xrfabrv) {
	say STDERR "Xref:$xrefAbbrev" if $debug;
	my ($cmpntxrfrt) = $fwdatatree->findnodes(q#//AUni[text()='# . $xrefAbbrev . q#']/ancestor::rt[@class='LexRefType']#);
	if (!$cmpntxrfrt) {
		say LOGFILE q#<!--  No Crossreferences found -->#, "\n\n" ;
		die qq#No Crossreference Type with the abbreviation $xrefAbbrev found in the FLEx database#, "\n\n" ;
		}
	foreach my $xrmbrrt ($cmpntxrfrt->findnodes('./Members/objsur')) {
		my $xrmbrguid = $xrmbrrt->getAttribute('guid');
		push (@mbrs, "$xrefAbbrev\t$xrmbrguid");
		}
	}
print Dumper @mbrs if $debug;

my $mbrcnt=0;
my $mbrtotal=0;
foreach my $mbr (@mbrs) {
	$mbrtotal++;
	my ($mbrabbrev, $mbrguid) = split("\t", $mbr);
	say STDERR "mbrabbrev:$mbrabbrev" if $debug;
	say STDERR "mbrguid:$mbrguid" if $debug;
	my $lxrefrt = $rthash{$mbrguid};
	my @targets = $lxrefrt->findnodes('./Targets/objsur');
	# $target[0] points to the complex form
	# $target[1] point to the component/main form
	my $cmplxguid = $targets[0]->getAttribute('guid');
	my $cmpntnode=$targets[1];
	my $cmpntguid = $cmpntnode->getAttribute('guid');
	if (scalar ( @targets ) != 2) { #only pairs not collections
		say LOGFILE "Error:Xref not a pair";		
		next;
		};
	my $MainLexrt = $rthash{$cmpntguid};
	if ($MainLexrt->getAttribute('class') ne 'LexEntry') {
		say LOGFILE "Error: Ignoring entry because component was not at the Entry level" ;
		say LOGFILE "Found ", $MainLexrt->getAttribute('class');
		next;
		}
	if ($mbrabbrev =~ m/.*\-([0-9]+)\-[0-9]/) {
	# abbreviation contains a sense number
	# use the sense node from the senses list from the component
	# rather than the entry node from the targets list
		my $senseno = $1;
		my @senses = $MainLexrt->findnodes('./Senses/objsur');
		my $sensecount = scalar @senses;
		if ($sensecount < $senseno) {
			say LOGFILE "Error: Ignoring Subentry because main entry has only $sensecount senses" ;
			next;
			}
		$cmpntnode=$senses[$senseno-1];
		}
#	say STDERR "	Target[1] Component class guid:", $rthash{$cmpntguid}->getAttribute('class')," ", $cmpntguid if $debug;
#	say STDERR "	Target[1] Component head:", displaylexentstring(traverseuptoclass($rthash{$cmpntguid}, "LexEntry")) if $debug;
#	say STDERR "" if $debug;

	say STDERR  "	Target[0] Complex class guid: ", $rthash{$cmplxguid}->getAttribute('class')," ", $cmplxguid if $debug;
	my $headrt = traverseuptoclass($rthash{$cmplxguid}, "LexEntry");
	say STDERR  "	Target[0] Complex head:", displaylexentstring($headrt) if $debug;
	my ($entryref) = $headrt->findnodes('./EntryRefs/objsur');
	if (! $entryref ) {
		say LOGFILE "Complex entry has no pre-existing Components:", displaylexentstring($headrt);
		next;
		}
	my $entryrefrt=$rthash{$entryref->getAttribute('guid')};
	say STDERR "Before:" if $debug;
	say STDERR $entryrefrt if $debug;
	my ($cmpntlexemesnode) = $entryrefrt->findnodes('./ComponentLexemes');
	if ($cmpntlexemesnode->findnodes(q#'./objsur[@guid="# . $cmpntguid . q#]'#) ) {
		say LOGFILE "<!--  Component guid $cmpntguid  already in Components list under" .
			displaylexentstring($headrt) . " -->";
		next;
		}
	my $newnode = $cmpntnode->cloneNode(1);
	$cmpntlexemesnode->addChild($newnode);
	say STDERR  "ComponentLexemes:", $cmpntlexemesnode if $debug; # add the component lexeme as a child node to this one.
	my ($formsinnode) = $entryrefrt->findnodes('./ShowComplexFormsIn');
	say STDERR "ShowComplexFormsIn", $formsinnode if $debug; # add the component lexeme as a child node to this one.
	$newnode = $cmpntnode->cloneNode(1);
	$formsinnode->addChild($newnode);
	say STDERR "After:" if $debug;
	say STDERR $entryrefrt if $debug;
	say STDERR "" if $debug;

	say LOGFILE q#<pair guid="#, $mbr->getAttribute('guid'), q#" entry1id=#;

	$mbrcnt++;
	last if ($mbrcnt > 30) && $debug;
	}

# footer of log
say LOGFILE q#<!--  DON'T EDIT ANYTHING BELOW THIS LINE -->#;
say LOGFILE '</pairs>';

say STDERR "Found $mbrcnt of $mbrtotal";
my $xmlstring = $fwdatatree->toString;
# Some miscellaneous Tidying differences
$xmlstring =~ s#><#>\n<#g;
$xmlstring =~ s#(<Run.*?)/\>#$1\>\</Run\>#g;
$xmlstring =~ s#/># />#g;
say "";
say "Finished processing, writing modified  $outfilename" ;
open my $out_fh, '>:raw', $outfilename;
print {$out_fh} $xmlstring;


# Subroutines
sub rtheader { # dump the <rt> part of the record
my ($node) = @_;
return  ( split /\n/, $node )[0];
}

sub traverseuptoclass { 
	# starting at $rt
	#    go up the ownerguid links until you reach an
	#         rt @class == $rtclass
	#    or 
	#         no more ownerguid links
	# return the rt you found.
my ($rt, $rtclass) = @_;
	while ($rt->getAttribute('class') ne $rtclass) {
#		say ' At ', rtheader($rt);
		if ( !$rt->hasAttribute('ownerguid') ) {last} ;
		# find node whose @guid = $rt's @ownerguid
		$rt = $rthash{$rt->getAttribute('ownerguid')};
	}
#	say 'Found ', rtheader($rt);
	return $rt;
}

sub displaylexentstring {
my ($lexentrt) = @_;

my ($formguid) = $lexentrt->findvalue('./LexemeForm/objsur/@guid');
my $formrt =  $rthash{$formguid};
my ($formstring) =($rthash{$formguid}->findnodes('./Form/AUni/text()'))[0]->toString;
# If there's more than one encoding, you only get the first

my ($homographno) = $lexentrt->findvalue('./HomographNumber/@val');

my $guid = $lexentrt->getAttribute('guid');
return qq#$formstring # . ($homographno ? qq#hm:$homographno #  : "") . qq#(guid="$guid")#;
}
