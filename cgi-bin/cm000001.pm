#!perl
package Cart;
require 5.002;
push (@INC, "cgi-bin");
use strict;
require ac000001;
require dc000001;
$Cart::prog_name = 'Cart.pm';
$Cart::prog_name = $Cart::prog_name;
$Cart::prog_ver = '$Revision: 19528 $ ';
$Cart::prog_ver = substr($Cart::prog_ver, 11);
$Cart::prog_ver =~ s/ \$//;
$Cart::XML_CARTROOT	= 'ActinicSavedCart';
$Cart::CARTVERSION	= "1.0";
sub new
{
my $Proto 			= shift;
my $sCartID			= shift;
my $sPath			= shift;
my $pCart 			= shift;
my $bIsCallBack 	= shift;
my $Class = ref($Proto) || $Proto;
my $Self  = {};
bless ($Self, $Class);
$Self->{_CARTID}  = $sCartID;
$Self->{_PATH}		= $sPath;
$Self->{_ISCALLBACK} = $bIsCallBack;
$Self->{_PRODUCTADJUSTMENTS}	= {};
$Self->{_ORDERADJUSTMENTS}	= ();
$Self->{_FINALORDERADJUSTMENTS}	= ();
$Self->{_ADJUSTMENTSCOUNT}	= 0;
$Self->{_PRODUCTADJUSTMENTSPROCESSED} = $::FALSE;
$Self->{_ORDERADJUSTMENTSPROCESSED} = $::FALSE;
$Self->{_FINALORDERADJUSTMENTSPROCESSED} = $::FALSE;
$Self->SetCart($pCart);
return $Self;
}
sub SetCart
{
my $Self  = shift;
my $pCart = shift;
$Self->{_CART} = $pCart;
$Self->ProcessCart();
}
sub GetCart
{
my $Self		= shift;
return $Self->{_CART};
} 	
sub GetCartList
{
my $Self		= shift;
return $Self->{_CartList};
} 	
sub ProcessCart
{
my $Self = shift;
my @Response;
$Self->{_CartList} = [];
my ($nStatus, $sMessage, $pFailures) = $Self->FromXml($Self->GetCart(), $::TRUE);
if ($nStatus == $::FAILURE)
{
ACTINIC::TerminalError($sMessage);
}
if ($#{$Self->{_CartList}} > 0)
{
$Self->CombineCartLines();
}
return ($::SUCCESS, '', \@{$Self->{_CartList}});		
}
sub CombineCartLines
{
my $Self 		= shift;
my $pCartList 	= $Self->{_CartList};
my $nCartIndex;
my %Removed;
for( $nCartIndex = 1; $nCartIndex <= $#$pCartList; $nCartIndex++ )
{
my $pCartItem = $pCartList->[$nCartIndex];
my @aFoundIndices = $Self->FindSimilarCartItems($pCartItem, 0, $nCartIndex - 1);
my $nFoundIndex;
foreach $nFoundIndex (@aFoundIndices)
{
$Removed{$nCartIndex} = $::TRUE;
$pCartList->[$nFoundIndex]->{QUANTITY} += $pCartList->[$nCartIndex]->{QUANTITY};
}
}
foreach (sort {$b <=> $a} keys(%Removed))
{
splice @$pCartList,$_,1;
}
}
sub FindSimilarCartItems
{
my $Self				= shift;
my $pCartItem		= shift;
my $pCartList	= $Self->{_CartList};
my $nLowerCartIdx	= $#_ > -1 ? shift : 0;
my $nUpperCartIdx = $#_ > -1 ? shift : $#$pCartList; # optional cart processing range bound - default: cart item count
my @aFoundIndices;
my $nFoundIndex;
FIND:	for( $nFoundIndex = $nLowerCartIdx; $nFoundIndex <= $nUpperCartIdx; $nFoundIndex++ )	
{
foreach (keys %{$pCartItem}, keys %{$pCartList->[$nFoundIndex]})
{
if( ($_ ne 'QUANTITY') &&
($_ ne 'SID')  &&
$pCartItem->{$_} ne $pCartList->[$nFoundIndex]->{$_} )	
{
next FIND;							
}
}
push @aFoundIndices, $nFoundIndex;
}
return @aFoundIndices;
}
sub UpdateCart
{
my $Self = shift;
my @Response = $Self->ToXml();
if ($Response[0] == $::SUCCESS)
{
$Self->{_CART} = $Response[2];
}
return @Response;	
}	
sub AddItem
{
my $Self = shift;
my $pOrderDetail = $_[0];
push (@{$Self->{_CartList}}, {%{$pOrderDetail}});
return ($::SUCCESS, '');
}
sub CountItems
{
my $Self = shift;
if (defined $Self->{_CartList})
{
return $#{$Self->{_CartList}} + 1;
}
my $pCartList = ProcessCart();
my $nCount = $#$pCartList + 1;
return $nCount;
}	
sub CountQuantities
{
my $Self = shift;
my $pItem;
my $nCount = 0;
foreach $pItem (@{$Self->{_CartList}})
{														
$nCount += $pItem->{'QUANTITY'};
}
return $nCount;
}	
sub UpdateItem
{
my $Self 			= shift;
my $nItemIndex 	= shift;
my $pOrderDetail 	= $_[0];
if ($nItemIndex < 0 ||
$nItemIndex > $#{$Self->{_CartList}} )
{
return($::NOTFOUND, "");
}	
$Self->{_CartList}[$nItemIndex] = {%{$pOrderDetail}};
return ($::SUCCESS, '');
}
sub RemoveItem
{
my $Self 		= shift;
my $nItemIndex = shift;
if ($nItemIndex < 0 ||
$nItemIndex > $#{$Self->{_CartList}} )
{
return($::NOTFOUND, "");
}
splice @{$Self->{_CartList}}, $nItemIndex, 1;
return ($::SUCCESS, '');
}
sub GetRelatedList
{
my $Self 		= shift;
my $sType		= shift;
my %hCartList;
my %hAlsoBoughtRefs;
my $pCartItem;
foreach $pCartItem (@{$Self->{_CartList}})
{
$hCartList{$pCartItem->{'PRODUCT_REFERENCE'}} = 1;
}
foreach $pCartItem (@{$Self->{_CartList}})
{
my ($Status, $Message, $pProduct) = GetProduct($pCartItem->{'PRODUCT_REFERENCE'}, $pCartItem->{'SID'});
foreach my $sABRefs (@{$$pProduct{$sType}})
{
if (!defined $hCartList{$sABRefs})
{
$hAlsoBoughtRefs{$sABRefs} = 1;
}
}
}
srand;
my @aOriginal = keys %hAlsoBoughtRefs;
my @aReturn;
while (@aOriginal) 
{
push(@aReturn, splice(@aOriginal, rand @aOriginal, 1));
}
return ($::SUCCESS, '', \@aReturn);
}
sub IsExternalCartFileExist
{
my $Self 		= shift;
my $sFileName = $Self->GetExternalCartFileName();
return (-e $sFileName);
}
sub GetExternalCartFileName
{
my $Self 		= shift;
my $sFileName;
my ($sDigest,$sBaseFile) = ACTINIC::CaccGetCookies();
if ($sDigest)
{
my ($Status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sDigest, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return ("");
}
$sFileName = "reg_" . $$pBuyer{AccountID};
}
else
{
$sFileName = $Self->{_CARTID};
}
$sFileName = ACTINIC::GetPath() . $sFileName . "_00.save";
return $sFileName;
}
sub ToXml
{
my $Self 		= shift;
my $pXmlCartItems = [];
my $pCartItem;
foreach $pCartItem (@{$Self->{_CartList}})
{
my ($Status, $Message, $pProduct) = GetProduct($pCartItem->{'PRODUCT_REFERENCE'}, $pCartItem->{'SID'});
if ($Status == $::FAILURE)
{
return ($Status, $Message, []);
}
elsif ($Status == $::NOTFOUND)
{
next;
}
my $pXmlCartItem = new Element();
$pXmlCartItem->SetTag('Product');
$pXmlCartItem->SetAttributes({'Reference' => $pCartItem->{'PRODUCT_REFERENCE'},
'Name' 		=> $pProduct->{'NAME'},
'SID'			=> $pCartItem->{'SID'}});
$pXmlCartItem->SetTextNode('Quantity', $pCartItem->{'QUANTITY'});
if ($pCartItem->{'INFOINPUT'})
{
$pXmlCartItem->SetTextNode('Info', $pCartItem->{'INFOINPUT'});
}			
if ($pCartItem->{'DATE'})
{
my $sDate = $pCartItem->{'DATE'};
if ($sDate =~ /([0-9]{4})\/([0-9]{2})\/([0-9]{2})/) # parse the date, which is in yyyy/mm/dd format
{
my $pXmlDate = new Element();
$pXmlDate->SetTag('Date');
$pXmlDate->SetAttributes({ 'Day' 	=> $3,
'Month'	=> $2,
'Year'	=> $1});
$pXmlCartItem->SetChildNode($pXmlDate);
}
}			
if (exists $pCartItem->{'QDQUALIFY'})
{
$pXmlCartItem->SetTextNode('QDQualify', $pCartItem->{'QDQUALIFY'});
}
if( $pProduct->{COMPONENTS} )
{
my ($VariantList, $k);
foreach $k (keys %{$pCartItem})
{
if( $k =~ /^COMPONENT\_/ )
{
$VariantList->[$'] = $pCartItem->{$k};
}
}
my %Component;
my $pItem;
my $nIndex = 0;
foreach $pItem (@{$pProduct->{COMPONENTS}})
{
my @Response = ActinicOrder::FindComponent($pItem, $VariantList);
($Status, %Component) = @Response;
if ($Status == $::FAILURE)
{
return ($Status, $Component{text});
}
my $pNames = $Component{Names};
if (!$pNames)
{
$pNames = {};
}
if ($pNames->{COMPONENT})
{
my $pXmlComponent = new Element();
$pXmlComponent->SetTag("Component");
$pXmlComponent->SetAttributes({"Name"	=> $pNames->{COMPONENT}->{NAME},
"Index"	=> $pNames->{COMPONENT}->{INDEX}});
if (1 < keys %{$pNames})
{
my $sAttribute;
foreach $sAttribute (keys %{$pNames})
{
if ($sAttribute ne "COMPONENT")
{
my $pXMLAttribute = new Element();
$pXMLAttribute->SetTag("Attribute");
$pXMLAttribute->SetAttributes({"Index"	=> $sAttribute,
"Value"	=> $pNames->{$sAttribute}->{VALUE},
"Name"	=>	$pNames->{$sAttribute}->{ATTRIBUTE},
"Choice"=> $pNames->{$sAttribute}->{CHOICE}});
$pXmlComponent->AddChildNode($pXMLAttribute);
}
}
}
$pXmlCartItem->AddChildNode($pXmlComponent);	
}
else
{
my $sAttribute;
foreach $sAttribute (keys %{$pNames})
{
if ($sAttribute ne "COMPONENT")
{
my $pXMLAttribute = new Element();
$pXMLAttribute->SetTag("Attribute");
$pXMLAttribute->SetAttributes({"Index"	=> $sAttribute,
"Value"	=> $pNames->{$sAttribute}->{VALUE},
"Name"	=>	$pNames->{$sAttribute}->{ATTRIBUTE},
"Choice"=> $pNames->{$sAttribute}->{CHOICE}});							
$pXmlCartItem->AddChildNode($pXMLAttribute);
}
}					
}
$nIndex++;
}
}		
push (@{$pXmlCartItems}, $pXmlCartItem);
}
return ($::SUCCESS, '', $pXmlCartItems);
}
sub SaveXmlFile
{
my  $Self 		= shift;
my $pXml = new PXML();
my $sFileName = $Self->GetExternalCartFileName();
my $pXmlCartItems = $Self->ToXml();
my $pXmlCart = new Element();
$pXmlCart->SetTag($Cart::XML_CARTROOT);
$pXmlCart->SetAttributes({	'Version' => $Cart::CARTVERSION,
'CatalogVersion' => $$::g_pCatalogBlob{VERSIONFULL}});
my $pXmlCartItem;
foreach $pXmlCartItem (@{$pXmlCartItems})
{
$pXmlCart->AddChildNode($pXmlCartItem);
}
ACTINIC::ChangeAccess("rw", $sFileName);
my @Response = $pXml->SaveXMLFile($sFileName, [$pXmlCart]);
$::Session->{_NEWESTSAVEDCARTTIME} = time;
ACTINIC::ChangeAccess("", $sFileName);
return @Response;
}	
sub FromXml
{
my $Self 			= shift;
my $pXmlCartItems = shift;
my $bReliableDescription = shift;	
my $sWarnings = "";	
my ($Status, $Message, $pFailure);
my $pXmlCartItem;
foreach $pXmlCartItem (@{$pXmlCartItems})
{
my $pCartItem = {};
if (!$bReliableDescription &&
!$pXmlCartItem->GetAttribute('Reference'))
{
$sWarnings .= ACTINIC::GetPhrase(-1, 2153) . "<P>\n";
ACTINIC::LogData("Attribute 'Reference' is not defined\n", $::DC_CART_RESTORE); 
next;
}
else
{
$pCartItem->{'PRODUCT_REFERENCE'} = $pXmlCartItem->GetAttribute('Reference');
}
if ($bReliableDescription ||
$pXmlCartItem->GetAttribute('SID'))
{
$pCartItem->{'SID'} = $pXmlCartItem->GetAttribute('SID');
}
else	
{
my $nSID;
($Status, $nSID) = ACTINIC::LookUpSectionID($Self->{_PATH}, $pCartItem->{'PRODUCT_REFERENCE'});
if ($Status != $::SUCCESS)
{
$sWarnings .= ACTINIC::GetPhrase(-1, 2154, '#' . $pCartItem->{'PRODUCT_REFERENCE'}) . "<P>\n";
ACTINIC::LogData("Section ID lookup failed for $pCartItem->{'PRODUCT_REFERENCE'}\n", $::DC_CART_RESTORE);				
next;
}
$pCartItem->{'SID'} = $nSID;
}
my $pProduct;
($Status, $Message, $pProduct) = GetProduct($pCartItem->{'PRODUCT_REFERENCE'}, $pCartItem->{'SID'});
if ($Status == $::FAILURE)
{
return ($Status, $Message, []);
}
elsif ($Status == $::NOTFOUND)
{
$sWarnings .= ACTINIC::GetPhrase(-1, 2154, '#' . $pCartItem->{'PRODUCT_REFERENCE'}) . "<P>\n";
ACTINIC::LogData("Product can't be located by product reference:$pCartItem->{'PRODUCT_REFERENCE'}\n", $::DC_CART_RESTORE);
next;
}
if (exists $pProduct->{'NO_ORDER'})
{
ACTINIC::LogData("Product ($pCartItem->{'PRODUCT_REFERENCE'}) can't be ordered online.\n", $::DC_CART_RESTORE);
next;
}
if (!$bReliableDescription && exists $pProduct->{'HIDE'})
{
ACTINIC::LogData("Product ($pCartItem->{'PRODUCT_REFERENCE'}) is hidden.\n", $::DC_CART_RESTORE);
next;
}
if (!($Self->{_ISCALLBACK}))
{
if (!ACTINIC::IsProductVisible($pCartItem->{'PRODUCT_REFERENCE'})) # if the product no longer visible for the user's price schedule
{
ACTINIC::LogData("Product ($pCartItem->{'PRODUCT_REFERENCE'})is not visible for price schedule.\n", $::DC_CART_RESTORE);
next;
}
}
my $sProductName = $pXmlCartItem->GetAttribute('Name');
if (	$sProductName	&&
$pProduct->{'NAME'} ne $sProductName &&
$$::g_pSetupBlob{'PROD_REF_COUNT'} == 0)
{
$sWarnings .= ACTINIC::GetPhrase(-1, 2154, $sProductName) . "<P>\n";
ACTINIC::LogData("Specified product name '$sProductName' doesn't equals to product name '$pProduct->{NAME}'\n", $::DC_CART_RESTORE);
next;
}
my $pXmlQuantity = $pXmlCartItem->GetChildNode('Quantity');
if (!$bReliableDescription &&
!$pXmlQuantity)
{
$pCartItem->{'QUANTITY'} = 0;			
$sWarnings .= ACTINIC::GetPhrase(-1, 2155, $pProduct->{'NAME'}) . "<P>\n"; # nevertheless, throw a warning
ACTINIC::LogData("Required XML node 'Quantity' not found.\n", $::DC_CART_RESTORE);
}
else
{
if (!$bReliableDescription &&
$pXmlQuantity->GetAttribute('Value'))
{
$pCartItem->{'QUANTITY'} = $pXmlQuantity->GetAttribute('Value');
}
else
{
$pCartItem->{'QUANTITY'} = $pXmlQuantity->GetNodeValue();
}
}
my $pXmlQDQualify = $pXmlCartItem->GetChildNode('QDQualify');
if ($pXmlQDQualify)
{
$pCartItem->{'QDQUALIFY'} = $pXmlQDQualify->GetNodeValue();
}
if ($bReliableDescription)
{
if ($pXmlCartItem->GetChildNode('Info'))
{
$pCartItem->{'INFOINPUT'} = $pXmlCartItem->GetChildNode('Info')->GetNodeValue();
}
}
else
{
if ($pProduct->{'OTHER_INFO_PROMPT'})
{
my $sInfoInput;
if ($pXmlCartItem->GetChildNode('Info'))
{
my $pXmlInfo = $pXmlCartItem->GetChildNode('Info');
$sInfoInput = $pXmlInfo->GetNodeValue();
}
else
{
$sInfoInput = '';
}
$pCartItem->{'INFOINPUT'} = $sInfoInput;
}
}
if ($bReliableDescription)
{
if ($pXmlCartItem->GetChildNode('Date'))
{
my ($sDay, $sMonth, $sYear);
my $pXmlDateNode = $pXmlCartItem->GetChildNode('Date');
$sDay = $pXmlDateNode->GetAttribute('Day');
$sMonth = $pXmlDateNode->GetAttribute('Month');
$sYear = $pXmlDateNode->GetAttribute('Year');
$pCartItem->{'DATE'} = $sYear . "/" . $sMonth . "/" . $sDay;
}
}
else
{
if ($pProduct->{'DATE_PROMPT'})
{
my ($sDay, $sMonth, $sYear);
if ($pXmlCartItem->GetChildNode('Date'))
{
my $pXmlDateNode = $pXmlCartItem->GetChildNode('Date');
$sDay = $pXmlDateNode->GetAttribute('Day');
$sMonth = $pXmlDateNode->GetAttribute('Month');
$sYear = $pXmlDateNode->GetAttribute('Year');
if (!$sDay
|| !$sMonth								
|| !$sYear)								
{
$sWarnings .= ACTINIC::GetPhrase(-1, 2155, $pProduct->{'NAME'}) . "<P>\n";
ACTINIC::LogData("Malformed xml node 'Date'.\n", $::DC_CART_RESTORE);
next;
}
}
else													
{
$sWarnings .= ACTINIC::GetPhrase(-1, 2158, $pProduct->{'NAME'}) . "<P>\n";
ACTINIC::LogData("Required node 'Date' not found.\n", $::DC_CART_RESTORE);
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime(time);
$sDay = $mday;
$sMonth = $mon++;
$sYear = $year + 1900;
}
$pCartItem->{'DATE'} = $sYear . "/" . $sMonth . "/" . $sDay;
}
}
my ($pXmlComponents, $pComponents, $pAttributes);
$pXmlComponents = $pXmlCartItem->GetChildNodes("Component");
if (!$bReliableDescription)		
{
my $pComponentHash = ActinicOrder::GetComponents($pProduct);
$pComponents = $pComponentHash->{COMPONENTS};
$pAttributes = $pComponentHash->{ATTRIBUTES};
}
my $pXmlComponent;
foreach $pXmlComponent (@{$pXmlComponents})
{
my $pComponent;
if ($bReliableDescription)
{
my $nIndex = $pXmlComponent->GetAttribute("Index");
$pCartItem->{sprintf("COMPONENT_%d", $nIndex)} = "on";
}
else
{
my $sComponentName = $pXmlComponent->GetAttribute("Name");
if (!$sComponentName)
{
$sWarnings .= ACTINIC::GetPhrase(-1, 2158, $pProduct->{'NAME'}) . "<P>\n";
ACTINIC::LogData("Required XML attribute 'Name' not found .\n", $::DC_CART_RESTORE);
next;
}
$pComponent = $pComponents->{$sComponentName};
if (!$pComponent)
{
$sWarnings .= ACTINIC::GetPhrase(-1, 2155, $pProduct->{'NAME'}) . "<P>\n";
ACTINIC::LogData("Component '$sComponentName' not found for product '$pProduct->{NAME}'.\n", $::DC_CART_RESTORE);
next;
}
$pCartItem->{sprintf("COMPONENT_%d", $pComponent->{INDEX})} = "on";					
}
my $pXmlAttributes = $pXmlComponent->GetChildNodes("Attribute");
my $pComponentAttributes;
if (!$bReliableDescription)
{
$pComponentAttributes = $pComponent->{ATTRIBUTES};
}
($Status, $Message) = ProcessAttributes($pCartItem, $pXmlAttributes, $pProduct, $pComponentAttributes, $bReliableDescription);
if ($Status != $::SUCCESS)
{
$sWarnings .= $Message;
}
}
my $pXmlAttributes = $pXmlCartItem->GetChildNodes("Attribute");
if (	@{$pXmlComponents} > 0 &&
@{$pXmlAttributes} > 0)
{			
$sWarnings .= ACTINIC::GetPhrase(-1, 2155, $pProduct->{'NAME'}) . "<P>\n";
ACTINIC::LogData("XML definition of product '$pProduct->{'NAME'} contains both COMPONENT and ATTRIBUTE tags.\n", $::DC_CART_RESTORE);
}
else
{
($Status, $Message) = ProcessAttributes($pCartItem, $pXmlAttributes, $pProduct, $pAttributes, $bReliableDescription);
if ($Status != $::SUCCESS)
{
$sWarnings .= $Message;
}
}
if (!$bReliableDescription)
{
FillComponentInfoGaps($pCartItem, $pComponents, $pAttributes);
}
if (!$bReliableDescription)
{
my @aFoundIndices = $Self->FindSimilarCartItems($pCartItem);
if (scalar(@aFoundIndices) != 0)
{
next;
}
}
my $VariantList = ActinicOrder::GetCartVariantList($pCartItem);
my $pComp;
my $bValidationFailed = $::FALSE;
foreach $pComp (@{$pProduct->{COMPONENTS}})
{
my @Response = ActinicOrder::FindComponent($pComp,$VariantList);
my ($Status, %Component) = @Response;
if ($Status != $::SUCCESS)
{
$bValidationFailed = $::TRUE;
}
}
if (!$bValidationFailed)
{
$Self->AddItem($pCartItem);			
}
}
my $pFailures = [];
if (!$bReliableDescription)
{
my $nIndex = 0;
my $pCartItem;
foreach $pCartItem (@{$Self->{_CartList}})
{
($Status, $Message, $pFailure) = ActinicOrder::ValidateOrderDetails($pCartItem, $nIndex);
if ($Status == $::FAILURE)
{
return ($::FAILURE, $sWarnings, $pFailures);
}
elsif ($Status == $::BADDATA)
{
$sWarnings .= $Message . "<P>\n";
push @{$pFailures}, $pFailure;
}
else
{
push @{$pFailures}, {};				
}
$nIndex++;
}
}
if (length $sWarnings > 0)
{
return ($::BADDATA, $sWarnings, $pFailures);
}
else
{
return ($::SUCCESS, '', $pFailures);
}
}
sub ProcessAttributes
{
my $pCartItem					= shift;		
my $pXmlAttributes			= shift;
my $pProduct					= shift; 
my $pAttributes				= shift;
my $bReliableDescription	= shift;
my $sWarnings = '';
my $pXmlAttribute;
foreach $pXmlAttribute (@{$pXmlAttributes})
{
if ($bReliableDescription)
{
my $nIndex = $pXmlAttribute->GetAttribute("Index");
my $sValue = $pXmlAttribute->GetAttribute("Value");
$pCartItem->{sprintf("COMPONENT_%d", $nIndex)} = $sValue; 
}
else
{
my $sAttributeName = $pXmlAttribute->GetAttribute("Name");
my $sAttributeChoice = $pXmlAttribute->GetAttribute("Choice");
my $nAttributeValue = $pXmlAttribute->GetAttribute("Value");
if (!$sAttributeName)
{
$sWarnings .= ACTINIC::GetPhrase(-1, 2155, $pProduct->{'NAME'}) . "<P>\n";
ACTINIC::LogData("Attribute 'Name' is missing from xml definition of product '$pProduct->{'NAME'}'.\n", $::DC_CART_RESTORE);
next;
}
my $pAttribute = $pAttributes->{$sAttributeName};
if (!$pAttribute)
{
$sWarnings .= ACTINIC::GetPhrase(-1, 2155, $pProduct->{'NAME'}) . "<P>\n";
ACTINIC::LogData("Attribute '$sAttributeName' cannot be found.\n", $::DC_CART_RESTORE);
next;
}
my $i = 0;
my $nChoiceIdx = -1;
my $choice;
foreach $choice (@{$pAttribute->{CHOICES}})
{						
if ($choice eq $sAttributeChoice)
{
$nChoiceIdx = $i;
}
$i++;
}
if ($nChoiceIdx == -1 &&
0 <= $nAttributeValue &&
$nAttributeValue < @{$pAttribute->{CHOICES}})
{
$nChoiceIdx = $nAttributeValue;
}
if ($nChoiceIdx > -1)
{
$pCartItem->{sprintf("COMPONENT_%d", $pAttribute->{INDEX})} = $nChoiceIdx + 1;
}						
}				
}
return ($sWarnings ? $::BADDATA : $::SUCCESS, $sWarnings);
}
sub FillComponentInfoGaps
{
my $pCartItem	= shift;
my $pComponents = shift;
my $pAttributes = shift;
my $pComponent;
foreach $pComponent (values %{$pComponents})
{
if (!$pComponent->{IS_OPTIONAL} &&
!$pCartItem->{sprintf("COMPONENT_%d", $pComponent->{INDEX})})
{
$pCartItem->{sprintf("COMPONENT_%d", $pComponent->{INDEX})} = "on";
}
if ($pCartItem->{sprintf("COMPONENT_%d", $pComponent->{INDEX})})
{
FillComponentInfoGaps($pCartItem, {}, $pComponent->{ATTRIBUTES});
}
}		
my $pAttribute;
foreach $pAttribute (values %{$pAttributes})
{
if (!$pCartItem->{sprintf("COMPONENT_%d", $pAttribute->{INDEX})})
{
$pCartItem->{sprintf("COMPONENT_%d", $pAttribute->{INDEX})} = 1;
}
}
}
sub RestoreXmlFile
{
my  $Self 		= shift;
my $pXml = new PXML();
my $sFileName = $Self->GetExternalCartFileName();	
if (!$Self->IsExternalCartFileExist())
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 2152) . "<P>\n");
}
ACTINIC::ChangeAccess("r", $sFileName);
my @Response = $pXml->ParseFile($sFileName);
ACTINIC::ChangeAccess("", $sFileName);
if ($Response[0] != $::SUCCESS)
{
return @Response;
}	
my $pXmlCart = @{$Response[2]}[0];
my $pXmlCartItems = $pXmlCart->GetChildNodes('Product');
if (!$pXmlCartItems ||
@{$pXmlCartItems} == 0)
{
return ($::BADDATA, ACTINIC::GetPhrase(-1, 2159) . "<P>\n");
}
else														
{
@Response = $pXml->SaveXMLFile($sFileName, [$pXmlCart]);
$::Session->{_NEWESTSAVEDCARTTIME} = time;
return $Self->FromXml($pXmlCartItems, $::FALSE);
}
}		
sub AddProductAdjustment 
{
my ($Self, $nIndex, $sProductRef, $sDescription, $nAmount, 
$nAdjustmentTaxTreatment, $sTaxProductRef, $bTreatCustomTaxAsExempt, $sCoupon, $nID, $nReward) = @_;
if(!defined $Self->{_PRODUCTADJUSTMENTS}->{$nIndex})
{
$Self->{_PRODUCTADJUSTMENTS}->{$nIndex} = ();
}
my @arrAdjust = ($sProductRef, $sDescription, $nAmount, $nAdjustmentTaxTreatment, $::eOrderLineProductAdjust);
$arrAdjust[$::eAdjIdxTaxProductRef] = $sTaxProductRef;
$arrAdjust[$::eAdjIdxCustomTaxAsExempt] = $bTreatCustomTaxAsExempt;
$arrAdjust[$::eAdjIdxCouponCode] = $sCoupon;
$arrAdjust[$::eAdjIdxDiscountID] = $nID;
$arrAdjust[$::eAdjIdxCartIndex] = $nIndex;
$arrAdjust[$::eAdjIdxRewardType] = $nReward;
push @{$Self->{_PRODUCTADJUSTMENTS}->{$nIndex}} , \@arrAdjust;
$Self->{_ADJUSTMENTSCOUNT}++;
}
sub AddOrderAdjustment 
{
my ($Self, $sDescription, $nAmount, $nAdjustmentTaxTreatment, $sTaxProductRef, $nBasis, $sCoupon) = @_;
my @arrAdjust = (':::::', $sDescription, $nAmount, $nAdjustmentTaxTreatment, $::eOrderLineOrderAdjust);
$arrAdjust[$::eAdjIdxTaxProductRef] = $sTaxProductRef;
$arrAdjust[$::eAdjIdxCustomTaxAsExempt] = $::FALSE;
$arrAdjust[$::eAdjIdxAdjustmentBasis] = $nBasis;
$arrAdjust[$::eAdjIdxCouponCode] = $sCoupon;
push @{$Self->{_ORDERADJUSTMENTS}} , \@arrAdjust;
$Self->{_ADJUSTMENTSCOUNT}++;
}
sub AddFinalAdjustment 
{
my ($Self, $sDescription, $nAmount, $nAdjustmentTaxTreatment, $sTaxProductRef, $nBasis) = @_;
my @arrAdjust = (':::::', $sDescription, $nAmount, $nAdjustmentTaxTreatment, $::eOrderLineOrderAdjust);
$arrAdjust[$::eAdjIdxTaxProductRef] = $sTaxProductRef;
$arrAdjust[$::eAdjIdxCustomTaxAsExempt] = $::FALSE;
$arrAdjust[$::eAdjIdxAdjustmentBasis] = $nBasis;	
push @{$Self->{_FINALORDERADJUSTMENTS}} , \@arrAdjust;
$Self->{_ADJUSTMENTSCOUNT}++;
}
sub GetProductAdjustments 
{
my ($Self, $nIndex) = @_;
if(defined $Self->{_PRODUCTADJUSTMENTS}->{$nIndex})
{
return(\@{$Self->{_PRODUCTADJUSTMENTS}->{$nIndex}});
}
return(());
}
sub GetConsolidatedProductAdjustments 
{
my ($Self, $nIndex) = @_;
if (defined $::DISPLAY_INDIVIDUAL_ADJUSTMENT_LINES)
{
return($Self->GetProductAdjustments($nIndex));
}
if (defined $Self->{_CONSOLIDATION_DONE})
{
if (defined $Self->{_CONSOLIDATEDADJUSTMENTS}->{$nIndex})
{
return(\@{$Self->{_CONSOLIDATEDADJUSTMENTS}->{$nIndex}});
}
else
{
return(());
}
}
my $pValues;
my %mapIDToItem;
foreach $pValues (values %{$Self->{_PRODUCTADJUSTMENTS}})
{
my $pItem;
foreach $pItem (@{$pValues})
{
my @Temp;
$Temp[$::eAdjIdxAmount] = $$pItem[$::eAdjIdxAmount];
$Temp[$::eAdjIdxProductDescription] = $$pItem[$::eAdjIdxProductDescription];
if (!$mapIDToItem{$$pItem[$::eAdjIdxDiscountID]} || # we havent processed this ID so far, OR
(($$pItem[$::eAdjIdxRewardType] == $::eRewardMoneyOff) 						&& !$$::g_pDiscountBlob{'CONSOLIDATE_MONEY_OFF'}) ||
(($$pItem[$::eAdjIdxRewardType] == $::eRewardPercentageOff) 				&& !$$::g_pDiscountBlob{'CONSOLIDATE_PERCENTAGE_OFF'}) ||
(($$pItem[$::eAdjIdxRewardType] == $::eRewardPercentageOffCheapest) 		&& !$$::g_pDiscountBlob{'CONSOLIDATE_PERCENTAGE_OFF_CHEAPEST'}) ||
(($$pItem[$::eAdjIdxRewardType] == $::eRewardMoneyOffExtraProduct) 		&& !$$::g_pDiscountBlob{'CONSOLIDATE_MONEY_OFF_EXTRA'}) ||
(($$pItem[$::eAdjIdxRewardType] == $::eRewardPercentageOffExtraProduct) && !$$::g_pDiscountBlob{'CONSOLIDATE_PERCENTAGE_OFF_EXTRA'}) ||
(($$pItem[$::eAdjIdxRewardType] == $::eRewardFixedPrice) 					&& !$$::g_pDiscountBlob{'CONSOLIDATE_FIXED_PRICE'}))
{	
$mapIDToItem{$$pItem[$::eAdjIdxDiscountID]} = \@Temp;
push @{$Self->{_CONSOLIDATEDADJUSTMENTS}->{$$pItem[$::eAdjIdxCartIndex]}}, \@Temp;
}
else
{
$mapIDToItem{$$pItem[$::eAdjIdxDiscountID]}->[$::eAdjIdxAmount] += $Temp[$::eAdjIdxAmount];
}
}
}
$Self->{_CONSOLIDATION_DONE} = $::TRUE;
if (defined $Self->{_CONSOLIDATEDADJUSTMENTS}->{$nIndex})
{
return(\@{$Self->{_CONSOLIDATEDADJUSTMENTS}->{$nIndex}});
}
else
{
return(());
}
}
sub GetOrderAdjustments 
{
my ($Self) = @_;
return(\@{$Self->{_ORDERADJUSTMENTS}});
}
sub GetFinalAdjustments 
{
my ($Self) = @_;
return(\@{$Self->{_FINALORDERADJUSTMENTS}});
}
sub GetAdjustmentCount 
{
my ($Self) = @_;
return($Self->{_ADJUSTMENTSCOUNT});
}
sub ProcessProductAdjustments 
{
my ($Self) = @_;
if($Self->{_PRODUCTADJUSTMENTSPROCESSED})
{
return($::SUCCESS, '');
}
$Self->{_PRODUCTADJUSTMENTSPROCESSED} = $::TRUE;
my ($nReturn, $sError);
my ($Status, $Message) = ACTINIC::ReadDiscountBlob($Self->{_PATH}); 
if ($Status != $::SUCCESS)
{
return ($Status, $Message);
}	
my $nCartIndex = 0;
my $pitemCart;
my %hashGroupQuantities;
my %hashGroupPrices;
my %hashGroupToData;
foreach $pitemCart (@{$Self->{_CartList}})
{
my $pProduct;
($nReturn, $sError, $pProduct) = GetProduct($pitemCart->{'PRODUCT_REFERENCE'}, $pitemCart->{'SID'});
if($nReturn == $::FAILURE)
{
return($nReturn, $sError);
}
my @Prices = $Self->GetCartItemPrice($pitemCart);
if ($Prices[0] != $::SUCCESS)
{
return($Prices[0], $Prices[1]);
}
my @ItemDetails = @Prices[2..9];
unshift @ItemDetails, $nCartIndex, $pitemCart->{'QUANTITY'};
push @ItemDetails, 0;
push @ItemDetails, 0;
push @ItemDetails, $pitemCart->{'PRODUCT_REFERENCE'};
push @{$hashGroupToData{$$pProduct{'PRODUCT_GROUP'}}}, \@ItemDetails;
$nCartIndex++;
}			
my ($parrAdjustments, $parrAdjustment);
($nReturn, $sError, $parrAdjustments) = ActinicDiscounts::CalculateProductAdjustment(\%hashGroupToData);
foreach $parrAdjustment (@$parrAdjustments)
{
$Self->AddProductAdjustment($parrAdjustment->[$::eAdjIdxCartIndex], 
$parrAdjustment->[$::eAdjIdxProductRef], 
$parrAdjustment->[$::eAdjIdxProductDescription], 
$parrAdjustment->[$::eAdjIdxAmount], 
$parrAdjustment->[$::eAdjIdxTaxTreatment],
"", #$parrAdjustment->[$::eAdjIdxProductRef], 
$::FALSE,
$parrAdjustment->[$::eAdjIdxCouponCode],
$parrAdjustment->[$::eAdjIdxDiscountID],
$parrAdjustment->[$::eAdjIdxRewardType]);
}
return($::SUCCESS, '');
}
sub ProcessOrderAdjustments 
{
my ($Self, $parrOrderTotals) = @_;
if($Self->{_ORDERADJUSTMENTSPROCESSED})
{
$Self->{_ORDERADJUSTMENTSPROCESSED} = $::TRUE;
return($::SUCCESS, '', $Self->GetOrderAdjustments());
}
$Self->ClearAdjustmentCache("_ORDERADJUSTMENTS");
my ($nReturn, $sError, $parrAdjustments, $parrAdjustment);
($nReturn, $sError, $parrAdjustments) = 
ActinicDiscounts::CalculateOrderAdjustment($parrOrderTotals);
foreach $parrAdjustment (@$parrAdjustments)
{
$Self->AddOrderAdjustment(@$parrAdjustment);
}
$Self->{_ORDERADJUSTMENTSPROCESSED} = $::TRUE;
return($::SUCCESS, '', $Self->GetOrderAdjustments());
}
sub ProcessFinalAdjustments 
{
my ($Self, $parrOrderTotals) = @_;
if($Self->{_FINALORDERADJUSTMENTSPROCESSED})
{
$Self->{_FINALORDERADJUSTMENTSPROCESSED} = $::TRUE;
return($::SUCCESS, '', $Self->GetFinalAdjustments());
}
$Self->ClearAdjustmentCache("_FINALORDERADJUSTMENTS");
my ($nReturn, $sError, $parrAdjustments, $parrAdjustment);
($nReturn, $sError, $parrAdjustments) = 
ActinicDiscounts::CalculateOrderAdjustment($parrOrderTotals);
foreach $parrAdjustment (@$parrAdjustments)
{
$Self->AddFinalAdjustment(@$parrAdjustment);
}
$Self->{_FINALORDERADJUSTMENTSPROCESSED} = $::TRUE;
return($::SUCCESS, '', $Self->GetFinalAdjustments());
}
sub ClearAdjustmentCache
{
my ($Self, $sAdjustLabel) = @_;
if ($Self->{$sAdjustLabel . 'PROCESSED'})
{
$Self->{_ADJUSTMENTSCOUNT}	-= scalar @{$Self->{$sAdjustLabel}};
$Self->{$sAdjustLabel} = ();
$Self->{$sAdjustLabel . 'PROCESSED'} = $::FALSE;
}
return();
}
sub SummarizeOrder
{
my ($Self, $bIgnoreAdvancedErrors) = @_;
if (defined $Self->{_ORDERSUMMARY} &&
!ActinicOrder::IsTaxInfoChanged())
{
return(@{$Self->{_ORDERSUMMARY}});
}
my @Response = ActinicOrder::SummarizeOrder($Self->GetCartList(), $bIgnoreAdvancedErrors);
$Self->{_ORDERSUMMARY} = \@Response;
if($Response[0] != $::SUCCESS &&
!defined $Self->{_CALLSHIPPINGPLUGINRESPONSE})
{
$Self->{_CALLSHIPPINGPLUGINRESPONSE} = \@Response;
}
return(@Response);
}
sub GetCartItemPrice
{
my $Self 			= shift;
my $pOrderDetail 	= shift;
my @Response;
my @DefaultTaxResponse;
my ($nComponentsTax1, $nComponentsTax2, $nComponentsDefTax1, $nComponentsDefTax2);
my ($nUComponentsTax1, $nUComponentsTax2, $nUComponentsDefTax1, $nUComponentsDefTax2);
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
my $nScheduleID = ActinicOrder::GetScheduleID($sDigest);
my %CurrentItem = %$pOrderDetail;
my ($nStatus, $sMessage, $pProduct) = GetProduct($CurrentItem{"PRODUCT_REFERENCE"}, $CurrentItem{SID});
if ($nStatus != $::SUCCESS)
{
return ($nStatus, $sMessage);
}
my $nEffectiveQuantity = ActinicOrder::EffectiveCartQuantity($pOrderDetail,$Self->GetCartList(),\&ActinicOrder::IdenticalCartLines,undef);
my $nPrice = ActinicOrder::CalculateSchPrice($pProduct, $nEffectiveQuantity, $sDigest);
@Response = ActinicOrder::GetProductTaxBands($pProduct);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($rarrCurTaxBands, $rarrDefTaxBands) = @Response[2, 3];
my $nRetailProdPrice = $pProduct->{PRICE};
my $nComponentPrice = 0;
my $nAlreadyTaxed  = 0;
if( $pProduct->{COMPONENTS} &&
$pProduct->{PRICING_MODEL} != $ActinicOrder::PRICING_MODEL_STANDARD )
{
my $VariantList = ActinicOrder::GetCartVariantList(\%CurrentItem);
my (%Component, $c);
my $nIndex = 1;
foreach $c (@{$pProduct->{COMPONENTS}})
{
($nStatus, %Component) = ActinicOrder::FindComponent($c, $VariantList);
if ($nStatus != $::SUCCESS)
{
return ($nStatus, $Component{text});
}
if ($Component{quantity} > 0 )
{
my $sRef= $Component{code} && 
($c->[$::CBIDX_ASSOCPRODPRICE] == 1 ||
$Component{'AssociatedPrice'}) ? 
$Component{code} : $CurrentItem{"PRODUCT_REFERENCE"} . "_" . $nIndex;
@Response = GetComponentPriceAndTaxBands(\%Component, $sRef, $nEffectiveQuantity, $nRetailProdPrice, 
$rarrCurTaxBands, $rarrDefTaxBands, $pProduct, $nScheduleID);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my ($nItemPrice, $phashTaxBands, $rarrCurCompTaxBands, $rarrDefCompTaxBands) = @Response[2 .. 5];
$nComponentPrice += $nItemPrice * $Component{quantity};
if ($c->[$::CBIDX_SEPARATELINE])
{
my $nTaxQuantity = $CurrentItem{"QUANTITY"} * $Component{quantity};
@Response = ActinicOrder::CalculateTax($nItemPrice, $nTaxQuantity, 
$rarrCurCompTaxBands, $rarrDefCompTaxBands, $nItemPrice);
@DefaultTaxResponse = ActinicOrder::CalculateDefaultTax($nItemPrice, $nTaxQuantity, 
$rarrCurCompTaxBands, $rarrDefCompTaxBands, $nItemPrice);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$nComponentsTax1 += $Response[2];
$nComponentsTax2 += $Response[3];
$nComponentsDefTax1 += $DefaultTaxResponse[2];
$nComponentsDefTax2 += $DefaultTaxResponse[3];
$nUComponentsTax1 += $Response[4];
$nUComponentsTax2 += $Response[5];
$nUComponentsDefTax1 += $DefaultTaxResponse[4];
$nUComponentsDefTax2 += $DefaultTaxResponse[5];
$nAlreadyTaxed += $nItemPrice * $Component{quantity};
}
}
$nIndex++;
}
}
my $nTaxBase = $nPrice;
my $nPriceModel = $pProduct->{PRICING_MODEL};
if( $nPriceModel == $ActinicOrder::PRICING_MODEL_PROD_COMP )
{
$nPrice += $nComponentPrice;
$nTaxBase = $nPrice - $nAlreadyTaxed;
}
elsif( $nPriceModel == $ActinicOrder::PRICING_MODEL_COMP )
{
$nPrice = $nComponentPrice;
$nTaxBase = $nPrice - $nAlreadyTaxed;
}
my $nLineTotal += $nPrice * $CurrentItem{"QUANTITY"};
@Response = ActinicOrder::CalculateTax($nTaxBase, $CurrentItem{"QUANTITY"}, $rarrCurTaxBands, $rarrDefTaxBands, 
$$pProduct{"PRICE"});
@DefaultTaxResponse = ActinicOrder::CalculateDefaultTax($nTaxBase, $CurrentItem{"QUANTITY"}, $rarrCurTaxBands, $rarrDefTaxBands, $$pProduct{"PRICE"});
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $nProductSubTotalTax1 = $Response[2] + $nComponentsTax1;
my $nProductSubTotalTax2 = $Response[3] + $nComponentsTax2;	
my $nProductSubTotalDefTax1 = $DefaultTaxResponse[2] + $nComponentsDefTax1;
my $nProductSubTotalDefTax2 = $DefaultTaxResponse[3] + $nComponentsDefTax2;	
my $nUProductSubTotalTax1 = $Response[4] + $nUComponentsTax1;
my $nUProductSubTotalTax2 = $Response[5] + $nUComponentsTax2;	
my $nUProductSubTotalDefTax1 = $DefaultTaxResponse[4] + $nUComponentsDefTax1;
my $nUProductSubTotalDefTax2 = $DefaultTaxResponse[5] + $nUComponentsDefTax2;	
return ($::SUCCESS, "", $nLineTotal, $nPrice, $rarrCurTaxBands, $rarrDefTaxBands, 
$nProductSubTotalTax1, $nProductSubTotalTax2, $nProductSubTotalDefTax1, $nProductSubTotalDefTax2, 
$nUProductSubTotalTax1, $nUProductSubTotalTax2, $nUProductSubTotalDefTax1, $nUProductSubTotalDefTax2);
}
sub SetShippingPluginResponse
{
my ($Self, $pResponse) = @_;
$Self->{_CALLSHIPPINGPLUGINRESPONSE} = $pResponse;
}
sub GetShippingPluginResponse
{
my ($Self) = @_;
return(@{$Self->{_CALLSHIPPINGPLUGINRESPONSE}});
}
sub GetProduct
{
my ($sProductReference, $sSID) = @_;
my ($nStatus, $sMessage, $sSectionBlobName, $pProduct);
if(@_ == 1)
{
($nStatus, $sSID) = ACTINIC::LookUpSectionID(ACTINIC::GetPath(), $sProductReference);
if($nStatus == $::FAILURE)
{
return ($nStatus, $sMessage, undef);
}
}
($nStatus, $sMessage, $sSectionBlobName) = ACTINIC::GetSectionBlobName($sSID);
if ($nStatus == $::FAILURE)
{
return ($nStatus, $sMessage, undef);
}
($nStatus, $sMessage, $pProduct) = ACTINIC::GetProduct($sProductReference, $sSectionBlobName,
ACTINIC::GetPath());
return ($nStatus, $sMessage, $pProduct);
}	
sub AdjustCustomTax
{
my ($sTaxOpaqueData, $nOrigUnitPrice, $nNewUnitPrice) = @_;
my ($nBandID, $nPercent, $nFlatRate, $sBandName) = split /=/, $sTaxOpaqueData;
if ($nBandID == $ActinicOrder::CUSTOM && 
$nOrigUnitPrice != $nNewUnitPrice)
{
if ($nOrigUnitPrice == 0)
{
return ('6=0=0=');
}
$nFlatRate = $nNewUnitPrice / $nOrigUnitPrice * $nFlatRate;
$nFlatRate = ActinicOrder::RoundTax($nFlatRate, $ActinicOrder::SCIENTIFIC_NORMAL);
return (sprintf("%d=%d=%d=", $nBandID, $nPercent, $nFlatRate));
}
return ($sTaxOpaqueData);
}
sub GetComponentPriceAndTaxBands
{
my ($rhashComponent, $sRef, $nQuantity, $nRetailProdPrice, 
$rarrCurTaxBands, $rarrDefTaxBands, $pProduct, $nScheduleID) = @_;
my $rhashTaxBands = $pProduct;
my @Response = ActinicOrder::GetComponentPrice($rhashComponent->{price}, $nQuantity, 
$rhashComponent->{quantity}, $nScheduleID, $sRef);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
my $nDiscUnitPrice = $Response[2] / $rhashComponent->{quantity};
my $bUseAssocPrice = $rhashComponent->{'UseAssociatedPrice'};
my $bUseAssocTax = $rhashComponent->{'AssociatedTax'};
if ($bUseAssocTax)
{
@Response = ActinicOrder::GetProductTaxBands($rhashComponent);
($rarrCurTaxBands, $rarrDefTaxBands) = @Response[2, 3];
$rhashTaxBands = $rhashComponent;
}
my $nAssocRetailProdPrice = undef;
if ($bUseAssocPrice || $bUseAssocTax)
{
$nAssocRetailProdPrice = $rhashComponent->{'RetailPrice'};
}
my ($nOrigTaxPrice);		
if ($bUseAssocPrice && $bUseAssocTax)
{
$nOrigTaxPrice = $nAssocRetailProdPrice;
}
elsif ($bUseAssocPrice)
{
$nOrigTaxPrice = $nRetailProdPrice;
}
elsif ($bUseAssocTax)
{
$nOrigTaxPrice = $nAssocRetailProdPrice;
}
else
{
$nOrigTaxPrice = $nRetailProdPrice;
}
my $rarrTemp;
foreach $rarrTemp (($rarrCurTaxBands, $rarrDefTaxBands))
{
my $nTaxIndex;
foreach $nTaxIndex (0 .. 1)
{
$rarrTemp->[$nTaxIndex] = 
AdjustCustomTax($rarrTemp->[$nTaxIndex], $nOrigTaxPrice, $nDiscUnitPrice); 
}
}	
return ($::SUCCESS, '', $nDiscUnitPrice, $rhashTaxBands, $rarrCurTaxBands, $rarrDefTaxBands);
}
sub GetAdjustmentTaxBands
{
my ($Self, $pProduct, $nCartIndex, $rarrCurProdTaxBands, $rarrDefProdTaxBands, $nProdRetailPrice) = @_;
if ($pProduct->{PRICING_MODEL} == $ActinicOrder::PRICING_MODEL_STANDARD)
{
return ($::SUCCESS, '', $rarrCurProdTaxBands, $rarrDefProdTaxBands, $nProdRetailPrice);
}
my $pCartItem = @{$Self->{_CartList}}[$nCartIndex];
my $VariantList = ActinicOrder::GetCartVariantList($pCartItem);
my @arrTaxBandHashes = ({}, {});
my @arrDefTaxBandHashes = ({}, {});
my @arrTaxBandHashArray = (\@arrTaxBandHashes, \@arrDefTaxBandHashes);
my ($nBandID, $nPercent, $nFlatRate, $sBandName, $sTaxBand);
if ($pProduct->{PRICING_MODEL} == $ActinicOrder::PRICING_MODEL_PROD_COMP)
{
my ($rarrTaxBands, $nArrIndex);
foreach $rarrTaxBands(($rarrCurProdTaxBands, $rarrDefProdTaxBands))
{
my $rarrTaxBandHash = $arrTaxBandHashArray[$nArrIndex];
my $nTaxIndex = 0;
foreach $sTaxBand(@{$rarrTaxBands})
{
($nBandID, $nPercent, $nFlatRate, $sBandName) = split /=/, $sTaxBand;
if ($nBandID ne '')
{
$rarrTaxBandHash->[$nTaxIndex]{$nBandID} = $sTaxBand;
}
$nTaxIndex++;
}
$nArrIndex++;
}
}
my $nTaxableRetailPrice = $nProdRetailPrice;
my ($rarrCurCompTaxBands, $rarrDefCompTaxBands);
my ($pProdComponent);
foreach $pProdComponent (@{$pProduct->{COMPONENTS}})
{
my ($nStatus, %Component) = ActinicOrder::FindComponent($pProdComponent, $VariantList);
if ($nStatus != $::SUCCESS)
{
return ($::FAILURE, "FindComponent failed");
}
if ($Component{quantity} > 0)
{
if ($Component{AssociatedTax})
{
my @Response = ActinicOrder::GetProductTaxBands(\%Component);
if ($Response[0] != $::SUCCESS)
{
return ($::FAILURE, "GetProductTaxBands failed");
}
($rarrCurCompTaxBands, $rarrDefCompTaxBands) = @Response[2, 3];
$nTaxableRetailPrice = $Component{'RetailPrice'};
}
else
{
$rarrCurCompTaxBands = $rarrCurProdTaxBands;
$rarrDefCompTaxBands = $rarrDefProdTaxBands;
}
my ($rarrTaxBands, $nArrIndex);
foreach $rarrTaxBands(($rarrCurCompTaxBands, $rarrDefCompTaxBands))
{
my $rarrTaxBandHash = $arrTaxBandHashArray[$nArrIndex];
my $nTaxIndex = 0;
foreach $sTaxBand(@{$rarrTaxBands})
{
($nBandID, $nPercent, $nFlatRate, $sBandName) = split /=/, $sTaxBand;
if ($nBandID ne '')
{
if ($nBandID == $ActinicOrder::CUSTOM)
{
if (defined $rarrTaxBandHash->[$nTaxIndex]{$nBandID})
{
$rarrTaxBandHash->[$nTaxIndex]{$ActinicOrder::PRORATA} = $sTaxBand;
}
}
$rarrTaxBandHash->[$nTaxIndex]{$nBandID} = $sTaxBand;
}
$nTaxIndex++;
}
$nArrIndex++;
}
}
}
my @arrTaxBands = ('5=0=0=', '5=0=0=');
my @arrDefTaxBands = ('5=0=0=', '5=0=0=');
my @arrReturnArrays = (\@arrTaxBands, \@arrDefTaxBands);
my $nArrIndex = 0;
my $rarrTaxBandHashes;
foreach $rarrTaxBandHashes(@arrTaxBandHashArray)
{
my $nTaxIndex = 0;
my $phashTaxBands;
foreach $phashTaxBands (@{$rarrTaxBandHashes})
{
if (scalar(keys %$phashTaxBands) == 1)
{
$nBandID = (keys %$phashTaxBands)[0];
$arrReturnArrays[$nArrIndex]->[$nTaxIndex] =
$phashTaxBands->{$nBandID};
}
$nTaxIndex++;
}
$nArrIndex++;
}	
return ($::SUCCESS, '', \@arrTaxBands, \@arrDefTaxBands, $nTaxableRetailPrice);
}
1;