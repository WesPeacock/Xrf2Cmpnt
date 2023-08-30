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
 # xrefAbbrev=Cmpnt
 # LogFile=Xrf2Cmpnt.log

my $config = Config::Tiny->read($configfile, 'crlf');

die "Couldn't find the INI file:$configfile\nQuitting" if !$config;
my $infilename = $config->{$inisection}->{FwdataIn};
my $outfilename = $config->{$inisection}->{FwdataOut};
my $logfilename = $config->{$inisection}->{LogFile};
my @xrfabrv = reverse sort split(/\ *,\ */, $config->{$inisection}->{xrefAbbrevs});
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
	say STDERR $xrefAbbrev if $debug;
	my ($cmpntxrfrt) = $fwdatatree->findnodes(q#//AUni[text()='# . $xrefAbbrev . q#']/ancestor::rt[@class='LexRefType']#);
	if (!$cmpntxrfrt) {
		say LOGFILE q#<!--  No Crossreferences found -->#, "\n\n" ;
		die qq#No Crossreference Type with the abbreviation $xrefAbbrev found in the FLEx database#, "\n\n" ;
		}
	my $scmpxr = $cmpntxrfrt->serialize();
	say STDERR $scmpxr  if $debug;
	push (@mbrs, $cmpntxrfrt->findnodes('./Members/objsur'));
	}
if ($debug) {
	for my $mbr (@mbrs) {
		say STDERR "scmpxr:";
		my $scmpxr = $mbr->serialize();
		say STDERR $scmpxr;
		}
	}

my $mbrcnt=0;
my $mbrtotal=0;
foreach my $mbr (@mbrs) {
	$mbrtotal++;
	my $mbrguid = $mbr->getAttribute('guid');
	say STDERR "mbrguid:$mbrguid" if $debug;
	my $lxrefrt = $rthash{$mbrguid};
	# say $lxrefrt;
	my @targets = $lxrefrt->findnodes('./Targets/objsur');
	next if (scalar ( @targets ) != 2); #only pairs not collections

	my $cmpntnode=$targets[1]; # clone this node into the LexentryRef structure
	my $cmpntguid = $cmpntnode->getAttribute('guid');
#	say STDERR "	Target[1] Component class guid:", $rthash{$cmpntguid}->getAttribute('class')," ", $cmpntguid if $debug;
#	say STDERR "	Target[1] Component head:", displaylexentstring(traverseuptoclass($rthash{$cmpntguid}, "LexEntry")) if $debug;
#	say STDERR "" if $debug;

	my $cmplxguid = $targets[0]->getAttribute('guid');
	say STDERR  "	Target[0] Complex class guid: ", $rthash{$cmplxguid}->getAttribute('class')," ", $cmplxguid if $debug;
	my $headrt = traverseuptoclass($rthash{$cmplxguid}, "LexEntry");
	say STDERR  "	Target[0] Complex head:", displaylexentstring($headrt) if $debug;
	my ($entryref) = $headrt->findnodes('./EntryRefs/objsur');
	if (! $entryref ) {
		say LOGFILE "Complex entry has no pre-existing Components:", displaylexentstring($headrt);
		next;
		}
	my $entryrefrt=$rthash{$entryref->getAttribute('guid')};
	my ($cmpntlexemesnode) = $entryrefrt->findnodes('./ComponentLexemes');
	if ($cmpntlexemesnode->findnodes(q#'./objsur[@guid="# . $cmpntguid . q#]'#) ) {
		say LOGFILE "<!--  Component guid $cmpntguid  already in Components list under" .
			displaylexentstring($headrt) . " -->";
		next;
		}
	my $newnode = $cmpntnode->cloneNode(1);
	$cmpntlexemesnode->addChild($newnode);
	say "ComponentLexemes:", $cmpntlexemesnode; # add the component lexeme as a child node to this one.
	my ($formsinnode) = $entryrefrt->findnodes('./ShowComplexFormsIn');
	say "ShowComplexFormsIn", $formsinnode; # add the component lexeme as a child node to this one.
	$newnode = $cmpntnode->cloneNode(1);
	$formsinnode->addChild($newnode);
	say "After:";
	say $entryrefrt;
	say "";

	say LOGFILE q#<pair guid="#, $mbr->getAttribute('guid'), q#" entry1id=#;

	$mbrcnt++;
	last if ($mbrcnt > 30) && $debug;
	}

# footer of log
say LOGFILE q#<!--  DON'T EDIT ANYTHING BELOW THIS LINE -->#;
say LOGFILE '</pairs>';

say STDERR "Found $mbrcnt of $mbrtotal";
die;
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
