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
Init();
DispatchCommands();
exit;
sub DispatchCommands
{
my (@Response, $Status, $Message, $sHTML, $sAction, $pFailures, $sCartID);
$sAction = $::g_InputHash{"ACTION"};
if ($sAction eq $::g_sUpdateCartLabel ||
$sAction eq "" ||
$sAction eq $::g_sSendCouponLabel)
{
@Response = UpdateCart();
$::s_bCartQuantityCalculated = $::FALSE;
}
elsif ($sAction eq $::g_sContinueShoppingLabel)
{
@Response = ContinueShopping();
}
elsif ($sAction eq $::g_sSaveShoppingListLabel)
{
@Response = SaveCartToXmlFile($::FALSE);
}
elsif ($sAction eq $::g_sGetShoppingListLabel)
{
@Response = GetCartFromXmlFile();
}
elsif ($::g_InputHash{"PAGE"} eq "CONFIRM")
{
if ($sAction eq $::g_sConfirmButtonLabel)
{
@Response = SaveCartToXmlFile($::TRUE);
}
else
{
@Response = ($::SUCCESS, "", undef);
}
}
elsif ($sAction eq $::g_sCheckoutNowLabel)
{
@Response = StartCheckout();															
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
exit;
}
($Status, $Message, $sHTML,$sCartID) = ActinicOrder::ShowCart($pFailures);
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
exit;
}	
PrintPage($sHTML, $sCartID);		
}
sub StartCheckout
{
my @Response = UpdateCart();
if ($Response[0] == $::BADDATA)
{
return @Response;
}
my $sURL = $::g_InputHash{CHECKOUTURL} ;
$sURL   .= $::g_InputHash{SHOP} ? '&SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) : '';
my ($bClearFrames) = ACTINIC::IsPartOfFrameset() && $$::g_pSetupBlob{UNFRAMED_CHECKOUT};
@Response = ACTINIC::BounceToPagePlain(0, "",
$$::g_pSetupBlob{CHECKOUT_DESCRIPTION},
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $sURL , \%::g_InputHash,
$bClearFrames);	
my ($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}		
PrintPage($sHTML);
exit;		
}
sub ContinueShopping
{
my @Response = UpdateCart();
if ($Response[0] == $::BADDATA)
{
return @Response;
}
my $sURL = $::Session->GetLastShopPage();
my ($bClearFrames) = $::FALSE;
if (!ACTINIC::IsPartOfFrameset() &&
ACTINIC::IsCatalogFramed())
{
$sURL = ACTINIC::RestoreFrameURL($sURL);
$bClearFrames = $::TRUE;
}
else
{
if ($ACTINIC::B2B->Get('UserDigest') &&
ACTINIC::IsCatalogFramed() &&
$$::g_pSetupBlob{'UNFRAMED_CHECKOUT'})
{
$bClearFrames = $::TRUE;
}
}
@Response = ACTINIC::BounceToPagePlain(0, "",
"",
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $sURL , \%::g_InputHash,
$bClearFrames);
my ($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}		
PrintPage($sHTML);
exit;		
}
sub UpdateCart
{
my ($nStatus, $sMessage, $pFailure, @Response);
@Response = $::Session->GetCartObject();
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
my @aFailureList;
my %hRemoved;
my ($pOrderDetail, $sErrorMessage);
my $nIndex;
my $nItemCount = $#$pCartList;
foreach ($nIndex = $nItemCount; $nIndex >= 0; $nIndex--)
{
my $nTempQuantity = GetQuantity($nIndex)+1-1;
if (IsMarkedForRemove($nIndex) ||
($nTempQuantity eq GetQuantity($nIndex) &&
GetQuantity($nIndex) == 0))
{
$pCartObject->RemoveItem($nIndex);
$hRemoved{$nIndex} = 1;
}		
}
$nIndex	= 0;
my $nLoopIndex;
foreach ($nLoopIndex = 0; $nLoopIndex <= $nItemCount; $nLoopIndex++)
{
if ($hRemoved{$nLoopIndex})
{
next;
}
$pOrderDetail = $pCartList->[$nIndex];
$$pOrderDetail{"QUANTITY"} = GetQuantity($nLoopIndex);
my $sInfo = ActinicOrder::InfoGetValue($$pOrderDetail{'PRODUCT_REFERENCE'}, $nLoopIndex);
if ($sInfo)
{
$$pOrderDetail{"INFOINPUT"} = $sInfo;
}
my ($nStatus, $sYear, $sMonth, $sDay) = GetDate($nLoopIndex);
if ($nStatus == $::SUCCESS)
{
$$pOrderDetail{"DATE"} = sprintf("%4.4d/%2.2d/%2.2d", $sYear, $sMonth, $sDay);
}
$pCartObject->UpdateItem($nIndex, $pOrderDetail);
$nIndex++;
}
$nIndex = 0;
foreach ($nLoopIndex = 0; $nLoopIndex <= $nItemCount; $nLoopIndex++)
{
if ($hRemoved{$nLoopIndex})
{
next;
}
$pOrderDetail = $pCartList->[$nIndex];
$$pOrderDetail{"QUANTITY"} = GetQuantity($nLoopIndex);
my $sInfo = ActinicOrder::InfoGetValue($$pOrderDetail{'PRODUCT_REFERENCE'}, $nLoopIndex);
if ($sInfo)
{
$$pOrderDetail{"INFOINPUT"} = $sInfo;
}
my ($nStatus, $sYear, $sMonth, $sDay) = GetDate($nLoopIndex);
if ($nStatus == $::SUCCESS)
{
$$pOrderDetail{"DATE"} = sprintf("%4.4d/%2.2d/%2.2d", $sYear, $sMonth, $sDay);
}	
($nStatus, $sMessage, $pFailure) = ValidateCartItem($nIndex, $nLoopIndex, $pOrderDetail);
if ($nStatus != $::SUCCESS)
{
$sErrorMessage .= "<BR>" . $sMessage;
push @aFailureList, $pFailure;
$nIndex++;
next;
}
push @aFailureList, {};
$nIndex++;
}
my $sCoupon = $::g_InputHash{'COUPONCODE'};
if ($sCoupon ne "" &&
$$::g_pDiscountBlob{'COUPON_ON_CART'})
{
@Response = ActinicDiscounts::ValidateCoupon($sCoupon);
if ($Response[0] == $::FAILURE)
{
$sErrorMessage .= ACTINIC::GetPhrase(-1, 1971,  $::g_sRequiredColor) . $Response[1] . ACTINIC::GetPhrase(-1, 1970);
}
else
{
if (ACTINIC::GetPhrase(-1, 2355) ne $sCoupon)
{
$::g_PaymentInfo{'COUPONCODE'} = $sCoupon;
$::Session->SetCoupon($::g_PaymentInfo{'COUPONCODE'});
}
}
}		
if (length $sErrorMessage > 0)
{
my $sHTML = sprintf($::ERROR_FORMAT, $sErrorMessage);
$ACTINIC::B2B->SetXML('CARTUPDATEERROR', $sHTML);
return ($::BADDATA, "", \@aFailureList);
}
$pCartObject->CombineCartLines();
return ($::SUCCESS, "", \@aFailureList);
}
sub ValidateCartItem
{
my ($nIndex, $nLoopIndex, $pCurrentDetail) = @_;
my $pOrderDetail;
$$pOrderDetail{'PRODUCT_REFERENCE'} = $$pCurrentDetail{'PRODUCT_REFERENCE'};
$$pOrderDetail{"SID"} 			= $$pCurrentDetail{"SID"};
$$pOrderDetail{"QUANTITY"} 	= GetQuantity($nLoopIndex);
$$pOrderDetail{"INFOINPUT"} 	= ActinicOrder::InfoGetValue($$pOrderDetail{'PRODUCT_REFERENCE'}, $nLoopIndex);
my ($nStatus, $sYear, $sMonth, $sDay) = GetDate($nLoopIndex);
if ($nStatus == $::SUCCESS)
{
$$pOrderDetail{"DATE"} = sprintf("%4.4d/%2.2d/%2.2d", $sYear, $sMonth, $sDay);
}	
foreach my $key (keys %$pCurrentDetail)
{
if ($key =~ /COMPONENT_/)
{
$$pOrderDetail{$key} = $$pCurrentDetail{$key};
}
}
$::s_bCartQuantityCalculated = $::FALSE;
return(ActinicOrder::ValidateOrderDetails($pOrderDetail, $nIndex));
}
sub IsMarkedForRemove
{
my $nIndex = shift;
return($::g_InputHash{"D_" . $nIndex} =~ /on/i ? $::TRUE : $::FALSE);
}
sub GetQuantity
{
my $nIndex = shift;
return($::g_InputHash{"Q_" . $nIndex});
}
sub GetDate
{
my $nIndex = shift;
my $sYear 	= $::g_InputHash{"Y_" . $nIndex};
my $sMonth	= $::g_MonthMap{$::g_InputHash{"M_" . $nIndex}};
my $sDay 	= $::g_InputHash{"DAY_" . $nIndex};
if ($sYear  &&
$sMonth &&
$sDay)
{
return ($::SUCCESS, $sYear, $sMonth, $sDay);
}
return ($::FAILURE, 0, 0, 0);
}
sub SaveCartToXmlFile
{
my $bSkipCheck = shift;
if ($::g_InputHash{"PAGE"} eq "CART")
{
my @Response = UpdateCart();
if ($Response[0] == $::BADDATA)
{
return @Response;
}	
}	
my @Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
if ($pCartObject->CountItems() > 0)
{
if ($pCartObject->IsExternalCartFileExist() &&
!$bSkipCheck)
{
return (DisplayConfirmationPage());
}
@Response = $pCartObject->SaveXmlFile();
return (@Response);
}
else
{
@Response = ACTINIC::BounceToPageEnhanced(5, ACTINIC::GetPhrase(-1, 1962) . ACTINIC::GetPhrase(-1, 44, $::g_sCart, $::g_sCart) . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2049),
$$::g_pSetupBlob{CHECKOUT_DESCRIPTION},
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $::Session->GetLastPage(), \%::g_InputHash,
$::FALSE);	
my ($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}		
PrintPage($sHTML);
exit;																
}
return @Response;
}
sub DisplayConfirmationPage
{	
my $sLine;
my %VariableTable;
$sLine = ACTINIC::GetPhrase(-1, 1962) . ACTINIC::GetPhrase(-1, 2163) . ACTINIC::GetPhrase(-1, 1970);
$sLine .= "<P>";
$sLine .= "<INPUT TYPE=SUBMIT NAME=ACTION VALUE=\"$::g_sConfirmButtonLabel\"> \n";
$sLine .= "<INPUT TYPE=SUBMIT NAME=ACTION VALUE=\"$::g_sCancelButtonLabel\"> <P>\n";
$VariableTable{$::VARPREFIX."BODY"} = $sLine;
$VariableTable{$::VARPREFIX."PAGE"} = "<INPUT TYPE=HIDDEN NAME=PAGE VALUE=\"CONFIRM\">\n";
my ($Status, $Message, $sPath, $sHTML);
$sPath = ACTINIC::GetPath();
my @Response = ACTINIC::TemplateFile($sPath."CRTemplate.html", \%VariableTable);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
PrintPage($sHTML);
exit;
}
sub GetCartFromXmlFile
{
if ($::g_InputHash{"PAGE"} eq "CART")
{
my @Response = UpdateCart();
if ($Response[0] == $::BADDATA)
{
return @Response;
}	
}	
my @Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
if (!$pCartObject->IsExternalCartFileExist())
{
my $sCartUrl = $::g_sCartScript . "?ACTION=SHOWCART&BPN=catalogbody.html";
@Response = ACTINIC::BounceToPageEnhanced(5, ACTINIC::GetPhrase(-1, 1962) . ACTINIC::GetPhrase(-1, 2159) . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2049),
$$::g_pSetupBlob{CHECKOUT_DESCRIPTION},
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $sCartUrl, \%::g_InputHash,
$::FALSE);	
my ($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}		
PrintPage($sHTML);
exit;			
}
@Response = $pCartObject->RestoreXmlFile();
if ($Response[0] == $::FAILURE)
{
return (@Response);
}
if ($Response[0] == $::BADDATA)
{
my $sHTML = sprintf($::ERROR_FORMAT, $Response[1]);
$ACTINIC::B2B->SetXML('CARTUPDATEERROR', $sHTML);
}
return ($::SUCCESS, '', $Response[2]);
}
sub Init
{
$::prog_name = "CARTMAN";
$::prog_name = $::prog_name;
$::prog_ver = '$Revision: 18819 $ ';
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
if(defined $::g_InputHash{"ACTION_UPDATE.x"})
{
$::g_InputHash{"ACTION"} = $::g_sUpdateCartLabel;
}
elsif(defined $::g_InputHash{"ACTION_SAVE.x"})
{
$::g_InputHash{"ACTION"} = $::g_sSaveShoppingListLabel;
}
elsif(defined $::g_InputHash{"ACTION_GET.x"})
{
$::g_InputHash{"ACTION"} = $::g_sGetShoppingListLabel;
}
elsif(defined $::g_InputHash{"ACTION_BUYNOW.x"})
{
$::g_InputHash{"ACTION"} = $::g_sCheckoutNowLabel;
}			
elsif(defined $::g_InputHash{"ACTION_CONTINUE.x"})
{
$::g_InputHash{"ACTION"} = $::g_sContinueShoppingLabel;
}				
elsif(defined $::g_InputHash{"ACTION_SEND.x"})
{
$::g_InputHash{"ACTION"} = $::g_sSendCouponLabel;
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
my ($Status, $Message) = ACTINIC::ReadDiscountBlob($sPath); 
if ($Status != $::SUCCESS)
{
return ($Status, $Message);
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
@Response = ACTINIC::ReadTaxSetupFile($sPath);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
ActinicOrder::ParseAdvancedTax();
return ($::SUCCESS, "");
}
sub PrintPage
{
my $sCartCookie = ActinicOrder::GenerateCartCookie();
return (
ACTINIC::UpdateDisplay($_[0], $::g_OriginalInputData,
$_[1], $_[2], '', $sCartCookie)
);
}