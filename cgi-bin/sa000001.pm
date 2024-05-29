#!/usr/local/bin/perl
package ActinicSMTPAuth;
use strict;
use MIME::Base64;
push (@INC, "cgi-bin");
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
$ActinicSMTPAuth::prog_name = 'ActinicSMTPAuth.pm';
$ActinicSMTPAuth::prog_name = $ACTINIC::prog_name;
$ActinicSMTPAuth::prog_ver = '$Revision: 18819 $ ';
$ActinicSMTPAuth::prog_ver = substr($ACTINIC::prog_ver, 11);
$ActinicSMTPAuth::prog_ver =~ s/ \$//;
@ActinicSMTPAuth::lsProtocol	= ("DIGEST-MD5", "CRAM-MD5", "LOGIN", "PLAIN");
@ActinicSMTPAuth::lpHandler	= (\&SMTPAuth_DIGEST_MD5, \&SMTPAuth_CRAM_MD5, \&SMTPAuth_LOGIN, \&SMTPAuth_PLAIN);
$ActinicSMTPAuth::sHostname = "localhost";
$ActinicSMTPAuth::sServername = '';
sub GetSMTPUsername
{
my $sUsername = $::sSMTPUsername;
$sUsername = decode_base64($sUsername);
$sUsername ^= "\xa5" x (length $sUsername);
return ($sUsername);
}
sub GetSMTPPassword
{
my $sPassword = $::sSMTPPassword;
$sPassword = decode_base64($sPassword);
$sPassword ^= "\xa5" x (length $sPassword);
return ($sPassword);
}
sub SMTPAuth_LOGIN
{
my ($sBuffer);
my ( $nStep, $sAnswer) = @_;
if ($nStep == 0)
{
return ($::SUCCESS, '', $::TRUE);
}
if ($nStep == 1)
{
$sAnswer = decode_base64($sAnswer);
if ($sAnswer !~ /username/i)
{
return($::FAILURE, $sAnswer, $::FALSE);
}
$sBuffer = encode_base64(GetSMTPUsername(), '') . "\r\n";
return ($::SUCCESS, $sBuffer, $::TRUE);
}
if ($nStep == 2)
{
$sAnswer = decode_base64($sAnswer);
if ($sAnswer !~ /password/i)
{
return($::FAILURE, $sAnswer, $::FALSE);
}
$sBuffer = encode_base64(GetSMTPPassword(), '') . "\r\n";
return ($::SUCCESS, $sBuffer, $::FALSE);
}
return ($::FAILURE, "Unexpected SMTPAuthentication step number!", $::FALSE);
}
sub SMTPAuth_PLAIN
{
my ($sBuffer);
my ( $nStep, $sAnswer) = @_;
if ($nStep == 0)
{
return ($::SUCCESS, '', $::TRUE);
}
if ($nStep == 1)
{
$sBuffer = '\0' . GetSMTPUsername() . '\0' . GetSMTPPassword() ;
$sBuffer = encode_base64($sBuffer, '') . "\r\n";
return ($::SUCCESS, $sBuffer, $::FALSE);
}
return ($::FAILURE, "Unexpected SMTPAuthentication step number!", $::FALSE);
}
sub SMTPAuth_CRAM_MD5
{
my ($sBuffer);
my ( $nStep, $sAnswer) = @_;
eval
{
require Digest::HMAC_MD5;
import Digest::HMAC_MD5 qw(hmac_md5_hex);
};
if ($@)
{
require di000001;
import Digest::Perl::MD5 qw(hmac_md5_hex);
}
if ($nStep == 0)
{
return ($::SUCCESS, '', $::TRUE);
}
if ($nStep == 1)
{
$sAnswer = decode_base64($sAnswer);
$sBuffer = GetSMTPUsername() . ' '. hmac_md5_hex($sAnswer, GetSMTPPassword());
$sBuffer = encode_base64($sBuffer, '') . "\r\n";
return ($::SUCCESS, $sBuffer, $::FALSE);
}
return ($::FAILURE, "Unexpected SMTPAuthentication step number!", $::FALSE);
}
sub SMTPAuth_DIGEST_MD5
{
my ($sBuffer);
my ( $nStep, $sAnswer) = @_;
eval
{
require Digest::MD5;
import Digest::MD5 qw(md5 md5_hex);
};
if ($@)
{
require di000001;
import Digest::Perl::MD5 qw(md5 md5_hex );
}
if ($nStep == 0)
{
return ($::SUCCESS, '', $::TRUE);
}
if ($nStep == 1)
{
$sAnswer = decode_base64($sAnswer);
my %sparams;
while($sAnswer =~ s/^(?:\s*,)?\s*(\w+)=("([^\\"]+|\\.)*"|[^,]+)\s*//)  # "
{
my ($k, $v) = ($1,$2);
if ($v =~ /^"(.*)"$/s)
{
($v = $1) =~ s/\\//g;
}
$sparams{$k} = $v;
}
if (length $sAnswer)
{
return ($::FAILURE, "Invalid SMTPAuthentication challenge!", $::FALSE);
}
my $sServ_name = $ActinicSMTPAuth::sServername;
my $sUri = 'smtp/' . $ActinicSMTPAuth::sHostname;
if (defined $sServ_name
&& (length $sServ_name > 0))
{
$sUri .=  '/' . $sServ_name;
}
my $sUserName = GetSMTPUsername();
my $sPassword = GetSMTPPassword();
my $sRealm  = ($sUserName =~ s/\@(.+)$//o) ? $1 : $sServ_name;
my $sNonce  = $sparams{nonce};
my $sCnonce = substr(md5_hex(join (":", $$, time, rand)),0,14);
my $sQop = 'auth';
my $nNc  = '00000001';
my($nHv, $sA1, $sA2);
$nHv = md5("$sUserName:$sRealm:$sPassword");
$sA1 = md5_hex("$nHv:$sNonce:$sCnonce");
$sA2 = md5_hex("AUTHENTICATE:$sUri");
$nHv = md5_hex("$sA1:$sNonce:$nNc:$sCnonce:$sQop:$sA2");
$sBuffer = qq(username="$sUserName",realm="$sRealm",nonce="$sNonce",nc=$nNc,cnonce="$sCnonce",digest-uri="$sUri",response=$nHv,qop=$sQop);
$sBuffer = encode_base64($sBuffer, '') . "\r\n";
return ($::SUCCESS, $sBuffer, $::FALSE);
}
if ($nStep == 2)
{
$sAnswer = decode_base64($sAnswer);
if ($sAnswer =~ /rspauth/)
{
return ($::SUCCESS, "\n", $::FALSE);
}
else
{
return ($::SUCCESS, 'Unexpected response from the SMTP server during DIGEST-MD5 authentication!', $::FALSE);
}
}
return ($::FAILURE, "Unexpected SMTPAuthentication step number!", $::FALSE);
}
my %qdval; @qdval{qw(username realm nonce cnonce digest-uri qop)} = ();
sub _qdval
{
my ($k, $v) = @_;
if (!defined $v)
{
return;
}
elsif (exists $qdval{$k})
{
$v =~ s/([\\"])/\\$1/g;
return qq{$k="$v"};
}
return "$k=$v";
}
1;