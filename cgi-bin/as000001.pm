#!/usr/local/bin/perl
package ActinicSafer;
use integer;
use strict;
use Exporter;
@ActinicSafer::ISA = ('Exporter');
@ActinicSafer::EXPORT_OK = ('ExpandUserKey', 'EncryptBlock', 'DecryptBlock');
$ActinicSafer::SAFER_K64_DEFAULT_NOF_ROUNDS =  6;
$ActinicSafer::SAFER_K128_DEFAULT_NOF_ROUNDS = 10;
$ActinicSafer::SAFER_SK64_DEFAULT_NOF_ROUNDS =  8;
$ActinicSafer::SAFER_SK128_DEFAULT_NOF_ROUNDS = 10;
$ActinicSafer::SAFER_NOF_ROUNDS = $ActinicSafer::SAFER_SK128_DEFAULT_NOF_ROUNDS;
$ActinicSafer::SAFER_MAX_NOF_ROUNDS = 13;
$ActinicSafer::SAFER_BLOCK_LEN = 8;
$ActinicSafer::SAFER_KEY_LEN  = (1 + $ActinicSafer::SAFER_BLOCK_LEN * (1 + 2 * $ActinicSafer::SAFER_MAX_NOF_ROUNDS));
$ActinicSafer::SAFER_STRENGTHENED = 1;
$ActinicSafer::TAB_LEN = 256;
sub Add
{
my ($x, $y) = @_;
return(((($x & 0xFF) + ($y & 0xFF)) & 0xFF));
}
sub Subtract
{
my ($x, $y) = @_;
return(((($x & 0xFF) - ($y & 0xFF)) & 0xFF));
}
sub Xor
{
my ($x, $y) = @_;
return(((($x & 0xFF) ^ ($y & 0xFF)) & 0xFF));
}
sub Exp
{
my $x = shift;
return($ActinicSafer::m_ExpTab[($x & 0xFF)]);
}
sub Log
{
my $x = shift;
return($ActinicSafer::m_LogTab[($x & 0xFF)]);
}
sub RotateLeft	 
{
my ($x, $n) = @_;
my ($top, $bottom);
$top = (($x & 0xFF) << $n) & 0xFF;
$bottom = (($x & 0xFF) >> (8 - $n)) & 0xFF;
return (($top | $bottom) & 0xFF);
}
sub Pad
{
my  (@bIn) = @_;
my 	@bOut;
my 	$nIndex;
for ($nIndex = 0; ($nIndex < @bIn.length) && ($nIndex < 8); $nIndex++)
{
$bOut[$nIndex] = $bIn[$nIndex];
}
while ($nIndex < 8)
{
$bOut[$nIndex] = 0;
}
return(@bOut);
}
sub InitTables
{
my 	($i, $ExpValue);
$ExpValue = 1;
for ($i = 0; $i < $ActinicSafer::TAB_LEN; $i++)
{
$ActinicSafer::m_ExpTab[$i] = ($ExpValue & 0xFF);
$ActinicSafer::m_LogTab[$ActinicSafer::m_ExpTab[$i] & 0xFF] = $i;
$ExpValue = ($ExpValue * 45) % 257;
}
}
sub ExpandUserKey(@)
{
my (@userkey) = @_;
my 	($i, $j);
if ($$::g_pSetupBlob{'KEY_LENGTH'} < 128)
{
for ($i = $$::g_pSetupBlob{'KEY_LENGTH'} / 8; $i < 16; $i++)
{
$userkey[$i] = 0;
}
}
my 	@ka;
my 	@kb;
my	$nof_rounds = $ActinicSafer::SAFER_NOF_ROUNDS;
my	$nIndex = 0;
my	@key;
$key[$nIndex++] = $nof_rounds;
$ka[$ActinicSafer::SAFER_BLOCK_LEN] = 0;
$kb[$ActinicSafer::SAFER_BLOCK_LEN] = 0;
for ($j = 0; $j < $ActinicSafer::SAFER_BLOCK_LEN; $j++)
{
$ka[$j] = RotateLeft($userkey[$j], 5);
$ka[$ActinicSafer::SAFER_BLOCK_LEN] ^= $ka[$j];
$key[$nIndex] = $userkey[$j+8];
$kb[$j] = $key[$nIndex++];
$kb[$ActinicSafer::SAFER_BLOCK_LEN] ^= $kb[$j];
}
for ($i = 1; $i <= $nof_rounds; $i++)
{
for ($j = 0; $j < $ActinicSafer::SAFER_BLOCK_LEN + 1; $j++)
{
$ka[$j] = RotateLeft($ka[$j], 6);
$kb[$j] = RotateLeft($kb[$j], 6);
}
for ($j = 0; $j < $ActinicSafer::SAFER_BLOCK_LEN; $j++)
{
if ($ActinicSafer::SAFER_STRENGTHENED)
{
$key[$nIndex++] = ((($ka[($j + 2 * $i - 1) % ($ActinicSafer::SAFER_BLOCK_LEN + 1)] & 0xFF)
+ $ActinicSafer::m_ExpTab[$ActinicSafer::m_ExpTab[18 * $i + $j + 1]]) & 0xFF);
}
else
{
$key[$nIndex++] = ((($ka[$j] & 0xFF)
+ $ActinicSafer::m_ExpTab[$ActinicSafer::m_ExpTab[18 * $i + $j + 1]]) & 0xFF);
}
}
for ($j = 0; $j < $ActinicSafer::SAFER_BLOCK_LEN; $j++)
{
if ($ActinicSafer::SAFER_STRENGTHENED)
{
$key[$nIndex++] = ((($kb[($j + 2 * $i) % ($ActinicSafer::SAFER_BLOCK_LEN + 1)] & 0xFF)
+ $ActinicSafer::m_ExpTab[$ActinicSafer::m_ExpTab[18 * $i + $j + 10]]) & 0xFF);
}
else
{
$key[$nIndex++] = ((($kb[$j] & 0xFF)
+ $ActinicSafer::m_ExpTab[$ActinicSafer::m_ExpTab[18 * $i + $j + 10]]) & 0xFF);
}
}
}
for ($j = 0; $j < $ActinicSafer::SAFER_BLOCK_LEN + 1; $j++)
{
$ka[$j] = $kb[$j] = 0;
}
return(@key);
}
sub EncryptBlock
{
my	($a, $b, $c, $d, $e, $f, $g, $h, $t);
my	$round;
$a = shift; 
$b = shift; 
$c = shift; 
$d = shift;
$e = shift; 
$f = shift; 
$g = shift; 
$h = shift;
$round = shift;
if ($ActinicSafer::SAFER_MAX_NOF_ROUNDS < $round) 
{
$round = $ActinicSafer::SAFER_MAX_NOF_ROUNDS;
}
while($round-- > 0)
{
$a = Xor($a, shift); 
$b = Add($b, shift); 
$c = Add($c, shift); 
$d = Xor($d, shift);
$e = Xor($e, shift); 
$f = Add($f, shift); 
$g = Add($g, shift); 
$h = Xor($h, shift);
$a = Add(Exp($a), shift); 
$b = Xor(Log($b), shift);
$c = Xor(Log($c), shift); 
$d = Add(Exp($d), shift);
$e = Add(Exp($e), shift); 
$f = Xor(Log($f), shift);
$g = Xor(Log($g), shift); 
$h = Add(Exp($h), shift);
$b = Add($b, $a); $a = Add($a, $b); $d = Add($d, $c); $c = Add($c, $d); 
$f = Add($f, $e); $e = Add($e, $f); $h = Add($h, $g); $g = Add($g, $h);
$c = Add($c, $a); $a = Add($a, $c); $g = Add($g, $e); $e = Add($e, $g); 
$d = Add($d, $b); $b = Add($b, $d); $h = Add($h, $f); $f = Add($f, $h);
$e = Add($e, $a); $a = Add($a, $e); $f = Add($f, $b); $b = Add($b, $f); 
$g = Add($g, $c); $c = Add($c, $g); $h = Add($h, $d); $d = Add($d, $h);
$t = $b; $b = $e; $e = $c; $c = $t; $t = $d; $d = $f; $f = $g; $g = $t;
}
$a = Xor($a, shift); 
$b = Add($b, shift); 
$c = Add($c, shift); 
$d = Xor($d, shift);
$e = Xor($e, shift); 
$f = Add($f, shift); 
$g = Add($g, shift); 
$h = Xor($h, shift);
return($a, $b, $c, $d, $e, $f, $g, $h);
}
sub DecryptBlock(@@)
{   
my	($a, $b, $c, $d, $e, $f, $g, $h, $t);
my	$round;
my	$nIndex = 0;
my	@block_out;
$a = shift;
$b = shift; 
$c = shift; 
$d = shift; 
$e = shift; 
$f = shift; 
$g = shift; 
$h = shift; 
my @key = @_;
$round = $key[0];
if ($ActinicSafer::SAFER_MAX_NOF_ROUNDS < $round) 
{
$round = $ActinicSafer::SAFER_MAX_NOF_ROUNDS;
}
$nIndex += $ActinicSafer::SAFER_BLOCK_LEN * (1 + 2 * $round);
$h = Xor($h, $key[$nIndex]); 
$g = Subtract($g, $key[--$nIndex]); 
$f = Subtract($f, $key[--$nIndex]); 
$e = Xor($e, $key[--$nIndex]);
$d = Xor($d, $key[--$nIndex]); 
$c = Subtract($c, $key[--$nIndex]); 
$b = Subtract($b, $key[--$nIndex]); 
$a = Xor($a, $key[--$nIndex]);
while ($round-- > 0)
{
$t = $e; $e = $b; $b = $c; $c = $t; $t = $f; $f = $d; $d = $g; $g = $t;
$a = Subtract($a, $e); $e = Subtract($e, $a); $b = Subtract($b, $f); $f = Subtract($f, $b); 
$c = Subtract($c, $g); $g = Subtract($g, $c); $d = Subtract($d, $h); $h = Subtract($h, $d);
$a = Subtract($a, $c); $c = Subtract($c, $a); $e = Subtract($e, $g); $g = Subtract($g, $e); 
$b = Subtract($b, $d); $d = Subtract($d, $b); $f = Subtract($f, $h); $h = Subtract($h, $f); 
$a = Subtract($a, $b); $b = Subtract($b, $a); $c = Subtract($c, $d); $d = Subtract($d, $c); 
$e = Subtract($e, $f); $f = Subtract($f, $e); $g = Subtract($g, $h); $h = Subtract($h, $g);
$h = Subtract($h, $key[--$nIndex]); 
$g = Xor($g, $key[--$nIndex]); 
$f = Xor($f, $key[--$nIndex]); 
$e = Subtract($e, $key[--$nIndex]);
$d = Subtract($d, $key[--$nIndex]); 
$c = Xor($c, $key[--$nIndex]); 
$b = Xor($b, $key[--$nIndex]); 
$a = Subtract($a, $key[--$nIndex]);
$h = Xor(Log($h), $key[--$nIndex]); 
$g = Subtract(Exp($g), $key[--$nIndex]);
$f = Subtract(Exp($f), $key[--$nIndex]); 
$e = Xor(Log($e), $key[--$nIndex]);
$d = Xor(Log($d), $key[--$nIndex]); 
$c = Subtract(Exp($c), $key[--$nIndex]);
$b = Subtract(Exp($b), $key[--$nIndex]); 
$a = Xor(Log($a), $key[--$nIndex]);
}
return($a, $b, $c, $d, $e, $f, $g, $h);
}
1;
package main;