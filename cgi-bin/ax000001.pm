#!/usr/bin/perl
package ACTINIC_PXML;
push (@INC, "cgi-bin");
require px000001;
$ACTINIC_PXML::prog_name = 'ACTINIC_PXML.pm';
$ACTINIC_PXML::prog_name = $ACTINIC_PXML::prog_name;
$ACTINIC_PXML::prog_ver = '$Revision: 18819 $ ';
$ACTINIC_PXML::prog_ver = substr($ACTINIC_PXML::prog_ver, 11);
$ACTINIC_PXML::prog_ver =~ s/ \$//;
use vars qw(@ISA);
@ISA = qw(PXML);
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $self  = $Class->SUPER::new();
bless ($self, $Class);
$self->Set(
ID						=>	'Actinic:',
XMLERROR				=> "<br>" . ACTINIC::GetPhrase(-1, 1972, $::g_sRequiredColor) . "<b>". ACTINIC::GetPhrase(-1, 218) . "</b>" . ACTINIC::GetPhrase(-1, 1970) . "<br>",
MAINFRAME				=>	sub { $self->MainFrameTagHandler(@_)		},
PRICES					=> sub { $self->PriceTagHandler(@_)				},
PRICE_EXPLANATION	=> sub { $self->ExplanationTagHandler(@_)		},
VAR						=> sub { $self->VarTagHandler(@_)				},
SECTION				=> sub { $self->SectionTagHandler(@_)			},
ADDRESSES				=> sub { $self->AddressTagHandler(@_)			},
UNREG					=> sub { $self->UnregTagHandler(@_)				},
IGNORE					=> sub { $self->IgnoreTagHandler(@_)			},
REMOVE					=> sub { $self->RemoveTagHandler(@_)			},
NOTINB2B				=> sub { $self->NotInB2BTagHandler(@_)			},
BASEHREF				=> sub { $self->BaseHrefTagHandler(@_)			},
DEFAULT				=> sub { $self->DefaultTagHandler(@_)			},
XMLTEMPLATE			=> sub { $self->XMLTemplateTagHandler(@_)		},
CARTERROR				=> sub { $self->CartErrorTagHandler(@_)		},
RETAIL_ONLY_SEARCH => sub { $self->RetailOnlySearchTagHandler(@_)},
LOCATION						=> sub { $self->LocationTagHandler(@_)					},
EXTRAFOOTERTEXT				=> sub { $self->ExtraFooterTagHandler(@_)				},
EXTRACARTTEXT				=> sub { $self->ExtraCartTagHandler(@_)				},
EXTRACARTBASEPLUSPERTEXT	=> sub { $self->ExtraCartBasePlusPerTagHandler(@_)	},
EXTRASHIPPINGTEXT			=> sub { $self->ExtraShippingTagHandler(@_)			},
BASEPLUSPERRATEWARNING	=> sub { $self->BasePlusPerInfoTagHandler(@_)		},
DEFAULTTAXZONEMESSAGE		=> sub { $self->DefaultTaxZoneMessageTagHandler(@_)},
SHOWFORPRICESCHEDULE		=> sub { $self->ShowForPriceScheduleTagHandler(@_)	},
COOKIECHECK					=> sub { $self->AddCookieCheck(@_)						},
);
$self->Set(@_);
return $self;
}
sub ExplanationTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag =~ /^\// )
{
return "";
}
if( $Self->{CurrentSectionBlob} )
{
my @Response;
@Response = ACTINIC::GetProduct($ParameterHash->{PROD_REF}, $Self->{CurrentSectionBlob},
ACTINIC::GetPath());
my ($Status, $Message, $pProduct) = @Response;
if ($Status != $::SUCCESS)
{
return "";
}
if (defined $$pProduct{PRICES})
{
my ($bShowRetailPrices, $bShowCustomerPrices, $nAccountSchedule) = ACTINIC::DeterminePricesToShow();
my $sComments;
if ($nAccountSchedule == -1)
{
$nAccountSchedule = $ActinicOrder::RETAILID;
}
if (defined $ParameterHash->{COMPONENTID} &&
$ParameterHash->{COMPONENTID} != -1)
{
my $nComponentID = $ParameterHash->{COMPONENTID};
if ($pProduct->{COMPONENTS}[$nComponentID][$::CBIDX_ASSOCPRODPRICE] == 1)
{
my $Assoc = $pProduct->{COMPONENTS}[$nComponentID][$::CBIDX_PERMUTATIONS][0][$::PBIDX_ASSOCIATEDPROD];
if (ref $Assoc eq 'HASH')
{
$sComments = $$Assoc{PRICE_COMMENTS}->{$nAccountSchedule};
}
}
elsif (defined $pProduct->{COMPONENTS}[$nComponentID][$::CBIDX_EXPLANATION] &&
ref($pProduct->{COMPONENTS}[$nComponentID][$::CBIDX_EXPLANATION]) eq 'HASH')
{
$sComments = $pProduct->{COMPONENTS}[$nComponentID][$::CBIDX_EXPLANATION]->{$nAccountSchedule};
}
}
else
{
$sComments = $pProduct->{'PRICE_COMMENTS'}->{$nAccountSchedule};
}
if ($sComments ne '')
{
$$sInsideText = ACTINIC::GetPhrase(-1, 2296). $sComments . ACTINIC::GetPhrase(-1, 2297);
}
}
}
return "";
}
sub RetailOnlySearchTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if ($sTag !~ /^\//)
{
if ($sDigest)
{
if (ref($sInsideText))
{
$$sInsideText = "";
}
}
}
else
{
return ('');
}
my $sRetailMessage = ACTINIC::GetPhrase(-1, 357);
if ($sDigest)
{
my ($Status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sDigest, ACTINIC::GetPath());
if ($Status == $::SUCCESS)
{
my $pAccount;
($Status, $sMessage, $pAccount) = ACTINIC::GetCustomerAccount($pBuyer->{AccountID}, ACTINIC::GetPath());
if ($Status == $::SUCCESS)
{
if ($pAccount->{PriceSchedule} == $ActinicOrder::RETAILID)
{
$sRetailMessage = '';
}
}
}
}
return ($sRetailMessage);
}
sub AddressTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if( $sTag =~ /^\// )
{
return "";
}
my ($Status, $sMessage, $pBuyer, $pAccount) = ACTINIC::GetBuyerAndAccount($sDigest, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
if ($Status != $::NOTFOUND)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
return("");
}
my ($pAddress, $plistValidAddresses, $plistValidInvoiceAddresses, $plistValidDeliveryAddresses);
($Status, $sMessage, $plistValidInvoiceAddresses, $plistValidDeliveryAddresses) =
ACTINIC::GetCustomerAddressLists($pBuyer, $pAccount);
if ($Status != $::SUCCESS)
{
return("");
}
my ($sType,$sSelect,$nRule,$sChecked);
if ($ParameterHash->{TYPE} =~ /^INVOICE/)
{
$plistValidAddresses = $plistValidInvoiceAddresses;
if ($pAccount->{InvoiceAddressRule} == 1)
{
$nRule = 0;
$sSelect = $pAccount->{InvoiceAddress};# Default (or fixed) address
($Status, $sMessage, $pAddress) = ACTINIC::GetCustomerAddress($$pBuyer{AccountID}, $sSelect, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
ACTINIC::CloseCustomerAddressIndex(); # The customer index is left open for multiple access, so clean it up here
return("");
}
}
else
{
$nRule   = $pBuyer->{InvoiceAddressRule};
$sSelect = $pBuyer->{InvoiceAddressID};   # Default (or fixed) address
if($nRule == 0 || ($nRule == 1 && $#$plistValidAddresses == 0))
{
$nRule = 0;
$pAddress = $plistValidAddresses->[0];
$sSelect  = $pAddress->{ID};
}
}
}
elsif( $ParameterHash->{TYPE} =~ /^DELIVERY/ )
{
$plistValidAddresses = $plistValidDeliveryAddresses;
$nRule   = $pBuyer->{DeliveryAddressRule};
if($nRule == 0)
{
$sSelect  = $pBuyer->{DeliveryAddressID};
($Status, $sMessage, $pAddress) = ACTINIC::GetCustomerAddress($$pBuyer{AccountID}, $sSelect, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
ACTINIC::CloseCustomerAddressIndex(); # The customer index is left open for multiple access, so clean it up here
return ("");
}
}
elsif($nRule == 1 && $#$plistValidAddresses == 0)
{
$nRule = 0;
$pAddress = $plistValidAddresses->[0];
$sSelect  = $pAddress->{ID};
}
else
{
$sSelect = $pBuyer->{DeliveryAddressID};
}
}
if( $ParameterHash->{TYPE} =~ /FORM$/ )
{
if( $nRule != 2 )
{
$$sInsideText = "";
}
ACTINIC::CloseCustomerAddressIndex();
return "";
}
ACTINIC::CloseCustomerAddressIndex();
my $sTableFormat   	= $Self->{Variables}->{ADDRESS_TABLE};
my $sTitle         	= $Self->{Variables}->{'ADDRESS_TITLE' . $nRule};
my $sTitle_1        	= $Self->{Variables}->{'ADDRESS_TITLE1' . $nRule};
my $sForm				= '<TD>' . $Self->{Variables}->{'ADDRESS_FORM' . $nRule} . '</TD>';
my $nColumns         = $Self->{Variables}->{ADDRESS_COLUMNS} || 1;
if( !$sForm or !$sTableFormat )
{
return "";
}
my $sAddressText = "";
if( $nRule == 0 )
{
$sAddressText .= '<TR><TD>';
$sAddressText .= sprintf($sForm,
$sSelect,
$pAddress->{Name},
$pAddress->{Line1},
$pAddress->{Line2},
$pAddress->{Line3},
$pAddress->{Line4},
$pAddress->{PostCode},
ACTINIC::GetCountryName($pAddress->{CountryCode}));
$sAddressText .= '</TD></TR>';
}
else
{
$sTitle = sprintf($sTitle,ACTINIC::GetPhrase(-1, 302));
if( $nRule == 2 )
{
if( $ParameterHash->{TYPE} =~ /^INVOICE/ )
{
$sTitle_1 = sprintf($sTitle_1,ACTINIC::GetPhrase(-1, 303,ACTINIC::GetPhrase(-1, 304)));
}
else
{
$sTitle_1 = sprintf($sTitle_1,ACTINIC::GetPhrase(-1, 303,ACTINIC::GetPhrase(-1, 305)));
}
}
my $nCount = 0;
my $nRowCount = 0;
my $sCh;
foreach $pAddress (@$plistValidAddresses)
{
if( $nCount % $nColumns == 0 )
{
$sAddressText .= '<TR VALIGN="TOP">';
}
if( $pAddress->{ID} eq $sSelect and $nRule == 1 )
{
$sCh = ' CHECKED';
}
else
{
$sCh = '';
}
$sAddressText .= sprintf($sForm,
ACTINIC::GetPhrase(-1, 301),
$pAddress->{ID},
$sCh,
$pAddress->{Name},
$pAddress->{Line1},
$pAddress->{Line2},
$pAddress->{Line3},
$pAddress->{Line4},
$pAddress->{PostCode},
ACTINIC::GetCountryName($pAddress->{CountryCode}));
$nCount++;
if( $nCount % $nColumns == 0 )
{
$sAddressText .= '</TR>';
$nRowCount++;
}
}
while( $nCount % $nColumns != 0 )
{
if( $nRowCount > 0 ) { $sAddressText .= '<TD>&nbsp;</TD>' }
$nCount++;
if( $nCount % $nColumns == 0 )
{
$sAddressText .= '</TR>';
last;
}
}
}
$sAddressText =~ s/<br>[,\s]*/<br>/gi;
$sAddressText =~ s/[,\s]*<br>/<br>/gi;
$sAddressText =~ s/(<br>)+/<br>/gi;
return sprintf($sTableFormat,
$sTitle,
$$::g_pSetupBlob{FORM_EMPHASIS_COLOR},
$$::g_pSetupBlob{FORM_BACKGROUND_COLOR},
$sAddressText,
$sTitle_1);
return "";
}
sub VarTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag !~ /^\// )
{
$Self->{Variables}->{$ParameterHash->{NAME}} = $ParameterHash->{VALUE};
}
return "";
}
sub CartErrorTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag =~ /^\// )
{
return "";
}
my $sErrorValue = $ACTINIC::B2B->GetXML("CartError_" . $ParameterHash->{ProdRef});
if (defined $sErrorValue)
{
return $sErrorValue;
}
return "";
}
sub DefaultTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
my $sXMLTag = $ACTINIC::B2B->GetXML($sTag);
if (defined $sXMLTag)
{
return $sXMLTag;
}
return $sFullTag;
}
sub XMLTemplateTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag =~ /^\// )
{
return "";
}
my $sTagname = $ParameterHash->{NAME};
my $sXMLTag = $ACTINIC::B2B->GetXML($sTagname);
if (defined $sXMLTag)
{
$$sInsideText = "";
return $sXMLTag;
}
$$sInsideText = "";
return "";
}
sub RetailPriceTextTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag !~ /^\// )
{
if(ref($sInsideText))
{
$ACTINIC::B2B->SetXML($sTag, $$sInsideText);
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if ($sDigest)
{
$$sInsideText = "";
}
}
}
return "";
}
sub DefaultRemovingTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
my $sXMLTag = $ACTINIC::B2B->GetXML($sTag);
if( defined($sXMLTag) )
{
return $sXMLTag;
}
else
{
if( ref($sInsideText) )
{
$$sInsideText = "";
}
return "";
}
}
sub IgnoreTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( ref($sInsideText) )
{
$$sInsideText = "";
}
return "";
}
sub RemoveTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
my $sTagID;
if( $ParameterHash->{TAG} )
{
$sTagID = $ParameterHash->{TAG};
}
my $sXMLTag = $ACTINIC::B2B->GetXML($sTagID);
if( ref($sInsideText) && !$sXMLTag)
{
$$sInsideText = "";
}
return "";
}
sub BaseHrefTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag =~ /^\// )
{
return "";
}
my $sReplace;
my $sURL;
if (defined $::Session)
{
$sURL = $::Session->GetBaseUrl();
}
if ($$::g_pSetupBlob{'SSL_USEAGE'} == "1")
{
if( $ParameterHash->{VALUE} )
{
$sReplace = $ParameterHash->{VALUE};
}
}
else
{
if ($sURL)
{
$sReplace = $sURL;
}
elsif( $ParameterHash->{VALUE} )
{
$sReplace = $ParameterHash->{VALUE};
}
if ( $ParameterHash->{FORCED} )
{
my $StoreFolderName = ACTINIC::GetStoreFolderName();
$sReplace =~ s/$StoreFolderName\///;
}
}
$$sInsideText = '<BASE HREF="' . $sReplace . '">';
return "";
}
sub NotInB2BTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag !~ /^\// )
{
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if( $sDigest )
{
if( ref($sInsideText) )
{
$$sInsideText = "";
}
}
}
return "";
}
sub UnregTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if( $sTag =~ /^\// )
{
return "";
}
if( $sDigest ||
$::g_bLoginPage )
{
if( ref($sInsideText) ) { $$sInsideText = ""; }
return "";
}
elsif ($::prog_name ne "SearchScript" && $::prog_name ne "SearchHighligh")
{
if ($::g_RECURSION_ACTIVE)
{
return "";
}
my ($Status, $sError, $sHTML) = ACTINIC::ReturnToLastPage(7," " ,
ACTINIC::GetPhrase(-1, 208),
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, %::g_InputHash);
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sError, ACTINIC::GetPath());
}
$::g_RECURSION_ACTIVE = $::TRUE;
ACTINIC::PrintPage($sHTML, undef, $::TRUE);
exit;
}
return "";
}
sub PriceTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag =~ /^\// )
{
return "";
}
if( !$Self->{CurrentSectionBlob} ||
!$ACTINIC::B2B->Get('UserDigest') )
{
return "";
}
my @Response;
if (!$ActinicOrder::bTaxDataParsed)
{
@Response = ACTINIC::ReadTaxSetupFile(ACTINIC::GetPath());
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
ActinicOrder::ParseAdvancedTax();
}
@Response = ACTINIC::GetProduct($ParameterHash->{PROD_REF}, $Self->{CurrentSectionBlob},
ACTINIC::GetPath());
my ($Status, $Message, $pProduct) = @Response;
if ($Status != $::SUCCESS)
{
return "";
}			
if (defined $$pProduct{PRICES})
{
@Response = ActinicOrder::GetProductPricesHTML($pProduct, undef, $Self->{CurrentSectionBlob});
$$sInsideText = ($Response[0] != $::SUCCESS) ? $Response[1] : $Response[2];
}
return "";
}
sub SectionTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId) = @_;
if( $sTag !~ /^\// )
{
$Self->{CurrentSectionBlob} = $ParameterHash->{BLOB};
}
return "";
}
sub MainFrameTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId) = @_;
if( $sTag =~ /^\// )
{
return "";
}
my $sXMLTag;
if( $::g_InputHash{MAINFRAMEURL} )
{
$sXMLTag = $::g_InputHash{MAINFRAMEURL};
}
else
{
$sXMLTag = $ACTINIC::B2B->GetXML("MAINFRAMEURL");
}
if( defined($sXMLTag) )
{
if( ref($sInsideText) )
{
if( $sXMLTag !~ /^((http(s?):)|(\/))/ )
{
if( $sXMLTag eq $$::g_pSetupBlob{FRAMESET_PAGE} )
{
$sXMLTag = $$::g_pSetupBlob{CATALOG_PAGE};
}
if( $sXMLTag eq $$::g_pSetupBlob{BROCHURE_FRAMESET_PAGE} )
{
$sXMLTag = $$::g_pSetupBlob{BROCHURE_MAIN_PAGE};
}
$sXMLTag = $::g_sAccountScript . '?' . ($::g_InputHash{SHOP} ?	'SHOP=' . $::g_InputHash{SHOP} . "&" : "") . 'PRODUCTPAGE=' . $sXMLTag;
}
$$sInsideText =~ s/(\s+SRC\s*=\s*)((\"[^\"]+\")|([^\ \>]+))((\s+)|(\>+))/$1\"$sXMLTag\"$5/is;
}
}
return "";
}
sub LocationTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag =~ /^\// )
{
return "";
}
my $sType = $ParameterHash->{TYPE};
my ($sHTMLFormat, $sHTML, $sReplace);
my $sNonEditableFormat = ACTINIC::GetPhrase(-1, 2066);
my $sEditableFormat = ACTINIC::GetPhrase(-1, 2067, ACTINIC::GetPhrase(-1, 1973), '%s', ACTINIC::GetPhrase(-1, 1970), '%s', '%s', ACTINIC::GetPhrase(0, 18));
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
my ($pAddress,
$plistValidInvoiceAddresses, $plistValidDeliveryAddresses,
$nInvoiceID, $nDeliveryID,
$sCountryInvoiceHTML, $sStateInvoiceHTML,
$sCountryDeliveryHTML, $sStateDeliveryHTML);
$nInvoiceID = -1;
$nDeliveryID = -1;
my ($pSingleInvoiceAddress, $pSingleDeliveryAddress);
if($sDigest ne '')
{
my ($Status, $sMessage, $pBuyer, $pAccount) = ACTINIC::GetBuyerAndAccount($sDigest, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
($Status, $sMessage,
$plistValidInvoiceAddresses, $plistValidDeliveryAddresses,
$nInvoiceID, $nDeliveryID) =
ACTINIC::GetCustomerAddressLists($pBuyer, $pAccount, $::TRUE);
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
if($nInvoiceID != -1)
{
$pSingleInvoiceAddress = pop(@$plistValidInvoiceAddresses);
}
elsif($pBuyer->{InvoiceAddressRule} == 1)
{
($Status, $sMessage, $sCountryInvoiceHTML, $sStateInvoiceHTML) =
ActinicOrder::GetBuyerLocationSelections($plistValidInvoiceAddresses,
'LocationInvoiceCountry', 'LocationInvoiceRegion',
'lstInvoiceCountry', 'lstInvoiceRegion',
'INVOICE', $pBuyer->{InvoiceAddressID});
}
if($nDeliveryID != -1)
{
$pSingleDeliveryAddress = pop(@$plistValidDeliveryAddresses);
}
elsif($pBuyer->{DeliveryAddressRule} == 1)
{
($Status, $sMessage, $sCountryDeliveryHTML, $sStateDeliveryHTML) =
ActinicOrder::GetBuyerLocationSelections($plistValidDeliveryAddresses,
'LocationDeliveryCountry', 'LocationDeliveryRegion',
'lstDeliveryCountry', 'lstDeliveryRegion',
'DELIVERY', $pBuyer->{DeliveryAddressID});
}
}
if(ref($sInsideText))
{
if(!$$::g_pLocationList{EXPECT_INVOICE} && !$$::g_pLocationList{EXPECT_DELIVERY})
{
return('');
}
if($sType eq 'DELIVERSELECTCOUNTRY')
{
if($pSingleDeliveryAddress)
{
$$sInsideText = sprintf($sNonEditableFormat,
ACTINIC::GetCountryName($pSingleDeliveryAddress->{CountryCode}),
'LocationDeliveryCountry',
$pSingleDeliveryAddress->{CountryCode});
}
elsif($sCountryDeliveryHTML ne '')
{
$$sInsideText = $sCountryDeliveryHTML;
}
}
if($sType eq 'DELIVERSELECTSTATE')
{
if($pSingleDeliveryAddress)
{
my $sStateName = ACTINIC::GetCountryName($pSingleDeliveryAddress->{StateCode});
$$sInsideText = sprintf($sNonEditableFormat,
($sStateName ne '') ? $sStateName : '',
'LocationDeliveryRegion',
($sStateName ne '') ? $pSingleDeliveryAddress->{StateCode} : $ActinicOrder::UNDEFINED_REGION);
}
elsif($sStateDeliveryHTML ne '')
{
$$sInsideText = $sStateDeliveryHTML;
}
}
if($sType eq 'INVOICESELECTCOUNTRY')
{
if($pSingleInvoiceAddress)
{
$$sInsideText = sprintf($sNonEditableFormat,
ACTINIC::GetCountryName($pSingleInvoiceAddress->{CountryCode}),
'LocationInvoiceCountry',
$pSingleInvoiceAddress->{CountryCode});
}
elsif($sCountryInvoiceHTML ne '')
{
$$sInsideText = $sCountryInvoiceHTML;
}
}
if($sType eq 'INVOICESELECTSTATE')
{
if($pSingleInvoiceAddress)
{
my $sStateName = ACTINIC::GetCountryName($pSingleInvoiceAddress->{StateCode});
$$sInsideText = sprintf($sNonEditableFormat,
($sStateName ne '') ? $sStateName : '',
'LocationInvoiceRegion',
($sStateName ne '') ? $pSingleInvoiceAddress->{StateCode} : $ActinicOrder::UNDEFINED_REGION);
}
elsif($sStateInvoiceHTML ne '')
{
$$sInsideText = $sStateInvoiceHTML;
}
}
if($sType eq 'SEPARATESHIP')
{
if($::g_LocationInfo{SEPARATESHIP})
{
$sReplace = sprintf($sEditableFormat,
ACTINIC::GetPhrase(-1, 1914),
$sType,
ACTINIC::GetPhrase(-1, 1914));
}
else
{
$sReplace = sprintf($sEditableFormat,
ACTINIC::GetPhrase(-1, 1915),
$sType,
"");
}
$$sInsideText =~ s/<INPUT .*?>/$sReplace/ig;
my $sPrompt = quotemeta ACTINIC::GetPhrase(0, 16);
$sReplace = ACTINIC::GetPhrase(0, 19);
if($sPrompt ne '')
{
$$sInsideText =~ s/$sPrompt/$sReplace/;
}
}
if($$::g_pLocationList{EXPECT_INVOICE} ||
($$::g_pLocationList{EXPECT_DELIVERY} && $::g_LocationInfo{SEPARATESHIP} eq ''))
{
my $nCountryCount;
if($$::g_pLocationList{EXPECT_INVOICE})
{
$nCountryCount = $$::g_pLocationList{INVOICE_COUNTRY_COUNT};
}
else
{
$nCountryCount = $$::g_pLocationList{DELIVERY_COUNTRY_COUNT};
}
if($sType eq 'INVOICEPOSTALCODE')
{
if($nInvoiceID != -1)
{
$sReplace = sprintf($sNonEditableFormat,
$::g_LocationInfo{INVOICEPOSTALCODE},
$sType,
$::g_LocationInfo{INVOICEPOSTALCODE});
$$sInsideText =~ s/<INPUT .*?>/$sReplace/ig;
}
elsif((defined $$::g_pLocationList{INVOICEPOSTALCODE} &&
$$::g_pLocationList{INVOICEPOSTALCODE}) ||
(defined $$::g_pLocationList{DELIVERPOSTALCODE} &&
$$::g_pLocationList{DELIVERPOSTALCODE} &&
$::g_LocationInfo{SEPARATESHIP} eq ''))
{
$sReplace = sprintf($sEditableFormat,
$::g_LocationInfo{INVOICEPOSTALCODE},
$sType,
$::g_LocationInfo{INVOICEPOSTALCODE});
$$sInsideText =~ s/<INPUT .*?>/$sReplace/ig;
}
}
elsif($sType eq 'INVOICEADDRESS3')
{
}
elsif($sType eq 'INVOICEADDRESS4')
{
if(((defined $$::g_pLocationList{INVOICEADDRESS4} &&
$$::g_pLocationList{INVOICEADDRESS4}) ||
(defined $$::g_pLocationList{DELIVERADDRESS4} &&
$$::g_pLocationList{DELIVERADDRESS4} &&
$::g_LocationInfo{SEPARATESHIP} eq '')) &&
$::g_LocationInfo{INVOICE_REGION_CODE} &&
$::g_LocationInfo{INVOICE_REGION_CODE} ne $ActinicOrder::UNDEFINED_REGION)
{
if($$::g_pLocationList{$::g_LocationInfo{INVOICE_COUNTRY_CODE}}{INVOICE_STATE_COUNT} < 2)
{
$sHTMLFormat = $sNonEditableFormat;
}
else
{
$sHTMLFormat = $sEditableFormat;
}
$sReplace = sprintf($sHTMLFormat,
ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_REGION_CODE}),
$sType,
ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_REGION_CODE}));
$$sInsideText =~ s/<INPUT .*?>/$sReplace/ig;						
}
else
{
$sReplace = ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_REGION_CODE});
$$sInsideText =~ s/VALUE\s*=\s*("|').*('|")/VALUE="$sReplace"/ig;	;
}				
}
elsif($sType eq 'INVOICECOUNTRY')
{
if(($$::g_pLocationList{INVOICECOUNTRY} ||
($$::g_pLocationList{DELIVERCOUNTRY} && $::g_LocationInfo{SEPARATESHIP} eq '')))
{
my $sKnownCountryCode;
if($$::g_pLocationList{INVOICECOUNTRY})
{
if($::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $ActinicOrder::UNDEFINED_COUNTRY &&
$::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
$sKnownCountryCode = $::g_LocationInfo{INVOICE_COUNTRY_CODE};
}
}
elsif($$::g_pLocationList{DELIVERCOUNTRY} && $::g_LocationInfo{SEPARATESHIP} eq '')
{
if($::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne $ActinicOrder::UNDEFINED_COUNTRY &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
$sKnownCountryCode = $::g_LocationInfo{DELIVERY_COUNTRY_CODE};
}
}
if($sKnownCountryCode eq '')
{
return('');
}
if($nCountryCount < 2)
{
$sHTMLFormat = $sNonEditableFormat;
}
else
{
$sHTMLFormat = $sEditableFormat;
}
$sReplace = sprintf($sHTMLFormat,
ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_COUNTRY_CODE}),
$sType,
ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_COUNTRY_CODE}));
$$sInsideText =~ s/<INPUT .*?>/$sReplace/ig;
}
}
}
if($$::g_pLocationList{EXPECT_DELIVERY} ||
($$::g_pLocationList{EXPECT_INVOICE} && $::g_LocationInfo{SEPARATESHIP} eq ''))
{
my $nCountryCount;
if($$::g_pLocationList{EXPECT_DELIVERY})
{
$nCountryCount = $$::g_pLocationList{DELIVERY_COUNTRY_COUNT};
}
else
{
$nCountryCount = $$::g_pLocationList{INVOICE_COUNTRY_COUNT};
}
if($sType eq 'DELIVERPOSTALCODE')
{
if($$::g_pLocationList{DELIVERPOSTALCODE})
{
$sReplace = sprintf($sEditableFormat,
$::g_LocationInfo{DELIVERPOSTALCODE},
$sType,
$::g_LocationInfo{DELIVERPOSTALCODE});
$$sInsideText =~ s/<INPUT .*?>/$sReplace/ig;
}
}
elsif($sType eq 'DELIVERADDRESS3')
{
}
elsif($sType eq 'DELIVERADDRESS4')
{
if($::g_LocationInfo{DELIVERY_REGION_CODE} &&
$::g_LocationInfo{DELIVERY_REGION_CODE} ne $ActinicOrder::UNDEFINED_REGION &&
(defined $$::g_pLocationList{DELIVERADDRESS4} &&
$$::g_pLocationList{DELIVERADDRESS4}))
{
if($$::g_pLocationList{$::g_LocationInfo{DELIVERY_COUNTRY_CODE}}{DELIVERY_STATE_COUNT} < 2)
{
$sHTMLFormat = $sNonEditableFormat;
}
else
{
$sHTMLFormat = $sEditableFormat;
}
$sReplace = sprintf($sHTMLFormat,
ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_REGION_CODE}),
$sType,
ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_REGION_CODE}));
$$sInsideText =~ s/<INPUT .*?>/$sReplace/ig;
}
else
{
$sReplace = ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_REGION_CODE});
$$sInsideText =~ s/VALUE\s*=\s*("|').*('|")/VALUE="$sReplace"/ig;	;
}					
}
elsif($sType eq 'DELIVERCOUNTRY')
{
if($::g_LocationInfo{DELIVERY_COUNTRY_CODE} &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne $ActinicOrder::UNDEFINED_COUNTRY &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
if($nCountryCount < 2)
{
$sHTMLFormat = $sNonEditableFormat;
}
else
{
$sHTMLFormat = $sEditableFormat;
}
$sReplace = sprintf($sHTMLFormat,
ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_COUNTRY_CODE}),
$sType,
ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_COUNTRY_CODE}));
$$sInsideText =~ s/<INPUT .*?>/$sReplace/ig;
}
}
}
}
return('');
}
sub ExtraFooterTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag !~ /^\// )
{
if(ref($sInsideText))
{
my $nSSPProviderID;
my $sTemplate = $$sInsideText;
$$sInsideText = '';
my %hTrademarkProviderIDs;
if ($ACTINIC::B2B->GetXML('ShippingDisclaimingDisplayed') == $::TRUE)
{
%hTrademarkProviderIDs = (%::s_Ship_hShippingClassProviderIDs, %::s_Ship_hBasePlusPerProviderIDs); # collect shipping class providers and base-plus-per providers
}
if ($::s_Ship_bDisplayExtraCartInformation &&
$::s_Ship_nSSPProviderID != -1)
{
$hTrademarkProviderIDs{$::s_Ship_nSSPProviderID} = $::TRUE;
}
foreach $nSSPProviderID (keys %hTrademarkProviderIDs)
{
my %hVariables;
$hVariables{$::VARPREFIX . 'POWEREDBYLOGO'} = $$::g_pSSPSetupBlob{$nSSPProviderID}{'POWERED_BY_LOGO'};
$hVariables{$::VARPREFIX . 'TRADEMARKS'} = $$::g_pSSPSetupBlob{$nSSPProviderID}{'TRADEMARKS'};
my @Response = ACTINIC::TemplateString($sTemplate, \%hVariables);
my ($Status, $Message, $sLine) = @Response;
if ($Status != $::SUCCESS)
{
$$sInsideText = '';
return ('');
}
$$sInsideText .= $sLine;
}
return ('');
}
}
$$sInsideText = '';
return('');
}
sub ExtraCartTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag !~ /^\// )
{
if(ref($sInsideText))
{
if ($::s_Ship_bDisplayExtraCartInformation &&
$::s_Ship_nSSPProviderID != -1 &&
$::s_Ship_sOpaqueShipData !~ /BasePlusIncrement/)
{
my %hVariables;
$hVariables{$::VARPREFIX . 'POWEREDBYLOGO'} = $$::g_pSSPSetupBlob{$::s_Ship_nSSPProviderID}{'POWERED_BY_LOGO'};
$hVariables{$::VARPREFIX . 'RATEDISCLAIMER'} = $$::g_pSSPSetupBlob{$::s_Ship_nSSPProviderID}{'RATE_DISCLAIMER'};
my @Response = ACTINIC::TemplateString($$sInsideText, \%hVariables);
my ($Status, $Message, $sLine) = @Response;
if ($Status == $::SUCCESS)
{
$$sInsideText = $sLine;
return ('');
}
}
}
}
$$sInsideText = '';
return('');
}
sub ExtraCartBasePlusPerTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag !~ /^\// )
{
if(ref($sInsideText))
{
if ($::s_Ship_bDisplayExtraCartInformation &&
$::s_Ship_nSSPProviderID != -1 &&
$::s_Ship_sOpaqueShipData =~ /BasePlusIncrement/)
{
my %hVariables;
$hVariables{$::VARPREFIX . 'BASE_PLUS_PER_RATE_DISCLAIMER'} = $$::g_pSSPSetupBlob{$::s_Ship_nSSPProviderID}{'BASE_PLUS_PER_RATE_DISCLAIMER'};
my @Response = ACTINIC::TemplateString($$sInsideText, \%hVariables);
my ($Status, $Message, $sLine) = @Response;
if ($Status == $::SUCCESS)
{
$$sInsideText = $sLine;
return ('');
}
}
}
}
$$sInsideText = '';
return('');
}
sub ExtraShippingTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag !~ /^\// )
{
if(ref($sInsideText))
{
$ACTINIC::B2B->SetXML('ShippingDisclaimingDisplayed', $::TRUE);
my $nSSPProviderID;
my $sTemplate = $$sInsideText;
$$sInsideText = '';
foreach $nSSPProviderID (keys %::s_Ship_hShippingClassProviderIDs)
{
my %hVariables;
$hVariables{$::VARPREFIX . 'POWEREDBYLOGO'} = $$::g_pSSPSetupBlob{$nSSPProviderID}{'POWERED_BY_LOGO'};
$hVariables{$::VARPREFIX . 'RATEDISCLAIMER'} = $$::g_pSSPSetupBlob{$nSSPProviderID}{'RATE_DISCLAIMER'};
my @Response = ACTINIC::TemplateString($sTemplate, \%hVariables);
my ($Status, $Message, $sLine) = @Response;
if ($Status != $::SUCCESS)
{
$$sInsideText = '';
return ('');
}
$$sInsideText .= $sLine;
}
return ('');
}
}
$$sInsideText = '';
return('');
}
sub BasePlusPerInfoTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag !~ /^\// )
{
if(ref($sInsideText))
{
$ACTINIC::B2B->SetXML('ShippingDisclaimingDisplayed', $::TRUE);
my $nSSPProviderID;
my $sTemplate = $$sInsideText;
$$sInsideText = '';
foreach $nSSPProviderID (keys %::s_Ship_hBasePlusPerProviderIDs)
{
my %hVariables;
$hVariables{$::VARPREFIX . 'BASE_PLUS_PER_RATE_DISCLAIMER'} = $$::g_pSSPSetupBlob{$nSSPProviderID}{'BASE_PLUS_PER_RATE_DISCLAIMER'};
my @Response = ACTINIC::TemplateString($sTemplate, \%hVariables);
my ($Status, $Message, $sLine) = @Response;
if ($Status != $::SUCCESS)
{
$$sInsideText = '';
return ('');
}
$$sInsideText .= $sLine;
}
return ('');
}
}
$$sInsideText = '';
return('');
}
sub DefaultTaxZoneMessageTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if( $sTag !~ /^\// )
{
return "";
}
if(ref($sInsideText))
{
if($ActinicOrder::s_nContext != $ActinicOrder::FROM_CART)
{
return('');
}
my ($sMessage, $sLocationDescription);
my $sFontOpen = ACTINIC::GetPhrase(-1, 1967);
my $sFontClose = ACTINIC::GetPhrase(-1, 1970);
if($::g_pTaxSetupBlob->{TAX_BY} != $ActinicOrder::eTaxAlways)
{
$sLocationDescription = ACTINIC::GetPhrase(-1, 2084);
if($::g_pTaxSetupBlob->{TAX_BY} == $ActinicOrder::eTaxByInvoice)
{
if(defined $::g_LocationInfo{INVOICE_COUNTRY_CODE} &&
$::g_LocationInfo{INVOICE_COUNTRY_CODE} ne '' &&
$::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $ActinicOrder::UNDEFINED_REGION &&
$::g_LocationInfo{INVOICE_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
if(defined $::g_LocationInfo{INVOICE_REGION_CODE} &&
$::g_LocationInfo{INVOICE_REGION_CODE} ne '' &&
$::g_LocationInfo{INVOICE_REGION_CODE} ne $ActinicOrder::UNDEFINED_REGION)
{
$sLocationDescription = ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_REGION_CODE});
}
else
{
$sLocationDescription = ACTINIC::GetCountryName($::g_LocationInfo{INVOICE_COUNTRY_CODE});
}
}
}
else
{
if(defined $::g_LocationInfo{DELIVERY_COUNTRY_CODE} &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne '' &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne $ActinicOrder::UNDEFINED_REGION &&
$::g_LocationInfo{DELIVERY_COUNTRY_CODE} ne $ActinicOrder::REGION_NOT_SUPPLIED)
{
if(defined $::g_LocationInfo{DELIVERY_REGION_CODE} &&
$::g_LocationInfo{DELIVERY_REGION_CODE} ne '' &&
$::g_LocationInfo{DELIVERY_REGION_CODE} ne $ActinicOrder::UNDEFINED_REGION)
{
$sLocationDescription = ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_REGION_CODE});
}
else
{
$sLocationDescription = ACTINIC::GetCountryName($::g_LocationInfo{DELIVERY_COUNTRY_CODE});
}
}
}
my $bRequestInfoEarly = $$::g_pSetupBlob{'TAX_AND_SHIP_EARLY'};
my $sMessage = $sFontOpen . sprintf(ACTINIC::GetPhrase(-1, 2083), $sLocationDescription);
$sMessage .= $sFontClose;
$$sInsideText = $sMessage;
}
else
{
$$sInsideText = '';
}
}
return('');
}
sub ShowForPriceScheduleTagHandler
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
if ($sTag =~ /^\//)
{
return ('');
}
my $nScheduleID = $ActinicOrder::RETAILID;
my ($Status, $sMessage, $pBuyer, $pAccount);
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if ($sDigest)
{
my ($Status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sDigest, ACTINIC::GetPath());
if ($Status == $::SUCCESS)
{
($Status, $sMessage, $pAccount) = ACTINIC::GetCustomerAccount($pBuyer->{AccountID}, ACTINIC::GetPath());
if ($Status == $::SUCCESS)
{
$nScheduleID = $pAccount->{PriceSchedule}
}
}
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
}
if ($ParameterHash->{'HTML'})
{
$$sInsideText = $ParameterHash->{'HTML'};
}
my @aIncludedScheduleIds = split(/,/, $ParameterHash->{'Schedules'});
my $nIncludedScheduleId;
foreach $nIncludedScheduleId (@aIncludedScheduleIds)
{
if ($nIncludedScheduleId eq $nScheduleID)
{
return '';
}
}
$$sInsideText = '';
return ('');
}
sub GetTemplateFragment
{
my $pXML = shift;
my $sFragment = shift;
my $pNode = $pXML->FindNode("XMLTEMPLATE", "NAME", $sFragment);
if (!$pNode)
{
return("");
}
return ($pNode->GetOriginal());
}
sub AddCookieCheck
{
my $Self = shift;
my ($sTag,  $sInsideText, $ParameterHash, $sId, $sFullTag) = @_;
my $sScript = '';
if ($::bCookieCheckRequired)
{
my $sCgiUrl = ACTINIC::GetScriptUrl($::sShoppingScriptID);
$sCgiUrl   .= '?ACTION=COOKIEERROR';
$sScript = '<SCRIPT LANGUAGE="JavaScript" TYPE="text/javascript">';
$sScript .= 'if (document.cookie.indexOf("ACTINIC_CART=") == -1)';
$sScript .= 'document.location.replace("' . $sCgiUrl . '");';
$sScript .= '</SCRIPT>';
}
$$sInsideText = $sScript;
return ('');
}
1;