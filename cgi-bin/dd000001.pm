#!perl
use strict;
package DigitalDownload;
$DigitalDownload::CONTENTPATH = '../gk/acatalog/' . 'DD/'; # needs to be set to the path to the digital content - requires trailing slash
$DigitalDownload::CGIBINURL = 'http://www.jackhartley.com/cgi-bin/';
$DigitalDownload::XORKEY = 0xd1;
$DigitalDownload::SIGKEY = 'HairyMonkey';
$DigitalDownload::PATHINFO_OVERRIDE = 0;
$DigitalDownload::NPH = 1;
$DigitalDownload::FAILURE = 0;
$DigitalDownload::SUCCESS = 1;
$DigitalDownload::DOWNLOAD_SCRIPT_NAME = 'nph-dl000001.pl';
sub GetContentList
{
if (2 != @_)
{
return ($DigitalDownload::FAILURE, 'Programming Error: Invalid parameter count', undef);
}
my ($status, $sError) = _LoadMD5();
if ($status != $DigitalDownload::SUCCESS)
{
return ($status, $sError, undef);
}
my ($nDuration, $plistProductRefs) = @_;
if (0 == @$plistProductRefs)
{
return ($DigitalDownload::SUCCESS, undef, {});
}
unless (opendir(DIR, $DigitalDownload::CONTENTPATH))
{
return ($DigitalDownload::FAILURE, "System Error: Unable to open content directory. $!", undef);
}
my @listFiles = grep
{-f "$DigitalDownload::CONTENTPATH/$_"}
readdir DIR;
closedir DIR;
my ($sProdRef, $sRegExp);
foreach $sProdRef (@$plistProductRefs)
{
$sRegExp .= (quotemeta $sProdRef) . "|";
}
chop $sRegExp;
$sRegExp = "^($sRegExp)_";
my $nTime = time + $nDuration * 3600;
my $sBaseURL = $DigitalDownload::CGIBINURL . $DigitalDownload::DOWNLOAD_SCRIPT_NAME; # the base URL (can be relative)
my ($sFile, %mapProdRefToFileList);
foreach $sFile (@listFiles)
{
if ($sFile =~ /$sRegExp/)
{
my $sProdRef = $1;
my $sEncodedString = _PackData($nTime, $sFile);
my $sURL = $sBaseURL;
unless ( ($::ENV{SERVER_SOFTWARE} =~ /MICROSOFT/i ||
$::ENV{SERVER_SOFTWARE} =~ /IIS/i) &&
!$DigitalDownload::PATHINFO_OVERRIDE)
{
$sFile =~ /$sRegExp\d+_(.*)/;
my $sPresentationFile = $2;
$sPresentationFile =~ s/ /+/;
$sURL .= "/$sPresentationFile";
}
$sURL .= "?DAT=" . $sEncodedString;
if (exists $mapProdRefToFileList{$sProdRef})
{
push @{$mapProdRefToFileList{$sProdRef}}, $sURL;
}
else
{
$mapProdRefToFileList{$sProdRef} = [$sURL];
}
}
}
return ($DigitalDownload::SUCCESS, undef, \%mapProdRefToFileList);
}
sub _LoadMD5
{
eval
{
require Digest::MD5;
import Digest::MD5 'md5_hex';
};
if ($@)
{
eval
{
require di000001;
import Digest::Perl::MD5 'md5_hex';
};
if ($@)
{
return ($DigitalDownload::FAILURE, 'Programming Error: No MD5 module found');
}
}
return ($DigitalDownload::SUCCESS, undef);
}
sub _PackData
{
my ($nTime, $sFile) = @_;
my $sDownloadString = $sFile . "\0" . $nTime;
$sDownloadString .= "\0" . md5_hex($sDownloadString . $DigitalDownload::SIGKEY);
my @listEncodedCharacters = map
{
$_ ^ $DigitalDownload::XORKEY
}
unpack('C*', $sDownloadString);
my $sEncodedString = join('',
map {sprintf('%2.2x', $_)}
@listEncodedCharacters);
return $sEncodedString;
}
sub _UnpackData
{
my ($sString) = @_;
my @listHexSets = $sString =~ m/[0-9a-zA-Z]{2}/g;
my @listHexValues = map {hex $_} @listHexSets;
my @listDecodedCharacters = map
{
$_ ^ $DigitalDownload::XORKEY
}
@listHexValues;
$sString = pack('C*', @listDecodedCharacters);
my ($sFile, $nTime, $sSignature) = split(/\0/, $sString);
my ($status, $sError) = _LoadMD5();
if ($status != $DigitalDownload::SUCCESS)
{
return ($status, $sError, undef, undef);
}
my $sRegeneratedSig = md5_hex($sFile . "\0" . $nTime . $DigitalDownload::SIGKEY);
if ($sRegeneratedSig ne $sSignature)
{
return ($DigitalDownload::FAILURE, "Error: Invalid signature", undef, undef);
}
return ($DigitalDownload::SUCCESS, undef, $nTime, $sFile);
}