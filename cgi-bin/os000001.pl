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
use Socket;
use strict;
$::prog_name = "ORDERSCR";
$::prog_name = $::prog_name;
$::prog_ver = '$Revision: 20345 $ ';
$::prog_ver = substr($::prog_ver, 11);
$::prog_ver =~ s/ \$//;
$::FORWARD	= 0;
$::BACKWARD	= 1;
$::eApplet 		= 0;
$::eSharedSSL	= 1;
$::eDelivery	= 0;
$::eInvoice		= 1;
$::ORDER_BLOB_VERSION = 22;
$::ORDER_DETAIL_BLOB_VERSION = 12;
$::g_sSmtpServer = "localhost";
$::g_sUserKey = "92ecfc80f9afe2b7f7db0cb0b764eec5";
$::g_nCurrentSequenceNumber = -1;
$::g_nNextSequenceNumber = -1;
$::g_bSpitSSLChange = $::FALSE;
my $nDebugLogLevel = 0;
$::g_pFieldSizes =
{
'NAME'			=> 40,
'FIRSTNAME'		=> 40,
'LASTNAME' 		=> 40,
'SALUTATION'	=> 15,
'JOBTITLE'		=> 50,
'COMPANY'		=> 100,
'PHONE'			=> 25,
'MOBILE'		=> 25,
'FAX'			=> 25,
'EMAIL'			=> 255,
'ADDRESS1'		=> 200,
'ADDRESS2'		=> 200,
'ADDRESS3'		=> 200,
'ADDRESS4'		=> 200,
'POSTALCODE'	=> 50,
'COUNTRY'		=> 75,
'USERDEFINED'	=> 255,
'HOWFOUND'		=> 255,
'WHYBUY'		=> 255,
'PONO'			=> 50,
};
Init();
ProcessInput();
exit;
sub Init
{
$::g_bFirstError = $::TRUE;
my (@Response, $Status, $Message, $sAction, $sSendMailButton);
@Response = ReadAndParseInput();
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::TerminalError($Message);
}
if ((not defined $::g_InputHash{'ACTION'}) &&
($::g_InputHash{'m_6'} eq 'VCSCALL'))
{
my $sAuthCallURL = ACTINIC::DecodeText($::g_InputHash{'m_3'}, $ACTINIC::FORM_URL_ENCODED);
$sAuthCallURL =~ /.*?PATH=(.*?)\&/;
$::g_InputHash{'PATH'} = $1;
$sAuthCallURL =~ /.*?SEQUENCE=(.*?)\&/;
$::g_InputHash{'SEQUENCE'} = $1;
$sAuthCallURL =~ /.*?ACTION=(.*?)\&/;
$::g_InputHash{'ACTION'} = $1;
$sAuthCallURL =~ /.*?CARTID=(.*?)\&/;
$::g_InputHash{'CARTID'} = $1;
$::g_InputHash{'ACT_POSTPROCESS'} = 1;
$::g_InputHash{ON} = $::g_InputHash{m_1};
$::g_InputHash{AM} = $::g_InputHash{p6} * $::g_InputHash{m_8};
}
if ($::g_InputHash{'ACTION'} =~ m/SSP_TRACK/i)
{
my $sPath = ACTINIC::GetPath();
@Response = ACTINIC::ReadPromptFile($sPath);
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
@Response = ACTINIC::ReadSSPSetupFile($sPath);
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
@Response = FormatTrackingPage();
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
my $sHTML = $Response[2];
ACTINIC::PrintPage($sHTML, undef);
exit;
}
if ($::g_InputHash{'SEQUENCE'} <= 3)
{
CreateAddressBook();
}
@Response = ReadAndParseBlobs();
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
$::g_sWebSiteUrl = $::Session->GetBaseUrl();
$::g_sContentUrl = $::g_sWebSiteUrl;
if ($::g_InputHash{"ACTION"} =~ /^OFFLINE_AUTHORIZE/i)
{
DoOfflineAuthorization();
exit;
}
if($::g_InputHash{"ACTION"} eq "OCC_VALIDATE" ||
($::g_InputHash{ACTION} =~ /^AUTHORIZE/i) ||
($::g_InputHash{"ACTION"} eq "RECORDORDER" && $$::g_pSetupBlob{USE_SHARED_SSL}))
{
$::Session->SetCallBack($::TRUE);
if(defined $::g_PaymentInfo{BUYERHASH})
{
$ACTINIC::B2B->Set('UserDigest', $::g_PaymentInfo{BUYERHASH});
$ACTINIC::B2B->Set('UserName', $::g_PaymentInfo{BUYERNAME});
$ACTINIC::B2B->Set('BaseFile', $::g_PaymentInfo{BASEFILE});
}
}
else
{
$ACTINIC::B2B->Set('UserDigest',ACTINIC::CAccFindUser());
}
ACTINIC::InitMonthMap();
if( $::g_InputHash{'BASE'} )
{
$::g_sContentUrl = $::g_InputHash{'BASE'};
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
if ($::g_InputHash{'SESSIONID'})
{
if ($ENV{'HTTP_COOKIE'} !~ /ACTINIC_CART/)
{
$ENV{'HTTP_COOKIE'} = ACTINIC::DecodeText($::g_InputHash{'COOKIE'}, $ACTINIC::FORM_URL_ENCODED);
}
else
{
$ENV{'HTTP_COOKIE'} =~ s/(ACTINIC_CART=)[^;]*;?/$1$::g_InputHash{'SESSIONID'};/;
$ENV{'HTTP_COOKIE'} =~ s/(CART_CONTENT=)[^;]*;?/$1$::g_InputHash{'CARTCOOKIE'};/;
$ENV{'HTTP_COOKIE'} =~ s/(ACTINIC_BUSINESS=)[^;]*;?/$1$::g_InputHash{'DIGEST'};/;
}
$::g_bSpitSSLChange = $::TRUE;
}
if( $::g_InputHash{ADDRESSSELECT} )
{
undef $::g_InputHash{'INVOICESALUTATION'};
undef $::g_InputHash{'INVOICENAME'};
undef $::g_InputHash{'INVOICEFIRSTNAME'};
undef $::g_InputHash{'INVOICELASTNAME'};
undef $::g_InputHash{'INVOICEJOBTITLE'};
undef $::g_InputHash{'INVOICECOMPANY'};
undef $::g_InputHash{'INVOICEADDRESS1'};
undef $::g_InputHash{'INVOICEADDRESS2'};
undef $::g_InputHash{'INVOICEADDRESS3'};
undef $::g_InputHash{'INVOICEADDRESS4'};
undef $::g_InputHash{'INVOICEPOSTALCODE'};
undef $::g_InputHash{'INVOICECOUNTRY'};
undef $::g_InputHash{'INVOICEPHONE'};
undef $::g_InputHash{'INVOICEMOBILE'};
undef $::g_InputHash{'INVOICEFAX'};
undef $::g_InputHash{'INVOICEEMAIL'};
undef $::g_InputHash{'DELIVERSALUTATION'};
undef $::g_InputHash{'DELIVERNAME'};
undef $::g_InputHash{'DELIVERFIRSTNAME'};
undef $::g_InputHash{'DELIVERLASTNAME'};
undef $::g_InputHash{'DELIVERJOBTITLE'};
undef $::g_InputHash{'DELIVERCOMPANY'};
undef $::g_InputHash{'DELIVERADDRESS1'};
undef $::g_InputHash{'DELIVERADDRESS2'};
undef $::g_InputHash{'DELIVERADDRESS3'};
undef $::g_InputHash{'DELIVERADDRESS4'};
undef $::g_InputHash{'DELIVERPOSTALCODE'};
undef $::g_InputHash{'DELIVERCOUNTRY'};
undef $::g_InputHash{'DELIVERPHONE'};
undef $::g_InputHash{'DELIVERMOBILE'};
undef $::g_InputHash{'DELIVERFAX'};
undef $::g_InputHash{'DELIVEREMAIL'};
undef $::g_InputHash{'DELIVERUSERDEFINED'};
}
return ($::SUCCESS, "", 0, 0);
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
@Response = ACTINIC::ReadPaymentFile($sPath);
if ($Response[0] != $::SUCCESS)
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
@Response = ACTINIC::ReadSSPSetupFile($sPath);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($Status, $Message) = ACTINIC::ReadDiscountBlob($sPath);
if ($Status != $::SUCCESS)
{
return ($Status, $Message);
}
my ($sContactDetails);
($::g_sCartId, $sContactDetails) = ACTINIC::GetCookies();;
if ($::g_InputHash{CARTID} &&
$::g_InputHash{CARTID} =~ /^[a-zA-Z0-9]+$/)
{
$::g_sCartId = $::g_InputHash{CARTID};
}
if ($::g_InputHash{CART} &&
$::g_InputHash{CART} =~ /^[a-zA-Z0-9]+$/)
{
$::g_sCartId = $::g_InputHash{CART};
}
my $sCallbackFlag;
if($::g_InputHash{"ACTION"} eq "OCC_VALIDATE" ||
($::g_InputHash{ACTION} =~ /^AUTHORIZE/i) ||
($::g_InputHash{ACTION} =~ /^OFFLINE_AUTHORIZE/i) ||
($::g_InputHash{"ACTION"} eq "RECORDORDER" && $$::g_pSetupBlob{USE_SHARED_SSL}))
{
$sCallbackFlag = $::TRUE;
}
else
{
$sCallbackFlag = $::FALSE;
}
$::Session = new Session($::g_sCartId, $sContactDetails, ACTINIC::GetPath(), $::FALSE, $sCallbackFlag);
if ($::g_bSpitSSLChange &&
$sContactDetails ne "")
{
$::Session->CookieStringToContactDetails();
}
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
$::g_sTaxDump = (join "|", keys %::g_TaxInfo) . (join "|", values %::g_TaxInfo);
$::g_sShippingDump = (join "|", keys %::g_ShipInfo) . (join "|", values %::g_ShipInfo);
return ($::SUCCESS, "", 0, 0);
}
sub ProcessInput
{
my (@Response, $sDetailCookie);
$::g_nCurrentSequenceNumber = $::g_InputHash{'SEQUENCE'};
if (!defined $::g_nCurrentSequenceNumber)
{
$::g_nCurrentSequenceNumber = $::STARTSEQUENCE;
}
my ($sConfirmButton, $sStartButton, $sDoneButton, $sNextButton, $sFinishButton, $sBackButton, $sCancelButton, $sChangeLocationButton);
$sConfirmButton = ACTINIC::GetPhrase(-1, 153);
$sStartButton = ACTINIC::GetPhrase(-1, 113);
$sDoneButton = ACTINIC::GetPhrase(-1, 114);
$sNextButton = ACTINIC::GetPhrase(-1, 502);
$sBackButton = ACTINIC::GetPhrase(-1, 503);
$sFinishButton = ACTINIC::GetPhrase(-1, 504);
$sCancelButton = ACTINIC::GetPhrase(-1, 505);
$sChangeLocationButton = ACTINIC::GetPhrase(0, 18);
my ($sHTML, $sAction, $eDirection);
$sAction = $::g_InputHash{'ACTION'};
if ($sAction =~ m/$sStartButton/i)
{
$::Session->SetCheckoutStarted();
}
elsif (!$::Session->IsCheckoutStarted())
{
@Response = ACTINIC::BounceToPageEnhanced(5, ACTINIC::GetPhrase(-1, 2300),
$$::g_pSetupBlob{CHECKOUT_DESCRIPTION},
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $::Session->GetLastShopPage(), \%::g_InputHash,
$::FALSE);
$sHTML = $Response[2];
goto THEEND;
}
if ($sAction eq "PPSTARTCHECKOUT")
{
IncludePaypalScript();
@Response = StartPaypalProCheckout();
if ($Response[0] == $::BADDATA)
{
$sHTML = $Response[1];
$sDetailCookie = $Response[2];
goto THEEND;
}
elsif ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
return;
}
$sHTML = $Response[1];
goto THEEND;
}
elsif ($sAction eq "PPCOMPLETECHECKOUT")
{
IncludePaypalScript();
CompletePaypalProCheckout();
exit;
}
elsif ($sAction eq $sConfirmButton)
{
IncludePaypalScript();
my $sError = ValidateOrderConfirmPhase();
if ($sError ne "")
{
$sHTML = DisplayOrderConfirmPhase($sError);
goto THEEND;
}
else
{
my $oPaypal = new ActinicPaypalConnection();
my $nAmount = ActinicOrder::GetOrderTotal();
my @Response = $oPaypal->DoExpressCheckoutPayment($nAmount);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
return;
}
@Response = RecordPaypalOrder($oPaypal);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
return;
}
$::g_nCurrentSequenceNumber = 3;
$sAction = $sNextButton;
}
}
if ($sAction eq "" &&
$::g_InputHash{ACTIONOVERRIDE})
{
$sAction = $::g_InputHash{ACTIONOVERRIDE};
}
elsif ($sAction =~ m/$sStartButton/i ||
$sAction =~ m/$sNextButton/i ||
$sAction =~ m/$sFinishButton/i ||
$sAction =~ m/^AUTHORIZE/i ||
$sAction =~ m/RECORDORDER/i ||
exists $::g_InputHash{$sNextButton . ".x"} ||
exists $::g_InputHash{$sFinishButton . ".x"})
{
$eDirection = $::FORWARD;
}
elsif ($sAction =~ m/$sBackButton/i ||
$sAction =~ m/$sChangeLocationButton/i ||
exists $::g_InputHash{$sBackButton . ".x"})
{
$eDirection = $::BACKWARD;
}
elsif ($sAction =~ m/$sDoneButton/i ||
exists $::g_InputHash{$sDoneButton . ".x"})
{
my $sRefPage = $::Session->GetLastShopPage();
if (defined $$::g_pSetupBlob{'UNFRAMED_CHECKOUT_URL'} &&
$$::g_pSetupBlob{'UNFRAMED_CHECKOUT_URL'} ne "")
{
$sRefPage = $$::g_pSetupBlob{'UNFRAMED_CHECKOUT_URL'};
}
if( !$ACTINIC::B2B->Get('UserDigest') )
{
if (defined $::g_InputHash{'ALTERNATEMALLHOME'})
{
$sRefPage = $::g_InputHash{'ALTERNATEMALLHOME'};
}
}
@Response = ACTINIC::BounceToPagePlain(0, undef, undef, $::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $sRefPage, \%::g_InputHash);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
return;
}
$sHTML = $Response[2];
if ($ACTINIC::B2B->Get('UserDigest'))
{
$sHTML =~ s/([\?|\&]ACTINIC_REFERRER[^\&|"|']*)//gi;
$sHTML =~ s/($::g_sAccountScriptName)(\&)/$1\?/gi;
}
goto THEEND;
}
elsif ($sAction =~ m/OCC_VALIDATE/i)
{
@Response = GetOCCValidationData();
if ($Response[0] != $::SUCCESS)
{
ACTINIC::RecordErrors($Response[1], ACTINIC::GetPath());
$sHTML = '0';
}
else
{
$sHTML = $Response[2];
}
ACTINIC::PrintText($sHTML);
return;
}
else
{
$sHTML = GetCancelPage();
goto THEEND;
}
@Response = ValidateInput($eDirection);
if ($Response[0] == $::BADDATA)
{
$sHTML = $Response[1];
$sDetailCookie = $Response[2];
goto THEEND;
}
elsif ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
return;
}
if($sAction =~ m/$sChangeLocationButton/i)
{
$::g_nCurrentSequenceNumber = $::STARTSEQUENCE;
$eDirection = $::FORWARD;
}
if ($eDirection == $::FORWARD)
{
$::g_nNextSequenceNumber = $::g_nCurrentSequenceNumber + 1;
}
else
{
$::g_nNextSequenceNumber = $::g_nCurrentSequenceNumber - 1;
}
ActinicOrder::ParseAdvancedTax();
@Response = DisplayPage("", $::g_nNextSequenceNumber, $eDirection);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
return;
}
$sHTML = $Response[2];
$sDetailCookie = $Response[3];
THEEND:
ACTINIC::UpdateDisplay($sHTML, $::g_OriginalInputData, undef, undef, $sDetailCookie, ActinicOrder::GenerateCartCookie());
}
sub ValidateInput
{
my ($eDirection);
if ($#_ != 0)
{
$eDirection = $::FORWARD;
}
($eDirection) = @_;
my ($bActuallyValidate) = ($eDirection == $::FORWARD);
my (@Response);
if ($::g_nCurrentSequenceNumber == $::STARTSEQUENCE)
{
@Response = ValidateStart($bActuallyValidate); # validate the input/cart settings
return (@Response);
}
else
{
my ($sPhaseList) = $$::g_pPhaseList{$::g_nCurrentSequenceNumber};
my (@Phases) = split (//, $sPhaseList);
my ($nPhase, $sError);
foreach $nPhase (@Phases)
{
if ($nPhase == $::BILLCONTACTPHASE)
{
$sError .= ValidateBill($bActuallyValidate);
}
elsif ($nPhase == $::SHIPCONTACTPHASE)
{
$sError .= ValidateShipContact($bActuallyValidate);
}
elsif ($nPhase == $::SHIPCHARGEPHASE)
{
$sError .= ValidateShipCharge($bActuallyValidate);
}
elsif ($nPhase == $::TAXCHARGEPHASE)
{
$sError .= ActinicOrder::ValidateTax($bActuallyValidate);
}
elsif ($nPhase == $::GENERALPHASE)
{
$sError .= ValidateGeneral($bActuallyValidate);
}
elsif ($nPhase == $::PAYMENTPHASE)
{
$sError .= ValidatePayment($bActuallyValidate);
}
elsif ($nPhase == $::COMPLETEPHASE)
{
if($::g_InputHash{'ACTION'} =~ m/^AUTHORIZE_(\d+)$/i)
{
$::g_PaymentInfo{'METHOD'} = $1;
}
if (!defined $::g_PaymentInfo{'METHOD'})
{
if ($$::g_pSetupBlob{USE_DH})
{
$sError .=  ACTINIC::GetPhrase(-1, 2040);
}
else
{
$sError .= ACTINIC::GetPhrase(-1, 1282);
}
next;
}
if (length $::g_PaymentInfo{'METHOD'} == 0)
{
EnsurePaymentSelection();
}
my ($ePaymentMethod) = ActinicOrder::PaymentStringToEnum($::g_PaymentInfo{'METHOD'}); # the payment method is stored as "ENUMERATEDID:DESCRIPTION"
if ($ACTINIC::B2B->Get('UserDigest') &&
($ePaymentMethod == $::PAYMENT_ON_ACCOUNT ||
$ePaymentMethod == $::PAYMENT_INVOICE))
{
$sError .= ValidateSignature($bActuallyValidate);
}
}
elsif ($nPhase == $::RECEIPTPHASE)
{
}
elsif ($nPhase == $::PRELIMINARYINFOPHASE)
{
$sError .= ActinicOrder::ValidatePreliminaryInfo($bActuallyValidate);
}
}
if ($sError ne '')
{
@Response = DisplayPage($sError, $::g_nCurrentSequenceNumber, $eDirection);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$Response[0] = $::BADDATA;
$Response[1] = $Response[2];
$Response[2] = $Response[3];
return (@Response);
}
}
return (UpdateCheckoutRecord());
}
sub ValidateStart
{
if ($#_ != 0)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'ValidateStart'), 0, 0);
}
my ($bActuallyValidate) = @_;
if (!$bActuallyValidate)
{
return ($::SUCCESS, "", 0, 0);
}
my ($nLineCount, @Response, $Status, $Message);
my $pCartObject;
@Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
$nLineCount = 0;
}
else
{
$pCartObject = $Response[2];
$nLineCount = $pCartObject->CountItems();
}
my ($sLocalPage, $sBaseUrl, $sHTML);
if ($nLineCount <= 0)
{
$sLocalPage = $::Session->GetLastShopPage();
if (ACTINIC::IsCatalogFramed() ||
($$::g_pSetupBlob{CLEAR_ALL_FRAMES} &&
$$::g_pSetupBlob{UNFRAMED_CHECKOUT}))
{
$sLocalPage = ACTINIC::RestoreFrameURL($sLocalPage);
}
@Response = ACTINIC::BounceToPageEnhanced(5, ACTINIC::GetPhrase(-1, 1962) . ACTINIC::GetPhrase(-1, 44, $::g_sCart, $::g_sCart) . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2049),
$$::g_pSetupBlob{CHECKOUT_DESCRIPTION},
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $sLocalPage, \%::g_InputHash,
$::FALSE);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
return ($::BADDATA, $sHTML, 0, 0);
}
my $pCartList = $pCartObject->GetCartList();
my $nIndex;
foreach ($nIndex = $#$pCartList; $nIndex >= 0; $nIndex--)
{
my $pFailure;
($Status, $Message, $pFailure) = ActinicOrder::ValidateOrderDetails($pCartList->[$nIndex], $nIndex);
if ($Status != $::SUCCESS)
{
my $sURL = $::g_sCartScript . "?ACTION=SHOWCART";
$sURL .= $::g_InputHash{SHOP} ? '&SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) : '';
@Response = ACTINIC::BounceToPageEnhanced(5, ACTINIC::GetPhrase(-1, 1962) . ACTINIC::GetPhrase(-1, 2167) . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2049),
$$::g_pSetupBlob{CHECKOUT_DESCRIPTION},
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $sURL , \%::g_InputHash,
$::FALSE);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
return ($::BADDATA, $sHTML, 0, 0);
}
}
($Status, $sHTML) = ActinicOrder::CheckBuyerLimit($::g_sCartId,'',$::TRUE);
if ($Status != $::SUCCESS)
{
return ($::BADDATA,$sHTML);
}
return ($::SUCCESS, "", 0, 0);
}
sub ValidateBill
{
if ($#_ != 0)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 12, 'ValidateBill'), ACTINIC::GetPath());
}
my ($bActuallyValidate) = @_;
my $sPreValidationError = "";
if( $::g_InputHash{ADBACTION} )
{
return('');
}
if( $::g_InputHash{ADDRESSSELECT} )
{
my $sUserDigest = $ACTINIC::B2B->Get('UserDigest');
my ($status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sUserDigest, ACTINIC::GetPath());
if ($status != $::SUCCESS)
{
return ($sMessage);
}
my $pAccount;
($status, $sMessage, $pAccount) = ACTINIC::GetCustomerAccount($$pBuyer{AccountID}, ACTINIC::GetPath());
if ($status != $::SUCCESS)
{
return ($sMessage);
}
my $pAddress;
($status, $sMessage, $pAddress) = ACTINIC::GetCustomerAddress($$pBuyer{AccountID}, $::g_InputHash{ADDRESSSELECT}, ACTINIC::GetPath());
ACTINIC::CloseCustomerAddressIndex();
if ($status != $::SUCCESS)
{
return ($sMessage);
}
if( $pBuyer->{InvoiceAddressRule} != 0 )
{
$::g_BillContact{'NAME'}		= $pBuyer->{'Name'};
$::g_BillContact{'FIRSTNAME'}	= $pBuyer->{'FirstName'};
$::g_BillContact{'LASTNAME'}	= $pBuyer->{'LastName'};
$::g_BillContact{'SALUTATION'}	= $pBuyer->{'Salutation'};
$::g_BillContact{'JOBTITLE'}	= $pBuyer->{'Title'};
}
else
{
$::g_BillContact{'NAME'}		= $pAccount->{'Name'};
$::g_BillContact{'FIRSTNAME'}	= $pAccount->{'FirstName'};
$::g_BillContact{'LASTNAME'}	= $pAccount->{'LastName'};
$::g_BillContact{'SALUTATION'}	= $pAccount->{'Salutation'};
$::g_BillContact{'JOBTITLE'}	= $pAccount->{'Title'};
}
$::g_BillContact{'PHONE'} 		= $pAccount->{'TelephoneNumber'};
$::g_BillContact{'MOBILE'} 		= $pAccount->{'MobileNumber'};
$::g_BillContact{'FAX'} 		= $pAccount->{'FaxNumber'};
if (length $::g_BillContact{'PHONE'} > $::g_pFieldSizes->{'PHONE'})
{
$::g_BillContact{'PHONE'}	=~ s/(.*?)(\/.*|$)/$1/;
}
$::g_BillContact{'PHONE'}		=~ s/(.{0,$::g_pFieldSizes->{'PHONE'}}).*/$1/;
$::g_BillContact{'MOBILE'}		=~ s/(.{0,$::g_pFieldSizes->{'MOBILE'}}).*/$1/;
$::g_BillContact{'FAX'}			=~ s/(.{0,$::g_pFieldSizes->{'FAX'}}).*/$1/;
$::g_BillContact{'EMAIL'} 		= $pAccount->{'EmailAddress'};
$::g_BillContact{'ADDRESS1'} 		= $pAddress->{'Line1'};
$::g_BillContact{'ADDRESS2'} 		= $pAddress->{'Line2'};
$::g_BillContact{'ADDRESS3'} 		= $pAddress->{'Line3'};
$::g_BillContact{'ADDRESS4'} 		= $pAddress->{'Line4'};
$::g_BillContact{'POSTALCODE'} 		= $pAddress->{'PostCode'};
$::g_BillContact{'COUNTRY'} 		= ACTINIC::GetCountryName($pAddress->{'CountryCode'});
$::g_BillContact{'SEPARATE'}		= $::TRUE;
if ($::g_LocationInfo{SEPARATESHIP} eq "" &&
$::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED &&
$::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $pAddress->{'CountryCode'})
{
$sPreValidationError = ACTINIC::GetPhrase(-1, 2298,
ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_COUNTRY_CODE}),
ACTINIC::GetCountryName($pAddress->{'CountryCode'}));
}
else
{
$::g_LocationInfo{INVOICE_COUNTRY_CODE} = $pAddress->{'CountryCode'};
if (!$::g_LocationInfo{SEPARATESHIP})
{
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} = $pAddress->{'CountryCode'};
}
}
ActinicOrder::ParseAdvancedTax();
if($$::g_pTaxSetupBlob{TAX_BY} == $::eTaxByInvoice)
{
if(defined $$::g_pTaxSetupBlob{TAX_1} &&
$$::g_pTaxSetupBlob{TAX_1}{ID} == $pAddress->{'Tax1ID'})
{
$::g_TaxInfo{'EXEMPT1'} = $pAddress->{'ExemptTax1'} ? 1 : 0;
$::g_TaxInfo{'EXEMPT1DATA'} = $pAddress->{'Tax1ExemptData'};
}
if(defined $$::g_pTaxSetupBlob{TAX_2} &&
$$::g_pTaxSetupBlob{TAX_2}{ID} == $pAddress->{'Tax2ID'})
{
$::g_TaxInfo{'EXEMPT2'} = $pAddress->{'ExemptTax2'} ? 1 : 0;
$::g_TaxInfo{'EXEMPT2DATA'} = $pAddress->{'Tax2ExemptData'};
}
}
$::g_BillContact{'MOVING'} 		= $::FALSE;
$::g_BillContact{'PRIVACY'} 		= $::TRUE;
$::g_BillContact{'REMEMBERME'}	= $::FALSE;
}
else
{
$::g_BillContact{'SALUTATION'} 	= $::g_InputHash{'INVOICESALUTATION'};
$::g_BillContact{'NAME'}		= $::g_InputHash{'INVOICENAME'};
$::g_BillContact{'FIRSTNAME'}	= $::g_InputHash{'INVOICEFIRSTNAME'};
$::g_BillContact{'LASTNAME'}	= $::g_InputHash{'INVOICELASTNAME'};
$::g_BillContact{'JOBTITLE'}	= $::g_InputHash{'INVOICEJOBTITLE'};
$::g_BillContact{'COMPANY'}		= $::g_InputHash{'INVOICECOMPANY'};
$::g_BillContact{'ADDRESS1'}	= $::g_InputHash{'INVOICEADDRESS1'};
$::g_BillContact{'ADDRESS2'}	= $::g_InputHash{'INVOICEADDRESS2'};
$::g_BillContact{'ADDRESS3'}	= $::g_InputHash{'INVOICEADDRESS3'};
$::g_BillContact{'ADDRESS4'}	= $::g_InputHash{'INVOICEADDRESS4'};
$::g_BillContact{'POSTALCODE'} 	= $::g_InputHash{'INVOICEPOSTALCODE'};
$::g_BillContact{'COUNTRY'}		= $::g_InputHash{'INVOICECOUNTRY'};
$::g_BillContact{'PHONE'}		= $::g_InputHash{'INVOICEPHONE'};
$::g_BillContact{'MOBILE'}		= $::g_InputHash{'INVOICEMOBILE'};
$::g_BillContact{'FAX'}			= $::g_InputHash{'INVOICEFAX'};
$::g_BillContact{'EMAIL'}		= $::g_InputHash{'INVOICEEMAIL'};
$::g_BillContact{'USERDEFINED'}	= $::g_InputHash{'INVOICEUSERDEFINED'};
$::g_BillContact{'MOVING'}		= ($::g_InputHash{'INVOICEMOVING'} ne "") ? $::TRUE : $::FALSE;
$::g_BillContact{'PRIVACY'}		= ($::g_InputHash{'INVOICEPRIVACY'} ne "") ? $::TRUE : $::FALSE;
$::g_BillContact{'SEPARATE'}	= ($::g_InputHash{'SEPARATESHIP'} ne "") ? $::TRUE : $::FALSE;
$::g_BillContact{'REMEMBERME'}	= (defined $::g_InputHash{'REMEMBERME'} && $::g_InputHash{'REMEMBERME'} ne "") ?
$::TRUE : $::FALSE;
}
if ($$::g_pSetupBlob{SHOPPER_NAME_HANDLING_MODE} eq 1)
{
$::g_BillContact{'NAME'}	=  $::g_BillContact{'FIRSTNAME'}.' '.$::g_BillContact{'LASTNAME'};
$::g_BillContact{'NAME'}	=~ s/(.{0,$::g_pFieldSizes->{'NAME'}}).*/$1/;
}
$::g_BillContact{'AGREEDTANDC'}	= (defined $::g_InputHash{'AGREETERMSCONDITIONS'} && $::g_InputHash{'AGREETERMSCONDITIONS'} ne "") ? $::TRUE : $::FALSE;
if (!ACTINIC::IsPromptRequired(0, 12) &&
(length $::g_BillContact{'EMAIL'} == 0) &&
ACTINIC::IsPromptRequired(1, 12) &&
!$::g_BillContact{'SEPARATE'})
{
$sPreValidationError .= ACTINIC::GetPhrase(-1, 2417);
}
if ((ACTINIC::IsPromptRequired(0, 12) ||
length $::g_BillContact{'EMAIL'} > 0)	&&
$::g_BillContact{'EMAIL'} !~ /\@/)
{
$sPreValidationError .= ACTINIC::GetPhrase(-1, 2378);
}
ACTINIC::TrimHashEntries(\%::g_BillContact);
my ($sError);
if (!$bActuallyValidate)
{
return ($sError);
}
$sError = $sPreValidationError;
my (@Response);
my $pMapping =
{
'SALUTATION' 	=> 0,
'NAME'			=> 1,
'JOBTITLE'		=> 2,
'COMPANY'		=> 3,
'ADDRESS1'		=> 4,
'ADDRESS2'		=> 5,
'ADDRESS3'		=> 6,
'ADDRESS4'		=> 7,
'POSTALCODE'	=> 8,
'COUNTRY'		=> 9,
'PHONE'			=> 10,
'FAX'			=> 11,
'EMAIL'			=> 12,
'FIRSTNAME'		=> 2464,
'LASTNAME'		=> 2465,
'MOBILE'		=> 2453,
};
if ($$::g_pSetupBlob{SHOPPER_NAME_HANDLING_MODE} eq 1) # first name/ last name handling
{
delete $pMapping->{'NAME'};
}
else
{
delete  $pMapping->{'FIRSTNAME'};
delete  $pMapping->{'LASTNAME'};
}
$sError .= CheckInputField(0, $pMapping, \%::g_BillContact);
if ($::g_InputHash{'COUPONCODE'} ne "" &&
$$::g_pDiscountBlob{'COUPON_ON_CHECKOUT'})
{
$::Session->GetCartObject();
$::g_PaymentInfo{'COUPONCODE'} = $::g_InputHash{'COUPONCODE'};
@Response = ActinicDiscounts::ValidateCoupon($::g_PaymentInfo{'COUPONCODE'});
if ($Response[0] == $::FAILURE)
{
$sError .= ACTINIC::GetPhrase(-1, 1971,  $::g_sRequiredColor) . $Response[1] . ACTINIC::GetPhrase(-1, 1970);
}
}
if ($$::g_pSetupBlob{'CHECKOUT_NEEDS_TERMS_AGREED'} &&
!$::g_BillContact{'AGREEDTANDC'})
{
$sError .= ACTINIC::GetPhrase(-1, 2385);
}
if (ACTINIC::IsPromptRequired(0, 14) &&
$::g_BillContact{'USERDEFINED'} eq "" &&
!$ACTINIC::B2B->Get('UserDigest'))
{
$sError .= ACTINIC::GetRequiredMessage(0, 14);
}
if (length $::g_BillContact{'USERDEFINED'} > $::g_pFieldSizes->{'USERDEFINED'})
{
$sError .= ACTINIC::GetLengthFailureMessage(0, 14, $::g_pFieldSizes->{'USERDEFINED'});
}
if($sError eq '')
{
$sError .= ActinicOrder::ValidatePreliminaryInfo($bActuallyValidate);
}
return ($sError);
}
sub ValidateShipContact
{
if ($#_ != 0)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 12, 'ValidateShipContact'), ACTINIC::GetPath());
}
my ($bActuallyValidate) = @_;
if ($::ACT_ADB)
{
ConfigureAddressBook();
$::ACT_ADB->ToForm();
$::s_VariableTable{$::VARPREFIX.'ADDRESSBOOK'}	= $::ACT_ADB->Show();
}
else
{
$::s_VariableTable{$::VARPREFIX.'ADDRESSBOOK'}	= "";
}
my $bCheckReversed = (defined $$::g_pSetupBlob{'REVERSE_ADDRESS_CHECK'} &&
$$::g_pSetupBlob{'REVERSE_ADDRESS_CHECK'});
if( $::g_InputHash{ADDRESSSELECT} )
{
my $sUserDigest = $ACTINIC::B2B->Get('UserDigest');
my ($status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sUserDigest, ACTINIC::GetPath());
if ($status != $::SUCCESS)
{
return ($sMessage);
}
my $pAccount;
($status, $sMessage, $pAccount) = ACTINIC::GetCustomerAccount($$pBuyer{AccountID}, ACTINIC::GetPath());
if ($status != $::SUCCESS)
{
return ($sMessage);
}
my $pAddress;
($status, $sMessage, $pAddress) = ACTINIC::GetCustomerAddress($$pBuyer{AccountID}, $::g_InputHash{ADDRESSSELECT}, ACTINIC::GetPath());
ACTINIC::CloseCustomerAddressIndex();
if ($status != $::SUCCESS)
{
return ($sMessage);
}
$::g_ShipContact{'COMPANY'}	= $pAccount->{AccountName};
$::g_ShipContact{'NAME'}		= $pBuyer->{Name};
$::g_ShipContact{'FIRSTNAME'}	= $pBuyer->{'FirstName'};
$::g_ShipContact{'LASTNAME'}	= $pBuyer->{'LastName'};
$::g_ShipContact{'SALUTATION'}	= $pBuyer->{Salutation};
$::g_ShipContact{'JOBTITLE'}	= $pBuyer->{Title};
$::g_ShipContact{'PHONE'} 		= $pBuyer->{'TelephoneNumber'};
$::g_ShipContact{'MOBILE'} 		= $pBuyer->{'MobileNumber'};
$::g_ShipContact{'FAX'} 		= $pBuyer->{'FaxNumber'};
if (length $::g_ShipContact{'PHONE'} > $::g_pFieldSizes->{'PHONE'})
{
$::g_ShipContact{'PHONE'}	=~ s/(.*?)(\/.*|$)/$1/;
}
$::g_ShipContact{'PHONE'}		=~ s/(.{0,$::g_pFieldSizes->{'PHONE'}}).*/$1/;
$::g_ShipContact{'MOBILE'}		=~ s/(.{0,$::g_pFieldSizes->{'MOBILE'}}).*/$1/;
$::g_ShipContact{'FAX'}			=~ s/(.{0,$::g_pFieldSizes->{'FAX'}}).*/$1/;
$::g_ShipContact{'EMAIL'} 		= $pBuyer->{'EmailAddress'};
$::g_ShipContact{'ADDRESS1'}	= $pAddress->{'Line1'};
$::g_ShipContact{'ADDRESS2'}	= $pAddress->{'Line2'};
$::g_ShipContact{'ADDRESS3'}	= $pAddress->{'Line3'};
$::g_ShipContact{'ADDRESS4'}	= $pAddress->{'Line4'};
$::g_ShipContact{'POSTALCODE'} 	= $pAddress->{'PostCode'};
$::g_ShipContact{'COUNTRY'} 	= ACTINIC::GetCountryName($pAddress->{'CountryCode'});
$::g_ShipContact{PRIVACY} 		  = $::TRUE;
}
else
{
if (((!$bCheckReversed && !$::g_BillContact{'SEPARATE'}) ||
($bCheckReversed && $::g_BillContact{'SEPARATE'})) )
{
$::g_ShipContact{'SALUTATION'} 	= $::g_BillContact{'SALUTATION'};
$::g_ShipContact{'NAME'}		= $::g_BillContact{'NAME'};
$::g_ShipContact{'FIRSTNAME'}	= $::g_BillContact{'FIRSTNAME'};
$::g_ShipContact{'LASTNAME'} 	= $::g_BillContact{'LASTNAME'};
$::g_ShipContact{'JOBTITLE'}	= $::g_BillContact{'JOBTITLE'};
$::g_ShipContact{'COMPANY'} 	= $::g_BillContact{'COMPANY'};
$::g_ShipContact{'ADDRESS1'}	= $::g_BillContact{'ADDRESS1'};
$::g_ShipContact{'ADDRESS2'}	= $::g_BillContact{'ADDRESS2'};
$::g_ShipContact{'ADDRESS3'}	= $::g_BillContact{'ADDRESS3'};
$::g_ShipContact{'ADDRESS4'}	= $::g_BillContact{'ADDRESS4'};
$::g_ShipContact{'POSTALCODE'} 	= $::g_BillContact{'POSTALCODE'};
$::g_ShipContact{'COUNTRY'} 	= $::g_BillContact{'COUNTRY'};
my $sUserDigest = $ACTINIC::B2B->Get('UserDigest');
if ($sUserDigest)
{
my ($status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sUserDigest, ACTINIC::GetPath());
if ($status != $::SUCCESS)
{
return ($sMessage);
}
$::g_ShipContact{'PHONE'} 		= $pBuyer->{'TelephoneNumber'};
$::g_ShipContact{'MOBILE'}	 	= $pBuyer->{'MobileNumber'};
$::g_ShipContact{'FAX'} 		= $pBuyer->{'FaxNumber'};
if (length $::g_ShipContact{'PHONE'} > $::g_pFieldSizes->{'PHONE'})
{
$::g_ShipContact{'PHONE'}	=~ s/(.*?)(\/.*|$)/$1/;
}
$::g_ShipContact{'PHONE'}		=~ s/(.{0,$::g_pFieldSizes->{'PHONE'}}).*/$1/;
$::g_ShipContact{'MOBILE'}		=~ s/(.{0,$::g_pFieldSizes->{'MOBILE'}}).*/$1/;
$::g_ShipContact{'EMAIL'} 		= $pBuyer->{'EmailAddress'};
}
else
{
$::g_ShipContact{'PHONE'} 		= $::g_BillContact{'PHONE'};
$::g_ShipContact{'MOBILE'} 		= $::g_BillContact{'MOBILE'};
$::g_ShipContact{'FAX'} 		= $::g_BillContact{'FAX'};
$::g_ShipContact{'EMAIL'} 		= $::g_BillContact{'EMAIL'};
}
$::g_ShipContact{'USERDEFINED'} 	= "";
}
else
{
$::g_ShipContact{'SALUTATION'}		= $::g_InputHash{'DELIVERSALUTATION'};
$::g_ShipContact{'NAME'} 			= $::g_InputHash{'DELIVERNAME'};
$::g_ShipContact{'FIRSTNAME'} 		= $::g_InputHash{'DELIVERFIRSTNAME'};
$::g_ShipContact{'LASTNAME'} 		= $::g_InputHash{'DELIVERLASTNAME'};
$::g_ShipContact{'JOBTITLE'}		= $::g_InputHash{'DELIVERJOBTITLE'};
$::g_ShipContact{'COMPANY'} 		= $::g_InputHash{'DELIVERCOMPANY'};
$::g_ShipContact{'ADDRESS1'}		= $::g_InputHash{'DELIVERADDRESS1'};
$::g_ShipContact{'ADDRESS2'}		= $::g_InputHash{'DELIVERADDRESS2'};
$::g_ShipContact{'ADDRESS3'}		= $::g_InputHash{'DELIVERADDRESS3'};
$::g_ShipContact{'ADDRESS4'}		= $::g_InputHash{'DELIVERADDRESS4'};
$::g_ShipContact{'POSTALCODE'} 		= $::g_InputHash{'DELIVERPOSTALCODE'};
$::g_ShipContact{'COUNTRY'} 		= $::g_InputHash{'DELIVERCOUNTRY'};
$::g_ShipContact{'PHONE'} 			= $::g_InputHash{'DELIVERPHONE'};
$::g_ShipContact{'MOBILE'} 			= $::g_InputHash{'DELIVERMOBILE'};
$::g_ShipContact{'FAX'} 			= $::g_InputHash{'DELIVERFAX'};
$::g_ShipContact{'EMAIL'} 			= $::g_InputHash{'DELIVEREMAIL'};
$::g_ShipContact{'USERDEFINED'} 	= $::g_InputHash{'DELIVERUSERDEFINED'};
}
$::g_ShipContact{'PRIVACY'} 			= $::g_BillContact{'PRIVACY'};
}
if ($$::g_pSetupBlob{SHOPPER_NAME_HANDLING_MODE} eq 1)
{
$::g_ShipContact{'NAME'} =  $::g_ShipContact{'FIRSTNAME'} .' '.	$::g_ShipContact{'LASTNAME'};
$::g_ShipContact{'NAME'} =~ s/(.{0,$::g_pFieldSizes->{'NAME'}}).*/$1/;
}
ACTINIC::TrimHashEntries(\%::g_ShipContact);
my ($sError);
if ((ACTINIC::IsPromptRequired(1, 12) ||
length $::g_ShipContact{'EMAIL'} > 0)	&&
$::g_ShipContact{'EMAIL'} !~ /\@/)
{
$sError.= ACTINIC::GetPhrase(-1, 2378);
}
if (!$bActuallyValidate ||
(!$bCheckReversed && !$::g_BillContact{'SEPARATE'}) ||
($bCheckReversed && $::g_BillContact{'SEPARATE'}))
{
return ($sError);
}
my $pMapping =
{
'SALUTATION' 	=> 0,
'NAME'			=> 1,
'FIRSTNAME'		=> 2451,
'LASTNAME'		=> 2452,
'JOBTITLE'		=> 2,
'COMPANY'		=> 3,
'ADDRESS1'		=> 4,
'ADDRESS2'		=> 5,
'ADDRESS3'		=> 6,
'ADDRESS4'		=> 7,
'POSTALCODE'	=> 8,
'COUNTRY'		=> 9,
'PHONE'			=> 10,
'MOBILE'		=> 2454,
'FAX'			=> 11,
'EMAIL'			=> 12,
};
if ($$::g_pSetupBlob{SHOPPER_NAME_HANDLING_MODE} eq 1)
{
delete  $pMapping->{'NAME'};
}
else
{
delete  $pMapping->{'FIRSTNAME'};
delete  $pMapping->{'LASTNAME'};
}
$sError .= CheckInputField(1, $pMapping, \%::g_ShipContact);
if (ACTINIC::IsPromptRequired(1, 13) &&
$::g_ShipContact{'USERDEFINED'} eq "" &&
!$ACTINIC::B2B->Get('UserDigest'))
{
$sError .= ACTINIC::GetRequiredMessage(1, 13);
}
if (length $::g_ShipContact{'USERDEFINED'} > $::g_pFieldSizes->{'USERDEFINED'})
{
$sError .= ACTINIC::GetLengthFailureMessage(1, 13, $::g_pFieldSizes->{'USERDEFINED'});
}
if($sError eq '')
{
$sError .= ActinicOrder::ValidatePreliminaryInfo($bActuallyValidate);
}
return ($sError);
}
sub CheckInputField
{
my ($nPhase, $pMapping, $pHash) = @_;
my ($sKey, $sError);
foreach $sKey (keys %{$pMapping})
{
if (ACTINIC::IsPromptRequired($nPhase, $pMapping->{$sKey}) &&
$$pHash{$sKey} eq "")
{
$sError .= ACTINIC::GetRequiredMessage($nPhase, $pMapping->{$sKey});
}
if (length $$pHash{$sKey} > $::g_pFieldSizes->{$sKey})
{
$sError .= ACTINIC::GetLengthFailureMessage($nPhase, $pMapping->{$sKey}, $::g_pFieldSizes->{$sKey});
}
}
return $sError;
}
sub ValidateShipCharge
{
if ($#_ != 0)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 12, 'ValidateShipCharge'), ACTINIC::GetPath());
}
my ($bActuallyValidate) = @_;
my ($sError);
if ($$::g_pSetupBlob{MAKE_SHIPPING_CHARGE} &&
!ActinicOrder::IsPhaseHidden($::SHIPCHARGEPHASE))
{
my @Response = ActinicOrder::CallShippingPlugIn();
if ($bActuallyValidate)
{
if ($Response[0] != $::SUCCESS)
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) .
ACTINIC::GetPhrase(-1, 102) . ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) . " - ". $Response[1] . "<BR>\n";
}
elsif (${$Response[2]}{ValidateFinalInput} != $::SUCCESS)
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) .
ACTINIC::GetPhrase(-1, 102) . ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) . " - ". ${$Response[3]}{ValidateFinalInput} . "<BR>\n";
}
}
}
$::g_ShipInfo{'USERDEFINED'}	= $::g_InputHash{'SHIPUSERDEFINED'};
ACTINIC::TrimHashEntries(\%::g_ShipInfo);
if (defined $::g_InputHash{'SHIPUSERDEFINED'})
{
if ($bActuallyValidate &&
ACTINIC::IsPromptRequired(2, 1) &&
$::g_ShipInfo{'USERDEFINED'} eq "")
{
$sError .= ACTINIC::GetRequiredMessage(2, 1);
}
if (length $::g_ShipInfo{'USERDEFINED'} > $::g_pFieldSizes->{'USERDEFINED'})
{
$sError .= ACTINIC::GetLengthFailureMessage(2, 1, $::g_pFieldSizes->{'USERDEFINED'});
}
if ($sError ne "")
{
$sError = ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 149) . ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1961, $sError);
}
}
return ($sError);
}
sub ValidateGeneral
{
if ($#_ != 0)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 12, 'ValidateGeneral'), ACTINIC::GetPath());
}
my ($bActuallyValidate) = @_;
$::g_GeneralInfo{'HOWFOUND'} 	= $::g_InputHash{'GENERALHOWFOUND'};
$::g_GeneralInfo{'WHYBUY'} 		= $::g_InputHash{'GENERALWHYBUY'};
$::g_GeneralInfo{'USERDEFINED'} = $::g_InputHash{'GENERALUSERDEFINED'};
ACTINIC::TrimHashEntries(\%::g_GeneralInfo);
my ($sError);
if (!$bActuallyValidate)
{
return ($sError);
}
my $pMapping =
{
'HOWFOUND' 		=> 0,
'WHYBUY'			=> 1,
'USERDEFINED'	=> 2,
};
$sError .= CheckInputField(4, $pMapping, \%::g_GeneralInfo);
if ($sError ne "")
{
$sError = ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 151) . ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1961, $sError);
}
return ($sError);
}
sub ValidatePayment
{
if ($#_ != 0)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 12, 'ValidatePayment'), ACTINIC::GetPath());
}
my ($bActuallyValidate) = @_;
$::g_PaymentInfo{'METHOD'}			= $::g_InputHash{'PAYMENTMETHOD'};
$::g_PaymentInfo{'USERDEFINED'}	= $::g_InputHash{'PAYMENTUSERDEFINED'};
$::g_PaymentInfo{'PONO'}			= $::g_InputHash{'PAYMENTPONO'};
$::g_PaymentInfo{'CARDTYPE'}		= $::g_InputHash{'PAYMENTCARDTYPE'};
$::g_PaymentInfo{'CARDNUMBER'}	= $::g_InputHash{'PAYMENTCARDNUMBER'};
$::g_PaymentInfo{'CARDISSUE'}		= $::g_InputHash{'PAYMENTCARDISSUE'};
$::g_PaymentInfo{'CARDVV2'}		= $::g_InputHash{'PAYMENTCARDVV2'};
$::g_PaymentInfo{'EXPMONTH'}		= $::g_InputHash{'PAYMENTEXPMONTH'};
$::g_PaymentInfo{'EXPYEAR'}		= $::g_InputHash{'PAYMENTEXPYEAR'};
$::g_PaymentInfo{'STARTMONTH'}	= $::g_InputHash{'PAYMENTSTARTMONTH'};
$::g_PaymentInfo{'STARTYEAR'}		= $::g_InputHash{'PAYMENTSTARTYEAR'};
ACTINIC::TrimHashEntries(\%::g_PaymentInfo);
my ($sError);
if (!$bActuallyValidate)
{
return ($sError);
}
my @Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response[1]);
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
my (@SummaryResponse) = $pCartObject->SummarizeOrder($::FALSE);
if (($SummaryResponse[6] == 0) ||
(!$$::g_pSetupBlob{'PRICES_DISPLAYED'}))
{
EnsurePaymentSelection();
}
else
{
if (0 == length $::g_PaymentInfo{'METHOD'})
{
return(ACTINIC::GetPhrase(-1, 55, ACTINIC::GetPhrase(-1, 152)));
}
my (@arrMethods, $nMethodID);
ActinicOrder::GenerateValidPayments(\@arrMethods);
my ($bFound) = $::FALSE;
foreach $nMethodID (@arrMethods)
{
if ($nMethodID == $::g_PaymentInfo{'METHOD'})
{
$bFound = $::TRUE;
last;
}
}
if (!$bFound)
{
return (ACTINIC::GetPhrase(-1, 2448, $::g_PaymentInfo{'METHOD'}));
}
}
my $pMapping =
{
'PONO' 			=> 6,
'USERDEFINED'	=> 7,
};
$sError .= CheckInputField(5, $pMapping, \%::g_PaymentInfo);
my ($ePaymentMethod) = ActinicOrder::PaymentStringToEnum($::g_PaymentInfo{'METHOD'}); # the payment method is stored as "ENUMERATEDID:DESCRIPTION"
if ($ePaymentMethod == $::PAYMENT_CREDIT_CARD &&
!$$::g_pSetupBlob{USE_SHARED_SSL} &&
!$$::g_pSetupBlob{USE_DH} )
{
if ($::g_PaymentInfo{'CARDTYPE'} eq "")
{
$sError .= ACTINIC::GetRequiredMessage(5, 1);
}
my ($nIndex, $sCCID, $bFound);
$bFound = $::FALSE;
for ($nIndex = 0; $nIndex < 12; $nIndex++)
{
$sCCID = sprintf('CC%d', $nIndex);
if ($$::g_pSetupBlob{$sCCID} eq
$::g_PaymentInfo{'CARDTYPE'})
{
$bFound = $::TRUE;
last;
}
}
if (!$bFound)
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(5, 1) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
ACTINIC::GetPhrase(-1, 107, $::g_PaymentInfo{'CARDTYPE'}) . "<BR>\n"
}
my ($nNumber) = $::g_PaymentInfo{'CARDNUMBER'};
$nNumber =~ s/\s//g;
$nNumber =~ s/-//g;
if ($nNumber eq "")
{
$sError .= ACTINIC::GetRequiredMessage(5, 2);
}
if ($nNumber =~ /[^0-9]/)
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(5, 2) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
ACTINIC::GetPhrase(-1, 108) . "<BR>\n"
}
my ($nCheckSum, $nDigitCount) = (0, 0);
my ($nDigit, $nCheck);
for($nIndex = (length $nNumber) - 1; $nIndex >= 0; $nIndex--)
{
$nDigit = substr($nNumber, $nIndex, 1);
$nCheck = (1 + $nDigitCount++ % 2) *
$nDigit;
if ( $nCheck >= 10)
{
$nCheck++;
}
$nCheckSum += $nCheck;
}
if (($nCheckSum % 10) != 0)
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(5, 2) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
ACTINIC::GetPhrase(-1, 109) . "<BR>\n"
}
if ($$::g_pSetupBlob{$sCCID . '_ISSUENUMBERFLAG'})
{
if ($::g_PaymentInfo{'CARDISSUE'} eq "" ||
$::g_PaymentInfo{'CARDISSUE'} < 0 ||
$::g_PaymentInfo{'CARDISSUE'} > 255)
{
$sError .= ACTINIC::GetPhrase(-1, 110, ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) .
ACTINIC::GetPhrase(5, 5) . ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970), $::g_PaymentInfo{'CARDTYPE'}) . "<BR>\n"
}
}
else
{
$::g_PaymentInfo{'CARDISSUE'} = "";
}
if ($$::g_pSetupBlob{$sCCID . '_CVV2FLAG'})
{
if (length $::g_PaymentInfo{'CARDVV2'} != $$::g_pSetupBlob{$sCCID . '_CVV2DIGITS'})
{
$sError .= ACTINIC::GetPhrase(-1, 560) . "<BR>\n"
}
}
else
{
$::g_PaymentInfo{'CARDVV2'} = "";
}
my @listCurrentTime = localtime(time);
my $nMonth = $listCurrentTime[$::TIME_MONTH];
my $nYear = $listCurrentTime[$::TIME_YEAR];
$nMonth++;
$nYear += 1900;
if ($$::g_pSetupBlob{$sCCID . '_STARTDATEFLAG'})
{
if (($::g_PaymentInfo{'STARTMONTH'} !~ /^\d{2}$/) ||
($::g_PaymentInfo{'STARTYEAR'} !~ /^\d{4}$/))
{
$sError .= ACTINIC::GetRequiredMessage(5, 3);
$::g_PaymentInfo{'STARTMONTH'} = "";
$::g_PaymentInfo{'STARTYEAR'} = "";
}
if ($::g_PaymentInfo{'STARTYEAR'} == $nYear &&
$::g_PaymentInfo{'STARTMONTH'} > $nMonth)
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(5, 3) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
ACTINIC::GetPhrase(-1, 111) . "<BR>\n"
}
}
else
{
$::g_PaymentInfo{'STARTMONTH'} = "";
$::g_PaymentInfo{'STARTYEAR'} = "";
}
if (($::g_PaymentInfo{'EXPMONTH'} !~ /^\d{2}$/) ||
($::g_PaymentInfo{'EXPYEAR'} !~ /^\d{4}$/))
{
$sError .= ACTINIC::GetRequiredMessage(5, 4);
$::g_PaymentInfo{'EXPMONTH'} = "";
$::g_PaymentInfo{'EXPYEAR'} = "";
}
if ($::g_PaymentInfo{'EXPYEAR'} == $nYear &&
$::g_PaymentInfo{'EXPMONTH'} < $nMonth)
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(5, 4) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
ACTINIC::GetPhrase(-1, 112) . "<BR>\n"
}
if ($$::g_pSetupBlob{$sCCID . '_STARTDATEFLAG'})
{
if ($::g_PaymentInfo{'EXPYEAR'} < $::g_PaymentInfo{'STARTYEAR'} ||
($::g_PaymentInfo{'EXPYEAR'} == $::g_PaymentInfo{'STARTYEAR'} &&
$::g_PaymentInfo{'EXPMONTH'} <= $::g_PaymentInfo{'STARTMONTH'}))
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(5, 4) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
ACTINIC::GetPhrase(-1, 561) . "<BR>\n"
}
}
}
else
{
$::g_PaymentInfo{'CARDTYPE'}		= "";
$::g_PaymentInfo{'CARDNUMBER'}	= "";
$::g_PaymentInfo{'CARDISSUE'}		= "";
$::g_PaymentInfo{'CARDVV2'}		= "";
$::g_PaymentInfo{'EXPMONTH'}		= "";
$::g_PaymentInfo{'EXPYEAR'}		= "";
$::g_PaymentInfo{'STARTMONTH'}	= "";
$::g_PaymentInfo{'STARTYEAR'}		= "";
}
if ($sError ne "")
{
$sError = ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 152) . ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1961, $sError);
}
return ($sError);
}
sub ValidateSignature
{
$::g_sSignature = $::g_InputHash{SIGNATURE};
if ($::g_sSignature ne '')
{
$::g_sSignature =~ /^([a-fA-F0-9]{32})$/;
$::g_sSignature = $1;
}
return (undef);
}
sub DisplayPage
{
if ($#_ != 2)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'DisplayPage'), 0, 0);
}
my (%VariableTable, $sDetailCookie);
my ($sError, $nPageNumber, $eDirection) = @_;
my (@Response, $sPath);
$sPath = ACTINIC::GetPath();
my ($pCartList);
my $sMessage;
my $bReDisplayReceipt = $::FALSE;
if($::g_InputHash{'ACTION'} !~ m/^AUTHORIZE_(\d+)$/i)
{
@Response = $::Session->GetCartObject();
if ($Response[0] == $::EOF)
{
if ($::g_InputHash{'ACTION'} =~ m/RECORDORDER/i)
{
if ($$::g_pSetupBlob{USE_DH})
{
ACTINIC::PrintText("0" . ACTINIC::GetPhrase(-1, 2040));
}
else
{
ACTINIC::PrintText("0" . ACTINIC::GetPhrase(-1, 1282));
}
exit;
}
my ($sPhaseList) = $$::g_pPhaseList{$nPageNumber};
my (@Phases) = split (//, $sPhaseList);
if (($nPageNumber == 3 && $Phases[0] == $::COMPLETEPHASE) ||
($nPageNumber == 4 && $Phases[0] == $::RECEIPTPHASE))
{
@Response = $::Session->RestoreCheckoutInfo();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($Status, $Message, $pBillContact, $pShipContact, $pShipInfo, $pTaxInfo, $pGeneralInfo, $pPaymentInfo, $pLocationInfo) = @Response;
%::g_BillContact = %$pBillContact;
%::g_ShipContact = %$pShipContact;
%::g_ShipInfo		= %$pShipInfo;
%::g_TaxInfo		= %$pTaxInfo;
%::g_GeneralInfo = %$pGeneralInfo;
%::g_PaymentInfo = %$pPaymentInfo;
%::g_LocationInfo = %$pLocationInfo;
@Response = $::Session->GetCartObject($::TRUE);
if ($Response[0] == $::SUCCESS)
{
$bReDisplayReceipt = $::TRUE;
}
}
if (!$bReDisplayReceipt)
{
@Response = ACTINIC::BounceToPageEnhanced(7, ACTINIC::GetPhrase(-1, 1282),
$$::g_pSetupBlob{CHECKOUT_DESCRIPTION},
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob,
$::Session->GetLastShopPage(),
\%::g_InputHash,
$::FALSE);
return (@Response);
}
}
my $pCartObject = $Response[2];
$pCartList = $pCartObject->GetCartList();
my $nLineCount = CountValidCartItems($pCartList);
if ($nLineCount != scalar @$pCartList &&
$::g_bFirstError)
{
$::g_bFirstError = $::FALSE;
$sMessage = "<P>" . ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(-1, 175) . ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970);
return(DisplayPage($sMessage, $::g_nCurrentSequenceNumber, $eDirection));
}
}
my (@DeleteDelimiters, @KeepDelimiters, $nInc, $status);
my ($pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $nKeyCount, $pSelectTable);
if ($bReDisplayReceipt)
{
($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters) = DisplayReceiptPhase($::g_PaymentInfo{'ORDERNUMBER'}, $::g_PaymentInfo{METHOD}, $bReDisplayReceipt);
$nPageNumber = 4;
}
else
{
$nInc = ($eDirection == $::FORWARD) ? 1 : -1;
$nKeyCount = 0;
while ($nKeyCount == 0 &&
$nPageNumber >= 0)
{
my $sTempCookie;
($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable, $sTempCookie) =
ProcessPage($nPageNumber);
$sDetailCookie .= $sTempCookie;
if ($status != $::SUCCESS)
{
if ($::g_bFirstError)
{
$::g_bFirstError = $::FALSE;
$sMessage = "<P>" . ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . $sMessage . ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970);
return(DisplayPage($sMessage, $::g_nCurrentSequenceNumber, $eDirection));
}
else
{
return($status, $sMessage, 0, undef);
}
}
$nKeyCount = (keys %$pVarTable) + (keys %$pSelectTable);
$nPageNumber += $nInc;
}
$nPageNumber -= $nInc;
if ($nKeyCount == 0)
{
if (length $sError > 0)
{
my ($sRefPage) = $::Session->GetLastShopPage();
if ($$::g_pSetupBlob{UNFRAMED_CHECKOUT} &&
$$::g_pSetupBlob{UNFRAMED_CHECKOUT_URL})
{
$sRefPage = $$::g_pSetupBlob{UNFRAMED_CHECKOUT_URL};
}
my @Response = ACTINIC::BounceToPageEnhanced(-1, $sError, ACTINIC::GetPhrase(-1, 25),
$::g_sWebSiteUrl, $::g_sContentUrl, $::g_pSetupBlob, $sRefPage, \%::g_InputHash);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($sError, ACTINIC::GetPath());
}
return ($::SUCCESS, '', $Response[2], undef);
}
else
{
return ($::SUCCESS, "", GetCancelPage(), undef);
}
}
}
my (@a1, @a2);
@a1 = %VariableTable;
@a2 = %$pVarTable;
push (@a1, @a2);
%VariableTable = @a1;
@DeleteDelimiters = @$pDeleteDelimiters;
@KeepDelimiters = @$pKeepDelimiters;
if (length $VariableTable{$::VARPREFIX.'ERROR'})
{
$sError .= ' ' . $VariableTable{$::VARPREFIX.'ERROR'};
}
$sError = ACTINIC::GroomError($sError);
$VariableTable{$::VARPREFIX.'ERROR'} = $sError;
$VariableTable{$::VARPREFIX.'SEQUENCE'} = $nPageNumber;
my ($sFileName);
$sFileName = sprintf('order%2.2d.html', $nPageNumber);
if ($::g_sOverrideCheckoutFileName)
{
$sFileName = $::g_sOverrideCheckoutFileName;
}
@Response = ActinicOrder::GenerateShoppingCartLines($pCartList, $::FALSE, [], $sFileName);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::TemplateFile($sPath.$sFileName, \%VariableTable);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($sDigest,$sBaseFile) = ACTINIC::CaccGetCookies();
$sPath = ($sBaseFile) ? $sBaseFile : $::g_sContentUrl;
@Response = ACTINIC::MakeLinksAbsolute($Response[2], $::g_sWebSiteUrl, $sPath);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($sHTML) = $Response[2];
my ($sDelimiter);
foreach $sDelimiter (@DeleteDelimiters)
{
$sHTML =~ s/$::DELPREFIX$sDelimiter(.*?)$::DELPREFIX$sDelimiter//gs;
}
foreach $sDelimiter (@KeepDelimiters)
{
$sHTML =~ s/$::DELPREFIX$sDelimiter//gs;
}
my ($sSelectName, $sDefaultOption);
while ( ($sSelectName, $sDefaultOption) = each %$pSelectTable)
{
$sHTML =~ s/(<\s*SELECT[^>]+?NAME\s*=\s*("|')?$sSelectName.+?)<OPTION\s+VALUE\s*=\s*("|')?$sDefaultOption("|')?\s*>/$1<OPTION SELECTED VALUE="$sDefaultOption">/is;
if ($1 eq "")
{
$sDefaultOption = "---";
$sHTML =~ s/(<\s*SELECT[^>]+?NAME\s*=\s*("|')?$sSelectName.+?)<OPTION\s+VALUE\s*=\s*("|')?$sDefaultOption("|')?\s*>/$1<OPTION SELECTED VALUE="$sDefaultOption">/is;
}
}
return ($::SUCCESS, "", $sHTML, $sDetailCookie);
}
sub ProcessPage
{
if ($#_ != 0)
{
return($::SUCCESS, ACTINIC::GetPhrase(-1, 12, 'ProcessPage'), undef, undef, undef, undef, undef);
}
my ($nPageNumber) = $_[0];
my @scratch = keys %$::g_pPhaseList;
my $nPhaseCount = $#scratch - 1;
my $sDetailCookie;
if ($nPageNumber > $nPhaseCount)
{
return($::SUCCESS, ACTINIC::GetPhrase(-1, 146, $nPageNumber, $nPhaseCount), undef, undef, undef, undef, $sDetailCookie);
}
undef %::s_LargeVariableTable;
@::s_LargeDeleteDelimiters = ();
@::s_LargeKeepDelimiters = ();
undef %::s_LargeSelectTable;
my ($sPhaseList) = $$::g_pPhaseList{$nPageNumber};
my ($pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable);
my (@Phases) = split (//, $sPhaseList);
my ($nPhase, $status, $sMessage);
foreach $nPhase (@Phases)
{
if ($nPhase == $::BILLCONTACTPHASE)
{
($pVarTable, $pDeleteDelimiters, $pKeepDelimiters) = DisplayBillContactPhase();
}
elsif ($nPhase == $::SHIPCONTACTPHASE)
{
($pVarTable, $pDeleteDelimiters, $pKeepDelimiters) = DisplayShipContactPhase();
}
elsif ($nPhase == $::SHIPCHARGEPHASE)
{
($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters) =
ActinicOrder::DisplayShipChargePhase();
if ($status != $::SUCCESS)
{
my $sDeliveryCountry = ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_COUNTRY_CODE});
if ($::g_BillContact{COUNTRY} eq $sDeliveryCountry &&
!$$::g_pLocationList{EXPECT_INVOICE})
{
undef $::g_BillContact{COUNTRY};
}
if ($::g_ShipContact{COUNTRY} eq $sDeliveryCountry)
{
undef $::g_ShipContact{COUNTRY};
}
return ($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable, $sDetailCookie);
}
UpdateCheckoutRecord();
}
elsif ($nPhase == $::TAXCHARGEPHASE)
{
($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters) = ActinicOrder::DisplayTaxPhase();
if ($status != $::SUCCESS)
{
my $sInvoiceCountry = ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_COUNTRY_CODE});
if ($::g_BillContact{COUNTRY} eq $sInvoiceCountry)
{
undef $::g_BillContact{COUNTRY};
}
if ($::g_ShipContact{COUNTRY} eq $sInvoiceCountry &&
!$$::g_pLocationList{EXPECT_DELIVERY})
{
undef $::g_ShipContact{COUNTRY};
}
my $sDeliveryCountry = ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_COUNTRY_CODE});
if ($::g_BillContact{COUNTRY} eq $sDeliveryCountry &&
!$$::g_pLocationList{EXPECT_INVOICE})
{
undef $::g_BillContact{COUNTRY};
}
if ($::g_ShipContact{COUNTRY} eq $sDeliveryCountry)
{
undef $::g_ShipContact{COUNTRY};
}
return ($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable, $sDetailCookie);
}
UpdateCheckoutRecord();
}
elsif ($nPhase == $::GENERALPHASE)
{
($pVarTable, $pDeleteDelimiters, $pKeepDelimiters) = ActinicOrder::DisplayGeneralPhase();
}
elsif ($nPhase == $::PAYMENTPHASE)
{
($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters) = DisplayPaymentPhase();
if ($status != $::SUCCESS)
{
return ($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable, $sDetailCookie);
}
}
elsif ($nPhase == $::COMPLETEPHASE)
{
if (length $::g_PaymentInfo{'METHOD'} == 0)
{
EnsurePaymentSelection();
}
my @Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
my (@SummaryResponse) = $pCartObject->SummarizeOrder($::FALSE);
my ($ePaymentMethod);
if ($SummaryResponse[6] == 0)
{
$ePaymentMethod = -1;
}
else
{
$ePaymentMethod= ActinicOrder::PaymentStringToEnum($::g_PaymentInfo{'METHOD'}); # the payment method is stored as "ENUMERATEDID:DESCRIPTION"
}
if ($ePaymentMethod == $::PAYMENT_CREDIT_CARD &&
$$::g_pSetupBlob{USE_DH})
{
($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters) = DisplayPageWithOrderDetails($::eApplet);
if ($status != $::SUCCESS)
{
return ($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable, $sDetailCookie);
}
}
elsif ($$::g_pPaymentList{$ePaymentMethod}{PAYMENT_TYPE})
{
my (@Response) = CallOCCPlugIn();
if ($Response[0] == $::ACCEPTED)
{
@Response = CompleteOrder();
if ($Response[0] != $::SUCCESS)
{
return(@Response);
}
undef %::s_VariableTable;
undef @::s_DeleteDelimiters;
undef @::s_KeepDelimiters;
($pVarTable, $pDeleteDelimiters, $pKeepDelimiters) =
(\%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
elsif ($Response[0] == $::PENDING)
{
my ($sHTML) = $Response[2];
@Response = CompleteOrder();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
ACTINIC::SaveSessionAndPrintPage($sHTML, undef, $::FALSE);
exit;
}
elsif ($Response[0] == $::REJECTED)
{
ACTINIC::SaveSessionAndPrintPage($Response[2], undef, $::FALSE);
exit;
}
else
{
return (@Response);
}
}
elsif ($ePaymentMethod == $::PAYMENT_CREDIT_CARD &&
$$::g_pSetupBlob{USE_SHARED_SSL})
{
($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters) = DisplayPageWithOrderDetails($::eSharedSSL);
if ($status != $::SUCCESS)
{
return ($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable, $sDetailCookie);
}
my @Response = ACTINIC::TemplateFile(ACTINIC::GetPath() . 'sharedssllink.html', $pVarTable);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($sDigest,$sBaseFile) = ACTINIC::CaccGetCookies();
my $sPath = ($sBaseFile) ? $sBaseFile : $::g_sContentUrl;
@Response = ACTINIC::MakeLinksAbsolute($Response[2], $::g_sWebSiteUrl, $sPath);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($sHTML) = $Response[2];
my ($sDelimiter);
foreach $sDelimiter (@$pDeleteDelimiters)
{
$sHTML =~ s/$::DELPREFIX$sDelimiter(.*?)$::DELPREFIX$sDelimiter//gs;
}
foreach $sDelimiter (@$pKeepDelimiters)
{
$sHTML =~ s/$::DELPREFIX$sDelimiter//gs;
}
ACTINIC::SaveSessionAndPrintPage($sHTML, undef, $::FALSE);
exit;
}
elsif ($ACTINIC::B2B->Get('UserDigest') &&
($ePaymentMethod == $::PAYMENT_ON_ACCOUNT ||
$ePaymentMethod == $::PAYMENT_INVOICE))
{
my ($Status, $Message, @Response);
@Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
my (@SummaryResponse, $nTotal);
@SummaryResponse = $pCartObject->SummarizeOrder($::FALSE);
if ($SummaryResponse[0] != $::SUCCESS)
{
return (@SummaryResponse);
}
$nTotal = $SummaryResponse[6];
my $sVitalOrderDetails =
$::g_BillContact{NAME} .
$::g_BillContact{FIRSTNAME} .
$::g_BillContact{LASTNAME} .
$::g_BillContact{COMPANY} .
$::g_BillContact{ADDRESS1} .
$::g_BillContact{ADDRESS2} .
$::g_BillContact{ADDRESS3} .
$::g_BillContact{ADDRESS4} .
$::g_BillContact{POSTALCODE} .
$::g_BillContact{COUNTRY} .
$::g_BillContact{PHONE} .
$::g_BillContact{MOBILE} .
$::g_BillContact{EMAIL} .
$::g_ShipContact{NAME} .
$::g_ShipContact{FIRSTNAME} .
$::g_ShipContact{LASTNAME} .
$::g_ShipContact{COMPANY} .
$::g_ShipContact{ADDRESS1} .
$::g_ShipContact{ADDRESS2} .
$::g_ShipContact{ADDRESS3} .
$::g_ShipContact{ADDRESS4} .
$::g_ShipContact{POSTALCODE} .
$::g_ShipContact{COUNTRY} .
$::g_ShipContact{PHONE} .
$::g_ShipContact{MOBILE} .
$::g_ShipContact{EMAIL} .
$nTotal;
my $pCartItem;
foreach $pCartItem (@$pCartList)
{
$sVitalOrderDetails .= $pCartItem->{PRODUCT_REFERENCE} . $pCartItem->{QUANTITY};
my ($sSectionBlobName);
($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($pCartItem->{SID});
if ($Status == $::FAILURE)
{
return ($Status, $Message);
}
@Response = ACTINIC::GetProduct($pCartItem->{PRODUCT_REFERENCE},  $sSectionBlobName,
ACTINIC::GetPath());
my $pProduct;
($Status, $Message, $pProduct) = @Response;
if ($Status == $::NOTFOUND)
{
next;
}
if ($Status != $::SUCCESS)
{
return (@Response);
}
my $VariantList;
if( $pProduct->{COMPONENTS} )
{
my $sKey;
foreach $sKey (keys %$pCartItem)
{
if( $sKey =~ /^COMPONENT\_/ )
{
$VariantList->[$'] = $pCartItem->{$sKey};
}
}
}
my %Component;
my $pComponent;
foreach $pComponent (@{$pProduct->{COMPONENTS}})
{
@Response = ActinicOrder::FindComponent($pComponent,$VariantList);
($Status, %Component) = @Response;
if ($Status == $::SUCCESS and $Component{quantity} > 0 )
{
my $sProdName;
if( !$pComponent->[0] &&
$Component{text} )
{
$Component{quantity} = 0; # Quantity=0 for attributes
}
$sVitalOrderDetails .= $Component{code} . ($pCartItem->{QUANTITY} * $Component{quantity});
}
}
}
eval
{
require Digest::MD5;
import Digest::MD5 'md5_hex';
};
if ($@)
{
require di000001;
import Digest::Perl::MD5 'md5_hex';
}
my $sMD5Vitals = md5_hex($sVitalOrderDetails);
my $sUser = $ACTINIC::B2B->Get('UserName');
my $sMD5User = md5_hex($ACTINIC::B2B->Get('UserName') . $ACTINIC::B2B->Get('UserDigest'));
undef %::s_VariableTable;
undef @::s_DeleteDelimiters;
undef @::s_KeepDelimiters;
$::s_VariableTable{$::VARPREFIX.'USER'} = $sUser;
$::s_VariableTable{$::VARPREFIX.'VITAL'} = $sMD5Vitals;
$::s_VariableTable{$::VARPREFIX.'ID'} = $sMD5User;
($pVarTable, $pDeleteDelimiters, $pKeepDelimiters) =
(\%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
$::g_sOverrideCheckoutFileName = 'signature.html';
}
else
{
if ($ePaymentMethod == $::PAYMENT_CREDIT_CARD &&
defined $$::g_pPaymentList{$::PAYMENT_PAYPAL_PRO})
{
EvaluatePaypalPro();
my $oPaypal = new ActinicPaypalConnection();
my $nAmount = ActinicOrder::GetOrderTotal();
my @Response = $oPaypal->DoDirectPayment(
$nAmount,
$$::g_pCatalogBlob{'SINTLSYMBOLS'},
$::g_PaymentInfo{'CARDNUMBER'},
$::g_PaymentInfo{'CARDVV2'},
$::g_PaymentInfo{'CARDISSUE'},
$::g_PaymentInfo{'STARTYEAR'},
$::g_PaymentInfo{'STARTMONTH'},
$::g_PaymentInfo{'EXPYEAR'},
$::g_PaymentInfo{'EXPMONTH'},
GetPPAddressDetails()
);
if ($Response[0] != $::SUCCESS)
{
return ($Response[0], ACTINIC::GetPhrase(-1, 2450, $Response[1]), $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable, $sDetailCookie);
}
@Response = RecordPaypalOrder($oPaypal);
if ($Response[0] != $::SUCCESS)
{
return ($Response[0], $Response[1], $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable, $sDetailCookie);
}
}
else
{
my (@Response) = CompleteOrder();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
}
undef %::s_VariableTable;
undef @::s_DeleteDelimiters;
undef @::s_KeepDelimiters;
($pVarTable, $pDeleteDelimiters, $pKeepDelimiters) =
(\%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
$::Session->PaymentMade();
}
}
elsif ($nPhase == $::RECEIPTPHASE)
{
my ($ePaymentMethod);
if($::g_InputHash{'ACTION'} =~ m/^AUTHORIZE_(\d+)$/i)
{
$ePaymentMethod = $1; # the : is to help parsing
}
elsif (length $::g_PaymentInfo{METHOD} == 0)
{
$ePaymentMethod = $::PAYMENT_CREDIT_CARD; # the : is to help parsing
}
else
{
($ePaymentMethod) = ActinicOrder::PaymentStringToEnum($::g_PaymentInfo{METHOD}); # the payment method is stored as "ENUMERATEDID:DESCRIPTION"
}
if ($ACTINIC::B2B->Get('UserDigest') &&
($ePaymentMethod == $::PAYMENT_ON_ACCOUNT ||
$ePaymentMethod == $::PAYMENT_INVOICE))
{
my (@Response) = CompleteOrder();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
}
if ($$::g_pPaymentList{$ePaymentMethod}{PAYMENT_TYPE} &&
$::g_InputHash{'ACTION'} =~ m/^AUTHORIZE/i)
{
LogData("AUTHORIZE:\n$::g_OriginalInputData");
if (defined $::g_InputHash{'ACT_POSTPROCESS'})
{
my ($sFilename, $pPaymentMethodHash);
$pPaymentMethodHash = $$::g_pPaymentList{$ePaymentMethod};
$sFilename = $$pPaymentMethodHash{POST_PROCESS};
my (@Response) = CallPlugInScript($sFilename);
my $sText = "1";
if ($Response[0] != $::SUCCESS)
{
$sText = "0" . ACTINIC::GetPhrase(-1, 1964);
}
else
{
my $sMailFile;
$sMailFile = $::Session->GetSessionFileFolder() . $::g_InputHash{ON} . ".mail";
if (-e $sMailFile &&
(($ePaymentMethod == $::PAYMENT_PAYPAL) ||
($ePaymentMethod == $::PAYMENT_NOCHEX)))
{
if (open (MFILE, "<$sMailFile"))
{
my $sRecipients = <MFILE>;
chomp($sRecipients);
my $sSubject = <MFILE>;
my $sMailBody;
chomp($sSubject);
{
local $/;
$sMailBody = <MFILE>;
}
close MFILE;
my @lRecipientlist = split(/,/, $sRecipients);
my $sRecipient;
foreach $sRecipient (@lRecipientlist)
{
$sRecipient =~ s/\s*//;
if (length $sRecipient == 0)
{
next;
}
my ($Status, $Message) = ACTINIC::SendMail($::g_sSmtpServer,
$sRecipient,
$sSubject,
$sMailBody,
$$::g_pSetupBlob{EMAIL});
if($Status != $::SUCCESS)
{
LogData("SendMail error:\n$Message");
ACTINIC::RecordErrors("SendMail error:\n$Message", ACTINIC::GetPath());
}
}
unlink $sMailFile;
}
else
{
LogData("SendMail error:\n" . ACTINIC::GetPhrase(-1, 21, $sMailFile, $!));
}
}
}
$::g_PaymentInfo{'AUTHORIZERESULT'} = $sText;
LogData("AUTHORIZERESULT:\n$sText");
}
else
{
my $sText;
LogData ("RecordAuthorization:\n");
my $sError = RecordAuthorization();
if (length $sError != 0)
{
ACTINIC::RecordErrors($sError, ACTINIC::GetPath());
$sText = "0" . ACTINIC::GetPhrase(-1, 1964);
}
else
{
$sText = "1";
}
$::g_PaymentInfo{'AUTHORIZERESULT'} = $sText;
ACTINIC::PrintText($sText);
}
my ($UpdateStatus, $UpdateMsg) = UpdateCheckoutRecord();
LogData ("processing is complete: $UpdateStatus, $UpdateMsg\n");
exit;
}
elsif (($ePaymentMethod == $::PAYMENT_CREDIT_CARD ||
$ePaymentMethod == $::PAYMENT_PAYPAL_PRO) &&
$::g_InputHash{'ACTION'} =~ m/RECORDORDER/i &&
defined $::g_InputHash{BLOB})
{
my $sText;
my $nOrderLength = length $::g_InputHash{BLOB};
if ($nOrderLength > 1024 * 250)
{
$sText = "0" . ACTINIC::GetPhrase(-1, 300);
}
else
{
my $sError = RecordOrder($::g_InputHash{ORDERNUMBER}, \$::g_InputHash{BLOB}, $::TRUE);
if (length $sError != 0)
{
my $bOmitMailDump = $::FALSE;
my $sErrorMessage = $sError;
if($sError =~ /^000/)
{
$bOmitMailDump = $::TRUE;
$sErrorMessage =~ s/^0+//;
}
NotifyOfError($sErrorMessage, $bOmitMailDump);
ACTINIC::RecordErrors($sErrorMessage, ACTINIC::GetPath()); # record the error to error.err
$sText = "0" . $sError;
}
else
{
$sText = "1";
$::Session->PaymentMade();
$::Session->SaveSession();
}
}
ACTINIC::PrintText($sText);
exit;
}
else
{
($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters) = DisplayReceiptPhase($::g_InputHash{ORDERNUMBER}, $ePaymentMethod);
if ($status != $::SUCCESS)
{
return ($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable, $sDetailCookie);
}
UpdateCheckoutRecord();
$sDetailCookie = $::Session->ContactDetailsToCookieString();
$::Session->MarkAsClosed();
$::Session->SaveSession();
}
}
elsif ($nPhase == $::PRELIMINARYINFOPHASE)
{
($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable) = ActinicOrder::DisplayPreliminaryInfoPhase();
if ($status != $::SUCCESS)
{
return ($status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable, $sDetailCookie);
}
UpdateCheckoutRecord();
}
my (@Array1, @Array2);
@Array1 = %$pVarTable;
@Array2 = %::s_LargeVariableTable;
push (@Array1, @Array2);
%::s_LargeVariableTable = @Array1;
push (@::s_LargeDeleteDelimiters, @$pDeleteDelimiters);
push (@::s_LargeKeepDelimiters, @$pKeepDelimiters);
if (defined $pSelectTable)
{
@Array1 = %$pSelectTable;
@Array2 = %::s_LargeSelectTable;
push (@Array1, @Array2);
%::s_LargeSelectTable = @Array1;
undef $pSelectTable;
}
($pDeleteDelimiters, $pKeepDelimiters) = ActinicOrder::ParseDelimiterStatus($nPhase);
push (@::s_LargeDeleteDelimiters, @$pDeleteDelimiters);
push (@::s_LargeKeepDelimiters, @$pKeepDelimiters);
}
return ($::SUCCESS, '', \%::s_LargeVariableTable, \@::s_LargeDeleteDelimiters, \@::s_LargeKeepDelimiters,
\%::s_LargeSelectTable, $sDetailCookie);
}
sub DisplayBillContactPhase
{
undef %::s_VariableTable;
undef @::s_DeleteDelimiters;
undef @::s_KeepDelimiters;
if (ActinicOrder::IsPhaseComplete($::BILLCONTACTPHASE) ||
ActinicOrder::IsPhaseHidden($::BILLCONTACTPHASE))
{
push (@::s_DeleteDelimiters, 'INVOICEPHASE');
return (\%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
else
{
push (@::s_KeepDelimiters, 'INVOICEPHASE');
}
if (0 == length $::g_BillContact{'COUNTRY'})
{
if ($$::g_pLocationList{EXPECT_INVOICE} &&
$::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
$::g_BillContact{'COUNTRY'} = ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_COUNTRY_CODE});
}
elsif ($$::g_pLocationList{EXPECT_DELIVERY} &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
$::g_BillContact{'COUNTRY'} = ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_COUNTRY_CODE});
}
}
$::s_VariableTable{$::VARPREFIX.'INVOICESALUTATION'} 	= ACTINIC::EncodeText2($::g_BillContact{'SALUTATION'});
$::s_VariableTable{$::VARPREFIX.'INVOICENAME'}		= ACTINIC::EncodeText2($::g_BillContact{'NAME'});
$::s_VariableTable{$::VARPREFIX.'INVOICEFIRSTNAME'}	= ACTINIC::EncodeText2($::g_BillContact{'FIRSTNAME'});
$::s_VariableTable{$::VARPREFIX.'INVOICELASTNAME'}	= ACTINIC::EncodeText2($::g_BillContact{'LASTNAME'});
$::s_VariableTable{$::VARPREFIX.'INVOICEJOBTITLE'} 	= ACTINIC::EncodeText2($::g_BillContact{'JOBTITLE'});
$::s_VariableTable{$::VARPREFIX.'INVOICECOMPANY'}	= ACTINIC::EncodeText2($::g_BillContact{'COMPANY'});
$::s_VariableTable{$::VARPREFIX.'INVOICEADDRESS1'} 	= ACTINIC::EncodeText2($::g_BillContact{'ADDRESS1'});
$::s_VariableTable{$::VARPREFIX.'INVOICEADDRESS2'}	= ACTINIC::EncodeText2($::g_BillContact{'ADDRESS2'});
$::s_VariableTable{$::VARPREFIX.'INVOICEADDRESS3'} 	= ACTINIC::EncodeText2($::g_BillContact{'ADDRESS3'});
$::s_VariableTable{$::VARPREFIX.'INVOICEADDRESS4'} 	= ACTINIC::EncodeText2($::g_BillContact{'ADDRESS4'});
$::s_VariableTable{$::VARPREFIX.'INVOICEPOSTALCODE'} 	= ACTINIC::EncodeText2($::g_BillContact{'POSTALCODE'});
$::s_VariableTable{$::VARPREFIX.'INVOICECOUNTRY'}	= ACTINIC::EncodeText2($::g_BillContact{'COUNTRY'});
$::s_VariableTable{$::VARPREFIX.'INVOICEPHONE'}		= ACTINIC::EncodeText2($::g_BillContact{'PHONE'});
$::s_VariableTable{$::VARPREFIX.'INVOICEMOBILE'}	= ACTINIC::EncodeText2($::g_BillContact{'MOBILE'});
$::s_VariableTable{$::VARPREFIX.'INVOICEFAX'}		= ACTINIC::EncodeText2($::g_BillContact{'FAX'});
$::s_VariableTable{$::VARPREFIX.'INVOICEEMAIL'}		= ACTINIC::EncodeText2($::g_BillContact{'EMAIL'});
$::s_VariableTable{$::VARPREFIX.'INVOICEUSERDEFINED'} = ACTINIC::EncodeText2($::g_BillContact{'USERDEFINED'});
$::s_VariableTable{$::VARPREFIX.'INVOICETITLE'}		= ACTINIC::GetPhrase(-1, 147);
$::s_VariableTable{$::VARPREFIX.'COUPONCODE'}		= ACTINIC::EncodeText2($::g_PaymentInfo{'COUPONCODE'});
if ($::g_BillContact{'MOVING'})
{
$::s_VariableTable{$::VARPREFIX.'INVOICEMOVINGCHECKSTATUS'} = 'CHECKED';
}
else
{
$::s_VariableTable{$::VARPREFIX.'INVOICEMOVINGCHECKSTATUS'} = '';
}
if ($::g_BillContact{'PRIVACY'})
{
$::s_VariableTable{$::VARPREFIX.'INVOICEPRIVACYCHECKSTATUS'} = 'CHECKED';
}
else
{
$::s_VariableTable{$::VARPREFIX.'INVOICEPRIVACYCHECKSTATUS'} = '';
}
if ($::g_BillContact{'SEPARATE'})
{
$::s_VariableTable{$::VARPREFIX.'INVOICESEPARATECHECKSTATUS'} = 'CHECKED';
}
else
{
$::s_VariableTable{$::VARPREFIX.'INVOICESEPARATECHECKSTATUS'} = '';
}
if ($::g_BillContact{'REMEMBERME'} ||
!defined $::g_BillContact{'REMEMBERME'})
{
$::s_VariableTable{$::VARPREFIX.'INVOICEREMEMBERME'} = 'CHECKED';
}
else
{
$::s_VariableTable{$::VARPREFIX.'INVOICEREMEMBERME'} = '';
}
if ($::g_BillContact{'AGREEDTANDC'})
{
$::s_VariableTable{$::VARPREFIX.'INVOICEAGREETERMSCONDITIONS'} = 'CHECKED';
}
else
{
$::s_VariableTable{$::VARPREFIX.'INVOICEAGREETERMSCONDITIONS'} = '';
}
return (\%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
sub DisplayShipContactPhase
{
undef %::s_VariableTable;
undef @::s_DeleteDelimiters;
undef @::s_KeepDelimiters;
if (ActinicOrder::IsPhaseComplete($::SHIPCONTACTPHASE) ||
ActinicOrder::IsPhaseHidden($::SHIPCONTACTPHASE) )
{
push (@::s_DeleteDelimiters, 'DELIVERPHASE');
return (\%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
elsif (defined $$::g_pSetupBlob{'REVERSE_ADDRESS_CHECK'} && $$::g_pSetupBlob{'REVERSE_ADDRESS_CHECK'})
{
if ($::g_BillContact{'SEPARATE'})
{
push (@::s_DeleteDelimiters, 'DELIVERPHASE');
return (\%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
else
{
push (@::s_KeepDelimiters, 'DELIVERPHASE');
}
}
else
{
if (!$::g_BillContact{'SEPARATE'})
{
push (@::s_DeleteDelimiters, 'DELIVERPHASE');
return (\%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
else
{
push (@::s_KeepDelimiters, 'DELIVERPHASE');
}
}
if ($::ACT_ADB)
{
ConfigureAddressBook();
$::ACT_ADB->ToForm();
$::s_VariableTable{$::VARPREFIX.'ADDRESSBOOK'}	= $::ACT_ADB->Show();
}
else
{
$::s_VariableTable{$::VARPREFIX.'ADDRESSBOOK'}	= "";
}
if (0 == length $::g_ShipContact{'COUNTRY'})
{
if ($$::g_pLocationList{EXPECT_DELIVERY} &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
$::g_ShipContact{'COUNTRY'} = ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_COUNTRY_CODE});
}
elsif ($$::g_pLocationList{EXPECT_INVOICE} &&
$::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
$::g_ShipContact{'COUNTRY'} = ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_COUNTRY_CODE});
}
}
my $sFormat = "<INPUT TYPE=HIDDEN NAME=%s VALUE='%s'>\n";
my $sParam;
foreach (keys %::g_LocationInfo)
{
$sParam .= sprintf($sFormat, $_, $::g_LocationInfo{$_});
}
$::s_VariableTable{$::VARPREFIX.'LOCATIONINFO'} = $sParam;
$::s_VariableTable{$::VARPREFIX.'DELIVERSALUTATION'} 	= ACTINIC::EncodeText2($::g_ShipContact{'SALUTATION'});
$::s_VariableTable{$::VARPREFIX.'DELIVERNAME'}		= ACTINIC::EncodeText2($::g_ShipContact{'NAME'});
$::s_VariableTable{$::VARPREFIX.'DELIVERFIRSTNAME'}	= ACTINIC::EncodeText2($::g_ShipContact{'FIRSTNAME'});
$::s_VariableTable{$::VARPREFIX.'DELIVERLASTNAME'}	= ACTINIC::EncodeText2($::g_ShipContact{'LASTNAME'});
$::s_VariableTable{$::VARPREFIX.'DELIVERJOBTITLE'} 	= ACTINIC::EncodeText2($::g_ShipContact{'JOBTITLE'});
$::s_VariableTable{$::VARPREFIX.'DELIVERCOMPANY'}	= ACTINIC::EncodeText2($::g_ShipContact{'COMPANY'});
$::s_VariableTable{$::VARPREFIX.'DELIVERADDRESS1'} 	= ACTINIC::EncodeText2($::g_ShipContact{'ADDRESS1'});
$::s_VariableTable{$::VARPREFIX.'DELIVERADDRESS2'} 	= ACTINIC::EncodeText2($::g_ShipContact{'ADDRESS2'});
$::s_VariableTable{$::VARPREFIX.'DELIVERADDRESS3'} 	= ACTINIC::EncodeText2($::g_ShipContact{'ADDRESS3'});
$::s_VariableTable{$::VARPREFIX.'DELIVERADDRESS4'} 	= ACTINIC::EncodeText2($::g_ShipContact{'ADDRESS4'});
$::s_VariableTable{$::VARPREFIX.'DELIVERPOSTALCODE'} 	= ACTINIC::EncodeText2($::g_ShipContact{'POSTALCODE'});
$::s_VariableTable{$::VARPREFIX.'DELIVERCOUNTRY'}	= ACTINIC::EncodeText2($::g_ShipContact{'COUNTRY'});
$::s_VariableTable{$::VARPREFIX.'DELIVERPHONE'}		= ACTINIC::EncodeText2($::g_ShipContact{'PHONE'});
$::s_VariableTable{$::VARPREFIX.'DELIVERMOBILE'}	= ACTINIC::EncodeText2($::g_ShipContact{'MOBILE'});
$::s_VariableTable{$::VARPREFIX.'DELIVERFAX'}		= ACTINIC::EncodeText2($::g_ShipContact{'FAX'});
$::s_VariableTable{$::VARPREFIX.'DELIVEREMAIL'}		= ACTINIC::EncodeText2($::g_ShipContact{'EMAIL'});
$::s_VariableTable{$::VARPREFIX.'DELIVERUSERDEFINED'} = ACTINIC::EncodeText2($::g_ShipContact{'USERDEFINED'});
$::s_VariableTable{$::VARPREFIX.'DELIVERTITLE'} 		= ACTINIC::GetPhrase(-1, 148);
return (\%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
sub DisplayPaymentPhase
{
undef %::s_VariableTable;
undef @::s_DeleteDelimiters;
undef @::s_KeepDelimiters;
if (ActinicOrder::IsPhaseComplete($::PAYMENTPHASE) ||
ActinicOrder::IsPhaseHidden($::PAYMENTPHASE) )
{
push (@::s_DeleteDelimiters, 'PAYMENTPHASE');
return ($::SUCCESS, '', \%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
my ($Status, $Message, @Response);
@Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
my (@SummaryResponse, $nTotal);
@SummaryResponse = $pCartObject->SummarizeOrder($::FALSE);
if ($SummaryResponse[0] != $::SUCCESS)
{
return (@SummaryResponse);
}
$nTotal = $SummaryResponse[6];
my ($bPaymentHidden) = ($nTotal == 0 || !$$::g_pSetupBlob{'PRICES_DISPLAYED'});
if ($bPaymentHidden)
{
EnsurePaymentSelection();
}
if ( $bPaymentHidden &&
ACTINIC::IsPromptHidden(5, 7))
{
push (@::s_DeleteDelimiters, 'PAYMENTPHASE');
return ($::SUCCESS, '', \%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
else
{
push (@::s_KeepDelimiters, 'PAYMENTPHASE');
}
@Response = ActinicOrder::GeneratePaymentSelection();
if ($Response[0] != $::SUCCESS)
{
return(@Response);
}
$::s_VariableTable{$::VARPREFIX.'PAYMENTMETHODOPTIONS'} = $Response[1];
$::s_VariableTable{$::VARPREFIX.'PAYMENTUSERDEFINED'} = ACTINIC::EncodeText2($::g_PaymentInfo{'USERDEFINED'});
$::s_VariableTable{$::VARPREFIX.'PAYMENTPONO'} 			= ACTINIC::EncodeText2($::g_PaymentInfo{'PONO'});
$::s_VariableTable{$::VARPREFIX.'PAYMENTCARDNUMBER'} 	= ACTINIC::EncodeText2($::g_PaymentInfo{'CARDNUMBER'});
$::s_VariableTable{$::VARPREFIX.'PAYMENTCARDISSUE'} 	= ACTINIC::EncodeText2($::g_PaymentInfo{'CARDISSUE'});
$::s_VariableTable{$::VARPREFIX.'PAYMENTCARDVV2'} 		= ACTINIC::EncodeText2($::g_PaymentInfo{'CARDVV2'});
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst, $sDate);
($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
$mon++;
$year += 1900;
my ($nYear, $nMonth);
if ($::g_PaymentInfo{'STARTMONTH'} eq '')
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTSTARTMONTHS'} .= '<OPTION SELECTED>' . ACTINIC::GetPhrase(5, 9) . "\n";
}
if ($::g_PaymentInfo{'STARTYEAR'} eq '')
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTSTARTYEARS'} .= '<OPTION SELECTED>' . ACTINIC::GetPhrase(5, 10) . "\n";
}
if ($::g_PaymentInfo{'EXPMONTH'} eq '')
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTEXPMONTHS'} .= '<OPTION SELECTED>' . ACTINIC::GetPhrase(5, 9) . "\n";
}
if ($::g_PaymentInfo{'EXPYEAR'} eq '')
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTEXPYEARS'} .= '<OPTION SELECTED>' . ACTINIC::GetPhrase(5, 10) . "\n";
}
for ($nMonth = 1; $nMonth < 13; $nMonth++)
{
if ($::g_PaymentInfo{'STARTMONTH'} == $nMonth)
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTSTARTMONTHS'} .= '<OPTION SELECTED>' . sprintf('%2.2d', $nMonth) . "\n";
}
else
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTSTARTMONTHS'} .= '<OPTION>' . sprintf('%2.2d', $nMonth) . "\n";
}
if ($::g_PaymentInfo{'EXPMONTH'} == $nMonth)
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTEXPMONTHS'} .= '<OPTION SELECTED>' . sprintf('%2.2d', $nMonth) . "\n";
}
else
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTEXPMONTHS'} .= '<OPTION>' . sprintf('%2.2d', $nMonth) . "\n";
}
}
for ($nYear = 0; $nYear < 11; $nYear++)
{
my ($nStartYear, $nExpYear);
($nStartYear, $nExpYear) = ($nYear + $year - 10, $nYear + $year);
if ($::g_PaymentInfo{'STARTYEAR'} == $nExpYear)
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTSTARTYEARS'} .= '<OPTION SELECTED>' . $nStartYear . "\n";
}
else
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTSTARTYEARS'} .= '<OPTION>' . $nStartYear . "\n";
}
if ($::g_PaymentInfo{'EXPYEAR'} == $nExpYear)
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTEXPYEARS'} .= '<OPTION SELECTED>' . $nExpYear . "\n";
}
else
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTEXPYEARS'} .= '<OPTION>' . $nExpYear . "\n";
}
}
if ($::g_PaymentInfo{'CARDTYPE'} ne '')
{
$::s_VariableTable{'<OPTION>' . $::g_PaymentInfo{'CARDTYPE'}} =
'<OPTION SELECTED>' . $::g_PaymentInfo{'CARDTYPE'};
}
if ($bPaymentHidden)
{
push (@::s_DeleteDelimiters, 'PAYMENTNOPRICES');
}
else
{
push (@::s_KeepDelimiters, 'PAYMENTNOPRICES');
}
$::s_VariableTable{$::VARPREFIX.'PAYMENTTITLE'} = ACTINIC::GetPhrase(-1, 152);
@Response = ACTINIC::GetDigitalContent($pCartList, $::TRUE);
if ($Response[0] == $::FAILURE)
{
return (@Response);
}
my %hDDLinks = %{$Response[2]};
if (keys %hDDLinks == 0)
{
push (@::s_DeleteDelimiters, 'DIGITALDOWNLOADINFORMATION');
}
else
{
$::s_VariableTable{$::VARPREFIX.'DDINFOMESSAGE'} = ACTINIC::GetPhrase(-1, 2274, $$::g_pSetupBlob{'DD_EXPIRY_TIME'});
push (@::s_KeepDelimiters, 'DIGITALDOWNLOADINFORMATION');
}
$::g_PaymentInfo{'AUTHORIZERESULT'} = "1";
return ($::SUCCESS, '', \%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
sub DisplayPageWithOrderDetails
{
undef %::s_VariableTable;
undef @::s_DeleteDelimiters;
undef @::s_KeepDelimiters;
my $eMode = $_[0];
my ($ePaymentMethod) = ActinicOrder::PaymentStringToEnum($::g_PaymentInfo{'METHOD'}); # the payment method is stored as "ENUMERATEDID:DESCRIPTION"
my (@ParamList, $sParamFormat, $bEncoding);
if ($eMode == $::eApplet)
{
$sParamFormat = '<PARAM NAME="%s" VALUE="%s">';
$bEncoding = $::FALSE;
}
else
{
$sParamFormat = '<INPUT TYPE="HIDDEN" NAME="%s" VALUE="%s">';
$bEncoding = $::TRUE;
}
my ($status, $sMessage, $sPageHistory);
($sPageHistory) = split(/\?/, $::Session->GetLastPage());
my ($sParam, @Response);
if ($::g_InputHash{SHOP})
{
$sParam = sprintf($sParamFormat, 'SHOP', ACTINIC::EncodeText2($::g_InputHash{SHOP}, $bEncoding));
push (@ParamList, $sParam);
}
$sPageHistory =~ s/\|\|\|$//;
$sParam = sprintf($sParamFormat, 'REFPAGE', ACTINIC::EncodeText2($sPageHistory, $bEncoding));
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'SEQUENCE', 3);
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'REQUIRED_COLOR', $::g_sRequiredColor);
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'FORM_BACKGROUND_COLOR', $$::g_pSetupBlob{'FORM_BACKGROUND_COLOR'});
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'FORM_EMPHASIS_COLOR', $$::g_pSetupBlob{'FORM_EMPHASIS_COLOR'});
push (@ParamList, $sParam);
my ($bBgIsImage, $sBgImageFileName, $sBgColor) = ACTINIC::GetPageBackgroundInfo();
$sParam = sprintf($sParamFormat, 'BACKGROUND_COLOR', $sBgColor);
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'FOREGROUND_COLOR', $$::g_pSetupBlob{'FOREGROUND_COLOR'});
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'LINK_COLOR', $$::g_pSetupBlob{'LINK_COLOR'});
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'ALINK_COLOR', $$::g_pSetupBlob{'ALINK_COLOR'});
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'VLINK_COLOR', $$::g_pSetupBlob{'VLINK_COLOR'});
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'COMPANY_NAME', $$::g_pSetupBlob{'COMPANY_NAME'});
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'CARTID', $::g_sCartId);
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'PROTOCOL_VERSION', $::SSSL_Protocol_Version);
push (@ParamList, $sParam);
my		$sCgiUrl;
if ($$::g_pSetupBlob{'SSL_USEAGE'} == "0")
{
$sCgiUrl = $$::g_pSetupBlob{CGI_URL};
}
else
{
$sCgiUrl = $$::g_pSetupBlob{SSL_CGI_URL};
}
if ($$::g_pSetupBlob{'USE_RELATIVE_CGI_URLS'})
{
my $sServer = $::Session->GetLastShopPage();
if ($sServer =~ /(http(s?):\/\/[^\/]*\/)/)
{
$sServer = $1;
$sCgiUrl =~ s/http(s?):\/\/[^\/]*\//$sServer/;
}
}
$sParam = sprintf($sParamFormat, 'CGI_URL', ACTINIC::EncodeText2($sCgiUrl, $bEncoding));
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'CGI_ID', $$::g_pSetupBlob{'CGI_ID'});
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'CGI_EXT', $$::g_pSetupBlob{'CGI_EXT'});
push (@ParamList, $sParam);
my $sKeyLength = $$::g_pSetupBlob{'KEY_LENGTH'};
$sParam = sprintf($sParamFormat, 'KEY_LENGTH', $sKeyLength);
push (@ParamList, $sParam);
my ($nCount);
my ($pKey) = $$::g_pSetupBlob{'PUBLIC_KEY_' . $sKeyLength . 'BIT'};
for ($nCount = 0; $nCount <= $#$pKey; $nCount++)
{
$sParam = sprintf($sParamFormat, 'PUBLIC_KEY_' . $nCount, sprintf('%2.2x', $$pKey[$nCount]));
push (@ParamList, $sParam);
}
if ($ePaymentMethod == $::PAYMENT_CREDIT_CARD)
{
my ($nIndex, $sCCID, $sTemp);
for ($nIndex = 0; $nIndex < 12; $nIndex++)
{
$sCCID = sprintf('CC%d', $nIndex);
$sParam = sprintf($sParamFormat, $sCCID, $$::g_pSetupBlob{$sCCID});
push (@ParamList, $sParam);
$sTemp = $sCCID."_STARTDATEFLAG";
$sParam = sprintf($sParamFormat, $sTemp, $$::g_pSetupBlob{$sTemp});
push (@ParamList, $sParam);
$sTemp = $sCCID."_ISSUENUMBERFLAG";
$sParam = sprintf($sParamFormat, $sTemp, $$::g_pSetupBlob{$sTemp});
push (@ParamList, $sParam);
$sTemp = $sCCID."_CVV2FLAG";
$sParam = sprintf($sParamFormat, $sTemp, $$::g_pSetupBlob{$sTemp});
push (@ParamList, $sParam);
$sTemp = $sCCID."_CVV2DIGITS";
$sParam = sprintf($sParamFormat, $sTemp, $$::g_pSetupBlob{$sTemp});
push (@ParamList, $sParam);
}
}
my $sOrderNumber;
($status, $sMessage, $sOrderNumber) = GetOrderNumber();
if ($status != $::SUCCESS)
{
return ($status, $sMessage, undef, undef, undef);
}
$sParam = sprintf($sParamFormat, 'ORDERNUMBER', $sOrderNumber);
push (@ParamList, $sParam);
my ($sDate) = ACTINIC::GetActinicDate();
$::g_PaymentInfo{ORDERDATE} = $sDate;
UpdateCheckoutRecord();
$sParam = sprintf($sParamFormat, 'ORDER_DATE', $sDate);
push (@ParamList, $sParam);
@Response = GetSaferBlob($sOrderNumber, ACTINIC::GetPath(), $sDate);
if($Response[0] != $::SUCCESS)
{
return(@Response);
}
$sParam = sprintf($sParamFormat, 'ORDER_DETAILS_LEN', length $Response[2], $bEncoding);
push (@ParamList, $sParam);
my ($UUSaferBlob) = ACTINIC::UUEncode($Response[2]);
$sParam = sprintf($sParamFormat, 'ORDER_DETAILS', $UUSaferBlob, $bEncoding);
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'ORDER_BLOB_VERSION', $::ORDER_BLOB_VERSION);
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'ORDER_DETAIL_BLOB_VERSION', $::ORDER_DETAIL_BLOB_VERSION);
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'SHARED_SSL_TEST_MODE', $$::g_pSetupBlob{SHARED_SSL_TEST_MODE});
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'SHARED_SSL_USER_ID', $$::g_pSetupBlob{SHARED_SSL_USER_ID});
push (@ParamList, $sParam);
if ($eMode == $::eApplet)
{
my ($nPhraseId, $sPhrase);
for ($nPhraseId = 500; $nPhraseId < 600; $nPhraseId++)
{
$sPhrase = ACTINIC::GetPhrase(-1, $nPhraseId);
$sParam = sprintf($sParamFormat, 'PHRASE' . $nPhraseId, ACTINIC::EncodeText2($sPhrase, $bEncoding));
push (@ParamList, $sParam);
}
$::s_VariableTable{$::VARPREFIX.'APPLETPARAMS'} = join("\n", @ParamList);
}
else
{
my $sUserDigest = $ACTINIC::B2B->Get('UserDigest');
if ($sUserDigest)
{
my ($status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sUserDigest, ACTINIC::GetPath());
if ($status != $::SUCCESS)
{
return ($status, $sMessage);
}
my $nBuyerID = $$pBuyer{ID};
my $nCustomerID = $$pBuyer{AccountID};
$sParam = sprintf($sParamFormat, 'BUYERID', $nBuyerID);
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'CUSTOMERID', $nCustomerID);
push (@ParamList, $sParam);
}
my ($ePaymentMethod) = ActinicOrder::PaymentStringToEnum($::g_PaymentInfo{'METHOD'}); # the payment method is stored as "ENUMERATEDID:DESCRIPTION"
if (defined $$::g_pPaymentList{$::PAYMENT_PAYPAL_PRO} &&
($ePaymentMethod == $::PAYMENT_CREDIT_CARD ||
$ePaymentMethod == $::PAYMENT_PAYPAL_PRO))
{
EvaluatePaypalPro();
$sParam = sprintf($sParamFormat, 'USEPP', $::TRUE);
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'PPPARAMS', $::PAYPAL_ENC_PARAM);
push (@ParamList, $sParam);
my ($sFirstName, $sLastName, $sEmail, $sCountry, $sState, $sZipCode, $sCity, $sStreet) = GetPPAddressDetails();
push (@ParamList, sprintf($sParamFormat, 'PPFIRSTNAME', 	$sFirstName));
push (@ParamList, sprintf($sParamFormat, 'PPLASTNAME', 	$sLastName));
push (@ParamList, sprintf($sParamFormat, 'PPEMAIL', 		$sEmail));
push (@ParamList, sprintf($sParamFormat, 'PPCOUNTRY', 	$sCountry));
push (@ParamList, sprintf($sParamFormat, 'PPSTATE', 		$sState));
push (@ParamList, sprintf($sParamFormat, 'PPZIPCODE', 	$sZipCode));
push (@ParamList, sprintf($sParamFormat, 'PPCITY', 		$sCity));
push (@ParamList, sprintf($sParamFormat, 'PPSTREET', 		$sStreet));
}
my ($Status, $Message);
@Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
@Response = $pCartObject->SummarizeOrder($::FALSE);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $nAmount = ActinicOrder::GetOrderTotal();
$sParam = sprintf($sParamFormat, 'ORDERTOTAL', $nAmount);
push (@ParamList, $sParam);
$sParam = sprintf($sParamFormat, 'CURRENCY', $$::g_pCatalogBlob{'SINTLSYMBOLS'});
push (@ParamList, $sParam);
my @PromptList = ('-1,107', '-1,108', '-1,109', '-1,110', '-1,111', '-1,112', '-1,152', '-1,187',
'-1,188', '-1,189', '-1,1970', '-1,1971', '-1,2074', '-1,2075', '-1,2076',
'-1,2078', '-1,2086', '-1,21', '-1,2171', '-1,2172', '-1,23', '-1,24',
'-1,25', '-1,26', '-1,319', '-1,320', '-1,502', '-1,503', '-1,505', '-1,55',
'-1,560', '-1,561', '-1,2450', '-1,94', '-1,962', '5,1', '5,2', '5,3', '5,4', '5,5', '5,8');
my ($nPhraseIdentifier, $sPhrase);
foreach $nPhraseIdentifier (@PromptList)
{
$nPhraseIdentifier =~ /,/;
$sPhrase = ACTINIC::GetPhrase($`, $');
$sParam = sprintf($sParamFormat, 'PHRASE' . $nPhraseIdentifier, ACTINIC::EncodeText2($sPhrase, $bEncoding));
push (@ParamList, $sParam);
}
$::s_VariableTable{$::VARPREFIX.'SSL_VALUES'} = join("\n", @ParamList);
if ($$::g_pSetupBlob{SHARED_SSL_TEST_MODE})
{
push (@::s_KeepDelimiters, 'TESTMODE');
}
else
{
push (@::s_DeleteDelimiters, 'TESTMODE');
}
}
return ($::SUCCESS, '', \%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
sub DisplayReceiptPhase
{
undef %::s_VariableTable;
undef @::s_DeleteDelimiters;
undef @::s_KeepDelimiters;
if ($#_ < 1)
{
return($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'DisplayReceiptPhase'), undef, undef, undef);
}
my ($Message, $Status);
my ($sOrderNumber, $ePaymentMethod, $bRedisplay) = @_;
my $bMailDelayed = $::FALSE;
if ($::Session->IsIPCheckFailed())
{
$::s_VariableTable{$::VARPREFIX.'ERROR'} = ACTINIC::GetPhrase(-1, 2308);
}
$::ReceiptPhase = $::TRUE;
my $bInvoiceUsesRegion = $::FALSE;
my $bShipSeparately = ($::g_LocationInfo{SEPARATESHIP} ne '');
if(defined $$::g_pLocationList{INVOICEADDRESS4} &&
$$::g_pLocationList{INVOICEADDRESS4})
{
$bInvoiceUsesRegion = $::TRUE;
$::g_BillContact{ADDRESS4} = ActinicLocations::GetInvoiceAddressRegionName($::g_BillContact{ADDRESS4});
}
if(defined $$::g_pLocationList{DELIVERADDRESS4} &&
$$::g_pLocationList{DELIVERADDRESS4})
{
$::g_ShipContact{ADDRESS4} = ActinicLocations::GetDeliveryAddressRegionName($::g_ShipContact{ADDRESS4});
if (!$bInvoiceUsesRegion &&
!$bShipSeparately)
{
$::g_BillContact{ADDRESS4} = ActinicLocations::GetInvoiceAddressRegionName($::g_BillContact{ADDRESS4});
}
}
else
{
if ($bInvoiceUsesRegion &&
!$bShipSeparately)
{
$::g_ShipContact{ADDRESS4} = ActinicLocations::GetDeliveryAddressRegionName($::g_ShipContact{ADDRESS4});
}
}
my $sUserDigest = $ACTINIC::B2B->Get('UserDigest');
my ($BuyerStatus, $sMessage, $pBuyer, $pAccount);
if ($sUserDigest && !$bRedisplay)
{
($BuyerStatus, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sUserDigest, ACTINIC::GetPath());
if ($BuyerStatus != $::SUCCESS &&
$BuyerStatus != $::NOTFOUND)
{
return ($BuyerStatus, $sMessage);
}
if ($BuyerStatus != $::NOTFOUND)
{
($Status, $sMessage, $pAccount) = ACTINIC::GetCustomerAccount($$pBuyer{AccountID}, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return ($Status, $sMessage);
}
}
}
my @aRecipients;
if (!$bRedisplay)
{
my $sName = '';
my $sTemplateFile = '';
my $sEmailCopyAddresses = $::g_pSetupBlob->{'EMAIL_COPY_ADDRESSES'};
@aRecipients = split(/ /, $sEmailCopyAddresses);
if ($sUserDigest &&
$BuyerStatus != $::NOTFOUND)
{
$sName = $$pBuyer{Salutation} ? $$pBuyer{Salutation} . ' ' : '';
$sName .= $$pBuyer{Name};
if ($$pBuyer{EmailOnOrder})
{
if (!$$pBuyer{EmailAddress})
{
ACTINIC::RecordErrors(ACTINIC::GetPhrase(-1, 280), ACTINIC::GetPath());
}
push(@aRecipients, $$pBuyer{EmailAddress});
}
$sTemplateFile = 'Act_BuyerEmail.txt';
}
else
{
$sName = $::g_BillContact{'SALUTATION'} ? $::g_BillContact{'SALUTATION'} . ' ' : '';
$sName .= $::g_BillContact{'NAME'};
if ($$::g_pSetupBlob{EMAIL_CUSTOMER_RECEIPT}) # an e-mail should be sent to the customer, thus add his address to the recipients
{
if (!$::g_BillContact{EMAIL})
{
ACTINIC::RecordErrors(ACTINIC::GetPhrase(-1, 280), ACTINIC::GetPath());
}
push(@aRecipients, $::g_BillContact{EMAIL});
}
$sTemplateFile = 'Act_CustomerEmail.txt';
}
if (scalar(@aRecipients) > 0)
{
if ((($ePaymentMethod == $::PAYMENT_PAYPAL) ||
($ePaymentMethod == $::PAYMENT_NOCHEX)) &&
!$::Session->IsPaymentMade())
{
my $sMailFile;
$sMailFile = $::Session->GetSessionFileFolder() . $::g_PaymentInfo{ORDERNUMBER} . ".mail";
$::Session->PaymentMade();
($Status, $Message) = GenerateCustomerMail($sTemplateFile, \@aRecipients, $sName, $sMailFile);
$::Session->ClearPaymentMade();
$bMailDelayed = $::TRUE;
}
else
{
($Status, $Message) = GenerateCustomerMail($sTemplateFile, \@aRecipients, $sName);
}
if ($Status != $::SUCCESS)
{
ACTINIC::RecordErrors($Message, ACTINIC::GetPath());
}
}
}
if ($sUserDigest &&
$BuyerStatus != $::NOTFOUND &&
$$pAccount{EmailOnOrder} &&
$$pAccount{EmailAddress})
{
my $sName = $$pAccount{Salutation} ? $$pAccount{Salutation} . ' ' : '';
$sName .= $$pAccount{Name};
@aRecipients = ($$pAccount{EmailAddress});
($Status, $Message) = GenerateCustomerMail('Act_AdminEmail.txt',
\@aRecipients,
$sName);
if ($Status != $::SUCCESS)
{
ACTINIC::RecordErrors($Message, ACTINIC::GetPath());
}
}
if (defined $$::g_pSetupBlob{'EMAIL_ORDER'} && $$::g_pSetupBlob{'EMAIL_ORDER'} && !$bRedisplay)
{
($Status, $Message) = GeneratePresnetMail();
if ($Status != $::SUCCESS)
{
ACTINIC::RecordErrors($Message, ACTINIC::GetPath());
}
}
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst, $sDate);
($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time);
$mon++;
$year += 1900;
$sDate = sprintf('%d %s %d', $mday, $::g_InverseMonthMap{$mon}, $year); # format the date "day Month Year" eg. "1 April 1998"
$::s_VariableTable{$::VARPREFIX.'CURRENTDATE'} = $sDate;
$::s_VariableTable{$::VARPREFIX.'THEORDERNUMBER'} = $sOrderNumber;
my ($sDirections, $sTemp, @Response);
if ($ePaymentMethod == $::PAYMENT_CREDIT_CARD_SEPARATE)
{
$sDirections = ACTINIC::GetPhrase(-1, 73);
}
$::s_VariableTable{$::VARPREFIX.'SENDSEPARATELY'} = $sDirections;
{
my %HashID = (
'CONTACT_JOB_TITLE' => 'COMPANYCONTACTTITLE',
'COMPANY_NAME' => 'COMPANYNAME',
'ADDRESS_1' => 'COMPANYSTREETADDRESS1',
'ADDRESS_2' => 'COMPANYSTREETADDRESS2',
'ADDRESS_3' => 'COMPANYSTREETADDRESS3',
'ADDRESS_4' => 'COMPANYSTREETADDRESS4',
'POSTAL_CODE' => 'COMPANYPOSTCODE',
'COUNTRY' => 'COMPANYCOUNTRY',
'PHONE' => 'COMPANYPHONE|-1|74',
'FAX' => 'COMPANYFAX|-1|75'
);
ActinicOrder::HashToVarTable(\%HashID, \%$::g_pSetupBlob, \%::s_VariableTable);
}
undef $sTemp;
if ((length $$::g_pSetupBlob{'CONTACT_NAME'}) > 0)
{
if ((length $$::g_pSetupBlob{'CONTACT_SALUTATION'}) > 0)
{
$sTemp = $$::g_pSetupBlob{'CONTACT_SALUTATION'} . " " . $$::g_pSetupBlob{'CONTACT_NAME'};
}
else
{
$sTemp = $$::g_pSetupBlob{'CONTACT_NAME'};
}
@Response = ACTINIC::EncodeText($sTemp,$::TRUE,$::TRUE);
$sTemp = $Response[1] . "<BR>";
}
$::s_VariableTable{$::VARPREFIX.'COMPANYCONTACTNAME'} = $sTemp;
undef $sTemp;
if ((length $$::g_pSetupBlob{'EMAIL'}) > 0)
{
$sTemp .= ACTINIC::GetPhrase(-1, 76) . ": <A HREF=\"MAILTO:" . $$::g_pSetupBlob{'EMAIL'} . "\">" .
$$::g_pSetupBlob{'EMAIL'} . "</A><BR>";
}
$::s_VariableTable{$::VARPREFIX.'COMPANYEMAIL'} = $sTemp;
undef $sTemp;
if ((length $$::g_pSetupBlob{'WEB_SITE_URL'}) > 0)
{
my $sService = ($$::g_pSetupBlob{WEB_SITE_URL} =~ /^http(s)?:\/\//) ? '' : 'http://';
$sTemp = ACTINIC::GetPhrase(-1, 77) . ": <A HREF=\"" . $sService . $$::g_pSetupBlob{'WEB_SITE_URL'} . "\">" .
$$::g_pSetupBlob{'WEB_SITE_URL'} . "</A><BR>";
}
$::s_VariableTable{$::VARPREFIX.'COMPANYURL'} = $sTemp;
$::s_VariableTable{$::VARPREFIX.'YOURRECEIPT'} 		= ACTINIC::GetPhrase(-1, 336);
$::s_VariableTable{$::VARPREFIX.'PRINTTHISPAGE'} 	= ACTINIC::GetPhrase(-1, 337);
$::s_VariableTable{$::VARPREFIX.'NEEDTOCONTACT'} 	= ACTINIC::GetPhrase(-1, 338);
$::s_VariableTable{$::VARPREFIX.'INVOICETO'} 		= ACTINIC::GetPhrase(-1, 339);
$::s_VariableTable{$::VARPREFIX.'DELIVERTO'} 		= ACTINIC::GetPhrase(-1, 340);
$::s_VariableTable{$::VARPREFIX.'DATETEXT'} 			= ACTINIC::GetPhrase(-1, 342);
$::s_VariableTable{$::VARPREFIX.'ORDERNUMBERTEXT'}	= ACTINIC::GetPhrase(-1, 343);
$::s_VariableTable{$::VARPREFIX.'MOVING'} = $::g_BillContact{'MOVING'} ? ACTINIC::GetPhrase(-1, 1914) : ACTINIC::GetPhrase(-1, 1915);
my ($sInvoiceName);
undef $sTemp;
if ((length $::g_BillContact{'NAME'}) > 0)
{
$sTemp = $::g_BillContact{'SALUTATION'} . " " . $::g_BillContact{'NAME'};
@Response = ACTINIC::EncodeText($sTemp);
$sInvoiceName .= $Response[1] . "<BR>\n";
}
$::s_VariableTable{$::VARPREFIX.'INVOICENAME'} = $sInvoiceName;
{
my %HashID = (
'JOBTITLE' => 'INVOICEJOBTITLE',
'COMPANY'  => 'INVOICECOMPANY',
'ADDRESS1' => 'INVOICEADDRESS1',
'ADDRESS2' => 'INVOICEADDRESS2',
'ADDRESS3' => 'INVOICEADDRESS3',
'ADDRESS4' => 'INVOICEADDRESS4',
'POSTALCODE' => 'INVOICEPOSTCODE',
'COUNTRY'  => 'INVOICECOUNTRY',
'PHONE'    => 'INVOICEPHONE|-1|348',
'MOBILE'    => 'INVOICEMOBILE|0|2453',
'FAX'      => 'INVOICEFAX|-1|349',
'EMAIL'    => 'INVOICEEMAIL|-1|350',
'USERDEFINED' => 'INVOICEUSERDEFINED|0|14'
);
ActinicOrder::HashToVarTable(\%HashID, \%::g_BillContact, \%::s_VariableTable);
}
my ($sDeliveryName);
if ((length $::g_ShipContact{'NAME'}) > 0)
{
$sTemp = $::g_ShipContact{'SALUTATION'} . " " . $::g_ShipContact{'NAME'};
@Response = ACTINIC::EncodeText($sTemp);
$sDeliveryName .= $Response[1] . "<BR>\n";
}
$::s_VariableTable{$::VARPREFIX.'DELIVERYNAME'} = $sDeliveryName;
{
my %HashID = (
'JOBTITLE' 	=> 'DELIVERYJOBTITLE',
'COMPANY'  	=> 'DELIVERYCOMPANY',
'ADDRESS1' => 'DELIVERYADDRESS1',
'ADDRESS2' => 'DELIVERYADDRESS2',
'ADDRESS3' => 'DELIVERYADDRESS3',
'ADDRESS4' => 'DELIVERYADDRESS4',
'POSTALCODE' => 'DELIVERYPOSTCODE',
'COUNTRY'  	=> 'DELIVERYCOUNTRY',
'PHONE'    	=> 'DELIVERYPHONE|-1|348',
'MOBILE'    	=> 'DELIVERMOBILE|1|2454',
'FAX'      	=> 'DELIVERYFAX|-1|349',
'EMAIL'    	=> 'DELIVERYEMAIL|-1|350',
'USERDEFINED' => 'DELIVERYUSERDEFINED|1|13'
);
ActinicOrder::HashToVarTable(\%HashID, \%::g_ShipContact, \%::s_VariableTable);
}
@Response = $::Session->GetCartObject($bRedisplay);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
@Response = $pCartObject->SummarizeOrder($::FALSE);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($Ignore0, $Ignore1, $nSubTotal, $nShipping, $nTax1, $nTax2, $nTotal, $nShippingTax1, $nShippingTax2,
$nHandling, $nHandlingTax1, $nHandlingTax2) = @Response;
@Response = ActinicOrder::FormatPrice($nTotal, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $sTotal = $Response[4];
$::s_VariableTable{$::VARPREFIX.'ACTINICORDERTOTAL'} = $nTotal;
$::s_VariableTable{$::VARPREFIX.'TEXTORDERTOTAL'} = $sTotal;
$::s_VariableTable{$::VARPREFIX.'FORMATTEDORDERTOTALCGI'} = ACTINIC::EncodeText2($sTotal, $::FALSE);
$::s_VariableTable{$::VARPREFIX.'FORMATTEDORDERTOTALHTML'} = ACTINIC::EncodeText2($sTotal);
@Response = ActinicOrder::FormatPrice($nTotal, $::FALSE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $sTotal = $Response[4];
$::s_VariableTable{$::VARPREFIX.'NUMERICORDERTOTALCGI'} = ACTINIC::EncodeText2($sTotal, $::FALSE);
$::s_VariableTable{$::VARPREFIX.'NUMERICORDERTOTAL'} = $sTotal;
@Response = ACTINIC::GetDigitalContent($pCartList);
if ($Response[0] == $::FAILURE)
{
return (@Response);
}
my %hDDLinks = %{$Response[2]};
my $sDownloadMessage;
if (keys %hDDLinks > 0)
{
$sDownloadMessage = ACTINIC::GetPhrase(-1, 2250, $$::g_pSetupBlob{'DD_EXPIRY_TIME'});
}
elsif ($bMailDelayed == $::TRUE)
{
$sDownloadMessage = ACTINIC::GetPhrase(-1, 2309);
}
$::s_VariableTable{$::VARPREFIX.'DOWNLOADINSTRUCTION'} = $sDownloadMessage;
my ($sPaymentPanel);
if ($nTotal > 0 && $$::g_pSetupBlob{'PRICES_DISPLAYED'}) # if their is money involed, display the payment panel
{
$::s_VariableTable{$::VARPREFIX.'PAYMENTMETHODTITLE'} = ACTINIC::GetPhrase(-1, 79); # "Payment Method"
undef $sPaymentPanel;
if (length $::g_PaymentInfo{'PONO'} > 0)
{
$sPaymentPanel = "<TR>\n";
@Response = ACTINIC::EncodeText($::g_PaymentInfo{'PONO'});
$sPaymentPanel .= "<TD BGCOLOR=\"$$::g_pSetupBlob{FORM_EMPHASIS_COLOR}\"><FONT FACE=\"ARIAL\" SIZE=\"2\"><B>" .
ACTINIC::GetPhrase(-1, 81) . ":</B></FONT></TD><TD COLSPAN=2><FONT FACE=\"ARIAL\" SIZE=\"2\">";
$sPaymentPanel .= $Response[1] . "</FONT></TD>";
$sPaymentPanel .= "</TR>\n";
}
$::s_VariableTable{$::VARPREFIX.'PURCHASEORDERNUMBER'} = $sPaymentPanel;
if ($ePaymentMethod == $::PAYMENT_CREDIT_CARD_SEPARATE)
{
push (@::s_KeepDelimiters, 'PAYMENTSENTSEPARATE');
push (@::s_DeleteDelimiters, 'PAYMENTOTHER');
$::s_VariableTable{$::VARPREFIX.'PAYMENTMETHODNAME'} = ACTINIC::GetPhrase(-1, 80);
$::s_VariableTable{$::VARPREFIX.'CREDITCARDTYPETITLE'} = ACTINIC::GetPhrase(-1, 82); # "Acceptable CC's"
my ($nCount, $sCCID, $sCCList);
for ($nCount = 0; $nCount < 12; $nCount++)
{
$sCCID = sprintf('CC%d', $nCount);
if (length $$::g_pSetupBlob{$sCCID} > 0)
{
$sCCList .= $$::g_pSetupBlob{$sCCID} . ", ";
}
}
$sCCList = substr($sCCList, 0, (length $sCCList) - 2);
@Response = ACTINIC::EncodeText($sCCList);
$::s_VariableTable{$::VARPREFIX.'CREDITCARDOPTIONS'} = $Response[1]; # list of acceptable CC's
$::s_VariableTable{$::VARPREFIX.'SELECTONE'} = ACTINIC::GetPhrase(-1, 83); # "Select One"
$::s_VariableTable{$::VARPREFIX.'CREDITCARDNUMBERTITLE'} = ACTINIC::GetPhrase(-1, 84); # "card number"
$::s_VariableTable{$::VARPREFIX.'CREDITCARDISSUENUMBERTITLE'} = ACTINIC::GetPhrase(-1, 85); # "card issue number"
$::s_VariableTable{$::VARPREFIX.'CREDITCARDCCV2TITLE'} = ACTINIC::GetPhrase(5, 8); # "card CCV2 number"
$::s_VariableTable{$::VARPREFIX.'CREDITCARDSTARTDATETITLE'} = ACTINIC::GetPhrase(-1, 86); # "card start date"
$::s_VariableTable{$::VARPREFIX.'CREDITCARDEXPDATETITLE'} = ACTINIC::GetPhrase(-1, 87); # "card exp date"
$::s_VariableTable{$::VARPREFIX.'SIGNATURETITLE'} = ACTINIC::GetPhrase(-1, 88); # "card signature"
}
else
{
push (@::s_DeleteDelimiters, 'PAYMENTSENTSEPARATE');
push (@::s_KeepDelimiters, 'PAYMENTOTHER');
undef $sPaymentPanel;
$sPaymentPanel .= ActinicOrder::EnumToPaymentString($ePaymentMethod);
if (defined $::g_PaymentInfo{'AUTHORIZERESULT'} &&
$::g_PaymentInfo{'AUTHORIZERESULT'} =~ /^0(.+)/)
{
$sPaymentPanel .= "<BR>" . ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(-1, 1969) .
ACTINIC::GetPhrase(-1, 1964) .
ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 1975);
}
$::s_VariableTable{$::VARPREFIX.'PAYMENTMETHODNAME'} = $sPaymentPanel;
if ($ePaymentMethod == $::PAYMENT_CREDIT_CARD)
{
push (@::s_KeepDelimiters, 'PAYMENTCREDITCARD');
$::s_VariableTable{$::VARPREFIX.'CREDITCARDTITLE'} = ACTINIC::GetPhrase(-1, 94); # "Credit Card"
if (length $::g_PaymentInfo{'CARDTYPE'} > 0) # if a credit card type exists, display it
{
$sPaymentPanel = $::g_PaymentInfo{'CARDTYPE'};
}
else											 # the credit card type is blank (applet does not return it)
{
$sPaymentPanel = "(" . ACTINIC::GetPhrase(-1, 95) . ")";
}
$::s_VariableTable{$::VARPREFIX.'CREDITCARDTYPE'} = $sPaymentPanel;
}
else
{
push (@::s_DeleteDelimiters, 'PAYMENTCREDITCARD');
}
}
push (@::s_KeepDelimiters, 'PAYMENTPANEL');
}
else
{
push (@::s_DeleteDelimiters, 'PAYMENTPANEL');
}
if (ACTINIC::IsPromptHidden(0, 13))
{
push (@::s_DeleteDelimiters, 'MOVINGSTATUS');
}
else
{
push (@::s_KeepDelimiters, 'MOVINGSTATUS');
}
if (!$::g_ShipInfo{'USERDEFINED'})
{
push (@::s_DeleteDelimiters, 'DELIVERYINSTRUCTION');
}
else
{
$::s_VariableTable{$::VARPREFIX.'DELIVERYINSTRUCTION_LABEL'} = ACTINIC::GetPhrase(-1, 2044);
$::s_VariableTable{$::VARPREFIX.'DELIVERYINSTRUCTION_TEXT'} = $::g_ShipInfo{'USERDEFINED'};
push (@::s_KeepDelimiters, 'DELIVERYINSTRUCTION');
}
return ($::SUCCESS, '', \%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
sub GetSaferBlob
{
my ($sOrderNumber, $sPath, $sJavaDateTime) = @_;
my $bUseExternalSuppliedData = ($#_ == 2);
my ($Status, $Message);
$::g_InputHash{'ORDERNUMBER'} = $sOrderNumber;
my (@FieldList, @FieldType);
my $objOrderBlob = new OrderBlob(\@FieldType, \@FieldList);
$objOrderBlob->AddWord($ACTINIC::ORDER_BLOB_MAGIC);
$objOrderBlob->AddByte($::ORDER_BLOB_VERSION);
$objOrderBlob->AddString($sOrderNumber);
$::g_BillContact{'REGION'} = ActinicLocations::GetInvoiceAddressRegionName($::g_BillContact{'ADDRESS4'});
$objOrderBlob->AddContact(\%::g_BillContact);
$::g_ShipContact{'REGION'} = ActinicLocations::GetDeliveryAddressRegionName($::g_ShipContact{'ADDRESS4'});
$objOrderBlob->AddContact(\%::g_ShipContact);
my ($ePaymentMethod) = ActinicOrder::PaymentStringToEnum($::g_PaymentInfo{'METHOD'}); # the payment method is stored as "ENUMERATEDID:DESCRIPTION"
if (defined $$::g_pPaymentList{$::PAYMENT_PAYPAL_PRO} &&
$ePaymentMethod == $::PAYMENT_CREDIT_CARD)
{
$ePaymentMethod = $::PAYMENT_PAYPAL_PRO
}
$objOrderBlob->AddString($$::g_pCatalogBlob{'SINTLSYMBOLS'});
$objOrderBlob->AddWord($ePaymentMethod);
$objOrderBlob->AddString($::g_PaymentInfo{'USERDEFINED'});
if (! defined $::g_BillContact{MOVING} ||
$::g_BillContact{MOVING} eq '')
{
$::g_BillContact{MOVING} = $::FALSE;
}
$objOrderBlob->AddByte($::g_BillContact{'MOVING'});
$objOrderBlob->AddString($::g_GeneralInfo{'WHYBUY'});
$objOrderBlob->AddString($::g_GeneralInfo{'HOWFOUND'});
$objOrderBlob->AddString(GetGeneralUD3());
my @Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
my @aCartData;
($Status, $Message, @aCartData) = ActinicOrder::PreprocessCartToDisplay($pCartList);
my ($pOrderDetail);
my $nShipped = 0;
if ($$::g_pSetupBlob{"DD_AUTO_SHIP"})
{
foreach $pOrderDetail (@aCartData)
{
if ($$pOrderDetail{"SHIPPED"})
{
$nShipped++;
}
my $pComponent;
foreach $pComponent (@{$$pOrderDetail{'COMPONENTS'}})
{
if ($$pComponent{"SHIPPED"})
{
$nShipped++;
}
}
}
}
@Response = $pCartObject->SummarizeOrder($::FALSE);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($Ignore, $Ignore2, $nSubTotal, $nShipping, $nTax1, $nTax2, $nTotal, $nShippingTax1, $nShippingTax2,
$nHandling, $nHandlingTax1, $nHandlingTax2) = @Response;
$objOrderBlob->AddQWord($nSubTotal);
$objOrderBlob->AddDWord(0);
$objOrderBlob->AddQWord(0);
$objOrderBlob->AddQWord($nSubTotal);
$objOrderBlob->AddQWord($nShipping);
$objOrderBlob->AddQWord($nShippingTax1);
$objOrderBlob->AddQWord($nShippingTax2);
$objOrderBlob->AddString($::g_ShipInfo{'USERDEFINED'});
$objOrderBlob->AddByte($$::g_pTaxSetupBlob{'TAX_INCLUSIVE_PRICING'});
$objOrderBlob->AddByte($ActinicOrder::g_pCurrentTaxZone->{'TAX_1'} != -1);
$objOrderBlob->AddByte($ActinicOrder::g_pCurrentTaxZone->{'TAX_2'} != -1);
@Response = ActinicOrder::GetTaxModelOpaqueData();
if($Response[0] != $::SUCCESS)
{
return(@Response);
}
$objOrderBlob->AddString($Response[2]);
my $sTaxKey;
foreach $sTaxKey (('TAX_1', 'TAX_2'))
{
$objOrderBlob->AddString(ActinicOrder::GetTaxOpaqueData($sTaxKey));
}
$objOrderBlob->AddByte($::g_TaxInfo{'EXEMPT1'});
$objOrderBlob->AddString($::g_TaxInfo{'EXEMPT1DATA'});
$objOrderBlob->AddByte($::g_TaxInfo{'EXEMPT2'});
$objOrderBlob->AddString($::g_TaxInfo{'EXEMPT2DATA'});
$objOrderBlob->AddQWord($nTax1);
$objOrderBlob->AddQWord($nTax2);
$objOrderBlob->AddString($::g_TaxInfo{'USERDEFINED'});
$objOrderBlob->AddQWord($nTotal);
my ($nLineCount) = CountValidCartItems($pCartList);
$nLineCount += $pCartObject->GetAdjustmentCount();
push (@FieldList, $nLineCount);
my $nLineCountIndex = $#FieldList;
push (@FieldType, $::RBDWORD);
$objOrderBlob->AddDWord($nShipped);
$objOrderBlob->AddDWord(0);
if($bUseExternalSuppliedData)
{
$objOrderBlob->AddString($sJavaDateTime);
}
else
{
my ($sDate) = ACTINIC::GetActinicDate();
$objOrderBlob->AddString($sDate);
$::g_PaymentInfo{ORDERDATE} = $sDate;
UpdateCheckoutRecord();
}
$objOrderBlob->AddString($::g_PaymentInfo{'PONO'});
$objOrderBlob->AddString("");
if ($::g_ShipInfo{'ADVANCED'} eq "" &&
$nShipping == 0)
{
$objOrderBlob->AddString("ShippingClass;-1;ShippingZone;-1;BasisTotal;1.000000;Simple;0;");
}
else
{
$objOrderBlob->AddString($::g_ShipInfo{'ADVANCED'});
}
$objOrderBlob->AddString($$::g_pSetupBlob{'AUTH_KEY'});
$objOrderBlob->AddString($::g_LocationInfo{DELIVERY_COUNTRY_CODE});
$objOrderBlob->AddString($::g_LocationInfo{DELIVERY_REGION_CODE});
$objOrderBlob->AddString($::g_LocationInfo{INVOICE_COUNTRY_CODE});
$objOrderBlob->AddString($::g_LocationInfo{INVOICE_REGION_CODE});
if ($$::g_pSetupBlob{MAKE_SHIPPING_CHARGE})
{
@Response = ActinicOrder::CallShippingPlugIn();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
elsif (${$Response[2]}{GetShippingDescription} != $::SUCCESS)
{
return(${$Response[2]}{GetShippingDescription}, ${$Response[3]}{GetShippingDescription});
}
$objOrderBlob->AddString($Response[5]);
}
else
{
$objOrderBlob->AddString('');
}
$objOrderBlob->AddByte($$::g_pSetupBlob{SHARED_SSL_TEST_MODE});
$objOrderBlob->AddQWord($nHandling);
$objOrderBlob->AddQWord($nHandlingTax1);
$objOrderBlob->AddQWord($nHandlingTax2);
$objOrderBlob->AddString($::g_ShipInfo{HANDLING});
if ($$::g_pSetupBlob{MAKE_HANDLING_CHARGE})
{
@Response = ActinicOrder::CallShippingPlugIn();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
elsif (${$Response[2]}{GetHandlingDescription} != $::SUCCESS)
{
return(${$Response[2]}{GetHandlingDescription}, ${$Response[3]}{GetHandlingDescription});
}
$objOrderBlob->AddString($Response[9]);
}
else
{
$objOrderBlob->AddString('');
}
my $sUserDigest = $ACTINIC::B2B->Get('UserDigest');
if ($::g_InputHash{BUYERID} && $::g_InputHash{CUSTOMERID})
{
$objOrderBlob->AddDWord($::g_InputHash{BUYERID});
$objOrderBlob->AddDWord($::g_InputHash{CUSTOMERID});
}
elsif( $sUserDigest )
{
my ($status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sUserDigest, ACTINIC::GetPath());
if ($status != $::SUCCESS)
{
return ($status, $sMessage);
}
my $nBuyerID = $$pBuyer{ID};
my $nCustomerID = $$pBuyer{AccountID};
$objOrderBlob->AddDWord($nBuyerID);
$objOrderBlob->AddDWord($nCustomerID);
}
else
{
$objOrderBlob->AddDWord(-1);
$objOrderBlob->AddDWord(-1);
}
$objOrderBlob->AddString($::g_sSignature);
my (@aPrefixes) = ('', 'SHIP_', 'HAND_');
my ($sPrefix);
foreach $sPrefix (@aPrefixes)
{
@Response = PrepareOrderTaxOpaqueData($sPrefix);
if($Response[0] != $::SUCCESS)
{
return(@Response);
}
$objOrderBlob->AddString($Response[2]);
}
if($::g_ShipInfo{SSP} =~ /^SSPID=(\d+);/)
{
$objOrderBlob->AddDWord($1);
$objOrderBlob->AddString($::g_ShipInfo{SSP});
}
else
{
$objOrderBlob->AddDWord(-1);
$objOrderBlob->AddString('');
}
$objOrderBlob->AddString($::s_Ship_sSeparatePackageDetails);
$objOrderBlob->AddString($::s_Ship_sMixedPackageDetails);
$objOrderBlob->AddByte($::g_BillContact{'AGREEDTANDC'});
no strict 'refs';
my (%CurrentItem, $pProduct);
my $nSequenceNumber = 0;
my $nCartIndex = 0;
foreach $pOrderDetail (@aCartData)
{
%CurrentItem = %$pOrderDetail;
my $pProduct = $CurrentItem{'PRODUCT'};
my $sPrice = $CurrentItem{'ACTINICPRICE'};
my $nTotal = $CurrentItem{'ACTINICCOST'};
$objOrderBlob->AddWord($ACTINIC::ORDER_DETAIL_BLOB_MAGIC);
$objOrderBlob->AddByte($::ORDER_DETAIL_BLOB_VERSION);
$objOrderBlob->AddString($CurrentItem{"REFERENCE"});
$objOrderBlob->AddString($$pProduct{"NAME"});
$objOrderBlob->AddDWord($CurrentItem{"QUANTITY"});
$objOrderBlob->AddQWord($sPrice);
$objOrderBlob->AddQWord($nTotal);
$objOrderBlob->AddQWord($$pProduct{"COST_PRICE"});
if (defined $CurrentItem{"DATE"})
{
$objOrderBlob->AddString($CurrentItem{"DATE"});
}
else
{
$objOrderBlob->AddString("");
}
if (defined $$pProduct{"DATE_PROMPT"})
{
$objOrderBlob->AddString($$pProduct{"DATE_PROMPT"});
}
else
{
$objOrderBlob->AddString("");
}
if (defined $CurrentItem{"INFO"})
{
$objOrderBlob->AddString($CurrentItem{"INFO"});
}
else
{
$objOrderBlob->AddString("");
}
if (defined $$pProduct{"OTHER_INFO_PROMPT"})
{
$objOrderBlob->AddString($$pProduct{"OTHER_INFO_PROMPT"});
}
else
{
$objOrderBlob->AddString("");
}
if (defined $CurrentItem{"SHIPPED"})
{
$objOrderBlob->AddDWord($CurrentItem{"SHIPPED"});
}
else
{
$objOrderBlob->AddDWord(0);
}
$objOrderBlob->AddDWord(0);
my $sBandPrefix = '';
if (ActinicOrder::PricesIncludeTaxes())
{
$sBandPrefix = 'DEF';
}
$objOrderBlob->AddString($CurrentItem{$sBandPrefix . "TAXBAND1"});
$objOrderBlob->AddString($CurrentItem{$sBandPrefix . "TAXBAND2"});
my $nTax = $CurrentItem{"TAX1"};
if ($::g_TaxInfo{'EXEMPT1'} ||
!ActinicOrder::IsTaxApplicableForLocation('TAX_1'))
{
if (ActinicOrder::PricesIncludeTaxes())
{
$nTax = -$nTax;
}
}
$objOrderBlob->AddQWord($nTax);
$nTax = $CurrentItem{"TAX2"};
if ($::g_TaxInfo{'EXEMPT2'} ||
!ActinicOrder::IsTaxApplicableForLocation('TAX_2'))
{
if (ActinicOrder::PricesIncludeTaxes())
{
$nTax = -$nTax;
}
}
$objOrderBlob->AddQWord($nTax);
$objOrderBlob->AddString(FormatShippingOpaqueData($pProduct, 0));
my $bParentExcludedFromShipping = $$pProduct{"EXCLUDE_FROM_SHIP"};
$objOrderBlob->AddQWord(0);
$objOrderBlob->AddDWord(0);
$objOrderBlob->AddDWord(0);
my $sTemp = $$pProduct{'REPORT_DESC'};
$sTemp =~  s/\\\n/\r\n/gi;
$objOrderBlob->AddString($sTemp);
@Response = ActinicOrder::PrepareProductTaxOpaqueData($pProduct, $sPrice, $$pProduct{'PRICE'}, $::FALSE);
if($Response[0] != $::SUCCESS)
{
return(@Response);
}
$objOrderBlob->AddString($Response[2]);
$objOrderBlob->AddByte(0);
$objOrderBlob->AddByte($$pProduct{NO_ORDERLINE});
$objOrderBlob->AddByte($::eOrderLineProduct);
$objOrderBlob->AddDWord($nSequenceNumber);
my $parrProductAdjustments = $pCartObject->GetProductAdjustments($nCartIndex);
my $parrAdjustDetails;
$nCartIndex++;
$nSequenceNumber++;
$objOrderBlob->AddByte(0);
$objOrderBlob->AddString("");
{
my $pComponent;
my $nIndex = 1;
foreach $pComponent (@{$CurrentItem{'COMPONENTS'}})
{
my $sProdName = $$pComponent{'NAME'};
$FieldList[$nLineCountIndex]++;
$objOrderBlob->AddWord($ACTINIC::ORDER_DETAIL_BLOB_MAGIC);
$objOrderBlob->AddByte($::ORDER_DETAIL_BLOB_VERSION);
$objOrderBlob->AddString($$pComponent{REFERENCE});
$objOrderBlob->AddString($sProdName);
$objOrderBlob->AddDWord($$pComponent{QUANTITY});
if ($$pComponent{'SEPARATELINE'})
{
$objOrderBlob->AddQWord($$pComponent{ACTINICPRICE});
$objOrderBlob->AddQWord($$pComponent{ACTINICCOST});
}
else
{
$objOrderBlob->AddQWord(0);
$objOrderBlob->AddQWord(0);
}
$objOrderBlob->AddQWord($$pComponent{COST_PRICE});
$objOrderBlob->AddString("");
$objOrderBlob->AddString("");
$objOrderBlob->AddString("");
$objOrderBlob->AddString("");
if (defined $CurrentItem{"SHIPPED"})
{
$objOrderBlob->AddDWord($$pComponent{QUANTITY});
}
else
{
$objOrderBlob->AddDWord(0);
}
$objOrderBlob->AddDWord(0);
$objOrderBlob->AddString($$pComponent{'TAXBAND1'});
$objOrderBlob->AddString($$pComponent{'TAXBAND2'});
$objOrderBlob->AddQWord($$pComponent{'TAX1'});
$objOrderBlob->AddQWord($$pComponent{'TAX2'});
if ($$pComponent{REFERENCE} ne '')
{
$objOrderBlob->AddString(FormatShippingOpaqueData($pComponent,
$bParentExcludedFromShipping));
}
else
{
$objOrderBlob->AddString('');
}
$objOrderBlob->AddQWord(0);
$objOrderBlob->AddDWord(0);
$objOrderBlob->AddDWord(1);
$objOrderBlob->AddString("");
$objOrderBlob->AddString($$pComponent{'TAX_OPAQUE_DATA'});
$objOrderBlob->AddByte($$pComponent{'SEPARATELINE'});
$objOrderBlob->AddByte($$pProduct{NO_ORDERLINE});
$objOrderBlob->AddByte($::eOrderLineComponent);
$objOrderBlob->AddDWord($nSequenceNumber);
$objOrderBlob->AddByte(0);
$objOrderBlob->AddString("");
$nSequenceNumber++;
$nIndex++;
}
}
foreach $parrAdjustDetails (@$parrProductAdjustments)
{
my $pApplicableProduct = $pProduct;
my $sProdRef = $parrAdjustDetails->[$::eAdjIdxTaxProductRef];
if($sProdRef ne '' &&
$pProduct->{'REFERENCE'} ne $sProdRef)
{
my($nStatus, $sMessage);
($nStatus, $sMessage, $pApplicableProduct) =
ActinicOrder::GetComponentAssociatedProduct($pProduct, $sProdRef);
if($nStatus != $::SUCCESS)
{
return($nStatus, $sMessage);
}
}
$objOrderBlob->AddAdjustment($nSequenceNumber, $parrAdjustDetails, $pApplicableProduct);
$nSequenceNumber++;
}
}
my $parrAdjustments = $pCartObject->GetOrderAdjustments();
my $parrAdjustDetails;
foreach $parrAdjustDetails (@$parrAdjustments)
{
$objOrderBlob->AddAdjustment($nSequenceNumber, $parrAdjustDetails);
$nSequenceNumber++;
}
$parrAdjustments = $pCartObject->GetFinalAdjustments();
foreach $parrAdjustDetails (@$parrAdjustments)
{
$objOrderBlob->AddAdjustment($nSequenceNumber, $parrAdjustDetails);
$nSequenceNumber++;
}
@Response = ACTINIC::OpenWriteBlob("memory");
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::WriteBlob(\@FieldList, \@FieldType);
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::CloseWriteBlob();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
return($::SUCCESS, '', $Response[2]);
}
sub CompleteOrder
{
ActinicOrder::ParseAdvancedTax();
my $sPath = ACTINIC::GetPath();
my ($Status, $Message, $sOrderNumber);
($Status, $Message, $sOrderNumber) = GetOrderNumber();
if ($Status != $::SUCCESS)
{
return ($Status, $Message);
}
my @Response = GetSaferBlob($sOrderNumber, $sPath);
if($Response[0] != $::SUCCESS)
{
return(@Response);
}
my ($SaferBlob) = $Response[2];
my $DHBlob;
if (length $::g_PaymentInfo{'CARDNUMBER'} > 0 ||
length $::g_PaymentInfo{'CARDTYPE'} > 0 ||
length $::g_PaymentInfo{'EXPYEAR'} > 0 ||
length $::g_PaymentInfo{'EXPMONTH'} > 0)
{
my (@FieldList, @FieldType);
push (@FieldList, $::g_PaymentInfo{'CARDNUMBER'});
push (@FieldType, $::RBSTRING);
push (@FieldList, $::g_PaymentInfo{'CARDTYPE'});
push (@FieldType, $::RBSTRING);
push (@FieldList, $::g_PaymentInfo{'EXPYEAR'} . '/' . $::g_PaymentInfo{'EXPMONTH'});
push (@FieldType, $::RBSTRING);
push (@FieldList, $::g_PaymentInfo{'CARDVV2'});
push (@FieldType, $::RBSTRING);
if (ActinicOrder::PaymentStringToEnum($::g_PaymentInfo{'METHOD'}) == $::PAYMENT_CREDIT_CARD)
{
push (@FieldList, $::g_PaymentInfo{'CARDISSUE'});
push (@FieldType, $::RBSTRING);
push (@FieldList, $::g_PaymentInfo{'STARTYEAR'} .
($::g_PaymentInfo{'STARTYEAR'} eq "" ? '' : '/') .
$::g_PaymentInfo{'STARTMONTH'});
push (@FieldType, $::RBSTRING);
}
else
{
push (@FieldList, 0);
push (@FieldType, $::RBSTRING);
push (@FieldList, "");
push (@FieldType, $::RBSTRING);
}
@Response = ACTINIC::OpenWriteBlob("memory");
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::WriteBlob(\@FieldList, \@FieldType);
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::CloseWriteBlob();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$DHBlob = $Response[2];
}
my $EncryptedBlob;
eval 'require ActEncrypt1024;';
if ($@)
{
ActinicEncrypt::InitEncrypt(@{$$::g_pSetupBlob{PUBLIC_KEY_128BIT}});
$EncryptedBlob = ActinicEncrypt::Encrypt($DHBlob, $SaferBlob);
}
else
{
my $sKey;
my $sKeyLength = $$::g_pSetupBlob{'KEY_LENGTH'};
my ($nCount);
my ($pKey) = $$::g_pSetupBlob{'PUBLIC_KEY_' . $sKeyLength . 'BIT'};
for ($nCount = ($sKeyLength / 8) - 1; $nCount >= 0; $nCount--)
{
$sKey .= sprintf('%2.2x', $$pKey[$nCount]);
}
my ($nDataLength, $nPhraseID);
($Status, $nPhraseID, $EncryptedBlob, $nDataLength) =
ActEncrypt1024::EncryptData($sKey, $SaferBlob, length $SaferBlob, $DHBlob, length $DHBlob);
if ($Status != $::SUCCESS)
{
return ($Status, ACTINIC::GetPhrase(-1, $nPhraseID));
}
}
my $sError = RecordOrder($sOrderNumber, \$EncryptedBlob);
if ($sError)
{
return($::FAILURE, NotifyOfError($sError));
}
return ($::SUCCESS, "", 0, 0);
}
sub UpdateCheckoutRecord
{
my (%EmptyPaymentInfo);
$EmptyPaymentInfo{'METHOD'} 		= $::g_PaymentInfo{'METHOD'};
$EmptyPaymentInfo{'USERDEFINED'} = $::g_PaymentInfo{'USERDEFINED'};
$EmptyPaymentInfo{'PONO'}			= $::g_PaymentInfo{'PONO'};
$EmptyPaymentInfo{'COUPONCODE'}	= $::g_PaymentInfo{'COUPONCODE'};
$EmptyPaymentInfo{'ORDERNUMBER'}	= $::g_PaymentInfo{'ORDERNUMBER'};
$EmptyPaymentInfo{'ORDERDATE'}	= $::g_PaymentInfo{'ORDERDATE'};
$EmptyPaymentInfo{'BUYERHASH'}	= $ACTINIC::B2B->Get('UserDigest');
$EmptyPaymentInfo{'BUYERNAME'}	= $ACTINIC::B2B->Get('UserName');
$EmptyPaymentInfo{'BASEFILE'}	= $ACTINIC::B2B->Get('BaseFile');
$EmptyPaymentInfo{'AUTHORIZERESULT'}	= $::g_PaymentInfo{'AUTHORIZERESULT'};
$::g_GeneralInfo{'USERDEFINED'} = GetGeneralUD3();
if ($ACTINIC::B2B->Get('UserDigest') ||
defined $::g_PaymentInfo{'SCHEDULE'})
{
$EmptyPaymentInfo{'SCHEDULE'} 	= $::g_PaymentInfo{'SCHEDULE'};
}
return ($::Session->UpdateCheckoutInfo(\%::g_BillContact, \%::g_ShipContact, \%::g_ShipInfo, \%::g_TaxInfo,
\%::g_GeneralInfo, \%EmptyPaymentInfo, \%::g_LocationInfo));
}
sub GetCancelPage
{
my ($sRefPage) = $::Session->GetLastShopPage();
if ($$::g_pSetupBlob{UNFRAMED_CHECKOUT} &&
$$::g_pSetupBlob{UNFRAMED_CHECKOUT_URL})
{
$sRefPage = $$::g_pSetupBlob{UNFRAMED_CHECKOUT_URL};
}
my @Response = ACTINIC::BounceToPagePlain(0, undef, undef,
$::g_sWebSiteUrl, $::g_sContentUrl, $::g_pSetupBlob, $sRefPage, \%::g_InputHash);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
return;
}
return ($Response[2]);
}
sub DoOfflineAuthorization
{
my	$sPath = ACTINIC::GetPath();
my @Response = ACTINIC::ReadPaymentFile($sPath);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($sFilename, $pPaymentMethodHash, $ePaymentMethod);
if($::g_InputHash{'ACTION'} =~ m/^OFFLINE_AUTHORIZE_(\d+)$/i)
{
$ePaymentMethod = $1;
}
else
{
return;
}
$pPaymentMethodHash = $$::g_pPaymentList{$ePaymentMethod};
$sFilename = $$pPaymentMethodHash{POST_PROCESS};
my (@Response) = CallPlugInScript($sFilename);
}
sub RecordAuthorization
{
my ($psCgiInput) = @_;
unless (defined $psCgiInput)
{
$psCgiInput = \$::g_OriginalInputData;
}
if (length $::g_InputHash{ON} < 5)
{
return(ACTINIC::GetPhrase(-1, 185, (length $::g_InputHash{ON}), $::g_InputHash{ON}));
}
my ($ePaymentMethod, $sRemoteIP);
if($::g_InputHash{'ACTION'} =~ m/^AUTHORIZE_(\d+)$/i)
{
$ePaymentMethod = $1;
}
elsif ($::g_InputHash{'ACTION'} =~ m/^OFFLINE_AUTHORIZE_(\d+)$/i)
{
$ePaymentMethod = $1;
}
$sRemoteIP = $ENV{REMOTE_ADDR};
my ($bIPRangeDefined, $sIPRange) = ACTINIC::IsCustomVarDefined("ACT_IPCHECK_" . $ePaymentMethod);
if ($bIPRangeDefined)
{
if (!ACTINIC::IsValidIP($sRemoteIP, $sIPRange))
{
$::Session->IPCheckFailed();
$::Session->SaveSession();
my $sMessage = ACTINIC::GetPhrase(-1, 2307, $sIPRange, $sRemoteIP, $::g_OriginalInputData);
ACTINIC::RecordErrors($sMessage, ACTINIC::GetPath());
ACTINIC::SendMail($::g_sSmtpServer,
$::g_pSetupBlob->{'EMAIL'},
$$::g_pPaymentList{$ePaymentMethod}{PROMPT}." - IP Address Check Exception for order number ".$::g_InputHash{ON},
$sMessage);
}
}
my (@FieldList, @FieldType);
push (@FieldList, hex("22"));
push (@FieldType, $::RBWORD);
push (@FieldList, 2);
push (@FieldType, $::RBBYTE);
push (@FieldList, $ePaymentMethod);
push (@FieldType, $::RBDWORD);
push (@FieldList, $::g_InputHash{TM} ? 1 : 0);
push (@FieldType, $::RBBYTE);
push (@FieldList, $$psCgiInput);
push (@FieldType, $::RBSTRING);
my $sPath = ACTINIC::GetPath();
my @Response = ACTINIC::OpenWriteBlob('memory');
my ($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
my $sError = (0 == length $Response[1]) ? "Error opening the write blob" : $Response[1];
return(NotifyOfError($sError));
}
@Response = ACTINIC::WriteBlob(\@FieldList, \@FieldType);
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
my $sError = (0 == length $Response[1]) ? "Error writing blob" : $Response[1];
return(NotifyOfError($sError));
}
@Response = ACTINIC::CloseWriteBlob();
if ($Response[0] != $::SUCCESS)
{
my $sError = (0 == length $Response[1]) ? "Error closing the write blob" : $Response[1];
return(NotifyOfError($sError));
}
my ($ClearBlob) = $Response[2];
my ($EncryptedBlob);
ActinicEncrypt::InitEncrypt(@{$$::g_pSetupBlob{PUBLIC_KEY_128BIT}});
$EncryptedBlob = ActinicEncrypt::Encrypt(undef, $ClearBlob);
my ($sTempFilename) = $::Session->GetSessionFileFolder() . $::g_InputHash{ON} . '.occ';
ACTINIC::SecurePath($sTempFilename);
my $sOCCFileName = $::g_InputHash{ON} . '.occ';
my ($sOCCFilePath) = $::Session->GetSessionFileFolder() . $sOCCFileName;
ACTINIC::SecurePath($sOCCFilePath);
while (-e $sOCCFilePath)
{
my $nIncremental;
($sOCCFileName, $nIncremental) = split /_/, $sOCCFileName;
$sOCCFileName = $::g_InputHash{ON} . "_" . ++$nIncremental . '.occ';
$sOCCFilePath = $::Session->GetSessionFileFolder() . $sOCCFileName;
ACTINIC::SecurePath($sOCCFilePath);
}
my ($sTempFilename) = $sOCCFilePath;
unless ( open (COMPLETEFILE, ">" . $sTempFilename))
{
return(ACTINIC::GetPhrase(-1, 21, $sTempFilename, $!));
}
binmode COMPLETEFILE;
unless (print COMPLETEFILE $EncryptedBlob)
{
my ($sError) = $!;
close COMPLETEFILE;
unlink $sTempFilename;
return(ACTINIC::GetPhrase(-1, 28, $sTempFilename, $sError));
}
close COMPLETEFILE;
my $sOCCValidationData = GetOCCValidationData();
$sOCCValidationData =~ /AMOUNT=(\d+)/;
my $sOrderAmount =   $1;
if ($sOrderAmount == $::g_InputHash{'AM'})
{
$::Session->PaymentMade();
}
my $sMailFile = $::Session->GetSessionFileFolder() . $::g_InputHash{ON} . ".mail";
if (! (-e $sMailFile))
{
$::Session->SaveSession();
}
return (undef);
}
sub LogData
{
if ($nDebugLogLevel)
{
my $sLogData = shift;
ACTINIC::RecordErrors($sLogData, ACTINIC::GetPath());
}
}
sub CallOCCPlugIn
{
local ($::sOrderNumber, $::nOrderTotal, %::PriceFormatBlob, %::InvoiceContact, $::sCallBackURLUser, %::OCCShipData);
local ($::sCallBackURLAuth, $::sCallBackURLBack, $::pCartList);
my ($Status, $Message);
my @Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
@Response = $pCartObject->SummarizeOrder($::TRUE);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$::nOrderTotal = $Response[6];
%::PriceFormatBlob = %{$::g_pCatalogBlob};
%::InvoiceContact = %::g_BillContact;
%::OCCShipData = %::g_ShipContact;
($Status, $Message, $::sOrderNumber) = GetOrderNumber();
if ($Status != $::SUCCESS)
{
return ($Status, $Message, undef);
}
my		$sCgiUrl;
if ($$::g_pSetupBlob{'SSL_USEAGE'} eq 1)
{
$sCgiUrl = $$::g_pSetupBlob{SSL_CGI_URL};
}
else
{
$sCgiUrl = $$::g_pSetupBlob{CGI_URL};
}
my	$ePaymentMethod = ActinicOrder::PaymentStringToEnum($::g_PaymentInfo{'METHOD'}); # the payment method is stored as "ENUMERATEDID:DESCRIPTION"
$::sCallBackURLAuth = sprintf("%sos%6.6d%s?%s", $sCgiUrl, $$::g_pSetupBlob{CGI_ID}, $$::g_pSetupBlob{CGI_EXT},
'PATH=' . ACTINIC::EncodeText2(ACTINIC::GetPath(), $::FALSE) . '&');
$::sCallBackURLAuth .= "SEQUENCE=3&ACTION=AUTHORIZE_$ePaymentMethod&CARTID=$::g_sCartId&";
my ($sBaseUrl) = sprintf("%sos%6.6d%s?%s", $sCgiUrl, $$::g_pSetupBlob{CGI_ID}, $$::g_pSetupBlob{CGI_EXT},
($::g_InputHash{SHOP} ? 'SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) . '&' : ''));
@Response = ACTINIC::EncodeText(ACTINIC::GetPhrase(-1, 504), $::FALSE);
my ($sFinish) = $Response[1];
@Response = ACTINIC::EncodeText($::Session->GetLastShopPage(), $::FALSE);
my $sRefPage = $Response[1];
$::sCallBackURLUser = $sBaseUrl . "SEQUENCE=3&ACTION=$sFinish" .
"&ORDERNUMBER=$::sOrderNumber&REFPAGE=" . $sRefPage . "&";
@Response = ACTINIC::EncodeText(ACTINIC::GetPhrase(-1, 503), $::FALSE);
my $sBack = $Response[1];
my $sReferrer = ACTINIC::GetReferrer();
if ($sReferrer =~ /\?.+/)
{
($sReferrer) = split /\?/, $sReferrer;
}
elsif (length $sReferrer < 3)
{
$sReferrer = sprintf("%sos%6.6d%s", $sCgiUrl, $$::g_pSetupBlob{CGI_ID}, $$::g_pSetupBlob{CGI_EXT});
}
$::sCallBackURLBack = $sReferrer . "?SEQUENCE=" . $::g_nNextSequenceNumber .
"&ACTION=" . $sBack .
"&REFPAGE=" . $sRefPage .
($::g_InputHash{SHOP} ? '&SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) : '') .
"&";
@Response = GetOCCScript(ACTINIC::GetPath());
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($sScript) = $Response[2];
local $::sPath = ACTINIC::GetPath();
local $::sWebSiteUrl = $::g_sWebSiteUrl;
local $::sContentUrl = $::g_sContentUrl;
local $::sCartID = $::g_sCartId;
if($ACTINIC::B2B->Get('UserDigest'))
{
$::sContentUrl = $ACTINIC::B2B->Get('BaseFile');
$::sContentUrl =~ s#/[^/]*$#/#;
$::sWebSiteUrl = $::g_sAccountScript;
$::sWebSiteUrl .= ($::g_InputHash{SHOP} ? '?SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) . '&': '?');
$::sWebSiteUrl .= 'PRODUCTPAGE=';
}
eval
{
require Digest::MD5;
import Digest::MD5 'md5_hex';
};
if ($@)
{
require di000001;
import Digest::Perl::MD5 'md5_hex';
}
if (eval($sScript) != $::SUCCESS)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 170, $@));
}
if ($::sRedirectURL)
{
LogData ("CallOCCPlugIn:\n$::sRedirectURL");
}
else
{
LogData ("CallOCCPlugIn:\n$::sHTML");
}
return ($::eStatus, $::sErrorMessage, $::sHTML);
}
sub GetOCCScript
{
if (defined $::s_sOCCScript)# if it is already in memory,
{
return ($::SUCCESS, "", $::s_sOCCScript);
}
if ($#_ < 0)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'GetOCCScript'), 0, 0);
}
my ($sPath) = $_[0];
my	$ePaymentMethod = ActinicOrder::PaymentStringToEnum($::g_PaymentInfo{'METHOD'}); # the payment method is stored as "ENUMERATEDID:DESCRIPTION"
my ($sFilename, $pPaymentMethodHash);
$pPaymentMethodHash = $$::g_pPaymentList{$ePaymentMethod};
$sFilename = $sPath . $$pPaymentMethodHash{BOUNCE_SCRIPT};
my @Response = ACTINIC::ReadAndVerifyFile($sFilename);
if ($Response[0] == $::SUCCESS)
{
$::s_sOCCScript = $Response[2];
}
return (@Response);
}
sub GetOrderNumber
{
if (length $::s_sOrderNumber > 0)
{
return ($::SUCCESS, undef, $::s_sOrderNumber, undef);
}
my (@CharacterSet) = split(//, "3456789ABCDEFGHJKLMNPQRSTUVWXY");
my $sInitials;
my $sName = $::g_BillContact{'NAME'};
$sName =~ s/[^a-zA-Z0-9 ]//g;
$sName =~ s/^\s*//;
$sName =~ s/\s*$//;
if (!$sName)
{
$sInitials = substr("00" . ACTINIC::Modulus($$, 100), -2);
}
elsif (2 >= length $sName)
{
$sInitials = substr($sName . ACTINIC::Modulus($$, 10), 0, 2);
}
elsif ($sName =~ /([^ \t\r\n]+)\s*([^ \t\r\n]+)\s*([^ \t\r\n]*)/) # two or three names - get the true initials
{
my $s = $3 ? $3 : $2;
$sInitials = substr($1, 0, 1) . substr($s, 0, 1);
}
else
{
$sInitials = substr($sName, 0, 2);
}
$sInitials = uc($sInitials);
my $sPostCode = uc($::g_BillContact{POSTALCODE});
$sPostCode =~ s/[^A-Z0-9]//g;
srand(time() ^($$ + ($$ << 15)));
while ( (length $sPostCode) < 4)
{
$sPostCode = int(rand(10000)) . $sPostCode; # tack on some pseudo-random numbers
}
$sPostCode = substr($sPostCode, -4, 4);
$sPostCode =~ s/\s/_/g;
my $nNumberBreakRetries = 1;
my $sUnLockFile = ACTINIC::GetPath() . 'Order.num';
my $sBackupFile = ACTINIC::GetPath() . 'Backup.num';
my $sLockFile = ACTINIC::GetPath() . 'OrderLock.num';
ACTINIC::SecurePath($sUnLockFile);
ACTINIC::SecurePath($sBackupFile);
ACTINIC::SecurePath($sLockFile);
START_AGAIN:
if (!-e $sUnLockFile &&
!-e $sLockFile &&
!-e $sBackupFile)
{
unless (open (LOCK, ">$sUnLockFile"))
{
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 182, $sUnLockFile, $!)), undef, undef);
}
binmode LOCK;
my $nCounter = pack("N", 0);
unless (print LOCK $nCounter)
{
my $sError = $!;
close (LOCK);
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 28, $sUnLockFile, $sError)), undef, undef);
}
close (LOCK);
sleep 2;
}
my $nByteLength = 4;
if (!-e $sUnLockFile &&
!-e $sLockFile &&
-e $sBackupFile)
{
unless (open (BACK, "<$sBackupFile"))
{
my $sError = $!;
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 21, $sBackupFile, $sError)), undef, undef);
}
binmode BACK;
my $nCounter;
unless ($nByteLength == read (BACK, $nCounter, $nByteLength))
{
my $sError = $!;
close (BACK);
if (!unlink($sBackupFile))
{
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 201, $!)), undef, undef);
}
sleep 2;
NotifyOfError(ACTINIC::GetPhrase(-1, 2304));
goto START_AGAIN;
}
close (BACK);
unless (open (LOCK, ">$sUnLockFile"))
{
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 182, $sUnLockFile, $!)), undef, undef);
}
binmode LOCK;
unless (print LOCK $nCounter)
{
my $sError = $!;
close (LOCK);
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 28, $sUnLockFile, $sError)), undef, undef);
}
close (LOCK);
sleep 2;
}
my $nDate;
my $bFileIsLocked = $::FALSE;
my $sRenameError;
RETRY:
$bFileIsLocked = $::FALSE;
if ($nNumberBreakRetries < 0)
{
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 201, $sRenameError)), undef, undef);
}
my $nRetries = 20;
while ($nRetries > 0)
{
if (rename($sUnLockFile, $sLockFile))
{
$bFileIsLocked = $::TRUE;
last;
}
$sRenameError = $!;
if (!defined $nDate)
{
my @tmp = stat $sLockFile;
$nDate = $tmp[9];
}
$nRetries--;
sleep 2;
}
if (!$bFileIsLocked)
{
if (-e $sLockFile)
{
my @tmp = stat $sLockFile;
if (!defined $nDate)
{
return ($::FAILURE, (ACTINIC::GetPhrase(-1, 201, $sRenameError)), undef, undef);
}
if (!defined $tmp[9])
{
$nNumberBreakRetries--;
sleep 2;
goto RETRY;
}
if ($nDate == $tmp[9])
{
if ($tmp[7] == 0)
{
if (!unlink($sLockFile))
{
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 201, $!)), undef, undef);
}
sleep 2;
goto START_AGAIN;
}
if (!rename($sLockFile, $sUnLockFile))
{
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 201, $!)), undef, undef);
}
}
$nNumberBreakRetries--;
sleep 2;
goto RETRY;
}
else
{
$nNumberBreakRetries--;
sleep 2;
goto RETRY;
}
}
unless (open (LOCK, "<$sLockFile"))
{
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 182, $sLockFile, $!)), undef, undef);
}
binmode LOCK;
my $nCounterBin;
unless ($nByteLength == read (LOCK, $nCounterBin, $nByteLength))
{
my $sError = $!;
close (LOCK);
unless (open (LOCK, "<$sBackupFile"))
{
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 182, $sBackupFile, $!)), undef, undef);
}
binmode LOCK;
unless ($nByteLength == read (LOCK, $nCounterBin, $nByteLength))
{
close (LOCK);
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 105, $sLockFile, $sError)), undef, undef);
}
}
close (LOCK);
my $nCounter = unpack("N", $nCounterBin);
$nCounter++;
if ($nCounter > 9999999)
{
$nCounter = 0;
}
$nCounterBin = pack ("N", $nCounter);
unless (open (LOCK, ">$sLockFile"))
{
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 182, $sLockFile, $!)), undef, undef);
}
binmode LOCK;
unless (print LOCK $nCounterBin)
{
my $sError = $!;
close (LOCK);
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 28, $sLockFile, $sError)), undef, undef);
}
close (LOCK);
unless (open (LOCK, ">$sBackupFile"))
{
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 182, $sBackupFile, $!)), undef, undef);
}
binmode LOCK;
unless (print LOCK $nCounterBin)
{
my $sError = $!;
close (LOCK);
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 28, $sBackupFile, $sError)), undef, undef);
}
close (LOCK);
if (!rename ($sLockFile, $sUnLockFile))
{
return ($::FAILURE, NotifyOfError(ACTINIC::GetPhrase(-1, 202, $!)), undef, undef);
}
$::s_sOrderNumber = $sInitials . $sPostCode . substr($$::g_pSetupBlob{CGI_ID}, -1) .
substr("0000000" . $nCounter, -7);
return ($::SUCCESS, undef, $::s_sOrderNumber, undef);
}
sub GetGeneralUD3
{
if (ACTINIC::IsPromptHidden(4, 2))
{
return ($::Session->GetReferrer());
}
return ($::g_GeneralInfo{'USERDEFINED'});
}
sub CountValidCartItems
{
if ($#_ != 0)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'CountValidCartItems'), 0, 0);
}
my $pCartList = $_[0];
my ($pOrderDetail, @Response);
my (%CurrentItem, $pProduct);
my $nLineCount = 0;
foreach $pOrderDetail (@$pCartList)
{
%CurrentItem = %$pOrderDetail;
my ($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($CurrentItem{SID});
if ($Status == $::FAILURE)
{
ACTINIC::RecordErrors($Message, ACTINIC::GetPath());
next;
}
@Response = ACTINIC::GetProduct($CurrentItem{"PRODUCT_REFERENCE"},  $sSectionBlobName,
ACTINIC::GetPath());
if ($Response[0] != $::NOTFOUND)
{
$nLineCount++;
}
}
return ($nLineCount);
}
sub EnsurePaymentSelection
{
if (0 < length $::g_PaymentInfo{'METHOD'})
{
return;
}
my @arrPayments;
ActinicOrder::GenerateValidPayments(\@arrPayments);
my $nPaymentOptions = @arrPayments;
if (length $::g_PaymentInfo{'METHOD'} == 0)
{
$::g_PaymentInfo{'METHOD'} = $::PAYMENT_INVOICE_PRE_PAY	;
}
}
sub RecordOrder
{
if ($#_ != 1 && $#_ != 2)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'RecordOrder'), 0, 0);
}
my ($sOrderNumber, $pBlob, $bCheckLightData) = @_;
$::g_PaymentInfo{'ORDERNUMBER'} = $sOrderNumber;
UpdateCheckoutRecord();
my ($Status, $Message, @FileList) = ACTINIC::ReadTheDir($::Session->GetSessionFileFolder());
if ($Status != $::SUCCESS)
{
@FileList = ();
}
my $sFileList = join(' ', @FileList);
my $bOrderExists = ($sFileList =~ /\.ord( |$)/);
if($bCheckLightData)
{
my($nReturnCode, $sError) = CheckSaferEncryptedData($sOrderNumber, $pBlob);
if($nReturnCode != $::TRUE)
{
return($sError);
}
}
my ($sTempFilename) = $::Session->GetSessionFileFolder() . ACTINIC::CleanFileName($sOrderNumber . '.ord');
if (-e $sTempFilename)
{
$::Session->Unlock($sTempFilename);
}
ACTINIC::SecurePath($sTempFilename);
unless ( open (COMPLETEFILE, ">" . $sTempFilename))
{
return(ACTINIC::GetPhrase(-1, 21, $sTempFilename, $!));
}
binmode COMPLETEFILE;
unless (print COMPLETEFILE $$pBlob)
{
my ($sError) = $!;
close COMPLETEFILE;
unlink $sTempFilename;
return(ACTINIC::GetPhrase(-1, 28, $sTempFilename, $sError));
}
close COMPLETEFILE;
$::Session->Lock($sTempFilename);
if (!$bOrderExists &&
$$::g_pSetupBlob{EMAIL_REQUESTED} &&
$$::g_pSetupBlob{EMAIL} ne "" &&
$::g_sSmtpServer ne "")
{
($Status, $Message) = ACTINIC::SendMail($::g_sSmtpServer, $$::g_pSetupBlob{EMAIL},
ACTINIC::GetPhrase(-1, 309), ACTINIC::GetPhrase(-1, 310));
if ($Status != $::SUCCESS)
{
ACTINIC::RecordErrors($Message, ACTINIC::GetPath());
}
}
return (undef);
}
sub CheckSaferEncryptedData
{
my ($sOrderNumber, $pBlob) = @_;
my (@BlobDetails) = unpack("C4NNC*", $$pBlob);
my $sError;
my $nLightDataOffset = 4 + 8 + $BlobDetails[3] + $BlobDetails[4];
my $sBlobLightData = substr($$pBlob, $nLightDataOffset);
my @bFixedKey = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
my @Response = GetSaferBlob($sOrderNumber, ACTINIC::GetPath(),
$::g_PaymentInfo{ORDERDATE});
if($Response[0] != $::SUCCESS)
{
return($::FALSE, $Response[1]);
}
my ($SaferBlob) = $Response[2];
ActinicSafer::InitTables();
my $sActualLight = ActinicEncrypt::EncryptSafer($SaferBlob, @bFixedKey);
if($sActualLight ne $sBlobLightData)
{
return($::FALSE, '000' . ACTINIC::GetPhrase(-1, 360));
}
return($::TRUE, '');
}
sub GenerateCustomerMail
{
my ($sTemplateFile, $paRecipients, $sName, $sMailFile) = @_;
my (@Response, $Status, $Message);
$ACTINIC::B2B->ClearXML();
if (scalar(@{$paRecipients}) == 0)
{
return ($::SUCCESS, "");
}
if (!$$::g_pSetupBlob{EMAIL})
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 279));
}
if (!$::g_sSmtpServer)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 281));
}
@Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
if (!$$::g_pSetupBlob{'EMAIL_CURRENCY_SYMBOL'})
{
$::USEINTLCURRENCYSYMBOL = $::TRUE;
}
@Response = $pCartObject->SummarizeOrder($::TRUE);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($Ignore0, $Ignore1, $nSubTotal, $nShipping, $nTax1, $nTax2, $nTotal, $nShippingTax1, $nShippingTax2, $nHandling, $nHandlingTax1, $nHandlingTax2) = @Response;
@Response = ActinicOrder::SummarizeOrderPrintable(@Response);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($Ignore2, $Ignore3, $sSubTotal, $sShipping, $sHandling, $sTax1, $sTax2, $sTotal) = @Response;
my $pCartList = $pCartObject->GetCartList();
$ACTINIC::B2B->SetXML('CUSTOMER_NAME',$sName);
$ACTINIC::B2B->SetXML('ORDER_NUMBER',$::g_InputHash{ORDERNUMBER});
my ($nSec, $nMin, $nHour, $nMday, $nMon, $nYear, $nWday, $nYday, $nIsdst, $sDate);
($nSec, $nMin, $nHour, $nMday, $nMon, $nYear, $nWday, $nYday, $nIsdst) = gmtime(time);
$nMon++;
$nYear += 1900;
my ($sMon) = $::g_InverseMonthMap{$nMon};
my ($sDatePrompt) = ACTINIC::FormatDate($nMday, $sMon, $nYear);
$sDate = $sDatePrompt . sprintf(" %2.2d:%2.2d GMT", $nHour, $nMin);
if ($::Session->IsIPCheckFailed())
{
$sDate .= "\r\n" . ACTINIC::GetPhrase(-1, 2308);
}
$ACTINIC::B2B->SetXML('ORDER_DATE',$sDate);
my %hashShipMap = (
'SALUTATION'	=> 'SHIP_SALUTATION',
'NAME'			=> 'SHIP_NAME',
'JOBTITLE'		=> 'SHIP_TITLE',
'COMPANY'		=> 'SHIP_COMPANY',
'ADDRESS1'		=> 'SHIP_ADDRESS1',
'ADDRESS2'		=> 'SHIP_ADDRESS2',
'ADDRESS3'		=> 'SHIP_ADDRESS3',
'ADDRESS4'		=> 'SHIP_ADDRESS4',
'POSTALCODE'	=> 'SHIP_POSTCODE',
'COUNTRY'		=> 'SHIP_COUNTRY',
'PHONE'			=> 'SHIP_PHONE',
'FAX'				=> 'SHIP_FAX',
'EMAIL'			=> 'SHIP_EMAIL',
'USERDEFINED'	=> 'SHIP_USERDEFINED',
);
my ($sTempUserDefined) = $::g_ShipContact{'USERDEFINED'};
if (!$::g_BillContact{'SEPARATE'} &&
$::g_BillContact{'USERDEFINED'})
{
$::g_ShipContact{'USERDEFINED'} = $::g_BillContact{'USERDEFINED'};
}
SetXMLFromHash(\%hashShipMap, \%::g_ShipContact);
$::g_ShipContact{'USERDEFINED'} = $sTempUserDefined;
my %hashBillMap = (
'SALUTATION'	=> 'BILL_SALUTATION',
'NAME'			=> 'BILL_NAME',
'JOBTITLE'		=> 'BILL_TITLE',
'COMPANY'		=> 'BILL_COMPANY',
'ADDRESS1'		=> 'BILL_ADDRESS1',
'ADDRESS2'		=> 'BILL_ADDRESS2',
'ADDRESS3'		=> 'BILL_ADDRESS3',
'ADDRESS4'		=> 'BILL_ADDRESS4',
'POSTALCODE'	=> 'BILL_POSTCODE',
'COUNTRY'		=> 'BILL_COUNTRY',
'PHONE'			=> 'BILL_PHONE',
'FAX'				=> 'BILL_FAX',
'EMAIL'			=> 'BILL_EMAIL',
'USERDEFINED'	=> 'BILL_USERDEFINED',
);
if ($::g_BillContact{'SEPARATE'})
{
$ACTINIC::B2B->SetXML('BILL_LABEL', ACTINIC::GetPhrase(-1, 339));
SetXMLFromHash(\%hashBillMap, \%::g_BillContact);
}
else
{
$ACTINIC::B2B->SetXML('BILL_LABEL', "");
my ($sKey, $sValue);
while (($sKey, $sValue) = each(%hashBillMap))
{
$ACTINIC::B2B->SetXML($sValue, "");
$ACTINIC::B2B->SetXML($sValue . "_SEP", "");
}
}
my %hashCompanyMap = (
'COMPANY_NAME'			=> 'COMPANY_NAME',
'CONTACT_SALUTATION'	=> 'COMPANY_SALUTATION',
'CONTACT_NAME'			=> 'COMPANY_CONTACT_NAME',
'CONTACT_JOB_TITLE'	=> 'COMPANY_CONTACT_TITLE',
'ADDRESS_1'				=> 'COMPANY_CONTACT_ADDRESS1',
'ADDRESS_2'				=> 'COMPANY_CONTACT_ADDRESS2',
'ADDRESS_3'				=> 'COMPANY_CONTACT_ADDRESS3',
'ADDRESS_4'				=> 'COMPANY_CONTACT_ADDRESS4',
'POSTAL_CODE'			=> 'COMPANY_CONTACT_POSTCODE',
'COUNTRY'				=> 'COMPANY_CONTACT_COUNTRY',
'PHONE'					=> 'COMPANY_CONTACT_PHONE',
'FAX'						=> 'COMPANY_CONTACT_FAX',
'EMAIL'					=> 'COMPANY_CONTACT_EMAIL',
'WEB_SITE_URL'			=> 'COMPANY_CONTACT_WEBSITE',
);
SetXMLFromHash(\%hashCompanyMap, \%$::g_pSetupBlob);
my ($nColumns, $nColumnsToPrice);
$nColumns = 0;
$ACTINIC::B2B->SetXML('CART', ACTINIC::GetPhrase(-1, 165));
if ($$::g_pSetupBlob{PRICES_DISPLAYED})
{
$ACTINIC::B2B->AppendXML('CART', " (" . ACTINIC::GetPhrase(-1, 96, $$::g_pCatalogBlob{'CURRENCY'}) . ")");
}
$ACTINIC::B2B->AppendXML('CART', "\r\n");
my $nProdRefColumnWidth = 0;
if ($$::g_pSetupBlob{PROD_REF_COUNT} > 0)
{
$nProdRefColumnWidth = $$::g_pSetupBlob{PROD_REF_COUNT} > (length ACTINIC::GetPhrase(-1, 97)) ?
$$::g_pSetupBlob{PROD_REF_COUNT} : (length ACTINIC::GetPhrase(-1, 97));
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%-%d.%ds ", $nProdRefColumnWidth, $nProdRefColumnWidth),
ACTINIC::GetPhrase(-1, 97)));
$nColumns++;
}
my $nDescriptionColumnWidth = 30 > (length ACTINIC::GetPhrase(-1, 98)) ? 30 : (length ACTINIC::GetPhrase(-1, 98));
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%-%d.%ds ", $nDescriptionColumnWidth, $nDescriptionColumnWidth),
ACTINIC::GetPhrase(-1, 98)));
$nColumns++;
my $nQuantityColumnWidth = 6 > (length ACTINIC::GetPhrase(-1, 159)) ? 6 : (length ACTINIC::GetPhrase(-1, 159));
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%ds ", $nQuantityColumnWidth),
ACTINIC::GetPhrase(-1, 159)));
$nColumns++;
my $nPriceColumnWidth = 0;
if ($$::g_pSetupBlob{PRICES_DISPLAYED})
{
$nPriceColumnWidth = 11;
$nPriceColumnWidth = $nPriceColumnWidth > (length ACTINIC::GetPhrase(-1, 99)) ? $nPriceColumnWidth :
length ACTINIC::GetPhrase(-1, 99);
$nPriceColumnWidth = $nPriceColumnWidth > (length ACTINIC::GetPhrase(-1, 100)) ? $nPriceColumnWidth :
length ACTINIC::GetPhrase(-1, 100);
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%ds ", $nPriceColumnWidth),
ACTINIC::GetPhrase(-1, 99)));
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%ds ", $nPriceColumnWidth),
ACTINIC::GetPhrase(-1, 100)));
$nColumns += 2;
}
$ACTINIC::B2B->AppendXML('CART', "\r\n");
$ACTINIC::B2B->AppendXML('CART', "-" x ($nProdRefColumnWidth + 2 + $nDescriptionColumnWidth + 2 + $nQuantityColumnWidth + 2 + 2 * ($nPriceColumnWidth + 2)));
my @TableFormat;
my $nCol = 0;
if ($$::g_pSetupBlob{PROD_REF_COUNT} > 0)
{
$TableFormat[$nCol++] = sprintf(" %%-%ds ",$nProdRefColumnWidth);
}
$TableFormat[$nCol++] = sprintf(" %%-%ds ",$nDescriptionColumnWidth);
$TableFormat[$nCol++] = sprintf(" %%%ds ", $nQuantityColumnWidth);
$TableFormat[$nCol++] = sprintf(" %%%ds ", $nPriceColumnWidth);
$TableFormat[$nCol++] = sprintf(" %%%ds ", $nPriceColumnWidth);
my @aCartData;
($Status, $Message, @aCartData) = ActinicOrder::PreprocessCartToDisplay($pCartList, $::TRUE);
my $nCartIndex = 0;
my ($pOrderDetail, $pProduct);
my @aDownloadLinks;
foreach $pOrderDetail (@aCartData)
{
my %CurrentItem = %$pOrderDetail;
my @aComponentsIncluded;
my @aComponentsSeparated;
my $pComponent;
foreach $pComponent (@{$CurrentItem{'COMPONENTS'}})
{
if ($pComponent->{'SEPARATELINE'})
{
push @aComponentsSeparated, $pComponent;
}
else
{
push @aComponentsIncluded, $pComponent;
}
}
$pProduct = $CurrentItem{'PRODUCT'};
my $bProductSupressed = $$pProduct{NO_ORDERLINE};
my $pPrintTable;
my $nColumn = 0;
my $nEffectiveQuantity = ActinicOrder::EffectiveCartQuantity($pOrderDetail,$pCartList,\&ActinicOrder::IdenticalCartLines,undef);
my $nCurrentRow = 0;
$ACTINIC::B2B->AppendXML('CART', "\r\n");
if (!$bProductSupressed)
{
MailOrderLine( $$pProduct{REFERENCE},
$$pProduct{NAME},
$$pOrderDetail{QUANTITY},
$CurrentItem{'PRICE'},
$CurrentItem{'COST'},
$nDescriptionColumnWidth,
@TableFormat
);
if ($CurrentItem{'DDLINK'} ne "")
{
push @aDownloadLinks, MailDownloadLink($$pProduct{REFERENCE}, $$pProduct{NAME}, $CurrentItem{'DDLINK'});
}
}
foreach $pComponent (@aComponentsIncluded)
{
my $sPrice;
my $sCost;
if ($bProductSupressed)
{
$bProductSupressed = $::FALSE;
if ($$::g_pSetupBlob{'PRICES_DISPLAYED'})
{
$sPrice = $CurrentItem{'PRICE'} ? $CurrentItem{'PRICE'} : "--";
$sCost  = $CurrentItem{'COST'}  ? $CurrentItem{'COST'}  : "--";
}
}
MailOrderLine( $pComponent->{'REFERENCE'},
$pComponent->{'NAME'},
$pComponent->{'QUANTITY'},
$sPrice,
$sCost,
$nDescriptionColumnWidth,
@TableFormat
);
if ($pComponent->{'DDLINK'} ne "")
{
push @aDownloadLinks, MailDownloadLink($pComponent->{'REFERENCE'}, $pComponent->{'NAME'}, $pComponent->{'DDLINK'});
}
}
if (length $$pProduct{'OTHER_INFO_PROMPT'} > 0)
{
MailOrderLine( "",
$$pProduct{'OTHER_INFO_PROMPT'} . "\r\n  " . $CurrentItem{'INFO'},
"",
"",
"",
$nDescriptionColumnWidth,
@TableFormat
);
}
if (length $$pProduct{'DATE_PROMPT'} > 0)
{
my ($nDay, $nMonth, $sMonth, $nYear, $sDate);
if ($CurrentItem{"DATE"} =~ /(\d{4})\/0?(\d{1,2})\/0?(\d{1,2})/)
{
$nYear = $1;
$nMonth = $2;
$nDay = $3;
$sMonth = $::g_InverseMonthMap{$nMonth};
$sDate = ACTINIC::FormatDate($nDay, $sMonth, $nYear);
}
else
{
$sDate = $CurrentItem{"DATE"};
ACTINIC::RecordErrors(sprintf(ACTINIC::GetPhrase(-1, 2158, $$pProduct{'DATE_PROMPT'}) . " [%s]",
$CurrentItem{"DATE"}), ACTINIC::GetPath());
}
MailOrderLine( "",
$$pProduct{'DATE_PROMPT'} . "\r\n  " . $sDate,
"",
"",
"",
$nDescriptionColumnWidth,
@TableFormat
);
}
foreach $pComponent (@aComponentsSeparated)
{
MailOrderLine( $pComponent->{'REFERENCE'},
$pComponent->{'NAME'},
$pComponent->{'QUANTITY'},
$pComponent->{'PRICE'},
$pComponent->{'COST'},
$nDescriptionColumnWidth,
@TableFormat
);
if ($pComponent->{'DDLINK'} ne "")
{
push @aDownloadLinks, MailDownloadLink($pComponent->{'REFERENCE'}, $pComponent->{'NAME'}, $pComponent->{'DDLINK'});
}
}
my $parrProductAdjustments = $pCartObject->GetConsolidatedProductAdjustments($nCartIndex);
my $parrAdjustDetails;
$nCurrentRow = 0;
$pPrintTable = [];
foreach $parrAdjustDetails (@$parrProductAdjustments)
{
@Response = ActinicOrder::FormatPrice($parrAdjustDetails->[$::eAdjIdxAmount], $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
MailOrderLine( '',
$parrAdjustDetails->[$::eAdjIdxProductDescription],
"",
"",
$Response[2],
$nDescriptionColumnWidth,
@TableFormat
);
}
$nCartIndex++;
}
if ($$::g_pSetupBlob{PRICES_DISPLAYED} &&
$nTotal > 0)
{
$ACTINIC::B2B->AppendXML('CART', "=" x ($nProdRefColumnWidth + 2 + $nDescriptionColumnWidth + 2 + $nQuantityColumnWidth + 2 + 2 * ($nPriceColumnWidth + 2)));
$ACTINIC::B2B->AppendXML('CART', "\r\n");
my $nTextColumnWidth;
if ($nProdRefColumnWidth)
{
$nTextColumnWidth += $nProdRefColumnWidth + 2;
}
$nTextColumnWidth += $nDescriptionColumnWidth + 2;
$nTextColumnWidth += $nQuantityColumnWidth + 2;
if ($nPriceColumnWidth)
{
$nTextColumnWidth += $nPriceColumnWidth + 2;
}
$nTextColumnWidth -= 2;
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%d.%ds ", $nTextColumnWidth, $nTextColumnWidth), ACTINIC::GetPhrase(-1, 101) . ":"));
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%ds\r\n", $nPriceColumnWidth), $sSubTotal));
my $parrFinalAdjustments = $pCartObject->GetFinalAdjustments();
my @arrAdjustments = @{$pCartObject->GetOrderAdjustments()};
push @arrAdjustments, @{$pCartObject->GetFinalAdjustments()};
my $parrAdjustDetails;
foreach $parrAdjustDetails (@arrAdjustments)
{
my $FullDescr = $parrAdjustDetails->[$::eAdjIdxProductDescription];
my ($parrProductDescription, $nLineCount) =
ActinicOrder::WrapText($FullDescr, $nTextColumnWidth - 2);
my $bWrapped = (@$parrProductDescription > 1);
my $sDescriptionLine = $parrProductDescription->[0];
if(!$bWrapped)
{
$sDescriptionLine .= ':';
}
$ACTINIC::B2B->AppendXML('CART',
sprintf(sprintf(" %%%d.%ds ", $nTextColumnWidth, $nTextColumnWidth),
$sDescriptionLine));
@Response = ActinicOrder::FormatPrice($parrAdjustDetails->[$::eAdjIdxAmount], $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%ds\r\n", $nPriceColumnWidth), $Response[2]));
my $i;
for($i = 1; $i < @$parrProductDescription; $i++)
{
$sDescriptionLine = $parrProductDescription->[$i];
if($i == @$parrProductDescription - 1)
{
$sDescriptionLine .= ':';
}
$ACTINIC::B2B->AppendXML('CART',
sprintf(sprintf(" %%%d.%ds\r\n", $nTextColumnWidth, $nTextColumnWidth), ' ' . $parrProductDescription->[$i]));
}
}
if ($$::g_pSetupBlob{MAKE_SHIPPING_CHARGE} && $nShipping > 0)
{
@Response = ActinicOrder::CallShippingPlugIn($pCartList, $nSubTotal);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
elsif (${$Response[2]}{GetShippingDescription} != $::SUCCESS)
{
return ( ${$Response[2]}{GetShippingDescription}, ${$Response[3]}{GetShippingDescription});
}
my $sShipDescription = $Response[5];
my $sShippingText = ACTINIC::GetPhrase(-1, 102);
if ($sShipDescription ne "")
{
$sShippingText .= " ($sShipDescription)";
}
$sShippingText .= ":";
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%d.%ds ", $nTextColumnWidth, $nTextColumnWidth), $sShippingText));
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%ds\r\n", $nPriceColumnWidth), $sShipping));
}
if ($$::g_pSetupBlob{MAKE_HANDLING_CHARGE} && $nHandling != 0)
{
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%d.%ds ", $nTextColumnWidth, $nTextColumnWidth), ACTINIC::GetPhrase(-1, 199) . ":"));
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%ds\r\n", $nPriceColumnWidth), $sHandling));
}
if ($nTax1 != 0)
{
if (!ActinicOrder::PricesIncludeTaxes() || $nTax1 < 0)
{
my $sTaxName = ActinicOrder::GetTaxName('TAX_1');
if ($nTax1 < 0)
{
$sTaxName = 'Exempted ' . $sTaxName;
}
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%d.%ds ", $nTextColumnWidth, $nTextColumnWidth), $sTaxName . ":"));
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%ds\r\n", $nPriceColumnWidth), $sTax1));
}
}
if ($nTax2 != 0)
{
if (!ActinicOrder::PricesIncludeTaxes() || $nTax2 < 0)
{
my $sTaxName = ActinicOrder::GetTaxName('TAX_2');
if ($nTax2 < 0)
{
$sTaxName = 'Exempted ' . $sTaxName;
}
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%d.%ds ", $nTextColumnWidth, $nTextColumnWidth), $sTaxName . ":"));
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%ds\r\n", $nPriceColumnWidth), $sTax2));
}
}
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%d.%ds ", $nTextColumnWidth, $nTextColumnWidth), ACTINIC::GetPhrase(-1, 103) . ":"));
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%ds\r\n", $nPriceColumnWidth), $sTotal));
if (ActinicOrder::PricesIncludeTaxes())
{
if ($nTax1 > 0)
{
my $sTaxName = ActinicOrder::GetTaxName('TAX_1');
$sTaxName = 'Including ' . $sTaxName;
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%d.%ds ", $nTextColumnWidth, $nTextColumnWidth), $sTaxName . ":"));
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%ds\r\n", $nPriceColumnWidth), $sTax1));
}
if ($nTax2 > 0)
{
my $sTaxName = ActinicOrder::GetTaxName('TAX_2');
$sTaxName = 'Including ' . $sTaxName;
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%d.%ds ", $nTextColumnWidth, $nTextColumnWidth), $sTaxName . ":"));
$ACTINIC::B2B->AppendXML('CART', sprintf(sprintf(" %%%ds\r\n", $nPriceColumnWidth), $sTax2));
}
}		
if($::s_Ship_nSSPProviderID != -1 &&
$$::g_pSSPSetupBlob{$::s_Ship_nSSPProviderID} &&
$$::g_pSSPSetupBlob{$::s_Ship_nSSPProviderID}{'RATE_DISCLAIMER'})
{
$ACTINIC::B2B->AppendXML('CART',
sprintf("\r\n%s\r\n",
ACTINIC::SplitString($$::g_pSSPSetupBlob{$::s_Ship_nSSPProviderID}{'RATE_DISCLAIMER'},
70,
"\r\n")));
}
}
if (@aDownloadLinks > 0)
{
$ACTINIC::B2B->AppendXML('CART', "\r\n" . ACTINIC::GetPhrase(-1, 2250, $$::g_pSetupBlob{'DD_EXPIRY_TIME'}));
my $sLine;
foreach $sLine (@aDownloadLinks)
{
$ACTINIC::B2B->AppendXML('CART', "\r\n\r\n" . $sLine);
}
}
if($::s_Ship_bDisplayExtraCartInformation == $::TRUE)
{
if($::s_Ship_nSSPProviderID != -1 &&
$$::g_pSSPSetupBlob{$::s_Ship_nSSPProviderID} &&
$$::g_pSSPSetupBlob{$::s_Ship_nSSPProviderID}{'TRADEMARKS'})
{
$ACTINIC::B2B->AppendXML('EXTRAFOOTER',
sprintf("\r\n%s\r\n",
ACTINIC::SplitString($$::g_pSSPSetupBlob{$::s_Ship_nSSPProviderID}{'TRADEMARKS'},
70,
"\r\n")));
}
}
else
{
$ACTINIC::B2B->AppendXML('EXTRAFOOTER', '');
}
my $sFilename = ACTINIC::GetPath() . $sTemplateFile;
unless (open (TEMPLATE, "<$sFilename"))
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 21, $sFilename, $!));
}
my $sBody;
{
local $/;
$sBody = <TEMPLATE>;
}
close (TEMPLATE);
$::USEINTLCURRENCYSYMBOL = $::FALSE;
$sBody =~ s/([^\r])\n/$1\r\n/g;
eval
{
require ax000001;
};
if ($@)
{
return $@;
}
my $Parser = new ACTINIC_PXML();
my $pDummy;
($sBody, $pDummy) = $Parser->Parse($sBody);
my $sRecipient;
if (defined $sMailFile &&
length $sMailFile > 0)
{
unless (open (MFILE, ">$sMailFile"))
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 21, $sFilename, $!));
}
foreach $sRecipient (@{$paRecipients})
{
print MFILE $sRecipient . ",";
}
print MFILE "\n";
print MFILE ACTINIC::GetPhrase(-1, 234) . " $::g_InputHash{ORDERNUMBER}" . "\n";
print MFILE $sBody;
close MFILE;
}
else
{
foreach $sRecipient (@{$paRecipients})
{
if ($sRecipient ne "")
{
($Status, $Message) = ACTINIC::SendMail($::g_sSmtpServer,
$sRecipient,
ACTINIC::GetPhrase(-1, 234) . " $::g_InputHash{ORDERNUMBER}",
$sBody,
$$::g_pSetupBlob{EMAIL});
if($Status != $::SUCCESS)
{
return ($::FAILURE, $Message);
}
}
}
}
return ($::SUCCESS, "");
}
sub MailOrderLine
{
my ($sProdRef, $sName, $sQuantity, $sPrice, $sCost, $nDescriptionColumnWidth, @TableFormat) = @_;
my $pPrintTable;
my $nColumn = 0;
my $nCurrentRow = 0;
if ($$::g_pSetupBlob{PROD_REF_COUNT} > 0)
{
$pPrintTable->[$nColumn++]->[0] = $sProdRef;
}
$sName =~ s/(!!\<|\>!!)//g;
my ($pProductDescription, $nLineCount) = ActinicOrder::WrapText($sName, $nDescriptionColumnWidth);
foreach (@$pProductDescription)
{
$pPrintTable->[$nColumn]->[$nCurrentRow++] = $_;
}
$nColumn++;
$pPrintTable->[$nColumn++]->[0] = $sQuantity;
if (!$$::g_pSetupBlob{'PRICES_DISPLAYED'})
{
$sPrice = "";
$sCost  = "";
}
$pPrintTable->[$nColumn++]->[0] = $sPrice;
$pPrintTable->[$nColumn++]->[0] = $sCost;
my $nLine;
for( $nLine=0; $nLine < $nCurrentRow; $nLine++ )
{
my $nCol;
for( $nCol=0; $nCol < $nColumn; $nCol++ )
{
$ACTINIC::B2B->AppendXML('CART', sprintf($TableFormat[$nCol], $pPrintTable->[$nCol]->[$nLine]));
}
$ACTINIC::B2B->AppendXML('CART', "\r\n");
}
}
sub MailDownloadLink
{
my ($sProdRef, $sName, $sLink) = @_;
my $sLine;
if ($$::g_pSetupBlob{PROD_REF_COUNT} > 0)
{
$sLine = $sProdRef . " ";
}
$sLine .= $sName . "\r\n" . $sLink;
return $sLine;
}
sub GeneratePresnetMail
{
my ($sTextMailBody, @Response, $Status, $Message);
@Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
$sTextMailBody = "Order#: $::g_InputHash{ORDERNUMBER}\r\n";
$sTextMailBody .= "Shop Name: $$::g_pSetupBlob{COMPANY_NAME}\r\n";
$sTextMailBody .= "Shop's Email: $$::g_pSetupBlob{EMAIL}\r\n";
$sTextMailBody .= "Sender's Email: $::g_BillContact{EMAIL}\r\n";
$sTextMailBody .= "Sender's Town/City: $::g_BillContact{ADDRESS4}\r\n";
$sTextMailBody .= "Sender's Country: $::g_BillContact{COUNTRY}\r\n";
$sTextMailBody .= "Recipient's Town/City: $::g_ShipContact{ADDRESS4}\r\n";
$sTextMailBody .= "Recipient's Country: $::g_ShipContact{COUNTRY}\r\n";
$sTextMailBody .= "Referrer: " . GetGeneralUD3() . "\r\n";
@Response = ACTINIC::EncodeText($$::g_pCatalogBlob{'SINTLSYMBOLS'});
$sTextMailBody .= "Currency: $Response[1]\r\n";
@Response = $pCartObject->SummarizeOrder($::FALSE);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($Ignore0, $Ignore1, $nSubTotal, $nShipping, $nTax1, $nTax2, $nTotal, $nShippingTax1, $nShippingTax2,
$nHandling, $nHandlingTax1, $nHandlingTax2) = @Response;
my ($nIntegral, $nFractional, $nFactor);
$nFactor = 10 ** $$::g_pCatalogBlob{'ICURRDIGITS'};
if ($nFactor == 1)
{
$sTextMailBody .= "Order Value: $nTotal\r\n";
}
else
{
my ($sFormat, $sFormattedTotal);
$sFormat = sprintf("%%d.%%0%dd", $$::g_pCatalogBlob{'ICURRDIGITS'});
$sFormattedTotal = sprintf($sFormat,
$nTotal / $nFactor, ACTINIC::Modulus($nTotal, $nFactor) );
$sTextMailBody .= "Order Value: $sFormattedTotal\r\n";
}
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst, $sDate);
($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime(time);
$mon++;
$year += 1900;
$sDate = sprintf("%02d/%02d/%4d %2.2d:%2.2d GMT", $mday, $mon, $year, $hour, $min);
$sTextMailBody .= "Order Date & time: $sDate\r\n";
$sTextMailBody .= "Latest delivery date: $::g_ShipContact{USERDEFINED}\r\n";
my ($pOrderDetail, %CurrentItem, $pProduct, $sLine);
foreach $pOrderDetail (@$pCartList)
{
%CurrentItem = %$pOrderDetail;
my $sSectionBlobName;
($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($CurrentItem{SID});
if ($Status == $::FAILURE)
{
return ($Status, $Message);
}
@Response = ACTINIC::GetProduct($CurrentItem{"PRODUCT_REFERENCE"}, $sSectionBlobName,
ACTINIC::GetPath());
($Status, $Message, $pProduct) = @Response;
if ($Status == $::NOTFOUND)
{
}
if ($Status == $::FAILURE)
{
return (@Response);
}
$sLine = sprintf("Item: %-21s", $$pProduct{'REFERENCE'});
$sLine .= $$pProduct{'NAME'};
$sTextMailBody .= "$sLine\r\n";
}
my ($sSubject, $sEmailRecpt);
$sSubject = $$::g_pSetupBlob{COMPANY_NAME};
$sEmailRecpt .= 'orderorder@pres.net';
($Status, $Message) = ACTINIC::SendMail($::g_sSmtpServer,
$sEmailRecpt,
$sSubject,
$sTextMailBody);
if($Status != $::SUCCESS)
{
return ($::FAILURE, $Message);
}
return ($::SUCCESS, "");
}
sub CallPlugInScript
{
if ($#_ != 0)
{
ACTINIC::RecordErrors("CallPlugInScript, validate params:\n",
ACTINIC::GetPath());
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'CallPlugInScript'), 0, 0);
}
my ($sScriptName) = @_;
my @Response = GetPlugInScript(ACTINIC::GetPath(), $sScriptName);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::RecordErrors("CallPlugInScript, could not load script:\n",
ACTINIC::GetPath());
return (@Response);
}
my ($sScript) = $Response[2];
local $::sPath = ACTINIC::GetPath();
$::sPlugInScriptError = '';
eval
{
require Digest::MD5;
import Digest::MD5 'md5_hex';
};
if ($@)
{
require di000001;
import Digest::Perl::MD5 'md5_hex';
}
eval($sScript);
if ($@)
{
ACTINIC::RecordErrors("CallPlugInScript, execute: $@\n",
ACTINIC::GetPath());
return ($::FAILURE, ACTINIC::GetPhrase(-1, 170, $@));
}
if ($::sPlugInScriptError)
{
ACTINIC::RecordErrors("CallPlugInScript, report: $::sPlugInScriptError\n",
ACTINIC::GetPath());
return ($::FAILURE, ACTINIC::GetPhrase(-1, 170, $::sPlugInScriptError));
}
return ($::SUCCESS, '');
}
sub GetPlugInScript
{
if ($#_ < 1)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'GetOCCScript'), 0, 0);
}
my ($sPath) = $_[0];
my ($sFilename) = $sPath . $_[1];
my @Response = ACTINIC::ReadAndVerifyFile($sFilename);
return (@Response);
}
sub AdjustTaxTreatment
{
my ($eTreatment) = @_;
if ($::g_TaxInfo{EXEMPT1})
{
if ($ActinicOrder::TAX1 == $eTreatment)
{
$eTreatment = $ActinicOrder::EXEMPT;
}
elsif ($ActinicOrder::BOTH == $eTreatment)
{
$eTreatment = $ActinicOrder::TAX2;
}
}
if ($::g_TaxInfo{EXEMPT2})
{
if ($ActinicOrder::TAX2 == $eTreatment)
{
$eTreatment = $ActinicOrder::EXEMPT;
}
elsif ($ActinicOrder::BOTH == $eTreatment)
{
$eTreatment = $ActinicOrder::TAX1;
}
}
return ($eTreatment);
}
sub GetOCCValidationData
{
my ($sText, @Response);
@Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
ActinicOrder::ParseAdvancedTax();
@Response = $pCartObject->SummarizeOrder($::FALSE);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sText = "AMOUNT=$Response[6]";
$sText .= "&CURRENCY=$$::g_pCatalogBlob{'SINTLSYMBOLS'}";
my $nFactor = 100;
my $nNumDigits = $::PriceFormatBlob{"ICURRDIGITS"};
if(defined $nNumDigits)
{
$nFactor = (10 ** $nNumDigits);
}
$sText .= "&FACTOR=$nFactor";
$sText .= "&ORDERNUMBER=$::g_PaymentInfo{'ORDERNUMBER'}";
LogData("OCC_VALIDATE: $sText");
return ($::SUCCESS, '', $sText);
}
sub NotifyOfError
{
my ($sError, $bOmitMailDump) = @_;
if ($$::g_pSetupBlob{EMAIL} ne "" && $::g_sSmtpServer ne "")
{
my ($sPrompt1, $sPrompt2, $sPrompt3, $sPrompt4, $sPrompt5);
if (defined $$::g_pPromptList{"-1,1957"}{PROMPT})
{
$sPrompt1 = ACTINIC::GetPhrase(-1, 1957);
$sPrompt2 = ACTINIC::GetPhrase(-1, 1958);
$sPrompt3 = ACTINIC::GetPhrase(-1, 1959);
$sPrompt4 = ACTINIC::GetPhrase(-1, 2097);
$sPrompt5 = ACTINIC::GetPhrase(-1, 2098);
}
else
{
$sPrompt1 = "Following error has been displayed to a customer:\n\n";
$sPrompt2 = "\nDebugging information:\nInput Hash:\n";
$sPrompt3 = "Error in Catalog order";
$sPrompt4 = "Calling Address:";
$sPrompt5 = "Calling Host:";
}
my $sText;
$sText .= $sPrompt1;
$sText .= $sError . "\n\n";
$sText .= GetContactDetailsString();
$sText .= $::ENV{REMOTE_HOST} ? "\n" . $sPrompt5 . " " . $::ENV{REMOTE_HOST} . "\n" : '';
$sText .= $::ENV{REMOTE_ADDR} ? "\n" . $sPrompt4 . " " . $::ENV{REMOTE_ADDR} . "\n" : '';
if(!$bOmitMailDump)
{
$sText .= $sPrompt2;
my $sKey;
foreach $sKey (sort keys %::g_InputHash)
{
my $sValue = $::g_InputHash{$sKey};
if ($sKey =~ /^PAYMENTCARD/i)
{
$sValue =~ s/[a-z0-9]/\*/gi;
}
$sText .= $sKey . ' : "' . $sValue . "\"\n";
}
}
my ($Status, $Message) = ACTINIC::SendMail($::g_sSmtpServer, $$::g_pSetupBlob{EMAIL},
$sPrompt3, $sText);
if ($Status != $::SUCCESS)
{
ACTINIC::RecordErrors($Message, ACTINIC::GetPath());
}
}
return $sError;
}
sub CreateAddressBook
{
if( $ACTINIC::B2B->Get('UserDigest') )
{
return;
}
eval 'require ab000001;';
if ( $@ )
{
ACTINIC::ReportError($@, ACTINIC::GetPath());
}
$::ACT_ADB = ADDRESS_BOOK->new(
FormPrefix			=>	'DELIVER',
FormNames 			=> [	'NAME',			'ADDRESS1',
'JOBTITLE',		'COMPANY',
'ADDRESS2',		'ADDRESS3',
'ADDRESS4',		'POSTALCODE',
'COUNTRY',		'PHONE',
'FAX',			'EMAIL',
'USERDEFINED',	'SALUTATION'	],
LocationInfoNames=> [	'DELIVERY_REGION_CODE',
'DELIVERY_COUNTRY_CODE',
'DELIVERPOSTALCODE'	],
DeliveryFormHash => 	\%::g_ShipContact,
LocationHash		=> 	\%::g_LocationInfo,
InputFormHash	 	=> 	\%::g_InputHash,
);
$::ACT_ADB->Init();
}
sub ConfigureAddressBook
{
$::ACT_ADB->Set(
OneAddressMessage 	 => 	ACTINIC::GetPhrase(-1, 271),
MoreAddressesMessage => 	ACTINIC::GetPhrase(-1, 272),
StatusMessage 		 => 	ACTINIC::GetPhrase(-1, 273),
MaxAddressesWarning  => 	ACTINIC::GetPhrase(-1, 274, ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor),ACTINIC::GetPhrase(-1, 1970)),
NoAddressesMessage 	 => 	ACTINIC::GetPhrase(-1, 275),
AddMessage 		    => 	ACTINIC::GetPhrase(-1, 276),
DeleteLabel 		    => 	ACTINIC::GetPhrase(-1, 277),
Action			       =>	$::g_InputHash{'ACTION'},
Sequence		       =>	$::g_InputHash{'SEQUENCE'}
);
}
sub NotifyMallAdministratorOfNewOrder
{
eval 'require MallInterfaceLayer;';
if ($@)
{
return($::SUCCESS);
}
return (MallInterfaceLayer::NewOrder(ACTINIC::GetPath(), $::g_InputHash{ORDERNUMBER}, $::g_InputHash{SHOP}));
}
sub PrepareOrderTaxOpaqueData
{
my($sKeyPrefix) = @_;
my $sKey = $sKeyPrefix . 'TAX_OPAQUE_DATA';
my ($nTaxID, $sOpaqueData);
foreach $nTaxID (sort keys %$::g_pTaxesBlob)
{
$sOpaqueData .= "$nTaxID\t$$::g_pTaxesBlob{$nTaxID}{$sKey}\n";
}
return($::SUCCESS, '', $sOpaqueData);
}
sub SetXMLFromHash
{
my ($pHashID, $pHash) = @_;
my ($sKey, $sValue);
while (($sKey, $sValue) = each(%$pHashID))
{
if ($$pHash{$sKey} eq "")
{
$ACTINIC::B2B->SetXML($sValue, "");
$ACTINIC::B2B->SetXML($sValue . "_SEP", "");
}
else
{
$ACTINIC::B2B->SetXML($sValue, $$pHash{$sKey} . " ");
$ACTINIC::B2B->SetXML($sValue . "_SEP", "\r\n");
}
}
return($::SUCCESS, '');
}
sub EvaluatePaypalPro
{
$::g_PaymentInfo{'METHOD'} = $::PAYMENT_PAYPAL_PRO;
my @Response = GetOCCScript(ACTINIC::GetPath());
$::g_PaymentInfo{'METHOD'} = $::PAYMENT_CREDIT_CARD;
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
}
my ($sScript) = $Response[2];
if (eval($sScript) != $::SUCCESS)
{
ACTINIC::ReportError($@, ACTINIC::GetPath());
}
$::PAYPAL_USER = DecryptPPDetails($::PAYPAL_USER);
$::PAYPAL_PWD = DecryptPPDetails($::PAYPAL_PWD);
}
sub EvaluatePaypalEC
{
$::g_PaymentInfo{'METHOD'} = $::PAYMENT_PAYPAL_EC;
my @Response = GetOCCScript(ACTINIC::GetPath());
$::g_PaymentInfo{'METHOD'} = $::PAYMENT_CREDIT_CARD;
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
}
my ($sScript) = $Response[2];
if (eval($sScript) != $::SUCCESS)
{
ACTINIC::ReportError($@, ACTINIC::GetPath());
}
$::PAYPAL_SIGNATURE = DecryptPPDetails($::PAYPAL_SIGNATURE);
$::PAYPAL_PWD = DecryptPPDetails($::PAYPAL_PWD);
}
sub IncludePaypalScript
{
if (defined $$::g_pPaymentList{$::PAYMENT_PAYPAL_EC})
{
EvaluatePaypalEC();
}
else
{
EvaluatePaypalPro();
}
}
sub GetPPAddressDetails
{
my @aNames = split(/ /, $::g_BillContact{NAME});
my ($sFirstName, $sLastName) = (shift @aNames, join ' ', @aNames);
return(
$sFirstName,
$sLastName,
$::g_BillContact{EMAIL},
ActinicLocations::GetISOInvoiceCountryCode(),
$::g_BillContact{ADDRESS4},
$::g_BillContact{POSTALCODE},
$::g_BillContact{ADDRESS3},
$::g_BillContact{ADDRESS1} . ' ' .$::g_BillContact{ADDRESS2}
);
}
sub DecryptPPDetails
{
my $sValue = shift;
my $sUserKey = $::g_sUserKey;
if ($sUserKey)
{
$sUserKey =~ s/([A-Fa-f0-9]{2})/pack("C",hex($1))/ge;
my @PrivateKey = unpack('C*',$sUserKey);
my ($sLength, $sDetails) = split(/ /, $sValue);
$sDetails =~ s/([A-Fa-f0-9]{2})/pack("C",hex($1))/ge;
ActinicEncrypt::InitEncrypt(@{$$::g_pSetupBlob{PUBLIC_KEY_128BIT}});
$sDetails = ActinicEncrypt::DecryptSafer($sDetails, @PrivateKey);
$sValue = substr($sDetails, 0, $sLength);
}
else
{
ACTINIC::ReportError("Paypal Pro is not supported on Actinic Host ", ACTINIC::GetPath());
}
return($sValue);
}
sub RecordPaypalOrder
{
my $oPaypal = shift;
my $nAmount = ActinicOrder::GetOrderTotal();
my $hResponse = $oPaypal->GetResponseHash();
if ($$hResponse{RESULT} != 0)
{
return ($::FAILURE, $$hResponse{RESPMSG});
}
if ($$hResponse{ACK} eq "Failure")
{
return ($::FAILURE, $$hResponse{L_LONGMESSAGE0});
}
$::g_PaymentInfo{'METHOD'} = $::PAYMENT_PAYPAL_PRO;
if (defined $$::g_pPaymentList{$::PAYMENT_PAYPAL_EC})
{
$::g_PaymentInfo{'METHOD'} = $::PAYMENT_PAYPAL_EC;
}
undef $::g_PaymentInfo{'CARDNUMBER'};
undef $::g_PaymentInfo{'CARDTYPE'};
undef $::g_PaymentInfo{'EXPYEAR'};
undef $::g_PaymentInfo{'EXPMONTH'};
my (@Response) = CompleteOrder();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($status, $sMessage, $sOrderNumber) = GetOrderNumber();
my $sAction = $::g_InputHash{ACTION};
$::g_InputHash{ON} = $sOrderNumber;
$::g_InputHash{TM} = $oPaypal->{TESTMODE};
$::g_InputHash{AM} = $nAmount * (10 ** $$::g_pCatalogBlob{"ICURRDIGITS"});
$::g_InputHash{ACTION} = sprintf("AUTHORIZE_%d", $::g_PaymentInfo{'METHOD'});
my ($sDate) = ACTINIC::GetActinicDate();
($sDate) = ACTINIC::EncodeText2($sDate, $::FALSE);
my $sParams = sprintf("ON=%s&TM=%s&AM=%s&CD=%s&TX=%s&DT=%s&",
$sOrderNumber,
$oPaypal->{TESTMODE},
$nAmount * (10 ** $$::g_pCatalogBlob{"ICURRDIGITS"}),
$$hResponse{PPREF},
$$hResponse{PNREF},
$sDate);
if (defined $$::g_pPaymentList{$::PAYMENT_PAYPAL_EC})
{
$sParams = sprintf("ON=%s&TM=%s&AM=%s&CD=%s&TX=%s&DT=%s&",
$sOrderNumber,
$oPaypal->{TESTMODE},
$nAmount * (10 ** $$::g_pCatalogBlob{"ICURRDIGITS"}),
$$hResponse{TRANSACTIONID},
$$hResponse{AUTHORIZATIONID},
$sDate);
}
eval
{
require Digest::MD5;
import Digest::MD5 'md5_hex';
};
if ($@)
{
require di000001;
import Digest::Perl::MD5 'md5_hex';
}
my $sSignature = md5_hex($sParams);
$sParams .= sprintf("SN=%s", $sSignature);
my $sError = RecordAuthorization(\$sParams);
$::g_InputHash{ACTION} = $sAction;
if (length $sError != 0)
{
ACTINIC::RecordErrors($sError, ACTINIC::GetPath());
return ($::FAILURE, ACTINIC::GetPhrase(-1, 1964));
}
return ($::SUCCESS, '');
}
sub FormatTrackingPage
{
my $sHTML = '';
my $nSSPID = $::g_InputHash{SSP_ID};
my $phashSSPProvider = $$::g_pSSPSetupBlob{$nSSPID};
if (!defined $phashSSPProvider)
{
return($::SUCCESS, '', ACTINIC::GetPhrase(-1, 2271));
}
my %hashVariables;
$hashVariables{$::VARPREFIX.'LICENSEKEY'} = ACTINIC::DecodeXOREncryption($$phashSSPProvider{'AccessKey'}, $::UPS_ENCRYPT_PASSWORD);
$hashVariables{$::VARPREFIX.'TYPEOFINQUIRYNUMBER'} = $::g_InputHash{TrackingType};
my $nMaxTrackingNumbers = $$phashSSPProvider{MaxTrackingNumbers};
my $i;
for($i = 1; $i <= $nMaxTrackingNumbers; $i++)
{
if(defined $::g_InputHash{'NUMBER' . $i})
{
$hashVariables{$::VARPREFIX.'INQUIRYNR' . $i} = $::g_InputHash{'NUMBER' . $i};
}
else
{
$hashVariables{$::VARPREFIX.'INQUIRYNR' . $i} = '';
}
}
$hashVariables{$::VARPREFIX.'INQUIRYNR'} = $::g_InputHash{'NUMBER'};
$hashVariables{$::VARPREFIX.'SENDERSHIPPERNUMBER'} = $::g_InputHash{'ShipperNumber'};
$hashVariables{$::VARPREFIX.'DESTINATIONPOSTALCODE'} = $::g_InputHash{'DestinationPostalCode'};
$hashVariables{$::VARPREFIX.'DESTINATIONCOUNTRY'} = $::g_InputHash{'DestinationCountry'};
$hashVariables{$::VARPREFIX.'FROMPICKUPMONTH'} = $::g_InputHash{'FromPickupMonth'};
$hashVariables{$::VARPREFIX.'FROMPICKUPDAY'} = $::g_InputHash{'FromPickupDay'};
$hashVariables{$::VARPREFIX.'FROMPICKUPYEAR'} = $::g_InputHash{'FromPickupYear'};
$hashVariables{$::VARPREFIX.'TOPICKUPMONTH'} = $::g_InputHash{'ToPickupMonth'};
$hashVariables{$::VARPREFIX.'TOPICKUPDAY'} = $::g_InputHash{'ToPickupDay'};
$hashVariables{$::VARPREFIX.'TOPICKUPYEAR'} = $::g_InputHash{'ToPickupYear'};
$ACTINIC::B2B->SetXML('FORWARDMESSAGE', ACTINIC::GetPhrase(-1, 2272));
my @Response = ACTINIC::TemplateFile(ACTINIC::GetPath() . $$phashSSPProvider{TrackingTemplate}, \%hashVariables);
if($Response[0] != $::SUCCESS)
{
return(@Response);
}
$sHTML = $Response[2];
return($::SUCCESS, '', $sHTML);
}
sub GetContactDetailsString
{
my $sText;
$sText .= ACTINIC::GetPhrase(-1, 339) . "\n";
unless (ACTINIC::IsPromptHidden(0, 0))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 0)  . " $::g_BillContact{'SALUTATION'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 1))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 1)  . " $::g_BillContact{'NAME'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 2464))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 2464)  . " $::g_BillContact{'FIRSTNAME'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 2465))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 2465)  . " $::g_BillContact{'LASTNAME'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 2))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 2)  . " $::g_BillContact{'JOBTITLE'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 3))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 3)  . " $::g_BillContact{'COMPANY'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 4))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 4)  . " $::g_BillContact{'ADDRESS1'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 5))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 5)  . " $::g_BillContact{'ADDRESS2'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 6))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 6)  . " $::g_BillContact{'ADDRESS3'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 7))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 7)  . " $::g_BillContact{'ADDRESS4'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 8))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 8)  . " $::g_BillContact{'POSTALCODE'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 9))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 9)  . " $::g_BillContact{'COUNTRY'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 10))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 10) . " $::g_BillContact{'PHONE'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 2453))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 2453) . " $::g_BillContact{'MOBILE'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 11))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 11) . " $::g_BillContact{'FAX'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 12))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 12) . " $::g_BillContact{'EMAIL'}\n";
}
unless (ACTINIC::IsPromptHidden(0, 13))
{
$sText .= "\t" . ACTINIC::GetPhrase(0, 13) . " $::g_BillContact{'USERDEFINED'}\n";
}
$sText .= "\n" . ACTINIC::GetPhrase(-1, 340) . "\n";
unless (ACTINIC::IsPromptHidden(1, 0))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 0)  . " $::g_ShipContact{'SALUTATION'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 1))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 1)  . " $::g_ShipContact{'NAME'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 2451))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 2451)  . " $::g_ShipContact{'FIRSTNAME'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 2452))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 2452)  . " $::g_ShipContact{'LASTNAME'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 2))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 2)  . " $::g_ShipContact{'JOBTITLE'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 3))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 3)  . " $::g_ShipContact{'COMPANY'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 4))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 4)  . " $::g_ShipContact{'ADDRESS1'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 5))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 5)  . " $::g_ShipContact{'ADDRESS2'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 6))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 6)  . " $::g_ShipContact{'ADDRESS3'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 7))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 7)  . " $::g_ShipContact{'ADDRESS4'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 8))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 8)  . " $::g_ShipContact{'POSTALCODE'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 9))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 9)  . " $::g_ShipContact{'COUNTRY'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 10))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 10) . " $::g_ShipContact{'PHONE'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 2454))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 2454) . " $::g_ShipContact{'MOBILE'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 11))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 11) . " $::g_ShipContact{'FAX'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 12))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 12) . " $::g_ShipContact{'EMAIL'}\n";
}
unless (ACTINIC::IsPromptHidden(1, 13))
{
$sText .= "\t" . ACTINIC::GetPhrase(1, 13) . " $::g_ShipContact{'USERDEFINED'}\n";
}
return ($sText);
}
sub FormatShippingOpaqueData
{
my ($phashShippingDetails, $bParentExcluded) = @_;
my $sOpaqueData = $phashShippingDetails->{'OPAQUE_SHIPPING_DATA'};
$sOpaqueData .= ";ALT_WEIGHT=$phashShippingDetails->{'ALT_WEIGHT'}";
$sOpaqueData .= ";EXCLUDE_FROM_SHIP=$phashShippingDetails->{'EXCLUDE_FROM_SHIP'}";
$sOpaqueData .= ";SHIP_CATEGORY=$phashShippingDetails->{'SHIP_CATEGORY'}";
$sOpaqueData .= ";SHIP_QUANTITY=$phashShippingDetails->{'SHIP_QUANTITY'}";
$sOpaqueData .= ";SHIP_SUPPLEMENT=$phashShippingDetails->{'SHIP_SUPPLEMENT'}";
$sOpaqueData .= ";SHIP_SUPPLEMENT_ONCE=$phashShippingDetails->{'SHIP_SUPPLEMENT_ONCE'}";
$sOpaqueData .= ";HAND_SUPPLEMENT=$phashShippingDetails->{'HAND_SUPPLEMENT'}";
$sOpaqueData .= ";HAND_SUPPLEMENT_ONCE=$phashShippingDetails->{'HAND_SUPPLEMENT_ONCE'}";
$sOpaqueData .= ";EXCLUDE_PARENT=$bParentExcluded";
$sOpaqueData .= ";SEP_LINE=$phashShippingDetails->{'SEPARATE_LINE'}";
$sOpaqueData .= ";USE_ASSOC_SHIP=$phashShippingDetails->{'USE_ASSOCIATED_SHIP'}";
if($phashShippingDetails->{SHIP_SEPARATELY})
{
$sOpaqueData .= ';SEPARATE;';
}
else
{
$sOpaqueData .= ';';
}
return ($sOpaqueData);
}
package OrderBlob;
sub new
{
my ($Proto, $parrType, $parrValue) = @_;
my $sClass = ref($Proto) || $Proto;
my $Self  = {};
bless ($Self, $sClass);
$Self->{_TYPES}	= $parrType;
$Self->{_VALUES}	= $parrValue;
return($Self);
}
sub AddByte
{
my ($Self, $nValue) = @_;
push @{$Self->{_TYPES}}, $::RBBYTE;
push @{$Self->{_VALUES}}, $nValue;
}
sub AddWord
{
my ($Self, $nValue) = @_;
push @{$Self->{_TYPES}}, $::RBWORD;
push @{$Self->{_VALUES}}, $nValue;
}
sub AddDWord
{
my ($Self, $nValue) = @_;
push @{$Self->{_TYPES}}, $::RBDWORD;
push @{$Self->{_VALUES}}, $nValue;
}
sub AddQWord
{
my ($Self, $nValue) = @_;
push @{$Self->{_TYPES}}, $::RBQWORD;
push @{$Self->{_VALUES}}, $nValue;
}
sub AddString
{
my ($Self, $sValue) = @_;
push @{$Self->{_TYPES}}, $::RBSTRING;
push @{$Self->{_VALUES}}, $sValue;
}
sub AddContact
{
my ($Self, $pContact) = @_;
$Self->AddString($$pContact{'NAME'});
$Self->AddString($$pContact{'FIRSTNAME'});
$Self->AddString($$pContact{'LASTNAME'});
$Self->AddString($$pContact{'SALUTATION'});
$Self->AddString($$pContact{'JOBTITLE'});
$Self->AddString($$pContact{'COMPANY'});
$Self->AddString($$pContact{'ADDRESS1'});
$Self->AddString($$pContact{'ADDRESS2'});
$Self->AddString($$pContact{'ADDRESS3'});
$Self->AddString($$pContact{'REGION'});
$Self->AddString($$pContact{'COUNTRY'});
$Self->AddString($$pContact{'POSTALCODE'});
$Self->AddString($$pContact{'PHONE'});
$Self->AddString($$pContact{'MOBILE'});
$Self->AddString($$pContact{'FAX'});
$Self->AddString($$pContact{'EMAIL'});
$Self->AddString($$pContact{'USERDEFINED'});
if (! defined $$pContact{PRIVACY} ||
$$pContact{PRIVACY} eq '')
{
$$pContact{PRIVACY} = $::FALSE;
}
$Self->AddByte($$pContact{'PRIVACY'});
}
sub AddAdjustment
{
my ($Self, $nOrderSequenceNumber, $parrAdjustDetails, $pProduct) = @_;
my $nAmount = $parrAdjustDetails->[$::eAdjIdxAmount];
$Self->AddWord($ACTINIC::ORDER_DETAIL_BLOB_MAGIC);
$Self->AddByte($::ORDER_DETAIL_BLOB_VERSION);
$Self->AddString($parrAdjustDetails->[$::eAdjIdxProductRef]);
$Self->AddString($parrAdjustDetails->[$::eAdjIdxProductDescription]);
$Self->AddDWord(0);
$Self->AddQWord($nAmount);
$Self->AddQWord($nAmount);
$Self->AddQWord(0);
$Self->AddString('');
$Self->AddString('');
$Self->AddString('');
$Self->AddString('');
$Self->AddDWord(0);
$Self->AddDWord(0);
my $rarrTaxOpaqueData = ActinicOrder::PricesIncludeTaxes() ?
$parrAdjustDetails->[$::eAdjIdxDefOpaqueData] :
$parrAdjustDetails->[$::eAdjIdxCurOpaqueData];
$Self->AddString($rarrTaxOpaqueData->[0]);
$Self->AddString($rarrTaxOpaqueData->[1]);
my $nTax = $parrAdjustDetails->[$::eAdjIdxTax1];
if ($::g_TaxInfo{'EXEMPT1'} ||
!ActinicOrder::IsTaxApplicableForLocation('TAX_1'))
{
if (ActinicOrder::PricesIncludeTaxes())
{
$nTax = -$nTax;
}
}
$Self->AddQWord($nTax);
$nTax = $parrAdjustDetails->[$::eAdjIdxTax2];
if ($::g_TaxInfo{'EXEMPT2'} ||
!ActinicOrder::IsTaxApplicableForLocation('TAX_2'))
{
if (ActinicOrder::PricesIncludeTaxes())
{
$nTax = -$nTax;
}
}
$Self->AddQWord($nTax);
$Self->AddString('');
$Self->AddQWord(0);
$Self->AddDWord(0);
$Self->AddDWord(0);
$Self->AddString('');
my @arrResponse;
if($pProduct)
{
@arrResponse = ActinicOrder::PrepareProductTaxOpaqueData($pProduct,
$nAmount, $$pProduct{'PRICE'}, $parrAdjustDetails->[$::eAdjIdxCustomTaxAsExempt]);
}
else
{
@arrResponse = ActinicOrder::PrepareProductTaxOpaqueData(undef,
$nAmount, $nAmount, $::FALSE, $ActinicOrder::PRORATA);
}
$Self->AddString($arrResponse[2]);
$Self->AddByte(0);
$Self->AddByte(0);
$Self->AddByte($parrAdjustDetails->[$::eAdjIdxLineType]);
$Self->AddDWord($nOrderSequenceNumber);
$Self->AddByte($parrAdjustDetails->[$::eAdjIdxTaxTreatment]);
$Self->AddString($parrAdjustDetails->[$::eAdjIdxCouponCode]);
}