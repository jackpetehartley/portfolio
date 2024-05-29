#!/usr/local/bin/perl
package ActinicOrder;
use strict;
$::STARTSEQUENCE		= -1;
$::BILLCONTACTPHASE	= 0;
$::SHIPCONTACTPHASE	= 1;
$::SHIPCHARGEPHASE	= 2;
$::TAXCHARGEPHASE		= 3;
$::GENERALPHASE		= 4;
$::PAYMENTPHASE		= 5;
$::COMPLETEPHASE		= 6;
$::RECEIPTPHASE		= 7;
$::PRELIMINARYINFOPHASE	= 8;
$::PAYMENT_ON_ACCOUNT_LOWER = 964;
$::PAYMENT_ON_ACCOUNT_UPPER = 965;
$::eTaxAlways			= 0;
$::eTaxByInvoice		= 1;
$::eTaxByDelivery		= 2;
$ActinicOrder::ZERO		= 0;
$ActinicOrder::EXEMPT	= 1;
$ActinicOrder::TAX1		= 2;
$ActinicOrder::TAX2		= 3;
$ActinicOrder::BOTH		= 4;
$ActinicOrder::BOTH 		= $ActinicOrder::BOTH;
$ActinicOrder::PRORATA	= 5;
$ActinicOrder::CUSTOM	= 6;
$ActinicOrder::PERCENTOFFSET = 10000;
$ActinicOrder::TRUNCATION				= 0;
$ActinicOrder::SCIENTIFIC_DOWN		= 1;
$ActinicOrder::SCIENTIFIC_NORMAL		= 2;
$ActinicOrder::CEILING					= 3;
$ActinicOrder::BANKERS					= 4;
$ActinicOrder::ROUNDPERLINE	= 0;
$ActinicOrder::ROUNDPERITEM	= 1;
$ActinicOrder::ROUNDPERORDER	= 2;
$ActinicOrder::bTaxDataParsed	= $::FALSE;
$ActinicOrder::prog_name = 'ActinicOrder.pm';
$ActinicOrder::prog_name = $ActinicOrder::prog_name;
$ActinicOrder::prog_ver = '$Revision: 20369 $ ';
$ActinicOrder::prog_ver = substr($ActinicOrder::prog_ver, 11);
$ActinicOrder::prog_ver =~ s/ \$//;
$ActinicOrder::UNDEFINED_REGION = "UndefinedRegion";
$ActinicOrder::REGION_NOT_SUPPLIED = '---';
$ActinicOrder::sPriceTemplate = '';
$ActinicOrder::PRICING_MODEL_STANDARD  = 0;
$ActinicOrder::PRICING_MODEL_COMP      = 1;
$ActinicOrder::PRICING_MODEL_PROD_COMP = 2;
$ActinicOrder::VDSIMILARLINES = 1;
$ActinicOrder::RETAILID = 1;
$ActinicOrder::FROM_UNKNOWN	= 0;
$ActinicOrder::FROM_CART		= 1;
$ActinicOrder::FROM_CHECKOUT	= 2;
$ActinicOrder::s_nContext = $ActinicOrder::FROM_UNKNOWN;
$ActinicOrder::g_pDefaultTaxZone = undef;
$ActinicOrder::g_pCurrentTaxZone = undef;
sub CallShippingPlugIn
{
no strict 'refs';
if ($::s_Ship_bRun)
{
return
(
$::SUCCESS,
'',
\%::s_Ship_nShippingStatus,
\%::s_Ship_sShippingError,
$::s_Ship_bShipPhaseIsHidden,
$::s_Ship_sShippingDescription,
$::s_Ship_nShipCharges,
\%::s_Ship_ShippingVariables,
$::s_Ship_nHandlingCharges,
$::s_Ship_sHandlingDescription,
$::s_Ship_nShipOptions,
$::s_Ship_bTaxAppliesToShipping
);
}
my ($pCartList);
if (defined $_[0])
{
$pCartList = $_[0];
}
if (defined $_[1])
{
$::s_Ship_nSubTotal = $_[1];
}
$::s_Ship_bDisplayPrices = $$::g_pSetupBlob{PRICES_DISPLAYED};
%::s_Ship_PriceFormatBlob = ();
%::s_Ship_OpaqueDataTables = ();
@::s_Ship_sShipProducts = ();
@::s_Ship_nShipQuantities = ();
@::s_Ship_nShipPrices = ();
@::s_Ship_nShipSeparately = ();
@::s_Ship_sShipCategories = ();
@::s_Ship_nShipShipQuantities = ();
@::s_Ship_nExcludeFromShipping = ();
@::s_Ship_dShipSupplements = ();
@::s_Ship_dShipSupplementOnce = ();
@::s_Ship_dHandSupplements = ();
@::s_Ship_dHandSupplementOnce = ();
@::s_Ship_dShipAltWeights = ();
@::s_Ship_bProduct = ();
@::s_Ship_bSeparateLine = ();
@::s_Ship_bParentExcluded = ();
@::s_Ship_bUseAssociatedShip = ();
my (@Response) = GetAdvancedShippingScript(ACTINIC::GetPath());
if ($Response[0] != $::SUCCESS)
{
return
(
$Response[0],
$Response[1],
undef,
undef,
undef,
undef,
undef,
undef,
undef,
undef,
undef
);
}
my ($sScript) = $Response[2];
my ($Status, $Message);
if (!defined $pCartList)
{
@Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
$pCartList = $pCartObject->GetCartList();
}
@Response = ACTINIC::GetDigitalContent($pCartList, $::TRUE);
if ($Response[0] == $::FAILURE)
{
return (@Response);
}
my %hDDLinks = %{$Response[2]};
my ($pOrderDetail, $pProduct, $nComponentCount);
$::s_Ship_nTotalQuantity = 0;
$nComponentCount = 0;
foreach $pOrderDetail (@$pCartList)
{
my ($sSectionBlobName);
($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($$pOrderDetail{SID});
if ($Status == $::FAILURE)
{
return ($Status, $Message);
}
@Response = ACTINIC::GetProduct($$pOrderDetail{"PRODUCT_REFERENCE"}, $sSectionBlobName,
ACTINIC::GetPath());
($Status, $Message, $pProduct) = @Response;
if ($Status == $::NOTFOUND)
{
next;
}
if ($Status != $::SUCCESS)
{
return
(
$Status,
$Message,
undef,
undef,
undef,
undef,
undef,
undef,
undef,
undef,
undef
);
}
$::s_Ship_nTotalQuantity += $$pOrderDetail{"QUANTITY"};
my $nEffectiveQuantity = EffectiveCartQuantity($pOrderDetail,$pCartList,\&IdenticalCartLines,undef);
my $nPricingModel = $pProduct->{PRICING_MODEL};
my $sPrice;
if ($nPricingModel == $ActinicOrder::PRICING_MODEL_COMP)
{
$sPrice = 0;
}
else
{
$sPrice = ActinicOrder::CalculateSchPrice($pProduct,$nEffectiveQuantity,$ACTINIC::B2B->Get('UserDigest'));
}
push (@::s_Ship_sShipProducts, $$pOrderDetail{"PRODUCT_REFERENCE"});
push (@::s_Ship_nShipQuantities, $$pOrderDetail{"QUANTITY"});
push (@::s_Ship_nShipPrices, $sPrice);
push (@::s_Ship_nShipSeparately, $$pProduct{"SHIP_SEPARATELY"});
push (@::s_Ship_sShipCategories, $$pProduct{"SHIP_CATEGORY"});
push (@::s_Ship_nShipShipQuantities, $$pProduct{"SHIP_QUANTITY"});
push (@::s_Ship_nExcludeFromShipping, $$pProduct{"EXCLUDE_FROM_SHIP"});
push (@::s_Ship_dShipSupplements, $$pProduct{"SHIP_SUPPLEMENT"});
push (@::s_Ship_dShipSupplementOnce, $$pProduct{"SHIP_SUPPLEMENT_ONCE"});
push (@::s_Ship_dHandSupplements, $$pProduct{"HAND_SUPPLEMENT"});
push (@::s_Ship_dHandSupplementOnce, $$pProduct{"HAND_SUPPLEMENT_ONCE"});
push (@::s_Ship_dShipAltWeights, $$pProduct{"ALT_WEIGHT"});
push (@::s_Ship_bProduct, $::TRUE);
push (@::s_Ship_bSeparateLine, $::TRUE);
push (@::s_Ship_bParentExcluded, $::FALSE);
push (@::s_Ship_bUseAssociatedShip, $::TRUE);
$::s_Ship_OpaqueDataTables{$$pProduct{REFERENCE}} = $$pProduct{OPAQUE_SHIPPING_DATA};
if( $pProduct->{COMPONENTS} )
{
my %CurrentItem = %$pOrderDetail;
my $VariantList = GetCartVariantList(\%CurrentItem);
my (%Component, $pComp);
my $nIndex = 1;
foreach $pComp (@{$pProduct->{COMPONENTS}})
{
@Response = FindComponent($pComp,$VariantList);
($Status, %Component) = @Response;
if ($Status != $::SUCCESS)
{
return ($Status,$Component{text});
}
if( $Component{quantity} > 0 )
{
my $sRef= $Component{code} && $pComp->[4] == 1 ? $Component{code} : $CurrentItem{"PRODUCT_REFERENCE"} . "_" . $nIndex;
@Response = GetComponentPrice($Component{price},$nEffectiveQuantity,$Component{quantity}, undef, $sRef);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($nPricingModel == $ActinicOrder::PRICING_MODEL_STANDARD)
{
$sPrice = 0;
}
else
{
$sPrice = $Response[2];
}
$sRef= $Component{code} ? $Component{code} : $CurrentItem{"PRODUCT_REFERENCE"} . "_" . $nIndex;
push (@::s_Ship_sShipProducts, $sRef);
push (@::s_Ship_nShipQuantities, $$pOrderDetail{"QUANTITY"} * $Component{quantity});
push (@::s_Ship_nShipPrices, $sPrice);
push (@::s_Ship_nShipSeparately, $Component{"SHIP_SEPARATELY"});
push (@::s_Ship_sShipCategories, $Component{"SHIP_CATEGORY"});
push (@::s_Ship_nShipShipQuantities, $Component{"SHIP_QUANTITY"});
push (@::s_Ship_nExcludeFromShipping, $Component{"EXCLUDE_FROM_SHIP"});
push (@::s_Ship_dShipSupplements, $Component{"SHIP_SUPPLEMENT"});
push (@::s_Ship_dShipSupplementOnce, $Component{"SHIP_SUPPLEMENT_ONCE"});
push (@::s_Ship_dHandSupplements, $Component{"HAND_SUPPLEMENT"});
push (@::s_Ship_dHandSupplementOnce, $Component{"HAND_SUPPLEMENT_ONCE"});
push (@::s_Ship_dShipAltWeights, $Component{"ALT_WEIGHT"});
push (@::s_Ship_bProduct, $::FALSE);
push (@::s_Ship_bSeparateLine, $Component{'SeparateLine'});
push (@::s_Ship_bParentExcluded, $$pProduct{"EXCLUDE_FROM_SHIP"});
push (@::s_Ship_bUseAssociatedShip, $Component{'UseAssociatedShip'});
$::s_Ship_OpaqueDataTables{$sRef} = $Component{OPAQUE_SHIPPING_DATA};
$nComponentCount++;
}
$nIndex++;
}
}
}
if(defined $::g_InputHash{DELIVERPOSTALCODE})
{
$::g_ShipContact{'POSTALCODE'} = $::g_InputHash{DELIVERPOSTALCODE};
}
if(defined $::g_InputHash{DELIVERRESIDENTIAL})
{
$::g_LocationInfo{'DELIVERRESIDENTIAL'} = $::g_InputHash{DELIVERRESIDENTIAL};
}
$::s_Ship_sSSPOpaqueShipData = $::g_ShipInfo{'SSP'};
$::s_Ship_sOpaqueShipData = $::g_ShipInfo{'ADVANCED'};
$::s_Ship_sOpaqueHandleData = $::g_ShipInfo{HANDLING};
$::s_sDeliveryCountryCode = $::g_LocationInfo{DELIVERY_COUNTRY_CODE};
$::s_sDeliveryRegionCode = $::g_LocationInfo{DELIVERY_REGION_CODE};
$::s_sShip_bLocationTaxable = IsTaxApplicableForLocation('TAX_1') || IsTaxApplicableForLocation('TAX_2');
%::s_Ship_PriceFormatBlob = %{$::g_pCatalogBlob};
if (eval($sScript) != $::SUCCESS)
{
return
(
$::FAILURE,
ACTINIC::GetPhrase(-1, 160, $@),
undef,
undef,
undef,
undef,
undef,
undef,
undef,
undef,
undef
);
}
if ($@)
{
return($::FAILURE, ACTINIC::GetPhrase(-1, 160, $@));
}
$::g_ShipInfo{'ADVANCED'} = $::s_Ship_sOpaqueShipData;
$::g_ShipInfo{HANDLING} = $::s_Ship_sOpaqueHandleData;
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} = $::s_sDeliveryCountryCode;
$::g_LocationInfo{DELIVERY_REGION_CODE} = $::s_sDeliveryRegionCode;
$::g_ShipInfo{'SSP'} = $::s_Ship_sSSPOpaqueShipData;
$::s_Ship_bRun = $::TRUE;
return
(
$::SUCCESS,
'',
\%::s_Ship_nShippingStatus,
\%::s_Ship_sShippingError,
$::s_Ship_bShipPhaseIsHidden,
$::s_Ship_sShippingDescription,
$::s_Ship_nShipCharges,
\%::s_Ship_ShippingVariables,
$::s_Ship_nHandlingCharges,
$::s_Ship_sHandlingDescription,
$::s_Ship_nShipOptions,
$::s_Ship_bTaxAppliesToShipping
);
}
sub GetAdvancedShippingScript
{
if (defined $ActinicOrder::s_sShippingScript)# if it is already in memory,
{
return ($::SUCCESS, "", $ActinicOrder::s_sShippingScript);
}
if ($#_ < 0)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'GetAdvancedShippingScript'), 0, 0);
}
my ($sPath) = $_[0];
my ($sFilename) = $sPath . "ActinicShipping.fil";
my @Response = ACTINIC::ReadAndVerifyFile($sFilename);
if ($Response[0] == $::SUCCESS)
{
$ActinicOrder::s_sShippingScript = $Response[2];
}
return (@Response);
}
sub GenerateValidPayments
{
my ($parrMethods, $bValidateDelivery) = @_;
if (!defined $bValidateDelivery)
{
$bValidateDelivery = $::FALSE;
}
my @arrFullList = @{$$::g_pPaymentList{'ORDER'}};
my %Lookup = GetPaymentsForLocation($bValidateDelivery);
my $nMethodID;
foreach $nMethodID (@arrFullList)
{
if ($$::g_pPaymentList{$nMethodID}{ENABLED})
{
if ( $::g_pLocationList->{EXPECT_PAYMENT} &&
!$Lookup{$nMethodID})
{
next;
}
push (@$parrMethods, $nMethodID);
}
}
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if ( $sDigest )
{
my @Response = ActinicOrder::GetAccountDefaultPaymentMethod($sDigest);
if ($Response[0] != $::SUCCESS)
{
return(@Response);
}
if (!$Lookup{$Response[2]})
{
push (@$parrMethods, $Response[2]);
}
}
}
sub GetPaymentsForLocation
{
my $bValidateDelivery = shift @_;
if (!defined $bValidateDelivery)
{
$bValidateDelivery = $::TRUE;
}
my $nMethodID;
my (%Invoice, %Intersection) = ();
if (!$::g_pLocationList->{EXPECT_PAYMENT} )
{
foreach $nMethodID (@{$$::g_pPaymentList{'ORDER'}})
{
if ($$::g_pPaymentList{$nMethodID}{ENABLED})
{
$Intersection{$nMethodID} = 1
}
}
return(%Intersection);
}
my @arrInvoiceList = @{$::g_pLocationList->{$::g_LocationInfo{INVOICE_COUNTRY_CODE}}->{ALLOWED_PAYMENT}};
foreach $nMethodID (@arrInvoiceList)
{
if ($$::g_pPaymentList{$nMethodID}{ENABLED})
{
$Invoice{$nMethodID} = 1;
}
}
if ($::g_BillContact{'SEPARATE'} && $bValidateDelivery &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne '')
{
my @arrDeliveryList = @{$::g_pLocationList->{$::g_LocationInfo{DELIVERY_COUNTRY_CODE}}->{ALLOWED_PAYMENT}};
foreach $nMethodID (@arrDeliveryList)
{
if ( $Invoice{$nMethodID} &&
$$::g_pPaymentList{$nMethodID}{ENABLED})
{
$Intersection{$nMethodID} = 1;
}
}
return(%Intersection);
}
return(%Invoice);
}
sub GetDefaultPayment
{
my ($bUseRestored) = shift @_;
if (!defined $bUseRestored)
{
$bUseRestored = $::TRUE;
}
if (0 < length $::g_PaymentInfo{METHOD} &&
$bUseRestored)
{
return($::g_PaymentInfo{METHOD});
}
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if ( $sDigest )
{
my @Response = ActinicOrder::GetAccountDefaultPaymentMethod($sDigest);
if ($Response[0] == $::SUCCESS)
{
return($Response[2]);
}
}
my $nMethodID;
foreach $nMethodID (@{$$::g_pPaymentList{'ORDER'}})
{
if ($$::g_pPaymentList{$nMethodID}{DEFAULT})
{
return($nMethodID);
}
}
return($::PAYMENT_UNDEFINED);
}
sub GeneratePaymentSelection
{
my $sHTML = ACTINIC::GetPhrase(-1, 1951);
my @arrMethods;
GenerateValidPayments(\@arrMethods, $::FALSE);
my $nPaymentCount = @arrMethods;
if (0 == $nPaymentCount)
{
my $nDefault = GetDefaultPayment($::FALSE);
if ($nDefault == $::PAYMENT_UNDEFINED)
{
return($::FAILURE, ACTINIC::GetPhrase(-1, 1955));
}
else
{
push (@arrMethods, $nDefault);
$nPaymentCount++;
}
}
if (1 == $nPaymentCount)
{
$sHTML = sprintf("<INPUT TYPE='HIDDEN' NAME='PAYMENTMETHOD' VALUE='%s'>%s",
$arrMethods[0], $$::g_pPaymentList{$arrMethods[0]}{'PROMPT'});
}
else
{
my $nDefault = GetDefaultPayment(@arrMethods);
my $sSelectLine = ACTINIC::GetPhrase(-1, 1952);
my $nMethodID;
foreach $nMethodID (@arrMethods)
{
if ($nMethodID == $::PAYMENT_PAYPAL_PRO ||
$nMethodID == $::PAYMENT_PAYPAL_EC)
{
next;
}
if ($nMethodID == $nDefault)
{
$sHTML .= sprintf(ACTINIC::GetPhrase(-1, 1954), $nMethodID, $$::g_pPaymentList{$nMethodID}{'PROMPT'});
}
else
{
$sHTML .= sprintf($sSelectLine, $nMethodID, $$::g_pPaymentList{$nMethodID}{'PROMPT'});
}
}
$sHTML .= ACTINIC::GetPhrase(-1, 1953);
}
return ($::SUCCESS, $sHTML);
}
sub PaymentStringToEnum
{
my ($sPayment) = @_;
return($sPayment);
}
sub EnumToPaymentString
{
my ($ePayment) = @_;
return($$::g_pPaymentList{$ePayment}{'PROMPT'});
}
sub IsAccountSpecificPaymentMethod
{
my ($ePayment) = @_;
return($$::g_pPaymentList{$ePayment}{'CUSTOMER_USE_ONLY'});
}
sub IsCreditCardAvailable
{
if (GetDefaultPayment($::FALSE) == $::PAYMENT_CREDIT_CARD)
{
return($::TRUE);
}
my (@arrMethods, $nMethodID);
GenerateValidPayments(\@arrMethods);
foreach $nMethodID (@arrMethods)
{
if ($nMethodID == $::PAYMENT_CREDIT_CARD)
{
return($::TRUE);
}
}
return($::FALSE);
}
sub CountUnregisteredCustomerPaymentOptions
{
my $nPaymentOptions = 0;
my $nMethodID;
foreach $nMethodID (@{$$::g_pPaymentList{'ORDER'}})
{
if ($$::g_pPaymentList{$nMethodID}{ENABLED})
{
$nPaymentOptions++;
}
}
return ($nPaymentOptions);
}
sub GetAccountDefaultPaymentMethod
{
my ($sDigest) = @_;
my ($Status, $Message, $pBuyer) =
ACTINIC::GetBuyer($sDigest, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return ($Status, $Message);
}
my $pAccount;
($Status, $Message, $pAccount) = ACTINIC::GetCustomerAccount($$pBuyer{AccountID}, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return ($Status, $Message);
}
return($::SUCCESS, '', $pAccount->{DefaultPaymentMethod});
}
sub ParseDelimiterStatus
{
if ($#_ != 0)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 12, 'ParseDelimiterStatus'), ACTINIC::GetPath());
}
my ($nPhase) = @_;
undef @ACTINIC::s_DeleteRegions;
undef @ACTINIC::s_KeepRegions;
my ($sPrefix);
if ($nPhase == $::BILLCONTACTPHASE)
{
$sPrefix = 'INVOICE';
}
elsif ($nPhase == $::SHIPCONTACTPHASE)
{
$sPrefix = 'DELIVER';
}
elsif ($nPhase == $::SHIPCHARGEPHASE)
{
$sPrefix = 'SHIP';
}
elsif ($nPhase == $::TAXCHARGEPHASE)
{
$sPrefix = 'TAX';
}
elsif ($nPhase == $::GENERALPHASE)
{
$sPrefix = 'GENERAL';
}
elsif ($nPhase == $::PAYMENTPHASE)
{
$sPrefix = 'PAYMENT';
}
elsif ($nPhase == $::COMPLETEPHASE)
{
$sPrefix = '';
}
elsif ($nPhase == $::RECEIPTPHASE)
{
$sPrefix = '';
}
elsif ($nPhase == $::PRELIMINARYINFOPHASE)
{
$sPrefix = '';
}
my ($pPromptList) = $::g_PhraseIndex{$nPhase};
my $nPhraseID;
my ($sDelimiter);
foreach $nPhraseID (@$pPromptList)
{
my ($pBlob) = $$::g_pPromptList{"$nPhase,$nPhraseID"};
if (!defined $pBlob)
{
next;
}
$sDelimiter = sprintf('%sPROMPT%3.3d',
$sPrefix, $nPhraseID);
if ($nPhase == $::TAXCHARGEPHASE)
{
if ($nPhraseID == 0)
{
if(!defined $$::g_pTaxSetupBlob{TAX_1} ||
!$$::g_pTaxSetupBlob{TAX_1}{ALLOW_EXEMPT})
{
$$pBlob{STATUS} = $::HIDDEN;
}
else
{
$$pBlob{STATUS} = $::OPTIONAL;
}
}
elsif ($nPhraseID == 1)
{
if(!defined $$::g_pTaxSetupBlob{TAX_2} ||
!$$::g_pTaxSetupBlob{TAX_2}{ALLOW_EXEMPT})
{
$$pBlob{STATUS} = $::HIDDEN;
}
else
{
$$pBlob{STATUS} = $::OPTIONAL;
}
}
}
elsif ($nPhase == $::SHIPCHARGEPHASE)
{
if ($nPhraseID == 0 &&
( !$$::g_pSetupBlob{MAKE_SHIPPING_CHARGE} ||
!$$::g_pSetupBlob{PRICES_DISPLAYED}))
{
$$pBlob{STATUS} = $::HIDDEN;
}
}
elsif ($nPhase == $::PAYMENTPHASE)
{
if (!IsCreditCardAvailable() ||
$$::g_pSetupBlob{USE_SHARED_SSL} ||
$$::g_pSetupBlob{USE_DH} )
{
if ($nPhraseID > 0 &&
$nPhraseID < 6 ||
$nPhraseID == 8)
{
$$pBlob{STATUS} = $::HIDDEN;
}
}
if ($nPhraseID == 0)
{
my $nPaymentOptions = CountUnregisteredCustomerPaymentOptions();
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if($sDigest ne '')
{
my ($nStatus, $sMessage, $nCustomerPaymentOption) = GetAccountDefaultPaymentMethod($sDigest);
if($nStatus == $::SUCCESS &&
ActinicOrder::IsAccountSpecificPaymentMethod($nCustomerPaymentOption))
{
$nPaymentOptions++;
}
}
if ($nPaymentOptions < 1)
{
$$pBlob{STATUS} = $::HIDDEN;
}
}
}
if ($$pBlob{STATUS} == $::HIDDEN)
{
push (@ACTINIC::s_DeleteRegions, $sDelimiter);
}
else
{
push (@ACTINIC::s_KeepRegions, $sDelimiter);
}
}
return (\@ACTINIC::s_DeleteRegions, \@ACTINIC::s_KeepRegions);
}
sub IsPhaseHidden
{
if ($#_ != 0)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 12, 'ParseDelimiterStatus'), ACTINIC::GetPath());
}
my ($nPhase) = @_;
my ($bPlugInHidden);
if ($nPhase == $::SHIPCHARGEPHASE)
{
my @Response = CallShippingPlugIn();
if ($Response[0] == $::SUCCESS &&
${$Response[2]}{IsFinalPhaseHidden} == $::SUCCESS)
{
if ($Response[10] == 0)
{
return($::TRUE);
}
if (($Response[10] == 1) &&
ACTINIC::IsPromptHidden(2,1))
{
return($::TRUE);
}
return($::FALSE);
}
}
elsif ($nPhase == $::PRELIMINARYINFOPHASE)
{
return (!$$::g_pLocationList{EXPECT_DELIVERY} && !$$::g_pLocationList{EXPECT_INVOICE})
}
elsif ($nPhase == $::TAXCHARGEPHASE)
{
my $bTax1Hidden = !TaxNeedsCalculating('TAX_1') || !IsTaxExemptionAllowed('TAX_1');
my $bTax2Hidden = !TaxNeedsCalculating('TAX_2') || !IsTaxExemptionAllowed('TAX_2');
return($bTax1Hidden && $bTax2Hidden);
}
my ($pPromptList) = $::g_PhraseIndex{$nPhase};
my $nPhraseID;
foreach $nPhraseID (@$pPromptList)
{
my ($pBlob) = $$::g_pPromptList{"$nPhase,$nPhraseID"};
if (!defined $pBlob)
{
next;
}
if ($nPhase == $::PAYMENTPHASE)
{
if (!IsCreditCardAvailable() ||
$$::g_pSetupBlob{USE_SHARED_SSL} ||
$$::g_pSetupBlob{USE_DH} )
{
if ($nPhraseID > 0 &&
$nPhraseID < 6 ||
$nPhraseID == 8)
{
$$pBlob{STATUS} = $::HIDDEN;
}
}
if ($nPhraseID == 0)
{
my $nPaymentOptions = CountUnregisteredCustomerPaymentOptions();
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if($sDigest ne '')
{
my ($nStatus, $sMessage, $nCustomerPaymentOption) = GetAccountDefaultPaymentMethod($sDigest);
if($nStatus == $::SUCCESS &&
ActinicOrder::IsAccountSpecificPaymentMethod($nCustomerPaymentOption))
{
$nPaymentOptions++;
}
}
if ($nPaymentOptions < 1)
{
$$pBlob{STATUS} = $::HIDDEN;
}
}
}
if ($$pBlob{'STATUS'} != $::HIDDEN)
{
return ($::FALSE);
}
}
return ($::TRUE);
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
sub ValidatePreliminaryInfo
{
if ($#_ != 0)
{
return(ACTINIC::GetPhrase(-1, 12, 'ValidatePreliminaryInfo'));
}
if($$::g_pLocationList{EXPECT_NONE})
{
return('');
}
my ($bActuallyValidate) = @_;
if(defined $::g_InputHash{'LocationInvoiceCountry'} ||
defined $::g_InputHash{'LocationDeliveryCountry'})
{
$::g_LocationInfo{SEPARATESHIP} = $::g_InputHash{'SEPARATESHIP'};
}
my $bSeparateShip = $::g_LocationInfo{SEPARATESHIP} ne '';
$::g_BillContact{'SEPARATE'} = $bSeparateShip;
my $sOldInvoiceCountry = $::g_LocationInfo{INVOICE_COUNTRY_CODE};
my $sOldDeliveryCountry = $::g_LocationInfo{DELIVERY_COUNTRY_CODE};
if(defined $::g_InputHash{'LocationInvoiceCountry'})
{
$::g_LocationInfo{INVOICE_COUNTRY_CODE} = $::g_InputHash{'LocationInvoiceCountry'};
$::g_LocationInfo{INVOICE_REGION_CODE} = $::g_InputHash{'LocationInvoiceRegion'};
}
if(defined $::g_InputHash{'LocationDeliveryCountry'})
{
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} = $::g_InputHash{'LocationDeliveryCountry'};
$::g_LocationInfo{DELIVERY_REGION_CODE} = $::g_InputHash{'LocationDeliveryRegion'};
}
if(defined $::g_InputHash{'LocationInvoiceCountry'} ||
defined $::g_InputHash{'LocationDeliveryCountry'})
{
$::g_LocationInfo{DELIVERRESIDENTIAL} = $::g_InputHash{'DELIVERRESIDENTIAL'};
}
if(defined $::g_InputHash{'DELIVERPOSTALCODE'})
{
$::g_LocationInfo{DELIVERPOSTALCODE} = $::g_InputHash{'DELIVERPOSTALCODE'};
}
if(defined $::g_InputHash{'INVOICERESIDENTIAL'})
{
$::g_LocationInfo{INVOICERESIDENTIAL} = $::g_InputHash{'INVOICERESIDENTIAL'};
}
if(defined $::g_InputHash{'INVOICEPOSTALCODE'})
{
$::g_LocationInfo{INVOICEPOSTALCODE} = $::g_InputHash{'INVOICEPOSTALCODE'};
}
if ($$::g_pLocationList{EXPECT_BOTH})
{
if ($::g_LocationInfo{INVOICE_COUNTRY_CODE} &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} eq '')
{
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} = $::g_LocationInfo{INVOICE_COUNTRY_CODE};
}
if ($::g_LocationInfo{INVOICE_COUNTRY_CODE} eq
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} &&
$::g_LocationInfo{INVOICE_REGION_CODE} ne $ActinicOrder::UNDEFINED_REGION &&
$::g_LocationInfo{DELIVERY_REGION_CODE} eq $ActinicOrder::UNDEFINED_REGION)
{
$::g_LocationInfo{DELIVERY_REGION_CODE} = $::g_LocationInfo{INVOICE_REGION_CODE};
}
if(!$bSeparateShip)
{
if(defined $$::g_pLocationList{DELIVERPOSTALCODE} && $$::g_pLocationList{DELIVERPOSTALCODE} ne '' &&
$$::g_pLocationList{DELIVERPOSTALCODE} ne '' &&
!defined $$::g_pLocationList{INVOICEPOSTALCODE})
{
$::g_LocationInfo{INVOICEPOSTALCODE} = $::g_LocationInfo{DELIVERPOSTALCODE};
}
if((!defined $$::g_pLocationList{INVOICEADDRESS4} || $$::g_pLocationList{INVOICEADDRESS4}) &&
defined $$::g_pLocationList{DELIVERADDRESS4} && $$::g_pLocationList{DELIVERADDRESS4})
{
$::g_LocationInfo{INVOICE_REGION_CODE} = $::g_LocationInfo{DELIVERY_REGION_CODE};
}
}
}
if(!$bSeparateShip)
{
if($$::g_pLocationList{EXPECT_DELIVERY} &&
!$$::g_pLocationList{EXPECT_INVOICE})
{
$::g_LocationInfo{INVOICE_COUNTRY_CODE} = $::g_LocationInfo{DELIVERY_COUNTRY_CODE};
$::g_LocationInfo{INVOICE_REGION_CODE} = $::g_LocationInfo{DELIVERY_REGION_CODE};
$::g_LocationInfo{INVOICEPOSTALCODE} = $::g_LocationInfo{DELIVERPOSTALCODE};
$::g_LocationInfo{INVOICERESIDENTIAL} = $::g_LocationInfo{DELIVERRESIDENTIAL};
}
elsif(!$$::g_pLocationList{EXPECT_DELIVERY} &&
$$::g_pLocationList{EXPECT_INVOICE})
{
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} = $::g_LocationInfo{INVOICE_COUNTRY_CODE};
$::g_LocationInfo{DELIVERY_REGION_CODE} = $::g_LocationInfo{INVOICE_REGION_CODE};
$::g_LocationInfo{DELIVERPOSTALCODE} = $::g_LocationInfo{INVOICEPOSTALCODE};
$::g_LocationInfo{DELIVERRESIDENTIAL} = $::g_LocationInfo{INVOICERESIDENTIAL};
}
}
else
{
if($$::g_pLocationList{EXPECT_DELIVERY} &&
!$$::g_pLocationList{EXPECT_INVOICE})
{
$::g_LocationInfo{INVOICE_COUNTRY_CODE} = '';
$::g_LocationInfo{INVOICE_REGION_CODE} = '';
}
elsif(!$$::g_pLocationList{EXPECT_DELIVERY} &&
$$::g_pLocationList{EXPECT_INVOICE})
{
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} = '';
$::g_LocationInfo{DELIVERY_REGION_CODE} = '';
}
}
if ($sOldInvoiceCountry ne $::g_LocationInfo{INVOICE_COUNTRY_CODE})
{
if ($$::g_pLocationList{EXPECT_INVOICE})
{
if($::g_LocationInfo{INVOICE_COUNTRY_CODE} &&
$::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
$::g_BillContact{'COUNTRY'} = ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_COUNTRY_CODE});
}
}
if (!$$::g_pLocationList{EXPECT_DELIVERY} &&
$::g_ShipContact{COUNTRY} eq ACTINIC::GetCountryName($sOldInvoiceCountry))
{
if($::g_LocationInfo{INVOICE_COUNTRY_CODE} &&
$::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
$::g_ShipContact{'COUNTRY'} = ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_COUNTRY_CODE});
}
}
}
if ($sOldDeliveryCountry ne $::g_LocationInfo{DELIVERY_COUNTRY_CODE})
{
if ($$::g_pLocationList{EXPECT_DELIVERY})
{
if($::g_LocationInfo{DELIVERY_COUNTRY_CODE} &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
$::g_ShipContact{COUNTRY} = ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_COUNTRY_CODE});
}
}
if (!$$::g_pLocationList{EXPECT_INVOICE} &&
!$bSeparateShip &&
$::g_BillContact{COUNTRY} eq ACTINIC::GetCountryName($sOldDeliveryCountry))
{
if($::g_LocationInfo{DELIVERY_COUNTRY_CODE} &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
$::g_BillContact{'COUNTRY'} = ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_COUNTRY_CODE});
}
}
}
if ($$::g_pLocationList{EXPECT_DELIVERY} &&
$$::g_pLocationList{EXPECT_INVOICE})
{
if ($::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $::g_LocationInfo{DELIVERY_COUNTRY_CODE} ||
$::g_LocationInfo{INVOICE_REGION_CODE} ne $::g_LocationInfo{DELIVERY_REGION_CODE})
{
}
}
if (($::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne  $::g_LocationInfo{INVOICE_COUNTRY_CODE}) &&
($::g_LocationInfo{INVOICE_COUNTRY_CODE} eq $ActinicOrder::REGION_NOT_SUPPLIED) &&
!$bSeparateShip)
{
$::g_LocationInfo{INVOICE_COUNTRY_CODE} = $::g_LocationInfo{DELIVERY_COUNTRY_CODE};
}
my ($sError);
if (!$bActuallyValidate)
{
return ($sError);
}
if ($$::g_pLocationList{EXPECT_BOTH})
{
if (($::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne  $::g_LocationInfo{INVOICE_COUNTRY_CODE}) &&
($::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED) &&
!$bSeparateShip)
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(-1, 171) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
" - ". ACTINIC::GetPhrase(-1, 2068) . "<BR>\n";
}
elsif ($::g_LocationInfo{DELIVERY_REGION_CODE} ne  $::g_LocationInfo{INVOICE_REGION_CODE} &&
(exists $$::g_pLocationList{INVOICEADDRESS4} && $$::g_pLocationList{INVOICEADDRESS4} &&
exists $$::g_pLocationList{DELIVERADDRESS4} && $$::g_pLocationList{DELIVERADDRESS4}) &&
!$bSeparateShip)
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(-1, 171) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
" - ". ACTINIC::GetPhrase(-1, 2069) . "<BR>\n";
}
elsif ($::g_LocationInfo{DELIVERY_COUNTRY_CODE} eq  $::g_LocationInfo{INVOICE_COUNTRY_CODE} &&
$::g_LocationInfo{INVOICE_COUNTRY_CODE} eq $ActinicOrder::REGION_NOT_SUPPLIED)
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(-1, 171) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
" - ". ACTINIC::GetPhrase(-1, 2273) . "<BR>\n";
}
}
if ($$::g_pLocationList{EXPECT_INVOICE})
{
if ($::g_LocationInfo{INVOICE_COUNTRY_CODE} eq '')
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(-1, 191) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
" - ". ACTINIC::GetPhrase(-1, 195) . "<BR>\n";
}
if ($::g_LocationInfo{INVOICE_COUNTRY_CODE} ne '' &&
$::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED && # not the 'None of the above' is selected
$::g_LocationInfo{INVOICE_REGION_CODE} ne $ActinicOrder::UNDEFINED_REGION &&
$::g_LocationInfo{INVOICE_REGION_CODE} !~ /^$::g_LocationInfo{INVOICE_COUNTRY_CODE}\./)
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor)  . ACTINIC::GetPhrase(-1, 191) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
" - ". ACTINIC::GetPhrase(-1, 196) . "<BR>\n";
}
}
if ($$::g_pLocationList{EXPECT_DELIVERY})
{
if ($::g_LocationInfo{DELIVERY_COUNTRY_CODE} eq '')
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(-1, 171) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
" - ". ACTINIC::GetPhrase(-1, 195) . "<BR>\n";
}
if ($::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne '' &&
$::g_LocationInfo{DELIVERY_REGION_CODE} ne $ActinicOrder::UNDEFINED_REGION &&
$::g_LocationInfo{DELIVERY_REGION_CODE} !~ /^$::g_LocationInfo{DELIVERY_COUNTRY_CODE}\./)
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(-1, 171) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
" - ". ACTINIC::GetPhrase(-1, 196) . "<BR>\n";
}
}
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if($sDigest ne '')
{
my ($Status, $sMessage, $pBuyer, $pAccount) = ACTINIC::GetBuyerAndAccount($sDigest, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
$sError .= $sMessage;
}
my ($pAddress, $plistValidAddresses, $plistValidInvoiceAddresses, $plistValidDeliveryAddresses);
($Status, $sMessage, $plistValidInvoiceAddresses, $plistValidDeliveryAddresses) =
ACTINIC::GetCustomerAddressLists($pBuyer, $pAccount);
if ($Status != $::SUCCESS)
{
$sError .= $sMessage;
}
my $sRegion;
if($#$plistValidInvoiceAddresses == -1 &&
($pAccount->{InvoiceAddressRule} == 1 || $pBuyer->{InvoiceAddressRule} != 2))
{
if($::g_LocationInfo{INVOICE_REGION_CODE} eq $ActinicOrder::UNDEFINED_REGION)
{
$sRegion = ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_COUNTRY_CODE});
}
else
{
$sRegion = ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_REGION_CODE});
}
$sError .= ACTINIC::GetPhrase(-1, 1949, $sRegion) . "<br>";
}
if($#$plistValidDeliveryAddresses == -1 &&
($pBuyer->{DeliveryAddressRule} != 2))
{
if($::g_LocationInfo{DELIVERY_REGION_CODE} eq $ActinicOrder::UNDEFINED_REGION)
{
$sRegion = ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_COUNTRY_CODE});
}
else
{
$sRegion = ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_REGION_CODE});
}
$sError .= ACTINIC::GetPhrase(-1, 1950, $sRegion) . "<br>";
}
if($sError eq '')
{
my $plistValidTaxableAddresses;
if ($$::g_pTaxSetupBlob{TAX_BY} != $::eTaxByDelivery)
{
$plistValidTaxableAddresses = $plistValidInvoiceAddresses;
}
else
{
$plistValidTaxableAddresses = $plistValidDeliveryAddresses;
}
SetCustomerTaxExemption($plistValidTaxableAddresses);
}
ACTINIC::CloseCustomerAddressIndex(); # The customer index is left open for multiple access, so clean it up here
}
if(exists $$::g_pLocationList{INVOICEPOSTALCODE} &&
$$::g_pLocationList{INVOICEPOSTALCODE} &&
$::g_LocationInfo{INVOICEPOSTALCODE} eq '')
{
$sError .= ACTINIC::GetRequiredMessage(0, 8);
}
if(exists $$::g_pLocationList{DELIVERPOSTALCODE} &&
$$::g_pLocationList{DELIVERPOSTALCODE} &&
$::g_LocationInfo{DELIVERPOSTALCODE} eq '')
{
$sError .= ACTINIC::GetRequiredMessage(1, 8);
}
if (!$sError)
{
if ($$::g_pSetupBlob{'MAKE_SHIPPING_CHARGE'})
{
my ($nStatus, $sMessage, $pCartObject) = $::Session->GetCartObject();
if($nStatus == $::SUCCESS)
{
my @Response = $pCartObject->SummarizeOrder($::FALSE);
if ($Response[0] != $::SUCCESS)
{
$sMessage = $Response[1];
}
else
{
@Response = $pCartObject->GetShippingPluginResponse();
if (${$Response[2]}{ValidatePreliminaryInput} != $::SUCCESS)
{
$sMessage = ${$Response[3]}{ValidatePreliminaryInput};
}
elsif (${$Response[2]}{ValidateFinalInput} != $::SUCCESS)
{
$sMessage = ${$Response[3]}{ValidateFinalInput};
}
}
}
if($sMessage ne '')
{
$sError .= ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . ACTINIC::GetPhrase(-1, 171) .
ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970) .
" - " . $sMessage . "<BR>\n";
}
}
}
if ($sError ne "")
{
$sError = ACTINIC::GetPhrase(-1, 1974) . ACTINIC::GetPhrase(-1, 1971, $::g_sRequiredColor) . $sError . ACTINIC::GetPhrase(-1, 1975) . ACTINIC::GetPhrase(-1, 1970);
}
return ($sError);
}
sub SetCustomerTaxExemption
{
my ($plistValidTaxableAddresses) = @_;
if($#$plistValidTaxableAddresses == -1)
{
return;
}
my (%hTax1ID, %hTax2ID, %hTax1Exempt, %hTax2Exempt, %hTax1ExemptionData, %hTax2ExemptionData);
my $pAddress;
foreach $pAddress (@$plistValidTaxableAddresses)
{
$hTax1ID{$pAddress->{Tax1ID}} = 0;
$hTax1Exempt{$pAddress->{ExemptTax1}} = 0;
$hTax1ExemptionData{$pAddress->{Tax1ExemptData}} = 0;
$hTax2ID{$pAddress->{Tax2ID}} = 0;
$hTax2Exempt{$pAddress->{ExemptTax2}} = 0;
$hTax2ExemptionData{$pAddress->{Tax2ExemptData}} = 0;
}
my($nTaxID, $bTaxExempt, $sTaxExemptionData);
$pAddress = $plistValidTaxableAddresses->[0];
if(keys %hTax1ID == 1 &&
keys %hTax1Exempt == 1 &&
keys %hTax1ExemptionData == 1 &&
$pAddress->{Tax1ID} != -1)
{
$::g_TaxInfo{'EXEMPT1'} = $pAddress->{'ExemptTax1'} ? 1 : 0;
$::g_TaxInfo{'EXEMPT1DATA'} = $pAddress->{'Tax1ExemptData'};
}
else
{
$::g_TaxInfo{'EXEMPT1'} = 0;
$::g_TaxInfo{'EXEMPT1DATA'} = '';
}
if(keys %hTax2ID == 1 &&
keys %hTax2Exempt == 1 &&
keys %hTax2ExemptionData == 1 &&
$pAddress->{Tax2ID} != -1)
{
$::g_TaxInfo{'EXEMPT2'} = $pAddress->{'ExemptTax2'} ? 1 : 0;
$::g_TaxInfo{'EXEMPT2DATA'} = $pAddress->{'Tax2ExemptData'};
}
else
{
$::g_TaxInfo{'EXEMPT2'} = 0;
$::g_TaxInfo{'EXEMPT2DATA'} = '';
}
}
sub ValidateTax
{
if ($#_ < 0)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 12, 'ValidateTax'), ACTINIC::GetPath());
}
my ($bActuallyValidate) = $_[0];
my ($bCheckout) = $::TRUE;
if ($#_ == 1)
{
$bCheckout = $_[1];
}
my @Response = ParseAdvancedTax();
if ($Response[0] != $::SUCCESS)
{
return($Response[1]);
}
my $bTaxAndShipEarly = $$::g_pSetupBlob{'TAX_AND_SHIP_EARLY'};
my $bNoTaxesEnabled = !(TaxNeedsCalculating('TAX_1') || TaxNeedsCalculating('TAX_2'));
if ($bNoTaxesEnabled ||
$bCheckout)
{
$::g_TaxInfo{'DONE'} = $::TRUE;
}
if (IsPhaseDone($::TAXCHARGEPHASE) ||
!$bCheckout ||
$bNoTaxesEnabled)
{
return('');
}
if(!$::g_InputHash{ADDRESSSELECT} )
{
if (IsTaxPhaseApplicable())
{
$::g_TaxInfo{'EXEMPT1'} 	= ($::g_InputHash{'TAXEXEMPT1'} eq "" ? $::FALSE : $::TRUE);
$::g_TaxInfo{'EXEMPT2'} 	= ($::g_InputHash{'TAXEXEMPT2'} eq "" ? $::FALSE : $::TRUE);
if (defined $::g_InputHash{'TAXEXEMPT1DATA'})
{
$::g_TaxInfo{'EXEMPT1DATA'} 	= $::g_InputHash{'TAXEXEMPT1DATA'};
}
else
{
$::g_TaxInfo{'EXEMPT1DATA'} 	= "";
}
if(defined $::g_InputHash{'TAXEXEMPT2DATA'})
{
$::g_TaxInfo{'EXEMPT2DATA'} 	= $::g_InputHash{'TAXEXEMPT2DATA'};
}
else
{
$::g_TaxInfo{'EXEMPT2DATA'} 	= "";
}
}
}
$::g_TaxInfo{'USERDEFINED'} = $::g_InputHash{'TAXUSERDEFINED'};
ACTINIC::TrimHashEntries(\%::g_TaxInfo);
my ($sError, $nTax);
if (!$bActuallyValidate)
{
return ($sError);
}
foreach $nTax (1 .. 2)
{
$sError .= CheckTaxExemption($nTax);
}
if (ACTINIC::IsPromptRequired(3, 2) &&
$::g_TaxInfo{'USERDEFINED'} eq "")
{
$sError .= ACTINIC::GetRequiredMessage(3, 2);
}
if ($sError ne "")
{
$sError = "<B>" . ACTINIC::GetPhrase(-1, 150) . "</B>" . ACTINIC::GetPhrase(-1, 1961, $sError);
}
return ($sError);
}
sub IsTaxInfoChanged
{
my $sTaxDump = (join "|", keys %::g_TaxInfo) . (join "|", values %::g_TaxInfo);
if ($::g_sTaxDump ne $sTaxDump)
{
$::g_sTaxDump = $sTaxDump;
return $::TRUE;
}
return $::FALSE;
}
sub IsShippingInfoChanged
{
my $sShippingDump = (join "|", keys %::g_ShipInfo) . (join "|", values %::g_ShipInfo);
if ($::g_sShippingDump ne $sShippingDump)
{
$::g_sShippingDump = $sShippingDump;
return $::TRUE;
}
return $::FALSE;
}
sub TaxIsKnown
{
if ($$::g_pTaxSetupBlob{TAX_BY} != $::eTaxAlways)
{
my $sKeyPrefix = ($$::g_pTaxSetupBlob{TAX_BY} == $::eTaxByInvoice) ?
'INVOICE_' : 'DELIVERY_';
my ($sTargetCountry, $sTargetRegion);
$sTargetCountry = $::g_LocationInfo{$sKeyPrefix . 'COUNTRY_CODE'};
$sTargetRegion = $::g_LocationInfo{$sKeyPrefix . 'REGION_CODE'};
if($sTargetCountry eq '')
{
return($::FALSE);
}
}
return($::g_TaxInfo{'DONE'} == $::TRUE);
}
sub CheckTaxExemption
{
my ($nTax) = @_;
my ($sExemptKey, $sExemptDataKey);
$sExemptKey = 'EXEMPT' . $nTax;
$sExemptDataKey = $sExemptKey . 'DATA';
if($::g_pTaxSetupBlob->{MODEL} == 1 &&
$::g_TaxInfo{$sExemptKey} &&
defined $::g_TaxInfo{$sExemptDataKey})
{
if($::g_TaxInfo{$sExemptDataKey} eq '')
{
return(ACTINIC::GetPhrase(-1, 298));
}
}
return('');
}
sub DisplayPreliminaryInfoPhase
{
my ($bCheckout) = $::TRUE;
if ($#_ == 0)
{
$bCheckout = $_[0];
}
undef %ActinicOrder::s_VariableTable;
undef %ActinicOrder::s_SelectTable;
undef @ActinicOrder::s_DeleteDelimiters;
undef @ActinicOrder::s_KeepDelimiters;
my $bLocationPageNotApplicable =
(!$bCheckout &&
!$$::g_pSetupBlob{'TAX_AND_SHIP_EARLY'}) ||
($bCheckout &&
$$::g_pSetupBlob{'TAX_AND_SHIP_EARLY'} &&
$::g_InputHash{ACTION} eq ACTINIC::GetPhrase(-1, 113)); # and this isn't the start page
if (IsPhaseComplete($::PRELIMINARYINFOPHASE) ||
$bLocationPageNotApplicable ||
!($$::g_pLocationList{EXPECT_DELIVERY} ||
$$::g_pLocationList{EXPECT_INVOICE}) ||
IsPhaseHidden($::PRELIMINARYINFOPHASE))
{
push (@ActinicOrder::s_DeleteDelimiters, 'PRELIMINARYINFORMATION');
return ($::SUCCESS, '', \%ActinicOrder::s_VariableTable, \@ActinicOrder::s_DeleteDelimiters, \@ActinicOrder::s_KeepDelimiters);
}
else
{
push (@ActinicOrder::s_KeepDelimiters, 'PRELIMINARYINFORMATION');
}
if (0 < length $::g_LocationInfo{INVOICE_COUNTRY_CODE})
{
$ActinicOrder::s_SelectTable{LocationInvoiceCountry} = $::g_LocationInfo{INVOICE_COUNTRY_CODE};
}
if (0 < length $::g_LocationInfo{INVOICE_REGION_CODE})
{
$ActinicOrder::s_SelectTable{LocationInvoiceRegion} = $::g_LocationInfo{INVOICE_REGION_CODE};
}
if (0 < length $::g_LocationInfo{DELIVERY_COUNTRY_CODE})
{
$ActinicOrder::s_SelectTable{LocationDeliveryCountry} = $::g_LocationInfo{DELIVERY_COUNTRY_CODE};
}
if (0 < length $::g_LocationInfo{DELIVERY_REGION_CODE})
{
$ActinicOrder::s_SelectTable{LocationDeliveryRegion} = $::g_LocationInfo{DELIVERY_REGION_CODE};
}
$ActinicOrder::s_VariableTable{'NETQUOTEVAR:DELIVERPOSTALCODE'} = $::g_LocationInfo{'DELIVERPOSTALCODE'};
$ActinicOrder::s_VariableTable{'NETQUOTEVAR:DELIVERRESIDENTIAL'} = $::g_LocationInfo{'DELIVERRESIDENTIAL'} ? 'CHECKED' : '';
$ActinicOrder::s_VariableTable{'NETQUOTEVAR:INVOICESEPARATECHECKSTATUS'} = $::g_LocationInfo{'SEPARATESHIP'} ? 'CHECKED' : '';
if ((scalar keys %::ActinicOrder::s_VariableTable) == 0)
{
$ActinicOrder::s_VariableTable{"<OPTION VALUE=\"\">"} = "<OPTION VALUE=\"\">";
}
return ($::SUCCESS, '', \%ActinicOrder::s_VariableTable, \@ActinicOrder::s_DeleteDelimiters, \@ActinicOrder::s_KeepDelimiters, \%ActinicOrder::s_SelectTable);
}
sub DisplayTaxPhase
{
my ($bCheckout) = $::TRUE;
if ($#_ == 0)
{
$bCheckout = $_[0];
}
undef %ActinicOrder::s_VariableTable;
undef @ActinicOrder::s_DeleteDelimiters;
undef @ActinicOrder::s_KeepDelimiters;
my @Response = ParseAdvancedTax();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $bTaxAndShipEarly = $$::g_pSetupBlob{'TAX_AND_SHIP_EARLY'};
my $bNoTaxesEnabled = !(TaxNeedsCalculating('TAX_1') || TaxNeedsCalculating('TAX_2'));
if (IsPhaseDone($::TAXCHARGEPHASE) ||
!$bCheckout ||
$bNoTaxesEnabled)
{
push (@ActinicOrder::s_DeleteDelimiters, 'TAXPHASE');
return ($::SUCCESS, '', \%ActinicOrder::s_VariableTable, \@ActinicOrder::s_DeleteDelimiters, \@ActinicOrder::s_KeepDelimiters);
}
else
{
push (@ActinicOrder::s_KeepDelimiters, 'TAXPHASE');
}
my $sTaxPrefix = $::VARPREFIX.'TAX';
$ActinicOrder::s_VariableTable{$sTaxPrefix.'USERDEFINED'} = ACTINIC::EncodeText2($::g_TaxInfo{'USERDEFINED'});
my ($nTax, $sExemptFlag, $sExemptData, $sExemptCheckStatus);
foreach $nTax (1 .. 2)
{
my $sTax = "TAX_$nTax";
if(defined $$::g_pTaxSetupBlob{$sTax})
{
$ActinicOrder::s_VariableTable{$sTaxPrefix.$nTax.'DESCRIPTION'} = $$::g_pTaxSetupBlob{$sTax}{NAME};
$ActinicOrder::s_VariableTable{$sTaxPrefix.$nTax.'MESSAGE'} = $$::g_pTaxSetupBlob{$sTax}{TAX_MSG};
$ActinicOrder::s_VariableTable{$sTaxPrefix.'PROMPT00'. ($nTax - 1)} = $$::g_pTaxSetupBlob{$sTax}{TAX_EXEMPT_PROMPT};
}
$sExemptFlag = 'EXEMPT' . $nTax;
$sExemptData = $sExemptFlag . 'DATA';
$sExemptCheckStatus = $sExemptFlag . 'CHECKSTATUS';
$ActinicOrder::s_VariableTable{$sTaxPrefix.$sExemptData} = $::g_TaxInfo{$sExemptData};
$ActinicOrder::s_VariableTable{$sTaxPrefix.$sExemptCheckStatus} =
($::g_TaxInfo{$sExemptFlag}) ? 'CHECKED' : '';
}
return ($::SUCCESS, '', \%ActinicOrder::s_VariableTable, \@ActinicOrder::s_DeleteDelimiters, \@ActinicOrder::s_KeepDelimiters);
}
sub DisplayShipChargePhase
{
undef %::s_VariableTable;
undef @::s_DeleteDelimiters;
undef @::s_KeepDelimiters;
if (ActinicOrder::IsPhaseComplete($::SHIPCHARGEPHASE)	||
ActinicOrder::IsPhaseHidden($::SHIPCHARGEPHASE))
{
push (@::s_DeleteDelimiters, 'SHIPANDHANDLEPHASE');
return ($::SUCCESS, '', \%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
else
{
push (@::s_KeepDelimiters, 'SHIPANDHANDLEPHASE');
}
if ($$::g_pSetupBlob{MAKE_SHIPPING_CHARGE})
{
my @Response = ActinicOrder::CallShippingPlugIn();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
elsif (${$Response[2]}{RestoreFinalUI} != $::SUCCESS)
{
return (${$Response[2]}{RestoreFinalUI}, ${$Response[3]}{RestoreFinalUI});
}
if ($Response[10] != 0)
{
push (@::s_KeepDelimiters, 'SHIPCLASSSELECTION');
}
else
{
push (@::s_DeleteDelimiters, 'SHIPCLASSSELECTION');
}
%::s_VariableTable = %{$Response[7]};
}
$::s_VariableTable{$::VARPREFIX.'SHIPUSERDEFINED'} = ACTINIC::EncodeText2($::g_ShipInfo{'USERDEFINED'});
return ($::SUCCESS, '', \%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
sub DisplayGeneralPhase
{
undef %::s_VariableTable;
undef @::s_DeleteDelimiters;
undef @::s_KeepDelimiters;
if (ActinicOrder::IsPhaseComplete($::GENERALPHASE) ||
ActinicOrder::IsPhaseHidden($::GENERALPHASE) )
{
push (@::s_DeleteDelimiters, 'GENERALPHASE');
return (\%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
else
{
push (@::s_KeepDelimiters, 'GENERALPHASE');
}
$::s_VariableTable{$::VARPREFIX.'GENERALHOWFOUND'} 	= ACTINIC::EncodeText2($::g_GeneralInfo{'HOWFOUND'});
$::s_VariableTable{$::VARPREFIX.'GENERALWHYBUY'} 		= ACTINIC::EncodeText2($::g_GeneralInfo{'WHYBUY'});
$::s_VariableTable{$::VARPREFIX.'GENERALUSERDEFINED'} = ACTINIC::EncodeText2($::g_GeneralInfo{'USERDEFINED'});
$::s_VariableTable{$::VARPREFIX.'GENERALTITLE'} 		= ACTINIC::GetPhrase(-1, 151);
return (\%::s_VariableTable, \@::s_DeleteDelimiters, \@::s_KeepDelimiters);
}
sub ParseAdvancedTax()
{
my $sTaxZone;
my $pTaxZone;
foreach $pTaxZone (values(%{$::g_pTaxZonesBlob}))
{
if ($pTaxZone->{'DEFAULT'})
{
$ActinicOrder::g_pDefaultTaxZone = $pTaxZone;
last;
}
}
if ($$::g_pTaxSetupBlob{TAX_BY} != $::eTaxAlways)
{
my $sKeyPrefix = ($$::g_pTaxSetupBlob{TAX_BY} == $::eTaxByInvoice) ?
'INVOICE_' : 'DELIVERY_';
my ($sTargetCountry, $sTargetRegion);
$sTargetCountry = $::g_LocationInfo{$sKeyPrefix . 'COUNTRY_CODE'};
$sTargetRegion = $::g_LocationInfo{$sKeyPrefix . 'REGION_CODE'};
if($sTargetCountry eq '')
{
return($::SUCCESS, '');
}
my $sZoneMembersKey = ($sTargetRegion eq $ActinicOrder::UNDEFINED_REGION) ?
"$sTargetCountry.$ActinicOrder::UNDEFINED_REGION" :
$sTargetRegion;
if (defined $$::g_pTaxZoneMembersTable{$sZoneMembersKey})
{
$sTaxZone = $$::g_pTaxZoneMembersTable{$sZoneMembersKey};
}
else
{
if (defined $$::g_pTaxZoneMembersTable{'---.UndefinedRegion'})
{
$sTaxZone = $$::g_pTaxZoneMembersTable{'---.UndefinedRegion'};
}
else
{
$sTaxZone = 'Error';
}
}
if($sTaxZone eq 'Error')
{
my $sErrorMsgFormat;
if(defined $$::g_pPromptList{"-1,359"}{PROMPT})
{
$sErrorMsgFormat = ACTINIC::GetPhrase(-1, 359);
}
else
{
$sErrorMsgFormat = 'Please select a state/province for %s';
}
return($::FAILURE,
sprintf($sErrorMsgFormat, ACTINIC::GetCountryName($sTargetCountry)));
}
$pTaxZone = $$::g_pTaxZonesBlob{$sTaxZone};
}
else
{
$pTaxZone = $$::g_pTaxZonesBlob{0};
}
$ActinicOrder::g_pCurrentTaxZone = $pTaxZone;
my ($nTax, $sTaxKey, $sTaxBlobKey);
my @arrTaxIDs = ($$pTaxZone{TAX_1}, $$pTaxZone{TAX_2});
my $nTaxIndex = 1;
foreach $nTax (0..1)
{
$sTaxKey = 'TAX_' . $nTaxIndex;
if(defined $$::g_pTaxSetupBlob{$sTaxKey})
{
if($arrTaxIDs[$nTax] == -1)
{
delete $$::g_pTaxSetupBlob{$sTaxKey};
}
elsif($arrTaxIDs[$nTax] != $$::g_pTaxSetupBlob{$sTaxKey}{ID})
{
delete $$::g_pTaxSetupBlob{$sTaxKey};
$$::g_pTaxSetupBlob{$sTaxKey} = $$::g_pTaxesBlob{$arrTaxIDs[$nTax]};
}
}
elsif($arrTaxIDs[$nTax] != -1)
{
$$::g_pTaxSetupBlob{$sTaxKey} = $$::g_pTaxesBlob{$arrTaxIDs[$nTax]};
}
if(defined $$::g_pTaxSetupBlob{$sTaxKey})
{
SetZoneValues($pTaxZone, $nTaxIndex);
}
$nTaxIndex++;
}
$ActinicOrder::bTaxDataParsed = $::TRUE;
return($::SUCCESS, '');
}
sub SetZoneValues
{
my ($pTaxZone, $nIndex) = @_;
my $sAllowExemptKey = 'ALLOW_TAX_' . $nIndex . '_EXEMPT';
my $sTaxMsgKey = 'TAX_' . $nIndex . '_MSG';
my $sTaxPromptKey = 'TAX_' . $nIndex . '_EXEMPT_PROMPT';
my $pTaxHash = $$::g_pTaxSetupBlob{'TAX_'.$nIndex};
$$pTaxHash{ALLOW_EXEMPT} = $$pTaxZone{$sAllowExemptKey};
$$pTaxHash{TAX_MSG} = $$pTaxZone{$sTaxMsgKey};
$$pTaxHash{TAX_EXEMPT_PROMPT} = $$pTaxZone{$sTaxPromptKey};
if (!$$pTaxZone{$sAllowExemptKey})
{
delete $::g_TaxInfo{'EXEMPT' . $nIndex . 'DATA'};
}
if($nIndex == 2)
{
$$pTaxHash{TAX_ON_TAX} = $$pTaxZone{TAX_ON_TAX};
my @arrOpaque = split(/=/, $$pTaxHash{TAX_OPAQUE_DATA});
$arrOpaque[3] = $$pTaxZone{TAX_ON_TAX};
$$pTaxHash{TAX_OPAQUE_DATA} = join "=", @arrOpaque;
}
}
sub IsPhaseComplete
{
if ($#_ != 0)
{
return ($::FALSE);
}
my ($nPhase) = @_;
if ($nPhase == $::STARTSEQUENCE)
{
return ($::FALSE);
}
elsif ($nPhase == $::BILLCONTACTPHASE)
{
return ($::g_BillContact{'DONE'} ? $::TRUE : $::FALSE);
}
elsif ($nPhase == $::SHIPCONTACTPHASE)
{
return ($::g_ShipContact{'DONE'} ? $::TRUE : $::FALSE);
}
elsif ($nPhase == $::SHIPCHARGEPHASE)
{
return ($::g_ShipInfo{'DONE'} ? $::TRUE : $::FALSE);
}
elsif ($nPhase == $::TAXCHARGEPHASE)
{
return ($::FALSE);
}
elsif ($nPhase == $::GENERALPHASE)
{
return ($::g_GeneralInfo{'DONE'} ? $::TRUE : $::FALSE);
}
elsif ($nPhase == $::PAYMENTPHASE)
{
return ($::g_PaymentInfo{'DONE'} ? $::TRUE : $::FALSE);
}
elsif ($nPhase == $::PRELIMINARYINFOPHASE)
{
return ($::g_LocationInfo{'DONE'} ? $::TRUE : $::FALSE);
}
return ($::FALSE);
}
sub IsPhaseDone
{
if ($#_ != 0)
{
return ($::FALSE);
}
my ($nPhase) = @_;
return(IsPhaseComplete($nPhase) || IsPhaseHidden($nPhase));
}
sub DisplayButton
{
my ($sName, $sValue, $bDisabled) = @_;
my $sFormat = '<INPUT TYPE="SUBMIT" NAME="%s" VALUE="%s" %s>';
my $sHTML = sprintf($sFormat,
ACTINIC::EncodeText2($sName),
ACTINIC::EncodeText2($sValue),
$bDisabled ? "DISABLED" : "");
return $sHTML;
}
sub PreprocessCartToDisplay
{
my ($pCartList) = shift;
my $bPlain = shift;
my ($pOrderDetail, %CurrentItem, $pProduct, %hDDLinks);
my @aCartData;
my @Response;
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
my $nScheduleID = ActinicOrder::GetScheduleID($sDigest);
@Response = ACTINIC::GetDigitalContent($pCartList);
my $bShowDDLinks = ((scalar (keys %{$Response[2]}) > 0)) ? $::TRUE : $::FALSE;
@Response = ACTINIC::GetDigitalContent($pCartList, $::TRUE);
if ($Response[0] == $::FAILURE)
{
return (@Response);
}
%hDDLinks = %{$Response[2]};
foreach $pOrderDetail (@$pCartList)
{
my %hLineData;
my @aComponents;
%CurrentItem = %$pOrderDetail;
my ($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($CurrentItem{SID});
if ($Status == $::FAILURE)
{
return ($Status, $Message);
}
@Response = ACTINIC::GetProduct($CurrentItem{"PRODUCT_REFERENCE"}, $sSectionBlobName,
ACTINIC::GetPath());
($Status, $Message, $pProduct) = @Response;
if ($Status == $::FAILURE)
{
return (@Response);
}
@Response = ActinicOrder::GetProductTaxBands($pProduct);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($rarrCurTaxBands, $rarrDefTaxBands) = @Response[2, 3];
my $nRetailProdPrice = $pProduct->{PRICE};
my $nEffectiveQuantity = EffectiveCartQuantity($pOrderDetail, $pCartList, \&IdenticalCartLines, undef);
$hLineData{'NAME'}  		= $$pProduct{'NAME'};
$hLineData{'REFERENCE'}	= $$pProduct{'REFERENCE'};
$hLineData{'QUANTITY'}	= $CurrentItem{'QUANTITY'};
$hLineData{'PRODUCT'}  	= $pProduct;
if ($hDDLinks{$hLineData{'REFERENCE'}} ne "")
{
if ($::ReceiptPhase &&
$bShowDDLinks)
{
my $nPrompt = $bPlain ? 2251 : 2252;
$hLineData{'DDLINK'} = ACTINIC::GetPhrase(-1, $nPrompt, $hDDLinks{$hLineData{'REFERENCE'}}[0]);
}
if ($$::g_pSetupBlob{"DD_AUTO_SHIP"} &&
$$pProduct{'AUTOSHIP'})
{
$hLineData{'SHIPPED'} = $CurrentItem{'QUANTITY'};
}
}
my $ComponentPrice = 0;
my $nRealIndex = 0;
if( $pProduct->{COMPONENTS} )
{
my $VariantList = GetCartVariantList(\%CurrentItem);
my %Component;
my $pComponent;
my $nIndex = 0;
foreach $pComponent (@{$pProduct->{COMPONENTS}})
{
@Response = FindComponent($pComponent, $VariantList);
($Status, %Component) = @Response;
if ($Status != $::SUCCESS)
{
return ($Status, $Component{text});
}
if ( $Component{quantity} <= 0 )
{
$nIndex++;
next;
}
$nIndex++;
$nRealIndex++;
my %hComponentItem;
my $nComponentQuantity = 0;
if ( $pComponent->[$::CBIDX_NAME] )
{
$nComponentQuantity = $Component{quantity} * $CurrentItem{'QUANTITY'};
if ($$pProduct{NO_ORDERLINE} &&
$nRealIndex == 1 &&
$Component{quantity} == 1)
{
$hLineData{'CANEDIT'} = 1;
$hComponentItem{'CANEDIT'} = 1;
}
}
my $sRef= $Component{code} &&
($pComponent->[$::CBIDX_ASSOCPRODPRICE] == 1 ||
$Component{'AssociatedPrice'}) ?
$Component{code} :
$CurrentItem{"PRODUCT_REFERENCE"} . "_" . $nIndex;
@Response = Cart::GetComponentPriceAndTaxBands(\%Component, $sRef, $nEffectiveQuantity,
$nRetailProdPrice, $rarrCurTaxBands, $rarrDefTaxBands, $pProduct, $nScheduleID);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($nItemPrice, $phashTaxBands, $rarrCurCompTaxBands, $rarrDefCompTaxBands) = @Response[2 .. 5];
if (!$pComponent->[$::CBIDX_SEPARATELINE])
{
$ComponentPrice += $nItemPrice * $Component{quantity};
}
$hLineData{'HASCOMPONENT'} = 1;
$hComponentItem{'NAME'} 		= $Component{text};
$hComponentItem{'REFERENCE'} 	= $Component{code};
$hComponentItem{'QUANTITY'} 	= $nComponentQuantity ? $nComponentQuantity : ($bPlain ? "" : '&nbsp;');
$hComponentItem{'SEPARATELINE'}	= $pComponent->[$::CBIDX_SEPARATELINE];
$hComponentItem{'OPAQUE_SHIPPING_DATA'} = $Component{OPAQUE_SHIPPING_DATA};
$hComponentItem{'ALT_WEIGHT'} = $Component{ALT_WEIGHT};
$hComponentItem{'SHIP_SEPARATELY'} = $Component{SHIP_SEPARATELY};
$hComponentItem{'SHIP_CATEGORY'} = $Component{SHIP_CATEGORY};
$hComponentItem{'SHIP_SUPPLEMENT'} = $Component{SHIP_SUPPLEMENT};
$hComponentItem{'SHIP_SUPPLEMENT_ONCE'} = $Component{SHIP_SUPPLEMENT_ONCE};
$hComponentItem{'HAND_SUPPLEMENT'} = $Component{HAND_SUPPLEMENT};
$hComponentItem{'HAND_SUPPLEMENT_ONCE'} = $Component{HAND_SUPPLEMENT_ONCE};
$hComponentItem{'SHIP_QUANTITY'} = $Component{SHIP_QUANTITY};
$hComponentItem{'EXCLUDE_FROM_SHIP'} = $Component{EXCLUDE_FROM_SHIP};
$hComponentItem{'USE_ASSOCIATED_SHIP'} = $Component{'UseAssociatedShip'};
$hComponentItem{'COST_PRICE'} = $Component{COST_PRICE};
if ($hDDLinks{$Component{code}} ne "")
{
if ($::ReceiptPhase &&
$bShowDDLinks)
{
my $nPrompt = $bPlain ? 2251 : 2252;
$hComponentItem{'DDLINK'} = ACTINIC::GetPhrase(-1, $nPrompt, $hDDLinks{$Component{code}}[0]);
}
if ($$::g_pSetupBlob{"DD_AUTO_SHIP"} &&
$$pProduct{'AUTOSHIP'})
{
$hLineData{'SHIPPED'} = $CurrentItem{'QUANTITY'};
$hComponentItem{'SHIPPED'} = $nComponentQuantity;
}
}
@Response = FormatPrice($nItemPrice, $::TRUE, $::g_pCatalogBlob);
$hComponentItem{'ACTINICPRICE'} = $nItemPrice;
$hComponentItem{'ACTINICCOST'} = $nItemPrice  * $nComponentQuantity;
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($bPlain)
{
$hComponentItem{'PRICE'} 		= $Response[2];
}
else
{
@Response = ACTINIC::EncodeText($Response[2],$::TRUE, $::TRUE);
$hComponentItem{'PRICE'} 		= $Response[1];
}
@Response = FormatPrice($nItemPrice  * $nComponentQuantity, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($bPlain)
{
$hComponentItem{'COST'} 		= $Response[2];
}
else
{
@Response = ACTINIC::EncodeText($Response[2],$::TRUE, $::TRUE);
$hComponentItem{'COST'} 		= $Response[1];
}
my $rarrTemp;
foreach $rarrTemp (($rarrCurCompTaxBands, $rarrDefCompTaxBands))
{
$rarrTemp->[0] = 
ProductToOrderDetailTaxOpaqueData('TAX_1', $nItemPrice, $rarrTemp->[0], $nItemPrice);
$rarrTemp->[1] = 
ProductToOrderDetailTaxOpaqueData('TAX_2', $nItemPrice, $rarrTemp->[1], $nItemPrice);
}
my $nTax1 = 0;
my $nTax2 = 0;
if ($hComponentItem{'SEPARATELINE'})
{
my $bTreatCustomAsExempt = $::FALSE;
@Response = CalculateTax($nItemPrice, $CurrentItem{"QUANTITY"} * $Component{quantity},
$rarrCurCompTaxBands, $rarrDefCompTaxBands, $nItemPrice);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$nTax1 = ActinicOrder::RoundScientific($Response[2]);
$nTax2 = ActinicOrder::RoundScientific($Response[3]);
@Response = ActinicOrder::PrepareProductTaxOpaqueData($phashTaxBands,
$nItemPrice, $nItemPrice, $bTreatCustomAsExempt);
if($Response[0] != $::SUCCESS)
{
return(@Response);
}
$hComponentItem{'TAX_OPAQUE_DATA'}		= $Response[2];
}
$hComponentItem{'TAXBAND1'}	= $rarrCurCompTaxBands->[0];
$hComponentItem{'TAXBAND2'}	= $rarrCurCompTaxBands->[1];
$hComponentItem{'TAX1'}		= $nTax1;
$hComponentItem{'TAX2'}		= $nTax2;
push @aComponents, \%hComponentItem;
}
}
if ($hLineData{'CANEDIT'} == 1 &&
$nRealIndex > 1)
{
$hLineData{'CANEDIT'} = 0;
}
$hLineData{'COMPONENTS'} = \@aComponents;
my $sPrice = 0;
$sPrice = ActinicOrder::CalculateSchPrice($pProduct, $nEffectiveQuantity, $sDigest);
my ($nItemTotal);
my $nPriceModel = $$pProduct{PRICING_MODEL};
if( $nPriceModel == $ActinicOrder::PRICING_MODEL_PROD_COMP )
{
$sPrice += $ComponentPrice;
}
elsif( $nPriceModel == $ActinicOrder::PRICING_MODEL_COMP )
{
$sPrice = $ComponentPrice;
}
if ($sPrice > 0)
{
$nItemTotal = $sPrice * $CurrentItem{"QUANTITY"};
$hLineData{'ACTINICPRICE'} = $sPrice;
$hLineData{'ACTINICCOST'} 	= $nItemTotal;
@Response = FormatPrice($sPrice, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($bPlain)
{
$hLineData{'PRICE'} = $Response[2];
}
else
{
@Response = ACTINIC::EncodeText($Response[2],$::TRUE,$::TRUE);
$hLineData{'PRICE'} = $Response[1];
}
@Response = FormatPrice($nItemTotal, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($bPlain)
{
$hLineData{'COST'} = $Response[2];
}
else
{
@Response = ACTINIC::EncodeText($Response[2],$::TRUE,$::TRUE);
$hLineData{'COST'} = $Response[1];
}
}
$hLineData{'DATE'} = $CurrentItem{'DATE'};
$hLineData{'INFO'} = $CurrentItem{'INFOINPUT'};
@Response = CalculateTax($sPrice, $CurrentItem{"QUANTITY"}, 
$rarrCurTaxBands, $rarrDefTaxBands, $$pProduct{"PRICE"});
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$hLineData{'TAX1'} = ActinicOrder::RoundScientific($Response[2]);
$hLineData{'TAX2'} = ActinicOrder::RoundScientific($Response[3]);
my $rarrTemp;
foreach $rarrTemp (($rarrCurTaxBands, $rarrDefTaxBands))
{
$rarrTemp->[0] = 
ProductToOrderDetailTaxOpaqueData('TAX_1', $sPrice, $rarrTemp->[0], $$pProduct{"PRICE"});
$rarrTemp->[1] = 
ProductToOrderDetailTaxOpaqueData('TAX_2', $sPrice, $rarrTemp->[1], $$pProduct{"PRICE"});
}
$hLineData{'TAXBAND1'} = $rarrCurTaxBands->[0];
$hLineData{'TAXBAND2'} = $rarrCurTaxBands->[1];
$hLineData{'DEFTAXBAND1'} = $rarrDefTaxBands->[0];
$hLineData{'DEFTAXBAND2'} = $rarrDefTaxBands->[1];
push @aCartData, \%hLineData;
}
return ($::SUCCESS, "", @aCartData);
}
sub ShowCart
{
my (@Response, $Status, $Message);
my $pFailures = $_[0];
@Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS &&
$Response[0] != $::EOF)
{
return (@Response);
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
my ($sLine, %VariableTable);
@Response = GenerateShoppingCartLines($pCartList, $::TRUE, $pFailures, "SCTemplate.html");
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$VariableTable{$::VARPREFIX."CARTDISPLAY"} = $Response[2];
my ($sBack, $sPrevPage, @sTemp);
$sPrevPage = $::Session->GetLastShopPage();
if( ACTINIC::IsCatalogFramed() )
{
$sBack = '';
}
else
{
$sBack = ACTINIC::GetPhrase(-1, 1973) . "<P><A HREF=\"" . $sPrevPage . "\">" . ACTINIC::GetPhrase(-1, 47) . "</A><P>" . ACTINIC::GetPhrase(-1, 1970) . "\n";
}
$sBack .= '<INPUT TYPE="HIDDEN" NAME="PAGE" VALUE="CART">';
$VariableTable{$::VARPREFIX."BACKLINK"} = $sBack;
if ($pCartObject->CountItems() != 0)
{
$ACTINIC::B2B->SetXML("UpdateButton", $::TRUE);
$ACTINIC::B2B->SetXML("CheckoutButton", $::TRUE);
}
else
{
$ACTINIC::B2B->SetXML("UpdateButtonDisabled", $::TRUE);
$ACTINIC::B2B->SetXML("CheckoutButtonDisabled", $::TRUE);
}
if ( ($ACTINIC::B2B->Get('UserDigest') &&
$$::g_pSetupBlob{'REG_SHOPPING_LIST'} == 1)
||
(!$ACTINIC::B2B->Get('UserDigest') &&
$$::g_pSetupBlob{'UNREG_SHOPPING_LIST'} == 1))
{
$ACTINIC::B2B->SetXML("ShoppingList", $::TRUE);
if ($pCartObject->CountItems() == 0)
{
$ACTINIC::B2B->SetXML("SaveButtonDisabled", $::TRUE);
}
else
{
$ACTINIC::B2B->SetXML("SaveButton", $::TRUE);
}
if ($pCartObject->IsExternalCartFileExist())
{
$ACTINIC::B2B->SetXML("RestoreButton", $::TRUE);
}
else
{
$ACTINIC::B2B->SetXML("RestoreButtonDisabled", $::TRUE);
}
}
$ACTINIC::B2B->SetXML("ContinueButton", $::TRUE);
my ($sPath, $sHTML);
$sPath = ACTINIC::GetPath();
@Response = ACTINIC::TemplateFile($sPath."SCTemplate.html", \%VariableTable);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
if( !$ACTINIC::B2B->Get('UserDigest') )
{
@Response = ACTINIC::MakeLinksAbsolute($sHTML, $::g_sWebSiteUrl, $::g_sContentUrl);
}
else
{
my $sCgiUrl = $::g_sAccountScript;
$sCgiUrl   .= ($::g_InputHash{SHOP} ? '?SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) . '&': '?');
$sCgiUrl   .= 'PRODUCTPAGE=';
@Response = ACTINIC::MakeLinksAbsolute($sHTML, $sCgiUrl, $::Session->GetBaseUrl());
}
return (@Response);
}
sub InfoLineHTML
{
my ($sPrompt, $sInfo, $sTemplate) = @_;
my %hVariables;
$hVariables{$::VARPREFIX . 'PROMPTLABEL'}	= $sPrompt;
$hVariables{$::VARPREFIX . 'PROMPTVALUE'} 	= $sInfo;
my ($Status, $Message, $sLine) = ACTINIC::TemplateString($sTemplate, \%hVariables);
if ($Status != $::SUCCESS)
{
return ($Message);
}
return($sLine);
}
sub DiscountInfoLineHTML
{
my ($sInfo, $sTemplate) = @_;
my %hVariables;
$hVariables{$::VARPREFIX . 'INFOLINE'} 		= $sInfo;
my ($Status, $Message, $sLine) = ACTINIC::TemplateString($sTemplate, \%hVariables);
if ($Status != $::SUCCESS)
{
return ($Message);
}
return($sLine);
}
sub DuplicateLinkLineHTML
{
my ($sLink, $sTemplate) = @_;
my %hVariables;
$hVariables{$::VARPREFIX . 'DUPLICATELINK'} = $sLink;
my ($Status, $Message, $sLine) = ACTINIC::TemplateString($sTemplate, \%hVariables);
if ($Status != $::SUCCESS)
{
return ($Message);
}
return($sLine);
}
sub ProductLineHTML
{
my ($sProdref, $sName, $sQuantity, $sTemplate, $sDuplicateTemplate, $pDuplicates, $sThumbnail, $bIncludeButtons) = @_;
$sProdref	= $sProdref ? $sProdref : '&nbsp;';
my %hVariables;
$hVariables{$::VARPREFIX . 'PRODREF'} 		= $sProdref;
$hVariables{$::VARPREFIX . 'PRODUCTNAME'} = $sName;
$hVariables{$::VARPREFIX . 'QUANTITY'} 	= $sQuantity;
$hVariables{$::VARPREFIX . 'DUPLICATELINKCAPTION'} = ACTINIC::GetPhrase(-1, 2376);
if (length $sThumbnail > 0)
{
my $sWidth  = $$::g_pSetupBlob{SEARCH_THUMBNAIL_WIDTH}  == 0 ? "" : sprintf("width=%d ",  $$::g_pSetupBlob{SEARCH_THUMBNAIL_WIDTH});
my $sHeight = $$::g_pSetupBlob{SEARCH_THUMBNAIL_HEIGHT} == 0 ? "" : sprintf("height=%d ", $$::g_pSetupBlob{SEARCH_THUMBNAIL_HEIGHT});
$hVariables{$::VARPREFIX . 'THUMBNAILSIZE'} = $sWidth . $sHeight;
$hVariables{$::VARPREFIX . 'THUMBNAIL'} = $sThumbnail;
$ACTINIC::B2B->SetXML('ImageLine', $::TRUE);
}
else
{
$ACTINIC::B2B->SetXML('ImageLine', undef);
}
my ($Status, $Message, $sLine) = ACTINIC::TemplateString($sTemplate, \%hVariables);
if ($Status != $::SUCCESS)
{
return ($Message);
}
if ($::DISPLAY_PRODUCT_DUPLICATE_LINKS &&
defined $pDuplicates &&
keys %{$pDuplicates} > 0 &&
$bIncludeButtons &&
$$::g_pSetupBlob{'DISPLAY_DUPLICATE_LINKS'})
{
my $sDuplicateHTML;
my $sKey;
foreach $sKey (keys %{$pDuplicates})
{
my $sShop = ($::g_InputHash{SHOP} ? '&SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) : '');
my $sProdLink = sprintf("<A HREF=\"$::g_sSearchScript?PRODREF=%s&NOLOGIN=1%s\">%s</A>",
ACTINIC::EncodeText2($sKey),
$sShop,
$$pDuplicates{$sKey});
$sDuplicateHTML .= DuplicateLinkLineHTML($sProdLink, $sDuplicateTemplate);
}
$ACTINIC::B2B->SetXML('DuplicateLinkLine', $sDuplicateHTML);
$ACTINIC::B2B->SetXML('DuplicateLinks', $::TRUE);
}
else
{
$ACTINIC::B2B->SetXML('DuplicateLinks', undef);
}
$sLine = ACTINIC::ParseXMLCore($sLine);
return($sLine);
}
sub AlsoBoughtItemLine
{
my ($sProdref, $sTemplate) = @_;
my ($Status, $Message, $pProduct) = Cart::GetProduct($sProdref);
my @Response = FormatPrice($$pProduct{'PRICE'}, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::EncodeText($Response[2],$::TRUE, $::TRUE);
my $sPrice = $Response[1];
my $sThumbnail = $$pProduct{'THUMBNAIL'};
my %hVariables;
$hVariables{$::VARPREFIX . 'PRODREF'}		= $$pProduct{'REFERENCE'};
$hVariables{$::VARPREFIX . 'PRODUCTNAME'}	= $$pProduct{'NAME'};
$hVariables{$::VARPREFIX . 'PRICE'} 		= $sPrice;
$hVariables{$::VARPREFIX . 'THUMBNAIL'} 	= $sThumbnail;
if (length $sThumbnail > 0)
{
my $sWidth  = $$::g_pSetupBlob{SEARCH_THUMBNAIL_WIDTH}  == 0 ? "" : sprintf("width=%d ",  $$::g_pSetupBlob{SEARCH_THUMBNAIL_WIDTH});
my $sHeight = $$::g_pSetupBlob{SEARCH_THUMBNAIL_HEIGHT} == 0 ? "" : sprintf("height=%d ", $$::g_pSetupBlob{SEARCH_THUMBNAIL_HEIGHT});
$hVariables{$::VARPREFIX . 'THUMBNAILSIZE'} 	= $sWidth . $sHeight;
$ACTINIC::B2B->SetXML('ImageLine', $::TRUE);
}
else
{
$ACTINIC::B2B->SetXML('ImageLine', undef);
}
my $sLine;
($Status, $Message, $sLine) = ACTINIC::TemplateString($sTemplate, \%hVariables);
if ($Status != $::SUCCESS)
{
return ($Message);
}
$sLine = ACTINIC::ParseXMLCore($sLine);
return($sLine);
}
sub OrderLineHTML
{
my ($bIncludeButtons, $sProdTable, $sPrice, $sCost, $sRemove, $sRowspan, $sTemplate, $sInfoLine, $sDateLine) = @_;
my %hVariables;
$hVariables{$::VARPREFIX . 'PRICE'} = $sPrice;
$hVariables{$::VARPREFIX . 'COST'} 	= $sCost;
$hVariables{$::VARPREFIX . 'REMOVEBUTTON'} 	= $sRemove;
$hVariables{$::VARPREFIX . 'REMOVEROWSPAN'} 	= $sRowspan;
my ($Status, $Message, $sLine) = ACTINIC::TemplateString($sTemplate, \%hVariables);
if ($Status != $::SUCCESS)
{
return ($Message);
}
$ACTINIC::B2B->SetXML('ProductLine', $sProdTable);
$ACTINIC::B2B->SetXML('InfoLine', $sInfoLine);
$ACTINIC::B2B->SetXML('DateLine', $sDateLine);
if ($sRowspan > 0)
{
$ACTINIC::B2B->SetXML('RemoveButtonSpan', $::TRUE);
}
else
{
$ACTINIC::B2B->SetXML('RemoveButtonSpan', undef);
}
$sLine = ACTINIC::ParseXMLCore($sLine);
return($sLine);
}
sub AdjustmentLineHTML
{
my ($sAdjustmentDescription, $nAdjustmentTotal, $sHTMLFormat) = @_;
my ($nStatus, $sMessage, $sLine, $sAdjustmentTotal);
my %hVariables;
$hVariables{$::VARPREFIX . 'ADJUSTMENTCAPTION'} = ACTINIC::EncodeText2($sAdjustmentDescription);
($nStatus, $sMessage, $sAdjustmentTotal) = FormatPrice($nAdjustmentTotal, $::TRUE, $::g_pCatalogBlob);
if ($nStatus != $::SUCCESS)
{
return ($sMessage);
}
$hVariables{$::VARPREFIX . 'ADJUSTMENT'} = ACTINIC::EncodeText2($sAdjustmentTotal);
($nStatus, $sMessage, $sLine) = ACTINIC::TemplateString($sHTMLFormat, \%hVariables);
if ($nStatus != $::SUCCESS)
{
return ($sMessage);
}
return($sLine);
}
sub GenerateShoppingCartLines
{
no strict 'refs';
if ($#_ < 0)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'GenerateShoppingCartLines'), 0, 0);
}
my ($pCartList) 		= $_[0];
my $bIncludeButtons 	= $_[1];
my $aFailures 			= $_[2];
my $sTemplate 			= $_[3];
my %hAlsoBoughtRefs;
my (@Response, $Status, $Message);
@Response = $::Session->GetCartObject($::TRUE);
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
my ($Ignore0, $Ignore1, $nSubTotal, $nShipping, $nTax1, $nTax2, $nTotal, $nShippingTax1, $nShippingTax2, $nHandling, $nHandlingTax1, $nHandlingTax2) = @Response;
@Response = SummarizeOrderPrintable(@Response);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($Ignore2, $Ignore3, $sSubTotal, $sShipping, $sHandling, $sTax1, $sTax2, $sTotal) = @Response;
my @aCartData;
($Status, $Message, @aCartData) = PreprocessCartToDisplay($pCartList);
if ($Status != $::SUCCESS)
{
return ($Status, $Message);
}
my ($sOrderLines);
my ($sMessage, $pTree);
($Status, $sMessage, $pTree) = ACTINIC::PreProcessXMLTemplate(ACTINIC::GetPath() . $sTemplate);
if ($Status != $::SUCCESS)
{
return ($Status, $sMessage);
}
my $pXML = new Element({"_CONTENT" => $pTree});
if (!$pXML->FindNode("XMLTEMPLATE", "NAME", "ShoppingCart"))
{
return ($::SUCCESS, "", "");
}
my $sOrderLineHTML 	= ACTINIC_PXML::GetTemplateFragment($pXML, "OrderLine");
my $sProductLineHTML = ACTINIC_PXML::GetTemplateFragment($pXML, "ProductLine");
my $sInfoLineHTML		= ACTINIC_PXML::GetTemplateFragment($pXML, "InfoLine");
my $sDateLineHTML		= ACTINIC_PXML::GetTemplateFragment($pXML, "DateLine");
my $sAlsoBoughtLine	= ACTINIC_PXML::GetTemplateFragment($pXML, "AlsoBoughtLine");
my $sDiscountInfoLineHTML		= ACTINIC_PXML::GetTemplateFragment($pXML, "DiscountInfoLine");
my $sOrderAdjustmentRowHTML 	= ACTINIC_PXML::GetTemplateFragment($pXML, "AdjustmentRow");
my $sDuplicateLinkLineHTML 	= ACTINIC_PXML::GetTemplateFragment($pXML, "DuplicateLinkLine");
my $sRelatedProductLine			= ACTINIC_PXML::GetTemplateFragment($pXML, "RelatedProductLine");
my $sProductAdjustmentLines;
my ($pOrderDetail, %CurrentItem, $pProduct, $nLineCount);
$nLineCount = 0;
foreach $pOrderDetail (@aCartData)
{
%CurrentItem = %$pOrderDetail;
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
my $nEffectiveQuantity = EffectiveCartQuantity($pOrderDetail, $pCartList, \&IdenticalCartLines, undef);
@Response = ACTINIC::ProcessEscapableText($$pProduct{'NAME'});
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $sShop = ($::g_InputHash{SHOP} ? '&SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) : '');
my $sProdLinkFormat = "<A HREF=\"$::g_sSearchScript?PRODREF=%s&NOLOGIN=1$sShop\">%s</A>";
my $sProdLink;
my $sProdRef;
if ($bProductSupressed &&
$bIncludeButtons &&
(!$CurrentItem{'CANEDIT'} == 1))
{
$sProdRef = "";
$sProdLink = ACTINIC::EncodeText2(ACTINIC::GetPhrase(-1, 2418));
}
else
{
$sProdRef = $$pProduct{'REFERENCE'};
$sProdLink = !$bIncludeButtons ? $Response[1] : sprintf($sProdLinkFormat, ACTINIC::EncodeText2($$pProduct{'REFERENCE'}), $Response[1]);
}
$sProdLink .= $CurrentItem{'DDLINK'};
my $sQuantityText = $CurrentItem{QUANTITY};
if ($$pProduct{"MIN_QUANTITY_ORDERABLE"} != $$pProduct{"MAX_QUANTITY_ORDERABLE"}	&&
$bIncludeButtons)
{
if ($aFailures->[$nLineCount]->{"QUANTITY"} &&
defined $aFailures->[$nLineCount]->{"BAD_QUANTITY"})
{
$sQuantityText = $aFailures->[$nLineCount]->{"BAD_QUANTITY"};
}
$sQuantityText = "<INPUT TYPE=TEXT SIZE=\"4\" NAME=\"Q_" . $nLineCount . "\" VALUE=\"". $sQuantityText . "\" STYLE=\"text-align: right;";
if ($aFailures->[$nLineCount]->{"QUANTITY"})
{
$sQuantityText .= "background-color: $::g_sErrorColor";
}
$sQuantityText .= "\">";
}
elsif ($bIncludeButtons)
{
$sQuantityText = "<INPUT TYPE=HIDDEN NAME=\"Q_" . $nLineCount . "\" VALUE=\"". $sQuantityText . "\">" . $sQuantityText;
}
my $sRemove = "<INPUT TYPE=CHECKBOX NAME=\"D_" . $nLineCount . "\">";
my ($sDay, $sMonth, $sYear);
my $sDateLine;
if (length $$pProduct{'DATE_PROMPT'} > 0)
{
if ($aFailures->[$nLineCount]->{"DATE"} &&
defined $aFailures->[$nLineCount]->{"DATE"})
{
$sDay = substr($aFailures->[$nLineCount]->{"BAD_DATE"}, 8, 2);
$sMonth = substr($aFailures->[$nLineCount]->{"BAD_DATE"}, 5, 2); # which is in actinic internal format YYYY/MM/DD
$sYear = substr($aFailures->[$nLineCount]->{"BAD_DATE"}, 0, 4);
}
else
{
$sDay = substr($CurrentItem{"DATE"}, 8, 2);
$sMonth = substr($CurrentItem{"DATE"}, 5, 2); # which is in actinic internal format YYYY/MM/DD
$sYear = substr($CurrentItem{"DATE"}, 0, 4);
}
$sMonth += 0;
$sDay += 0;
$sMonth = $::g_InverseMonthMap{$sMonth};
if ($bIncludeButtons)
{
my $sStyle;
if ($aFailures->[$nLineCount]->{"DATE"})
{
$sStyle = " style=\"background-color: $::g_sErrorColor\"";
}
my $nMinYear = $$pProduct{"DATE_MIN"};
my $nMaxYear = $$pProduct{"DATE_MAX"};
$sDay 	= ACTINIC::GenerateComboHTML("DAY_$nLineCount", $sDay, "%2.2d", $sStyle, (1..31));
$sMonth	= ACTINIC::GenerateComboHTML("M_$nLineCount", $sMonth, "%s", $sStyle, @::gMonthList);
if ($nMinYear == $nMaxYear)
{
$sYear = "$nMinYear<INPUT TYPE=HIDDEN NAME=\"Y_$nLineCount\" VALUE=\"$nMinYear\">"
}
else
{
$sYear 	= ACTINIC::GenerateComboHTML("Y_$nLineCount", $sYear, "%4.4d", $sStyle, ($nMinYear..$nMaxYear));
}
}
my $sDatePrompt = ACTINIC::FormatDate($sDay, $sMonth, $sYear);
$sDateLine = InfoLineHTML($$pProduct{'DATE_PROMPT'}, $sDatePrompt, $sDateLineHTML);
}
my $sInfoLine;
if (length $$pProduct{'OTHER_INFO_PROMPT'} > 0)
{
my $sInfo = $CurrentItem{'INFO'};
if ($aFailures->[$nLineCount]->{"INFOINPUT"} &&
defined $aFailures->[$nLineCount]->{"BAD_INFOINPUT"})
{
$sInfo = $aFailures->[$nLineCount]->{"BAD_INFOINPUT"};
}
$sInfo = InfoHTMLGenerate($$pProduct{'REFERENCE'}, $nLineCount, $sInfo, !$bIncludeButtons, $aFailures->[$nLineCount]->{"INFOINPUT"});
$sInfo =~ s/%0a/<BR>/g;
$sInfoLine = InfoLineHTML($$pProduct{'OTHER_INFO_PROMPT'}, $sInfo, $sInfoLineHTML);
}
my $ProdTable;
my $nRowspan = scalar @aComponentsSeparated + 1;
if (!$bProductSupressed)
{
$ProdTable = ProductLineHTML($$pProduct{'REFERENCE'}, $sProdLink, $sQuantityText, $sProductLineHTML, $sDuplicateLinkLineHTML, $$pProduct{'DUPLICATES'}, $$pProduct{'THUMBNAIL'}, $bIncludeButtons);
}
elsif ($bProductSupressed &&
$bIncludeButtons &&
!$CurrentItem{'CANEDIT'} == 1)
{
if (scalar @aComponentsIncluded > 0)
{
$nRowspan++;
}
$ProdTable = ProductLineHTML($sProdRef, $sProdLink, $sQuantityText, $sProductLineHTML, $sDuplicateLinkLineHTML, $$pProduct{'DUPLICATES'}, $$pProduct{'THUMBNAIL'}, $bIncludeButtons);
$sOrderLines .= OrderLineHTML($bIncludeButtons,
$ProdTable,
'&nbsp;',
'&nbsp;',
$sRemove,
$nRowspan,
$sOrderLineHTML, $sInfoLine, $sDateLine);
$ProdTable = "";
$sRemove = "";
$nRowspan = -1;
($sInfoLine, $sDateLine) = ("", "");
}
foreach $pComponent (@aComponentsIncluded)
{
$ProdTable .= ProductLineHTML($pComponent->{'REFERENCE'},
$pComponent->{'NAME'} . $pComponent->{'DDLINK'},
$pComponent->{'QUANTITY'},
$sProductLineHTML);
}
my $sPrice;
my $sCost;
if ($$::g_pSetupBlob{'PRICES_DISPLAYED'})
{
$sPrice = $CurrentItem{'PRICE'} ? $CurrentItem{'PRICE'} : "--";
$sCost  = $CurrentItem{'COST'}  ? $CurrentItem{'COST'}  : "--";
}
if ($ProdTable)
{
$sOrderLines .= OrderLineHTML($bIncludeButtons, $ProdTable, $sPrice, $sCost, $sRemove, $nRowspan, $sOrderLineHTML, $sInfoLine, $sDateLine);
($sInfoLine, $sDateLine) = ("", "");
}
foreach $pComponent (@aComponentsSeparated)
{
my $sCompQty = $pComponent->{'QUANTITY'};
my $sCompRemove = "";
my $nCompRowspan = -1;
if ($CurrentItem{'CANEDIT'} == 1 &&
$$pComponent{'CANEDIT'} == 1 &&
$bIncludeButtons)
{
$sCompQty = $sQuantityText;
$sCompRemove = $sRemove;
$nCompRowspan = scalar @aComponentsSeparated;
}
my $sProductLines = ProductLineHTML($pComponent->{'REFERENCE'},
$pComponent->{'NAME'}  . $pComponent->{'DDLINK'},
$sCompQty,
$sProductLineHTML);
$sOrderLines .= OrderLineHTML($bIncludeButtons,
$sProductLines,
$pComponent->{'PRICE'},
$pComponent->{'COST'}, $sCompRemove, $nCompRowspan,
$sOrderLineHTML, $sInfoLine, $sDateLine);
}
my $parrProductAdjustments = $pCartObject->GetConsolidatedProductAdjustments($nLineCount);
my $parrAdjustDetails;
foreach $parrAdjustDetails (@$parrProductAdjustments)
{
@Response = ACTINIC::EncodeText($parrAdjustDetails->[$::eAdjIdxProductDescription]);
my $sProductHTML = ProductLineHTML('', $Response[1], '', $sProductLineHTML);
@Response = FormatPrice($parrAdjustDetails->[$::eAdjIdxAmount], $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::EncodeText($Response[2],$::TRUE,$::TRUE);
my $sAdjLine = OrderLineHTML($::FALSE, $sProductHTML, "", $Response[1], '', 0, $sOrderLineHTML);
if ($$::g_pSetupBlob{'SHOW_DISCOUNT_AT_CART_END'})
{
$sProductAdjustmentLines .= $sAdjLine;
}
else
{
$sOrderLines .= $sAdjLine;
}
}
$nLineCount++;
}
if ($$::g_pSetupBlob{'SHOW_DISCOUNT_AT_CART_END'})
{
$sOrderLines .= $sProductAdjustmentLines;
}
$ACTINIC::B2B->SetXML("OrderLine", $sOrderLines);
my %hVariables;
if ($nLineCount == 0)
{
$ACTINIC::B2B->SetXML("EmptyCartLine", 1);
$ACTINIC::B2B->SetXML("OrderLine", "");
}
if ($$::g_pSetupBlob{'PRICES_DISPLAYED'} &&
$nTotal > 0 &&
$nLineCount > 0)
{
$ACTINIC::B2B->SetXML("SubTotalRow", 1);
$hVariables{$::VARPREFIX . 'SUBTOTAL'} = ACTINIC::EncodeText2($sSubTotal);
$ACTINIC::B2B->SetXML("TotalRow", 1);
$hVariables{$::VARPREFIX . 'TOTAL'} = ACTINIC::EncodeText2($sTotal);
my $parrAdjustments = $pCartObject->GetOrderAdjustments();
my $nAdjustmentCount = scalar(@$parrAdjustments) + scalar($pCartObject->GetFinalAdjustments());
if($nAdjustmentCount > 0)
{
my $sAdjustmentsHTML;
my $parrAdjustDetails;
foreach $parrAdjustDetails (@$parrAdjustments)
{
$sAdjustmentsHTML .=
AdjustmentLineHTML(
$parrAdjustDetails->[$::eAdjIdxProductDescription],
$parrAdjustDetails->[$::eAdjIdxAmount],
$sOrderAdjustmentRowHTML);
}
$parrAdjustments = $pCartObject->GetFinalAdjustments();
foreach $parrAdjustDetails (@$parrAdjustments)
{
$sAdjustmentsHTML .=
AdjustmentLineHTML(
$parrAdjustDetails->[$::eAdjIdxProductDescription],
$parrAdjustDetails->[$::eAdjIdxAmount],
$sOrderAdjustmentRowHTML);
}
$ACTINIC::B2B->SetXML("AdjustmentRows", 1);
$hVariables{$::VARPREFIX . 'ADJUSTMENTROWS'} = $sAdjustmentsHTML;
}
if ($$::g_pSetupBlob{'MAKE_SHIPPING_CHARGE'} && $nShipping != 0)
{
@Response = $pCartObject->GetShippingPluginResponse();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
elsif (${$Response[2]}{GetShippingDescription} != $::SUCCESS)
{
return (${$Response[2]}{GetShippingDescription}, ${$Response[3]}{GetShippingDescription});
}
my $sShipDescription = $Response[5];
@Response = ACTINIC::EncodeText($sShipping);
my $sCaption = ACTINIC::GetPhrase(-1, 102);
if ($sShipDescription ne "")
{
$sCaption .= " ($sShipDescription)";
}
$ACTINIC::B2B->SetXML("ShippingRow", 1);
$hVariables{$::VARPREFIX . 'SHIPPINGCAPTION'} = $sCaption;
$hVariables{$::VARPREFIX . 'SHIPPING'} = $Response[1];
}
if ($$::g_pSetupBlob{'MAKE_HANDLING_CHARGE'} && $nHandling != 0)
{
$ACTINIC::B2B->SetXML("HandlingRow", 1);
$hVariables{$::VARPREFIX . 'HANDLING'} = ACTINIC::EncodeText2($sHandling);
}
if ($nTax1 != 0)
{
if (PricesIncludeTaxes())
{
if ($nTax1 > 0)
{
$ACTINIC::B2B->SetXML("IncludingTax1Row", 1);
}
else
{
$ACTINIC::B2B->SetXML("ExemptedTax1Row", 1);
}
}
else
{
$ACTINIC::B2B->SetXML("Tax1Row", 1);
}
$hVariables{$::VARPREFIX . 'TAX1CAPTION'} = ACTINIC::EncodeText2(GetTaxName('TAX_1'));
$hVariables{$::VARPREFIX . 'TAX1'} = ACTINIC::EncodeText2($sTax1);
}
if ($nTax2 != 0)
{
if (PricesIncludeTaxes())
{
if ($nTax2 > 0)
{
$ACTINIC::B2B->SetXML("IncludingTax2Row", 1);
}
else
{
$ACTINIC::B2B->SetXML("ExemptedTax2Row", 1);
}
}
else
{
$ACTINIC::B2B->SetXML("Tax2Row", 1);
}
$hVariables{$::VARPREFIX . 'TAX2CAPTION'} = ACTINIC::EncodeText2(GetTaxName('TAX_2'));
$hVariables{$::VARPREFIX . 'TAX2'} = ACTINIC::EncodeText2($sTax2);
}
}
if ($::ReceiptPhase)
{
$ACTINIC::B2B->SetXML('DiscountInfo', "");
}
if ($ACTINIC::B2B->GetXML('DiscountInfo') ne "")
{
my @arrInfoLines = split /\n/, $ACTINIC::B2B->GetXML('DiscountInfo');
my $sLine;
my $sFinal;
foreach $sLine (@arrInfoLines)
{
if ($sLine)
{
$sFinal .= DiscountInfoLineHTML($sLine, $sDiscountInfoLineHTML);
}
}
$ACTINIC::B2B->SetXML("DiscountInfoLine", $sFinal);
}
if (!$::ReceiptPhase &&
$$::g_pSetupBlob{'ALSO_BOUGHT_ENABLED'})
{
my $pAlsoBought;
($Status, $Message, $pAlsoBought) = $pCartObject->GetRelatedList("ALSOBOUGHT");
my $sLine = "";
my $nIndex = 0;
foreach my $sABRef (@{$pAlsoBought})
{
$nIndex++;
$sLine .= AlsoBoughtItemLine($sABRef, $sAlsoBoughtLine);
if ($nIndex == $$::g_pSetupBlob{'ALSO_BOUGHT_NUMBER_OF_PRODS'})
{
last;
}
}
$ACTINIC::B2B->SetXML("AlsoBoughtLine", $sLine);
}
else
{
$ACTINIC::B2B->SetXML("AlsoBoughtLine", undef);
}
if (!$::ReceiptPhase &&
$$::g_pSetupBlob{'RELATED_PRODUCTS_ENABLED'})
{
my $pRelated;
($Status, $Message, $pRelated) = $pCartObject->GetRelatedList("RELATED");
my $sLine = "";
my $nIndex = 0;
foreach my $sABRef (@{$pRelated})
{
$nIndex++;
$sLine .= AlsoBoughtItemLine($sABRef, $sRelatedProductLine);
if ($nIndex == $$::g_pSetupBlob{'RELATED_PRODUCTS_NUMBER_OF_PRODS'})
{
last;
}
}
$ACTINIC::B2B->SetXML("RelatedProductLine", $sLine);
}
else
{
$ACTINIC::B2B->SetXML("RelatedProductLine", undef);
}
$sOrderLines = ACTINIC::ParseXMLCore(ACTINIC_PXML::GetTemplateFragment($pXML, "ShoppingCart"));
my $sLine;
($Status, $Message, $sLine) = ACTINIC::TemplateString($sOrderLines, \%hVariables);
if ($Status != $::SUCCESS)
{
return ($Status, $Message);
}
$ACTINIC::B2B->SetXML("ShoppingCart", $sLine);
return ($::SUCCESS, "", $sLine, 0);
}
sub EffectiveCartQuantity
{
my $pCartItem = shift;
my $pCartList = shift;
my $pCompare  = shift;
my $pCompareOpt = shift;
if( $ActinicOrder::VDSIMILARLINES == 0 )
{
return ($pCartItem->{QUANTITY});
}
my $nQuantity = 0;
foreach (@$pCartList)
{
if( &$pCompare($_,$pCartItem,$pCompareOpt) == $::TRUE )
{
$nQuantity += $_->{QUANTITY};
}
}
return ($nQuantity);
}
sub IdenticalCartLines
{
my $pCartItem1 = shift;
my $pCartItem2 = shift;
my $pOptions	= shift;
if( $pCartItem1->{QDQUALIFY} eq '1' and $pCartItem2->{QDQUALIFY} eq '1' )
{
foreach (keys %$pCartItem1, keys %$pCartItem2)
{
if( ($_ ne 'QUANTITY') &&
($_ ne 'SID')  &&
($_ !~ /^COMPONENT\_/)	&&
($pCartItem1->{$_} ne $pCartItem2->{$_} ))
{
return ($::FALSE);
}
}
}
else
{
foreach (keys %$pCartItem1, keys %$pCartItem2)
{
if( ($_ ne 'QUANTITY') &&
($_ ne 'SID') &&
($pCartItem1->{$_} ne $pCartItem2->{$_} ))
{
return ($::FALSE);
}
}
}
return ($::TRUE);
}
sub CalculateCartQuantities
{
if ($::s_bCartQuantityCalculated)
{
return($::SUCCESS, "", \%::s_ItemQuantities, \%::hAssCompQuantities);
}
%::s_ItemQuantities = {};
%::hAssCompQuantities = {};
my @Response;
@Response = $::Session->GetCartObject($::TRUE);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
my ($pOrderDetail, $pProduct);
foreach $pOrderDetail (@$pCartList)
{
my %CurrentItem = %$pOrderDetail;
my ($sSectionBlobName);
my ($Status, $Message);
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
next;
}
if ($Status == $::FAILURE)
{
return (@Response);
}
$::s_ItemQuantities{$CurrentItem{"PRODUCT_REFERENCE"}} += $CurrentItem{QUANTITY};
if( $pProduct->{COMPONENTS} )
{
my $VariantList = GetCartVariantList(\%CurrentItem);
my (%Component, $c);
my $nIndex = 1;
foreach $c (@{$pProduct->{COMPONENTS}})
{
@Response = FindComponent($c,$VariantList);
($Status, %Component) = @Response;
if ($Status != $::SUCCESS)
{
return ($Status,$Component{text});
}
if( $Component{quantity} > 0 )
{
my $nComponentQuantity = $CurrentItem{QUANTITY} * $Component{quantity};
if ($Component{code})
{
if (defined $::hAssCompQuantities{$Component{code}})
{
$::hAssCompQuantities{$Component{code}} += $nComponentQuantity;
}
else
{
$::hAssCompQuantities{$Component{code}} = $nComponentQuantity;
}
if ($c->[$::CBIDX_ASSOCPRODPRICE] == 1 ||
$Component{'AssociatedPrice'})
{
$::s_ItemQuantities{$Component{code}} += $nComponentQuantity;
}
else
{
$::s_ItemQuantities{$CurrentItem{"PRODUCT_REFERENCE"} . "_" . $nIndex} += $nComponentQuantity;
}
}
}
$nIndex++;
}
}
}
$::s_bCartQuantityCalculated = $::TRUE;
return($::SUCCESS, "", \%::s_ItemQuantities, \%::hAssCompQuantities)
}
sub CalculateSchPrice
{
my ($pProduct,$Quantity,$sDigest,$nIndex) = @_;
my $Price = $pProduct->{PRICE};
if( defined($Quantity) )
{
my @Response = CalculateCartQuantities();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($Response[2]{$pProduct->{"REFERENCE"}})
{
$Quantity = $Response[2]{$pProduct->{"REFERENCE"}};
}
my $SchPrice = GetSchedulePrices($pProduct,$sDigest);
if( $SchPrice )
{
if( defined($nIndex) )
{
$Price = $SchPrice->[$nIndex]->[1];
}
else
{
my $MaxFound = -1;
foreach (@{$SchPrice})
{
if( $_->[0] > $MaxFound and $Quantity >= $_->[0] )
{
$MaxFound = $_->[0];
$Price    = $_->[1];
}
}
}
}
}
return ($Price);
}
sub GetComponentPrice
{
my $pPrice = shift;
my $Quantity = shift;
my $CompQuantity = shift;
my $nSchedule = shift;
my $sReference = shift;
if ($Quantity == 0)
{
$Quantity = 1;
}
$Quantity *= $CompQuantity;
if (defined $sReference)
{
my @Response = CalculateCartQuantities();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($Response[2]{$sReference})
{
$Quantity = $Response[2]{$sReference};
}
}
if( ref($pPrice) ne 'HASH' )
{
if( ref($pPrice) eq 'ARRAY' )
{
return ($::SUCCESS, undef, $pPrice->[0] * $CompQuantity);
}
return ($::SUCCESS, undef, $pPrice * $CompQuantity);
}
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
my $nIndex = GetScheduleID($sDigest);
if( defined($nSchedule) )
{
$nIndex = $nSchedule;
}
my $SchPrice = $pPrice->{$nIndex};
my $Price;
my $MaxFound = -1;
foreach (@{$SchPrice})
{
if( $_->[0] > $MaxFound and $Quantity >= $_->[0] )
{
$MaxFound = $_->[0];
$Price    = $_->[1];
}
}
if( $MaxFound == -1 )
{
$SchPrice = $pPrice->{'1'};
foreach (@{$SchPrice})
{
if( $_->[0] > $MaxFound and $Quantity >= $_->[0] )
{
$MaxFound = $_->[0];
$Price    = $_->[1];
}
}
}
return ($::SUCCESS, undef, $Price * $CompQuantity);
}
sub GetScheduleID
{
my $sDigest = shift @_;
my $nScheduleID = $ActinicOrder::RETAILID;
if ($sDigest)
{
if(defined $::g_PaymentInfo{'SCHEDULE'} &&
$::g_PaymentInfo{'SCHEDULE'} >= $ActinicOrder::RETAILID)
{
$nScheduleID = $::g_PaymentInfo{'SCHEDULE'};
}
else
{
my ($Status, $sMessage, $pBuyer, $pAccount);
($Status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sDigest, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
($Status, $sMessage, $pAccount) = ACTINIC::GetCustomerAccount($$pBuyer{AccountID}, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
$nScheduleID = $pAccount->{PriceSchedule};
}
}
return($nScheduleID);
}
sub GetSchedulePrices
{
my ($pProduct,$sDigest) = @_;
my $nScheduleID = GetScheduleID($sDigest);
return ($pProduct->{PRICES}->{$nScheduleID});
}
sub ArrayAdd
{
my ($aLeft, $aRight) = @_;
my $nIndex;
for ($nIndex = 0; $nIndex <= ($#$aRight > $#$aLeft ? $#$aRight : $#$aLeft); $nIndex++)
{
$$aLeft[$nIndex] += $$aRight[$nIndex];
}
}
sub SummarizeOrder
{
no strict 'refs';
if ($#_ < 0)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'SummarizeOrder'), 0, 0);
}
my (@Response, @DefaultTaxResponse, $nStatus, $sMessage, $pCartObject, $pCartList, $bIgnoreAdvancedErrors);
($pCartList) = $_[0];
$bIgnoreAdvancedErrors = $::FALSE;
if ($#_ == 1)
{
$bIgnoreAdvancedErrors = $_[1];
}
ValidateTax($::FALSE);
ParseAdvancedTax();
($nStatus, $sMessage, $pCartObject) = $::Session->GetCartObject($::TRUE);
if ($nStatus != $::SUCCESS)
{
return ($nStatus, $sMessage);
}
@Response = $pCartObject->ProcessProductAdjustments();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($pOrderDetail, $nSubTotal, $nTax1, $nTax2, %CurrentItem, $pProduct, $rarrCurTaxBands, $rarrDefTaxBands);
$nSubTotal = 0;
my $nCartIndex = 0;
my (@nShipPrices, @sShipProducts, @nShipQuantities);
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
my ($nProductSubTotal, $nAdjustedProductSubTotal, $nSubTotalPlusShipHand, $nSubTotalPlusShipHandTax1, $nSubTotalPlusShipHandTax2);
my @aProductSubTotalTax;
my $nProductAdjustments;
my @aProductAdjustmentsTax;
my @aAdjustedProductSubTotalTax;
foreach $pOrderDetail (@$pCartList)
{
my $nPrice;
my $nProductPrice;
my @aProductTax;
($nStatus, $sMessage,
$nProductPrice, 	$nPrice,
$rarrCurTaxBands, $rarrDefTaxBands,
@aProductTax) = $pCartObject->GetCartItemPrice($pOrderDetail);
if ($nStatus == $::FAILURE)
{
return ($nStatus, $sMessage);
}
if ($nStatus == $::NOTFOUND)
{
next;
}
$nProductSubTotal				+= $nProductPrice;
ArrayAdd(\@aProductSubTotalTax, \@aProductTax);
($nStatus, $sMessage, $pProduct) = Cart::GetProduct($$pOrderDetail{"PRODUCT_REFERENCE"}, $$pOrderDetail{SID});
if ($nStatus != $::SUCCESS)
{
return ($nStatus, $sMessage);
}
my $parrProductAdjustments =
$pCartObject->GetProductAdjustments($nCartIndex);
@Response = CalculateProductAdjustments($parrProductAdjustments, $pProduct, 
$rarrCurTaxBands, $rarrDefTaxBands, 
$$pProduct{"PRICE"}, $nProductPrice, $aProductTax[0], $aProductTax[1], $pCartObject);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($nAdjustments, @aAdjustmentsTax) = @Response[2..10];
$nProductAdjustments += $nAdjustments;
ArrayAdd(\@aProductAdjustmentsTax, \@aAdjustmentsTax);
push (@sShipProducts, $CurrentItem{"PRODUCT_REFERENCE"});
push (@nShipQuantities, $CurrentItem{"QUANTITY"});
push (@nShipPrices, $nPrice);
$nCartIndex++;
}
$nAdjustedProductSubTotal = $nProductSubTotal + $nProductAdjustments;
ArrayAdd(\@aAdjustedProductSubTotalTax, \@aProductSubTotalTax);
ArrayAdd(\@aAdjustedProductSubTotalTax, \@aProductAdjustmentsTax);
my ($nProductTax1, $nProductTax2) = ($nTax1, $nTax2);
my @arrTotalsAndTaxes =
(
[$nProductSubTotal, @aProductSubTotalTax[0..3], TaxIsKnown(), @aProductSubTotalTax[4..7]],
[$nAdjustedProductSubTotal, @aAdjustedProductSubTotalTax[0..3], TaxIsKnown(), @aAdjustedProductSubTotalTax[4..7]],
);
my $parrAdjustments;
($nStatus, $sMessage, $parrAdjustments) = $pCartObject->ProcessOrderAdjustments(\@arrTotalsAndTaxes);
if ($nStatus != $::SUCCESS)
{
return ($nStatus, $sMessage);
}
@Response = CalculateOrderAdjustments($parrAdjustments,
$nProductSubTotal, $aProductSubTotalTax[4], $aProductSubTotalTax[5],
\@arrTotalsAndTaxes);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($nAdjustments, $nAdjustmentsTax1, $nAdjustmentsTax2,
$nUAdjustmentsTax1, $nUAdjustmentsTax2) = @Response[2..6];
my $nOrderAdjustedSubTotal = $nAdjustedProductSubTotal + $nAdjustments;
my $nOrderAdjustedSubTotalTax1 = $aAdjustedProductSubTotalTax[0] + $nAdjustmentsTax1;
my $nOrderAdjustedSubTotalTax2 = $aAdjustedProductSubTotalTax[1] + $nAdjustmentsTax2;
my $nUOrderAdjustedSubTotalTax1 = $aAdjustedProductSubTotalTax[4] + $nUAdjustmentsTax1;
my $nUOrderAdjustedSubTotalTax2 = $aAdjustedProductSubTotalTax[5] + $nUAdjustmentsTax2;
push @arrTotalsAndTaxes, [$nOrderAdjustedSubTotal, $nOrderAdjustedSubTotalTax1, $nOrderAdjustedSubTotalTax2, 0, 0, 0, , $nUOrderAdjustedSubTotalTax1, $nUOrderAdjustedSubTotalTax2];
my ($nShipping);
my $bTaxAppliesToShipping = $::FALSE;
if ($$::g_pSetupBlob{'MAKE_SHIPPING_CHARGE'})
{
my @Response = CallShippingPlugIn($pCartList, $nOrderAdjustedSubTotal);
$pCartObject->SetShippingPluginResponse(\@Response);
if ($Response[0] != $::SUCCESS ||
${$Response[2]}{CalculateShipping} != $::SUCCESS)
{
if ($bIgnoreAdvancedErrors)
{
$Response[6] = 0;
}
else
{
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
elsif (${$Response[2]}{CalculateShipping} != $::SUCCESS)
{
return (${$Response[2]}{CalculateShipping}, ${$Response[3]}{CalculateShipping});
}
}
}
$nShipping = $Response[6];
$bTaxAppliesToShipping = $Response[11];
}
else
{
$nShipping = 0;
}
my ($nShippingTax1, $nShippingTax2) = (0, 0);
my ($nUShippingTax1, $nUShippingTax2) = (0, 0);
if ($bTaxAppliesToShipping)
{
@Response = GetShippingTaxBands();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
@Response = CalculateTax($nShipping, 1, $Response[2], $Response[3], $nShipping,
$nOrderAdjustedSubTotal, $nUOrderAdjustedSubTotalTax1, $nUOrderAdjustedSubTotalTax2);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
($nShippingTax1, $nShippingTax2) = @Response[2,3];
($nUShippingTax1, $nUShippingTax2) = @Response[4,5];
}
$nTax1 = $nOrderAdjustedSubTotalTax1 + $nShippingTax1;
$nTax2 = $nOrderAdjustedSubTotalTax2 + $nShippingTax2;
my $nUTax1 = $nUOrderAdjustedSubTotalTax1 + $nUShippingTax1;
my $nUTax2 = $nUOrderAdjustedSubTotalTax2 + $nUShippingTax2;
my ($nHandling);
if ($$::g_pSetupBlob{'MAKE_HANDLING_CHARGE'})
{
my @Response = CallShippingPlugIn($pCartList, $nOrderAdjustedSubTotal);
$pCartObject->SetShippingPluginResponse(\@Response);
if ($Response[0] != $::SUCCESS ||
${$Response[2]}{CalculateHandling} != $::SUCCESS)
{
if ($bIgnoreAdvancedErrors)
{
$Response[8] = 0;
}
else
{
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
elsif (${$Response[2]}{CalculateHandling} != $::SUCCESS)
{
return (${$Response[2]}{CalculateHandling}, ${$Response[3]}{CalculateHandling});
}
}
}
$nHandling = $Response[8];
}
else
{
$nHandling = 0;
}
@Response = GetHandlingTaxBands();
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
@Response = CalculateTax($nHandling, 1,  $Response[2], $Response[3], $nHandling);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($nHandlingTax1, $nHandlingTax2) = @Response[2,3];
my ($nUHandlingTax1, $nUHandlingTax2) = @Response[4,5];
$nTax1 += $nHandlingTax1;
$nTax2 += $nHandlingTax2;
$nUTax1 += $nUHandlingTax1;
$nUTax2 += $nUHandlingTax2;
my $nOrderTotalPlusShipHand = $nOrderAdjustedSubTotal + $nShipping + $nHandling;
my $nOrderTotalPlusShipHandTax1 = $nTax1;
my $nOrderTotalPlusShipHandTax2 = $nTax2;
push @arrTotalsAndTaxes, [$nOrderTotalPlusShipHand,
$nOrderTotalPlusShipHandTax1, $nOrderTotalPlusShipHandTax2, 0, 0, 0,
$nUOrderAdjustedSubTotalTax1 + $nUHandlingTax1 + $nUShippingTax1,
$nUOrderAdjustedSubTotalTax2 + $nUHandlingTax2 + $nUShippingTax2];
($nStatus, $sMessage, $parrAdjustments) = $pCartObject->ProcessFinalAdjustments(\@arrTotalsAndTaxes);
if ($nStatus != $::SUCCESS)
{
return ($nStatus, $sMessage);
}
@Response = CalculateOrderAdjustments($parrAdjustments, $nOrderTotalPlusShipHand,
$nUOrderAdjustedSubTotalTax1 + $nUHandlingTax1 + $nUShippingTax1,
$nUOrderAdjustedSubTotalTax2 + $nUHandlingTax2 + $nUShippingTax2,
\@arrTotalsAndTaxes);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
($nAdjustments, $nAdjustmentsTax1, $nAdjustmentsTax2, $nUAdjustmentsTax1, $nUAdjustmentsTax2) = @Response[2..4];
$nOrderTotalPlusShipHand += $nAdjustments;
$nTax1 += $nAdjustmentsTax1;
$nTax2 += $nAdjustmentsTax2;
$nUTax1 += $nUAdjustmentsTax1;
$nUTax2 += $nUAdjustmentsTax2;
if ($nUTax1 != 0 &&
GetTaxRoundGroup('TAX_1') == $ActinicOrder::ROUNDPERORDER)
{
$nTax1 = RoundTax($nUTax1, GetTaxRoundRule('TAX_1'));
$nShippingTax1 = RoundTax($nUShippingTax1,
$ActinicOrder::SCIENTIFIC_NORMAL);
$nHandlingTax1 = RoundTax($nUHandlingTax1,
$ActinicOrder::SCIENTIFIC_NORMAL);
}
if ($nUTax2 != 0 &&
GetTaxRoundGroup('TAX_2') == $ActinicOrder::ROUNDPERORDER)
{
$nTax2 = RoundTax($nUTax2, GetTaxRoundRule('TAX_2'));
$nShippingTax2 = RoundTax($nUShippingTax2,
$ActinicOrder::SCIENTIFIC_NORMAL);
$nHandlingTax2 = RoundTax($nUHandlingTax2,
$ActinicOrder::SCIENTIFIC_NORMAL);
}
my $nTotal = $nOrderTotalPlusShipHand;
if ($::g_TaxInfo{'EXEMPT1'} ||
!IsTaxApplicableForLocation('TAX_1'))
{
if (PricesIncludeTaxes())
{
$nTax1 = -$nTax1;
$nShippingTax1 = -$nShippingTax1;
$nHandlingTax1 = -$nHandlingTax1;
$nTotal += $nTax1;
}
else
{
$nTax1 = 0;
$nShippingTax1 = 0;
$nHandlingTax1 = 0;
}
}
elsif (!PricesIncludeTaxes())
{
$nTotal += $nTax1;
}
if ($::g_TaxInfo{'EXEMPT2'} ||
!IsTaxApplicableForLocation('TAX_2'))
{
if (PricesIncludeTaxes())
{
$nTax2 = -$nTax2;
$nShippingTax2 = -$nShippingTax2;
$nHandlingTax2 = -$nHandlingTax2;
$nTotal += $nTax2;
}
else
{
$nTax2 = 0;
$nShippingTax2 = 0;
$nHandlingTax2 = 0;
}
}
elsif (!PricesIncludeTaxes())
{
$nTotal += $nTax2;
}
return ($::SUCCESS, "", $nAdjustedProductSubTotal, $nShipping, $nTax1, $nTax2, $nTotal, $nShippingTax1, $nShippingTax2,
$nHandling, $nHandlingTax1, $nHandlingTax2);
}
sub GetCartVariantList
{
my ($phashCart) = @_;
my ($plistVariants, $sKey);
$plistVariants = [];
foreach $sKey (keys %$phashCart)
{
if( $sKey =~ /^COMPONENT\_/ )
{
$plistVariants->[$'] = $phashCart->{$sKey};
}
}
return($plistVariants);
}
sub CalculateProductAdjustments
{
my ($parrAdjustments, $pProduct, $rarrProductTaxBands, $rarrDefProductTaxBands, $nProductRetailPrice, 
$nProductPrice, $nProductTax1, $nProductTax2, $robjCart) = @_;
my ($nAdjustments, $sTax1Band, $sTax2Band, $nRetailPrice);
my ($nAdjustmentsTax1, $nAdjustmentsTax2, $nAdjustmentsDefTax1, $nAdjustmentsDefTax2);
my ($nUAdjustmentsTax1, $nUAdjustmentsTax2, $nUAdjustmentsDefTax1, $nUAdjustmentsDefTax2);
my ($parrAdjustDetails, @arrResponse);
foreach $parrAdjustDetails (@$parrAdjustments)
{
$nAdjustments += $parrAdjustDetails->[$::eAdjIdxAmount];
my ($nStatus, $sMessage, $rarrCurrentTaxBands, $rarrDefaultTaxBands, $nRetailPrice) = 
$robjCart->GetAdjustmentTaxBands($pProduct, $parrAdjustDetails->[$::eAdjIdxCartIndex], 
$rarrProductTaxBands, $rarrDefProductTaxBands, $nProductRetailPrice);
if ($nStatus != $::SUCCESS)
{
return ($nStatus, $sMessage);
}
@arrResponse = CalculateTax($parrAdjustDetails->[$::eAdjIdxAmount], 1, 
$rarrCurrentTaxBands, $rarrDefaultTaxBands, $nRetailPrice, $nProductPrice, $nProductTax1, $nProductTax2);
my @arrDefResponse = CalculateDefaultTax($parrAdjustDetails->[$::eAdjIdxAmount], 1, 
$rarrCurrentTaxBands, $rarrDefaultTaxBands, $nRetailPrice, $nProductPrice, $nProductTax1, $nProductTax2);
if ($arrResponse[0] != $::SUCCESS)
{
return (@arrResponse);
}
my ($nAdjustmentTax1, 		$nAdjustmentTax2) 	= @arrResponse[2,3];
my ($nAdjustmentDefTax1, 	$nAdjustmentDefTax2) = @arrDefResponse[2,3];
my ($nUAdjustmentTax1, 		$nUAdjustmentTax2) 	= @arrResponse[4,5];
my ($nUAdjustmentDefTax1, 	$nUAdjustmentDefTax2) = @arrDefResponse[4,5];
my $rarrTemp;
foreach $rarrTemp (($rarrCurrentTaxBands, $rarrDefaultTaxBands))
{
$rarrTemp->[0] = 
ProductToOrderDetailTaxOpaqueData('TAX_1', $parrAdjustDetails->[$::eAdjIdxAmount], 
$rarrTemp->[0], $nRetailPrice);
$rarrTemp->[1] = 
ProductToOrderDetailTaxOpaqueData('TAX_2', $parrAdjustDetails->[$::eAdjIdxAmount], 
$rarrTemp->[1], $nRetailPrice);
}
SetAdjustmentTaxDetails($parrAdjustDetails, $nAdjustmentTax1, $nAdjustmentTax2, 
$rarrCurrentTaxBands, $rarrDefaultTaxBands);
$nAdjustmentsTax1 += $nAdjustmentTax1;
$nAdjustmentsTax2 += $nAdjustmentTax2;
$nAdjustmentsDefTax1 += $nAdjustmentDefTax1;
$nAdjustmentsDefTax2 += $nAdjustmentDefTax2;
$nUAdjustmentsTax1 += $nUAdjustmentTax1;
$nUAdjustmentsTax2 += $nUAdjustmentTax2;
$nUAdjustmentsDefTax1 += $nUAdjustmentDefTax1;
$nUAdjustmentsDefTax2 += $nUAdjustmentDefTax2;
}
return ($::SUCCESS, '', $nAdjustments,
$nAdjustmentsTax1, $nAdjustmentsTax2, $nAdjustmentsDefTax1, $nAdjustmentsDefTax2,
$nUAdjustmentsTax1, $nUAdjustmentsTax2, $nUAdjustmentsDefTax1, $nUAdjustmentsDefTax2);
}
sub GetComponentAssociatedProduct
{
my($pProduct, $sProdRef) = @_;
my($nStatus, $sMessage, $pComponent);
foreach $pComponent (@{$pProduct->{'COMPONENTS'}})
{
my $pPermutation;
foreach $pPermutation (@{$pComponent->[$::CBIDX_PERMUTATIONS]})
{
my $pAssocProd = $pPermutation->[$::PBIDX_ASSOCIATEDPROD];
if(ref($pAssocProd) eq 'HASH' &&
$pAssocProd->{'REFERENCE'} eq $sProdRef)
{
return($::SUCCESS, '', $pAssocProd);
}
}
}
return($::FALSE, "Unable to find associated product, '$sProdRef'");
}
sub CalculateOrderAdjustments
{
my ($parrAdjustments, $nTaxBase, $nTax1, $nTax2, $parrTotalsAndTaxes) = @_;
my ($nAdjustments, $nAdjustmentsTax1, $nAdjustmentsTax2);
my ($parrAdjustDetails, @arrResponse);
my $nCartTotal = $nTaxBase;
my ($nUAdjustmentsTax1, $nUAdjustmentsTax2);
my ($nUAdjustmentsTax1Sum, $nUAdjustmentsTax2Sum);
foreach $parrAdjustDetails (@$parrAdjustments)
{
$nTaxBase += $parrAdjustDetails->[$::eAdjIdxAmount];
$nAdjustments += $parrAdjustDetails->[$::eAdjIdxAmount];
my ($sTax1Band, $sTax2Band);
my ($nStatus, $sMessage, $pAssociatedProduct);
$pAssociatedProduct = undef;
$sTax1Band = '5=0=0=';
$sTax2Band = '5=0=0=';
my $nTotalsIndex = 0;
my $parrTotalAndTaxes = $parrTotalsAndTaxes->[0];
if($parrAdjustDetails->[$::eAdjIdxTaxTreatment] == $::eAdjTaxProRata)
{
$parrTotalAndTaxes = $parrTotalsAndTaxes->[0];
}
elsif($parrAdjustDetails->[$::eAdjIdxTaxTreatment] == $::eAdjTaxProRataAdjusted)
{
$parrTotalAndTaxes = $parrTotalsAndTaxes->[1];
}
elsif($parrAdjustDetails->[$::eAdjIdxTaxTreatment] == $::eAdjTaxProRataTotal)
{
$parrTotalAndTaxes = $parrTotalsAndTaxes->[3];
}
my ($nUAdjustmentsTax1, $nUAdjustmentsTax2);
if($parrAdjustDetails->[$::eAdjIdxAdjustmentBasis] == 1)
{
$nUAdjustmentsTax1 = $parrTotalAndTaxes->[8] * $parrAdjustDetails->[$::eAdjIdxAmount] / $parrTotalAndTaxes->[0];
$nUAdjustmentsTax2 = $parrTotalAndTaxes->[9] * $parrAdjustDetails->[$::eAdjIdxAmount] / $parrTotalAndTaxes->[0];
}
else
{
$nUAdjustmentsTax1 = $parrTotalAndTaxes->[6] * $parrAdjustDetails->[$::eAdjIdxAmount] / $parrTotalAndTaxes->[0];
$nUAdjustmentsTax2 = $parrTotalAndTaxes->[7] * $parrAdjustDetails->[$::eAdjIdxAmount] / $parrTotalAndTaxes->[0];
}
$nUAdjustmentsTax1Sum += $nUAdjustmentsTax1;
$nUAdjustmentsTax2Sum += $nUAdjustmentsTax2;
my $nTax1Diff = RoundScientific($nUAdjustmentsTax1);
my $nTax2Diff = RoundScientific($nUAdjustmentsTax2);
$nAdjustmentsTax1 += $nTax1Diff;
$nAdjustmentsTax2 += $nTax2Diff;
$sTax1Band = ProductToOrderDetailTaxOpaqueData('TAX_1',
$parrAdjustDetails->[$::eAdjIdxAmount],
$sTax1Band,
$parrAdjustDetails->[$::eAdjIdxAmount]);
$sTax2Band = ProductToOrderDetailTaxOpaqueData('TAX_2',
$parrAdjustDetails->[$::eAdjIdxAmount],
$sTax2Band,
$parrAdjustDetails->[$::eAdjIdxAmount]);
my @arrTaxOpaqueData = ($sTax1Band, $sTax2Band);
if(defined $pAssociatedProduct)
{
SetAdjustmentTaxDetails($parrAdjustDetails, $nTax1Diff, $nTax2Diff,  \@arrTaxOpaqueData,  \@arrTaxOpaqueData, $pAssociatedProduct);
}
else
{
SetAdjustmentTaxDetails($parrAdjustDetails, $nTax1Diff, $nTax2Diff, \@arrTaxOpaqueData,  \@arrTaxOpaqueData);
}
}
return ($::SUCCESS, '', $nAdjustments, $nAdjustmentsTax1, $nAdjustmentsTax2, $nUAdjustmentsTax1Sum, $nUAdjustmentsTax2Sum);
}
sub SetAdjustmentTaxDetails
{
my ($parrAdjustDetails, $nTax1, $nTax2, $rarrCurTaxOpaqueData, $rarrDefTaxOpaqueData) = @_;
$parrAdjustDetails->[$::eAdjIdxTax1]				= $nTax1;
$parrAdjustDetails->[$::eAdjIdxTax2]				= $nTax2;
$parrAdjustDetails->[$::eAdjIdxCurOpaqueData]	= $rarrCurTaxOpaqueData;
$parrAdjustDetails->[$::eAdjIdxDefOpaqueData]	= $rarrDefTaxOpaqueData;
}
sub SummarizeOrderPrintable
{
my ($Status, $Error, $nSubTotal, $nShipping, $nTax1, $nTax2, $nTotal, $nIgnore1, $nIgnore2, $nHandling, $nIgnore3, $nIgnore4) = @_;
my (@Response);
if ($Status != $::SUCCESS)
{
return (@_);
}
my ($sSubTotal, $sShipping, $sHandling, $sTax1, $sTax2, $sTotal);
@Response = FormatPrice($nSubTotal, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sSubTotal = $Response[2];
@Response = FormatPrice($nShipping, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sShipping = $Response[2];
@Response = FormatPrice($nHandling, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sHandling = $Response[2];
@Response = FormatPrice($nTax1, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sTax1 = $Response[2];
@Response = FormatPrice($nTax2, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sTax2 = $Response[2];
@Response = FormatPrice($nTotal, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sTotal = $Response[2];
if (! $$::g_pSetupBlob{'MAKE_SHIPPING_CHARGE'})
{
$sShipping = "";
}
if (! $$::g_pSetupBlob{'MAKE_HANDLING_CHARGE'})
{
$sHandling = "";
}
return ($::SUCCESS, "", $sSubTotal, $sShipping, $sHandling, $sTax1, $sTax2, $sTotal);
}
sub GetComponents
{
my $pProduct = shift;
my $pComponentHash = {COMPONENTS => {}, ATTRIBUTES => {}};
my $pComponentDefinition;
foreach $pComponentDefinition (@{$pProduct->{COMPONENTS}})
{
my $pComponent = {};
$pComponent->{NAME} 			= $pComponentDefinition->[$::CBIDX_NAME];
$pComponent->{ATTRIBUTES} 	= {};
my $bRealComponent = !($pComponent->{NAME} eq '');
my $pAttributeDefinition;
foreach $pAttributeDefinition (@{$pComponentDefinition->[$::CBIDX_ATTRIBUTELIST]})
{
my $sAttributeName 	= $pAttributeDefinition->[$::ABIDX_NAME];
my $nAttributeIndex 	= $pAttributeDefinition->[$::ABIDX_WIDGETIDX];
if ($sAttributeName eq '')
{
$pComponent->{IS_OPTIONAL} 	= $pComponentDefinition->[$::CBIDX_OPTIONAL];
$pComponent->{IS_COMPONENT} 	= $::TRUE;
$pComponent->{INDEX} 			= $nAttributeIndex; # a component's index is the index of its 'on' attribute
}
else
{
my $pAttribute = {};
$pAttribute->{INDEX}				= $nAttributeIndex;
$pAttribute->{NAME} 				= $sAttributeName;
$pAttribute->{IS_COMPONENT} 	= $::FALSE;
$pAttribute->{CHOICES} 			= [];
my $choice;
foreach $choice (@{$pAttributeDefinition->[$::ABIDX_CHOICES]})
{
push (@{$pAttribute->{CHOICES}}, $choice);
}
if ($bRealComponent)
{
$pComponent->{ATTRIBUTES}->{$sAttributeName} = $pAttribute;
}
else
{
$pComponentHash->{ATTRIBUTES}->{$sAttributeName} = $pAttribute;
}
}
}
if ($bRealComponent)
{
$pComponentHash->{COMPONENTS}->{$pComponent->{NAME}}= $pComponent;
}
}
return $pComponentHash;
}
sub FindComponent
{
my $component = shift;
my $selection = shift;
my $separator = shift || ',';
my %Res;
my @tmp;
my %hNames;
$Res{price} = 0,
$Res{code} = '';
$Res{quantity} = 0;
$Res{'COST_PRICE'} = 0;
$Res{'OPAQUE_SHIPPING_DATA'} = 0;
$Res{'ALT_WEIGHT'} = 0;
$Res{'SHIP_SEPARATELY'} = 0;
$Res{'SHIP_CATEGORY'} = 0;
$Res{'SHIP_SUPPLEMENT'} = 0;
$Res{'SHIP_SUPPLEMENT_ONCE'} = 0;
$Res{'HAND_SUPPLEMENT'} = 0;
$Res{'HAND_SUPPLEMENT_ONCE'} = 0;
$Res{'SHIP_QUANTITY'} = 0;
$Res{'EXCLUDE_FROM_SHIP'} = 0;
$Res{RetailPrice} = 0;
$Res{'AssociatedTax'} = 0;
$Res{'UseAssociatedPrice'} = 0;
$Res{'UseAssociatedShip'} = 0;
$Res{'SeparateLine'} = $component->[$::CBIDX_SEPARATELINE];
my $ComponentSwitch = -1;
my $pAttribute;
foreach $pAttribute (@{$component->[$::CBIDX_ATTRIBUTELIST]})
{
my $nWidgetIdx = $pAttribute->[$::ABIDX_WIDGETIDX];
my $sValue = $selection->[$nWidgetIdx];
if( $pAttribute->[$::ABIDX_NAME] eq '' )
{
$ComponentSwitch = $nWidgetIdx;
$hNames{COMPONENT} = {"NAME" 	=> $component->[$::CBIDX_NAME],
"INDEX"	=> $nWidgetIdx};
}
if( $sValue )
{
if ( $sValue =~ /^on/i )
{
if ( $pAttribute->[$::ABIDX_NAME] ne '' )
{
push @tmp, $selection->[$pAttribute->[$::ABIDX_NAME]];
}
$Res{text} .= $pAttribute->[$::ABIDX_NAME];
if( $pAttribute->[$::ABIDX_NAME] =~ /[^\ ]/ &&
$pAttribute->[$::ABIDX_CHOICES]->[$sValue-1] =~ /[^\ ]/ )
{
my $nIndex = $sValue - 1;
$Res{text} .= ': ' . $pAttribute->[$::ABIDX_CHOICES]->[$nIndex];
$hNames{$nWidgetIdx} = { 	"ATTRIBUTE"	=> $pAttribute->[$::ABIDX_NAME],
"CHOICE"		=> $pAttribute->[$::ABIDX_CHOICES]->[$nIndex],
"VALUE"		=> $nIndex + 1 };
}
elsif( $pAttribute->[$::ABIDX_NAME] =~ /[^\ ]/ )
{
$Res{text} .= ': ' . $pAttribute->[$::ABIDX_NAME];
}
$Res{text} .= $separator . ' ';
$Res{quantity} = $component->[$::CBIDX_QUANTITYUSED];
$Res{price} = $pAttribute->[$::ABIDX_CHOICES];
}
else
{
if( $component->[$::CBIDX_ASSOCPRODPRICE] != 1  )
{
if( $sValue < 1 )
{
return ($::SUCCESS, {});
}
if( $sValue - 1 > $#{$pAttribute->[$::ABIDX_CHOICES]} )
{
my %R;
$R{text} = ACTINIC::GetPhrase(-1, 2215);
return ($::FAILURE, %R);
}
if( $pAttribute->[$::ABIDX_NAME] ne '' )
{
push @tmp,$sValue;
}
my $nIndex = $sValue - 1;
$Res{text} .= $pAttribute->[$::ABIDX_NAME] . ': ' . $pAttribute->[$::ABIDX_CHOICES]->[$nIndex] . $separator . ' ';
$hNames{$nWidgetIdx} = { 	"ATTRIBUTE"	=> $pAttribute->[$::ABIDX_NAME],
"CHOICE"		=> $pAttribute->[$::ABIDX_CHOICES]->[$nIndex],
"VALUE"		=> $nIndex + 1};
$Res{quantity} = $component->[$::CBIDX_QUANTITYUSED];
}
else
{
$Res{text} .= $pAttribute->[$::ABIDX_NAME] . $separator . ' ';
$Res{quantity} = $component->[$::CBIDX_QUANTITYUSED];
$hNames{COMPONENT} = {"NAME" 	=> $pAttribute->[$::ABIDX_NAME],
"INDEX"	=> $ComponentSwitch};
}
}
}
else
{
return ($::SUCCESS, {});
}
}
if (!$Res{text})
{
%hNames = {};
}
$Res{Names} = \%hNames;
$Res{text} =~ s/[$separator\ ]*$//g;
if ($Res{text})
{
$Res{text} = ($component->[$::CBIDX_NAME] ? ($component->[$::CBIDX_NAME] . " - ") : "") . $Res{text};
}
else
{
$Res{text} = $component->[$::CBIDX_NAME];
}
if ($ComponentSwitch != -1  &&
$selection->[$ComponentSwitch] !~ /^on/i )
{
$Res{quantity} = 0;
}
if( $Res{quantity} == 0 )
{
return ($::SUCCESS,%Res);
}
my $range;
my $rindex;
my $pPriceHash;
foreach $range (@{$component->[$::CBIDX_PERMUTATIONS]})
{
my $bIsSpecific = $::FALSE;
my $nMatch = 0;
if ( $#{$range->[$::PBIDX_CHOICELIST]} != -1 )
{
for ( $rindex=0; $rindex<=$#tmp; $rindex++ )
{
if ( $range->[$::PBIDX_CHOICELIST]->[$rindex] > 0  &&
$range->[$::PBIDX_CHOICELIST]->[$rindex] == $tmp[$rindex] )
{
$bIsSpecific = $::TRUE;
$nMatch++;
}
elsif ( $range->[$::PBIDX_CHOICELIST]->[$rindex] == -1 )
{
$nMatch++;
}
}
}
if ( $nMatch < $#tmp + 1 )
{
next;
}
if ( !ref($range->[$::PBIDX_ASSOCIATEDPROD]) &&
$range->[$::PBIDX_ASSOCIATEDPROD] =~ /^[\-\+]$/ )
{
my %Prompts;
$Prompts{'-'} = 296;
$Prompts{'+'} = 297;
my ($Status, $sError, $sHTML) = ACTINIC::ReturnToLastPage(7, ACTINIC::GetPhrase(-1, 1962) . ACTINIC::GetPhrase(-1, $Prompts{$range->[$::PBIDX_ASSOCIATEDPROD]}, $component->[0]) . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2053),
ACTINIC::GetPhrase(-1, 208),
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, %::g_InputHash);
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sError, ACTINIC::GetPath());
}
ACTINIC::PrintPage($sHTML, undef, $::TRUE);
exit;
}
$Res{'UseAssociatedPrice'} = ($range->[$::PBIDX_PRICINGMODEL] == 1) ? $::TRUE : $::FALSE;
if (ref($range->[$::PBIDX_ASSOCIATEDPROD]) eq 'HASH' &&
$range->[$::PBIDX_ASSOCIATEDPROD]->{REFERENCE})
{
my $hashAssocProd = $range->[$::PBIDX_ASSOCIATEDPROD];
$Res{'OPAQUE_SHIPPING_DATA'} = $hashAssocProd->{OPAQUE_SHIPPING_DATA};
$Res{'ALT_WEIGHT'} = $hashAssocProd->{ALT_WEIGHT};
$Res{'SHIP_SEPARATELY'} = $hashAssocProd->{SHIP_SEPARATELY};
$Res{'SHIP_CATEGORY'} = $hashAssocProd->{SHIP_CATEGORY};
$Res{'SHIP_SUPPLEMENT'} = $hashAssocProd->{SHIP_SUPPLEMENT};
$Res{'SHIP_SUPPLEMENT_ONCE'} = $hashAssocProd->{SHIP_SUPPLEMENT_ONCE};
$Res{'HAND_SUPPLEMENT'} = $hashAssocProd->{HAND_SUPPLEMENT};
$Res{'HAND_SUPPLEMENT_ONCE'} = $hashAssocProd->{HAND_SUPPLEMENT_ONCE};
$Res{'SHIP_QUANTITY'} = $hashAssocProd->{SHIP_QUANTITY};
$Res{'EXCLUDE_FROM_SHIP'} = $hashAssocProd->{EXCLUDE_FROM_SHIP};
$Res{'COST_PRICE'} = $hashAssocProd->{COST_PRICE};
if ($component->[$::CBIDX_ASSOCPRODPRICE])
{
$Res{'RetailPrice'} = $hashAssocProd->{PRICE};
}
if ($component->[$::CBIDX_ASSOCIATEDNAME])
{
$Res{text} = $range->[$::PBIDX_ASSOCIATEDPROD]->{NAME};
}
if ($component->[$::CBIDX_ASSOCIATEDTAX])
{
$Res{AssociatedTax} = 1;
my $sKey;
foreach $sKey (keys %{$range->[$::PBIDX_ASSOCIATEDPROD]})
{
if ($sKey =~ /TAX_/)
{
$Res{$sKey} = $range->[$::PBIDX_ASSOCIATEDPROD]->{$sKey};
}
}
}
}
if ($component->[$::CBIDX_ASSOCIATEDSHIP])
{
$Res{'UseAssociatedShip'} = 1;
}
if ( $bIsSpecific )
{
if( ref($range->[$::PBIDX_ASSOCIATEDPROD]) eq 'HASH' )
{
$Res{code} = $range->[$::PBIDX_ASSOCIATEDPROD]->{REFERENCE};
if ($range->[$::PBIDX_ASSOCIATEDNAME])
{
$Res{text} = $range->[$::PBIDX_ASSOCIATEDPROD]->{NAME};
}
$Res{'UseAssociatedPrice'} = ($range->[$::PBIDX_PRICINGMODEL] == 1) ? $::TRUE : $::FALSE;
$Res{'AssociatedPrice'} = $range->[$::PBIDX_ASSOCIATEDPROD]->{PRICES};
$Res{'RetailPrice'} = $range->[$::PBIDX_ASSOCIATEDPROD]->{PRICE};
if ($range->[$::PBIDX_ASSOCIATEDTAX])
{
$Res{AssociatedTax} = 1;
$Res{'AssociatedPrice'} = $range->[$::PBIDX_ASSOCIATEDPROD]->{PRICES};
$Res{'RetailPrice'} = $range->[$::PBIDX_ASSOCIATEDPROD]->{PRICE};
my $sKey;
foreach $sKey (keys %{$range->[$::PBIDX_ASSOCIATEDPROD]})
{
if ($sKey =~ /TAX_/)
{
$Res{$sKey} = $range->[$::PBIDX_ASSOCIATEDPROD]->{$sKey};
}
}
}
if ($range->[$::PBIDX_ASSOCIATEDSHIP])
{
$Res{'UseAssociatedShip'} = 1;
}
if( $range->[$::PBIDX_PRICINGMODEL] == 1 )
{
$pPriceHash = $range->[$::PBIDX_ASSOCIATEDPROD]->{PRICES};
}
elsif( $range->[$::PBIDX_PRICINGMODEL] == 2 )
{
$pPriceHash = $range->[$::PBIDX_PRICE];
}
}
else
{
if ( $range->[$::PBIDX_ASSOCIATEDPROD] )
{
$Res{code}  = $range->[$::PBIDX_ASSOCIATEDPROD];
}
if( $range->[$::PBIDX_PRICE] )
{
$pPriceHash = $range->[$::PBIDX_PRICE];
}
}
}
}
RANGE:
foreach $range (@{$component->[$::CBIDX_PERMUTATIONS]})
{
if( $#{$range->[$::PBIDX_CHOICELIST]} != -1 )
{
for( $rindex=0; $rindex<=$#tmp; $rindex++ )
{
if ( $range->[$::PBIDX_CHOICELIST]->[$rindex] > 0 &&
$range->[$::PBIDX_CHOICELIST]->[$rindex] != $tmp[$rindex] )
{
next RANGE;
}
}
}
if ( !ref($range->[$::PBIDX_ASSOCIATEDPROD]) &&
$range->[$::PBIDX_ASSOCIATEDPROD] =~ /^[\-\+]$/ )
{
my %Prompts;
$Prompts{'-'} = 296;
$Prompts{'+'} = 297;
my ($Status, $sError, $sHTML) = ACTINIC::ReturnToLastPage(7,ACTINIC::GetPhrase(-1, 1962) . ACTINIC::GetPhrase(-1, $Prompts{$range->[$::PBIDX_ASSOCIATEDPROD]}, $component->[0]) . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2053),
ACTINIC::GetPhrase(-1, 208),
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, %::g_InputHash);
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sError, ACTINIC::GetPath());
}
ACTINIC::PrintPage($sHTML, undef, $::TRUE);
exit;
}
if (ref($range->[$::PBIDX_ASSOCIATEDPROD]) eq 'HASH' &&
$range->[$::PBIDX_ASSOCIATEDPROD]->{REFERENCE})
{
my $hashAssocProd = $range->[$::PBIDX_ASSOCIATEDPROD];
$Res{'OPAQUE_SHIPPING_DATA'} = $hashAssocProd->{OPAQUE_SHIPPING_DATA};
$Res{'ALT_WEIGHT'} = $hashAssocProd->{ALT_WEIGHT};
$Res{'SHIP_SEPARATELY'} = $hashAssocProd->{SHIP_SEPARATELY};
$Res{'SHIP_CATEGORY'} = $hashAssocProd->{SHIP_CATEGORY};
$Res{'SHIP_SUPPLEMENT'} = $hashAssocProd->{SHIP_SUPPLEMENT};
$Res{'SHIP_SUPPLEMENT_ONCE'} = $hashAssocProd->{SHIP_SUPPLEMENT_ONCE};
$Res{'HAND_SUPPLEMENT'} = $hashAssocProd->{HAND_SUPPLEMENT};
$Res{'HAND_SUPPLEMENT_ONCE'} = $hashAssocProd->{HAND_SUPPLEMENT_ONCE};
$Res{'SHIP_QUANTITY'} = $hashAssocProd->{SHIP_QUANTITY};
$Res{'EXCLUDE_FROM_SHIP'} = $hashAssocProd->{EXCLUDE_FROM_SHIP};
$Res{'COST_PRICE'} = $hashAssocProd->{COST_PRICE};
if ($range->[$::PBIDX_ASSOCIATEDNAME])
{
$Res{text} = $range->[$::PBIDX_ASSOCIATEDPROD]->{NAME};
}
if ($component->[$::CBIDX_ASSOCPRODPRICE])
{
$Res{'UseAssociatedPrice'} = 1;
$Res{'AssociatedPrice'} = $range->[$::PBIDX_ASSOCIATEDPROD]->{PRICES};
$Res{'RetailPrice'} = $range->[$::PBIDX_ASSOCIATEDPROD]->{PRICE};
}
$Res{AssociatedTax} = 0;
if ($range->[$::PBIDX_ASSOCIATEDTAX])
{
$Res{'AssociatedTax'} = 1;
$Res{'AssociatedPrice'} = $range->[$::PBIDX_ASSOCIATEDPROD]->{PRICES};
$Res{'RetailPrice'} = $range->[$::PBIDX_ASSOCIATEDPROD]->{PRICE};
my $sKey;
foreach $sKey (keys %{$range->[$::PBIDX_ASSOCIATEDPROD]})
{
if ($sKey =~ /TAX_/)
{
$Res{$sKey} = $range->[$::PBIDX_ASSOCIATEDPROD]->{$sKey};
}
}
}
$Res{'UseAssociatedShip'} = 0;
if ($range->[$::PBIDX_ASSOCIATEDSHIP])
{
$Res{'UseAssociatedShip'} = 1;
}
}
if( !$pPriceHash || (keys %$pPriceHash) <= 0)
{
if( ref($range->[$::PBIDX_ASSOCIATEDPROD]) eq 'HASH' )
{
$Res{code} = $range->[$::PBIDX_ASSOCIATEDPROD]->{REFERENCE};
if( $range->[$::PBIDX_PRICINGMODEL] == 1 )
{
$pPriceHash = $range->[$::PBIDX_ASSOCIATEDPROD]->{PRICES};
}
else
{
$pPriceHash = $range->[$::PBIDX_PRICE];
}
}
else
{
if( $range->[$::PBIDX_ASSOCIATEDPROD] )
{
$Res{code}  = $range->[$::PBIDX_ASSOCIATEDPROD]
}
if( $range->[$::PBIDX_PRICE] )
{
$pPriceHash = $range->[$::PBIDX_PRICE]
}
}
}
}
if( $pPriceHash && (keys %$pPriceHash) > 0 )
{
$Res{price} = $pPriceHash
}
return ($::SUCCESS, %Res);
}
sub WrapText
{
my $sText = shift;
my $nWidth = shift;
my $bPreserve = shift;
my $bAdapt = shift;
if( $nWidth <= 0 )
{
$bPreserve = 1;
$nWidth = 0;
$bAdapt = 1;
}
my $pResult;
my $nRealLength = 0;
$sText =~ tr/\ /\ /s;
my (@Lines) = split("\r\n",$sText);
WRAP:
foreach (@Lines)
{
my $nOffset = 0;
my $sLine = $_ . ' ';
my $nTotlen = length($sLine);
while ( $nOffset < $nTotlen )
{
my $nExtra = 0;
my $sExtra = "";
my $nLen = rindex(substr($sLine,$nOffset,$nWidth),' ');
if( $nLen<0 )
{
if( $bPreserve )
{
$nLen = index(substr($sLine,$nOffset),' ');
if( $bAdapt )
{
$pResult = [];
$nWidth = $nLen + 1;
goto WRAP;
}
}
else
{
$nLen = $nWidth - 1;
$nExtra = 1;
$sExtra = '-';
}
}
push @{$pResult},substr($sLine,$nOffset,$nLen) . $sExtra;
$nOffset += $nLen + 1;
$nRealLength = $nLen+$nExtra if $nLen+$nExtra > $nRealLength;
}
}
return ($pResult,$nRealLength);
}
sub GenerateCartCookie
{
my $sCookie =  "CART_TOTAL\t0\tCART_COUNT\t0\n";
my @Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
return ("CART_CONTENT=". ACTINIC::EncodeText2($sCookie,0));
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
my $nCount = $pCartObject->CountQuantities();
if ($nCount <= 0)
{
return ("CART_CONTENT=". ACTINIC::EncodeText2($sCookie,0));
}
@Response = $pCartObject->SummarizeOrder($::TRUE);
if ($Response[0] != $::SUCCESS)
{
return ("CART_CONTENT=". ACTINIC::EncodeText2($sCookie,0));
}
my $nTotal = $Response[6];
@Response = ActinicOrder::FormatPrice($nTotal, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return ("CART_CONTENT=". ACTINIC::EncodeText2($sCookie,0));
}
my $sTotal = $Response[2];
$sCookie =  "CART_TOTAL\t" . ACTINIC::EncodeText2($sTotal) . "\tCART_COUNT\t" . ACTINIC::EncodeText2($nCount) . "\n";
$sCookie = "CART_CONTENT=" . ACTINIC::EncodeText2($sCookie,0);
return($sCookie);
}
sub ProductToOrderDetailTaxOpaqueData
{
my ($sTaxID, $nUnitCost, $sTaxBand, $nRetailPrice) = @_;
my ($nTaxBandID, $nTaxRate, $nCustomRate, $sBandName) = split /=/, $sTaxBand;
my $nTaxID;
if (PricesIncludeTaxes())
{
$nTaxID = $ActinicOrder::g_pDefaultTaxZone->{$sTaxID};
if ($nTaxID == -1)
{
return('0=0=0==');
}
}
else
{
if(defined $$::g_pTaxSetupBlob{$sTaxID})
{
$nTaxID = $$::g_pTaxSetupBlob{$sTaxID}{ID};
}
else
{
return('0=0=0==');
}
}
if($nTaxBandID == $ActinicOrder::CUSTOM)
{
$sTaxBand = AdjustCustomTaxOpaqueData($nTaxID, $nUnitCost, $sTaxBand, $nRetailPrice);
}
if(defined $$::g_pTaxesBlob{$nTaxID})
{
$sBandName = $$::g_pTaxesBlob{$nTaxID}{'BANDS'}{$nTaxBandID}{'BAND_NAME'};
$sTaxBand .= "$sBandName=";
}
else
{
return('0=0=0==');
}
return($sTaxBand);
}
sub AdjustCustomTaxOpaqueData
{
my ($nTaxID, $nUnitCost, $sTaxBand, $nRetailPrice) = @_;
my ($nTaxBand, $nTaxRate, $nCustomRate, $sBandName) = split /=/, $sTaxBand;
my $sBandData;
if($nRetailPrice != 0)
{
$nTaxRate = ($nCustomRate / $nRetailPrice) * 100 * 100;
$nTaxRate = RoundTax($nTaxRate,
$$::g_pTaxesBlob{$nTaxID}{'ROUND_RULE'});
if($nUnitCost != $nRetailPrice)
{
$nCustomRate = $nUnitCost / $nRetailPrice * $nCustomRate;
$nCustomRate = RoundTax($nCustomRate, $$::g_pTaxesBlob{$nTaxID}{'ROUND_RULE'});
}
$sBandData = sprintf("%d=%d=%d=", $nTaxBand, $nTaxRate, $nCustomRate);
return($sBandData);
}
return('6=0=0=');
}
sub PrepareProductTaxOpaqueData
{
my($pProduct, $sPrice, $nCustomTaxBase, $bTreatCustomAsExempt, $nOverrideBandID) = @_;
my ($nTaxID, $sOpaqueData);
foreach $nTaxID (sort keys %$::g_pTaxesBlob)
{
my ($sTaxBand, $nTaxBandID, $nTaxRate, $nCustomRate, $sBandName);
if(defined $nOverrideBandID)
{
$nTaxBandID = $nOverrideBandID;
if($nTaxBandID == $ActinicOrder::PRORATA)
{
$sTaxBand = '5=0=0=';
}
elsif($nTaxBandID == $ActinicOrder::EXEMPT)
{
$sTaxBand = '1=0=0=';
}
elsif($nTaxBandID == $ActinicOrder::ZERO)
{
$sTaxBand = '0=0=0=';
}
}
else
{
$sTaxBand = $$pProduct{'TAX_' . $nTaxID};
($nTaxBandID, $nTaxRate, $nCustomRate, $sBandName) =
split /=/, $sTaxBand;
if($nTaxBandID == $ActinicOrder::CUSTOM)
{
if($bTreatCustomAsExempt)
{
$sTaxBand = '1=0=0=';
$nTaxBandID = $ActinicOrder::EXEMPT;
}
else
{
$sTaxBand = ActinicOrder::AdjustCustomTaxOpaqueData($nTaxID, $sPrice, $sTaxBand, $nCustomTaxBase);
}
}
}
if(defined $$::g_pTaxesBlob{$nTaxID})
{
$sBandName = $$::g_pTaxesBlob{$nTaxID}{'BANDS'}{$nTaxBandID}{'BAND_NAME'};
}
$sOpaqueData .= "$nTaxID\t$sTaxBand$sBandName=\n";
}
return($::SUCCESS, '', $sOpaqueData);
}
sub CalculateDefaultTax
{
if (!TaxIsKnown())
{
return(CalculateTax(@_));
}
my %SavedTaxInfo = %::g_TaxInfo;
%::g_TaxInfo = {};
my @Response = CalculateTax(@_);
%::g_TaxInfo = %SavedTaxInfo;
return @Response;
}
sub CalculateTaxExclusivePrice
{
my ($dUnitPrice, $rarrDefTaxBands, $bTax2AppliesTax1) = @_;
my $dTaxExclusivePrice = $dUnitPrice;
my $nTax;
if ($bTax2AppliesTax1)
{
for ($nTax = 1; $nTax >= 0; $nTax--)
{
my ($nBandID, $nPercent, $nFlatRate, $sBandName) = split /=/, $rarrDefTaxBands->[$nTax];
my $sTaxKey = 'TAX_' . ($nTax + 1);
if ($nBandID == $ActinicOrder::ZERO		||
$nBandID == $ActinicOrder::EXEMPT)
{
next;
}
if ($nBandID == $ActinicOrder::CUSTOM)
{
$dTaxExclusivePrice -= $nFlatRate;
}
else
{
$dTaxExclusivePrice = $ActinicOrder::PERCENTOFFSET / ($ActinicOrder::PERCENTOFFSET + $nPercent) * $dTaxExclusivePrice;
}
}
}
else
{
my $dTotalPercent = 0;
for $nTax(0 .. 1)
{
my ($nBandID, $nPercent, $nFlatRate, $sBandName) = split /=/, $rarrDefTaxBands->[$nTax];
if ($nBandID == $ActinicOrder::CUSTOM)
{
$dTaxExclusivePrice -= $nFlatRate;
}
else
{
$dTotalPercent += $nPercent;
}
}
$dTaxExclusivePrice = $ActinicOrder::PERCENTOFFSET / ($ActinicOrder::PERCENTOFFSET + $dTotalPercent) * $dUnitPrice;
}
return ($dTaxExclusivePrice);
}
sub GetTaxName
{
my ($sTaxKey) = @_;
my $phashTax = GetTaxHash($sTaxKey);
if (defined $phashTax)
{
return ($phashTax->{'NAME'});
}
return ('');
}
sub PricesIncludeTaxes
{
return ($::g_pTaxSetupBlob->{'TAX_INCLUSIVE_PRICING'});
}
sub TaxNeedsCalculating
{
my ($sTaxKey) = @_;
if (PricesIncludeTaxes())
{
return ($ActinicOrder::g_pDefaultTaxZone->{$sTaxKey} != -1);
}
return ($ActinicOrder::g_pCurrentTaxZone->{$sTaxKey} != -1);
}
sub IsTaxExemptionAllowed
{
my ($sTaxKey) = @_;
if (!TaxNeedsCalculating($sTaxKey))
{
return ($::FALSE);
}
return $ActinicOrder::g_pCurrentTaxZone->{sprintf('ALLOW_%s_EXEMPT', $sTaxKey)};
}
sub GetTaxHash
{
my ($sTaxKey) = @_;
my $nTaxID = $ActinicOrder::g_pCurrentTaxZone->{$sTaxKey};
if (PricesIncludeTaxes() || $nTaxID == undef)
{
$nTaxID = $ActinicOrder::g_pDefaultTaxZone->{$sTaxKey};
}
if ($nTaxID != -1)
{
return ($::g_pTaxesBlob->{$nTaxID});
}
return (undef);
}
sub GetTaxOpaqueData
{
my ($sTaxKey) = @_;
my $rhashZone = PricesIncludeTaxes() ?
$ActinicOrder::g_pDefaultTaxZone :
$ActinicOrder::g_pCurrentTaxZone;
my $rhashTax = GetTaxHash($sTaxKey);
if (!defined $rhashTax)
{
return ('');
}
my $sOpaqueData = $rhashTax->{'TAX_OPAQUE_DATA'};
my @arrFields = split(/=/, $sOpaqueData);
$arrFields[3] = $rhashZone->{'TAX_ON_TAX'} == 1 ? 1 : 0;
$sOpaqueData = join('=', @arrFields) . '=';
return ($sOpaqueData);
}
sub GetTaxRoundRule
{
my ($sTaxKey) = @_;
my $phashTax = GetTaxHash($sTaxKey);
if (defined $phashTax)
{
return ($phashTax->{'ROUND_RULE'});
}
return ($ActinicOrder::SCIENTIFIC_NORMAL);
}
sub GetTaxRoundGroup
{
my ($sTaxKey) = @_;
my $phashTax = GetTaxHash($sTaxKey);
if (defined $phashTax)
{
return ($phashTax->{'ROUND_GROUP'});
}
return ($ActinicOrder::ROUNDPERLINE);
}
sub CalculateTax
{
if ($#_ != 4 && $#_ != 7)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'CalculateTax'), 0, 0);
}
my ($nValue, @aProductTax, $nProductTotal, @aTaxes, $nTax);
my ($nUnitCost, $nQuantity, $rarrCurTaxBands, $rarrDefTaxBands, $nRetailPrice) = @_[0 .. 4];
if ($#_ == 7)
{
$nProductTotal = $_[5];
@aProductTax = @_[6,7];
}
my $nOrigUnitCost = $nUnitCost;
if (PricesIncludeTaxes())
{
$nUnitCost = CalculateTaxExclusivePrice($nUnitCost, $rarrDefTaxBands, $ActinicOrder::g_pDefaultTaxZone->{'TAX_ON_TAX'});
}
if ($nUnitCost == 0 || $nQuantity == 0)
{
return ($::SUCCESS, '', 0, 0);
}
my @arrTaxExempt = (0, 0);
my @arrTaxes = (0, 0);
foreach $nTax (0 .. 1)
{
my $sTaxKey = 'TAX_' . ($nTax + 1);
if (!TaxNeedsCalculating($sTaxKey))
{
next;
}
my $phashTax = GetTaxHash($sTaxKey);
my $sExemptKey = 'EXEMPT' . ($nTax + 1);
my $bLocationTaxable = IsTaxApplicableForLocation($sTaxKey);
my $pTaxZone = $ActinicOrder::g_pCurrentTaxZone;
if (!$bLocationTaxable ||
!$pTaxZone->{sprintf('ALLOW_%s_EXEMPT', $sTaxKey)})
{
$::g_TaxInfo{$sExemptKey} = 0;
}
my $bCustomerExempt = $::g_TaxInfo{$sExemptKey};
$arrTaxExempt[$nTax] = (!$bLocationTaxable) || $bCustomerExempt;
my $sTaxBand = @{$rarrCurTaxBands}->[$nTax];
if (PricesIncludeTaxes() && $arrTaxExempt[$nTax])
{
$sTaxBand = @{$rarrDefTaxBands}->[$nTax];
$pTaxZone = $ActinicOrder::m_pDefaultTaxZone;
}
my ($nBandID, $nPercent, $nFlatRate, $sBandName) = split /=/, $sTaxBand;
if ($nBandID == $ActinicOrder::ZERO		||
$nBandID == $ActinicOrder::EXEMPT	||
(!PricesIncludeTaxes() &&
$arrTaxExempt[$nTax]))
{
$arrTaxes[$nTax] = 0;
}
elsif ($nBandID == $ActinicOrder::PRORATA)
{
if ($nProductTotal == 0 ||
$aProductTax[$nTax] == 0)
{
$arrTaxes[$nTax] = 0;
$arrTaxes[$nTax + 2] = 0;
}
else
{
$arrTaxes[$nTax] = $nUnitCost * $aProductTax[$nTax] / $nProductTotal;
$arrTaxes[$nTax + 2] = $arrTaxes[$nTax];
if ($phashTax->{'ROUND_GROUP'} != $ActinicOrder::ROUNDPERORDER)
{
$arrTaxes[$nTax] = RoundTax($arrTaxes[$nTax],
$$::g_pTaxSetupBlob{$sTaxKey}{'ROUND_RULE'});
}
}
}
elsif ($nBandID == $ActinicOrder::CUSTOM)
{
if ($nRetailPrice == 0)
{
$arrTaxes[$nTax] = 0;
$arrTaxes[$nTax + 2] = 0;
}
elsif($nUnitCost == $nRetailPrice)
{
$arrTaxes[$nTax] = $nFlatRate * $nQuantity;
$arrTaxes[$nTax + 2] = $arrTaxes[$nTax];
}
else
{
my $dTax = $nFlatRate * ($nUnitCost / $nRetailPrice);
$arrTaxes[$nTax + 2] = $dTax  * $nQuantity;
if ($phashTax->{'ROUND_GROUP'} == $ActinicOrder::ROUNDPERITEM)
{
$arrTaxes[$nTax] = RoundTax($dTax,
$$::g_pTaxSetupBlob{$sTaxKey}{'ROUND_RULE'}) * $nQuantity;
}
elsif ($phashTax->{'ROUND_GROUP'} == $ActinicOrder::ROUNDPERLINE)
{
$arrTaxes[$nTax] = RoundTax($dTax * $nQuantity,
$$::g_pTaxSetupBlob{$sTaxKey}{'ROUND_RULE'});
}
else
{
$arrTaxes[$nTax] = $dTax * $nQuantity;
}
}
}
else
{
my $nBandRate = $nPercent;
my $nLowThreshold = $phashTax->{'LOW_THRESHOLD'};
my $nHighThreshold = $phashTax->{'HIGH_THRESHOLD'};
my $nUnRoundedValue;
if ($phashTax->{'ROUND_GROUP'} != $ActinicOrder::ROUNDPERITEM)
{
$nValue = $nUnitCost * $nQuantity;
}
else
{
$nValue = $nUnitCost;
}
$nUnRoundedValue = $nValue;
if ($pTaxZone->{'TAX_ON_TAX'})
{
my $i;
for ($i = $nTax - 1; $i >= 0; $i--)
{
if ($arrTaxExempt[$i] == 0)
{
if ($phashTax->{'ROUND_GROUP'} == $ActinicOrder::ROUNDPERITEM)
{
$nValue += $arrTaxes[$i] / $nQuantity;
$nUnRoundedValue += $arrTaxes[$i + 2] / $nQuantity;
}
else
{
$nValue += $arrTaxes[$i];
$nUnRoundedValue += $arrTaxes[$i + 2];
}
}
}
}
my $nNegativeMultiplier = ($nUnitCost < 0) ? -1 : 1;
$nUnitCost *= $nNegativeMultiplier;
if	($nBandRate > 0 &&
$nUnitCost > $nLowThreshold &&
($nHighThreshold == 0 || $nHighThreshold > $nUnitCost))# and it's less than the high threshold if specified
{
$arrTaxes[$nTax] = $nValue * $nBandRate / $ActinicOrder::PERCENTOFFSET;
$arrTaxes[$nTax + 2] = $nUnRoundedValue * $nBandRate / $ActinicOrder::PERCENTOFFSET;
$nUnitCost *= $nNegativeMultiplier;
if ($phashTax->{'ROUND_GROUP'} != $ActinicOrder::ROUNDPERORDER)
{
$arrTaxes[$nTax] = RoundTax($arrTaxes[$nTax],
$phashTax->{'ROUND_RULE'});
}
if ($phashTax->{'ROUND_GROUP'} == $ActinicOrder::ROUNDPERITEM)
{
$arrTaxes[$nTax] *= $nQuantity;
$arrTaxes[$nTax + 2] *= $nQuantity;
}
}
else
{
$arrTaxes[$nTax] = 0;
$arrTaxes[$nTax + 2] = 0;
}
}
}
return ($::SUCCESS, '', @arrTaxes);
}
sub RoundTax
{
my ($nValue, $eRule) = @_;
my $bNegative = $::FALSE;
if ($nValue < 0)
{
$bNegative = $::TRUE;
$nValue *= -1;
}
my $dAllowance = 1E-13;
if ($eRule == $ActinicOrder::TRUNCATION)
{
$nValue = int ($nValue + $dAllowance);
}
elsif ($eRule == $ActinicOrder::SCIENTIFIC_DOWN)
{
$nValue = int ($nValue + 0.5 - $dAllowance);
}
elsif ($eRule == $ActinicOrder::SCIENTIFIC_NORMAL)
{
$nValue = int ($nValue + 0.5 + $dAllowance);
}
elsif ($eRule == $ActinicOrder::CEILING)
{
$nValue = int ($nValue + 1 - $dAllowance);
}
elsif ($eRule == $ActinicOrder::BANKERS)
{
my $dDiff = $nValue - int($nValue + $dAllowance);
if ($dDiff == 0.5)
{
$nValue += int($nValue) % 2 == 1 ? 0 : -1;
}
$nValue = int($nValue + 0.5);
}
if ($bNegative)
{
$nValue *= -1;
}
return ($nValue);
}
sub RoundScientific
{
return(RoundTax(@_, $ActinicOrder::SCIENTIFIC_NORMAL));
}
sub FormatPrice
{
if ($#_ != 2)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'FormatPrice'), 0, 0);
}
my ($nPrice, $bSymbolPresent, $pCurrencyTable);
($nPrice, $bSymbolPresent, $pCurrencyTable) = @_;
my($nStatus, $sMessage, $sFormattedPrice) = FormatSinglePrice($nPrice, $bSymbolPresent, $pCurrencyTable);
my $sFormattedSinglePrice = $sFormattedPrice;
if($$::g_pSetupBlob{'PRICES_DISPLAYED'} && $$::g_pSetupBlob{'ALT_CURRENCY_PRICES'})
{
my ($sAltPricePrice, $nAltPricePrice, $sAltCurrencyIntlSymbol);
$sAltCurrencyIntlSymbol = $$::g_pSetupBlob{'ALT_CURRENCY_INTL_SYMBOL'};
$nAltPricePrice = $nPrice * $$pCurrencyTable{$sAltCurrencyIntlSymbol}{'EXCH_RATE'};
my $nAdjustment = 10 ** ($$pCurrencyTable{ICURRDIGITS} - $$pCurrencyTable{$sAltCurrencyIntlSymbol}{ICURRDIGITS});
$nAltPricePrice /= $nAdjustment;
$nAltPricePrice = RoundTax($nAltPricePrice, $ActinicOrder::SCIENTIFIC_NORMAL);
($nStatus, $sMessage, $sAltPricePrice) =
FormatSinglePrice($nAltPricePrice, $bSymbolPresent, $$pCurrencyTable{$sAltCurrencyIntlSymbol}, $::TRUE);
$sFormattedPrice = sprintf($$::g_pSetupBlob{'EURO_FORMAT'}, $sFormattedPrice, $sAltPricePrice);
}
return ($::SUCCESS, '', $sFormattedPrice, 0, $sFormattedSinglePrice);
}
sub FormatSinglePrice
{
if ($#_ != 2 && $#_ != 3)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'FormatSinglePrice'), 0, 0);
}
my ($nPrice, $bSymbolPresent, $pCurrencyTable, $bUseOtherCurrencySymbol) = @_;
my ($nNumDigits, $nGrouping, $sDecimal, $sThousand, $eNegOrder, $ePosOrder, $sCurSymbol);
$nNumDigits = $$pCurrencyTable{"ICURRDIGITS"};
$nGrouping = $$pCurrencyTable{"IMONGROUPING"};
$sDecimal = $$pCurrencyTable{"SMONDECIMALSEP"};
$sThousand = $$pCurrencyTable{"SMONTHOUSANDSEP"};
$eNegOrder = $$pCurrencyTable{"INEGCURR"};
$ePosOrder = $$pCurrencyTable{"ICURRENCY"};
if (defined $::USEINTLCURRENCYSYMBOL &&
$::USEINTLCURRENCYSYMBOL == $::TRUE)
{
$sCurSymbol = $$pCurrencyTable{"SINTLSYMBOLS"};
}
else
{
if ($#_ == 3 && $bUseOtherCurrencySymbol)
{
$sCurSymbol = $$pCurrencyTable{"ALT_CURRENCY_SYMBOL"};
}
else
{
$sCurSymbol = $$pCurrencyTable{"SCURRENCY"};
}
}
if (!$bSymbolPresent)
{
$sCurSymbol = '';
}
my ($dPrice, $nFraction, $nWholePart, $bNegative, $dRoundAdjustment);
$bNegative = ($nPrice < 0);
$nPrice = abs $nPrice;
$nPrice = int($nPrice + 0.5);
$dPrice = $nPrice / (10 ** $nNumDigits);
$nWholePart = int $dPrice;
$dRoundAdjustment = 10 ** (-1 * ($nNumDigits + 1));
$nFraction = int (($dPrice - $nWholePart + $dRoundAdjustment) * (10 ** $nNumDigits));
my ($nCount, @nWholeParts, $sPart, $nSafeOffset, $nSafeGroup);
if ($nGrouping != 0 && $nGrouping ne "")
{
for ($nCount = (length $nWholePart) - $nGrouping; $nCount > (-1 * $nGrouping); $nCount -= $nGrouping)
{
if ($nCount < 0)
{
$nSafeOffset = 0;
$nSafeGroup = $nGrouping + $nCount;
}
else
{
$nSafeOffset = $nCount;
$nSafeGroup = $nGrouping;
}
$sPart = substr ($nWholePart, $nSafeOffset, $nSafeGroup); # strip this group of digits (3 for US$)
push (@nWholeParts, $sPart);
}
}
my ($sFormattedPrice, $sFormat);
$sFormattedPrice = '';
while (scalar @nWholeParts > 0)
{
$sFormattedPrice .= (pop @nWholeParts) . $sThousand;
}
$sFormattedPrice = substr ($sFormattedPrice, 0,
(length $sFormattedPrice) - (length $sThousand));
if ($nNumDigits > 0)
{
$sFormat = '%s%s%' . $nNumDigits . "." . $nNumDigits . "d";
$sFormattedPrice = sprintf ($sFormat, $sFormattedPrice, $sDecimal, $nFraction);
}
if ($bNegative)
{
if ($eNegOrder == 0)
{
$sFormattedPrice = "(".$sCurSymbol.$sFormattedPrice.")";
}
elsif ($eNegOrder == 1)
{
$sFormattedPrice = "-".$sCurSymbol.$sFormattedPrice;
}
elsif ($eNegOrder == 2)
{
$sFormattedPrice = $sCurSymbol."-".$sFormattedPrice;
}
elsif ($eNegOrder == 3)
{
$sFormattedPrice = $sCurSymbol.$sFormattedPrice."-";
}
elsif ($eNegOrder == 4)
{
$sFormattedPrice = "(".$sFormattedPrice.$sCurSymbol.")";
}
elsif ($eNegOrder == 5)
{
$sFormattedPrice = "-".$sFormattedPrice.$sCurSymbol;
}
elsif ($eNegOrder == 6)
{
$sFormattedPrice = $sFormattedPrice."-".$sCurSymbol;
}
elsif ($eNegOrder == 7)
{
$sFormattedPrice = $sFormattedPrice.$sCurSymbol."-";
}
elsif ($eNegOrder == 8)
{
$sFormattedPrice = "-".$sFormattedPrice." ".$sCurSymbol;
}
elsif ($eNegOrder == 9)
{
$sFormattedPrice = "-".$sCurSymbol." ".$sFormattedPrice;
}
elsif ($eNegOrder == 10)
{
$sFormattedPrice = $sFormattedPrice." ".$sCurSymbol."-";
}
elsif ($eNegOrder == 11)
{
$sFormattedPrice = $sCurSymbol." ".$sFormattedPrice."-";
}
elsif ($eNegOrder == 12)
{
$sFormattedPrice = $sCurSymbol." -".$sFormattedPrice;
}
elsif ($eNegOrder == 13)
{
$sFormattedPrice = $sFormattedPrice."- ".$sCurSymbol;
}
elsif ($eNegOrder == 14)
{
$sFormattedPrice = "(".$sCurSymbol." ".$sFormattedPrice.")";
}
elsif ($eNegOrder == 15)
{
$sFormattedPrice = "(".$sFormattedPrice." ".$sCurSymbol.")";
}
}
else
{
if ($ePosOrder == 0)
{
$sFormattedPrice = $sCurSymbol.$sFormattedPrice;
}
elsif ($ePosOrder == 1)
{
$sFormattedPrice .= $sCurSymbol;
}
elsif ($ePosOrder == 2)
{
$sFormattedPrice = $sCurSymbol." ".$sFormattedPrice;
}
elsif ($ePosOrder == 3)
{
$sFormattedPrice .= " ".$sCurSymbol;
}
}
return ($::SUCCESS, '', $sFormattedPrice, 0);
}
sub FormatTaxRate
{
if ($#_ != 0)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'FormatTaxRate'), 0, 0);
}
my ($nRate) = @_;
my ($nIntegerRate, $nDecimalRate);
$nIntegerRate = $nRate / 100;
$nDecimalRate = (($nRate * 100) + 0.2) % 10000;
if ($nDecimalRate)
{
while (!($nDecimalRate % 10))
{
$nDecimalRate /= 10;
}
return (sprintf('%d.%d', $nIntegerRate, $nDecimalRate));
}
else
{
return('' . $nIntegerRate);
}
}
sub FormatCompletePrice
{
if (!defined $_[0] || !defined$_[1])
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'FormatCompletePrice'), 0, 0);
}
my ($sPriceTemplate, $nTaxExcPrice, $rarrCurTaxBands, $rarrDefTaxBands, $nRetailPrice, $nTax1, $nTax2, $rhValues) = @_;
my ($sLine, $Status, $Message, @Response);
$sLine = "";
if ($$::g_pSetupBlob{"PRICES_DISPLAYED"} &&
$nTaxExcPrice != 0)
{
my ($sPrice);
if (!defined $nTax1  || !defined $nTax2)
{
@Response = ActinicOrder::CalculateTax($nTaxExcPrice, 1, $rarrCurTaxBands, $rarrDefTaxBands, $nRetailPrice);
if($Response[0] != $::SUCCESS)
{
return (@Response);
}
$nTax1 = $Response[2];
$nTax2 = $Response[3];
}
my $nTaxIncPrice = $nTaxExcPrice + $nTax1 + $nTax2;
if (PricesIncludeTaxes())
{
$nTaxIncPrice = $nTaxExcPrice;
$nTaxExcPrice = $nTaxIncPrice - $nTax1 - $nTax2;
}
my @arrPrices = ($nTaxExcPrice, $nTaxIncPrice);
my @arrFormattedPrices = ('', '');
my $i;
foreach $i (0..1)
{
my @Response = ActinicOrder::FormatPrice($arrPrices[$i], $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
@Response = ACTINIC::EncodeText($Response[2], $::TRUE, $::TRUE);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$arrFormattedPrices[$i] = $Response[1];
}
my ($sTaxExcPrice, $sTaxIncPrice) = @arrFormattedPrices;
my ($sTaxMessage);
($Status, $Message, $sTaxMessage) = FormatTaxMessage($rarrCurTaxBands->[0], $rarrCurTaxBands->[1], $nTaxExcPrice, $nRetailPrice, $nTax1, $nTax2);
if ($Status != $::SUCCESS)
{
return ($Status, $Message);
}
@Response = ACTINIC::EncodeText($sTaxMessage);
($Status, $sTaxMessage) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
if ($nTaxIncPrice == $nTaxExcPrice)
{
$rhValues->{'TaxesApply'} = '';
}
$rhValues->{'TaxInclusivePrice'} = $sTaxIncPrice;
$rhValues->{'TaxExclusivePrice'} = $sTaxExcPrice;
$rhValues->{'TaxMessage'} = $sTaxMessage;
($Status, $Message, $sLine) = ACTINIC::ReplaceActinicVars($sPriceTemplate, $rhValues);
if ($Status != $::SUCCESS)
{
return ($Status, $Message);
}
}
return ($::SUCCESS, "", $sLine, 0);
}
sub GetPriceTemplate
{
if($ActinicOrder::sPriceTemplate ne '')
{
return($::SUCCESS, '', \$ActinicOrder::sPriceTemplate);
}
my $sFilename = ACTINIC::GetPath()."price.html";
unless (open (TFFILE, "<$sFilename"))
{
return($::FAILURE, ACTINIC::GetPhrase(-1, 21, $sFilename, $!), '', 0);
}
{
local $/;
$ActinicOrder::sPriceTemplate = <TFFILE>;
}
close (TFFILE);
return($::SUCCESS, '', \$ActinicOrder::sPriceTemplate);
}
sub FormatTaxMessage
{
my ($nTax1Band, $nTax2Band, $nPrice, $nRetailPrice, $nTax1, $nTax2) = @_;
my ($sTaxMessage, $sFormat, $nTax1BandID, $nTax2BandID, $sTax1, $sTax2, $nTaxRate, $nCustomTax1Rate, $nCustomTax2Rate);
my $bSeparateTax = ((defined $nTax1 && $nTax1 > 0) ||
(defined $nTax2 && $nTax2 > 0));
$sTaxMessage = "";
my $sTaxDescriptionFormat = ACTINIC::GetPhrase(-1, 229);
if (defined $$::g_pTaxSetupBlob{'TAX_1'})
{
($nTax1BandID, $nTaxRate, $nCustomTax1Rate) = split /=/, $nTax1Band;
if ($nTax1BandID == $ActinicOrder::CUSTOM &&
$nRetailPrice > 0)
{
my $nRate = ($nCustomTax1Rate / $nRetailPrice) * 100 * 100;
$nTaxRate = RoundTax($nRate,
$$::g_pTaxSetupBlob{TAX_1}{'ROUND_RULE'});
}
if ($bSeparateTax)
{
$sTax1 = $$::g_pTaxSetupBlob{'TAX_1'}{'NAME'};
}
elsif ($nTaxRate > 0)
{
$sTax1 = sprintf($sTaxDescriptionFormat,
$$::g_pTaxSetupBlob{'TAX_1'}{'NAME'},
ActinicOrder::FormatTaxRate($nTaxRate));
}
}
else
{
$sTax1 = '';
}
if (defined $$::g_pTaxSetupBlob{'TAX_2'})
{
($nTax2BandID, $nTaxRate, $nCustomTax2Rate) = split /=/, $nTax2Band;
if ($nTax2BandID == $ActinicOrder::CUSTOM &&
$nRetailPrice > 0)
{
my $nRate = ($nCustomTax2Rate / $nRetailPrice) * 100 * 100;
$nTaxRate = RoundTax($nRate,
$$::g_pTaxSetupBlob{TAX_2}{'ROUND_RULE'});
}
if ($bSeparateTax)
{
$sTax2 = $$::g_pTaxSetupBlob{'TAX_2'}{'NAME'};
}
elsif ($nTaxRate > 0)
{
$sTax2 = sprintf($sTaxDescriptionFormat,
$$::g_pTaxSetupBlob{'TAX_2'}{'NAME'},
ActinicOrder::FormatTaxRate($nTaxRate));
}
}
else
{
$sTax2 = '';
}
if ($::g_pSetupBlob->{TAX_INCLUSIVE_PRICES})
{
$sFormat = ACTINIC::GetPhrase(-1, 219);
}
else
{
$sFormat = ACTINIC::GetPhrase(-1, 67);
}
if ($sTax1 ne '' && IsTaxLevied($nTax1Band) &&
(!IsTaxLevied($nTax2Band) || $sTax2 eq ''))
{
$sTaxMessage = $sTax1;
}
elsif (($sTax1 eq '' || !IsTaxLevied($nTax1Band)) &&
$sTax2 ne '' && IsTaxLevied($nTax2Band))
{
$sTaxMessage = $sTax2;
}
elsif ($sTax1 ne '' && IsTaxLevied($nTax1Band) && $sTax2 ne '' && IsTaxLevied($nTax2Band))
{
$sTaxMessage = ACTINIC::GetPhrase(-1, 68, $sTax1, $sTax2);# '%s and %s'
}
return ($::SUCCESS, "", $sTaxMessage, 0);
}
sub HashToVarTable
{
my ($pHashID, $pHash, $pVarTable) = @_;
my ($sKey, $sValue);
while (($sKey, $sValue) = each(%$pHashID))
{
my $sTemp = '';
if ($sValue =~ /([^\|]+)\|(.*)\|(.*)/)
{
$sTemp = ACTINIC::GetPhrase($2, $3) . " " .$$pHash{$sKey};
$sValue = $1;
}
else
{
$sTemp = $$pHash{$sKey};
}
my @Response = ACTINIC::EncodeText($sTemp, $::TRUE, $::TRUE);
$sTemp = $Response[1] . "<BR>";
if ((length $$pHash{$sKey}) == 0)
{
$sTemp = "";
}
$$pVarTable{$::VARPREFIX . $sValue} = $sTemp;
}
return($::SUCCESS, '');
}
sub GetOrderTotal
{
my @Response = $::Session->GetCartObject();
if ($Response[0] != $::SUCCESS)
{
ACTINIC::RecordErrors("There s a problem determining the order total. Please contact Actinic.", ACTINIC::GetPath());
}
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
ActinicOrder::ParseAdvancedTax();
@Response = $pCartObject->SummarizeOrder($::FALSE);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::RecordErrors("There s a problem determining the order total. Please contact Actinic.", ACTINIC::GetPath());
}
my $nPrice = $Response[6];
$nPrice = int($nPrice + 0.5);
my $dPrice = $nPrice / (10 ** $$::g_pCatalogBlob{"ICURRDIGITS"});
return $dPrice;
}
sub IsTaxLevied
{
my($nTaxBand) = @_;
if($nTaxBand == $ActinicOrder::CUSTOM || $nTaxBand == $ActinicOrder::PRORATA)
{
return($::TRUE);
}
return($nTaxBand > $ActinicOrder::CUSTOM ? $::TRUE : $::FALSE);
}
sub GetTaxModelOpaqueData
{
if (PricesIncludeTaxes())
{
return($::SUCCESS, '', $$::g_pTaxSetupBlob{MODEL_OPAQUEDATA});
}
my @arrModel = split(/=/, $$::g_pTaxSetupBlob{MODEL_OPAQUEDATA});
my $nModelID = $arrModel[0];
my $nAddress = $arrModel[1];
my $sModelOpaqueData = sprintf('%d=%d=', $nModelID, $nAddress);
my ($nTax, $sTaxKey);
foreach $nTax(1..2)
{
$sTaxKey = 'TAX_' . $nTax;
if(defined $$::g_pTaxSetupBlob{$sTaxKey} &&
$$::g_pTaxSetupBlob{$sTaxKey}{SHIP_TAX_OPAQUE_DATA})
{
$sModelOpaqueData .= $$::g_pTaxSetupBlob{$sTaxKey}{SHIP_TAX_OPAQUE_DATA};
}
else
{
$sModelOpaqueData .= '0=0=0==';
}
}
foreach $nTax(1..2)
{
$sTaxKey = 'TAX_' . $nTax;
if(defined $$::g_pTaxSetupBlob{$sTaxKey} &&
$$::g_pTaxSetupBlob{$sTaxKey}{HAND_TAX_OPAQUE_DATA})
{
$sModelOpaqueData .= $$::g_pTaxSetupBlob{$sTaxKey}{HAND_TAX_OPAQUE_DATA};
}
else
{
$sModelOpaqueData .= '0=0=0==';
}
}
return($::SUCCESS, '', $sModelOpaqueData);
}
sub GetProductTaxBands
{
my ($pProductInfo) = @_;
my @arrTaxKeys = ('TAX_1', 'TAX_2', 'DEF_TAX_1_ID', 'DEF_TAX_2_ID');
my @arrTaxBands = ('0=0=0=', '0=0=0=', '0=0=0=', '0=0=0=');
my $nIndex = 0;
for ($nIndex = 0; $nIndex < scalar(@arrTaxKeys); $nIndex++)
{
my $sKey = $arrTaxKeys[$nIndex];
if (defined $$::g_pTaxSetupBlob{$sKey})
{
my $nTaxID = (ref($$::g_pTaxSetupBlob{$sKey}) eq 'HASH') ?
$$::g_pTaxSetupBlob{$sKey}{'ID'}:
$$::g_pTaxSetupBlob{$sKey};
my $sProductTaxKey = 'TAX_' . $nTaxID; 
if (defined $$pProductInfo{$sProductTaxKey})
{
$arrTaxBands[$nIndex] = $$pProductInfo{$sProductTaxKey};
}
else
{
}
}
}
my @arrCurTaxBandData = ($arrTaxBands[0], $arrTaxBands[1]);
my @arrDefTaxBandData = ($arrTaxBands[2], $arrTaxBands[3]);
return($::TRUE, '', \@arrCurTaxBandData, \@arrDefTaxBandData);
}
sub GetKeyedTaxBands
{
my ($sOpaqueDataKey) = @_;
my (@arrCurTaxOpaqueData, @arrDefTaxOpaqueData);
if (defined $$::g_pTaxSetupBlob{TAX_1})
{
$arrCurTaxOpaqueData[0] = $$::g_pTaxSetupBlob{TAX_1}{$sOpaqueDataKey};
}
if (defined $$::g_pTaxSetupBlob{DEF_TAX_1_ID})
{
$arrDefTaxOpaqueData[0] = $$::g_pTaxesBlob{$$::g_pTaxSetupBlob{DEF_TAX_1_ID}}{$sOpaqueDataKey};
}
if (defined $$::g_pTaxSetupBlob{TAX_2})
{
$arrCurTaxOpaqueData[1] = $$::g_pTaxSetupBlob{TAX_2}{$sOpaqueDataKey};
}
if (defined $$::g_pTaxSetupBlob{DEF_TAX_2_ID})
{
$arrDefTaxOpaqueData[1] = $$::g_pTaxesBlob{$$::g_pTaxSetupBlob{DEF_TAX_2_ID}}{$sOpaqueDataKey};
}
return (\@arrCurTaxOpaqueData, \@arrDefTaxOpaqueData);
}
sub GetShippingTaxBands
{
return ($::TRUE, '', GetKeyedTaxBands('SHIP_TAX_OPAQUE_DATA'));
}
sub GetHandlingTaxBands
{
return ($::TRUE, '', GetKeyedTaxBands('HAND_TAX_OPAQUE_DATA'));
}
sub GetProductPricesHTML
{
my ($pProduct, $plistVariants, $sSectionBlobName) = @_;
if (!defined $plistVariants &&
$pProduct->{COMPONENTS})
{
$plistVariants = ACTINIC::GetVariantList($pProduct->{REFERENCE});
}
my $sOnlinePriceLayout = ACTINIC::GetHierarchicalCustomVar($pProduct, 'OnlinePriceLayout', $sSectionBlobName);
my @Response = ACTINIC::ParseOnlinePriceTemplate($sOnlinePriceLayout);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $elemOnlinePrices = $Response[2];
my $elemRetailPrices = $Response[3];
my $elemCustomerPrices = $Response[4];
my $rhValues = {};
my ($bShowRetailPrices, $bShowCustomerPrices, $nAccountSchedule) = ACTINIC::DeterminePricesToShow();
if ($bShowRetailPrices && $bShowCustomerPrices)
{
my $sPriceLabel = ACTINIC::GetHierarchicalCustomVar($pProduct, 'RetailPricePrefix', $sSectionBlobName);
@Response = ActinicOrder::FormatSchedulePrices($pProduct, $ActinicOrder::RETAILID,
$plistVariants, $sPriceLabel, $::TRUE, $::TRUE, 
$elemRetailPrices->GetOriginal(), $elemRetailPrices->GetOriginal());
$rhValues->{'RetailPrices'} = $Response[2];
$sPriceLabel = ACTINIC::GetHierarchicalCustomVar($pProduct, 'YourPricePrefix', $sSectionBlobName);
@Response = FormatSchedulePrices($pProduct,
$nAccountSchedule, $plistVariants, $sPriceLabel, $::FALSE, $::TRUE, 
$elemCustomerPrices->GetOriginal(), $elemCustomerPrices->GetOriginal());
$rhValues->{'CustomerPrices'} = $Response[2];
return (ACTINIC::ReplaceActinicVars($elemOnlinePrices->GetOriginal(), $rhValues));
}
elsif ($bShowCustomerPrices)
{
if (0 == scalar(@{$pProduct->{'PRICES'}->{$nAccountSchedule}}))
{
return ($::SUCCESS, '', ACTINIC::GetPhrase(-1, 351));
}
else
{
my $sPriceLabel = ACTINIC::GetHierarchicalCustomVar($pProduct, 'YourPricePrefix', $sSectionBlobName);
$sPriceLabel =~ s/:$//;
@Response = FormatSchedulePrices($pProduct,
$nAccountSchedule, $plistVariants, $sPriceLabel, $::FALSE, $::TRUE, 
$elemCustomerPrices->GetOriginal(), $elemCustomerPrices->GetOriginal());
return @Response;
}
}
else
{
if (0 == scalar(@{$pProduct->{'PRICES'}->{$ActinicOrder::RETAILID}}))
{
return ($::SUCCESS, '',  ACTINIC::GetPhrase(-1, 351));
}
else
{
my $sPriceLabel = ACTINIC::GetHierarchicalCustomVar($pProduct, 'ProductPriceDescription', $sSectionBlobName);
@Response = FormatSchedulePrices($pProduct, $ActinicOrder::RETAILID,
$plistVariants, $sPriceLabel, $::FALSE, $::FALSE, $elemRetailPrices->GetOriginal(), $elemRetailPrices->GetOriginal());
return @Response;
}
}
}
sub FormatSchedulePrices
{
if (!defined $_[1])
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'FormatSchedulePrices'), 0, 0);
}
my ($pProduct, $nScheduleID, $rVariantList, $sLabel, $nSinglePrice, 
$bIgnoreComponentPrices, $sFirstPriceLineTemplate, $sOtherPriceLineTemplate) = @_;
my (@Response, $Status, $sLine, %PriceBreak, $pComponent);
my $ComponentPrice = 0;
my $ComponentRetailPrice = 0;
my %Component;
my ($nAlreadyTaxed, $nAlreadyTaxedRetail, $nTax1, $nTax2, $nTaxBase);
if (!defined $bIgnoreComponentPrices)
{
$bIgnoreComponentPrices = $::FALSE;
}
@Response = GetProductTaxBands($pProduct);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($rarrCurTaxBands, $rarrDefTaxBands) = @Response[2, 3];
foreach $pComponent (@{$pProduct->{COMPONENTS}})
{
@Response = ActinicOrder::FindComponent($pComponent, $$rVariantList);
($Status, %Component) = @Response;
if ($Status != $::SUCCESS)
{
return ($Status,$Component{text});
}
if( $Component{quantity} > 0 )
{
@Response = ActinicOrder::GetComponentPrice($Component{price}, $$pProduct{"MIN_QUANTITY_ORDERABLE"}, $Component{quantity}, $nScheduleID);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $nItemPrice = $Response[2];
if (!$nItemPrice)
{
$nItemPrice = $Component{'RetailPrice'}
}
@Response = GetComponentPrice($Component{price}, 1, $Component{quantity}, $ActinicOrder::RETAILID);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $nRetailPrice = $Response[2];
if (!$nRetailPrice)
{
$nRetailPrice = $Component{'RetailPrice'}
}
$ComponentPrice += $nItemPrice;
$ComponentRetailPrice += $nRetailPrice;
if ($Component{AssociatedTax})
{
$nAlreadyTaxed += $nItemPrice;
$nAlreadyTaxedRetail += $nRetailPrice;
if (defined $Component{'AssociatedPrice'})
{
@Response = GetComponentPrice($Component{'AssociatedPrice'}, $$pProduct{"MIN_QUANTITY_ORDERABLE"}, $Component{quantity}, $ActinicOrder::RETAILID);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$nRetailPrice = $Response[2];
}
@Response = GetProductTaxBands(\%Component);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($rarrCurCompTaxBands, $rarrDefCompTaxBands) = @Response[2, 3];
@Response = CalculateTax($nItemPrice, 1, $rarrCurCompTaxBands, $rarrDefCompTaxBands, $nRetailPrice);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$nTax1 += $Response[2];
$nTax2 += $Response[3];
}
elsif ($pComponent->[$::CBIDX_SEPARATELINE] &&
!$$pProduct{NO_ORDERLINE})
{
@Response = CalculateTax($nItemPrice, 1, $rarrCurTaxBands, $rarrDefTaxBands, $nRetailPrice);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$nTax1 += $Response[2];
$nTax2 += $Response[3];
$nAlreadyTaxed += $nItemPrice;
$nAlreadyTaxedRetail += $nRetailPrice;
}
my $nSchedulePrice;
if( ref($Component{price}) eq 'HASH' )
{
my $raPrices = \$Component{price}->{$nScheduleID};
foreach $nSchedulePrice (@$$raPrices)
{
$PriceBreak{int($$nSchedulePrice[0] / $Component{quantity} + 0.499999)} = defined $$nSchedulePrice[2] ?
int($$nSchedulePrice[2] / $Component{quantity}) : -1;
}
}
}
}
$sLine = '';
my ($sPrice, $raPrices, $raTemp, $nSchedulePrice, $nSchedulePriceCount);
if (defined $$pProduct{PRICES})
{
$raPrices = \$$pProduct{PRICES}->{$nScheduleID};
foreach $nSchedulePrice (@$$raPrices)
{
$PriceBreak{$$nSchedulePrice[0]} = defined $$nSchedulePrice[2] ? $$nSchedulePrice[2] : -1;
}
}
$nSchedulePriceCount = keys %PriceBreak;
my $nRetailPrice = $$pProduct{PRICE};
if ((!$nSinglePrice) && $nSchedulePriceCount > 1)
{
my ($nSchedulePrice, $index);
my $nIndex = 0;
my $nLimit;
my $nLastPrice;
foreach $nLimit (sort {$a <=> $b} (keys %PriceBreak))
{
$$raTemp->[$nIndex]->[0] = $nLimit;
$$raTemp->[$nIndex]->[2] = $PriceBreak{$nLimit};
my $nPrice;
my $MaxFound = -1;
foreach (@$$raPrices)
{
if( $_->[0] > $MaxFound and $nLimit >= $_->[0] )
{
$MaxFound = $_->[0];
$nPrice   = $_->[1];
}
}
my $nPriceModel = $$pProduct{PRICING_MODEL};
my ($nAlreadyTaxed, $nTax1, $nTax2, $nTaxBase);
if( $nPriceModel != $ActinicOrder::PRICING_MODEL_STANDARD )
{
$ComponentPrice = 0;
foreach $pComponent (@{$pProduct->{COMPONENTS}})
{
@Response = ActinicOrder::FindComponent($pComponent, $$rVariantList);
($Status, %Component) = @Response;
if ($Status != $::SUCCESS)
{
return ($Status,$Component{text});
}
if( $Component{quantity} > 0 )
{
@Response = ActinicOrder::GetComponentPrice($Component{price}, $nLimit, $Component{quantity}, $nScheduleID);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $nItemPrice = $Response[2];
@Response = GetComponentPrice($Component{price}, 1, $Component{quantity}, $ActinicOrder::RETAILID);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $nRetailPrice = $Response[2];
$ComponentPrice += $nItemPrice;
if ($Component{AssociatedTax})
{
if (defined $Component{'AssociatedPrice'})
{
@Response = GetComponentPrice($Component{'AssociatedPrice'}, $$pProduct{"MIN_QUANTITY_ORDERABLE"}, $Component{quantity}, $ActinicOrder::RETAILID);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$nRetailPrice = $Response[2];
}
@Response = GetProductTaxBands(\%Component);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
@Response = CalculateTax($nItemPrice, $Component{quantity}, $Response[2], $Response[3], $nRetailPrice);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$nTax1 += $Response[2];
$nTax2 += $Response[3];
$nAlreadyTaxed += $nItemPrice;
}
elsif ($pComponent->[$::CBIDX_SEPARATELINE] &&
!$$pProduct{NO_ORDERLINE})
{
@Response = CalculateTax($nItemPrice, $Component{quantity}, 
$rarrCurTaxBands, $rarrDefTaxBands, $nRetailPrice);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$nTax1 += $Response[2];
$nTax2 += $Response[3];
$nAlreadyTaxed += $nItemPrice;
}
}
}
if( $nPriceModel == $ActinicOrder::PRICING_MODEL_PROD_COMP )
{
$nPrice += $ComponentPrice;
$nTaxBase = $nPrice - $nAlreadyTaxed;
}
elsif( $nPriceModel == $ActinicOrder::PRICING_MODEL_COMP &&
!$bIgnoreComponentPrices)
{
$nPrice = $ComponentPrice;
$nTaxBase = $nPrice - $nAlreadyTaxed;
}
}
$$raTemp->[$nIndex]->[1] = $nPrice;
if ($nAlreadyTaxed > 0)
{
@Response = ActinicOrder::CalculateTax($nTaxBase, 1, $rarrCurTaxBands, $rarrDefTaxBands, $nTaxBase);
if($Response[0] != $::SUCCESS)
{
return (@Response);
}
$$raTemp->[$nIndex]->[3] = $nTax1 + $Response[2];
$$raTemp->[$nIndex]->[4] = $nTax2 + $Response[3];
}
if ($nPrice == $nLastPrice)
{
pop @$$raTemp;
}
else
{
$nIndex++;
$nLastPrice = $nPrice;
}
}
$raPrices = $raTemp;
@Response = GetQuantityLabels($raPrices);
my $rarrQtyLabels = $Response[2];
$nIndex = 0;
my $sPriceLines = "";
foreach (@$$raPrices)
{
my $rhValues = {};
$rhValues->{'PriceDescription'} = $sLabel;
$rhValues->{'QuantityDescription'} = $$rarrQtyLabels[$nIndex++];
if ($rhValues->{'QuantityDescription'} eq '')
{
$rhValues->{'QuantityApplies'} = '';
}
my $sPriceTemplate = ($nIndex == 0) ? $sFirstPriceLineTemplate : $sOtherPriceLineTemplate;
@Response = ActinicOrder::FormatCompletePrice($sPriceTemplate, $_->[1], 
$rarrCurTaxBands, $rarrDefTaxBands, $nRetailPrice, $_->[3], $_->[4], $rhValues);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sPriceLines .=  $Response[2];
}
$sLine = $sPriceLines;
}
else
{
if(defined $$raPrices->[0])
{
$sPrice = $$raPrices->[0]->[1];
}
else
{
$sPrice = $$pProduct{PRICE};
}
my $nRetailPrice = $$pProduct{PRICE};
my $nPriceModel = $$pProduct{PRICING_MODEL};
my $nRetailTaxBase = $nRetailPrice;
if( $nPriceModel == $ActinicOrder::PRICING_MODEL_PROD_COMP )
{
$sPrice += $ComponentPrice;
$nTaxBase = $sPrice - $nAlreadyTaxed;
$nRetailTaxBase = $nRetailPrice + $ComponentRetailPrice - $nAlreadyTaxedRetail;
}
elsif( $nPriceModel == $ActinicOrder::PRICING_MODEL_COMP &&
!$bIgnoreComponentPrices)
{
$sPrice = $ComponentPrice;
$nTaxBase = $sPrice - $nAlreadyTaxed;
$nRetailTaxBase = $nRetailPrice + $ComponentRetailPrice - $nAlreadyTaxedRetail;
}
if ($nAlreadyTaxed > 0 &&
$nTaxBase > 0)
{
@Response = ActinicOrder::CalculateTax($nTaxBase, 1, $rarrCurTaxBands, $rarrDefTaxBands, $nRetailTaxBase);
if($Response[0] != $::SUCCESS)
{
return (@Response);
}
$nTax1 += $Response[2];
$nTax2 += $Response[3];
}
my $rhValues = {};
$rhValues->{'PriceDescription'} = $sLabel;
$rhValues->{'QuantityApplies'} = '';
@Response = ActinicOrder::FormatCompletePrice($sFirstPriceLineTemplate, $sPrice, $rarrCurTaxBands, $rarrDefTaxBands, $nRetailPrice, $nTax1, $nTax2, $rhValues);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sLine = $Response[2];
}
return($::SUCCESS, '', $sLine);
}
sub GetQuantityLabels
{
my ($raPrices) = @_;
my ($nSchedulePriceCount, $nLastQty, $sQtyLabel, $nArrIndex, $nPromptID, @arrQtyLabels);
if (defined $$raPrices)
{
$nSchedulePriceCount = @$$raPrices;
}
else
{
push @arrQtyLabels, "";
return ($::SUCCESS, '', \@arrQtyLabels);
}
$nLastQty = -1;
for($nArrIndex = $nSchedulePriceCount - 1; $nArrIndex >= 0; $nArrIndex--)
{
if($nArrIndex == $nSchedulePriceCount - 1)
{
if(defined $$raPrices->[$nArrIndex]->[2] &&
$$raPrices->[$nArrIndex]->[2] > 0)
{
if($$raPrices->[$nArrIndex]->[0] == $$raPrices->[$nArrIndex]->[2])
{
$nPromptID = $$raPrices->[$nArrIndex]->[0] > 1 ?
286 : 287;
$arrQtyLabels[$nArrIndex] =
sprintf(ACTINIC::GetPhrase(-1, $nPromptID), $$raPrices->[$nArrIndex]->[0]);
}
else
{
$arrQtyLabels[$nArrIndex] =
sprintf(ACTINIC::GetPhrase(-1, 289),
$$raPrices->[$nArrIndex]->[0],
$$raPrices->[$nArrIndex]->[2]);
}
}
else
{
$arrQtyLabels[$nArrIndex] =
sprintf(ACTINIC::GetPhrase(-1, 288), $$raPrices->[$nArrIndex]->[0],
$$raPrices->[$nArrIndex]->[2]);
}
}
elsif($$raPrices->[$nArrIndex]->[0] == $nLastQty)
{
$nPromptID = $$raPrices->[$nArrIndex]->[0] > 1 ?
286 : 287;
$arrQtyLabels[$nArrIndex] =
sprintf(ACTINIC::GetPhrase(-1, $nPromptID), $$raPrices->[$nArrIndex]->[0]);
}
elsif ($nArrIndex == 0)
{
if($nLastQty > 1)
{
if ($$raPrices->[$nArrIndex]->[0] < 2)
{
$arrQtyLabels[$nArrIndex] = sprintf(ACTINIC::GetPhrase(-1, 290), $nLastQty);
}
else
{
$arrQtyLabels[$nArrIndex] = sprintf(ACTINIC::GetPhrase(-1, 289),
$$raPrices->[$nArrIndex]->[0], $nLastQty);
}
}
else
{
$arrQtyLabels[$nArrIndex] =
sprintf(ACTINIC::GetPhrase(-1, 287), $nLastQty);
}
}
else
{
$arrQtyLabels[$nArrIndex] =
sprintf(ACTINIC::GetPhrase(-1, 289), $$raPrices->[$nArrIndex]->[0], $nLastQty);
}
$nLastQty = $$raPrices->[$nArrIndex]->[0] - 1;
}
return ($::SUCCESS, '', \@arrQtyLabels);
}
sub ReadPrice
{
if ($#_ != 1)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'ReadPrice'), 0, 0);
}
my ($sPrice, $pCurrencyTable);
($sPrice, $pCurrencyTable) = @_;
my ($nNumDigits, $nGrouping, $sDecimal, $sThousand, $eNegOrder, $ePosOrder, $sCurSymbol);
$nNumDigits = $$pCurrencyTable{"ICURRDIGITS"};
$nGrouping = $$pCurrencyTable{"IMONGROUPING"};
$sDecimal = $$pCurrencyTable{"SMONDECIMALSEP"};
$sThousand = $$pCurrencyTable{"SMONTHOUSANDSEP"};
$eNegOrder = $$pCurrencyTable{"INEGCURR"};
$ePosOrder = $$pCurrencyTable{"ICURRENCY"};
$sCurSymbol = $$pCurrencyTable{"SCURRENCY"};
my ($bNegative);
$bNegative = ($sPrice =~ /-/ || $sPrice =~ /\(/ );
$sPrice =~ s/&#[0-9]{1,4};//g;
$sCurSymbol =~ s/([.\$\\])/\\$1/g;
$sPrice =~ s/$sCurSymbol//;
if ($sDecimal ne $sThousand)
{
$sThousand =~ s/([.\$\\])/\\$1/g;
$sPrice =~ s/$sThousand//g;
}
$sDecimal =~ s/([.\$\\])/\\$1/g;
if ($nNumDigits != 0)
{
$sPrice =~ s/$sDecimal/./g;
}
$sPrice =~ s/[^.0-9]//g;
$sPrice *= 10 ** $nNumDigits;
if ($bNegative)
{
$sPrice *= -1.0;
}
$sPrice = int ($sPrice + 0.5);
return ($::SUCCESS, '', $sPrice, 0);
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
sub GetGeneralUD3
{
if (ACTINIC::IsPromptHidden(4, 2))
{
return ($::Session->GetReferrer());
}
return ($::g_GeneralInfo{'USERDEFINED'});
}
sub CheckBuyerLimit
{
my ($sCartId, $sDestinationURL, $bClearFrame) = @_;
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
my $nLowerBound = $$::g_pSetupBlob{'MIN_ORDER_VALUE'};
my $nUpperBound = $$::g_pSetupBlob{'MAX_ORDER_VALUE'};
my $nBuyerLimit = 0;
my ($Status, $Message, $pBuyer);
if( $sDigest )
{
($Status, $Message, $pBuyer) = ACTINIC::GetBuyer($sDigest, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return ($Status, $Message, "");
}
if ($pBuyer->{LimitOrderValue})
{
$nBuyerLimit = $pBuyer->{MaximumOrderValue};
}
}
my ($pCartList, @EmptyArray);
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
my ($Ignore0, $Ignore1, $nSubTotal, $nShipping, $nTax1, $nTax2, $nTotal, $nShippingTax1, $nShippingTax2, $nHandling, $nHandlingTax1, $nHandlingTax2) = @Response;
my $sLimit;
my $nPromptID;
if ($nUpperBound > 0 &&
$nTotal > $nUpperBound)
{
@Response = ActinicOrder::FormatPrice($nUpperBound, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sLimit = $Response[2];
$nPromptID = 2349;
}
elsif ($nBuyerLimit > 0 &&
$nBuyerLimit < $nTotal)
{
@Response = ActinicOrder::FormatPrice($nBuyerLimit, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sLimit = $Response[2];
$nPromptID = 299;
}
elsif ($nLowerBound > 0 &&
$nTotal < $nLowerBound)
{
@Response = ActinicOrder::FormatPrice($nLowerBound, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sLimit = $Response[2];
$nPromptID = 2348;
}
if ($sLimit ne "")
{
my ($sLocalPage, $sHTML);
if( !$sDestinationURL )
{
$sDestinationURL = $::Session->GetLastShopPage();
}
if ($$::g_pSetupBlob{UNFRAMED_CHECKOUT} && # if the checkout is unframed,
$$::g_pSetupBlob{UNFRAMED_CHECKOUT_URL})
{
$sDestinationURL = $$::g_pSetupBlob{UNFRAMED_CHECKOUT_URL};
}
@Response = ActinicOrder::FormatPrice($nTotal, $::TRUE, $::g_pCatalogBlob);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $sTotal = $Response[2];
my $nDelay = 5;
if( !$bClearFrame )
{
$nDelay = 2;
}
my $bClear = ($bClearFrame && ACTINIC::IsCatalogFramed());
if ($$::g_pSetupBlob{UNFRAMED_CHECKOUT})
{
$bClear = (!$bClearFrame && ACTINIC::IsCatalogFramed());
}
else
{
$bClear = ($bClearFrame && ACTINIC::IsCatalogFramed() && $$::g_pSetupBlob{UNFRAMED_CHECKOUT});
}
@Response = ACTINIC::BounceToPageEnhanced($nDelay, ACTINIC::GetPhrase(-1, 1962) . ACTINIC::GetPhrase(-1, $nPromptID, $sTotal, $sLimit) . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2054),
$$::g_pSetupBlob{CHECKOUT_DESCRIPTION},
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $sDestinationURL, \%::g_InputHash,
$bClear);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
return ($::BADDATA, $sHTML);
}
return ($::SUCCESS,'');
}
sub IsTaxApplicableForLocation
{
my ($sTaxKey) = @_;
if (defined $$::g_pTaxSetupBlob{$sTaxKey})
{
return (defined $$::g_pTaxSetupBlob{$sTaxKey}{ID} ?
1 : 0);
}
return (0);
}
sub IsTaxPhaseApplicable
{
if (!defined $::g_pPhaseList)
{
return ($::FALSE);
}
my $sPhaseList = $$::g_pPhaseList{$::g_nCurrentSequenceNumber};
my (@Phases) = split (//, $sPhaseList);
my $nPhase;
foreach $nPhase (@Phases)
{
if ($nPhase == $::TAXCHARGEPHASE)
{
return ($::TRUE);
}
}
return ($::FALSE);
}
sub GetBuyerLocationSelections
{
my ($plistValidAddresses, $sCountryComboName, $sStateComboName, $sCountryComboID, $sStateComboID, $sPrefix, $nDefaultID) = @_;
my ($pAddress, $sCountrySelectHTML, $sStateSelectHTML, $nPhraseID);
my %hashRegionCode;
foreach $pAddress (@$plistValidAddresses)
{
if(!defined $hashRegionCode{$pAddress->{CountryCode}})
{
$hashRegionCode{$pAddress->{CountryCode}} = 1;
if ($pAddress->{CountryCode} eq $::g_LocationInfo{$sPrefix. '_COUNTRY_CODE'} ||
((!defined $::g_LocationInfo{$sPrefix. '_COUNTRY_CODE'} ||
$::g_LocationInfo{$sPrefix. '_COUNTRY_CODE'} eq "") &&
$pAddress->{ID} == $nDefaultID))
{
$nPhraseID = 1219;
}
else
{
$nPhraseID = 1220;
}
$sCountrySelectHTML .= sprintf(ACTINIC::GetPhrase(-1, $nPhraseID),
$pAddress->{CountryCode}, ACTINIC::GetCountryName($pAddress->{CountryCode}));
}
if($pAddress->{StateCode} ne '')
{
if(!defined $hashRegionCode{$pAddress->{StateCode}})
{
$hashRegionCode{$pAddress->{StateCode}} = 1;
if ($pAddress->{StateCode} eq $::g_LocationInfo{$sPrefix. '_REGION_CODE'} ||
((!defined $::g_LocationInfo{$sPrefix. '_REGION_CODE'} ||
$::g_LocationInfo{$sPrefix. '_REGION_CODE'} eq "")&&
$pAddress->{ID} == $nDefaultID))
{
$nPhraseID = 1219;
}
else
{
$nPhraseID = 1220;
}
$sStateSelectHTML .= sprintf(ACTINIC::GetPhrase(-1, $nPhraseID),
$pAddress->{StateCode}, ACTINIC::GetCountryName($pAddress->{StateCode}));
}
}
}
if($sCountrySelectHTML ne '')
{
$sCountrySelectHTML = sprintf(ACTINIC::GetPhrase(-1, 1204),
$sCountryComboID, $sCountryComboName) .
sprintf(ACTINIC::GetPhrase(-1, 1220), $ActinicOrder::UNDEFINED_REGION, ACTINIC::GetPhrase(-1, 193)) .
$sCountrySelectHTML . ACTINIC::GetPhrase(-1, 1205);
}
if($sStateSelectHTML ne '')
{
$sStateSelectHTML = sprintf(ACTINIC::GetPhrase(-1, 1204),
$sStateComboID, $sStateComboName) .
sprintf(ACTINIC::GetPhrase(-1, 1220), $ActinicOrder::UNDEFINED_REGION, ACTINIC::GetPhrase(-1, 194)) .
$sStateSelectHTML . ACTINIC::GetPhrase(-1, 1205);
}
return($::SUCCESS, '', $sCountrySelectHTML, $sStateSelectHTML);
}
sub ValidateOrderDetails
{
my ($pOrderDetails) = shift;
my $nIndex;
my %hFailures;
if (defined $_[0])
{
$nIndex = $_[0];
}
else
{
$nIndex = -1;
}
my ($bInfoExists, $bDateExists, $key, $value, $sMessage, %Values);
$bInfoExists = $::FALSE;
$bDateExists = $::FALSE;
$sMessage = "";
my ($pProduct);
my $ProductRef = $$pOrderDetails{"PRODUCT_REFERENCE"};
my ($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($$pOrderDetails{SID});
if ($Status == $::FAILURE)
{
return ($Status, $Message);
}
my @Response = ACTINIC::GetProduct($ProductRef, $sSectionBlobName, ACTINIC::GetPath());
($Status, $Message, $pProduct) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
$bInfoExists = (length $$pProduct{"OTHER_INFO_PROMPT"} != 0); # see if the info field exists.
$bDateExists = (length $$pProduct{"DATE_PROMPT"} != 0);
my ($sInfo);
if ($bInfoExists)
{
@Response = InfoValidate($ProductRef , $$pOrderDetails{"INFOINPUT"}, $$pProduct{"OTHER_INFO_PROMPT"});
if ($Response[0] != $::SUCCESS)
{
$sMessage .= $Response[1];
$hFailures{"INFOINPUT"} = 1;
$hFailures{"BAD_INFOINPUT"} = $$pOrderDetails{"INFOINPUT"};
}
}
my ($nDay, $nMonth, $nYear, $bBad);
$bBad = $::FALSE;
if ($bDateExists)
{
$nDay = substr($$pOrderDetails{"DATE"}, 8, 2);
$nMonth = substr($$pOrderDetails{"DATE"}, 5, 2);
$nYear = substr($$pOrderDetails{"DATE"}, 0, 4);
if ( ($nMonth == 4 ||
$nMonth == 6 ||
$nMonth == 6 ||
$nMonth == 11)  &&
$nDay > 30)
{
$bBad = $::TRUE;
}
elsif ($nMonth == 2)
{
if ($nDay > 29)
{
$bBad = $::TRUE;
}
elsif ($nDay == 29)
{
if ($nYear % 400 == 0)
{
}
elsif ($nYear % 100 == 0)
{
$bBad = $::TRUE;
}
elsif ($nYear % 4 == 0)
{
}
else
{
$bBad = $::TRUE;
}
}
}
my $sPrompt = $$pProduct{"DATE_PROMPT"};
if (length $nDay == 0 ||
length $nMonth == 0 ||
length $nYear == 0)
{
$sMessage .= ACTINIC::GetPhrase(-1, 57, "<B>$sPrompt</B>") . "<P>\n";
$hFailures{"DATE"} = 1;
$hFailures{"BAD_DATE"} = $$pOrderDetails{"DATE"};
}
elsif ($bBad)
{
$sMessage .= ACTINIC::GetPhrase(-1, 58, "<B>$sPrompt</B>") . "<P>\n";
$hFailures{"DATE"} = 1;
$hFailures{"BAD_DATE"} = $$pOrderDetails{"DATE"};
}
}
my ($nQuantity, $nMaxQuantity, $nMinQuantity, $nOrderedQuantity);
$nMinQuantity = $$pProduct{"MIN_QUANTITY_ORDERABLE"}; # get the min quantity count.  this is maintained on a per
($Status, $Message, $nMaxQuantity) = GetMaxRemains($ProductRef, $sSectionBlobName, $nIndex);
if ($Status != $::SUCCESS)
{
return($Status, $Message, 0, 0);
}
my ($pProductQuantities, $hAssCompQuantities);
($Status, $Message, $pProductQuantities, $hAssCompQuantities) = CalculateCartQuantities();
$nQuantity = $$pOrderDetails{"QUANTITY"};
$nOrderedQuantity = $$pProductQuantities{$$pOrderDetails{"PRODUCT_REFERENCE"}};
my ($nFailure, $nBadQuantity, $sCheckMessage) = CheckProductQuantity($pProduct, $nQuantity, $nOrderedQuantity, $nMaxQuantity, $nIndex);
if ($nFailure == 1)
{
$sMessage .= $sCheckMessage;
$hFailures{"QUANTITY"} = 1;
$hFailures{"BAD_QUANTITY"} = $nBadQuantity;
}
if( $pProduct->{COMPONENTS} )
{
my ($CompProduct, $c, $nCompInd, $nCompQuantity);
my $VariantList = GetCartVariantList($pOrderDetails);
foreach $nCompInd (0 .. $#{$pProduct->{COMPONENTS}})
{
my %hComponent;
$c = ${$pProduct->{COMPONENTS}}[$nCompInd];
($Status, %hComponent) = FindComponent($c, $VariantList);
if ($Status != $::SUCCESS)
{
return ($Status, $hComponent{text});
}
($Status, $Message, $CompProduct) = GetComponentAssociatedProduct($pProduct, $hComponent{code});
if ($Status == $::SUCCESS)
{
if ($hComponent{'quantity'}  < 1)
{
next;
}
$nCompQuantity = $nQuantity * $hComponent{'quantity'};
$nOrderedQuantity = $hAssCompQuantities->{$$CompProduct{'REFERENCE'}};
my ($nMaxCompQuantity) = $$CompProduct{'MAX_QUANTITY_ORDERABLE'};
if ($nMaxCompQuantity  == 0)
{
$nMaxCompQuantity = $::MAX_ORD_QTY;
}
$nMaxQuantity = $nMaxCompQuantity - (($nIndex != -2) ? $nOrderedQuantity : 0);
if ($nMaxQuantity < 0)
{
$nMaxQuantity = 0;
}
elsif ($nIndex > -1)
{
$nMaxQuantity += $nCompQuantity;
}
$nFailure = 0;
if ($nFailure == 1)
{
$sMessage .= $hComponent{text} . ' ' . $sCheckMessage;
$hFailures{"QUANTITY"} = 1;
$hFailures{"BAD_QUANTITY"} = $nQuantity;
}
}
}
}
if ($$::g_pSetupBlob{'TAX_AND_SHIP_EARLY'} &&
$nIndex == -1)
{
my ($nStatus, $sError, $pCartObject) = $::Session->GetCartObject();
if($nStatus == $::SUCCESS)
{
$pCartObject->AddItem($pOrderDetails);
my $pCartList = $pCartObject->GetCartList();
my $nLastItemIdx = $#$pCartList;
$sMessage .= ActinicOrder::ValidatePreliminaryInfo($::TRUE);
$pCartObject->RemoveItem($nLastItemIdx);
}
}
if (length $sMessage > 0 &&
$nIndex > -1)
{
$sMessage = "<B>" . $$pProduct{"NAME"} . ":</B><BR><BLOCKQOUTE>" . $sMessage . "</BLOCKQOUTE>";
}
return (length $sMessage == 0 ? $::SUCCESS : $::BADDATA, $sMessage, \%hFailures, 0);
}
sub CheckProductQuantity
{
my ($pProduct, $nQuantity, $nOrderedQuantity, $nMinQuantity, $nMaxQuantity, $nIndex, $sMessage, $bAssocProd);
($pProduct, $nQuantity, $nOrderedQuantity, $nMaxQuantity, $nIndex) = @_;
my $nFailure = 0;
my $nBadQuantity = 0;
if ($nIndex > -1)
{
$nOrderedQuantity -= $nQuantity;
}
if ($nOrderedQuantity < $$pProduct{"MIN_QUANTITY_ORDERABLE"})
{
$nMinQuantity = $$pProduct{"MIN_QUANTITY_ORDERABLE"} - $nOrderedQuantity;
}
else
{
$nMinQuantity = 1;
}
if ($nMaxQuantity == 0)
{
$sMessage .= ACTINIC::GetPhrase(-1, 59) . "<P>\n";
$nFailure = 1;
$nBadQuantity = $nQuantity;
}
elsif ($nQuantity =~ /\D/ ||
$nQuantity < $nMinQuantity  ||
$nQuantity > $nMaxQuantity)
{
if ($nMaxQuantity > 1)
{
$sMessage .= ACTINIC::GetPhrase(-1, 60, $nMinQuantity, $nMaxQuantity) . "<P>\n";
$nFailure = 1;
$nBadQuantity = $nQuantity;
}
elsif ($nMaxQuantity == 1)
{
$sMessage .= ACTINIC::GetPhrase(-1, 61) . "<P>\n";
$nFailure = 1;
$nBadQuantity = $nQuantity;
}
elsif ($nMaxQuantity == -1)
{
$sMessage .= ACTINIC::GetPhrase(-1, 62, $nMinQuantity) . "<P>\n";
$nFailure = 1;
$nBadQuantity = $nQuantity;
}
}
if ($$pProduct{'OUT_OF_STOCK'})
{
$sMessage .= ACTINIC::GetPhrase(-1, 297, $$pProduct{'NAME'}) . "<P>\n";
$nFailure = 1;
$nBadQuantity = $nQuantity;
}
return ($nFailure, $nBadQuantity, $sMessage);
}
sub GetMaxRemains
{
no strict 'refs';
if ($#_ < 1)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 12, 'GetMaxRemains'), 0, 0);
}
my (@Response, $Status, $Message, $sCartID, $ProductRef, $Product, $nIndex, $sSectionBlob);
$ProductRef = $_[0];
$sSectionBlob = $_[1];
if (defined $_[2])
{
$nIndex = $_[2];
}
else
{
$nIndex = -1;
}
@Response = ACTINIC::GetProduct($ProductRef, $sSectionBlob,
ACTINIC::GetPath());
my ($pProduct);
($Status, $Message, $pProduct) = @Response;
if ($Status == $::NOTFOUND)
{
}
if ($Status == $::FAILURE)
{
return (@Response);
}
@Response = $::Session->GetCartObject();
my $pCartObject = $Response[2];
my $pCartList = $pCartObject->GetCartList();
my ($OrderDetail, %CurrentItem, $nQuantityLeft, $nCartItemIndex);
$nQuantityLeft = $$pProduct{'MAX_QUANTITY_ORDERABLE'};
if ($nQuantityLeft  == 0)
{
$nQuantityLeft = $::MAX_ORD_QTY;
}
if ($nIndex != -2)
{
$nCartItemIndex = -1;
foreach $OrderDetail (@$pCartList)
{
%CurrentItem = %$OrderDetail;
$nCartItemIndex++;
if ($nCartItemIndex == $nIndex)
{
next;
}
if ($CurrentItem{'PRODUCT_REFERENCE'} eq $ProductRef)
{
$nQuantityLeft -= $CurrentItem{'QUANTITY'};
}
}
}
if ($nQuantityLeft < 0)
{
$nQuantityLeft = -1;
}
return ($::SUCCESS, "", $nQuantityLeft, 0);
}
sub InfoHTMLGenerate
{
my $sProdref = shift;
my $nIndex 	= shift;
my $sValue 	= shift;
my $bStatic	= shift;
my $bHighLight = shift;
my $sHTML;
if ($bStatic)
{
$sHTML = $sValue;
}
else
{
my $sStyle;
if (defined $bHighLight &&
$bHighLight == $::TRUE)
{
$sStyle = " style=\"background-color: $::g_sErrorColor\"";
}
my $sIndex = "O_$nIndex";
$sHTML = ACTINIC::GetPhrase(-1, 2161, "", $sIndex, 35, 1000, $sValue, $sStyle);
}
return $sHTML;
}
sub InfoGetValue
{
my $sProdref = shift;
my $nIndex = shift;
my $sValue;
$sValue = $::g_InputHash{"O_$nIndex"};
$sValue =~ s/^\s+//;
$sValue =~ s/\s+$//;
$sValue =~ s/\n/%0a/g;
return $sValue;
}
sub InfoValidate
{
my $sProdref = shift;
my $sInfo	= shift;
my $sPrompt	= shift;
my $sMessage;
if (length $sInfo == 0)
{
$sMessage .= ACTINIC::GetPhrase(-1, 55, "<B>$sPrompt</B>") . "<P>\n";
}
elsif (length $sInfo > 1000)
{
$sMessage .= ACTINIC::GetPhrase(-1, 56, "<B>$sPrompt</B>") . "<P>\n";
}
return (length $sMessage == 0 ? $::SUCCESS : $::BADDATA, $sMessage);
}
package ActinicLocations;
sub GetISOCountryCode
{
my ($sActinicCode) = @_;
if (uc($sActinicCode) eq 'UK')
{
return('GB');
}
return($sActinicCode);
}
sub GetISORegionCode
{
my ($sActinicCode) = @_;
my $sISOCode = $sActinicCode;
if($sISOCode =~ /^(\w+)\.(.+)/)
{
$sISOCode = $2;
}
if($sISOCode =~ /^(\w+):(.+)/)
{
$sISOCode = $1;
}
return($sISOCode);
}
sub GetMerchantCountryCode
{
return($$::g_pSetupBlob{MERCHANT_COUNTRY_CODE});
}
sub GetISODeliveryCountryCode
{
return(GetISOCountryCode($::g_LocationInfo{DELIVERY_COUNTRY_CODE}));
}
sub GetISOInvoiceCountryCode
{
return(GetISOCountryCode($::g_LocationInfo{INVOICE_COUNTRY_CODE}));
}
sub GetISODeliveryRegionCode
{
return(GetISORegionCode($::g_LocationInfo{DELIVERY_REGION_CODE}));
}
sub GetISOInvoiceRegionCode
{
return(GetISORegionCode($::g_LocationInfo{INVOICE_REGION_CODE}));
}
sub GetDeliveryAddressRegionName
{
my ($sRegionName) = @_;
if	(defined $::g_LocationInfo{DELIVERY_REGION_CODE} &&
$::g_LocationInfo{DELIVERY_REGION_CODE} ne '' &&
$::g_LocationInfo{DELIVERY_REGION_CODE} ne $ActinicOrder::UNDEFINED_REGION)
{
return(GetAddressRegionName($::g_LocationInfo{DELIVERY_REGION_CODE}));
}
return($sRegionName);
}
sub GetInvoiceAddressRegionName
{
my ($sRegionName) = @_;
if	(defined $::g_LocationInfo{INVOICE_REGION_CODE} &&
$::g_LocationInfo{INVOICE_REGION_CODE} ne '' &&
$::g_LocationInfo{INVOICE_REGION_CODE} ne $ActinicOrder::UNDEFINED_REGION)
{
return(GetAddressRegionName($::g_LocationInfo{INVOICE_REGION_CODE}));
}
return($sRegionName);
}
sub GetAddressRegionName
{
my ($sActinicCode) = @_;
my $sRegionName = ACTINIC::GetCountryName($sActinicCode);
if($sActinicCode =~ /:(\w+)$/)
{
$sRegionName =~ s/\s*:.+$//;
}
return($sRegionName);
}
sub GetParentRegionCode
{
my ($sActinicCode) = @_;
if($sActinicCode =~ /:/)
{
$sActinicCode =~ s/:.+$//;
}
return($sActinicCode);
}
sub GetInvoiceParentRegionCode
{
if	(defined $::g_LocationInfo{INVOICE_REGION_CODE} &&
$::g_LocationInfo{INVOICE_REGION_CODE} ne '' &&
$::g_LocationInfo{INVOICE_REGION_CODE} ne $ActinicOrder::UNDEFINED_REGION)
{
return(GetParentRegionCode($::g_LocationInfo{INVOICE_REGION_CODE}));
}
return('');
}
sub GetDeliveryParentRegionCode
{
if	(defined $::g_LocationInfo{DELIVERY_REGION_CODE} &&
$::g_LocationInfo{DELIVERY_REGION_CODE} ne '' &&
$::g_LocationInfo{DELIVERY_REGION_CODE} ne $ActinicOrder::UNDEFINED_REGION)
{
return(GetParentRegionCode($::g_LocationInfo{DELIVERY_REGION_CODE}));
}
return('');
}
1;