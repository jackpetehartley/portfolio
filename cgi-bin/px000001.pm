#!perl
package PXML;
use strict;
push (@INC, "cgi-bin");
use ac000001;
$PXML::prog_name = 'PXML.pm';
$PXML::prog_name = $PXML::prog_name;
$PXML::prog_ver = '$Revision: 18819 $ ';
$PXML::prog_ver = substr($PXML::prog_ver, 11);
$PXML::prog_ver =~ s/ \$//;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $Self  = {};
bless ($Self, $Class);
$Self->{_XMLERROR} = "Error parsing XML text (%s)";
$Self->{_LoopProtect} = 25000;
$Self->{_CurrentLoop} = 0;
$Self->Set(@_);
return $Self;
}
sub Set
{
my $Self       = shift;
my %Parameters = @_;
foreach (keys %Parameters)
{
if( ref($Parameters{$_}) eq "CODE" )
{
$Self->{_Tags}->{uc($_)} = $Parameters{$_};
}
else
{
$Self->{$_} = $Parameters{$_};
}
}
}
sub Parse
{
my $Self  = shift;
my $sText = shift;
my $sId   = shift;
my $pTree;
my $pResTree;
my $sDummy;
my $Result;
if( !$sId ) 
{ 
$sId = $Self->{ID};
}
$Self->{_CurrentLoop}++;
if( $Self->{_CurrentLoop} > $Self->{_LoopProtect} )
{
$Result = $Self->{_XMLERROR};
$Result =~ s/\%s/Infinite Loop \(\?\)/;
return $Result;
}
while ( $sText =~ /
(
<
\s*
$sId
([0-9a-zA-Z_]+?)
(
(\s+
[0-9a-zA-Z_]+?
(\=
(
(\"[^\"]*\") |
(\'[^\']*\') |
([^\"\'\ \/\>\r\n\t]+)
)
)*?
)*?
)
\s*
(\/*?)
\s*
>
)
| (<!--.*?-->)
/sx )
{
$sText   = $';
$Result .= $`;
if( $11 )
{
$Result .= $&;
next;
}
my $sTag					= $2;
my $sParameterText	= $3;
my $sInsideText		= "";
my $sStartTag			= $&;
my $sEndTag;
my $ParameterHash;
if( $sParameterText )
{
$ParameterHash = $Self->ParseParameters($sParameterText);
}
if ( !$10 ) 
{ 
$sInsideText  = $Self->FindEndTag($sId,$sTag,\$sText,\$sEndTag); 
}
my $sGeneralTag = uc($sTag);
if ( !defined($Self->{_Tags}->{$sGeneralTag}) ) 
{ 
$sGeneralTag = 'DEFAULT'; 
}
if( defined($Self->{_Tags}->{$sGeneralTag}) )
{
my $sReplace =	&{$Self->{_Tags}->{$sGeneralTag}}(
$sTag,
\$sInsideText,
$ParameterHash,
$sId,
$sStartTag
);
if( $sReplace eq $sStartTag )
{
$Result .= $sReplace;
}
else
{
($sDummy, $pResTree) = $Self->Parse($sReplace,$sId);
$Result .= $sDummy;
}
($sDummy, $pResTree) = $Self->Parse($sInsideText,$sId);
$Result .= $sDummy;
if( defined($Self->{_Tags}->{$sGeneralTag.'_END'}) )	
{
$sReplace = &{$Self->{_Tags}->{$sGeneralTag.'_END'}}('/'.$sTag, "", "", $sId, $sEndTag);
}
else
{
$sReplace = &{$Self->{_Tags}->{$sGeneralTag}}('/'.$sTag, "", "", $sId, $sEndTag);
}
if( $sReplace eq $sEndTag )
{
$Result .= $sReplace;
}
else
{
($sDummy, $pResTree) = $Self->Parse($sReplace,$sId);
$Result .= $sDummy;
}
}
else
{
($sDummy, $pResTree) = $Self->Parse($sInsideText,$sId) ;
$Result .= $sStartTag . $sDummy . $sEndTag;
}
my $pContent;
if (ref($pResTree) ne 'ARRAY')
{
$pContent = ACTINIC::DecodeText($sDummy, $ACTINIC::HTML_ENCODED);
}
else
{
$pContent = $pResTree;
}		
my $pTemp = Element::new('Element', {
_TAG 			=> $sTag,
_PARAMETERS => $ParameterHash,
_CONTENT		=> $pContent,
_ORIGINAL	=> $sInsideText,
});
push @{$pTree}, $pTemp;
}
return $Result . $sText, $pTree;
}
sub FindEndTag
{
my $Self = shift;
my ($sId, $sTag, $sText, $sEnd) = @_;
my ($sBetween, $sAfter, $sBefore);
$sAfter = $$sText;
my $nStartCount = 1;
my $nEndCount 	 = 0;
my $sIterate;
while ($nStartCount > $nEndCount)
{
$nStartCount = 1;
if( $sAfter =~ / < \s* \/ $sId $sTag \s* > /sx )
{
$sAfter = $';
$$sEnd  = $&;
$sBetween .= $`;
$nEndCount++;
}
else
{
my $sErr = sprintf($Self->{_XMLERROR}, $sId. $sTag);
return $sErr . $$sText;
}			
$sIterate = $sBetween . $$sEnd;
while( $sIterate =~ / < \s* $sId $sTag (\s [^<]* [^\/])? > /sx )
{
$sIterate = $';
$nStartCount++;
}	
if ($nStartCount > $nEndCount)
{
$sBetween .= $$sEnd;
}
}
$$sText = $sAfter;
return $sBetween;		
}
sub ParseParameters
{
my $Self        = shift;
my $sParameters = shift;
my $ParameterHash = ();
while ( $sParameters =~ m/\G
\s+
([0-9a-zA-Z_]+)
(\=
(
(\"[^\"]*\") |
(\'[^\']*\') |
([^\"\'\ \/\>\r\n\t]+)
)
)*
/gsx )
{
my $sName = $1;
if( $2 )
{
my $sValue = ACTINIC::DecodeText($3, $ACTINIC::HTML_ENCODED);
$sValue =~ s/^(\"|\')//;
$sValue =~ s/(\"|\')$//;
$ParameterHash->{$sName} = $sValue;
}
else
{
$ParameterHash->{$sName} = 'SET';
}
}
return $ParameterHash;
}
sub SaveXML
{
my $Self  		= shift;
my $hashTree 	= $_[0];
my $sIndent		= $_[1];
my $pIterator;
my $sXML;
foreach $pIterator (@$$hashTree)
{
my $sEmbed;
my $sTag;
my $sEndTag;
my $sTagName = $$pIterator{_TAG};
my $sParameters;
my $pParam;
foreach $pParam (keys %{$$pIterator{_PARAMETERS}})
{
$sParameters .= "$pParam=\"" . ACTINIC::EncodeText2($$pIterator{_PARAMETERS}->{$pParam}) . "\" ";
}
$sTag = "<$sTagName $sParameters";
$sTag =~ s/\s*$//;
$sEndTag = "</$sTagName>";
if ($$pIterator{_CONTENT} eq '')
{
$sXML .= $sIndent . $sTag . "/>\n";
next;
}
if (ref($$pIterator{_CONTENT}) eq 'ARRAY')
{
$sTag .= ">\n";
$sEndTag = $sIndent . $sEndTag;
$sEmbed = $Self->SaveXML(\$$pIterator{_CONTENT}, $sIndent . "\t");
}
else
{
$sTag .= ">";
$sEmbed = ACTINIC::EncodeText2($$pIterator{_CONTENT});
}
$sXML .= "$sIndent$sTag$sEmbed$sEndTag\n";
}
return $sXML;
}
sub SaveXMLFile
{
my $Self  		= shift;
my $sFilename	= shift;
my $hashTree 	= $_[0];
my $sXML;
$sXML = $Self->SaveXML(\$hashTree);
unless (open (XMLFILE, ">$sFilename"))
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 21, $sFilename, $!));
}
unless (print XMLFILE $sXML)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 28, $sFilename, $!));
}
close XMLFILE;
return ($::SUCCESS, $sXML);
}	
sub ParseFile
{
my $Self  		= shift;
my $sFilename	= shift;
my $sId   		= shift;	
my $sXML;
unless (open (XMLFILE, "<$sFilename"))
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 21, $sFilename, $!));
}
{
local $/;
$sXML = <XMLFILE>;
}
close XMLFILE;
my ($sParsedText, $pTree) = $Self->Parse($sXML, $sId);
return ($::SUCCESS, $sXML, $pTree);
}		
package Element;
use strict;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $Self = shift;
if (!$Self)
{
$Self = {};
}			
if (!exists $Self->{_CONTENT})
{
$Self->{_CONTENT} = '';			
}
if (!exists $Self->{_PARAMETERS})
{
$Self->{_PARAMETERS} = {};
}
if (!exists $Self->{_TAG})
{
$Self->{_TAG} = '';		
}
if (!exists $Self->{_ORIGINAL})
{
$Self->{_ORIGINAL} = '';		
}		
bless ($Self, $Class);
return $Self;
}
sub IsElementNode
{
my $Self  = shift;
return (ref($Self->{_CONTENT}) eq 'ARRAY');
}
sub IsTextNode
{		
my $Self  = shift;
return (ref($Self->{_CONTENT}) eq undef);
}
sub GetChildNodeCount
{
my $Self = shift;
my $nLength = @{$Self->{_CONTENT}};
return $nLength;
}
sub FindNode	
{
my $Self  				= shift;
my $sNodeName 			= shift;
my $sAttributeName 	= shift;
my $sAttributeValue 	= shift;
if (!$Self->IsElementNode())
{
return undef;
}
my $pNode;
foreach $pNode (@{$Self->{_CONTENT}})
{
if ($pNode->IsElementNode())
{
my $pRecNode = $pNode->FindNode($sNodeName, $sAttributeName, $sAttributeValue);
if (defined $pRecNode)
{
return $pRecNode;	
}
}
if (%{$pNode}->{_TAG} eq $sNodeName &&
($sAttributeName eq "" ||
$pNode->GetAttribute($sAttributeName) eq $sAttributeValue))
{
return $pNode;
}
}
return undef;
}
sub GetChildNodeAt
{
my $Self = shift;
my $i = shift;
return $Self->{_CONTENT}[$i];
}
sub GetChildNode	
{
my $Self  = shift;
my $sNodeName = shift;
if (!$Self->IsElementNode())
{
return undef;
}
my $pNode;
foreach $pNode (@{$Self->{_CONTENT}})
{
if (%{$pNode}->{_TAG} eq $sNodeName)
{
return $pNode;
}
}
return undef;
}
sub GetChildNodes	
{
my $Self  = shift;
my $sNodeName = shift;
if (!$Self->IsElementNode())
{
return undef;
}
my $pChildNodes = [];
my $i = 0;
my $pNode;
foreach $pNode (@{$Self->{_CONTENT}})
{
if (!$sNodeName ||
%{$pNode}->{_TAG} eq $sNodeName)
{
$pChildNodes->[$i++] = $pNode;
}
}
return $pChildNodes;
}
sub SetChildNode	
{
my $Self  = shift;
my $pElement = shift;
if (!$Self->IsElementNode())
{
$Self->{_CONTENT} = [];
}
my $i = 0;
my $pNode;
foreach $pNode (@{$Self->{_CONTENT}})
{
if (%{$pNode}->{_TAG} eq $pElement->GetTag())
{					
$Self->{_CONTENT}[$i] = $pElement;
return;
}
$i++;
}
$Self->{_CONTENT}[$i] = $pElement;
}
sub AddChildNode	
{
my $Self  = shift;
my $pElement = shift;
if (!$Self->IsElementNode())
{
$Self->{_CONTENT} = [];
}
push(@{$Self->{_CONTENT}}, $pElement);
}
sub RemoveChildNodes	
{
my $Self  = shift;
my $pElement = shift;
$Self->{_CONTENT} = [];
}
sub SetTextNode
{
my $Self  	= shift;
my $sName 	= shift;
my $sValue	= shift;
if (!$Self->IsElementNode())
{
$Self->{_CONTENT} = [];
}
my $i = 0;
my $pNode;
foreach $pNode (@{$Self->{_CONTENT}})
{
if (%{$pNode}->{_TAG} eq $sName)
{					
$Self->{_CONTENT}[$i]->SetTag($sName);
$Self->{_CONTENT}[$i]->SetNodeValue($sValue);
return;
}
$i++;
}
my $pElement = new Element({"_TAG" => $sName, "_CONTENT" => $sValue});
push @{$Self->{_CONTENT}}, $pElement;
}
sub CreateElementFromLegacyStructure
{
my $sNodeName = shift;
my $pLegacyStructure = shift;
my $pNewElement = new Element();
$pNewElement->SetTag($sNodeName);
if (ref($pLegacyStructure) eq "HASH")
{
my $key;
foreach $key (keys(%{$pLegacyStructure}))
{
$pNewElement->SetChildNode(Element::CreateElementFromLegacyStructure($key, $pLegacyStructure->{$key}));
}
}
else
{
$pNewElement->SetNodeValue($pLegacyStructure)	;					
}
return $pNewElement;
}
sub ToLegacyStructure
{
my $Self 			= shift;
my $bNoEmptyRoot 	= shift;
if (!defined $bNoEmptyRoot)
{
$bNoEmptyRoot = $::TRUE;
}
my $pLegacyStructure;
if ($Self->IsTextNode())
{
if ($Self->GetNodeValue() eq "" &&
$bNoEmptyRoot)
{
$pLegacyStructure = {};
}
else
{
$pLegacyStructure = $Self->GetNodeValue();
}
}
else
{
$pLegacyStructure = {};
for (my $i = 0; $i < $Self->GetChildNodeCount(); $i++)
{
my $pChildNode = $Self->GetChildNodeAt($i);
$pLegacyStructure->{$pChildNode->GetTag()} = $pChildNode->ToLegacyStructure($::FALSE);
}
}
return $pLegacyStructure;
}
sub GetNodeValue
{
my $Self  = shift;
return $Self->{_CONTENT};		
}
sub SetNodeValue
{
my $Self  = shift;
my $sValue = shift;
$Self->{_CONTENT} = $sValue;		
}
sub GetTag
{
my $Self  = shift;
return $Self->{_TAG};		
}
sub SetTag
{
my $Self  = shift;
my $sTag = shift;
$Self->{_TAG} = $sTag;		
}	
sub GetAttribute
{
my $Self  = shift;
my $sName = shift;
return $Self->{_PARAMETERS}->{$sName};		
}	
sub SetAttribute
{
my $Self  = shift;
my $sName = shift;
my $sValue = shift;
$Self->{_PARAMETERS}->{$sName} = $sValue;		
}	
sub SetAttributes
{
my $Self  	= shift;
my $hValues = shift;
my $sKey;
foreach $sKey (keys %{$hValues})
{
$Self->{_PARAMETERS}->{$sKey} = $$hValues{$sKey};		
}
}	
sub GetOriginal
{
my $Self  = shift;
return $Self->{_ORIGINAL};		
}	
1;