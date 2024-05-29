#!/usr/bin/perl
use strict;
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
require sm000001;
$::g_sSmtpServer = "localhost";
Init();
DispatchCommands();
exit;
sub DispatchCommands
{
my (@Response, $Status, $Message, $sHTML, $sAction, $pFailures, $sCartID);
$sAction = $::g_InputHash{"ACTION"};
if ($sAction =~ m/$::g_sSendMailLabel/i )
{
@Response = SendMailToMerchant();
}
elsif ($sAction =~ m/SHOWFORM/i)
{
DisplayMailPage($::g_BillContact{'NAME'}, "", $::g_BillContact{'EMAIL'}, "");
}
else
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 1284), ACTINIC::GetPath());
exit;
}
($Status, $Message, $pFailures) = @Response;
if ($Status == $::FAILURE)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
exit;
}
sub SendMailToMerchant
{
my ($sEmailRecpt, $sSubject, $sTextMailBody, $sName, $sMessage, $sHTML);
$sEmailRecpt 	= $::g_InputHash{'EmailAddress'};
$sSubject 		= $::g_InputHash{'Subject'};
$sName 			= $::g_InputHash{'Name'};
$sMessage 		= $::g_InputHash{'Message'};
my $sError;
if ($sName eq "")
{
$sError .= ACTINIC::GetRequiredMessage(-1, 2370);
}
if ($sSubject eq "")
{
$sError .= ACTINIC::GetRequiredMessage(-1, 2372);
}
if ($sEmailRecpt eq "")
{
$sError .= ACTINIC::GetRequiredMessage(-1, 2371);
}
elsif ($sEmailRecpt !~ /.+\@.+\..+/)
{
$sError .= ACTINIC::GetPhrase(-1, 2378) . "\r\n";
}
if ($sMessage eq "")
{
$sError .= ACTINIC::GetRequiredMessage(-1, 2373);
}
if ($sError ne "")
{
$sError = ACTINIC::GroomError($sError);
$ACTINIC::B2B->SetXML('VALIDATIONERROR', $sError);
DisplayMailPage($sName, $sSubject, $sEmailRecpt, $sMessage);
}
else
{
$sError = ACTINIC::GetPhrase(-1, 2377);
$sTextMailBody .= ACTINIC::GetPhrase(-1, 2370) . $sName . "\r\n";
$sTextMailBody .= ACTINIC::GetPhrase(-1, 2371) . $sEmailRecpt . "\r\n";
$sTextMailBody .= ACTINIC::GetPhrase(-1, 2373) . "\r\n" . $sMessage . "\r\n\r\n";
my @Response = ACTINIC::SendMail($::g_sSmtpServer, $$::g_pSetupBlob{EMAIL}, $sSubject, $sTextMailBody, $sEmailRecpt);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::RecordErrors($Response[1], ACTINIC::GetPath());
$sError = $Response[1];
}
@Response = ACTINIC::BounceToPageEnhanced(5, ACTINIC::GetPhrase(-1, 1962) . $sError . ACTINIC::GetPhrase(-1, 1970),
$$::g_pSetupBlob{CHECKOUT_DESCRIPTION},
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $::Session->GetLastShopPage(), \%::g_InputHash,
$::FALSE);
$sHTML = $Response[2];
$sHTML =~ s/<Actinic:UNREG>.*?\/Actinic:UNREG>//isg;
}
ACTINIC::SaveSessionAndPrintPage($sHTML, undef);
exit;
}
sub DisplayMailPage
{
my ($sName, $sSubject, $sEmail, $sText) = @_;
my %VarTable;
$VarTable{'NETQUOTEVAR:NAMEVALUE'} 		= $sName;
$VarTable{'NETQUOTEVAR:EMAILVALUE'} 	= $sEmail;
$VarTable{'NETQUOTEVAR:SUBJECTVALUE'} 	= $sSubject;
$VarTable{'NETQUOTEVAR:MESSAGEVALUE'}	= $sText;
my @Response = ACTINIC::TemplateFile(ACTINIC::GetPath() . "mail_form.html", \%VarTable);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
}
my ($sDigest,$sBaseFile) = ACTINIC::CaccGetCookies();
my $sPath = ($sBaseFile) ? $sBaseFile : $::g_sContentUrl;
if( !$ACTINIC::B2B->Get('UserDigest') )
{
@Response = ACTINIC::MakeLinksAbsolute($Response[2], $::g_sWebSiteUrl, $::sPath);
}
else
{		
my $sCgiUrl = $::g_sAccountScript;
$sCgiUrl   .= ($::g_InputHash{SHOP} ? '?SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) . '&': '?');
$sCgiUrl   .= 'PRODUCTPAGE=';
@Response = ACTINIC::MakeLinksAbsolute($Response[2], $sCgiUrl, $sPath);
}
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
}
my $sHTML = $Response[2];
PrintPage($sHTML);
exit;
}
sub Init
{
$::prog_name = "MailForm";
$::prog_ver = '$Revision: 18819 $';
$::prog_ver = substr($::prog_ver, 11);
$::prog_ver =~ s/ \$//;
$ActinicOrder::s_nContext = $ActinicOrder::FROM_CART;
my (@Response, $Status, $Message);
@Response = ReadAndParseInput();
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::TerminalError($Message);
}
@Response = ReadAndParseBlobs();
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
$::g_sWebSiteUrl = $::Session->GetBaseUrl();
$::g_sContentUrl = $::g_sWebSiteUrl;
$ACTINIC::B2B->Set('UserDigest',ACTINIC::CAccFindUser());
ACTINIC::InitMonthMap();
if(!defined $::g_InputHash{"ACTION"})
{
if(defined $::g_InputHash{"ACTION_SENDMAIL.x"})
{
$::g_InputHash{"ACTION"} = $::g_sSendMailLabel;
}
}
}
sub ReadAndParseInput
{
my ($status, $message, $temp);
($status, $message, $::g_OriginalInputData, $temp, %::g_InputHash) = ACTINIC::ReadAndParseInput();
if ($status != $::SUCCESS)
{
return ($status, $message, 0, 0);
}
return ($::SUCCESS, "", 0, 0);
}
sub ReadAndParseBlobs
{
my ($Status, $Message, @Response, $sPath);
$sPath = ACTINIC::GetPath();
@Response = ACTINIC::ReadPromptFile($sPath);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
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
%::g_BillContact	= %$pBillContact;
%::g_ShipContact 	= %$pShipContact;
%::g_ShipInfo	 	= %$pShipInfo;
%::g_TaxInfo		= %$pTaxInfo;
%::g_GeneralInfo 	= %$pGeneralInfo;
%::g_PaymentInfo  = %$pPaymentInfo;
%::g_LocationInfo = %$pLocationInfo;
return ($::SUCCESS, "");
}
sub PrintPage
{
return (
ACTINIC::UpdateDisplay($_[0], $::g_OriginalInputData,
$_[1], $_[2], '', '')
);
}