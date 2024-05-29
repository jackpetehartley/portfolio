#!/usr/bin/perl
require al000001;
require ao000001;
require sm000001;
push (@INC, "cgi-bin");
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
use strict;
$::prog_name = "REFERRER";
$::prog_ver = '$Revision: 20560 $ ';
$::prog_ver = substr($::prog_ver, 11);
$::prog_ver =~ s/ \$//;
my $sPathToCatalog = '../gk/acatalog/';
$sPathToCatalog =~ s/\/?$/\//;
my ($status, $sMessage, $temp);
($status, $sMessage, $::g_OriginalInputData, $temp, %::g_InputHash) = ACTINIC::ReadAndParseInput();
if ($status != $::SUCCESS)
{
ACTINIC::TerminalError($sMessage);
}
my ($sSource, $sDestination, $sCatalogUrl, $sCoupon) = ($::g_InputHash{SOURCE}, $::g_InputHash{DESTINATION}, $::g_InputHash{BASEURL}, $::g_InputHash{COUPON});
$sCatalogUrl =~ s#/?$#/#;
if (!$sSource &&
!$sCoupon)
{
ACTINIC::TerminalError("The referring source is not defined.");
}
if (!$sDestination)
{
ACTINIC::TerminalError("The destination page is not defined.");
}
if (length $sCatalogUrl < 2)
{
ACTINIC::TerminalError("The BASEURL is not defined.");
}
$::g_InputHash{'ACTINIC_REFERRER'} = $sCatalogUrl;
Init();
my $sURL = $sCatalogUrl . $sDestination;
my @Response = ACTINIC::EncodeText($sURL);
$sURL = $Response[1];
my %vartable;
$vartable{'</FORM>'} = "<INPUT TYPE=HIDDEN NAME=ACTINIC_REFERRER VALUE=$sURL></FORM>";
@Response = ACTINIC::TemplateFile($sPathToCatalog . $sDestination, \%vartable);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::TerminalError($Response[1]);
}
@Response = ACTINIC::MakeLinksAbsolute($Response[2], $sCatalogUrl, $sCatalogUrl);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::TerminalError($Response[1]);
}
my $sHTML = $Response[2];
$sHTML =~ s/(\<\s*A\s*HREF[^>?]+\?)/$1ACTINIC_REFERRER=$sURL&/gi;
if ($sCoupon)
{
$::Session->SetCoupon($sCoupon);
}
if ($sSource &&
ACTINIC::IsPromptHidden(4, 2))
{
$::Session->SetReferrer($sSource);
}
ACTINIC::SaveSessionAndPrintPage($sHTML, $::Session->GetSessionID());
exit;
sub Init
{
($status, $sMessage) = ACTINIC::ReadPromptFile($sPathToCatalog);
if ($status != $::SUCCESS)
{
ACTINIC::TerminalError($sMessage);
}
($status, $sMessage) = ACTINIC::ReadSetupFile($sPathToCatalog);
if ($status != $::SUCCESS)
{
ACTINIC::TerminalError($sMessage);
}
my ($sCartID, $sContactDetails) = ACTINIC::GetCookies();
$::Session = new Session($sCartID, $sContactDetails, ACTINIC::GetPath(), $::TRUE);
}