#!/usr/local/bin/perl
package ActinicEncrypt;
use as000001;
use ad000001;
use integer;
use strict;
sub InitEncrypt
{
ActinicDiffie::InitDiffie(@_);
ActinicSafer::InitTables();
}
sub Encrypt
{
my	($sHeavy, $sLight) = @_;
my	($i, $j);
my	(@bKey, @bFixedKey, $sCipherHeavy, $sCipherLight);
@bFixedKey = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16);
$sCipherLight = EncryptSafer($sLight, @bFixedKey);
if(!$sHeavy)
{
$sCipherHeavy = "";
my $sHeader = pack("C4NNC16",
$ActinicDiffie::BLOB_VERSION_2,
$ActinicDiffie::BLOB_SAFER_SK128,
$ActinicDiffie::BLOB_PRIME_128_1,
$ActinicDiffie::KEY_LENGTH_128,
0,
(length $sCipherLight),
ActinicDiffie::AsBytes(0));
return(join '', $sHeader, $sCipherHeavy, $sCipherLight);
}
my	$nMyPrivateKey = GenerateRandom($sHeavy . $sLight);
my 	($nMyPublicKey, $nMyEncryptKey);
my $nPrimeSubOne = ActinicDiffie::badd($ActinicDiffie::g_nPrime, '-1');
$nMyPrivateKey = ActinicDiffie::bmod($nMyPrivateKey, $nPrimeSubOne);
$nMyPublicKey = ActinicDiffie::ModPow($ActinicDiffie::g_nBase, $nMyPrivateKey, $ActinicDiffie::g_nPrime);
$nMyEncryptKey = ActinicDiffie::ModPow($ActinicDiffie::g_nPublicKey, $nMyPrivateKey, $ActinicDiffie::g_nPrime);
@bKey = ActinicDiffie::AsBytes($nMyEncryptKey);
$sCipherHeavy = EncryptSafer($sHeavy, @bKey);
my $sHeader = pack("C4NNC16",
$ActinicDiffie::BLOB_VERSION_2,
$ActinicDiffie::BLOB_SAFER_SK128,
$ActinicDiffie::BLOB_PRIME_128_1,
$ActinicDiffie::KEY_LENGTH_128,
(length $sCipherHeavy),
(length $sCipherLight),
ActinicDiffie::AsBytes($nMyPublicKey));
return(join '', $sHeader, $sCipherHeavy, $sCipherLight);
}
sub EncryptSafer
{
my	($sPlaintext, @bKey) = @_;
my	(@bExpanded, @block_in);
@block_in = (unpack "C*", $sPlaintext);
@bExpanded = ActinicSafer::ExpandUserKey(@bKey);
my	$nCipherLength = (int(($#block_in + 7) / 8) * 8); 
my	(@bCipher, @bIn, @bOut, $nPos, $i);
my	$nOutPos = 0;
for ($nPos = 0; $nPos <= $#block_in; $nPos = $nPos + 8)
{
if (($nPos + 7) <= $#block_in)
{
@bIn = @block_in[$nPos .. ($nPos+7)];
}
else
{
@bIn = ActinicSafer::Pad(@block_in[$nPos .. $#block_in]);
}
@bOut = ActinicSafer::EncryptBlock(@bIn, @bExpanded);
for ($i = 0; $i < 8; $i++)
{
$bCipher[$nOutPos++] = $bOut[$i];
}
}
return(pack("C*", @bCipher));
}
sub DecryptSafer
{
my	($sEncryptedtext, @bKey) = @_;
my	(@bExpanded, @block_in);
@block_in = (unpack "C*", $sEncryptedtext);
@bExpanded = ActinicSafer::ExpandUserKey(@bKey);
my	$nCipherLength = (int(($#block_in + 7) / 8) * 8); 
my	(@bCipher, @bIn, @bOut, $nPos, $i);
my	$nOutPos = 0;
for ($nPos = 0; $nPos <= $#block_in; $nPos = $nPos + 8)
{
if (($nPos + 7) <= $#block_in)
{
@bIn = @block_in[$nPos .. ($nPos+7)];
}
else
{
@bIn = ActinicSafer::Pad(@block_in[$nPos .. $#block_in]);
}
@bOut = ActinicSafer::DecryptBlock(@bIn, @bExpanded);
for ($i = 0; $i < 8; $i++)
{
$bCipher[$nOutPos++] = $bOut[$i];
}
}
return(pack("C*", @bCipher));
}
sub GenerateRandom()
{
my	($sData) = @_;
my	($i, $nPos, $nOffset);
my	(@bKey, @bExpanded);
my	(@bIn, @bOut);
srand (time() ^ ($$ + ($$ << 15)));
for ($i = 0; $i < 16; $i++)
{
$bKey[$i] = int(rand 256) & 0xFF;
}
@bExpanded = ActinicSafer::ExpandUserKey(@bKey);
my @block_in = unpack("C*", $sData);
for ($nPos = 0; $nPos < $#block_in; $nPos += 8)
{
if (($nPos + 7) <= $#block_in)
{
@bIn = $block_in[$nPos .. ($nPos+7)];
}
else
{
@bIn = ActinicSafer::Pad($block_in[$nPos .. $#block_in]);
}
@bOut = ActinicSafer::EncryptBlock(@bIn, @bExpanded);
for ($i = 0; $i < 8; $i++)
{
$bKey[$i + $nOffset] ^= $bOut[$i];
if ($#block_in < 8)
{
$bKey[$i+8] ^= $bOut[$i];
}
}
$nOffset ^= 8;
}
return(ActinicDiffie::FromBytes(@bKey));
}
1;