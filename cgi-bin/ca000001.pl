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
my (@Response, $Status, $Message, $sHTML, $sAction, $sCartID);
$::g_sCurrentPage = $::g_InputHash{"PAGE"};
$sAction = $::g_InputHash{"ACTION"};
my ($key, $value);
if ($sAction eq "REGQUERY")
{
SendRegInfo();
exit;
}
elsif ($sAction eq "COOKIEERROR")
{
$::bCookieCheckRequired = $::FALSE;
my $sMessage = ACTINIC::GetPhrase(-1, 52) . "\n";
($Status, $Message, $sHTML) = ReturnToLastPage(-1, $sMessage, ACTINIC::GetPhrase(-1, 53));
PrintPage($sHTML, $sCartID);
exit;
}
elsif ($$::g_pSetupBlob{CATALOG_SUSPENDED})
{
@Response = ReturnToLastPage(7, ACTINIC::GetPhrase(-1, 2077), "");
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
exit;
}
@Response = BounceHelper($sHTML);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
exit;
}
PrintPage($sHTML);
}
elsif (($sAction eq $::g_sSendCouponLabel) ||
(($sAction eq "") &&
($::g_InputHash{'COUPONCODE'} ne "")))
{
RecordCouponCode();
exit;
}
elsif ($sAction eq "SSLBOUNCE")
{
PrintSSLBouncePage();
exit;
}
elsif ($sAction eq "SHOWCART")
{
ShowCart();
}
elsif ($::g_sCurrentPage eq "PRODUCT")
{
ProcessAddToCartCall();
}
elsif ($::g_sCurrentPage eq "ORDERDETAIL")
{
if ($sAction eq $::g_sCancelButtonLabel)
{
@Response = ReturnToLastPage(0, "", "");
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
exit;
}
PrintPage($sHTML);
}
else
{
my %OrderDetails;
($Status, $Message, %OrderDetails) = ValidateOrderDetails($::FALSE);
if ($Status == $::BADDATA)
{
$sHTML = $Message;
PrintPage($sHTML, $sCartID);
exit;
}
elsif ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
AddItemToCart(\%OrderDetails);
@Response = BounceAfterAddToCart();
($Status, $Message, $sHTML, $sCartID) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
exit;
}
PrintPage($sHTML, $sCartID);
}
}
else
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 1284), ACTINIC::GetPath());
exit;
}
}
sub RecordCouponCode
{
my $sErrorMessage;
my @Response = $::Session->GetCartObject();
if ($::g_InputHash{'COUPONCODE'} ne "" &&
$$::g_pDiscountBlob{'COUPON_ON_PRODUCT'})
{
@Response = ActinicDiscounts::ValidateCoupon($::g_InputHash{'COUPONCODE'});
if ($Response[0] == $::FAILURE)
{
$sErrorMessage .= ACTINIC::GetPhrase(-1, 1971,  $::g_sRequiredColor) . $Response[1] . ACTINIC::GetPhrase(-1, 1970);
}
else
{
$::g_PaymentInfo{'COUPONCODE'} = $::g_InputHash{'COUPONCODE'};
$::Session->SetCoupon($::g_PaymentInfo{'COUPONCODE'});
}
}
if ($sErrorMessage ne "")
{
my %hErrors;
@Response = ReturnToLastPage(5, $sErrorMessage);
}
else
{
@Response = ReturnToLastPage(0, "");
}
PrintPage($Response[2]);
}
sub ProcessAddToCartCall
{
my ($sHTML, $sCartID, @Response);
my ($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($::g_InputHash{SID});
if ($Status == $::FAILURE)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
($Status, $Message) = ACTINIC::ReadSectionFile(ACTINIC::GetPath().$sSectionBlobName);
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
my $nCartMode = ${$::g_pSectionList{$sSectionBlobName}}{CART_MODE};
if ($nCartMode == $::ATCM_SIMPLE)
{
@Response = OrderDetails();
}
elsif	($nCartMode == $::ATCM_ADVANCED)
{
@Response = AddSingleItem();
}
elsif ($nCartMode == $::ATCM_SINGLE)
{
@Response = AddMultipleItems();
}
elsif ($nCartMode == $::ATCM_PDONCART)
{
@Response = AddItemWithDefaultParams();
}
($Status, $Message, $sHTML, $sCartID) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
exit;
}
PrintPage($sHTML, $sCartID);
exit
}
sub AddItemToCart
{
my $pValues = shift;
$$pValues{'PRODUCT_REFERENCE'} =~ s/^\d+\!//g;
my ($Status, $Message, $pCartObject) = $::Session->GetCartObject();
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
exit;
}
$pCartObject->AddItem($pValues);
$pCartObject->CombineCartLines();
}
sub AddItemWithDefaultParams
{
my ($sProdRef, $pProduct) = GetProductDetails();
my ($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($::g_InputHash{SID});
if ($Status == $::FAILURE)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
my @Response;
@Response = CheckQuantity($sProdRef, $sSectionBlobName, $pProduct, -1);
if ($Response[0] != $::SUCCESS)
{
return ($::SUCCESS, $Response[1], $Response[2], "");
}
my ($bAllowedToBuy, $sMessage) = IsCustomerAllowedToBuy($pProduct);
if (!$bAllowedToBuy)
{
@Response = ReturnToLastPage(-1, $sMessage);
return @Response;
}
my ($pCartObject);
my %Values = GetProductFromInput($sProdRef, $pProduct);
if (!defined $Values{QUANTITY})
{
$sMessage = "<B>" . $$pProduct{"NAME"} . ":</B><BR><BLOCKQOUTE>" . "Invalid order details" . "</BLOCKQOUTE>";
return ($::FAILURE, $sMessage, undef, undef);
}
my ($nCartQuantity, $nMinQuantity);
$nMinQuantity = $$pProduct{"MIN_QUANTITY_ORDERABLE"}; # get the min quantity count.  this is maintained on a per product.
my ($pProductQuantities);
($Status, $sMessage, $pProductQuantities) = ActinicOrder::CalculateCartQuantities();
if ($Status != $::SUCCESS)
{
return ($Status, $sMessage);
}
$nCartQuantity = $$pProductQuantities{$sProdRef};
if (($Values{QUANTITY} + $nCartQuantity) < $nMinQuantity)
{
$Values{QUANTITY} = $nMinQuantity - $nCartQuantity;
}
$::s_bCartQuantityCalculated = $::FALSE;
AddItemToCart(\%Values);
my @aFailureList;
@Response = ActinicOrder::ShowCart(\@aFailureList);
return @Response;
}
sub AddSingleItem
{
my ($sProdRef, $pProduct) = GetProductDetails();
my %Values = GetProductFromInput($sProdRef, $pProduct);
my ($bAllowedToBuy, $sMessage) = IsCustomerAllowedToBuy($pProduct);
if (!$bAllowedToBuy)
{
my @Response = ReturnToLastPage(-1, $sMessage);
return @Response;
}
my ($Status, $Message, $pFailures) = ActinicOrder::ValidateOrderDetails(\%Values);
if ($Status == $::SUCCESS)
{
AddItemToCart(\%Values);
return (BounceAfterAddToCart());
}
my (%hErrors, $sItem);
$pFailures->{MESSAGE} = $Message;
$pFailures->{PRODUCTNAME} = $pProduct->{NAME};
$pFailures->{PREVQUANTITY} = $Values{QUANTITY};
$pFailures->{PREVDATE} = $Values{DATE};
$pFailures->{PREVINFOINPUT} = $Values{INFOINPUT};
foreach $sItem (keys %::g_InputHash)
{
if ($sItem =~ /(v_$sProdRef\_\d+)$/)
{
$pFailures->{$1} = $::g_InputHash{$1};
}
}
$hErrors{$sProdRef} = $pFailures;
$Message = ACTINIC::GetPhrase(-1,2181);
my @Response = RedisplayProductPageWithErrors($Message, %hErrors);
return @Response;
}
sub AddMultipleItems
{
my $sPath = ACTINIC::GetPath();
my ($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($::g_InputHash{SID});
if ($Status == $::FAILURE)
{
ACTINIC::ReportError($Message, $sPath);
}
my $sItem;
my %hErrors;
my $bErrorOnPage = $::FALSE;
my ($pCartObject, @Response, @aToBeAdded);
@Response = $::Session->GetCartObject();
($Status, $Message, $pCartObject) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
exit;
}
my $nAddedProducts = 0;
my $nFailedProducts = 0;
my ($Status, $Message, $bFailure, $pFailures, $bAllowedToBuy);
foreach $sItem (keys %::g_InputHash)
{
$bFailure = $::FALSE;
if ($sItem !~ /^Q_(.*)$/)
{
next;
}
my $sProdref = $1;
if ($::g_InputHash{$sItem} eq "" ||
$::g_InputHash{$sItem} eq "0")
{
next;
}
my ($pProduct);
@Response = ACTINIC::GetProduct($sProdref, $sSectionBlobName, $sPath);
($Status, $Message, $pProduct) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, $sPath);
}
my %Values = GetProductFromInput($sProdref, $pProduct);
($bAllowedToBuy, $Message) = IsCustomerAllowedToBuy($pProduct);
if (!$bAllowedToBuy)
{
$pFailures = {};
$nFailedProducts++;
$bFailure = $::TRUE;
}
if (!$bFailure)
{
($Status, $Message, $pFailures) = ActinicOrder::ValidateOrderDetails(\%Values);
if ($Status == $::SUCCESS)
{
push @aToBeAdded, \%Values;
$nAddedProducts++;
}
else
{
$nFailedProducts++;
$bFailure = $::TRUE;
$bErrorOnPage = $::TRUE;
}
}
$pFailures->{REDISPLAYONLY} = !$bFailure;
$pFailures->{MESSAGE} = $Message;
$pFailures->{PRODUCTNAME} = $pProduct->{NAME};
$pFailures->{PREVQUANTITY} = $Values{QUANTITY};
$pFailures->{PREVDATE} = $Values{DATE};
$pFailures->{PREVINFOINPUT} = $Values{INFOINPUT};
foreach $sItem (keys %::g_InputHash)
{
if ($sItem =~ /(v_$sProdref\_\d+)$/)
{
$pFailures->{$1} = $::g_InputHash{$1};
}
}
$hErrors{$sProdref} = $pFailures;
}
if ($nAddedProducts == 0 &&
$nFailedProducts == 0)
{
$Message = ACTINIC::GetPhrase(-1,2202);
$bErrorOnPage = $::TRUE;
}
elsif ($nFailedProducts == 0)
{
my $pItem;
foreach $pItem (@aToBeAdded)
{
AddItemToCart($pItem);
}
}
if ($bErrorOnPage)
{
if ($nAddedProducts > 0)
{
$Message = ACTINIC::GetPhrase(-1,2181);
}
@Response = RedisplayProductPageWithErrors($Message, %hErrors);
}
else
{
@Response = BounceAfterAddToCart();
}
return @Response;
}
sub RedisplayProductPageWithErrors
{
my ($sErrorMessage, %hErrors) = @_;
my $sPath = ACTINIC::GetPath();
my $sFileName = $::g_InputHash{PAGEFILENAME};
my $sMessage;
$sMessage = ACTINIC::GetPhrase(-1,1971, $::g_sErrorColor) . $sErrorMessage . ACTINIC::GetPhrase(-1,1970);
my $sGenMessage = ACTINIC::GetPhrase(-1,2178, $$::g_pSetupBlob{FORM_BACKGROUND_COLOR}, $sMessage);
my %VariableTable;
my @Response = ACTINIC::TemplateFile($sPath.$sFileName, \%VariableTable);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $sProdref;
foreach $sProdref (keys %hErrors)
{
$sMessage = $hErrors{$sProdref}->{MESSAGE};
$sMessage = ACTINIC::GetPhrase(-1,1971, $::g_sErrorColor) . $sMessage . ACTINIC::GetPhrase(-1,1970);
$ACTINIC::B2B->SetXML('CartError_' . $sProdref, $sMessage);
my $sProdRefMeta = quotemeta ($sProdref);
my $sStyle = " STYLE=\"background-color: $::g_sErrorColor\"";
my ($sTemp, $sTempIndex);
if ($hErrors{$sProdref}->{QUANTITY})
{
$Response[2] =~ s/(NAME=\s*["']?Q_$sProdRefMeta['"]?)/$1 $sStyle/is;
}
if ($hErrors{$sProdref}->{INFOINPUT})
{
$Response[2] =~ s/(NAME=\s*["']?O_$sProdRefMeta['"]?)/$1 $sStyle/is;
}
if ($hErrors{$sProdref}->{DATE})
{
$Response[2] =~ s/(NAME=\s*["']?Y_$sProdRefMeta['"]?)/$1 $sStyle/is;
$Response[2] =~ s/(NAME=\s*["']?M_$sProdRefMeta['"]?)/$1 $sStyle/is;
$Response[2] =~ s/(NAME=\s*["']?DAY_$sProdRefMeta['"]?)/$1 $sStyle/is;
}
$sTemp = $hErrors{$sProdref}->{PREVQUANTITY};
$Response[2] =~ s/(NAME=\s*["']?Q_$sProdRefMeta['"]?[^>]*?VALUE=\s*["']?)(\d+)(['"]?)/$1$sTemp$3/is;
$sTemp = $hErrors{$sProdref}->{PREVINFOINPUT};
if ($sTemp)
{
if (!($Response[2] =~ /NAME=\s*["']?O_$sProdRefMeta['"]?[^>]*?VALUE=\s*['"]?/) )
{
$Response[2] =~ s/(NAME=\s*["']?O_$sProdRefMeta['"]?.*?)(>)/$1 VALUE=\"$sTemp\"$2/is;
}
else
{
$Response[2] =~ s/(NAME=\s*["']?O_$sProdRefMeta['"]?[^>]*?VALUE=\s*["']?)(.*?)(['"]?)/$1$sTemp$3/is;
}
}
my ($nYear, $nMonth, $nDay, $sMonth);
$sTemp = $hErrors{$sProdref}->{PREVDATE};
if ($sTemp)
{
($nYear, $nMonth, $nDay, $sMonth) = ParseDateStamp($sTemp);
$Response[2] =~ s/(NAME=\s*["']?Y_$sProdRefMeta['"]?.*?)(<OPTION)\s+SELECTED(>)(.*?)(<\/SELECT)/$1$2$3$4$5/is;
$Response[2] =~ s/(NAME=\s*["']?Y_$sProdRefMeta['"]?.*?)(<OPTION)(>$nYear)/$1$2 SELECTED$3/is;
$Response[2] =~ s/(NAME=\s*["']?M_$sProdRefMeta['"]?.*?)(<OPTION)(>$sMonth)/$1$2 SELECTED$3/is;
$Response[2] =~ s/(NAME=\s*["']?DAY_$sProdRefMeta['"]?.*?)(<OPTION)(>$nDay)/$1$2 SELECTED$3/is;
}
my $sKey;
my ($sSearch, $sSearch1);
foreach $sKey (keys %{$hErrors{$sProdref}})
{
if ($sKey =~ /v_$sProdRefMeta\_(\d+)/)
{
my $nCompIndex = $1;
$sTempIndex = 'v_' . $sProdRefMeta . '_' . $nCompIndex;
$sTemp = $hErrors{$sProdref}->{$sKey};
my $sDropDownRegExp = "<SELECT\\s+NAME=\\s*[\"']?" . $sTempIndex . "[\"']?";
my $sRadioButtonRegExp = "<INPUT\\s+TYPE=RADIO\\s+NAME=\\s*[\"']?" . $sTempIndex . "[\"']?";
my $sCheckBoxRegExp = "<INPUT\\s+TYPE=CHECKBOX\\s+NAME=\\s*[\"']?" . $sTempIndex . "[\"']?";
if ($Response[2] =~ /$sDropDownRegExp/is)
{
$sSearch = "(NAME=\\s*[\"']?" . $sTempIndex . "[\"']?.*?\\<OPTION\\s+VALUE=\\s*[\"']?" . $sTemp . "[\"']?)";
$Response[2] =~ s/$sSearch/$1 SELECTED/is;
}
elsif ($Response[2] =~ /$sRadioButtonRegExp/is)
{
$sSearch = "(<INPUT\\s+TYPE=RADIO\\s+NAME=\\s*[\"']?" . $sTempIndex . "[\"']?\\s+VALUE=\\s*[\"']?" . $sTemp . "[\"']?)";
$sSearch1 = "(<INPUT\\s+TYPE=RADIO\\s+NAME=\\s*[\"']?" . $sTempIndex . "[\"']?\\s+VALUE=\\s*[\"']?.*?[\"']?)\\s+CHECKED\\s*(>)";
$Response[2] =~ s/$sSearch1/$1$2/is;
$Response[2] =~ s/$sSearch/$1 CHECKED/is;
}
elsif ($Response[2] =~ /$sCheckBoxRegExp/is)
{
if ($sTemp =~ /on/i)
{
$sSearch = "(<INPUT\\s+TYPE=CHECKBOX\\s+NAME=\\s*[\"']?" . $sTempIndex . "[\"']?)";
$Response[2] =~ s/$sSearch/$1 CHECKED /is;
}
}
}
}
if (!$hErrors{$sProdref}->{REDISPLAYONLY})
{
$sGenMessage .= ACTINIC::GetPhrase(-1,2179, $sProdref, $hErrors{$sProdref}->{PRODUCTNAME});
}
}
$Response[2] = ACTINIC::MakeExtendedInfoLinksAbsolute($Response[2], $::g_sWebSiteUrl);
$sGenMessage .= ACTINIC::GetPhrase(-1,2180);
$ACTINIC::B2B->SetXML('CartError_List', $sGenMessage);
return (@Response);
}
sub GetProductFromInput
{
my ($ProductRef, $pProduct) = @_;
my ($bInfoExists, $bDateExists, $key, $value, $sMessage, %Values, @Response);
$bInfoExists = $::FALSE;
$bDateExists = $::FALSE;
$sMessage = "";
$bInfoExists = (length $$pProduct{"OTHER_INFO_PROMPT"} != 0); # see if the info field exists.
$bDateExists = (length $$pProduct{"DATE_PROMPT"} != 0);
my $pOrderDetail;
$Values{'PRODUCT_REFERENCE'} = $ProductRef;
$Values{'QDQUALIFY'} = '1';
if (defined $::g_InputHash{"Q_" . $ProductRef})
{
$Values{"QUANTITY"} 	= $::g_InputHash{"Q_" . $ProductRef};
}
else
{
$Values{"QUANTITY"} 	= $::g_InputHash{"QUANTITY"};
}
$Values{"SID"} 		= $::g_InputHash{"SID"};
if ($bInfoExists )
{
$Values{"INFOINPUT"} = ActinicOrder::InfoGetValue($ProductRef, $ProductRef);
}
if ($bDateExists)
{
my $sYear 	= $::g_InputHash{"Y_" . $ProductRef};
my $sMonth	= $::g_InputHash{"M_" . $ProductRef};
my $sDay 	= $::g_InputHash{"DAY_" . $ProductRef};
$sMonth	= $::g_MonthMap{$sMonth};
if ($sYear eq "") 
{
my $now = time(); 
my @now = gmtime($now); 
$sDay = $now[3]; 
$sMonth = $now[4] + 1; 
$sYear = $now[5] + 1900; 
} 
$Values{"DATE"} = sprintf("%4.4d/%2.2d/%2.2d", $sYear, $sMonth, $sDay);
}
if( $pProduct->{COMPONENTS} )
{
if( $pProduct->{PRICING_MODEL} != $ActinicOrder::PRICING_MODEL_STANDARD )
{
$Values{'QDQUALIFY'} = '0';
}
my $k;
foreach $k (keys %::g_InputHash)
{
if( $k =~ /^v_\Q$ProductRef\E\_/ )
{
$Values{'COMPONENT_'.$'} = $::g_InputHash{$k};
}
elsif ($k =~ /^vb_\Q$ProductRef\E\_/)
{
my @sVarSpecItems = split('_', $');
my $nCount;
for ($nCount = 0; $nCount <= $#sVarSpecItems; $nCount+=2)
{
$Values{'COMPONENT_' . $sVarSpecItems[$nCount]} = $sVarSpecItems[$nCount + 1];
}
}
}
}
return %Values;
}
sub SendRegInfo
{
my ($sPath, $sOut, $sType, $key, $value);
my @ItemsToSend = qw(VERSIONFULL CATALOGURL LICENSE DETAILS LASTUPLOADDATE);
if (defined $::g_InputHash{"HTML"} && $::g_InputHash{"HTML"} == 1)
{
$sType = 'text/html';
$sOut = "<HTML><BODY><TABLE WIDTH=100%>";
foreach (@ItemsToSend)
{
$sOut .= "<TR><TD WIDTH=20%>$_</TD><TD WIDTH=80%>$$::g_pCatalogBlob{$_}</TD></TR>";
}
$sOut .= "</TABLE></BODY></HTML>";
}
else
{
$sType = 'application/octet-stream';
foreach (@ItemsToSend)
{
$sOut .= "$_|$$::g_pCatalogBlob{$_}|";
}
}
my $nLength = length $sOut;
binmode STDOUT;
ACTINIC::PrintHeader($sType, $nLength, "", $::TRUE);
print $sOut;
}
sub BounceAfterAddToCart
{
my ($Status, $Message, %OrderDetails, $sCartID, @Response);
$::s_bCartQuantityCalculated = $::FALSE;
my $pCartObject;
@Response = $::Session->GetCartObject();
($Status, $Message, $pCartObject) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
exit;
}
$pCartObject->CombineCartLines();
my $nLineCount = $pCartObject->CountItems();
my ($sPageTitle, $sCartHTML);
$sPageTitle = ACTINIC::GetPhrase(-1, 51);
my $pCartList = $pCartObject->GetCartList();
@Response = ActinicOrder::GenerateShoppingCartLines($pCartList, $::FALSE, [], "ODTemplate.html");
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $sCartHTML = $Response[2];
my ($sHTML);
my $nBounceDelay = $$::g_pSetupBlob{'BOUNCE_PAGE_DELAY'};
if ($nBounceDelay == 0 ||
(defined $$::g_pSetupBlob{'DISPLAY_CART_AFTER_CONFIRM'} &&
$$::g_pSetupBlob{'DISPLAY_CART_AFTER_CONFIRM'}))
{
$::s_bCartQuantityCalculated = $::FALSE;
ShowCart();
}
elsif ($::g_InputHash{ACTION} eq ACTINIC::GetPhrase(-1, 184))
{
@Response = ACTINIC::EncodeText($::Session->GetBaseUrl(), $::FALSE);
my $sDestinationUrl = $::g_InputHash{CHECKOUTURL} ;
($Status, $sHTML) = ActinicOrder::CheckBuyerLimit($sCartID,$sDestinationUrl,$::FALSE);
if ($Status != $::SUCCESS)
{
return ($::SUCCESS,"",$sHTML,$sCartID);
}
@Response = ACTINIC::BounceToPageEnhanced(2, ACTINIC::GetPhrase(-1, 1962) .  $sCartHTML . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2051),
$sPageTitle, $::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob,
$sDestinationUrl, \%::g_InputHash, $$::g_pSetupBlob{UNFRAMED_CHECKOUT});
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
}
else
{
@Response = ReturnToLastPage($nBounceDelay, ACTINIC::GetPhrase(-1, 1962) . $sCartHTML . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2051),
$sPageTitle);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
}
return ($::SUCCESS, "", $sHTML);
}
sub ValidateOrderDetails
{
my ($bInfoExists, $bDateExists, $key, $value, $sMessage, %Values);
$bInfoExists = $::FALSE;
$bDateExists = $::FALSE;
$sMessage = "";
my ($sCookie, $Status, $Message, @Response);
$sCookie = $::Session->GetSessionID();
my ($ProductRef, $pProduct);
$ProductRef = $::g_InputHash{"PRODREF"};
if (length $ProductRef == 0)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 54), 0, 0);
}
my ($sSectionBlobName);
($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($::g_InputHash{SID});
if ($Status == $::FAILURE)
{
return ($Status, $Message);
}
@Response = ACTINIC::GetProduct($ProductRef, $sSectionBlobName, ACTINIC::GetPath());
($Status, $Message, $pProduct) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
%Values = GetProductFromInput($ProductRef, $pProduct);
my $pFailure;
($Status, $Message, $pFailure) = ActinicOrder::ValidateOrderDetails(\%Values, -1);
if ($Status != $::SUCCESS)
{
my $sHTML = sprintf($::ERROR_FORMAT, $Message);
$ACTINIC::B2B->SetXML('CARTUPDATEERROR', $sHTML);
my $sCartID;
my ($nYear, $nMonth, $nDay, $sMonth) = ParseDateStamp($Values{"DATE"});
@Response = OrderDetails($nDay, $nMonth, $nYear, $Values{"INFOINPUT"}, $pFailure);
($Status, $Message, $sHTML, $sCartID) = @Response;
if ($Status != $::SUCCESS)
{
return(@Response);
}
my (%Variables);
$Variables{"NAME=QUANTITY VALUE=\"\\d+\""} =
"NAME=QUANTITY VALUE=\"" . $::g_InputHash{"QUANTITY"} ."\"";
@Response = ACTINIC::TemplateString($sHTML, \%Variables);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
return ($::BADDATA, $sHTML, 0, 0);
}
else
{
my (%EmptyPaymentInfo);
$EmptyPaymentInfo{'METHOD'} 		= $::g_PaymentInfo{'METHOD'};
$EmptyPaymentInfo{'USERDEFINED'} = $::g_PaymentInfo{'USERDEFINED'};
$EmptyPaymentInfo{'PONO'}			= $::g_PaymentInfo{'PONO'};
if ($ACTINIC::B2B->Get('UserDigest') ||
defined $::g_PaymentInfo{'SCHEDULE'})
{
$EmptyPaymentInfo{'SCHEDULE'} = $::g_PaymentInfo{'SCHEDULE'};
}
$::Session->UpdateCheckoutInfo(\%::g_BillContact, \%::g_ShipContact, \%::g_ShipInfo, \%::g_TaxInfo,
\%::g_GeneralInfo, \%EmptyPaymentInfo, \%::g_LocationInfo);
return ($::SUCCESS, "", %Values);
}
return ($::FAILURE, "Should never get here (ValidateData)", 0, 0);
}
sub GetProductDetails
{
my ($ProductRef, $key, $value);
my $sPath = ACTINIC::GetPath();
foreach (keys %::g_InputHash)
{
if( $_ =~ /^_/)
{
$ProductRef = $';
$ProductRef =~ s/\.[xy]$//;
$ProductRef =~ s/_.*//g;
last;
}
}
my ($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($::g_InputHash{SID});
if ($Status == $::FAILURE)
{
ACTINIC::ReportError($Message, $sPath);
}
my ($sImageButtonName, $sSuffix);
if( !$ProductRef )
{
$ProductRef = $::g_InputHash{"PRODREF"};
}
if (length $ProductRef == 0)
{
while (($key, $value) = each %::g_InputHash)
{
if (length $::g_sAddToButtonLabel > 0 &&
$value =~ /\Q$::g_sAddToButtonLabel\E/ &&
$key !~ /_/)
{
$ProductRef = $key;
}
if ($key =~ /(.+)\.([xy])$/ &&
$key !~ /_/)
{
if($sImageButtonName)
{
if($sSuffix ne $2)
{
$ProductRef = $sImageButtonName;
}
}
else
{
$sImageButtonName = $1;
$sSuffix = $2;
}
}
if ($key =~ /^vb_([^_]*)_/)
{
$ProductRef = $1;
}
}
my ($Temp);
$Temp = keys %::g_InputHash;
$Temp = $Temp;
}
if (!$ProductRef)
{
if( $sImageButtonName )
{
$ProductRef = $sImageButtonName;
}
else
{
foreach (keys %::g_InputHash)
{
if ($_ =~ /^Q_/i)
{
$ProductRef = $';
last;
}
}
if (!$ProductRef)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 54), $sPath);
}
}
}
my ($pProduct);
my @Response = ACTINIC::GetProduct($ProductRef, $sSectionBlobName, $sPath);
($Status, $Message, $pProduct) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, $sPath);
}
return ($ProductRef, $pProduct);
}
sub CheckQuantity
{
my ($ProductRef, $sSectionBlobName, $pProduct, $nIndex) = @_;
my ($nMaxQuantity, @Response, $Status, $Message);
if ($::g_sCurrentPage eq "PRODUCT")
{
($Status, $Message, $nMaxQuantity) =
ActinicOrder::GetMaxRemains($ProductRef, $sSectionBlobName, $nIndex);
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
}
if (($nMaxQuantity == -1) ||
(($::g_sCurrentPage eq "PRODUCT") &&
($nMaxQuantity == 0)))
{
$Message .= "<B>" . ACTINIC::GetPhrase(-1, 63) . "</B>";
@Response = ReturnToLastPage(5, $Message, ACTINIC::GetPhrase(-1, 64));
return ($::FAILURE, $Response[1], $Response[2], "");
}
if ($$pProduct{'OUT_OF_STOCK'})
{
$Message .= ACTINIC::GetPhrase(-1, 297, $$pProduct{'NAME'}) . "<P>\n";
@Response = ReturnToLastPage(5, $Message, ACTINIC::GetPhrase(-1, 64));
return ($::FAILURE, $Response[1], $Response[2], "");
}
}
return ($::SUCCESS, "", "", $nMaxQuantity);
}
sub OrderDetails
{
my (@Date, $sDefaultInfo, $pFailure);
($Date[0], $Date[1], $Date[2], $sDefaultInfo, $pFailure) = @_;
if (!defined $Date[0])
{
my $now = time;
my @now = gmtime($now);
$Date[0] = $now[3];
$Date[1] = $now[4] + 1;
$Date[2] = $now[5] + 1900;
}
my ($sPath, $bStandAlonePage);
$sPath = ACTINIC::GetPath();
my ($sLine, %VariableTable);
my ($ProductRef, $pProduct) = GetProductDetails();
my ($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($::g_InputHash{SID});
if ($Status == $::FAILURE)
{
ACTINIC::ReportError($Message, $sPath);
}
my ($sCartID, $nMaxQuantity, @Response);
if ($::g_sCurrentPage eq "PRODUCT")
{
@Response = CheckQuantity($ProductRef, $sSectionBlobName, $pProduct, -1);
}
else
{
@Response = CheckQuantity($ProductRef, $sSectionBlobName, $pProduct, -2);
}
if ($Response[0] != $::SUCCESS)
{
return ($::SUCCESS, $Response[1], $Response[2], "");
}
$nMaxQuantity = $Response[3];
my (@DeleteDelimiters, @KeepDelimiters);
my($sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable);
($Status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters, $pSelectTable) =
ActinicOrder::DisplayPreliminaryInfoPhase($::FALSE);
if ($Status != $::SUCCESS)
{
return ($Status, $sMessage, $pVarTable, $pDeleteDelimiters, $pKeepDelimiters);
}
my (@Array1, @Array2, %SelectTable);
@Array1 = %$pVarTable;
@Array2 = %VariableTable;
push (@Array1, @Array2);
%VariableTable = @Array1;
if (defined $pSelectTable)
{
@Array1 = %$pSelectTable;
@Array2 = %SelectTable;
push (@Array1, @Array2);
%SelectTable = @Array1;
}
push (@DeleteDelimiters, @$pDeleteDelimiters);
push (@KeepDelimiters, @$pKeepDelimiters);
($pDeleteDelimiters, $pKeepDelimiters) =
ActinicOrder::ParseDelimiterStatus($::PRELIMINARYINFOPHASE);
push (@DeleteDelimiters, @$pDeleteDelimiters);
push (@KeepDelimiters, @$pKeepDelimiters);
my $nVarCount = (keys %$pVarTable) + (keys %$pSelectTable);
$sLine = "<INPUT TYPE=HIDDEN NAME=PRODREF VALUE=\"$ProductRef\">";
$sLine .= "<INPUT TYPE=HIDDEN NAME=SID VALUE=\"$::g_InputHash{SID}\">";
my $VariantList;
if( $pProduct->{COMPONENTS} )
{
my $sProdRefHTML;
($VariantList, $sProdRefHTML) = ACTINIC::GetVariantList($ProductRef);
$sLine .= $sProdRefHTML;
}
$VariableTable{$::VARPREFIX."PRODUCTREF"} = $sLine;
my $pTree;
($Status, $sMessage, $pTree) = ACTINIC::PreProcessXMLTemplate(ACTINIC::GetPath() . "ODTemplate.html");
if ($Status != $::SUCCESS)
{
return ($Status, $sMessage);
}
my $pXML = new Element({"_CONTENT" => $pTree});
my $sProductLineHTML = ACTINIC_PXML::GetTemplateFragment($pXML, "ODLine");
my %hVariables;
my $sProductTable;
if (!$pProduct->{NO_ORDERLINE} )
{
@Response = ACTINIC::ProcessEscapableText($$pProduct{"NAME"});
($Status, $sLine) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
$hVariables{$::VARPREFIX."PRODUCTNAME"} = $sLine;
@Response = FormatProductReference($ProductRef);
($Status, $Message, $sLine) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
$hVariables{$::VARPREFIX."DISPLAYPRODUCTREF"} = '&nbsp;' . $sLine;
($Status, $Message, $sProductTable) = ACTINIC::TemplateString($sProductLineHTML, \%hVariables);
if ($Status != $::SUCCESS)
{
return ($Status, $Message);
}
}
my (%Component, $pAcomponent, $sComponents);
foreach $pAcomponent (@{$pProduct->{COMPONENTS}})
{
@Response = ActinicOrder::FindComponent($pAcomponent,$VariantList);
($Status, %Component) = @Response;
if ($Status != $::SUCCESS)
{
return ($Status,$Component{text});
}
if( $Component{quantity} > 0 )
{
$hVariables{$::VARPREFIX."PRODUCTNAME"} = "";
$hVariables{$::VARPREFIX."DISPLAYPRODUCTREF"} = "";
if ( $Component{text} )
{
@Response = ACTINIC::ProcessEscapableText($Component{text});
($Status, $sLine) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
$hVariables{$::VARPREFIX."PRODUCTNAME"} =  $sLine;
}
if ( $Component{code} )
{
@Response = FormatProductReference($Component{code});
($Status, $Message, $sLine) = @Response;
if ($Status == $::SUCCESS)
{
$hVariables{$::VARPREFIX."DISPLAYPRODUCTREF"} = '&nbsp;' . $sLine;
}
}
($Status, $Message, $sLine) = ACTINIC::TemplateString($sProductLineHTML, \%hVariables);
if ($Status != $::SUCCESS)
{
return ($Status, $Message);
}
$sProductTable .= $sLine;
}
}
$ACTINIC::B2B->SetXML("ODLine", $sProductTable );
my ($bAllowedToBuy, $sMessage) = IsCustomerAllowedToBuy($pProduct);
if (!$bAllowedToBuy)
{
my @Response = ReturnToLastPage(-1, $sMessage);
return @Response;
}
@Response = ActinicOrder::GetProductPricesHTML($pProduct, \$VariantList, $sSectionBlobName);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$VariableTable{$::VARPREFIX."PRODUCTPRICE"} = $Response[2];
if (($$pProduct{"MIN_QUANTITY_ORDERABLE"} == $$pProduct{"MAX_QUANTITY_ORDERABLE"}) || # nothing to edit - so hard code the quantity
($::g_sCurrentPage eq "PRODUCT" && $nMaxQuantity == 1))
{
if ($nMaxQuantity == 1)
{
$VariableTable{$::VARPREFIX."QUANTITY"} = '1' .
"<INPUT TYPE=HIDDEN NAME=QUANTITY VALUE=\"1\">";
}
else
{
$VariableTable{$::VARPREFIX."QUANTITY"} = $$pProduct{"MIN_QUANTITY_ORDERABLE"} .
"<INPUT TYPE=HIDDEN NAME=QUANTITY VALUE=\"" . $$pProduct{"MIN_QUANTITY_ORDERABLE"} . "\">";
}
}
else
{
my $nDefaultQuantity = $pProduct->{MIN_QUANTITY_ORDERABLE};
if ($::g_sCurrentPage eq "PRODUCT")
{
my $nMaxOrderable = ($pProduct->{MAX_QUANTITY_ORDERABLE} == 0 ? $::MAX_ORD_QTY : $pProduct->{MAX_QUANTITY_ORDERABLE});
if ($nMaxQuantity != $nMaxOrderable)
{
$nDefaultQuantity = 1;
}
}
else
{
$nDefaultQuantity = $::g_InputHash{"Q_$ProductRef"};
}
$VariableTable{$::VARPREFIX."QUANTITY"} = "<INPUT TYPE=TEXT NAME=\"Q_$ProductRef\" VALUE=\"" .
$nDefaultQuantity . "\" SIZE=6 MAXLENGTH=10>";
}
if (length $$pProduct{"DATE_PROMPT"} > 0)
{
my $nMinYear = $$pProduct{"DATE_MIN"};
my $nMaxYear = $$pProduct{"DATE_MAX"};
my ($nDefaultDay, $nDefaultMonth, $nDefaultYear) = (1, 1, $nMinYear);
if ($#Date > 0)
{
if (defined $Date[0])
{
$nDefaultDay = $Date[0];
}
if (defined $Date[1])
{
$nDefaultMonth = $Date[1];
}
if (defined $Date[2])
{
$nDefaultYear = $Date[2];
}
}
my ($sStyle, $sYearLine);
if ($pFailure->{"DATE"})
{
$sStyle = " style=\"background-color: $::g_sErrorColor\"";
}
my $sDayLine 	= ACTINIC::GenerateComboHTML("DAY_$ProductRef", $nDefaultDay, "%2.2d", $sStyle, (1..31));
my $sMonthLine = ACTINIC::GenerateComboHTML("M_$ProductRef", $::g_InverseMonthMap{$nDefaultMonth}, "%s", $sStyle, @::gMonthList);
if ($nMinYear == $nMaxYear)
{
$sYearLine = "$nMinYear<INPUT TYPE=HIDDEN NAME=\"Y_$ProductRef\" VALUE=\"$nMinYear\">"
}
else
{
$sYearLine 	= ACTINIC::GenerateComboHTML("Y_$ProductRef", $nDefaultYear, "%4.4d", $sStyle, ($nMinYear..$nMaxYear));
}
my $sDatePrompt = ACTINIC::FormatDate($sDayLine, $sMonthLine, $sYearLine);
$ACTINIC::B2B->SetXML("DateInput", 1);
$VariableTable{$::VARPREFIX."DATEPROMPTCAPTION"} = $$pProduct{"DATE_PROMPT"};
$VariableTable{$::VARPREFIX."DATEPROMPTVALUE"} = $sDatePrompt; # add the date prompt (if any) to the var table
}
my $sInfoPrompt = $$pProduct{"OTHER_INFO_PROMPT"};
if (length $sInfoPrompt > 0)
{
$ACTINIC::B2B->SetXML("InfoInput", 1);
$VariableTable{$::VARPREFIX."INFOINPUTCAPTION"} = $sInfoPrompt;
$VariableTable{$::VARPREFIX."INFOINPUTVALUE"} = ActinicOrder::InfoHTMLGenerate($ProductRef, $ProductRef, $sDefaultInfo, $::FALSE, $pFailure->{"INFOINPUT"});
}
if (defined $$::g_pSetupBlob{'SUPPRESS_CART_WITH_CONFIRM'} &&
$$::g_pSetupBlob{'SUPPRESS_CART_WITH_CONFIRM'})
{
$ACTINIC::B2B->SetXML("ShoppingCart", "");  # don't display the cart contents
}
else
{
my $pCartObject;
@Response = $::Session->GetCartObject();
($Status, $Message, $pCartObject) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
my $pCartList = $pCartObject->GetCartList();
if ($#{$pCartList} >= 0)
{
@Response = ActinicOrder::GenerateShoppingCartLines($pCartList, $::FALSE, [], "ODTemplate.html");
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
}
else
{
$ACTINIC::B2B->SetXML("ShoppingCart", "");
}
}
@Response = ACTINIC::TemplateFile($sPath."ODTemplate.html", \%VariableTable);
my ($sHTML);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
@Response = BounceHelper($sHTML);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
my ($sDelimiter);
foreach $sDelimiter (@DeleteDelimiters)
{
$sHTML =~ s/$::DELPREFIX$sDelimiter(.*?)$::DELPREFIX$sDelimiter//gis;
}
foreach $sDelimiter (@KeepDelimiters)
{
$sHTML =~ s/$::DELPREFIX$sDelimiter//gis;
}
my ($sSelectName, $sDefaultOption);
while ( ($sSelectName, $sDefaultOption) = each %$pSelectTable)
{
$sHTML =~ s/(<\s*SELECT[^>]+?NAME\s*=\s*("|')?$sSelectName.+?)<OPTION\s+VALUE\s*=\s*("|')?$sDefaultOption("|')?\s*>/$1<OPTION SELECTED VALUE="$sDefaultOption">/is;
}
return ($::SUCCESS, "", $sHTML);
}
sub IsCustomerAllowedToBuy
{
my ($pProduct) = @_;
my $sMessage;
my $bAllowedToBuy = $::TRUE;
my ($bShowRetailPrices, $bShowCustomerPrices, $nAccountSchedule) = ACTINIC::DeterminePricesToShow();
if ('' ne $ACTINIC::B2B->Get('UserDigest'))
{
if (
(
($::FALSE == $bShowCustomerPrices) &&
($::TRUE == $bShowRetailPrices) &&
(0 ==  scalar(@{$pProduct->{'PRICES'}->{$ActinicOrder::RETAILID}}))
)
||
(
(
($::TRUE == $bShowCustomerPrices) &&
(0 == scalar(@{$pProduct->{'PRICES'}->{$nAccountSchedule}}))
)
&&
(
($::FALSE == $bShowRetailPrices) ||
(0 == scalar(@{$pProduct->{'PRICES'}->{$ActinicOrder::RETAILID}}))
)
)
)
{
$sMessage = ACTINIC::GetPhrase(-1, 351);
$bAllowedToBuy = $::FALSE;
}
}
else
{
if (0 == scalar(@{$pProduct->{'PRICES'}->{$ActinicOrder::RETAILID}}))
{
$sMessage = ACTINIC::GetPhrase(-1,333);# 'This product is only avalable to registered customers'
$bAllowedToBuy = $::FALSE;
}
}
return ($bAllowedToBuy, $sMessage);
}
sub FormatProductReference
{
if (!defined $_[0])
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'FormatProductReference'), 0, 0);
}
my ($sProdRef, $sFormat, $sLine, @Response, $Status, $Message);
$sProdRef = $_[0];
$sLine = "";
if ($$::g_pSetupBlob{"PROD_REF_COUNT"} > 0)
{
$sProdRef =~ s/^\d+\!//g;
$sLine = ACTINIC::GetPhrase(-1, 65, $sProdRef);
@Response = ACTINIC::EncodeText($sLine);
($Status, $sLine) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
}
return ($::SUCCESS, "", $sLine, 0);
}
sub Init
{
$::prog_name = "SHOPCART";
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
@Response = ACTINIC::ReadSSPSetupFile(ACTINIC::GetPath());
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
}
$ACTINIC::B2B->Set('UserDigest',ACTINIC::CAccFindUser());
ACTINIC::InitMonthMap();
if(!defined $::g_InputHash{"ACTION"})
{
if(defined $::g_InputHash{"ACTION_CONFIRM.x"})
{
$::g_InputHash{"ACTION"} = $::g_sConfirmButtonLabel;
}
elsif(defined $::g_InputHash{"ACTION_CANCEL.x"})
{
$::g_InputHash{"ACTION"} = $::g_sCancelButtonLabel;
}
elsif(defined $::g_InputHash{"ACTION_BUYNOW.x"})
{
$::g_InputHash{"ACTION"} = ACTINIC::GetPhrase(-1, 184);
}
elsif(defined $::g_InputHash{"ACTION_SEND.x"})
{
$::g_InputHash{"ACTION"} = $::g_sSendCouponLabel;
}
elsif (defined $$::g_pSetupBlob{'EDIT_IMG'} && $$::g_pSetupBlob{'EDIT_IMG'} ne '')
{
my $sKey;
foreach $sKey (keys(%::g_InputHash))
{
if ($sKey =~ /^ACTION_EDIT(\d+)\.x/)
{
$::g_InputHash{$1} = $::g_sEditButtonLabel;
}
elsif ($sKey =~ /^ACTION_REMOVE(\d+)\.x/)
{
$::g_InputHash{$1} = $::g_sRemoveButtonLabel;
}
}
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
$::g_sWebSiteUrl = $::Session->GetBaseUrl();
$::g_sContentUrl = $::g_sWebSiteUrl;
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
@Response = ACTINIC::ReadTaxSetupFile($sPath);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
ActinicOrder::ParseAdvancedTax();
return ($::SUCCESS, "");
}
sub ReturnToLastPage
{
my ($nDelay, $sMessage, $sTitle);
($nDelay, $sMessage, $sTitle) = @_;
if (!defined $sTitle)
{
$sTitle = "";
}
return (ACTINIC::ReturnToLastPage($nDelay, $sMessage, $sTitle,
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, %::g_InputHash));
}
sub GroomHTML
{
my ($sMessage, $sTitle);
($sMessage, $sTitle) = @_;
if (!defined $sTitle)
{
$sTitle = "";
}
return (ACTINIC::GroomHTML($sMessage, $sTitle,
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, %::g_InputHash));
}
sub PrintPage
{
my $sCartCookie = ActinicOrder::GenerateCartCookie();
return (
ACTINIC::UpdateDisplay($_[0], $::g_OriginalInputData,
$_[1], $_[2], '', $sCartCookie)
);
}
sub AddLink
{
my ($sURL, $sTarget, $sImage, $sAlt, $sText) = @_;
my ($sHTML);
$sHTML .= "<A HREF=\"";
$sHTML .= $sURL . "\"";
$sHTML .= " TARGET=\"" . $sTarget . "\">";
if (defined $sImage && $sImage ne '' && ACTINIC::CheckFileExists($sImage, ACTINIC::GetPath()))
{
$sHTML .= "<IMG SRC=\"" . $sImage ."\" ALT=\"" . $sAlt . "\" BORDER=0><BR>";
}
$sHTML .= "" . $sText . "</A><BR>";
return($::SUCCESS, "", $sHTML);
}
sub ShowCart
{
my ($Status, $Message, $sHTML);
my ($pCartObject, @Response);
@Response = $::Session->GetCartObject();
($Status, $Message, $pCartObject) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
exit;
}
my $pCartList = $pCartObject->GetCartList();
my @aFailureList;
my ($pOrderDetail, $sErrorMessage);
my $nIndex;
$nIndex	= 0;
foreach $pOrderDetail (@{$pCartList})
{
my ($nStatus, $sMessage, $pFailure) = ActinicOrder::ValidateOrderDetails($pOrderDetail, -2);
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
if (length $sErrorMessage > 0)
{
my $sHTML = sprintf($::ERROR_FORMAT, $sErrorMessage);
$ACTINIC::B2B->SetXML('CARTUPDATEERROR', $sHTML);
}
@Response = ActinicOrder::ShowCart(\@aFailureList);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($Message, ACTINIC::GetPath());
exit;
}
PrintPage($sHTML, $::Session->GetSessionID());
exit;
}
sub DisplayCartWithLinks
{
my ($sCartID, $sPageTitle, @EmptyArray, $sStartButton);
my ($Status, $Message, $sHTML, @Response);
($sCartID, $sPageTitle) = @_;
my $pCartObject;
@Response = $::Session->GetCartObject();
($Status, $Message, $pCartObject) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
my $pCartList = $pCartObject->GetCartList();
@Response = ActinicOrder::GenerateShoppingCartLines($pCartList, $::FALSE, [], "ODTemplate.html");
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sHTML .= $Response[2];
my ($sRefPage, $sPathArg, $sRefPageArg);
$sRefPage = $::Session->GetLastShopPage();
$sPathArg = ($::g_InputHash{SHOP} ? '&SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) : '');
@Response = ACTINIC::EncodeText($sRefPage, $::FALSE);
$sRefPageArg .= "&REFPAGE=" . $Response[1];
$sHTML .= "<BR>";
$sHTML .= "<TABLE BORDER=0 WIDTH=600><TR><TD WIDTH=\"33%\" ALIGN=\"LEFT\">";
my ($sLinkHTML, $sTarget);
($Status, $Message, $sLinkHTML) = AddLink($sRefPage, "_self", 	$$::g_pSetupBlob{'CONTINUE_SHOP'},
"Continue Shopping", "");
if ($Status != $::SUCCESS)
{
return (@Response);
}
$sHTML .= $sLinkHTML;
$sHTML .= "</TD><TD WIDTH=\"33%\" ALIGN=\"CENTER\">";
my $sCartURL = sprintf('%sca%6.6d%s', $$::g_pSetupBlob{'CGI_URL'}, $$::g_pSetupBlob{'CGI_ID'},
$$::g_pSetupBlob{'CGI_EXT'});
$sCartURL .= "?ACTION=SHOWCART" . $sPathArg . $sRefPageArg;
($Status, $Message, $sLinkHTML) = AddLink($sCartURL, "_self", 	$$::g_pSetupBlob{'EDIT_CART'},
"Show Cart", "");
if ($Status != $::SUCCESS)
{
return (@Response);
}
$sHTML .= $sLinkHTML;
$sHTML .= "</TD><TD WIDTH=\"33%\" ALIGN=\"RIGHT\">";
my ($sCheckoutUrl);
$sCheckoutUrl = sprintf('%sos%6.6d%s', $$::g_pSetupBlob{'CGI_URL'}, $$::g_pSetupBlob{'CGI_ID'},
$$::g_pSetupBlob{'CGI_EXT'});
$sCheckoutUrl .= "?";
$sStartButton = ACTINIC::GetPhrase(-1, 113);
@Response = ACTINIC::EncodeText($sStartButton, $::FALSE);
$sCheckoutUrl .= "ACTION=" . $Response[1];
$sCheckoutUrl .= $sPathArg;
if ($$::g_pSetupBlob{UNFRAMED_CHECKOUT})
{
$sTarget = "_parent";
@Response = ACTINIC::GetCatalogBasePageName(ACTINIC::GetPath());
if($Response[0] != $::SUCCESS)
{
$sCheckoutUrl .= $sRefPageArg;
}
else
{
my $sAbsBasePageURL = ($Response[2] =~ m#http.*://#) ? $Response[2] : $::g_sWebSiteUrl . $Response[2];
@Response = ACTINIC::EncodeText($sAbsBasePageURL, $::FALSE);
$sCheckoutUrl .= "&REFPAGE=" . $Response[1];
}
}
else
{
$sTarget = "_self";
$sCheckoutUrl .= $sRefPageArg;
}
($Status, $Message, $sLinkHTML) = AddLink($sCheckoutUrl, $sTarget, $$::g_pSetupBlob{'PROCEED_CHECKOUT'},
"Proceed to Checkout", "");
if ($Status != $::SUCCESS)
{
return (@Response);
}
$sHTML .= $sLinkHTML;
$sHTML .= "</TD></TR></TABLE>";
@Response = GroomHTML("<B>" .
$sHTML . "</B>",
$sPageTitle);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
return($::SUCCESS, "", $sHTML);
}
sub PrintSSLBouncePage
{
my $sHTML;
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
}
else
{
my $sCookie 		= ACTINIC::EncodeText2($ENV{'HTTP_COOKIE'}, $::TRUE);
my $sSessionID 	= ACTINIC::EncodeText2($::Session->GetSessionID(), $::TRUE);
my $sCartCookie 	= ACTINIC::EncodeText2(ActinicOrder::GenerateCartCookie(), $::TRUE);
my $sBusinessCookie 	= ACTINIC::CAccBusinessCookie();
my $sReferrer	= ACTINIC::GetReferrer();
if ((defined $::g_InputHash{REFPAGE}) &&
(!ACTINIC::IsStaticPage($sReferrer)))
{
my ($sBefore, $sAfter) = split(/\?/, $sReferrer);
my ($sNewRefPage) = "REFPAGE=" . ACTINIC::EncodeText2($::g_InputHash{REFPAGE}, $::FALSE);
if ($sAfter !~ /=/)
{
$sAfter = $sNewRefPage . $sAfter
}
elsif ($sAfter =~ /(^|\&)REFPAGE=.*?(\&|$)/)
{
$sAfter =~ s/(^|\&)REFPAGE=.*?(\&|$)/$1$sNewRefPage$2/;
}
else
{
$sAfter = $sNewRefPage . ($sAfter =~ /=/ ? "&" : "") . $sAfter;
}
$sReferrer = $sBefore . "?" . $sAfter;
}
my ($sURL, $sParams) = split /\?/, $::g_InputHash{'URL'};
my %EncodedInput = split(/[&=]/, $sParams);
my ($key, $value);
my $sHTMLParams;
while (($key, $value) = each %EncodedInput)
{
$value = ACTINIC::DecodeText($value, $ACTINIC::FORM_URL_ENCODED);
$value = ACTINIC::EncodeText2($value);
$sHTMLParams .= sprintf("<INPUT TYPE=HIDDEN NAME='%s' VALUE='%s'>", $key, $value);
}
$sHTML = "<HTML><HEAD>\n" .
"<SCRIPT LANGUAGE='JavaScript'>\n" .
"<!-- \n" .
"function onLoad() {document.Bounce.submit();}\n" .
"// -->\n" .
"</SCRIPT>\n" .
"</HEAD>\n" .
"<BODY OnLoad='onLoad();'>\n" .
"<FORM NAME='Bounce' METHOD=POST ACTION='$sURL'>\n" .
"<INPUT TYPE=HIDDEN NAME='ACTINIC_REFERRER' VALUE='$sReferrer'>\n" .
"<INPUT TYPE=HIDDEN NAME='COOKIE' VALUE='$sCookie'>\n" .
"<INPUT TYPE=HIDDEN NAME='CARTCOOKIE' VALUE='$sCartCookie'>\n" .
"<INPUT TYPE=HIDDEN NAME='SESSIONID' VALUE='$sSessionID'>\n" .
"<INPUT TYPE=HIDDEN NAME='DIGEST' VALUE='$sBusinessCookie'>\n" .
$sHTMLParams .
"</FORM>\n" .
"</HEAD></HTML>\n";
}
ACTINIC::PrintPage($sHTML, $::Session->GetSessionID());
}
sub BounceHelper
{
my $sHTML = shift @_;
my @Response;
if( !$ACTINIC::B2B->Get('UserDigest') )
{
@Response = ACTINIC::MakeLinksAbsolute($sHTML, $::g_sWebSiteUrl, $::g_sContentUrl);
}
else
{
my $sBaseFile = $ACTINIC::B2B->Get('BaseFile');
my $smPath = ($sBaseFile) ? $sBaseFile : $::g_sContentUrl;
my $sCgiUrl = $::g_sAccountScript;
$sCgiUrl   .= ($::g_InputHash{SHOP} ? '?SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) . '&': '?');
$sCgiUrl   .= 'PRODUCTPAGE=';
@Response = ACTINIC::MakeLinksAbsolute($sHTML, $sCgiUrl, $smPath);
}
return(@Response);
}
sub ParseDateStamp
{
my $sDate = shift @_;
my ($nYear, $nMonth, $sMonth, $nDay);
$sDate =~ /(\d+)\/(\d+)\/(\d+)/;
$nYear = $1;
$nMonth = $2 +1 - 1;
$sMonth = $::g_InverseMonthMap{$nMonth};
$nDay = $3 + 1 - 1;
return ($nYear, $nMonth, $nDay, $sMonth);
}