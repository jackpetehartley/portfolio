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
require al000001;
use File::Copy;
use strict;
$::BD_COPY_32 = 0x01;									 # Copy x bytes (32 bit count)
$::BD_COPY_16 = 0x02;									 # Copy x bytes (16 bit count)
$::BD_COPY_8  = 0x03;									 # Copy x bytes (8 bit count)
$::BD_INSERT_32 = 0x04;
$::BD_INSERT_16 = 0x05;
$::BD_INSERT_8  = 0x06;
$::BD_DELETE_32 = 0x07;
$::BD_DELETE_16 = 0x08;
$::BD_DELETE_8  = 0x09;
$::BD_CHECKSUM_TO = 0x0A;								 # 32 bit checksum of all bytes in 'to' file
$::BD_LENGTH_TO   = 0x0B;								 # 32 bit length of 'to' file
$::MAX_RETRY_COUNT      = 10;
$::RETRY_SLEEP_DURATION = 1;
$::s_bUseNonParsedHeaders = $::FALSE;
PrepareResponse();
my ($status, $sError, $sEnv, $unused);
($status, $sError, $sEnv, $unused, %::g_InputHash) = ACTINIC::ReadAndParseInput();
if ($::SUCCESS != $status)
{
SendResponse($sError . "\n");
CompleteResponse();
exit;
}
my $sPath = ACTINIC::GetPath();
ACTINIC::SecurePath($sPath);
($status, $sError) = ACTINIC::AuthenticateUser($::g_InputHash{USER}, $::g_InputHash{PASS});
if ($status != $::SUCCESS)
{
SendResponse(InsertString("IDS_MD_AUTHORISATION_FAILED") . "\n");
CompleteResponse();
exit;
}
my @Basenames = split(/ /, $::g_InputHash{BASE});
my $sBase;
foreach $sBase (@Basenames)
{
$sBase = ACTINIC::CleanFileName($sBase);
SendResponse("Message: Applying changes to $sBase\n");
($status, $sError) = BDApplyDiff($sPath . "old"  . $sBase . ".fil",
$sPath . "full" . $sBase . ".fil",
$sPath . "diff" . $sBase . ".fil");
if ($::SUCCESS != $status)
{
SendResponse($sError . "\n");
CompleteResponse();
exit;
}
}
SendResponse("OK\n");
CompleteResponse();
exit;
sub BDApplyDiff
{
my ($sOldFileName, $sNewFileName, $sDiffFileName) = @_;
my $bDiffFileExists = (-e $sDiffFileName && 0 != -s $sDiffFileName);
my $bNewFileExists = -e $sNewFileName;
my $bOldFileExists = -e $sOldFileName;
if (!$bNewFileExists &&
!$bDiffFileExists)
{
return ($::SUCCESS, undef);
}
if ($bNewFileExists)
{
if ($bOldFileExists)
{
unlink($sOldFileName);
}
if (!copy($sNewFileName, $sOldFileName))
{
my $sError = $!;
return ($::FAILURE, InsertString("IDS_MD_CORUPTINDEX", $sNewFileName, $sOldFileName, $sError));
}
else
{
return ($::SUCCESS, undef);
}
}
if (!$bOldFileExists)
{
return ($::FAILURE, InsertString("IDS_MD_NO_COMPLETE_FILE"));
}
my $sPath = $sOldFileName;
$sPath =~ s/[^\/]*$//;							 # strip the filename off of $sOldFileName to find the path
my $sScratchFilePart = "aaaaaaaa";			 # build a temporary filename start point - would like to use POSIX::tmpnam, but don't want to
my $nCount = 0;
while (-e ($sPath . $sScratchFilePart . '.fil') &&
$nCount < 4000)							 # but don't loop forever
{
$sScratchFilePart++;
}
if (4000 == $nCount)
{
return ($::FAILURE, InsertString("IDS_MD_CANT_CREATE_UNIQUE_SCRATCH"));
}
my $sScratchFile = $sPath . $sScratchFilePart . '.fil';
my ($status, $sMessage) = OpenWithRetry(\*FROM, "<$sOldFileName");
if ($status != $::SUCCESS)
{
return ($::FAILURE, InsertString("IDS_MD_CANT_OPEN_FROM", $sOldFileName,  $sMessage));
}
binmode FROM;
($status, $sMessage) = OpenWithRetry(\*TO, ">$sScratchFile");
if ($status != $::SUCCESS)
{
close(FROM);
return ($::FAILURE, InsertString("IDS_MD_CANT_OPEN_TO", $sScratchFile,  $sMessage));
}
binmode TO;
unless (open (DIFF, "<$sDiffFileName"))
{
my $sError = $!;
close(TO);
close(FROM);
unlink ($sScratchFile);
return ($::FAILURE, InsertString("IDS_MD_CANT_OPEN_DIFF", $sDiffFileName,  $sError));
}
binmode DIFF;
my $sFromFile = $sOldFileName;
SendResponse("Progress: 0\n");
my @tmp = stat DIFF;
my $nFileLength = $tmp[7];
my ($status, $sError, $nLength, $nCommand, $Buffer);
my $nChecksum = 0;
my $nCurrentProgress = 0;
while (!eof(DIFF))
{
if (0 < $nFileLength)
{
my $nProgress = int ((tell DIFF) / $nFileLength * 100);
if (abs($nProgress - $nCurrentProgress) > 3)
{
$nCurrentProgress = $nProgress;
SendResponse("Progress: $nProgress\n");
}
}
unless (1 == read DIFF, $Buffer, 1)
{
last;
}
($nCommand) = unpack "C", $Buffer;
if ($::BD_COPY_32 == $nCommand)				 # Copy x bytes (32 bit count)
{
($status, $sError, $nLength) = BDGetLength32(\*DIFF);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
($status, $sError, $nChecksum) = BDCopyData(\*FROM, \*TO, $nLength, $nChecksum);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
}
elsif ($::BD_COPY_16 == $nCommand)			 # Copy x bytes (16 bit count)
{
($status, $sError, $nLength) = BDGetLength16(\*DIFF);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
($status, $sError, $nChecksum) = BDCopyData(\*FROM, \*TO, $nLength, $nChecksum);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
}
elsif ($::BD_COPY_8 == $nCommand)			 # Copy x bytes (8 bit count)
{
($status, $sError, $nLength) = BDGetLength8(\*DIFF);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
($status, $sError, $nChecksum) = BDCopyData(\*FROM, \*TO, $nLength, $nChecksum);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
}
elsif ($::BD_INSERT_32 == $nCommand)		 # Insert x bytes (32 bit count)
{
($status, $sError, $nLength) = BDGetLength32(\*DIFF);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
($status, $sError, $nChecksum) = BDCopyData(\*DIFF, \*TO, $nLength, $nChecksum);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
}
elsif ($::BD_INSERT_16 == $nCommand)		 # Insert x bytes (16 bit count)
{
($status, $sError, $nLength) = BDGetLength16(\*DIFF);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
($status, $sError, $nChecksum) = BDCopyData(\*DIFF, \*TO, $nLength, $nChecksum);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
}
elsif ($::BD_INSERT_8 == $nCommand)			 # Insert x bytes (8 bit count)
{
($status, $sError, $nLength) = BDGetLength8(\*DIFF);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
($status, $sError, $nChecksum) = BDCopyData(\*DIFF, \*TO, $nLength, $nChecksum);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
}
elsif ($::BD_DELETE_32 == $nCommand)
{
($status, $sError, $nLength) = BDGetLength32(\*DIFF);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
unless (seek FROM, $nLength, 1)
{
my $sError = $!;
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($::FAILURE, InsertString("IDS_MD_ERROR_SEEKING_FROM", $sFromFile, tell(FROM), $nLength, $sError));
}
}
elsif($::BD_DELETE_16 == $nCommand)
{
($status, $sError, $nLength) = BDGetLength16(\*DIFF);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
unless (seek FROM, $nLength, 1)
{
my $sError = $!;
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($::FAILURE, InsertString("IDS_MD_ERROR_SEEKING_FROM", $sFromFile, tell(FROM), $nLength, $sError));
}
}
elsif ($::BD_DELETE_8 == $nCommand)
{
($status, $sError, $nLength) = BDGetLength8(\*DIFF);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
unless (seek FROM, $nLength, 1)
{
my $sError = $!;
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($::FAILURE, InsertString("IDS_MD_ERROR_SEEKING_FROM", $sFromFile, tell(FROM), $nLength, $sError));
}
}
elsif ($::BD_CHECKSUM_TO == $nCommand)		 # 32 bit checksum of all bytes in 'to' file
{
($status, $sError, $nLength) = BDGetLength32(\*DIFF);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
if ($nLength != $nChecksum)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($::FAILURE, InsertString("IDS_MD_CHECKSUM_ERROR", $nLength, $nChecksum));
}
}
elsif ($::BD_LENGTH_TO)							 # 32 bit length of 'to' file
{
($status, $sError, $nLength) = BDGetLength32(\*DIFF);
if ($::SUCCESS != $status)
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($status, $sError);
}
my $nTell = tell TO;
if ($nLength != $nTell)						 # Check the length we've written
{
close(DIFF);
close(TO);
close(FROM);
if ($sScratchFile)
{
unlink ($sScratchFile);
}
return ($::FAILURE, InsertString("IDS_MD_DIFF_LENGTH_ERROR", $nLength, $nTell));
}
}
}
close(FROM);
close(TO);
close(DIFF);
if ($sScratchFile)
{
unlink($sOldFileName);
if (!rename ($sScratchFile, $sOldFileName))
{
my $sError = $!;
unlink ($sScratchFile);
return ($::FAILURE, InsertString("IDS_MD_CORRUPT_WEB", $sScratchFile, $sOldFileName, $sError));
}
}
return ($::SUCCESS);
}
sub BDGetLength32
{
my ($pFile) = @_;
my $nLength = 0;
my $Buffer;
unless (4 == read $pFile, $Buffer, 4)
{
return($::FAILURE, InsertString("IDS_MD_ERROR_READING_FILE", $!));
}
($nLength) = unpack "N", $Buffer;
return($::SUCCESS, undef, $nLength);
}
sub BDGetLength16
{
my ($pFile) = @_;
my $nLength = 0;
my $Buffer;
unless (2 == read $pFile, $Buffer, 2)
{
return($::FAILURE, InsertString("IDS_MD_ERROR_READING_FILE", $!));
}
($nLength) = unpack "n", $Buffer;
return($::SUCCESS, undef, $nLength);
}
sub BDGetLength8
{
my ($pFile) = @_;
my $nLength = 0;
my $Buffer;
unless (1 == read $pFile, $Buffer, 1)
{
return($::FAILURE, InsertString("IDS_MD_ERROR_READING_FILE", $!));
}
($nLength) = unpack "C", $Buffer;
return($::SUCCESS, undef, $nLength);
}
sub BDCopyData
{
my ($pFrom, $pTo, $nLength, $nChecksum) = @_;
my	$nChar;
my $Buffer;
unless ($nLength == read $pFrom, $Buffer, $nLength)
{
return ($::FAILURE, InsertString("IDS_MD_ERROR_COPY_FROM", $!), $nChecksum);
}
my @Data = unpack "C$nLength", $Buffer;
$nChecksum += unpack "%32C*", $Buffer;
unless (print $pTo $Buffer)
{
return ($::FAILURE, InsertString("IDS_MD_ERROR_COPY_TO", $!), $nChecksum);
}
return($::SUCCESS, undef, $nChecksum);
}
sub OpenWithRetry
{
my ($rFile, $sFilename) = @_;
my $nAttempt = $::MAX_RETRY_COUNT;
my $bOpenFailed = $::TRUE;
while ($nAttempt-- &&
$bOpenFailed)
{
if (open ($rFile, $sFilename))
{
$bOpenFailed = $::FALSE;
}
if ($nAttempt &&
$bOpenFailed)
{
sleep($::RETRY_SLEEP_DURATION);
}
}
return ($bOpenFailed ? $::FAILURE : $::SUCCESS, $!);
}
sub PrepareResponse
{
if ($::s_bUseNonParsedHeaders)
{
ACTINIC::PrintNonParsedHeader("text/plain");
binmode STDOUT;
}
}
sub SendResponse
{
if ($::s_bUseNonParsedHeaders)
{
print STDOUT $_[0];
}
else
{
$::s_sResponseCache .= $_[0];
}
}
sub CompleteResponse
{
if (!$::s_bUseNonParsedHeaders)
{
binmode STDOUT;
ACTINIC::PrintHeader("text/plain", (length $::s_sResponseCache), undef, $::FALSE);
print STDOUT $::s_sResponseCache;
}
}
sub InsertString
{
no strict 'refs';
my ($sResult, $sID, @args);
if ($#_ < 0)
{
return ("Invalid argument count in sub InsertString!");
}
($sID, @args) = @_;
if (!defined $::g_pPrompts)
{
my @Response = ACTINIC::ReadConfigurationFile($sPath . "mergephrase.fil",'$g_pPrompts');
$::s_bLoadFailed = ($Response[0] != $::SUCCESS);
}
if ($::s_bLoadFailed ||
! defined $$::g_pPrompts{$sID})
{
$::g_pPrompts =
{
'IDS_MD_NO_COMPLETE_FILE' => "No complete file exists to apply the differential file to.  Please refresh the catalog site.\n",
'IDS_MD_CORUPTINDEX' => "The web site index has been corrupted.  Catalog is unable to update the index.  Copy %s to %s failed.  %s.  Please refresh the site.",
'IDS_MD_CANT_OPEN_FROM' => "Cannot open differential 'old' file '%s'.  %s",
'IDS_MD_CANT_OPEN_TO' => "Cannot open output scratch file '%s'.  %s",
'IDS_MD_CANT_OPEN_DIFF' => "Cannot open differential 'diff' file '%s'.  %s",
'IDS_MD_CANT_CREATE_UNIQUE_SCRATCH' => "Unable to create a unique scratch file.",
'IDS_MD_ERROR_SEEKING_FROM' => "Error seeking in 'from' file '%s' (%d, %d).  %s",
'IDS_MD_CHECKSUM_ERROR' => "Diff file checksum error (Calculated %d, Expected %d).\r\nPlease refresh your website. If the problem persists and you are unable to upload your store contact support.",
'IDS_MD_DIFF_LENGTH_ERROR' => "Diff file length error (Expected %d, Actual %d).",
'IDS_MD_CORRUPT_WEB' => "The web site index has been corrupted.  Copy %s to %s.  %s.  Please refresh the site.",
'IDS_MD_ERROR_READING_FILE' => "Error reading file. %s",
'IDS_MD_ERROR_COPY_FROM' => "Error copying from 'from' file.  %s",
'IDS_MD_ERROR_COPY_TO' => "Error copying to 'to' file.  %s",
'IDS_MD_AUTHORISATION_FAILED' => "Bad Catalog username or password. Check your Housekeeping | Security settings and try again. If that fails, try refreshing the site.",
};
}
if (!defined $$::g_pPrompts{$sID})
{
return ("The requested phrase is not defined!");
}
$sResult = $$::g_pPrompts{$sID};
if ($#args > -1)
{
$sResult = sprintf($sResult, @args);
}
return ($sResult);
}