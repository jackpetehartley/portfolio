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
require as000001;
require ad000001;
require ae000001;
require ao000001;
require sm000001;
use strict;
$::prog_name = "CATACACC";
$::prog_ver = '$Revision: 20549 $';
$::prog_ver = substr($::prog_ver, 11);
$::prog_ver =~ s/ \$//;
Init();
CAccDispatch();
exit;
sub CAccDispatch
{
my $sProdRef = $::g_InputHash{'PRODUCTREF'};
if ($::g_InputHash{ACTION} eq 'LOGOUT')
{
CaccLogout();
}
elsif ($::g_InputHash{ACTION} eq 'DIRECTLINK')
{
if ($sProdRef &&
!ACTINIC::IsProductVisible($sProdRef))
{
CAccPrintWarningBouncePage();
}
else
{
my @Response = ACTINIC::TemplateFile(ACTINIC::GetPath() . $$::g_pSetupBlob{FRAMESET_PAGE});
if ($Response[0] != $::SUCCESS)
{
ACTINIC::TerminalError($Response[1]);
}
@Response = ACTINIC::MakeLinksAbsolute($Response[2], $::g_InputHash{ACTINIC_REFERRER}, $::g_InputHash{ACTINIC_REFERRER});
$ACTINIC::B2B->Set('BaseFile', $::g_InputHash{ACTINIC_REFERRER});
ACTINIC::PrintPage($Response[2], $::Session->GetSessionID());
}
exit;
}
if (defined $::g_InputHash{SSLBOUNCE} &&
$::g_InputHash{SSLBOUNCE} == 1)
{
PrintSSLBouncePage();
}
ACTINIC::CAccLogin();
if (($$::g_pSetupBlob{SSL_USEAGE} == 1) &&
($::g_bJustAfterLogin == $::TRUE))
{
my @Response = ACTINIC::BounceToPagePlain(0, undef, undef, $::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $::g_sAccountScript . "?PRODUCTPAGE=" . $::g_pInputHash{PRODUCTPAGE}, \%::g_InputHash);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
}
my $sHTML = $Response[2];
my $sCartCookie = ActinicOrder::GenerateCartCookie();
ACTINIC::SaveSessionAndPrintPage($sHTML, $::Session->GetSessionID(), $::TRUE, "", $::TRUE, $sCartCookie);
exit;
}
if ($sProdRef &&
!ACTINIC::IsProductVisible($sProdRef))
{
CAccPrintWarningBouncePage();
}
else
{
if( $::g_InputHash{PRODUCTPAGE} =~ /\S/ )
{
$ACTINIC::B2B->Set('ProductPage',$::g_InputHash{PRODUCTPAGE});
}
my @Response = CAccPrintPage();
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
}
}
}
sub CaccLogout
{
my $sHTML;
my ($sAccountCookie, $sBaseFile)   = ACTINIC::CaccGetCookies();
if ($$::g_pSetupBlob{'HOMEPAGEURL'})
{
$sBaseFile = $$::g_pSetupBlob{'HOMEPAGEURL'};
}
my @Response = ACTINIC::BounceToPagePlain(0, undef, undef, $::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $sBaseFile, \%::g_InputHash);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
}
$sHTML = $Response[2];
$ACTINIC::B2B->Set('UserIDCookie',".");
$ACTINIC::B2B->Set('ClearIDCookie','CLEAR');
my (%hashBillAddress, %hashShipAddress, %hashShipInfo, %hashTaxInfo,
%hashGeneralInfo, %hashPaymentInfo, %hashLocationInfo);
my @Response = $::Session->UpdateCheckoutInfo(
\%hashBillAddress, \%hashShipAddress, \%hashShipInfo, \%hashTaxInfo,
\%hashGeneralInfo, \%hashPaymentInfo, \%hashLocationInfo);
CAccPrintPageWithOptionalHighlight($sHTML, undef, $::FALSE);
exit;
}
sub CAccPrintPage
{
my $sHTML = shift;
if( $sHTML )
{
CAccPrintPageWithOptionalHighlight($sHTML, $::Session->GetSessionID(), $::FALSE);
exit;
}
my ($sProductPage,$sBodyPage);
if( $::g_InputHash{PRODUCTPAGE} =~ /\S/ )
{
$sProductPage = $::g_InputHash{PRODUCTPAGE};
if( $::g_InputHash{MAINFRAMEURL} =~ /\S/ )
{
$sBodyPage = $::g_InputHash{MAINFRAMEURL};
}
}
else
{
if ($::g_InputHash{BROCHUREMAINFRAMEURL} =~ /\S/)
{
$::g_InputHash{MAINFRAMEURL} = $::g_InputHash{BROCHUREMAINFRAMEURL};
($sBodyPage,$sProductPage) = ($::g_InputHash{BROCHUREMAINFRAMEURL}, $$::g_pSetupBlob{BROCHURE_FRAMESET_PAGE});
}
else
{
($sBodyPage,$sProductPage) = ACTINIC::CAccCatalogBody();
}
}
my ($sFirst,$sLast) = split("#",$sProductPage);
my $StoreFolderName = ACTINIC::GetStoreFolderName();
$sFirst =~ s/^$StoreFolderName\///;
my $bBinmode = $::FALSE;
if (!ACTINIC::IsStaticPage($sFirst))
{
$bBinmode = $::TRUE;
}
my @Response = ACTINIC::TemplateFile(ACTINIC::GetPath() . $sFirst, undef, $bBinmode);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $sPath = $ACTINIC::B2B->Get('BaseFile');
if( $sLast ) { $sPath .= "#$sLast" }
my $sCgiUrl = $::g_sAccountScript;
$sCgiUrl   .= ($::g_InputHash{SHOP} ? '?SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) . '&' : '?');
$sCgiUrl   .= "ACTINIC_REFERRER=" . ACTINIC::EncodeText2($::g_sAccountScript) . '&';
if( $sBodyPage and $sBodyPage ne $sProductPage )
{
$sCgiUrl .= "MAINFRAMEURL=$sBodyPage" . '&PRODUCTPAGE=';
}
else
{
$sCgiUrl .= "PRODUCTPAGE=";
}
$sHTML = ACTINIC::ParseXML($Response[2]);
@Response = ACTINIC::MakeLinksAbsolute($sHTML, $sCgiUrl, $sPath);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sHTML = $Response[2];
if ($sFirst =~ /\.\.\//)
{
$sHTML =~ s/(<Actinic:BASEHREF)/$1 FORCED=1/;
}
if( $::g_InputHash{PRODUCTPAGE} =~ /\S/ )
{
my $sReplace = sprintf("<INPUT TYPE=HIDDEN NAME=ACTINIC_REFERRER VALUE='%s?PRODUCTPAGE=%s'>", $::g_sAccountScript, $sProductPage );
$sHTML =~ s/(<FORM[^>]*>)/$1$sReplace/gi;
my @Response = ACTINIC::EncodeText($sReplace);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $sEncodedReplace = $Response[1];
$sHTML =~ s/(&\#60;FORM.*?&\#62;)/$1$sEncodedReplace/gi
}
CAccPrintPageWithOptionalHighlight($sHTML, $::Session->GetSessionID(), $::FALSE, $::TRUE);
exit;
}
sub CAccPrintPageWithOptionalHighlight
{
my ($sHTML, $sCookie, $bNoCache, $bSkipXMLParse) = @_;
if (!defined $bSkipXMLParse)
{
$bSkipXMLParse = $::FALSE;
}
if (!$bSkipXMLParse)
{
$sHTML = ACTINIC::ParseXML($sHTML);
}
my $sWords = $::g_InputHash{WD};
my $bParseAgain = $::FALSE;
if ($sWords)
{
ACTINIC::HighlightWords($sWords, $$::g_pSearchSetup{SEARCH_HIGHLIGHT_START}, $$::g_pSearchSetup{SEARCH_HIGHLIGHT_END}, \$sHTML);
$bParseAgain = $::TRUE;
}
my $sCartCookie = ActinicOrder::GenerateCartCookie();
ACTINIC::SaveSessionAndPrintPage($sHTML, $sCookie, $bNoCache, "",
!$bParseAgain,
$sCartCookie);
}
sub CAccPrintWarningBouncePage
{
my ($Status, $Message, $sHTML) = ACTINIC::BounceToPageEnhanced(2,
ACTINIC::GetPhrase(-1, 2177),
'',
$::g_sWebSiteUrl,
$::g_sContentUrl,
$::g_pSetupBlob,
$::g_sAccountScript . "?PRODUCTPAGE=" . $::g_pInputHash{PRODUCTPAGE},
\%::g_InputHash);
if ($Status != $::SUCCESS)
{
ACTINIC::TerminalError($Message);
}
ACTINIC::SaveSessionAndPrintPage($sHTML, $::Session->GetSessionID(), $::FALSE);
}
sub Init
{
$::g_bFirstError = $::TRUE;
my (@Response, $Status, $Message, $temp);
($Status, $Message, $::g_OriginalInputData, $temp, %::g_InputHash) = ACTINIC::ReadAndParseInput();
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
@Response = ReadAndParseBlobs();
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
$::g_sWebSiteUrl = $::Session->GetBaseUrl();
$::g_sContentUrl = $::g_sWebSiteUrl;
}
sub ReadAndParseBlobs
{
my ($Status, $Message, @Response, $sPath);
$sPath = ACTINIC::GetPath();
@Response = ACTINIC::ReadCatalogFile($sPath);
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::ReadSetupFile($sPath);
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::ReadLocationsFile($sPath);
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::ReadPhaseFile($sPath);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::ReadPromptFile($sPath);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::ReadTaxSetupFile($sPath);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::ReadSearchSetupFile($sPath);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($sCartID, $sContactDetails) = ACTINIC::GetCookies();
$::Session = new Session($sCartID, $sContactDetails, ACTINIC::GetPath(), $::TRUE);
my ($pBillContact, $pShipContact, $pShipInfo, $pTaxInfo, $pGeneralInfo, $pPaymentInfo, $pLocationInfo);
@Response = $::Session->RestoreCheckoutInfo();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
no strict 'refs';
($Status, $Message, $pBillContact, $pShipContact, $pShipInfo, $pTaxInfo, $pGeneralInfo, $pPaymentInfo, $pLocationInfo) = @Response;
%::g_BillContact = %$pBillContact;
%::g_ShipContact = %$pShipContact;
%::g_ShipInfo		= %$pShipInfo;
%::g_TaxInfo		= %$pTaxInfo;
%::g_GeneralInfo = %$pGeneralInfo;
%::g_PaymentInfo = %$pPaymentInfo;
%::g_LocationInfo = %$pLocationInfo;
return ($::SUCCESS, "", 0, 0);
}
sub PrintSSLBouncePage
{
my ($sParams, $sKey, $sValue);
undef $::g_InputHash{SSLBOUNCE};
while (($sKey, $sValue) = each (%::g_InputHash))
{
$sParams .= "$sKey=" . ACTINIC::EncodeText2($sValue, $::FALSE) . "&";
}
my @Response = ACTINIC::BounceToPagePlain(0, undef, undef, $::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, sprintf("%s?%s", $::g_sAccountScript, $sParams), \%::g_InputHash);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
}
ACTINIC::PrintPage($Response[2], $::Session->GetSessionID());
exit;
}