#!perl
package Search;
require 5.002;
push (@INC, "cgi-bin");
require al000001;
use strict;
require ac000001;
$Search::prog_name = 'Search.pm';
$Search::prog_name = $Search::prog_name;
$Search::prog_ver = '$Revision: 18819 $ ';
$Search::prog_ver = substr($Search::prog_ver, 11);
$Search::prog_ver =~ s/ \$//;
$::ANY_PRICE_BAND = -1;
$::MAX_RETRY_COUNT      = 10;
$::RETRY_SLEEP_DURATION = 1;
sub OpenTextIndex
{
my ($sPath, $rFile) = @_;
my ($status, $sError);
my $nRetryCount = $::MAX_RETRY_COUNT;
$status = $::SUCCESS;
my $sFileName = $sPath . "oldtext.fil";
my $nExpected = $::g_nSearchTextIndexVersion;
while ($nRetryCount--)
{
unless (open ($rFile, "<$sFileName"))
{
$sError = $!;
sleep $::RETRY_SLEEP_DURATION;
$status = $::FAILURE;
$sError = ACTINIC::GetPhrase(-1, 246, $sFileName, $sError);
next;
}
binmode $rFile;
my $sBuffer;
unless (read($rFile, $sBuffer, 4) == 4)
{
$sError = $!;
close ($rFile);
return ($::FAILURE, ACTINIC::GetPhrase(-1, 252, $sError));
}
my ($nVersion) = unpack("n", $sBuffer);
if ($nVersion != $nExpected)
{
close($rFile);
sleep $::RETRY_SLEEP_DURATION;
$status = $::FAILURE;
$sError = ACTINIC::GetPhrase(-1, 259, $nExpected, $nVersion);
next;
}
last;
}
if ($status != $::SUCCESS)
{
return($status, $sError);
}
return ($::SUCCESS);
}
sub WordSearch
{
my ($sWord, $nLocation, $rFile, $rhashProdRefs) = @_;
my ($nDependencies, $nCount, $nRefs, $sRefs, $sBuff, $sFragment, $sAnchor);
my ($nIndex, $sSeek, $nHere, $nLength, $sNext, $nRead);
unless (seek($rFile, $nLocation, 0))
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 247, $!));
}
unless (read($rFile, $sBuff, 2) == 2)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 248, $!));
}
($nCount) = unpack("n", $sBuff);
for ($nIndex = 0; $nIndex < $nCount; $nIndex++)
{
unless (read($rFile, $sBuff, 2) == 2)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 248, $!));
}
($nLength) = unpack("n", $sBuff);
unless (read ($rFile, $sAnchor, $nLength) == $nLength)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 248, $!));
}
unless (read($rFile, $sBuff, 1) == 1)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 248, $!));
}
($nRefs) = unpack("C", $sBuff);
$sRefs = "";
if ($nRefs > 0)
{
unless (read($rFile, $sRefs, $nRefs) == $nRefs)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 248, $!));
}
}
if ($sWord eq "")
{
$$rhashProdRefs{$sAnchor} = $$rhashProdRefs{$sAnchor} . $sRefs;
}
}
unless (read($rFile, $sBuff, 2) == 2)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 248, $!));
}
$nDependencies = unpack("n", $sBuff);
for ($nIndex = 0; $nIndex < $nDependencies; $nIndex++)
{
unless (read($rFile, $sBuff, 1) == 1)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 248, $!));
}
$nLength = unpack("C", $sBuff);
unless (read($rFile, $sFragment, $nLength) == $nLength)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 248, $!));
}
unless (read($rFile, $sSeek, 4) == 4)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 248, $!));
}
unless ($$::g_pSetupBlob{SEARCH_MATCH_WHOLE_WORDS})
{
$sFragment = substr($sFragment, 0, length($sWord));
}
my $sQuotedFragment = quotemeta($sFragment);
if ($sWord =~ m/^$sQuotedFragment/i)
{
$sNext = $';
$nHere = tell($rFile);
my ($status, $sError) = WordSearch($sNext, unpack("N", $sSeek), $rFile, $rhashProdRefs);
if ($status != $::SUCCESS)
{
return ($status, $sError);
}
unless (seek($rFile, $nHere, 0))
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 247, $!));
}
}
if ($sFragment gt $sWord)
{
last;
}
}
return ($::SUCCESS);
}
sub SearchText
{
my ($sPath, $psSearchString, $bJoin, $rhashResults) = @_;
my $sWordCharacters = ACTINIC::GetPhrase(-1, 239);
my $sSplitString = "[^\Q$sWordCharacters\E]";
$$psSearchString =~ s/$sSplitString/ /g;
my $sStopList = ACTINIC::GetPhrase(-1, 238);
$$psSearchString =~ s/\s+/ /go;
$$psSearchString = lc $$psSearchString;
$sStopList = lc $sStopList;
$$psSearchString =~ tr/[ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞ]/[àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþ]/;
$sStopList =~ tr/[ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞ]/[àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþ]/;
my @listPreliminarySearchWords = split(/ +/, $$psSearchString);
my ($sWord, @listSearchWords);
foreach $sWord (@listPreliminarySearchWords)
{
if ($sWord eq '' ||
$sStopList =~ /\b$sWord\b/)
{
next;
}
push (@listSearchWords, $sWord);
}
$$psSearchString = join(' ', @listSearchWords);
if (!@listSearchWords)
{
return ($::SUCCESS);
}
my ($status, $sError) = OpenTextIndex($sPath, \*INDEX);
if ($status != $::SUCCESS)
{
return($status, $sError);
}
my (@HitLists, $rhash);
foreach $sWord (@listSearchWords)
{
$rhash = {};
($status, $sError) = WordSearch($sWord, 2, \*INDEX, $rhash); # do the search - the 2 is the number of bytes into the file where the index begins (after the 2 byte version number)
if ($status != $::SUCCESS)
{
close (INDEX);
return ($status, $sError);
}
push (@HitLists, $rhash);
}
close (INDEX);
my ($rhashCurrent, $rhashNext, $rhashLast);
$rhashLast = shift @HitLists;
foreach $rhashCurrent (@HitLists)
{
$rhashNext = {};
ACTINIC::JoinHashes($rhashLast, $rhashCurrent, $bJoin, $rhashNext);
$rhashLast = $rhashNext;
}
%$rhashResults = %$rhashLast;
LogSearchWords($$psSearchString, scalar keys %$rhashResults);
return ($::SUCCESS);
}
sub SearchSection
{
my ($sPath, $nSectionID, $rhashResults) = @_;
undef %$rhashResults;
if (!$nSectionID)
{
return ($::SUCCESS);
}
my ($status, $sError) = OpenTextIndex($sPath, \*INDEX);
if ($status != $::SUCCESS)
{
return($status, $sError);
}
my $sWord = sprintf('!@%8.8x', $nSectionID);
($status, $sError) = WordSearch($sWord, 2, \*INDEX, $rhashResults); # do the search - the 2 is the number of bytes into the file where the index begins (after the 2 byte version number)
if ($status != $::SUCCESS)
{
close (INDEX);
return ($status, $sError);
}
close (INDEX);
return ($::SUCCESS);
}
sub SearchProperty
{
my ($sPath, $sPropertyName, $sPropertyValue, $rhashResults) = @_;
$sPropertyName =~ s/^S_(.*)_\d+$/$1/;
if ((!$sPropertyName) or
($sPropertyValue eq ''))
{
return ($::SUCCESS);
}
my ($status, $sError) = OpenTextIndex($sPath, \*INDEX);
if ($status != $::SUCCESS)
{
return($status, $sError);
}
my $sWord = "!!$sPropertyName!$sPropertyValue";
($status, $sError) = WordSearch($sWord, 2, \*INDEX, $rhashResults); # do the search - the 2 is the number of bytes into the file where the index begins (after the 2 byte version number)
if ($status != $::SUCCESS)
{
close (INDEX);
return ($status, $sError);
}
close (INDEX);
return ($::SUCCESS);
}
sub SearchPriceSchedule
{
my ($sPath, $nPriceScheduleID, $rhashResults) = @_;
undef %$rhashResults;
my ($status, $sError) = OpenTextIndex($sPath, \*INDEX);
if ($status != $::SUCCESS)
{
return($status, $sError);
}
my $sWord = sprintf('!&%s', $nPriceScheduleID);
($status, $sError) = WordSearch($sWord, 2, \*INDEX, $rhashResults); # do the search - the 2 is the number of bytes into the file where the index begins (after the 2 byte version number)
if ($status != $::SUCCESS)
{
close (INDEX);
return ($status, $sError);
}
close (INDEX);
return ($::SUCCESS);
}
sub SearchPrice
{
my ($sPath, $nPriceBand, $rhashProdRefs) = @_;
if ($nPriceBand == $::ANY_PRICE_BAND)
{
return ($::SUCCESS);
}
my $nRetryCount = $::MAX_RETRY_COUNT;
my ($status, $sError);
my $nExpectedVersion = 0;
while ($nRetryCount--)
{
($status, $sError) = ACTINIC::ReadConfigurationFile($sPath . "priceband.fil");
if ($status != $::SUCCESS)
{
sleep $::RETRY_SLEEP_DURATION;
$sError .= ACTINIC::GetPhrase(-1, 256);
next;
}
if ($nPriceBand >= $#$::g_pPriceBand)
{
sleep $::RETRY_SLEEP_DURATION;
$status = $::FAILURE;
$sError = ACTINIC::GetPhrase(-1, 249);
next;
}
if ($::gnPriceBandVersion != $nExpectedVersion)
{
sleep $::RETRY_SLEEP_DURATION;
$status = $::FAILURE;
$sError = ACTINIC::GetPhrase(-1, 257, $nExpectedVersion, $::gnPriceBandVersion);
next;
}
last;
}
if ($status != $::SUCCESS)
{
return($status, $sError);
}
my $nLowerBound = $$::g_pPriceBand[$nPriceBand];
my $nUpperBound = $$::g_pPriceBand[$nPriceBand + 1];
$nRetryCount = $::MAX_RETRY_COUNT;
$status = $::SUCCESS;
my $sFileName = $sPath . "oldprice.fil";
my $nExpected = 0;
while ($nRetryCount--)
{
unless (open (INDEX, "<$sFileName"))
{
sleep $::RETRY_SLEEP_DURATION;
$status = $::FAILURE;
$sError = ACTINIC::GetPhrase(-1, 250, $sFileName, $!);
next;
}
binmode INDEX;
my $sBuffer;
unless (read(INDEX, $sBuffer, 2) == 2)
{
$sError = $!;
close (INDEX);
return ($::FAILURE, ACTINIC::GetPhrase(-1, 252, $sError));
}
my ($nVersion) = unpack("N", $sBuffer);
if ($nVersion != $nExpected)
{
close(INDEX);
sleep $::RETRY_SLEEP_DURATION;
$status = $::FAILURE;
$sError = ACTINIC::GetPhrase(-1, 258, $nExpected, $nVersion);
next;
}
last;
}
if ($status != $::SUCCESS)
{
return($status, $sError);
}
unless (seek (INDEX, $nLowerBound, 0))
{
$sError = $!;
close (INDEX);
return ($::FAILURE, ACTINIC::GetPhrase(-1, 251, $sError));
}
my $nBytesToRead = $nUpperBound - $nLowerBound;
my $sBuffer;
unless (read(INDEX, $sBuffer, $nBytesToRead) == $nBytesToRead)
{
$sError = $!;
close (INDEX);
return ($::FAILURE, ACTINIC::GetPhrase(-1, 252, $sError));
}
close (INDEX);
%$rhashProdRefs = map {$_ => 0} split(/\|/, $sBuffer);
return ($::SUCCESS);
}
sub SearchProductGroup
{
my ($sPath, $nGroupID, $rhashResults) = @_;
undef %$rhashResults;
if (!$nGroupID)
{
return ($::SUCCESS);
}
my ($status, $sError) = OpenTextIndex($sPath, \*INDEX);
if ($status != $::SUCCESS)
{
return($status, $sError);
}
my $sWord = sprintf('!D!%8.8x', $nGroupID);
($status, $sError) = WordSearch($sWord, 2, \*INDEX, $rhashResults); # do the search - the 2 is the number of bytes into the file where the index begins (after the 2 byte version number)
if ($status != $::SUCCESS)
{
close (INDEX);
return ($status, $sError);
}
close (INDEX);
return ($::SUCCESS);
}
sub LogSearchWords
{
my $sWordList = shift;
my $nHits = shift;
if (length $::SEARCH_WORD_LOG_FILE == 0)
{
return;
}
my $sUserDigest = $ACTINIC::B2B->Get('UserDigest');
my ($nBuyerID, $nCustomerID) = (0, 0);
if ($sUserDigest)
{
my ($status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sUserDigest, ACTINIC::GetPath());
if ($status != $::SUCCESS)
{
return ($status, $sMessage);
}
$nBuyerID = $$pBuyer{ID};
$nCustomerID = $$pBuyer{AccountID};		
}
my $sFilename = ACTINIC::GetPath() . $::SEARCH_WORD_LOG_FILE;
my $bDoHeader = !-e $sFilename;
$sWordList =~ s/"/""/;
open (LOGFILE, ">>" . $sFilename);
if ($bDoHeader)	
{
print LOGFILE "Version: $::EC_MAJOR_VERSION\nDate, Remote host, Customer ID, Buyer ID, Search words\n";
}
print LOGFILE ACTINIC::GetActinicDate();
print LOGFILE ", ";
print LOGFILE (length $::ENV{REMOTE_HOST} > 0 ? $::ENV{REMOTE_HOST} : $::ENV{REMOTE_ADDR});
print LOGFILE ", ";
print LOGFILE $nCustomerID;
print LOGFILE ", ";
print LOGFILE $nBuyerID;
print LOGFILE ", ";
print LOGFILE "\"$sWordList\", $nHits";	
print LOGFILE "\n";
close LOGFILE;	
}
1;