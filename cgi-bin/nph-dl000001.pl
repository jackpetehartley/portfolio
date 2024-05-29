#!/usr/bin/perl
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
push (@INC, "cgi-bin");
use strict;
use dd000001;
use CGI;
my $pCGI = new CGI;
my $DAT = $pCGI->param('DAT');
if (!$DAT ||
$DAT !~ /^[a-fA-F0-9]+$/ ||
(length $DAT) % 2 != 0)
{
Error("The link you clicked on was invalid. Please check the link and make sure you have included the entire URL.", $pCGI);
exit;
}
my ($status, $sError, $nTime, $sFile) = DigitalDownload::_UnpackData($pCGI->param('DAT'));
if ($status != $DigitalDownload::SUCCESS)
{
Error($sError, $pCGI);
exit;
}
if ($nTime != $DigitalDownload::UNLIMITED &&
$nTime < time())
{
Error("The download has expired.  Please contact us for the files.", $pCGI);
exit;
}
unless ($sFile =~ /^([-a-zA-Z0-9 _.]+)$/)
{
Error("Invalid filename.", $pCGI);
exit;
}
$sFile = $DigitalDownload::CONTENTPATH . $1;
unless (-e $sFile &&
-r $sFile &&
-f $sFile)
{
Error("Unable to access file.", $pCGI);
exit;
}
my $sPresentationFilename;
if ($sFile =~ /.*?_\d+_([- _a-zA-Z0-9.]+)$/)
{
$sPresentationFilename = $1;
}
my $SIZE_INDEX = 7;
my @temp = stat $sFile;
my $nSize = $temp[$SIZE_INDEX];
if ($DigitalDownload::NPH)
{
$|=1;
print $::ENV{SERVER_PROTOCOL} . " 200 OK\n";
}
print "Content-type: application/octet\n";
print "Content-disposition: attachment; filename=$sPresentationFilename\n";
print "Content-length: $nSize\n";
print "Server: " . $::ENV{SERVER_SOFTWARE} . "\n";
my ($day, $month, $now, $later, $expiry, @now, $sNow);
my (@days) = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
my (@months) = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
$now = time;
@now = gmtime($now);
$day = $days[$now[6]];
$month = $months[$now[4]];
$sNow = sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT", $day, $now[3],
$month, $now[5]+1900, $now[2], $now[1], $now[0]);
print "Date: $sNow\n\n";
my $BLOCKSIZE = 512000;
unless (open (DAT, "<$sFile"))
{
Error("Unable to open file> $!", $pCGI);
exit;
}
binmode DAT;
binmode STDOUT;
my $Block;
while (read DAT, $Block, $BLOCKSIZE)
{
print $Block;
}
close DAT;
exit;
sub Error
{
my ($sString, $pCGI) = @_;
if ($DigitalDownload::NPH)
{
$|=1;
print $pCGI->header(-nph => 1);
}
else
{
print $pCGI->header;
}
print $pCGI->start_html("Error");
print $pCGI->h1("Error");
print $sString;
print $pCGI->end_html;
}