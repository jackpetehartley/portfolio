#!/usr/local/bin/perl
package	ActinicDiffie;
use Exporter;
@ActinicDiffie::ISA = ('Exporter');
@ActinicDiffie::EXPORT_OK = ('ModPow', 'Encrypt', 'InitDiffie', , 'AsBytes', 'AsHex',
'g_nPrime', 'g_nBase', 'g_nPublicKey', 
'bnorm');
$ActinicDiffie::BLOB_HEADER_LENGTH = 8;
$ActinicDiffie::BLOB_VERSION_1 = 1;
$ActinicDiffie::BLOB_VERSION_2 = 2;
$ActinicDiffie::BLOB_SAFER_SK128 = 1;
$ActinicDiffie::BLOB_PRIME_128_1 = 0;
$ActinicDiffie::g_nPrime = '+46779512018758372353420000348743236593';
$ActinicDiffie::g_nBase = '+5';
$ActinicDiffie::g_nPublicKey = '+0';
$ActinicDiffie::KEY_LENGTH_256 = 32;
$ActinicDiffie::KEY_LENGTH_128 = 16;
BEGIN {}
END {}
$ActinicDiffie::zero = 0;
sub bnorm { #(num_str) return num_str
local($_) = @_;
s/\s+//g;
if (s/^([+-]?)0*(\d+)$/$1$2/) {
substr($_,$[,0) = '+' unless $1;
s/^-0/+0/;
$_;
} else {
'NaN';
}
}
sub internal { #(num_str) return int_num_array
local($d) = @_;
($is,$il) = (substr($d,$[,1),length($d)-2);
substr($d,$[,1) = '';
($is, reverse(unpack("a" . ($il%5+1) . ("a5" x ($il/5)), $d)));
}
sub external { #(int_num_array) return num_str
$es = shift;
grep($_ > 9999 || ($_ = substr('0000'.$_,-5)), @_);
&bnorm(join('', $es, reverse(@_)));
}
sub bneg { #(num_str) return num_str
local($_) = &bnorm(@_);
vec($_,0,8) ^= ord('+') ^ ord('-') unless $_ eq '+0';
s/^H/N/;
$_;
}
sub babs { #(num_str) return num_str
&abs(&bnorm(@_));
}
sub abs { # post-normalized abs for internal use
local($_) = @_;
s/^-/+/;
$_;
}
sub bcmp { #(num_str, num_str) return cond_code
local($x,$y) = (&bnorm($_[$[]),&bnorm($_[$[+1]));
if ($x eq 'NaN') {
undef;
} elsif ($y eq 'NaN') {
undef;
} else {
&cmp($x,$y);
}
}
sub cmp { # post-normalized compare for internal use
local($cx, $cy) = @_;
return 0 if ($cx eq $cy);
local($sx, $sy) = (substr($cx, 0, 1), substr($cy, 0, 1));
local($ld);
if ($sx eq '+') {
return  1 if ($sy eq '-' || $cy eq '+0');
$ld = length($cx) - length($cy);
return $ld if ($ld);
return $cx cmp $cy;
} else { # $sx eq '-'
return -1 if ($sy eq '+');
$ld = length($cy) - length($cx);
return $ld if ($ld);
return $cy cmp $cx;
}
}
sub badd { #(num_str, num_str) return num_str
local(*x, *y); ($x, $y) = (&bnorm($_[$[]),&bnorm($_[$[+1]));
if ($x eq 'NaN') {
'NaN';
} elsif ($y eq 'NaN') {
'NaN';
} else {
@x = &internal($x);
@y = &internal($y);
local($sx, $sy) = (shift @x, shift @y);
if ($sx eq $sy) {
&external($sx, &add(*x, *y));
} else {
($x, $y) = (&abs($x),&abs($y));
if (&cmp($y,$x) > 0) {
&external($sy, &sub(*y, *x));
} else {
&external($sx, &sub(*x, *y));
}
}
}
}
sub bsub { #(num_str, num_str) return num_str
&badd($_[$[],&bneg($_[$[+1]));    
}
sub bgcd { #(num_str, num_str) return num_str
local($x,$y) = (&bnorm($_[$[]),&bnorm($_[$[+1]));
if ($x eq 'NaN' || $y eq 'NaN') {
'NaN';
} else {
($x, $y) = ($y,&bmod($x,$y)) while $y ne '+0';
$x;
}
}
sub add { #(int_num_array, int_num_array) return int_num_array
local(*x, *y) = @_;
$car = 0;
for $x (@x) {
last unless @y || $car;
$x -= 1e5 if $car = (($x += shift(@y) + $car) >= 1e5);
}
for $y (@y) {
last unless $car;
$y -= 1e5 if $car = (($y += $car) >= 1e5);
}
(@x, @y, $car);
}
sub sub { #(int_num_array, int_num_array) return int_num_array
local(*sx, *sy) = @_;
$bar = 0;
for $sx (@sx) {
last unless @y || $bar;
$sx += 1e5 if $bar = (($sx -= shift(@sy) + $bar) < 0);
}
@sx;
}
sub bmul { #(num_str, num_str) return num_str
local(*x, *y); ($x, $y) = (&bnorm($_[$[]), &bnorm($_[$[+1]));
if ($x eq 'NaN') {
'NaN';
} elsif ($y eq 'NaN') {
'NaN';
} else {
@x = &internal($x);
@y = &internal($y);
local($signr) = (shift @x ne shift @y) ? '-' : '+';
@prod = ();
for $x (@x) {
($car, $cty) = (0, $[);
for $y (@y) {
$prod = $x * $y + $prod[$cty] + $car;
$prod[$cty++] =
$prod - ($car = int($prod * 1e-5)) * 1e5;
}
$prod[$cty] += $car if $car;
$x = shift @prod;
}
&external($signr, @x, @prod);
}
}
sub bmod { #(num_str, num_str) return num_str
(&bdiv(@_))[$[+1];
}
sub bdiv { #(dividend: num_str, divisor: num_str) return num_str
local (*x, *y); ($x, $y) = (&bnorm($_[$[]), &bnorm($_[$[+1]));
return wantarray ? ('NaN','NaN') : 'NaN'
if ($x eq 'NaN' || $y eq 'NaN' || $y eq '+0');
return wantarray ? ('+0',$x) : '+0' if (&cmp(&abs($x),&abs($y)) < 0);
@x = &internal($x); @y = &internal($y);
$srem = $y[$[];
$sr = (shift @x ne shift @y) ? '-' : '+';
$car = $bar = $prd = 0;
if (($dd = int(1e5/($y[$#y]+1))) != 1) {
for $x (@x) {
$x = $x * $dd + $car;
$x -= ($car = int($x * 1e-5)) * 1e5;
}
push(@x, $car); $car = 0;
for $y (@y) {
$y = $y * $dd + $car;
$y -= ($car = int($y * 1e-5)) * 1e5;
}
}
else {
push(@x, 0);
}
@q = (); ($v2,$v1) = @y[-2,-1];
while ($#x > $#y) {
($u2,$u1,$u0) = @x[-3..-1];
$q = (($u0 == $v1) ? 99999 : int(($u0*1e5+$u1)/$v1));
--$q while ($v2*$q > ($u0*1e5+$u1-$q*$v1)*1e5+$u2);
if ($q) {
($car, $bar) = (0,0);
for ($y = $[, $x = $#x-$#y+$[-1; $y <= $#y; ++$y,++$x) {
$prd = $q * $y[$y] + $car;
$prd -= ($car = int($prd * 1e-5)) * 1e5;
$x[$x] += 1e5 if ($bar = (($x[$x] -= $prd + $bar) < 0));
}
if ($x[$#x] < $car + $bar) {
$car = 0; --$q;
for ($y = $[, $x = $#x-$#y+$[-1; $y <= $#y; ++$y,++$x) {
$x[$x] -= 1e5
if ($car = (($x[$x] += $y[$y] + $car) > 1e5));
}
}   
}
pop(@x); unshift(@q, $q);
}
if (wantarray) {
@d = ();
if ($dd != 1) {
$car = 0;
for $x (reverse @x) {
$prd = $car * 1e5 + $x;
$car = $prd - ($tmp = int($prd / $dd)) * $dd;
unshift(@d, $tmp);
}
}
else {
@d = @x;
}
(&external($sr, @q), &external($srem, @d, $zero));
} else {
&external($sr, @q);
}
}
sub ModPow
{
my ($nValue, $nPower, $nModulo) = @_;
my $nSquare = $nValue;
my $nResult = '+1';
if ($nPower <= 0)
{
return('+1');					
}
while ($nPower ne '+0')
{
if ($nPower =~ /([13579])$/)
{
if ($nResult eq '+1')
{
$nResult = $nSquare;
}
else
{
$nResult = &bmod(&bmul($nResult, $nSquare), $nModulo);
}
}
$nSquare = &bmod(&bmul($nSquare, $nSquare), $nModulo);
$nPower = &bdiv($nPower, '+2');
}
return($nResult);
}
sub AsBytes
{
my	$nNumber = shift;
my	(@bResult, $nPos);
for ($nPos = 0; $nPos < 16; $nPos++)
{
$bResult[$nPos] = bmod($nNumber, '256');
$nNumber = bdiv($nNumber, '256');
}
return(@bResult);
}
sub AsHex
{
my	$nNumber = shift;
my	(@bytes, $nPos, $sOutput);
$sOutput = "";
@bytes = ActinicDiffie::AsBytes($nNumber);
for ($nPos = $#bytes; $nPos >= 0; $nPos--)
{
$sOutput = $sOutput . sprintf "%02x", $bytes[$nPos];
}
return($sOutput);
}
sub FromBytes
{
my	$nRetVal = &bnorm($_[$#_]);
my	$i;
for ($i = $#_ - 1; $i >= 0; $i--)
{
$nRetVal = badd(bmul($nRetVal, '256'), $_[$i]);
}
return($nRetVal);
}
sub InitDiffie
{
my $nPos;
$ActinicDiffie::g_nPublicKey = '+0';
for ($nPos = $#_; $nPos >= 0; $nPos--)
{
$ActinicDiffie::g_nPublicKey = badd(bmul($ActinicDiffie::g_nPublicKey, 256), $_[$nPos]);
}		
}
1;