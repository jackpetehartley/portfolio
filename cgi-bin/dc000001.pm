#!perl -wc
package ActinicDiscounts;
require 5.002;
push (@INC, "cgi-bin");
use strict;
require ac000001;
use Time::Local;
$ActinicDiscounts::prog_name = 'ActinicDiscounts.pm';
$ActinicDiscounts::prog_name = $ActinicDiscounts::prog_name;
$ActinicDiscounts::prog_ver = '$Revision: 18819 $ ';
$ActinicDiscounts::prog_ver = substr($ActinicDiscounts::prog_ver, 11);
$ActinicDiscounts::prog_ver =~ s/ \$//;
sub CalculateProductAdjustment 
{
my ($phashCartItems) = @_;
my @arrAdjustments;
my $nTotalAdjustments = 0;
my ($pItem, $pCartItem, $nGroupID);
my $bGotOneDiscount  = $::FALSE;
my %hUsedGroups;
my %hCartTotals;
foreach $nGroupID (keys %{$phashCartItems})
{
my @Array = sort 
{
$$b[$::eDCartLineTotal] / $$b[$::eDCartLineQuantity] <=> 
$$a[$::eDCartLineTotal] / $$a[$::eDCartLineQuantity]
} (@{$$phashCartItems{$nGroupID}});
$$phashCartItems{$nGroupID} = \@Array;
map {$hCartTotals{$$_[$::eDCartLineIndex]} = $$_[$::eDCartLineTotal]} (@{$$phashCartItems{$nGroupID}});
}
foreach $pItem (@{$$::g_pDiscountBlob{PRODUCT_LEVEL}})
{
$nGroupID = $$pItem{'GROUPID'};
if (!defined $$phashCartItems{$nGroupID})
{
next;
}
if (!IsDateValid(\$pItem) ||
!IsCustomerValid(\$pItem) ||
!IsCouponValid(\$pItem))
{
next;
}
if ($$::g_pDiscountBlob{'PRODUCT_GROUPS'}->{$nGroupID}->[0] &&
$hUsedGroups{$nGroupID})
{
next;
}
my @arrThisAdjustments = CalculateProductRewards($phashCartItems, $nGroupID, $pItem);
if ((scalar @arrThisAdjustments) != 0)
{
push @arrAdjustments, @arrThisAdjustments;
$hUsedGroups{$nGroupID} = 1;
if ($$::g_pDiscountBlob{'ONE_PRODUCT_DISCOUNT'}) 
{
last;
}
}
}
my %hTotals;
foreach $pItem (@arrAdjustments)
{
my $nNewTotal = $$pItem[$::eAdjIdxAmount] + $hTotals{$$pItem[$::eAdjIdxCartIndex]};
if (0 < $nNewTotal + $hCartTotals{$$pItem[$::eAdjIdxCartIndex]})
{
$hTotals{$$pItem[$::eAdjIdxCartIndex]} = $nNewTotal;
next;
}
else
{												
$$pItem[$::eAdjIdxAmount] = -($hCartTotals{$$pItem[$::eAdjIdxCartIndex]} + $hTotals{$$pItem[$::eAdjIdxCartIndex]});
$hTotals{$$pItem[$::eAdjIdxCartIndex]} += $$pItem[$::eAdjIdxAmount];
}
}
return($::SUCCESS, '', \@arrAdjustments);
}
sub GetRewardString
{
my $pDiscount = shift;
my $nReward = $$pDiscount{'REWARD_TYPE'};
my $nBasis	= $$pDiscount{'BASIS'};
my $sMsg;
if ($nReward == $::eRewardMoneyOff)
{
my $sPrice = (ActinicOrder::FormatPrice($$pDiscount{'REWARDS'}->{'MONEY_OFF'}, $::TRUE, $::g_pCatalogBlob))[2];
$sMsg = ACTINIC::GetPhrase(-1, 2391, $sPrice, GetGroupLink($$pDiscount{'GROUPID'}));
}			
elsif ($nReward == $::eRewardPercentageOff)
{
if ($$pDiscount{'REWARDS'}->{'PERCENTAGE_OFF'} eq '100.00%')
{
$sMsg = ACTINIC::GetPhrase(-1, 2392, GetGroupLink($$pDiscount{'GROUPID'}));
}
else
{
$sMsg = ACTINIC::GetPhrase(-1, 2391, StripTrailingZero($$pDiscount{'REWARDS'}->{'PERCENTAGE_OFF'}), GetGroupLink($$pDiscount{'GROUPID'}));
}
}				
elsif ($nReward == $::eRewardPercentageOffCheapest)
{
if ($$pDiscount{'REWARDS'}->{'PERCENTAGE_OFF'} eq '100.00%')
{
$sMsg = ACTINIC::GetPhrase(-1, 2394, GetGroupLink($$pDiscount{'GROUPID'}));
}
else
{
$sMsg = ACTINIC::GetPhrase(-1, 2393, StripTrailingZero($$pDiscount{'REWARDS'}->{'PERCENTAGE_OFF'}), GetGroupLink($$pDiscount{'GROUPID'}));
}		
}			
elsif ($nReward == $::eRewardFixedPrice)
{
my $sPrice = (ActinicOrder::FormatPrice($$pDiscount{'REWARDS'}->{'MONEY_OFF'}, $::TRUE, $::g_pCatalogBlob))[2];
$sMsg = ACTINIC::GetPhrase(-1, 2395, GetGroupLink($$pDiscount{'GROUPID'}), $sPrice);
}
elsif ($nReward == $::eRewardMoneyOffExtraProduct)
{
my $sPrice = (ActinicOrder::FormatPrice($$pDiscount{'REWARDS'}->{'MONEY_OFF'}, $::TRUE, $::g_pCatalogBlob))[2];
$sMsg = ACTINIC::GetPhrase(-1, 2397, $sPrice, GetRewardProductLink($pDiscount));
}
elsif ($nReward == $::eRewardPercentageOffExtraProduct)
{
if ($$pDiscount{'REWARDS'}->{'PERCENTAGE_OFF'} eq '100.00%')
{
$sMsg = ACTINIC::GetPhrase(-1, 2392, GetRewardProductLink($pDiscount));
}
else
{
$sMsg = ACTINIC::GetPhrase(-1, 2397, StripTrailingZero($$pDiscount{'REWARDS'}->{'PERCENTAGE_OFF'}), GetRewardProductLink($pDiscount));
}		
}	
return $sMsg;
}
sub StripTrailingZero
{
my $sIn = shift;
$sIn =~ s/(.+\.+[^\.0]*)0*(%*)$/$1$2/;
$sIn =~ s/\.(%*)$/$1/;
return $sIn;
}
sub GetRewardProductLink
{
my $pDiscount = shift;
my $sLink;
if ($$pDiscount{'REWARDS'}->{'USE_GROUP'})
{
$sLink = GetGroupLink($$pDiscount{'REWARDS'}->{'PRODUCT_GROUP'});
}
else
{
my ($nStatus, $sMessage, $pProduct) = Cart::GetProduct($$pDiscount{'REWARDS'}->{'PRODUCT_REF'});
if ($nStatus != $::SUCCESS)
{
return "";
}
my @Response = ACTINIC::ProcessEscapableText($$pProduct{'NAME'});
$sLink = sprintf("<A HREF=\"$::g_sSearchScript?PRODREF=%s&NOLOGIN=1\">%s</A>", $$pDiscount{'REWARDS'}->{'PRODUCT_REF'}, $Response[1]);
}	
return $sLink;
}
sub GetGroupLink
{
my $nGroupID = shift;
my $sLink;
my $sShop = ($::g_InputHash{SHOP} ? '&SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) : '');
if ($$::g_pDiscountBlob{'PRODUCT_GROUPS'}->{$nGroupID}->[2] ne '')
{
my ($nStatus, $sMessage, $pProduct) = Cart::GetProduct($$::g_pDiscountBlob{'PRODUCT_GROUPS'}->{$nGroupID}->[2]);
if ($nStatus != $::SUCCESS)
{
return "";
}
my @Response = ACTINIC::ProcessEscapableText($$pProduct{'NAME'});
$sLink = sprintf("<A HREF=\"$::g_sSearchScript?PRODREF=%s&NOLOGIN=1%s\">%s</A>", 
$$::g_pDiscountBlob{'PRODUCT_GROUPS'}->{$nGroupID}->[2], 
$sShop,
$Response[1]);
}
else
{
$sLink = sprintf("<A HREF=\"$::g_sSearchScript?PG=%d&GROUPONLY=1%s\">%s</A>", 
$nGroupID, 
$sShop,
$$::g_pDiscountBlob{'PRODUCT_GROUPS'}->{$nGroupID}->[1]);
}
return ($sLink);
}
sub AddProductDiscountInfo
{
my $sMessage = shift;
if ($$::g_pSetupBlob{'SHOW_PRODUCT_DISCOUNT_INFO'})
{
$ACTINIC::B2B->AppendXML("DiscountInfo", $sMessage . "\n");
}
}
sub AddOrderDiscountInfo
{
my $sMessage = shift;
if ($$::g_pSetupBlob{'SHOW_DISCOUNT_INFO'})
{
$ACTINIC::B2B->AppendXML("DiscountInfo", $sMessage . "\n");
}
}
sub CalculateProductRewards
{
my $pItemList = shift;
my $nGroupID  = shift;
my $pDiscount = shift;
my @arrAdjustments;
my $nReward = $$pDiscount{'REWARD_TYPE'};
my $nBasis	= $$pDiscount{'BASIS'};
my $bPaymentMessageDisplayed = $::FALSE;
my $bInactive = $::FALSE;
my $nDiscountTotal;
my %SavedItemList;
foreach my $nGroup (keys %{$pItemList})
{
my @Array;
map 
{
my @Array2;
map {push @Array2, $_} (@{$_});
push @Array, \@Array2;
} (@{$$pItemList{$nGroup}});
$SavedItemList{$nGroup} = \@Array;
}
while ($::TRUE)
{
my ($nRemained, @CartItems) = GetNextTriggeringIndex($$pItemList{$nGroupID}, $$pDiscount{'BASIS'}, $$pDiscount{'REWARDS'}->{'TRIGGER'});
if ($$pDiscount{RESTRICTED_TO_PAYMENT} &&
(scalar @CartItems) != 0)
{
if (IsPaymentValid(\$pDiscount))
{
if (!$bPaymentMessageDisplayed)
{
if (!($nReward == $::eRewardMoneyOffExtraProduct ||
$nReward == $::eRewardPercentageOffExtraProduct))
{
my $sMessage = ACTINIC::GetPhrase(-1, 2362, $$pDiscount{'DESCRIPTION'}, GetPaymentMethodList(\$pDiscount));
AddProductDiscountInfo($sMessage);
$bPaymentMessageDisplayed = $::TRUE;
}
}
}
else
{
$bInactive = $::TRUE;
}
}	
if ((scalar @CartItems) == 0)
{
if ($nRemained > 0 &&
!$bInactive)
{
my $sReward = GetRewardString($pDiscount);
my $sTrigger;
if ($$pDiscount{'BASIS'} != $::eBasisQuantity)	
{
my $sPrice = (ActinicOrder::FormatPrice($nRemained, $::TRUE, $::g_pCatalogBlob))[2];
if ($nReward == $::eRewardMoneyOffExtraProduct ||
$nReward == $::eRewardPercentageOffExtraProduct)
{
$sTrigger = ACTINIC::GetPhrase(-1, 2398, $sPrice, GetGroupLink($$pDiscount{'GROUPID'}));
}
else
{
$sTrigger = ACTINIC::GetPhrase(-1, 2415, $sPrice);
}
}
else
{
if ($nReward == $::eRewardMoneyOffExtraProduct ||
$nReward == $::eRewardPercentageOffExtraProduct)
{
$sTrigger = ACTINIC::GetPhrase(-1, 2416,  
$nRemained, 
GetGroupLink($$pDiscount{'GROUPID'}),
$nRemained == 1 ?  ACTINIC::GetPhrase(-1, 2403) : ACTINIC::GetPhrase(-1, 2404));
}
else
{
$sTrigger = ACTINIC::GetPhrase(-1, 2414, $nRemained);
}					
}
my $sMessage = $sReward . $sTrigger;
AddProductDiscountInfo($sMessage);
}
last;
}		
if ($nReward == $::eRewardMoneyOffExtraProduct ||
$nReward == $::eRewardPercentageOffExtraProduct)
{
my (@TempItems) = GetExtraProduct($pItemList, $pDiscount);
if ((scalar @TempItems) == 0)
{
my $sReward = GetRewardString($pDiscount);
my $sTrigger = ACTINIC::GetPhrase(-1, 2399, ACTINIC::GetPhrase(-1, $$pDiscount{'REWARDS'}->{'USE_GROUP'} ? 2412 : 2411));
my $sMessage = $sReward . $sTrigger;
AddProductDiscountInfo($sMessage);				
last;
}	
if ($$pDiscount{RESTRICTED_TO_PAYMENT} &&
IsPaymentValid(\$pDiscount))
{
if (!$bPaymentMessageDisplayed)
{
my $sMessage = ACTINIC::GetPhrase(-1, 2362, $$pDiscount{'DESCRIPTION'}, GetPaymentMethodList(\$pDiscount));
AddProductDiscountInfo($sMessage);
$bPaymentMessageDisplayed = $::TRUE;
}
}				
push @CartItems, $TempItems[0];
}					
if ($nReward == $::eRewardPercentageOff)
{
@CartItems = GetAllAvailableGroupItems($$pItemList{$nGroupID}, $$pDiscount{'BASIS'});
}
my $pLine;
my $nUsed;
my $nTaxExclusiveItemTotal;
my $nUsedValue;
foreach $pLine (@CartItems)
{		
$nUsed += ($nBasis == $::eBasisQuantity) ? $$pLine[1] : $$pLine[2];
$nUsedValue += ($nBasis == $::eBasisQuantity) ? $$pLine[3]->[$::eDCartLineItemCost] * $$pLine[1] : $$pLine[2];
$nTaxExclusiveItemTotal += $$pLine[3]->[$::eDCartLineItemCost] * $$pLine[1];
}
my $nIndex;
my $nAdjTotal;
foreach $pLine (@CartItems)
{
my $nAdjustment = 0;
my $nContribution = 0;
unless ((($nBasis == $::eBasisQuantity) &&
($$pLine[3]->[$::eDCartLineItemCost] * $$pLine[1] == 0)) ||
(($nBasis != $::eBasisQuantity) && 
($$pLine[2] == 0)))
{
$nContribution = 1 / $nUsedValue * (($nBasis == $::eBasisQuantity) ? $$pLine[3]->[$::eDCartLineItemCost] * $$pLine[1] : $$pLine[2]);
}
if ($nReward == $::eRewardMoneyOff)
{
if ((scalar @CartItems) == $nIndex + 1)
{
$nAdjustment = -$$pDiscount{'REWARDS'}->{'MONEY_OFF'} - $nAdjTotal;
}				
else
{
$nAdjustment = ActinicOrder::RoundTax(-($$pDiscount{'REWARDS'}->{'MONEY_OFF'} * $nContribution), $ActinicOrder::SCIENTIFIC_NORMAL);
}
}	
elsif ($nReward == $::eRewardPercentageOff)
{
if ($$pDiscount{'BASIS'} == $::eBasisQuantity)	
{
$nAdjustment = ActinicOrder::RoundTax(-($$pLine[1] * $$pLine[3]->[$::eDCartLineItemCost] / 100 * $$pDiscount{'REWARDS'}->{'PERCENTAGE_OFF'}), $ActinicOrder::SCIENTIFIC_NORMAL);
}
else
{
$nAdjustment = ActinicOrder::RoundTax(-($$pLine[2] / 100 * $$pDiscount{'REWARDS'}->{'PERCENTAGE_OFF'}), $ActinicOrder::SCIENTIFIC_NORMAL);
}
}	
elsif ($nReward == $::eRewardPercentageOffCheapest)
{
if ((scalar @CartItems) == $nIndex + 1)
{
$nAdjustment = ActinicOrder::RoundTax(-($$pLine[3]->[$::eDCartLineItemCost] / 100 * $$pDiscount{'REWARDS'}->{'PERCENTAGE_OFF'}), $ActinicOrder::SCIENTIFIC_NORMAL);
}					
}
elsif ($nReward == $::eRewardFixedPrice)
{
my $nDiscount = $$pDiscount{'REWARDS'}->{'MONEY_OFF'} - $nTaxExclusiveItemTotal;
if ((scalar @CartItems) == $nIndex + 1)
{
$nAdjustment = $nDiscount - $nAdjTotal;
}				
else
{
$nAdjustment = ActinicOrder::RoundTax(($nDiscount * $nContribution), $ActinicOrder::SCIENTIFIC_NORMAL);
}				
}				
elsif ($nReward == $::eRewardMoneyOffExtraProduct)
{
if ((scalar @CartItems) == $nIndex + 1)
{
$nAdjustment = -$$pDiscount{'REWARDS'}->{'MONEY_OFF'};
}
}					
elsif ($nReward == $::eRewardPercentageOffExtraProduct)
{
if ((scalar @CartItems) == $nIndex + 1)
{				
$nAdjustment = ActinicOrder::RoundTax(-($$pLine[3]->[$::eDCartLineItemCost] / 100 * $$pDiscount{'REWARDS'}->{'PERCENTAGE_OFF'}), $ActinicOrder::SCIENTIFIC_NORMAL);
}
}		
my $nUsedValue = ($nBasis == $::eBasisQuantity) ? $$pLine[3]->[$::eDCartLineItemCost] * $$pLine[1] : $$pLine[2];
$nAdjTotal += $nAdjustment;
$nDiscountTotal += $nAdjustment;
if (((scalar @CartItems) == $nIndex + 1) &&
(($nReward == $::eRewardPercentageOffExtraProduct) ||
($nReward == $::eRewardMoneyOffExtraProduct)))
{
$$pLine[3]->[$::eDcartLineQuantityUsed]++;
$$pLine[3]->[$::eDcartLineValueUsed] += $$pLine[2];	
$nUsedValue = $$pLine[3]->[$::eDCartLineItemCost];
}
else
{
$$pLine[3]->[$::eDcartLineQuantityUsed] += $$pLine[1];
$$pLine[3]->[$::eDcartLineValueUsed] += $$pLine[2];			
}
if (($nAdjTotal < 0) &&
($nUsedValue < abs($nAdjustment)))
{
$nAdjTotal -= $nAdjustment;
$nDiscountTotal -= $nAdjustment;
$nAdjustment = - $nUsedValue;
$nAdjTotal += $nAdjustment;
$nDiscountTotal += $nAdjustment;
}				
if (($nAdjustment != 0) &&
!$bInactive)
{
my @arrAdjustment = 
($$pLine[3]->[$::eDcartLineProductRef],
$$pDiscount{'DESCRIPTION'}, 
$nAdjustment, 
$::eAdjTaxProRata );
$arrAdjustment[$::eAdjIdxCouponCode] = $::g_PaymentInfo{COUPONCODE};
$arrAdjustment[$::eAdjIdxCartIndex]	 = $$pLine[0];
$arrAdjustment[$::eAdjIdxDiscountID] = $$pDiscount{'ID'};
$arrAdjustment[$::eAdjIdxRewardType] = $nReward;
if ((scalar @arrAdjustments) != 0 &&
$arrAdjustments[$#arrAdjustments][$::eAdjIdxCartIndex] == $$pLine[0] &&
$arrAdjustments[$#arrAdjustments][$::eAdjIdxDiscountID] == $$pDiscount{'ID'})
{
$arrAdjustments[$#arrAdjustments][2] += $nAdjustment;
}
else
{
push @arrAdjustments, \@arrAdjustment;
}
}
$nIndex++;
}			
if ($$pDiscount{'ONE_PER_ORDER'})
{
last;
}				
}	
if ($bInactive)
{
if ($bInactive &&
($nDiscountTotal != 0))
{
my $sPrice = (ActinicOrder::FormatPrice(abs($nDiscountTotal), $::TRUE, $::g_pCatalogBlob))[2];
my $sMessage = ACTINIC::GetPhrase(-1, 2363, $sPrice, "adjustment", GetPaymentMethodList(\$pDiscount));
AddProductDiscountInfo($sMessage);
}			
foreach my $nGroup (keys %SavedItemList)
{
my @Array;
map 
{
my @Array2;
map {push @Array2, $_} (@{$_});
push @Array, \@Array2;
} (@{$SavedItemList{$nGroup}});
$$pItemList{$nGroup} = \@Array;
}		
}
return @arrAdjustments;
}
sub GetExtraProduct
{
my $pItemList = shift;
my $pDiscount = shift;
if ($$pDiscount{'REWARDS'}->{'USE_GROUP'})
{
my ($nRemained, @Cart) = GetNextTriggeringIndex($$pItemList{$$pDiscount{'REWARDS'}->{'PRODUCT_GROUP'}}, $::eBasisQuantity, 1);
return(@Cart);
}
else
{
my ($nRemained, @Cart) = GetNextTriggeringIndex($$pItemList{-1}, $::eBasisProductReference, $$pDiscount{'REWARDS'}->{'PRODUCT_REF'});
return(@Cart);
}
}
sub GetAllAvailableGroupItems
{
my ($pItemList, $nBasis) = @_;
my $pItem;
my @Quantity;
foreach $pItem (@{$pItemList})
{
my $nUsableQty = $$pItem[$::eDCartLineQuantity] - $$pItem[$::eDcartLineQuantityUsed];
my $nUsableValue = $$pItem[$::eDCartLineTotal] - $$pItem[$::eDcartLineValueUsed];
my @Ret;
if ($nBasis == $::eBasisQuantity)
{
@Ret = ($$pItem[0], $nUsableQty, 0, $pItem);
}
else
{
@Ret = ($$pItem[0], 0, $nUsableValue, $pItem);
}
push @Quantity, \@Ret;
}
return (@Quantity);
}
sub GetNextTriggeringIndex
{
my ($pItemList, $nBasis, $nTrigger) = @_;
my $pItem;
my $nActual = 0;
my @Quantity;
foreach $pItem (@{$pItemList})
{
my $nUsableQty = $$pItem[$::eDCartLineQuantity] - $$pItem[$::eDcartLineQuantityUsed];
my $nUsableValue = $$pItem[$::eDCartLineTotal] - $$pItem[$::eDcartLineValueUsed];
if (($nBasis == $::eBasisQuantity) &&
($nUsableQty == 0)
||
($nBasis != $::eBasisQuantity) &&
($nUsableValue == 0))
{
next;
}
my $nTotalCost;
my $nCurrentIncrement;
my $nRatio;
if ($nBasis == $::eBasisTaxExclusiveValue)
{
if (ActinicOrder::PricesIncludeTaxes())
{
$nRatio = ($$pItem[$::eDCartLineTotal] == 0) ? 1 :
$$pItem[$::eDCartLineTotal] /
($$pItem[$::eDCartLineTotal] - $$pItem[$::eDcartLineTax1Default] - $$pItem[$::eDcartLineTax2Default]);
}
else
{
$nRatio = 1;
}
$nCurrentIncrement = $nUsableValue / $nRatio;
}
elsif ($nBasis == $::eBasisValueIncludingDefaultTax)
{
if (ActinicOrder::PricesIncludeTaxes())
{
$nRatio = 1;
}
else
{
$nRatio = ($$pItem[$::eDCartLineTotal] + 
$$pItem[$::eDcartLineTax1Default] + 
$$pItem[$::eDcartLineTax2Default]) == 0 ? 1 : 
$$pItem[$::eDCartLineTotal] / ($$pItem[$::eDCartLineTotal] + 
$$pItem[$::eDcartLineTax1Default] + 
$$pItem[$::eDcartLineTax2Default]);
}
$nCurrentIncrement = $nUsableValue / $nRatio;
}
elsif ($nBasis == $::eBasisValueIncludingActualTax)
{
my $nPriceInclActualTax = $$pItem[$::eDCartLineTotal];
if (ActinicOrder::PricesIncludeTaxes())
{
if ($::g_TaxInfo{'EXEMPT1'} ||
!ActinicOrder::IsTaxApplicableForLocation('TAX_1'))
{
$nPriceInclActualTax -= $$pItem[$::eDcartLineTax1Default];
}
if ($::g_TaxInfo{'EXEMPT2'} ||
!ActinicOrder::IsTaxApplicableForLocation('TAX_2'))
{
$nPriceInclActualTax -= $$pItem[$::eDcartLineTax2Default];
}
$nRatio = ($$pItem[$::eDCartLineTotal] == 0) ? 1 :
$$pItem[$::eDCartLineTotal] /
($nPriceInclActualTax);
}
else
{
$nRatio = ($$pItem[$::eDCartLineTotal] + 
$$pItem[$::eDcartLineTax1Actual] + 
$$pItem[$::eDCartLineTax2Actual]) == 0 ? 1 : 
$$pItem[$::eDCartLineTotal] / ($$pItem[$::eDCartLineTotal] + 
$$pItem[$::eDcartLineTax1Actual] + 
$$pItem[$::eDCartLineTax2Actual]);
}
$nCurrentIncrement = $nUsableValue / $nRatio;
}
elsif ($nBasis == $::eBasisQuantity)			
{
$nCurrentIncrement = $nUsableQty;
}
elsif ($nBasis == $::eBasisProductReference)
{
if ($nTrigger eq $$pItem[$::eDcartLineProductRef] &&
$nUsableQty >= 1)
{
my @Ret = ($$pItem[0], 1, 0, $pItem);
push @Quantity, \@Ret;
return (0, @Quantity);				
}
next;
}
$nActual += $nCurrentIncrement;			
if ($nActual >= $nTrigger)
{
my $nUsedQty = 0;
my $nUsedValue = 0;
if ($nBasis == $::eBasisQuantity)
{
$nUsedQty = $nTrigger - ($nActual - $nCurrentIncrement);
}			
else
{
$nUsedValue = ($nTrigger - ($nActual - $nCurrentIncrement)) * $nRatio;
}
my @Ret = ($$pItem[0], $nUsedQty, $nUsedValue, $pItem);
push @Quantity, \@Ret;
return (0, @Quantity);
}
my @Ret;
if ($nBasis == $::eBasisQuantity)
{
@Ret = ($$pItem[0], $nUsableQty, 0, $pItem);
}
else
{
@Ret = ($$pItem[0], 0, $nUsableValue, $pItem);
}
push @Quantity, \@Ret;
}
return ($nActual == 0 ? 0 : $nTrigger - $nActual, ());
}
sub CalculateOrderAdjustment 
{
my ($parrOrderTotals) = @_;
my @arrAdjustments;
my $nTotalAdjustments = 0;
my ($pItem);
my $bGotOneDiscount  = $::FALSE;
my $bGotOneSurcharge = $::FALSE;
foreach $pItem (@{$$::g_pDiscountBlob{ORDER_LEVEL}})
{
if (!IsDateValid(\$pItem) ||
!IsCustomerValid(\$pItem) ||
!IsCouponValid(\$pItem))
{
next;
}
if (($pItem->{'BASIS'} <= 2 && scalar(@$parrOrderTotals) == 2))
{
my $nTotal;
my $nAdjustable;
if (defined $pItem->{'BASIS'})
{
if ($pItem->{'BASIS'} == $::eBasisTaxExclusiveValue)
{											
$nTotal = $parrOrderTotals->[1][0];
if (ActinicOrder::PricesIncludeTaxes())
{
$nTotal -= $parrOrderTotals->[1][3] +
$parrOrderTotals->[1][4];
}
$nAdjustable = $nTotal;
}
elsif ($pItem->{'BASIS'} == $::eBasisValueIncludingDefaultTax)
{
$nTotal = $parrOrderTotals->[1][0];
if (!ActinicOrder::PricesIncludeTaxes())
{
$nTotal += $parrOrderTotals->[1][3] +
$parrOrderTotals->[1][4];
}
$nAdjustable = $parrOrderTotals->[1][0];
}
elsif ($pItem->{'BASIS'} == $::eBasisValueIncludingActualTax)
{
if ($parrOrderTotals->[1][5])
{
$nTotal = $parrOrderTotals->[1][0];
if (!ActinicOrder::PricesIncludeTaxes())
{
$nTotal += $parrOrderTotals->[1][1] +
$parrOrderTotals->[1][2];
}
else
{
if ($::g_TaxInfo{'EXEMPT1'} ||
!ActinicOrder::IsTaxApplicableForLocation('TAX_1'))
{
$nTotal -= $parrOrderTotals->[1][1];
}
if ($::g_TaxInfo{'EXEMPT2'} ||
!ActinicOrder::IsTaxApplicableForLocation('TAX_2'))
{
$nTotal -= $parrOrderTotals->[1][2];
}
}
$nAdjustable = $parrOrderTotals->[1][0];
}
}						
}
my $nAdjustment = CalculateOrderRewards(\$pItem, $nTotal, $nAdjustable, $bGotOneDiscount, $bGotOneSurcharge);
if (($parrOrderTotals->[1][0] + $nTotalAdjustments + $nAdjustment) < 0)
{
$nAdjustment = - ($parrOrderTotals->[1][0] + $nTotalAdjustments);
}
$nTotalAdjustments += $nAdjustment;
my @arrAdjustment = 
($pItem->{'DESCRIPTION'}, 
$nAdjustment, 
$::eAdjTaxProRataAdjusted,
"",
$pItem->{'BASIS'},
$::g_PaymentInfo{COUPONCODE});
if ($nAdjustment != 0)
{
if (((!$$::g_pDiscountBlob{ONE_ORDER_DISCOUNT} && $nAdjustment < 0)	||
($nAdjustment < 0 && !$bGotOneDiscount)) ||
((!$$::g_pDiscountBlob{ONE_ORDER_DISCOUNT_SURCHAGE} && $nAdjustment > 0) ||
($nAdjustment > 0 && !$bGotOneSurcharge)))  
{
push @arrAdjustments, \@arrAdjustment;
}
if ($nAdjustment < 0)
{
$bGotOneDiscount = $::TRUE;
}
else
{
$bGotOneSurcharge = $::TRUE;
}
}
}
}
return($::SUCCESS, '', \@arrAdjustments);
}
sub CalculateOrderRewards
{
my ($phashDiscount, $nTotal, $nAdjustable, $bGotOneDiscount, $bGotOneSurcharge) = @_;
my $nCartValue;		
my $nAdjustment = 0;
my $sAdjustment = 0;
my $nNextBand;
foreach $nCartValue (sort {$b <=> $a} keys %{$$phashDiscount->{'REWARDS'}})
{
if ($nCartValue <= $nTotal)
{
$sAdjustment = $$phashDiscount->{'REWARDS'}->{$nCartValue};
last;
}
$nNextBand = $nCartValue;
}
$nAdjustment = $sAdjustment;
if ($nAdjustment =~ /%$/)
{
$nAdjustment =~ s/%$//;
$nAdjustment = $nAdjustable * $nAdjustment / 100;
my $nRound = ($nAdjustment < 0) ? -0.5 : 0.5;
$nAdjustment = int($nAdjustment + $nRound);
}	
my $bDiscount = ($nAdjustment < 0) || ($$phashDiscount->{'REWARDS'}->{$nNextBand} < 0) ? $::TRUE : $::FALSE;
if (($$::g_pDiscountBlob{ONE_ORDER_DISCOUNT} && 
$bDiscount &&
$bGotOneDiscount) ||
($$::g_pDiscountBlob{ONE_ORDER_DISCOUNT_SURCHAGE} && 
!$bDiscount &&
$bGotOneSurcharge))
{
return 0;
}
if (!$bDiscount &&
($nTotal == 0))
{
return 0;
}	
if ($$phashDiscount->{RESTRICTED_TO_PAYMENT} &&
$nAdjustment != 0)
{
my $sMessage;
if (IsPaymentValid($phashDiscount))
{
$sMessage = ACTINIC::GetPhrase(-1, 2362, $$phashDiscount->{'DESCRIPTION'}, GetPaymentMethodList($phashDiscount));
}
else
{
my $sAdjustment = ($sAdjustment =~ /%$/) ? StripTrailingZero($sAdjustment) : (ActinicOrder::FormatPrice($sAdjustment, $::TRUE, $::g_pCatalogBlob))[2];
$sAdjustment =~ s/^-//;
my $sDiscount = ACTINIC::GetPhrase(-1, ($nAdjustment < 0 ? 2364 : 2365));
$sMessage = ACTINIC::GetPhrase(-1, 2363, $sAdjustment, $sDiscount, GetPaymentMethodList($phashDiscount));
$nAdjustment = 0;
}
AddOrderDiscountInfo($sMessage);
}				
my $sNext = $$phashDiscount->{'REWARDS'}->{$nNextBand};
if ($nNextBand > $nCartValue &&
$sNext =~ /^-/)
{
$sNext =~ s/^-//;
my $sPrice = (ActinicOrder::FormatPrice($nNextBand, $::TRUE, $::g_pCatalogBlob))[2];
my $sOff = ($sNext =~ /%$/) ? StripTrailingZero($sNext) : (ActinicOrder::FormatPrice($sNext, $::TRUE, $::g_pCatalogBlob))[2];
my $sMessage = ACTINIC::GetPhrase(-1, 2366, $sOff, $sPrice);
AddOrderDiscountInfo($sMessage);
}
return $nAdjustment;
}
sub GetPaymentMethodList
{
my ($phashDiscount) = @_;
my $sRestriction;
my $sList;
foreach $sRestriction (keys %{$$phashDiscount->{'RESTRICTIONS'}})
{
if ($sRestriction =~ /P_(\d+)/)
{
$sList .= $$::g_pPaymentList{$1}{'PROMPT'} . ", ";
}
}	
my $sOr = " " . ACTINIC::GetPhrase(-1, 2367);
$sList =~ s/, $//;
$sList =~ s/,([^,]*)$/$sOr$1/g;
return $sList;
}
sub IsDateValid
{
my ($phashDiscount) = @_;
my $nNow = time;
if ($$phashDiscount->{USE_FROM_DATE})
{
my @aFrom = split /\//, $$phashDiscount->{VALID_FROM};
my $nStart = timegm(0, 0, 0, $aFrom[2], $aFrom[1] - 1, $aFrom[0]);
if ($nNow < $nStart)
{
return $::FALSE;
}
}
if ($$phashDiscount->{USE_UNTIL_DATE})
{
my @aUntil = split /\//, $$phashDiscount->{VALID_UNTIL};
my $nExpiry = timegm(59, 59, 23, $aUntil[2], $aUntil[1] - 1, $aUntil[0]);
if ($nNow > $nExpiry)
{
return $::FALSE;
}		
}
return ($::TRUE);
}
sub IsCustomerValid
{
my ($phashDiscount) = @_;
if (!$$phashDiscount->{RESTRICTED_TO_CUSTOMER})
{
return $::TRUE;
}
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
my $nSchedule = ActinicOrder::GetScheduleID($sDigest);	
my $sKey = "C_" . $nSchedule;
if ($$phashDiscount->{RESTRICTIONS}->{$sKey} == 1)
{			
return $::TRUE;
}
return $::FALSE;
}
sub IsPaymentValid
{
my ($phashDiscount) = @_;
if (!$$phashDiscount->{RESTRICTED_TO_PAYMENT})
{
return $::TRUE;
}
my $nPaymentID = $::g_PaymentInfo{METHOD};
my $sKey = "P_" . $nPaymentID;
if ($$phashDiscount->{RESTRICTIONS}->{$sKey} == 1)
{			
return $::TRUE;
}
return $::FALSE;
}
sub IsCouponValid
{
my ($phashDiscount) = @_;
if (!$$phashDiscount->{REQUIRES_COUPON})
{
return $::TRUE;
}
my $sCoupon = $::g_PaymentInfo{COUPONCODE};
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
my $sMD5Coupon = md5_hex($sCoupon);
if ($$phashDiscount->{COUPON_CODE} eq $sMD5Coupon)
{			
return $::TRUE;
}
return $::FALSE;
}
sub ValidateCoupon
{
my $sCoupon = shift;
my ($pItem);
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
my $sMD5Coupon = md5_hex($sCoupon);
my @Discounts = (@{$$::g_pDiscountBlob{ORDER_LEVEL}}, @{$$::g_pDiscountBlob{PRODUCT_LEVEL}});
foreach $pItem (@Discounts)
{
if (!$pItem->{REQUIRES_COUPON})
{
next;
}
if ($pItem->{COUPON_CODE} ne $sMD5Coupon)
{
next;
}
if ($pItem->{USE_UNTIL_DATE})
{
my @aUntil = split /\//, $pItem->{VALID_UNTIL};
my $nNow = time;
my $nExpiry = timegm(59, 59, 23, $aUntil[2], $aUntil[1] - 1, $aUntil[0]);
if ($nNow > $nExpiry)
{
my $sExpiry = ACTINIC::FormatDate($aUntil[2], $aUntil[1], $aUntil[0], $::FALSE);
return ($::FAILURE, ACTINIC::GetPhrase(-1, 2358, $sExpiry), undef);
}	
}		
return ($::SUCCESS, undef, undef);			
}
if (ACTINIC::GetPhrase(-1, 2355) eq $sCoupon)
{
return ($::SUCCESS, undef, undef);	
}
return ($::FAILURE, ACTINIC::GetPhrase(-1, 2357, $sCoupon), undef);
}
1;