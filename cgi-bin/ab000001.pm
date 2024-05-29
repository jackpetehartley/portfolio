#!/usr/bin/perl
$ACTINIC_ADB::prog_name = 'ActinicAddressBook.pm';
$ACTINIC_ADB::prog_name = $ACTINIC_ADB::prog_name;
$ACTINIC_ADB::prog_ver = '$Revision: 18819 $ ';
$ACTINIC_ADB::prog_ver = substr($ACTINIC_ADB::prog_ver, 11);
$ACTINIC_ADB::prog_ver =~ s/ \$//;
package HTML_ZCL;
my @oc_tags = ('A','ADDRESS','APPLET',
'B','BIG','BLINK','BLOCKQUOTE','BODY',
'CENTER','CITE','CODE',
'DD','DIV','DL','DT',
'EM','EMBED',
'FORM','FRAMESET',
'H1','H2','H3','H4','H5','H6','HEAD','HTML',
'I',
'LI','LISTING',
'MAP',
'NOFRAMES','NOSCRIPT',
'OBJECT','OL','OPTION',
'P','PLAINTEXT','PRE',
'S','SAMP','SCRIPT','SELECT','SMALL','SPAN','STRIKE','STRONG','STYLE','SUB','SUP',
'TABLE','TD','TEXTAREA','TH','TITLE','TR','TT',
'U','UL',
'VAR',
'XMP',
);
my @s_tags = ('AREA',
'BASEFONT','BR',
'FRAME',
'HR',
'IMG','INPUT',
'LINK',
'META',
'PARAM',
);
my $tag;
my $code = "";
foreach $tag (@oc_tags)
{
$code .= 'sub '.$tag.' {my $self=shift;my $txt = pop(@_);my $b = '.
'"<'.$tag.'".$self->attrib(@_).">".$txt."</'.$tag.'>";return $b;'."}".
'sub '.$tag.'_ {my $self=shift;my $b = "<'.$tag.'".$self->attrib(@_).">";return $b;'."}".
'sub _'.$tag.' {my $self=shift;my $b = "</'.$tag.'>";return $b;'."}";
}
foreach $tag (@s_tags)
{
$code .= 'sub '.$tag.' {my $self=shift;my $b = "<'.$tag.'".$self->attrib(@_).">";return $b;'."}";
}
eval $code;
sub new
{
my $proto = shift;
my $class = ref($proto) || $proto;
my $self = {};
bless ($self, $class);
$self->Set(@_);
return $self;
}
sub Set
{
my $self = shift;
my %pars = @_;
my $k;
foreach $k (keys %pars)
{
$self->{$k} = $pars{$k};
}
}
sub attrib
{
my $self = shift;
my %pars = @_;
my $txt = "";
my $k;
foreach $k (reverse sort keys %pars )
{
if( $pars{$k} ne "" )
{
$txt .= " ".uc($k)."=\"$pars{$k}\"";
}
else
{
$txt .= " ".uc($k);
}
}
return $txt;
}
sub FONT
{
my $self = shift;
my $sText = pop (@_);
my $sOpenTag = ACTINIC::GetPhrase(-1, 1967);
my $sCloseTag = ACTINIC::GetPhrase(-1, 1970);
return ($sOpenTag . $sText . $sCloseTag);
}
package ADDRESS_BOOK;
use vars qw(@ISA);
@ISA = qw(HTML_ZCL);
sub new
{
my $proto = shift;
my $class = ref($proto) || $proto;
my $self = $class->SUPER::new();
bless ($self, $class);
$self->{MaxAddresses} 		= 9;
$self->{BgColor} 				= "#ffffff";
$self->{LabelBgColor} 		= "#d0d0ff";
$self->{NameBgColor} 		= $$::g_pSetupBlob{FORM_BACKGROUND_COLOR};
$self->Set(@_);
if ( !defined($self->{Nnam_1}) ) { $self->{Nnam_1} = $self->{FormNames}->[0]; }
if ( !defined($self->{Nnam_2}) ) { $self->{Nnam_2} = $self->{FormNames}->[1]; }
$self->{UseThis} 		= 0;
return $self;
}
sub Init
{
my $self = shift;
if( defined($self->{done}) ) { return; }
$self->FromCookies();
foreach (keys %{$self->{InputFormHash}} )
{
if( $_ =~ /^ADBUSETHIS([1-9]*$)/ )
{
$self->{UseThis} = $1;
if( $self->{InputFormHash}->{ADBACTION} )
{
my ($a,$s) = split('&',$self->{InputFormHash}->{ADBACTION});
my ($a1,$a2) = split('=',$a);
my ($s1,$s2) = split('=',$s);
$self->{InputFormHash}->{ACTION}   = $self->Decode($a2);
$self->{InputFormHash}->{SEQUENCE} = $self->Decode($s2);
}
last;
}
}
if( $self->{UseThis} > 0 )
{
$self->{AddressForm} = $self->{Table}[$self->{UseThis}-1][0];
$self->ToForm();
}
elsif( $self->{InputFormHash}->{ADBADD} )
{
$self->FromForm();
$self->Add($self->{AddressForm});
}
else
{
$self->ClearForm();
}
$self->{done} = 1;
}
sub Show
{
my $self = shift;
my @tnam;
my $na = 0;
my $html;
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if($sDigest ne '')
{
my ($Status, $sMessage, $pBuyer, $pAccount) = ACTINIC::GetBuyerAndAccount($sDigest, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
if($pBuyer->{DeliveryAddressRule} != 2)
{
return('');
}
}
foreach (@{$self->{CookieList}})
{
if ( $self->{Table}[$_][0] && $self->{Table}[$_][2] == 0 ) { $na++; }
}
$html .= $self->CountMessage($na);
if( $na == 0 )
{
$html .= $self->INPUT(
TYPE => "CHECKBOX",
NAME => "ADBADD"
).
$self->FONT(
$self->{AddMessage}
);
$html .= $self->HR();
return $html;
}
$html .= $self->TABLE_(
BORDER      => "1" ,
CELLSPACING => "1" ,
CELLPADDING => "0" ,
BGCOLOR     => $self->{NameBgColor},
WIDTH       => '100%',
).
$self->TR(
$self->TD(
COLSPAN => 3,
'&nbsp;',
).
$self->TD(
ALIGN   => "CENTER",
$self->FONT(
$self->{DeleteLabel}
)
)
);
my ($key,$value);
while (($key, $value) = each %{$self->{InputFormHash}})
{
if( $key !~ /^ADBUSETHIS/ && $key !~ /^DELIVER/ && $key !~ /^ADBACTION/ )
{
$html .= $self->INPUT(
TYPE  => "HIDDEN",
NAME  => $key,
VALUE => $value
);
}
}
my $record = 'ACTION=' . $self->Encode($self->{Action}) . '&SEQUENCE=' . $self->{Sequence};
$html .= $self->INPUT(
TYPE  => "HIDDEN",
NAME  => "ADBACTION",
VALUE => $record
);
my $cnt = 0;
foreach (sort {
uc(${$self->{Table}[$a][0]}{$self->{Nnam_1}}.${$self->{Table}[$a][0]}{$self->{Nnam_2}})
cmp
uc(${$self->{Table}[$b][0]}{$self->{Nnam_1}}.${$self->{Table}[$b][0]}{$self->{Nnam_2}})
} @{$self->{CookieList}} )
{
if ( $self->{Table}[$_][2] > 0 )
{ 
next;
}
my $tval = $self->{Table}[$_][0];
my $nam  = $$tval{$self->{Nnam_1}};
my $strt = $$tval{$self->{Nnam_2}};
my $bDisabled = $::FALSE;
if (defined $$tval{'DELIVERY_REGION_CODE'} && defined $$tval{'DELIVERY_COUNTRY_CODE'})
{
$bDisabled = (($$tval{'DELIVERY_REGION_CODE'}  ne $self->{LocationHash}->{'DELIVERY_REGION_CODE'}) ||
($$tval{'DELIVERY_COUNTRY_CODE'} ne $self->{LocationHash}->{'DELIVERY_COUNTRY_CODE'}));
}
$cnt++;
$html .= $self->TR($self->Row($_, $cnt, $nam, $strt, $bDisabled));
}
$html .= $self->_TABLE();
$html .= $self->_TD();
$html .= $self->_TR();
$html .= $self->_TABLE();
$html .= $self->BR().
$self->INPUT(
TYPE => "CHECKBOX",
NAME => "ADBADD"
).
$self->FONT(
$self->{AddMessage}
);
return $html;
}
sub Row
{
my $self = shift;
my $ind  = shift;
my $cnt  = shift;
my $nam  = shift;
my $strt = shift;
my $bDisabled = shift;
my $sStatus = $bDisabled ? 'DISABLED' : '';
my $html;
my $j = $ind + 1;
if( $strt eq '{No Street}' ) { $strt = '&nbsp;'; }
$html = $self->TD(
ALIGN => "RIGHT",
$self->FONT(
$cnt . '.&nbsp;'
)
).
$self->TD(
BGCOLOR => $self->{NameBgColor},
$self->INPUT(
STYLE => 'font-weight:bold;color:white;background:' .
$::g_sRequiredColor . ';width: 200px;',
WIDTH => '200',
TYPE  => "SUBMIT",
NAME  => "ADBUSETHIS" . "$j",
VALUE => $nam,
$sStatus => ''
)
).
$self->TD(
BGCOLOR => $self->{NameBgColor},
WIDTH   => '270',
$self->FONT(
'&nbsp;' . $strt . '&nbsp;'
)
).
$self->TD(
ALIGN => "CENTER",
$self->INPUT(
TYPE => "CHECKBOX",
NAME => "ADBDELETE" . $ind
)
);
return $html;
}
sub CountMessage
{
my $self = shift;
my $na = shift;
my $buf;
if( $self->{InputFormHash}->{SEQUENCE} > $self->{Sequence} + 1)
{
if( $na < $self->{MaxAddresses} )
{
$buf .= $self->INPUT(
TYPE => "CHECKBOX",
NAME => "ADBADD"
).
$self->FONT(
$self->{AddMessage}
);
}
return $buf;
}
if( $na >= $self->{MaxAddresses} )
{
$buf .= $self->FONT(
$self->{MaxAddressesWarning}
);
}
if( $na > 0 )					  # Something there - open TABLE to frame it
{
my $adct;
$buf .= $self->TABLE_(
WIDTH       => "600",
BORDER      => "1" ,
CELLSPACING => "0" ,
CELLPADDING => "0" ,
);
$buf .= $self->TR_();
$buf .= $self->TD_();
if( $na == 1 )
{
$adct = $self->{OneAddressMessage};
}
else
{
$adct = $self->{MoreAddressesMessage};
$adct =~ s/\%s/$na/;
}
my $st = $self->{StatusMessage};
$st =~ s/\%s/$adct/;
$buf .= $self->FONT(
$st
);
}
else								  # Address Book empty - different status message and no frame
{
$buf .= $self->FONT(
$self->{NoAddressesMessage}
);
}
return $buf;
}
sub Debug
{
my $self = shift;
my $buf = $self->{dbbuf};
foreach (keys %{$self->{InputFormHash}})
{
$buf .= "<br>$_ = " . $self->{InputFormHash}->{$_};
}
return $buf;
}
sub ToCookies
{
my $self = shift;
my ($key,$value);
foreach (@{$self->{CookieList}})
{
if( $self->{Table}[$_][2] == 0 && $self->{Table}[$_][1] > 0 )
{
my $sCookie;
while (($key, $value) = each %{$self->{Table}[$_][0]})
{
$sCookie .= $key . "=" . $value . ">>";
}
$self->{Table}[$_][0] = $self->Encode($sCookie);
}
}
}
sub Add
{
my $self = shift;
my $h = shift;
if ( $h->{$self->{Nnam_1}} eq "" && $h->{$self->{Nnam_2}} eq "" ) { return; }
if ( $h->{$self->{Nnam_1}} eq ""  ) { $h->{$self->{Nnam_1}} = '{No Name}'; }
if ( $h->{$self->{Nnam_2}} eq ""  ) { $h->{$self->{Nnam_2}} = "{No Street}"; }
my $hind = $h->{$self->{Nnam_1}} . $h->{$self->{Nnam_2}};
if( defined( $self->{Hash}{$hind} ) )
{
$self->{Table}[$self->{Hash}{$hind}] = [$h,1,0];
}
else
{
foreach (@{$self->{CookieList}})
{
if ( $self->{Table}[$_][2] != 0 )
{
$self->{Hash}{$hind} = $_;
$self->{Table}[$_] = [$h,1,0];
return;
}
}
my $i;
for ( $i=0; $i<$self->{MaxAddresses}; $i++ )
{
if ( !defined($self->{Table}[$i][0]) || $self->{Table}[$i][2] != 0 )
{
$self->{Hash}{$hind} = $i;
push @{$self->{CookieList}},$i;
$self->{Table}[$i] = [$h,1,0];
return;
}
}
}
}
sub Remove
{
my $self = shift;
my $i = shift;
$self->{Table}[$i][2] = 1;
$self->{Table}[$i][0] = undef;
}
sub FromCookies
{
my $self = shift;
$self->GetCookies();
my $i;
foreach $i (@{$self->{CookieList}})
{
if ( $self->{InputFormHash}->{'ADBDELETE'.$i} )
{
$self->Remove($i);
}
else
{
if ( defined($self->{Table}[$i][0]) )
{
my @lst = split(">>",$self->Decode($self->{Table}[$i][0]));
my $h = {};
my ($key,$value);
foreach (@lst)
{
($key,$value) = split "=";
$h->{$key} = $value;
}
if ( !$h->{$self->{Nnam_1}} && !$h->{$self->{Nnam_2}} )
{
$self->Remove($i);
}
else
{
$self->{Table}[$i][0] = $h;
$self->{Hash}{$h->{$self->{Nnam_1}}.$h->{$self->{Nnam_2}}} = $i;
}
}
}
}
}
sub GetCookies
{
my $self = shift;
my ($sCookie, $sCookies);
$sCookies = $::ENV{'HTTP_COOKIE'};
my (@CookieList) = split(/;/, $sCookies);
my ($sLabel,$sA);
@{$self->{CookieList}} = ();
foreach $sCookie (@CookieList)
{
$sCookie =~ s/^\s*//;
if ($sCookie =~ /^ACTINIC_ADDRBOOK([0-9]*)/)
{
my $ind = $1;
($sLabel, $sA) = split (/=/, $sCookie);
$sA =~ s/^\s*"?//;
$sA =~ s/"?\s*$//;
$self->{Table}[$ind] = [$sA,0,0];
push @{$self->{CookieList}},$ind;
}
}
}
sub Header
{
my $self = shift;
my (@expires, $day, $month, $now, $later, $before, $expiry, $expired);
my (@days) = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
my (@months) = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
$now = time;
$later = $now + 2 * 365 * 24 * 3600;
@expires = gmtime($later);
$day = $days[$expires[6]];
$month = $months[$expires[4]];
$expiry = sprintf("%s, %02d-%s-%04d %02d:%02d:%02d GMT", $day, $expires[3],
$month, $expires[5]+1900, $expires[2], $expires[1], $expires[0]);
$before = $now - 24 * 3600;
@expires = gmtime($before);
$day = $days[$expires[6]];
$month = $months[$expires[4]];
$expired = sprintf("%s, %02d-%s-%04d %02d:%02d:%02d GMT", $day, $expires[3],
$month, $expires[5]+1900, $expires[2], $expires[1], $expires[0]);
my $buf;
$self->ToCookies();
foreach (@{$self->{CookieList}})
{
if ( $self->{Table}[$_][2] != 0 )
{
$buf .= "Set-Cookie: ACTINIC_ADDRBOOK" . $_ . "=\"\"" .
"; EXPIRES=" . $expired . "; PATH=/;\n";
}
elsif ( $self->{Table}[$_][1] > 0 )
{
$buf .= "Set-Cookie: ACTINIC_ADDRBOOK" . $_ . "=\"" . $self->{Table}[$_][0] . "\"" .
"; EXPIRES=" . $expiry . "; PATH=/;\n";
}
}
return $buf;
}
sub FromForm
{
my $self = shift;
if( 	!$self->{InputFormHash}->{$self->{FormPrefix} . $self->{Nnam_1}} &&
!$self->{InputFormHash}->{$self->{FormPrefix} . $self->{Nnam_2}} 	)
{
return;
}
foreach (@{$self->{FormNames}})
{
$self->{AddressForm}->{$_} = $self->{InputFormHash}->{$self->{FormPrefix} . $_};
}
foreach (@{$self->{LocationInfoNames}})
{
$self->{AddressForm}->{$_} = $self->{InputFormHash}->{$_};
}	
}
sub ToForm
{
my $self = shift;
if( $self->{UseThis} <= 0 ) { return; }
foreach (@{$self->{FormNames}})
{
$self->{DeliveryFormHash}->{$_} = $self->{AddressForm}->{$_};
}
foreach (@{$self->{LocationInfoNames}})
{
if (defined $self->{AddressForm}->{$_})
{
$self->{LocationHash}->{$_} = $self->{AddressForm}->{$_};
}
}		
if ( $self->{DeliveryFormHash}->{$self->{Nnam_1}} eq '{No Name}'  )
{
$self->{DeliveryFormHash}->{$self->{Nnam_1}} = "";
}
if ( $self->{DeliveryFormHash}->{$self->{Nnam_2}} eq '{No Street}'  )
{
$self->{DeliveryFormHash}->{$self->{Nnam_2}} = "";
}
}
sub ClearForm
{
my $self = shift;
foreach (keys %{$self->{DeliveryFormHash}})
{
$self->{DeliveryFormHash}->{$_} = "";
}
}
sub Decode
{
return ACTINIC::DecodeText($_[1],$ACTINIC::FORM_URL_ENCODED);
}
sub Encode
{
return ACTINIC::EncodeText2($_[1],$::FALSE,$::FALSE);
}
1;