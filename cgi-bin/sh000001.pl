#!/usr/bin/perl
my $bFound = 0;
my $sDir;
foreach $sDir (@INC)
{
if ($sDir eq ".")
{
$bFound = 1;
last;
}
}
if (!$bFound)
{
push (@INC, ".");
}
push (@INC, "cgi-bin");
require al000001;
require ao000001;
require sm000001;
use strict;
$::prog_name = "SearchHighligh";
$::prog_name = $::prog_name;
$::prog_ver = '$Revision: 18819 $ ';
$::prog_ver = substr($::prog_ver, 11);
$::prog_ver =~ s/ \$//;
my $sPath = Init();
my $sPageName = $::g_InputHash{PN};
$sPageName =~ /([^\#]*)(.*)/;
my $sAnchor = $2;
$sPageName = $1;
if (!$sPageName)
{
SearchError(ACTINIC::GetPhrase(-1, 268), $sPath);
exit;
}
if ($sPageName =~ /\//i ||
$sPageName =~ /\.\./)
{
SearchError(ACTINIC::GetPhrase(-1, 269), $sPath);
exit;
}
ACTINIC::SecurePath($sPageName);
if ($sAnchor !~ /^\#[a-zA-Z0-9_]*$/)
{
SearchError(ACTINIC::GetPhrase(-1, 270), $sPath);
exit;
}
my $sWords = $::g_InputHash{WD};
my ($status, $sError, $sHTML) = PreparePage($sPath, $sPageName, $sAnchor, $sWords, $::g_sWebSiteUrl, $::g_sContentUrl,
$$::g_pSearchSetup{SEARCH_HIGHLIGHT_START}, $$::g_pSearchSetup{SEARCH_HIGHLIGHT_END});
if ($status != $::SUCCESS)
{
SearchError($sError, $sPath);
exit;
}
ACTINIC::PrintPage($sHTML, undef, $::FALSE);
exit;
sub Init
{
my ($status, $sError, $unused);
($status, $sError, $::g_OriginalInputData, $unused, %::g_InputHash) = ACTINIC::ReadAndParseInput();
if ($::SUCCESS != $status)
{
ACTINIC::TerminalError($sError);
}
my $sPath = ACTINIC::GetPath();
ACTINIC::SecurePath($sPath);
if (!$sPath)
{
ACTINIC::TerminalError("Path not found.");
}
if (!-e $sPath ||
!-d $sPath)
{
ACTINIC::TerminalError("Invalid path.");
}
($status, $sError) = ACTINIC::ReadPromptFile($sPath);
if ($status != $::SUCCESS)
{
ACTINIC::TerminalError($sError, $sPath);
}
($status, $sError) = ACTINIC::ReadSetupFile($sPath);
if ($status != $::SUCCESS)
{
ACTINIC::ReportError($sError, $sPath);
}
($status, $sError) = ACTINIC::ReadSearchSetupFile($sPath);
if ($status != $::SUCCESS)
{
ACTINIC::ReportError($sError, $sPath);
}
($status, $sError) = ACTINIC::ReadCatalogFile($sPath);
if ($status != $::SUCCESS)
{
ACTINIC::ReportError($sError, $sPath);
}
my ($sCartID, $sContactDetails) = ACTINIC::GetCookies();
$::Session = new Session($sCartID, $sContactDetails, ACTINIC::GetPath(), $::TRUE);
$::g_sWebSiteUrl = $::Session->GetBaseUrl();
$::g_sContentUrl = $::g_sWebSiteUrl;
return ($sPath);
}
sub SearchError
{
my ($sMessage, $sPath) = @_;
my ($status, $sError, $sHTML) = ACTINIC::ReturnToLastPage(5, ACTINIC::GetPhrase(-1, 1962) . $sMessage . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2050), ACTINIC::GetPhrase(-1, 141),
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, %::g_InputHash);
if ($status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
ACTINIC::UpdateDisplay($sHTML, $::g_OriginalInputData);
}
sub PreparePage
{
my ($sPath, $sPageName, $sAnchor, $sWords, $sWebSiteUrl, $sContentUrl, $sStart, $sEnd) = @_;
unless (open (TFFILE, "<$sPath$sPageName"))
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 21, $sPath . $sPageName, $!));
}
my ($sHTML);
{
local $/;
$sHTML = <TFFILE>;
}
close (TFFILE);
ACTINIC::HighlightWords($sWords, $sStart, $sEnd, \$sHTML);
($status, $sError, $sHTML) = ACTINIC::MakeLinksAbsolute($sHTML, $sWebSiteUrl, $sContentUrl);
if ($status != $::SUCCESS)
{
return ($status, $sError);
}
return ($::SUCCESS, undef, $sHTML);
}