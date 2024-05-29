#!perl
package Session;
use strict;
push (@INC, "cgi-bin");
use px000001;
require al000001;
require ac000001;
$Session::prog_name = 'Session.pm';
$Session::prog_name = $Session::prog_name;
$Session::prog_ver = '$Revision: 20560 $ ';
$Session::prog_ver = substr($Session::prog_ver, 11);
$Session::prog_ver =~ s/ \$//;
$Session::SESSIONFILEVERSION = "1.0";
$Session::XML_ROOT				= 'SessionFile';
$Session::XML_URLINFO			= 'URLInfo';
$Session::XML_CHECKOUTINFO		= 'CheckoutInfo';
$Session::XML_SHOPPINGCART 	= 'ShoppingCart';
$Session::XML_BASEURL 		= "BASEURL";
$Session::XML_LASTSHOPPAGE = "LASTSHOPPAGE";
$Session::XML_LASTPAGE 		= "LASTPAGE";
$Session::XML_CLOSED 		= "Closed";
$Session::XML_PAYMENT 		= "Payment";
$Session::XML_IPCHECK 		= "IPCheck";
$Session::XML_DIGEST			= "Digest";
$Session::XML_CHECKOUTSTARTED	= "CheckoutStarted";
$Session::XML_PPTOKEN		= "Token";
$Session::XML_PPPAYERID		= "PayerID";
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $sSessionID 	= shift;
my $sCookieString = shift;
my $sPath			= shift;
my $sCallerID		= shift;
my $bCallBack		= shift;
if (!defined $bCallBack || $bCallBack != $::TRUE)
{
$bCallBack = $::FALSE;
}
my $Self  = {};
bless ($Self, $Class);
$Self->Set(@_);
$Self->{_PATH}						= $sPath;
$Self->{_OLDSESSIONID}			= $sSessionID;
$Self->{_NEWESTSAVEDCARTTIME}	= 0;
$Self->ClearOldFiles();
$Self->CheckForBadPaths();
if ($sSessionID eq "")
{
my @Response = $Self->CreateSessionID();
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], $Self->GetSessionFileFolder());
}
}
else
{
$Self->{_SESSIONID} 	= $sSessionID;
}
$Self->{_SESSIONFILE} 	= $Self->{_SESSIONID} . ".session";
$Self->{_COOKIESTRING}	= $sCookieString;
my $sFullFileName = $Self->GetSessionFileFolder() . $Self->{_SESSIONFILE};
$Self->{_LOCKER} = new SessionLock($sFullFileName);
$Self->{_SESSIONINFO} = new Element({'_TAG' => $Session::XML_ROOT, '_PARAMETERS' => {'Version' => $Session::SESSIONFILEVERSION}});
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_URLINFO, "");
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_CHECKOUTINFO, "");
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_SHOPPINGCART, "");
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_PAYMENT, "");
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_IPCHECK, "");
$Self->{_ISCALLBACK} = $bCallBack;
$Self->{_NEWSESSIONFILE} = $::FALSE;
$Self->RestoreSession();
if ($Self->{_NEWSESSIONFILE} &&
!$sCallerID &&
$::g_InputHash{'ACTION'} ne ACTINIC::GetPhrase(-1, 113) &&
$::g_InputHash{'ACTION'} ne "PPSTARTCHECKOUT" &&
$::g_InputHash{'ACTION'} !~ /^OFFLINE_AUTHORIZE/i)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 2249), $Self->GetSessionFileFolder());
}
my ($sDigest,$sBaseFile) = ACTINIC::CaccGetCookies();
if (!$Self->{_ISCALLBACK} && ($Self->GetDigest() ne $sDigest))
{
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_SHOPPINGCART, "");
$Self->UpdateCheckoutInfo({}, {}, {}, {}, {}, {}, {});
$Self->SetDigest($sDigest);
$Self->GetURLInfo()->SetTextNode($Session::XML_LASTSHOPPAGE, "");
$Self->GetURLInfo()->SetTextNode($Session::XML_BASEURL, "");
$Self->GetURLInfo()->SetTextNode($Session::XML_LASTPAGE, "");
}
if ($Self->IsClosed() &&
$sCallerID)
{
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_SHOPPINGCART, "");
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_CLOSED, "");
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_CHECKOUTSTARTED, "");
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_PAYMENT, "");
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_IPCHECK, "");
if ($sDigest eq "")
{
$Self->UpdateCheckoutInfo({}, {}, {}, {}, {}, {}, {});
my $pRemember = $Self->GetCheckoutInfo()->GetChildNode('BillContact');
if (defined $pRemember ||
defined $pRemember->GetChildNode('REMEMBERME')	||
defined $pRemember->GetChildNode('REMEMBERME')->GetNodeValue() ||
$pRemember->GetChildNode('REMEMBERME')->GetNodeValue() == $::TRUE )
{
$Self->CookieStringToContactDetails();
}
}
}
$Self->InitURLs();
return $Self;
}
sub GetURLInfo
{
my $Self = shift;
return $Self->{_SESSIONINFO}->GetChildNode($Session::XML_URLINFO);
}
sub GetCheckoutInfo
{
my $Self = shift;
return $Self->{_SESSIONINFO}->GetChildNode($Session::XML_CHECKOUTINFO);
}
sub GetCartInfo
{
my $Self = shift;
return $Self->{_SESSIONINFO}->GetChildNode($Session::XML_SHOPPINGCART);
}
sub SetCartInfo
{
my $Self = shift;
my $pXmlCartItems = shift;
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_SHOPPINGCART, "");
my $pShoppingCart = $Self->{_SESSIONINFO}->GetChildNode($Session::XML_SHOPPINGCART);
my $pXmlCartItem;
foreach $pXmlCartItem (@{$pXmlCartItems})
{
$pShoppingCart->AddChildNode($pXmlCartItem);
}
}
sub Set
{
my $Self       = shift;
my %Parameters = @_;
foreach (keys %Parameters)
{
$Self->{$_} = $Parameters{$_};
}
}
sub Get
{
my $Self		= shift;
my $sParam 	= shift;
return $Self->{$sParam};
}
sub GetSessionID
{
my $Self		= shift;
return $Self->{_SESSIONID};
}
sub GetBaseUrl
{
my $Self		= shift;
my $sURL = $Self->GetURLInfo()->GetChildNode($Session::XML_BASEURL)->GetNodeValue();
$sURL =~ s|/[^/]*$|/|;
return $sURL;
}
sub GetLastShopPage
{
my $Self		= shift;
if (!$Self->GetURLInfo()->IsElementNode() ||
($Self->GetURLInfo()->IsElementNode() &&
!$Self->GetURLInfo()->GetChildNode($Session::XML_LASTSHOPPAGE)))
{
return $Self->GetBaseUrl();
}
else
{
return $Self->GetURLInfo()->GetChildNode($Session::XML_LASTSHOPPAGE)->GetNodeValue();
}
}
sub GetLastPage
{
my $Self		= shift;
return $Self->GetURLInfo()->GetChildNode($Session::XML_LASTPAGE)->GetNodeValue();
}
sub IPCheckFailed
{
my $Self		= shift;
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_IPCHECK, "Failed");
}
sub IsIPCheckFailed
{
my $Self		= shift;
my $pNode = $Self->{_SESSIONINFO}->GetChildNode($Session::XML_IPCHECK);
if (!$pNode || $pNode->GetNodeValue() ne "Failed")
{
return $::FALSE;
}
return $::TRUE;
}
sub PaymentMade
{
my $Self		= shift;
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_PAYMENT, "True");
}
sub ClearPaymentMade
{
my $Self		= shift;
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_PAYMENT, "");
}
sub IsPaymentMade
{
my $Self		= shift;
my $pNode = $Self->{_SESSIONINFO}->GetChildNode($Session::XML_PAYMENT);
if (!$pNode || $pNode->GetNodeValue() ne "True")
{
return $::FALSE;
}
return $::TRUE;
}
sub SetPaypalProIDs
{
my $Self		= shift;
my $sToken	= shift;
my $sPayerID = shift;
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_PPTOKEN, $sToken);
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_PPPAYERID, $sPayerID);
}
sub GetPaypalProIDs
{
my $Self		= shift;
my ($sToken, $sPayerID);
my $pNode = $Self->{_SESSIONINFO}->GetChildNode($Session::XML_PPTOKEN);
if ($pNode)
{
$sToken = $pNode->GetNodeValue();
}
undef $pNode;
my $pNode = $Self->{_SESSIONINFO}->GetChildNode($Session::XML_PPPAYERID);
if ($pNode)
{
$sPayerID = $pNode->GetNodeValue();
}
return ($sToken, $sPayerID);
}
sub MarkAsClosed
{
my $Self		= shift;
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_CLOSED, "True");
}
sub IsClosed
{
my $Self		= shift;
my $pNode = $Self->{_SESSIONINFO}->GetChildNode($Session::XML_CLOSED);
if (!$pNode || $pNode->GetNodeValue() ne "True")
{
return $::FALSE;
}
return $::TRUE;
}
sub SetCheckoutStarted
{
my $Self		= shift;
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_CHECKOUTSTARTED, "True");
}
sub IsCheckoutStarted
{
my $Self		= shift;
my $pNode = $Self->{_SESSIONINFO}->GetChildNode($Session::XML_CHECKOUTSTARTED);
if (!$pNode || $pNode->GetNodeValue() ne "True")
{
return $::FALSE;
}
return $::TRUE;
}
sub SetDigest
{
my $Self		= shift;
my $sDigest	= shift;
$Self->{_SESSIONINFO}->SetTextNode($Session::XML_DIGEST, $sDigest);
}
sub GetDigest
{
my $Self		= shift;
my $pNode = $Self->{_SESSIONINFO}->GetChildNode($Session::XML_DIGEST);
if ($pNode)
{
return  $pNode->GetNodeValue();
}
return "";
}
sub IsCallBack
{
my $Self		= shift;
return $Self->{_ISCALLBACK};
}
sub SetCallBack
{
my $Self		= shift;
my $IsCallBack = shift;
$Self->{_ISCALLBACK} = $IsCallBack;
}
sub SetCoupon
{
my $Self 	= shift;
my $sCoupon = shift;
$Self->GetCheckoutInfo()->GetChildNode('PaymentInfo')->SetTextNode("COUPONCODE", $sCoupon);
}
sub SetReferrer
{
my $Self 	= shift;
my $sReferrer = shift;
$Self->GetCheckoutInfo()->GetChildNode('GeneralInfo')->SetTextNode("USERDEFINED", $sReferrer);
}
sub GetReferrer
{
my $Self 	= shift;
my $sReferrer;
if ($Self->GetCheckoutInfo()->IsElementNode() &&
$Self->GetCheckoutInfo()->GetChildNode('GeneralInfo') &&
$Self->GetCheckoutInfo()->GetChildNode('GeneralInfo')->GetChildNode("USERDEFINED") &&
$Self->GetCheckoutInfo()->GetChildNode('GeneralInfo')->GetChildNode("USERDEFINED")->IsTextNode())
{
$sReferrer = $Self->GetCheckoutInfo()->GetChildNode('GeneralInfo')->GetChildNode("USERDEFINED")->GetNodeValue();
}
return $sReferrer;
}
sub UpdateCheckoutInfo
{
my $Self = shift;
my ($pBillContact, $pShipContact, $pShipInfo, $pTaxInfo,
$pGeneralInfo, $pPaymentInfo, $pLocationInfo) = @_;
if ($Self->IsClosed())
{
return ($::SUCCESS, "", "");
}
$Self->GetCheckoutInfo()->SetChildNode(Element::CreateElementFromLegacyStructure('BillContact', $pBillContact));
$Self->GetCheckoutInfo()->SetChildNode(Element::CreateElementFromLegacyStructure('ShipContact', $pShipContact));
$Self->GetCheckoutInfo()->SetChildNode(Element::CreateElementFromLegacyStructure('ShipInfo', $pShipInfo));
$Self->GetCheckoutInfo()->SetChildNode(Element::CreateElementFromLegacyStructure('TaxInfo', $pTaxInfo));
$Self->GetCheckoutInfo()->SetChildNode(Element::CreateElementFromLegacyStructure('GeneralInfo', $pGeneralInfo));
$Self->GetCheckoutInfo()->SetChildNode(Element::CreateElementFromLegacyStructure('PaymentInfo', $pPaymentInfo));
$Self->GetCheckoutInfo()->SetChildNode(Element::CreateElementFromLegacyStructure('LocationInfo', $pLocationInfo));
return ($::SUCCESS, "", "");
}
sub RestoreCheckoutInfo
{
my $Self 			= shift;
return ($::SUCCESS, '',
$Self->GetCheckoutInfo()->GetChildNode('BillContact')->ToLegacyStructure(),
$Self->GetCheckoutInfo()->GetChildNode('ShipContact')->ToLegacyStructure(),
$Self->GetCheckoutInfo()->GetChildNode('ShipInfo')->ToLegacyStructure(),
$Self->GetCheckoutInfo()->GetChildNode('TaxInfo')->ToLegacyStructure(),
$Self->GetCheckoutInfo()->GetChildNode('GeneralInfo')->ToLegacyStructure(),
$Self->GetCheckoutInfo()->GetChildNode('PaymentInfo')->ToLegacyStructure(),
$Self->GetCheckoutInfo()->GetChildNode('LocationInfo')->ToLegacyStructure());
}
sub IsCheckoutInfoChanged
{
my $Self 		= shift;
my $sNodeName 	= shift;
my $pHash		= shift;
if (!defined $Self->GetCheckoutInfo() ||
!defined $Self->GetCheckoutInfo()->GetChildNode($sNodeName))
{
return $::FALSE;
}
my $pBaseNode = $Self->GetCheckoutInfo()->GetChildNode($sNodeName);
if (!$pBaseNode->IsElementNode())
{
return $::FALSE;
}
for (my $i = 0; $i < $pBaseNode->GetChildNodeCount(); $i++)
{
my $pChildNode = $pBaseNode->GetChildNodeAt($i);
if ($pHash->{$pChildNode->GetTag()} != $pChildNode->GetNodeValue())
{
return $::TRUE;
}
}
return $::FALSE;
}
sub GetCartObject
{
my $Self				= shift;
my $bIgonreClose 	= shift;
if ($Self->IsClosed() && !$bIgonreClose)
{
return ($::EOF, ACTINIC::GetPhrase(-1, 1282), []);
}
if (!defined $Self->{_CART})
{
require cm000001;
if ($Self->{_SESSIONINFO}->GetChildNode($Session::XML_SHOPPINGCART)->IsElementNode())
{
$Self->{_CART} = Cart::new("Cart", $Self->{_SESSIONID}, $Self->{_PATH}, $Self->GetCartInfo()->GetChildNodes(), $Self->IsCallBack());
}
else
{
$Self->{_CART} = Cart::new("Cart", $Self->{_SESSIONID}, $Self->{_PATH}, [], $Self->IsCallBack());
}
}
return ($::SUCCESS, "", $Self->{_CART});
}
sub RestoreSession
{
my $Self	= shift;
my $sFileName 	= $Self->GetSessionFileName($Self->{_SESSIONID});
my $bSessionLockIsNeeded = $::FALSE;
if (defined $::g_pPaymentList &&
(($$::g_pPaymentList{$::PAYMENT_PAYPAL}{ENABLED} == 1)	||
($$::g_pPaymentList{$::PAYMENT_NOCHEX}{ENABLED} == 1)))
{
$bSessionLockIsNeeded = $::TRUE;
}
if (! (-e $sFileName)  ||
-z $sFileName)
{
$Self->{_NEWSESSIONFILE} = $::TRUE;
my @Response = $Self->RestoreOldChkFile($Self->{_PATH} . $Self->{_SESSIONID} . ".chk");
if ($Response[0] != $::SUCCESS)
{
if ($::FAILURE == $Self->CookieStringToContactDetails())
{
$Self->UpdateCheckoutInfo({}, {}, {}, {}, {}, {}, {});
}
}
}
else
{
$Self->GetXMLTree();
}
if ($bSessionLockIsNeeded == $::TRUE)
{
if ($Self->{_LOCKER}->Lock() != $SessionLock::SUCCESS)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 2310, $sFileName), $Self->GetSessionFileFolder());
}
}
}
sub GetSessionFileFolder
{
my $Self			= shift;
if ($$::g_pSetupBlob{'PATH_TO_CART'} ne "" &&
!$ACTINIC::ActinicHostMode)
{
return($$::g_pSetupBlob{'PATH_TO_CART'});
}
else
{
return($Self->{_PATH});
}
}
sub Unlock
{
my $Self			= shift;
my $sFile		= shift;
if ($$::g_pSetupBlob{'CART_PERMISSIONS_UNLOCK'} ne "" &&
!$ACTINIC::ActinicHostMode)
{
chmod oct($$::g_pSetupBlob{'CART_PERMISSIONS_UNLOCK'}), $sFile;
}
else
{
ACTINIC::ChangeAccess("rw", $sFile);
}
}
sub Lock
{
my $Self			= shift;
my $sFile		= shift;
if ($$::g_pSetupBlob{'CART_PERMISSIONS_LOCK'} ne "" &&
!$ACTINIC::ActinicHostMode)
{
chmod oct($$::g_pSetupBlob{'CART_PERMISSIONS_LOCK'}), $sFile;
}
else
{
ACTINIC::ChangeAccess("", $sFile);
}
}
sub GetXMLTree
{
my $Self			= shift;
my $sFileName  = $Self->GetSessionFileFolder() . $Self->{_SESSIONFILE};
my $pParser 	= new PXML;
$Self->Unlock($sFileName);
my @Response = $pParser->ParseFile($sFileName);
$Self->Lock($sFileName);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], $Self->GetSessionFileFolder());
}
$Self->{_SESSIONINFO} = new Element(@{$Response[2]}[0]);
}
sub SaveSession
{
my $Self			= shift;
my $sFileName 	= $Self->GetSessionFileFolder() . $Self->{_SESSIONFILE};
my $pParser 	= new PXML;
if ($Self->{_CART})
{
$Self->{_CART}->UpdateCart();
$Self->SetCartInfo($Self->{_CART}->GetCart());
}
my $pXmlRoot = [$Self->{_SESSIONINFO}];
$Self->Unlock($sFileName);
my @Response = $pParser->SaveXMLFile($sFileName, $pXmlRoot);
$Self->Lock($sFileName);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], $Self->GetSessionFileFolder());
}
}
sub ClearOldFiles
{
my $Self = shift;
my $sPath = $Self->GetSessionFileFolder();
my (@FileList, @Response, $Status, $Message);
@Response = ACTINIC::ReadTheDir($sPath);
($Status, $Message, @FileList) = @Response;
if ($Status != $::SUCCESS)
{
return;
}
my ($sFile, $sFilePath, @stat, $Now, $LifeSpan);
foreach $sFile (@FileList)
{
my (@FileParts);
@FileParts = split (/\./, $sFile);
my $sExtension = $FileParts[$#FileParts];
if ($sExtension ne "chk" &&
$sExtension ne "cart" &&
$sExtension ne "done" &&
$sExtension ne "save" &&
$sExtension ne "session" &&
$sExtension ne "mail")
{
next;
}
$sFilePath = $sPath.$sFile;
@stat = stat $sFilePath;
$Now = time;
$LifeSpan = 60 * 60 * $$::g_pSetupBlob{'CART_EXPIRY'};
my $bMySavedUnRegCart = $::FALSE;
if ($sExtension eq "save")
{
if ($FileParts[-2] =~ /^reg_(\d*)_(\d*)$/)
{
$LifeSpan = 60 * 60 * 24 * $$::g_pSetupBlob{'REG_SHOPPING_LIST_EXPIRY'};
}
else
{
if ($FileParts[-2] =~ /^$Self->{_OLDSESSIONID}_(\d*)$/)
{
$bMySavedUnRegCart = $::TRUE;
}
$LifeSpan = 60 * 60 * 24 * $$::g_pSetupBlob{'UNREG_SHOPPING_LIST_EXPIRY'};
}
}
if ( ($Now - $LifeSpan) < $stat[9])
{
if ($bMySavedUnRegCart &&
($stat[9] > $Self->{_NEWESTSAVEDCARTTIME}))
{
$Self->{_NEWESTSAVEDCARTTIME} = $stat[9];
}
next;
}
ACTINIC::ChangeAccess("rw", $sFilePath);
ACTINIC::SecurePath($sFilePath);
if ($sExtension eq "session")
{
if (-e "$sFilePath.OPN")
{
unlink "$sFilePath.OPN";
}
if (-e "$sFilePath.LCK")
{
unlink "$sFilePath.LCK";
}
}
unlink ($sFilePath);
}
}
sub CheckForBadPaths
{
if (defined $::g_InputHash{PRODUCTPAGE})
{
ACTINIC::CheckSafeFilePath($::g_InputHash{PRODUCTPAGE});
}
if (defined $::g_InputHash{PAGEFILENAME})
{
ACTINIC::CheckSafeFilePath($::g_InputHash{PAGEFILENAME});
}
if (defined $::g_InputHash{DESTINATION})
{
ACTINIC::CheckSafeFilePath($::g_InputHash{DESTINATION});
}
}
sub InitURLs
{
my $Self = shift;
my $sReferrer = ACTINIC::GetReferrer();
my $bExpired = $::FALSE;
$Self->GetURLInfo()->SetTextNode($Session::XML_LASTPAGE, $sReferrer);
my ($sDigest,$sBaseFile) = ACTINIC::CaccGetCookies();
my $sLocalPage;
if( $sDigest )
{
if (($sReferrer =~ /$::g_sAccountScriptName$/i) &&
($sReferrer !~ /\?/))
{
my ($sBodyPage, $sProductPage) = ACTINIC::CAccCatalogBody();
$sReferrer .= "?PRODUCTPAGE\=" . $sBodyPage;
}
$sReferrer =~ /$::g_sAccountScriptName.*(\?|&)PRODUCTPAGE\=\"?(.*?)\"?(&|$)/i;
if ((ACTINIC::IsStaticPage($2)) &&
((!$$::g_pSetupBlob{USE_FRAMES}) ||
(!ACTINIC::IsFramePage($2))))
{
if (defined $::g_InputHash{SHOP} &&
$sReferrer !~ /[\?|\&]SHOP=/)
{
my $sShop = 'SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE);
$sReferrer =~ s/$::g_sAccountScriptName\?/$::g_sAccountScriptName\?$sShop\&/i;
}
$Self->GetURLInfo()->SetTextNode($Session::XML_LASTSHOPPAGE, $sReferrer);
}
}
elsif (ACTINIC::IsStaticPage($sReferrer) &&
(!$::g_InputHash{BPN}))
{
my $sLocalPage = $sReferrer;
my $sFileName = $sReferrer;
$sFileName =~ s/.*\/([^\/\=]+$)/$1/;
my ($bFramePage) = ACTINIC::IsFramePage($sFileName);
my ($sOriginalServer, $sNewServer);
$sLocalPage =~ m|https?://([-.a-zA-Z0-9]+)|;
$sNewServer = lc $1;
if (!$bFramePage)
{
if ($Self->GetURLInfo()->GetChildNode($Session::XML_LASTSHOPPAGE) &&
$Self->GetLastShopPage())
{
$Self->GetLastShopPage() =~ m|https?://([-.a-zA-Z0-9]+)|;
$sOriginalServer = lc $1;
}
unless ($Self->GetURLInfo()->GetChildNode($Session::XML_LASTSHOPPAGE) &&
$Self->GetLastShopPage() &&
($sOriginalServer ne $sNewServer))
{
$Self->GetURLInfo()->SetTextNode($Session::XML_LASTSHOPPAGE, $sLocalPage);
}
}
}
elsif ($::g_InputHash{BPN})
{
$Self->GetURLInfo()->SetTextNode($Session::XML_LASTSHOPPAGE, $$::g_pSetupBlob{CATALOG_URL} . $$::g_pSetupBlob{CATALOG_PAGE});
}
if (!$Self->GetURLInfo()->IsElementNode() ||
($Self->GetURLInfo()->IsElementNode() &&
!$Self->GetURLInfo()->GetChildNode($Session::XML_LASTSHOPPAGE)))
{
$Self->GetURLInfo()->SetTextNode($Session::XML_LASTSHOPPAGE, $$::g_pSetupBlob{CATALOG_URL} . $$::g_pSetupBlob{CATALOG_PAGE});
$bExpired = $::TRUE;
}
my $sBaseURLInfo;
if ($Self->GetURLInfo()->IsElementNode() &&
$Self->GetURLInfo()->GetChildNode($Session::XML_BASEURL) &&
$Self->GetURLInfo()->GetChildNode($Session::XML_BASEURL)->IsTextNode())
{
$sBaseURLInfo = $Self->GetURLInfo()->GetChildNode($Session::XML_BASEURL)->GetNodeValue();
}
if (!defined $sBaseURLInfo ||
$sBaseURLInfo eq "")
{
if (!ACTINIC::IsStaticPage($sReferrer))
{
$sReferrer = "";
}
else
{
$sReferrer =~ s|/[^/]*$|/|;
if (!defined $::g_InputHash{ACTINIC_REFERRER})
{
$sReferrer =~ m|[^/]/([^/]+)/$|;
my $sLastDir = $1;
if ($$::g_pSetupBlob{CATALOG_URL} !~ /$sLastDir\/$/ ||
!defined $sLastDir)
{
if ($$::g_pSetupBlob{CATALOG_URL} !~ /\/\/[^\/]+\/$/ &&
$$::g_pSetupBlob{CATALOG_URL} =~ /$sLastDir\/([^\/]+)\/$/)
{
$sReferrer .= $1 . "/";
}
}
}
}
if (!$sReferrer ||
!ACTINIC::IsStaticPage($sReferrer))
{
$sReferrer = $$::g_pSetupBlob{CATALOG_URL};
}
if ($bExpired)
{
$sReferrer =~ s/\/[^\/]*$/\//;
$sReferrer =~ /[^\/]\/([^\/]+)\/$/;
my $sLastDir = $1;
if (defined $sLastDir &&
$$::g_pSetupBlob{CGI_URL} =~ /$sLastDir\/$/)
{
$sReferrer = $$::g_pSetupBlob{CATALOG_URL};
}
}
$Self->GetURLInfo()->SetTextNode($Session::XML_BASEURL, $sReferrer);
}
}
sub ContactDetailsToCookieString
{
my $Self = shift;
my ($Status, $Message, $pBillContact, $pShipContact, $pShipInfo, $pTaxInfo,
$pGeneralInfo, $pPaymentInfo, $pLocationInfo) = $Self->RestoreCheckoutInfo();
my $sCookie;
if (!$$pBillContact{'REMEMBERME'})
{
$sCookie .= $ACTINIC::BILLCONTACT."\n";
$sCookie .= "REMEMBERME=0\n";
$sCookie .= "\n";
$sCookie = "ACTINIC_CONTACT=\"" . ACTINIC::EncodeText2($sCookie, $::FALSE) . "\"";
return ($sCookie);
}
my %hContactDetails = (
$ACTINIC::BILLCONTACT => $pBillContact,
$ACTINIC::SHIPCONTACT => $pShipContact,
$ACTINIC::SHIPINFO => $pShipInfo,
$ACTINIC::TAXINFO => $pTaxInfo,
$ACTINIC::PAYMENTINFO => $pPaymentInfo,
$ACTINIC::LOCATIONINFO => $pLocationInfo,
$ACTINIC::GENERALINFO => $pGeneralInfo
);
my ($sKeyContactDetails, $pValueContactDetails, $Temp);
while (($sKeyContactDetails, $pValueContactDetails) = each %hContactDetails)
{
$sCookie .= $sKeyContactDetails."\n";
my ($key, $value, $temp);
if (ref($pValueContactDetails) eq 'HASH')
{
while (($key, $value) = each %{$pValueContactDetails})
{
if (($sKeyContactDetails eq $ACTINIC::BILLCONTACT) &&
($key eq "AGREEDTANDC"))
{
next;
}
if (($sKeyContactDetails eq $ACTINIC::SHIPINFO) && (
($key eq "ADVANCED") ||
($key eq "HANDLING")))
{
next;
}
if (($sKeyContactDetails eq $ACTINIC::GENERALINFO) &&
($key eq "USERDEFINED") &&
(ACTINIC::IsPromptHidden(4, 2)))
{
next;
}
if (($sKeyContactDetails eq $ACTINIC::PAYMENTINFO) && (
($key eq "ORDERNUMBER") ||
($key eq "COUPONCODE")  ||
($key eq "PONO")))
{
next;
}
$sCookie .= ACTINIC::EncodeText2($key, $::FALSE) . "=" . ACTINIC::EncodeText2($value, $::FALSE) . "\n";
}
$temp = keys %$pValueContactDetails;
}
$sCookie .= "\n";
}
$Temp = keys %hContactDetails;
$sCookie = "ACTINIC_CONTACT=\"" . ACTINIC::EncodeText2($sCookie, $::FALSE) . "\"";
$Self->{_COOKIESTRING} = $sCookie;
return ($sCookie);
}
sub CookieStringToContactDetails
{
my $Self = shift;
my $sContactDetails = $Self->{_COOKIESTRING};
my (%BillContact, %ShipContact, %ShipInfo, %TaxInfo, %GeneralInfo, %PaymentInfo, %LocationInfo);
if (!$sContactDetails)
{
$Self->UpdateCheckoutInfo(\%BillContact, \%ShipContact, \%ShipInfo, \%TaxInfo, \%GeneralInfo, \%PaymentInfo, \%LocationInfo);
return $::FAILURE;
}
$sContactDetails = ACTINIC::DecodeText($sContactDetails, $ACTINIC::FORM_URL_ENCODED);
my @Lines = split(/\n/, $sContactDetails);
my ($key, $value, $Temp, $sLine, $pHash);
foreach $sLine (@Lines)
{
if ($sLine eq $ACTINIC::BILLCONTACT)
{
$pHash = \%BillContact;
}
elsif ($sLine eq $ACTINIC::SHIPCONTACT)
{
$pHash = \%ShipContact;
}
elsif ($sLine eq $ACTINIC::SHIPINFO)
{
$pHash = \%ShipInfo;
}
elsif ($sLine eq $ACTINIC::TAXINFO)
{
$pHash = \%TaxInfo;
}
elsif ($sLine eq $ACTINIC::GENERALINFO)
{
$pHash = \%GeneralInfo;
}
elsif ($sLine eq $ACTINIC::PAYMENTINFO)
{
$pHash = \%PaymentInfo;
}
elsif ($sLine eq $ACTINIC::LOCATIONINFO)
{
$pHash = \%LocationInfo;
}
elsif ($sLine eq '')
{
next;
}
else
{
($key, $value) = map {ACTINIC::DecodeText($_, $ACTINIC::FORM_URL_ENCODED)} split (/=/, $sLine);
$$pHash{$key} = $value;
}
}
$Self->UpdateCheckoutInfo(\%BillContact, \%ShipContact, \%ShipInfo, \%TaxInfo, \%GeneralInfo, \%PaymentInfo, \%LocationInfo);
return $::SUCCESS;
}
sub RestoreOldChkFile
{
my $Self	= shift;
my $sFilename = shift;
my (%BillContact, %ShipContact, %ShipInfo, %TaxInfo, %GeneralInfo, %PaymentInfo, %LocationInfo);
$::BILLCONTACT 	= "INVOICE";
$::SHIPCONTACT 	= "DELIVERY";
$::SHIPINFO 		= "SHIPPING";
$::TAXINFO 			= "TAX";
$::GENERALINFO 	= "GENERAL";
$::PAYMENTINFO 	= "PAYMENT";
$::LOCATIONINFO 	= "LOCATION";
unless (open (CKFILE, "<$sFilename"))
{
my ($sError);
$sError = $!;
ACTINIC::ChangeAccess('', $sFilename);
return ($::FAILURE, ACTINIC::GetPhrase(-1, 21, $sFilename, $sError), 0, 0);
}
my ($key, $value, $Temp, $sLine, $pHash);
while (defined ($sLine = <CKFILE>))
{
chomp $sLine;
if ($sLine eq $::BILLCONTACT)
{
$pHash = \%BillContact;
}
elsif ($sLine eq $::SHIPCONTACT)
{
$pHash = \%ShipContact;
}
elsif ($sLine eq $::SHIPINFO)
{
$pHash = \%ShipInfo;
}
elsif ($sLine eq $::TAXINFO)
{
$pHash = \%TaxInfo;
}
elsif ($sLine eq $::GENERALINFO)
{
$pHash = \%GeneralInfo;
}
elsif ($sLine eq $::PAYMENTINFO)
{
$pHash = \%PaymentInfo;
}
elsif ($sLine eq $::LOCATIONINFO)
{
$pHash = \%LocationInfo;
}
while (defined ($sLine = <CKFILE>))
{
chomp $sLine;
if ($sLine eq '')
{
last;
}
($key, $value) = split (/\|\|G\|\|/, $sLine);
$$pHash{$key} = $value;
}
}
close (CKFILE);
$Self->UpdateCheckoutInfo(\%BillContact, \%ShipContact, \%ShipInfo, \%TaxInfo, \%GeneralInfo, \%PaymentInfo, \%LocationInfo);
}
sub CreateSessionID
{
my $Self = shift;
$::bCookieCheckRequired = $::TRUE;
my ($sCartID, $sPath);
$sPath = $Self->GetSessionFileFolder();
if (defined $Self->{_SESSIONID} &&
$Self->{_SESSIONID} ne '')
{
return;
}
if (!$sCartID)
{
my $sClient;
if (length $::ENV{REMOTE_HOST} > 0)
{
$sClient = $::ENV{REMOTE_HOST};
}
else
{
$sClient = $::ENV{REMOTE_ADDR};
}
$sClient =~ s/[^a-zA-Z0-9]/Z/g;
$sCartID = $sClient . 'A' . time . 'B' . $$;
my ($sCartFile, $bTriedToRemove, @Response);
$sCartFile = $Self->GetSessionFileName($sCartID);
$bTriedToRemove = $::FALSE;
my $nIndex = 0;
my $sBase = $sCartID;
while (-f $sCartFile)
{
my (@stat);
@stat = stat $sCartFile;
if ($stat[9] < (time - 60 * 60 * 2) &&
!$bTriedToRemove)
{
ACTINIC::ChangeAccess("rw", $sCartFile);
ACTINIC::SecurePath($sCartFile);
unlink ($sCartFile);
$bTriedToRemove = $::TRUE;
}
else
{
$sCartID = $sBase . 'C' . $nIndex;
$sCartFile = $Self->GetSessionFileName($sCartID);
$bTriedToRemove = $::FALSE;
}
$nIndex++;
}
ACTINIC::SecurePath($sCartFile);
unless (open (GCIFILE, ">$sCartFile"))
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 21, $sCartFile, $!), 0, 0);
}
close (GCIFILE);
ACTINIC::ChangeAccess('', $sCartFile);
}
$Self->{_SESSIONID} = $sCartID;
return ($::SUCCESS, '', $sCartID, 0);
}
sub GetSessionFileName
{
my $Self = shift;
my $sID 	= shift;
my $sPath = $Self->GetSessionFileFolder();
return ($sPath . $sID . '.session');
}
package SessionLock;
use strict;
use vars qw($SUCCESS $ERR_TIMEOUT $ERR_DIRPERMS $ERR_OPNANDLCK $ERR_NOOPNNOLCK
$ERR_MORELCK $ERR_STALELCK $ERR_RECURSE $FAILURE $s_sHostname);
$SUCCESS = 0;
$FAILURE = -1;
$ERR_TIMEOUT  = 1;
$ERR_DIRPERMS = 2;
$ERR_OPNANDLCK = 3;
$ERR_NOOPNNOLCK = 4;
$ERR_MORELCK = 5;
$ERR_STALELCK = 6;
$ERR_RECURSE = 7;
$s_sHostname = '';
sub new
{
my $rSelf = {};
my $sThis= shift;
my $sClass = ref($sThis)||$sThis;
$rSelf->{basename}= shift;
$rSelf->{locked}=0;
$rSelf->{nTriesDone}	= 0;
$rSelf->{recurse_level} = 0;
$rSelf->{ID} = int(rand(1000));
$rSelf->{locktime} = 0;
$rSelf->{maxrecurse} = 5;
$rSelf->{nRetrytime}	= 0.3;
$rSelf->{nRetries}	= 200;
$rSelf->{staleage}	= 40;
bless $rSelf,$sClass;
}
sub SetLockSample
{
my $rSelf=shift;
if (@_ == 2)
{
my ($nNewTry, $nNewTime) = @_;
if (($nNewTry >= 1) &&
($nNewTry <= 10000))
{
$rSelf->{nRetries} = $nNewTry;
}
if (($nNewTime >= 0.01) &&
($nNewTime <= 1.0))
{
$rSelf->{nRetrytime} = $nNewTime;
}
}
return ($rSelf->{nRetries}, $rSelf->{nRetrytime});
}
sub GetTryCount
{
my $rSelf = shift;
return $rSelf->{nTriesDone};
}
sub DESTROY
{
my $rSelf=shift;
$rSelf->Unlock;
}
sub _try_rename
{
my $rSelf = shift;
my $fn = shift;
my $fnLCK = "$fn.$rSelf->{ID}.LCK";
if (rename("$fn.OPN", $fnLCK))
{
if (rename($fnLCK, "$fn.LCK"))
{
return $SUCCESS;
}
}
return $FAILURE;
}
sub _try_rename_back
{
my $rSelf = shift;
my $fn = shift;
if (rename("$fn.LCK", "$fn.OPN"))
{
return $SUCCESS;
}
return $FAILURE;
}
sub _cleanup
{
my $rSelf = shift;
my $fn = $rSelf->{basename} . '.LCK';
if (-e $fn)
{
unlink $fn;
}
if (-e $fn)
{
ACTINIC::RecordErrors("_cleanup\[$rSelf->{ID}\]: Deleting file : " . $fn . " failed", ACTINIC::GetPath());
}
$rSelf->{locked} = 0;
return $SUCCESS;
}
sub _init
{
my $rSelf = shift;
unless ((-e "$rSelf->{basename}.OPN") ||
(-e "$rSelf->{basename}.LCK"))
{
my $sFn = "$rSelf->{basename}.OPN";
unless (open(TF, '>' . $sFn))
{
ACTINIC::RecordErrors("_init\[$rSelf->{ID}\]: Error creating $sFn", ACTINIC::GetPath());
return $ERR_DIRPERMS;
}
close(TF);
}
return $SUCCESS;
}
sub _do_lock
{
my $rSelf = shift;
$rSelf->{nTriesDone}	= 0;
my $sOpenFile = "$rSelf->{basename}.OPN";
my $sLockFile = "$rSelf->{basename}.LCK";
if ((!(-e $sOpenFile)) &&
(!(-e $sLockFile)) &&
(!(-e $sOpenFile)))
{
return $ERR_NOOPNNOLCK;
}
if ((-e $sOpenFile) &&
(-e $sLockFile) &&
(-e $sOpenFile))
{
return $ERR_OPNANDLCK;
}
my ($bExists, $nAge, $nNow);
while ($rSelf->{nTriesDone} < $rSelf->{nRetries})
{
$rSelf->{nTriesDone}++;
my $Stat = $rSelf->_try_rename($rSelf->{basename});
if ($Stat == $SUCCESS)
{
$rSelf->{locked}=1;
return $SUCCESS;
}
else
{
($bExists, $nAge) = $rSelf->FileExists($sLockFile);
if ($bExists)
{
if ($rSelf->{locktime} != $nAge)
{
$rSelf->{locktime} = $nAge;
}
$nNow = time;
if (($nNow - $nAge) > $rSelf->{staleage})
{
ACTINIC::RecordErrors("_do_lock\[$rSelf->{ID}\]: ERR_STALELCK diff=" . $nNow-$nAge . " file=" . $sLockFile, ACTINIC::GetPath());
return $ERR_STALELCK;
}
}
select (undef, undef, undef, $rSelf->{nRetrytime});
}
}
my $rn = int(rand(10000));
my $tempname = $rSelf->{basename} . ".TEMP.$$.$rn";
unless ( open(TF, ">$tempname.OPN") &&
close(TF) &&
($rSelf->_try_rename($tempname) == $SUCCESS) &&
($rSelf->_try_rename_back($tempname) == $SUCCESS) &&
unlink("$tempname.OPN") )
{
return $ERR_DIRPERMS;
}
return $ERR_TIMEOUT;
}
sub FileExists
{
my $rSelf = shift;
my $sFile = shift;
my (@FileStat, $bExists);
@FileStat = stat $sFile;
$bExists = (-e $sFile);
if ($bExists &&
($FileStat[9] gt 0))
{
return ($::TRUE, $FileStat[9]);
}
select (undef, undef, undef, 0.01);
@FileStat = stat $sFile;
$bExists = (-e $sFile);
if ($bExists &&
(($FileStat[9] gt 0)))
{
return ($::TRUE, $FileStat[9]);
}
return ($::FALSE, undef);
}
sub Lock
{
my $rSelf=shift;
my $bInit = $::FALSE;
if (@_ == 1)
{
($bInit) = @_;
}
my $sLockFile = $rSelf->{basename} . ".LCK";
my $ret;
if ($bInit)
{
$ret = $rSelf->_init();
if ($ret != $SUCCESS)
{
ACTINIC::RecordErrors("Lock\[$rSelf->{ID}\]: Init failed", ACTINIC::GetPath());
$rSelf->{recurse_level}--;
return $ret;
}
}
if (++$rSelf->{recurse_level} > $rSelf->{maxrecurse})
{
ACTINIC::RecordErrors("_do_lock\[$rSelf->{ID}\]: Recurse error", ACTINIC::GetPath());
return $ERR_RECURSE;
}
if ($rSelf->{locked})
{
$rSelf->{recurse_level}--;
return ($SUCCESS);
}
$ret = $rSelf->_do_lock();
if ($ret == $SUCCESS)
{
$rSelf->{recurse_level}--;
my $nNow = time;
utime($nNow, $nNow, $sLockFile);
return $SUCCESS;
}
elsif ($ret == $ERR_TIMEOUT)
{
my ($bExists, $nAge) = $rSelf->FileExists($sLockFile);
if ($bExists)
{
my $now = time;
if ($rSelf->{locktime} != $nAge)
{
$rSelf->{locktime} = $nAge;
my $ret = $rSelf->Lock();
$rSelf->{recurse_level}--;
return ($ret==$SUCCESS) ? $SUCCESS : $ERR_TIMEOUT;
}
}
$rSelf->{recurse_level}--;
ACTINIC::RecordErrors("Lock\[$rSelf->{ID}\]: Time out", ACTINIC::GetPath());
return $ERR_TIMEOUT
}
elsif ($ret == $ERR_STALELCK)
{
if (-e $sLockFile)
{
ACTINIC::RecordErrors("Lock:\[$rSelf->{ID}\]: Stale lock - forcing removal of $rSelf->{basename}.LCK", ACTINIC::GetPath());
$rSelf->{locked}=1;
$rSelf->Unlock();
$ret = $rSelf->Lock();
}
$rSelf->{recurse_level}--;
return ($ret==$SUCCESS) ? $SUCCESS : $FAILURE;
}
elsif ($ret == $ERR_DIRPERMS)
{
ACTINIC::RecordErrors("Lock:\[$rSelf->{ID}\]: Permissions error", ACTINIC::GetPath());
return $ERR_DIRPERMS;
}
elsif ($ret == $ERR_NOOPNNOLCK)
{
select(undef, undef, undef, 0.01);
my $bInit = ($rSelf->{recurse_level} == ($rSelf->{maxrecurse} - 1)) ? $::TRUE : $::FALSE;
$ret = $rSelf->Lock($bInit);
$rSelf->{recurse_level}--;
return ($ret==$SUCCESS)?$SUCCESS:$FAILURE;
}
elsif ($ret == $ERR_OPNANDLCK)
{
ACTINIC::RecordErrors("Lock\[$rSelf->{ID}\]: Invalid status", ACTINIC::GetPath());
$rSelf->_cleanup();
$ret = $rSelf->Lock();
$rSelf->{recurse_level}--;
return ($ret==$SUCCESS)?$SUCCESS:$FAILURE;
}
}
sub Unlock
{
my $rSelf=shift;
if ($rSelf->{locked})
{
if ($rSelf->_try_rename_back($rSelf->{basename}) != $SUCCESS)
{
ACTINIC::RecordErrors("Unlock\[$rSelf->{ID}\]: Unlock: failed : " . $rSelf->{basename}, ACTINIC::GetPath());
return $FAILURE;
}
$rSelf->{locked}=0;
}
return $SUCCESS;
}
1;