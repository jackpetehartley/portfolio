#!/usr/bin/perl
use strict;
use Socket;
$::prog_name = "CATALOG";
$::prog_ver = '$Revision: 18819 $';
$::prog_ver = substr($::prog_ver, 11);
$::prog_ver =~ s/ \$//;
$::FALSE = 0;
$::TRUE = 1;
$::DOS_SLEEP_DURATION = 2;
$::FAILURE 	= 0;
$::SUCCESS 	= 1;
$::NOTFOUND = 2;
$::FAILEDSEARCH = $::NOTFOUND;
$::EOF		= 3;
$::EOB     	= 4;
$::BADDATA	= 5;
$::WARNING	= 6;
$::ACCEPTED	= 7;
$::REJECTED	= 8;
$::PENDING	= 9;
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
umask (0177);
$::g_nErrorNumber = 200;
$::g_sErrorFilename = "error.err";
$::PAD_SPACE = " " x 40;
$::g_sDaemonAddress = 'NETQUOTEVAR:DAEMONADDRESS';
$::g_nDaemonPort    = 'NETQUOTEVAR:DAEMONPORT';
$::g_bPathKnown = 0;
$::g_sPath = '../gk/acatalog/';
$::g_sAlternatePath = '';
$::g_bUseAlternatePath = $::FALSE;
SecurePath($::g_sPath, 459);
$::g_bActinicHostMode = $::FALSE;
if (!$::g_bActinicHostMode)
{
if (! -e $::g_sPath)
{
$::g_sInternalErrors .= "path does not exist :$::g_sPath:, ";
$::g_nErrorNumber = 542;
$::g_bPathKnown = 0;
}
elsif (! -r $::g_sPath)
{
$::g_sInternalErrors .= "path is not readable :$::g_sPath:, ";
$::g_nErrorNumber = 543;
$::g_bPathKnown = 0;
}
else
{
$::g_bPathKnown = 1;
}
}
$::g_sVersionDayno = '';
if ($ENV{CONTENT_LENGTH} > 0)
{
ReadAndParseHTTP();
}
elsif ($ENV{QUERY_STRING} eq 'getordernum')
{
GetOrderNum();
SendResponse();
exit;
}
else
{
my ($sMessage) = "<HTML>\n" .
"<HEAD><TITLE>Script Error!</TITLE></HEAD>\n" .
"<BODY>\n" .
"<BLINK><B><FONT COLOR=\"\#FF0000\">\n" .
"Script Error" .
"</FONT></B></BLINK>\n" .
"</BODY>\n" .
"</HTML>\n";
PrintHeader('text/html', length $sMessage, undef, $::FALSE);
binmode STDOUT;
print $sMessage;
exit;
}
$::g_sErrorFilename = $::g_sPath . 'error.err';
my %SupportedCommands = map { $_ => 1 } qw ( create getkey getordernum setordernum lookup lookrt shopid delete version date list trial baseurl rename getservertime);
unless ($SupportedCommands{$::g_sAction})
{
$::g_sInternalErrors .= "unknown command :$::g_sAction:, ";
$::g_nErrorNumber = 456;
RecordErrors();
SendResponse();
exit;
}
if ($::g_sInternalErrors ne '')
{
RecordErrors();
SendResponse();
exit;
}
$::g_sFilename = $::g_sPath . $::g_sFilenameBase . '.' . $::g_sFilenameExtension; # Set PATH & filename
if ($::g_sAction eq "create")
{
CreateFile();
}
elsif ($::g_sAction eq "getkey")
{
GetPublicKey();
}	
elsif ($::g_sAction eq "getordernum")
{
GetOrderNum();
}
elsif ($::g_sAction eq "setordernum")
{
SetOrderNum();
}	
elsif (substr($::g_sAction,0,4) eq "look")
{
LookUpAndRetrieve();
}
elsif ($::g_sAction eq "delete")
{
DeleteFile();
}
elsif ($::g_sAction eq "rename")
{
RenameFile();
}
elsif ($::g_sAction eq "version")
{
my $s_scriptVersionDayno = "90 IDWA";
if ($::g_sVersionDayno ge $s_scriptVersionDayno)
{
$::g_OutputData = $s_scriptVersionDayno;
}
else
{
$::g_OutputData = $::g_sVersionDayno;
}
}
elsif ($::g_sAction eq "date")
{
GetFileDate();
}
elsif ($::g_sAction eq "list")
{
GetFileList();
}
elsif ($::g_sAction eq "trial")
{
$::g_OutputData = $::g_bTrial ? '1' : '0';
}
elsif ($::g_sAction eq "shopid")
{
if ($::g_bActinicHostMode)
{
$::g_OutputData = $::g_sShopID;
}
}
elsif ($::g_sAction eq "baseurl")
{
if ($::g_bActinicHostMode)
{
$::g_OutputData = $::g_sBaseURL;
}
}
elsif ($::g_sAction eq "getservertime")
{
my ($now);
$now = time;
$::g_OutputData = $now;
}
else
{
$::g_sInternalErrors .= "script exception, ";
$::g_nErrorNumber = 999;
$::g_Answer = $::g_sFilename;
}
RecordErrors();
SendResponse();
exit;
sub ReadAndParseHTTP
{
binmode STDIN;
my ($nStep, $InputBuffer, $InputData);
$nStep = 0;
while ((length $InputData) != $ENV{'CONTENT_LENGTH'})
{
$nStep = read(STDIN, $InputBuffer, $ENV{'CONTENT_LENGTH'});  # Set $InputData equal to user input
$InputData .= $InputBuffer;
if (0 == $nStep)
{
last;
}
}
if ((length $InputData) != $ENV{'CONTENT_LENGTH'})
{
$::g_sInternalErrors .= "Some of the HTTP data is missing $::g_nLength != " . $ENV{'CONTENT_LENGTH'} . ", ";
$::g_nErrorNumber = 455;
}
my ($sUser, $sPassword, $nFilenameLength, $Data, $nMajorVersion, $sDayno);
if ($InputData !~ /^(\w+) (\w+) ([.0-9]+) (\w+) (\w+) (\d+) (.*)/s)
{
$::g_sInternalErrors .= "Catalog data format invalid, ";
$::g_nErrorNumber = 455;
return;
}
($sUser, $sPassword, $nMajorVersion, $sDayno, $::g_sAction, $nFilenameLength, $Data) = ($1, $2, $3, $4, $5, $6, $7);
$::g_sVersionDayno = "$nMajorVersion $sDayno";
$::g_sFilename = substr($Data, 0, $nFilenameLength);
SecurePath($::g_sFilename, 460);
$::g_UserData = substr($Data, $nFilenameLength + 1);
my (@sFields) = split(/\./, $::g_sFilename);	 # Extract the file name and extension from $::g_sFilename
$::g_sFilenameExtension = pop @sFields;
$::g_sFilenameBase = join('.',@sFields);
$::g_sFilenameExtension =~ s/ //g;
if ($::g_sFilenameBase =~ /\.\./ ||
$::g_sFilenameBase =~ /:/ 	 ||
$::g_sFilenameBase =~ /\// 	 ||
$::g_sFilenameBase =~ /\\/ 	 )
{
$::g_sInternalErrors .= "Attempt to access file outside of web space, ";
$::g_nErrorNumber = 455;
}
if ($::g_sFilenameExtension =~ /\.\./ ||
$::g_sFilenameExtension =~ /:/ 	 ||
$::g_sFilenameExtension =~ /\// 	 ||
$::g_sFilenameExtension =~ /\\/ 	 )
{
$::g_sInternalErrors .= "Attempt to access file outside of web space, ";
$::g_nErrorNumber = 455;
}
if ( (length $sUser) > 12)
{
$::g_sInternalErrors .= "Parameters too large, user too long (" . (length $sUser) . "), ";
$::g_nErrorNumber = 455;
}
if ( (length $sPassword) > 12)
{
$::g_sInternalErrors .= "Parameters too large, password too long (" . (length $sPassword) . "), ";
$::g_nErrorNumber = 455;
}
if ($nFilenameLength > 10240)
{
$::g_sInternalErrors .= "Parameters too large, filename too long (" . (length $nFilenameLength) . "), ";
$::g_nErrorNumber = 455;
}
if ((length $::g_UserData) < 1 &&
$::g_sAction eq "create")
{
$::g_UserData = "NO DATA SENT";
$::g_sInternalErrors .= "No message sent $::g_nLength, ";
$::g_nErrorNumber = 458;
}
if(!$::g_bActinicHostMode &&
$::g_bUseAlternatePath &&
($::g_sFilenameExtension eq "ord" ||
$::g_sFilenameExtension eq "occ" ||
$::g_sFilenameExtension eq "session"))
{
$::g_sPath = $::g_sAlternatePath;
}
AuthenticateUser($sUser, $sPassword);
}
sub CreateFile
{
if ($::g_sFilenameBase eq "")
{
$::g_sInternalErrors .= "no filename given for CREATE, ";
$::g_nErrorNumber = 457;
$::g_Answer = $::g_sFilename;
return;
}
if (-e $::g_sFilename)
{
chmod(0666, $::g_sFilename);
unlink($::g_sFilename);
}
my $uSum = substr($::g_UserData, 0, 12);
my $sFileContents = substr($::g_UserData, 12);
my $uTotal;
{
use integer;
$uTotal = unpack('%32C*', $sFileContents);
}
if ($uTotal != $uSum)
{
$::g_sInternalErrors .= "corrupt file transfer: local($uTotal) != remote($uSum) " . substr($sFileContents, 0, 10) . "| " . length ($sFileContents) . ", ";
$::g_nErrorNumber = 554;
return;
}
if (!$::g_bActinicHostMode)
{
if (open(NQFILE, ">" . $::g_sFilename))
{
binmode NQFILE;
unless(print NQFILE ($sFileContents))
{
$::g_sInternalErrors .= "out of disk space, ";
$::g_nErrorNumber = 553;
}
$::g_Answer = $::g_sFilename;
close (NQFILE);
}
else
{
$::g_sInternalErrors .= "unable to create $::g_sFilename $!, ";
$::g_nErrorNumber = 540;
$::g_Answer = $::g_sFilename;
}
chmod(0644, $::g_sFilename);
}
else
{
eval
{
require AHDClient;
};
if ($@)
{
$::g_sInternalErrors .= "unable to load the daemon client library ($@)";
$::g_nErrorNumber = 560;
return;
}
my ($nStatus, $sError, $pClient) = new AHDClient($::g_sDaemonAddress, $::g_nDaemonPort, '../gk/acatalog/');
if ($nStatus != $::SUCCESS)
{
$::g_sInternalErrors .= "Unable to connect to the Host Daemon. $sError\n";
$::g_nErrorNumber = 561;
return;
}
($nStatus, $sError) = $pClient->SetUsernameAndPassword($::g_sUsername, $::g_sPassword);
if ($nStatus != $::SUCCESS)
{
$::g_sInternalErrors .= "Unable to log in to the Host Daemon. $sError\n";
if ($sError == 201)
{
$::g_nErrorNumber = 562;
}
elsif ($sError == 290)
{
$::g_nErrorNumber = 564;
}
else
{
$::g_nErrorNumber = 565;
}
return;
}
my $sName = $::g_sFilenameBase.".".$::g_sFilenameExtension;
unlink($::g_sFilename);
if (-e $::g_sFilename)
{
($nStatus, $sError) = $pClient->DeleteFile($sName);
if ($nStatus != $::SUCCESS)
{
$::g_sInternalErrors .= "Unable to delete file. $sError\n";
if ($sError == 815)
{
$::g_nErrorNumber = 563;
}
elsif ($sError == 817)
{
$::g_nErrorNumber = 566;
}
elsif ($sError == 860)
{
$::g_nErrorNumber = 567;
}
elsif ($sError == 861)
{
$::g_nErrorNumber = 568;
}
else
{
$::g_nErrorNumber = 569;
}
return;
}
}
($nStatus, $sError) = $pClient->CreateFile($sName, $sFileContents);
if ($nStatus != $::SUCCESS)
{
$::g_sInternalErrors .= "Unable to create file. $sError\n";
if ($sError == 815)
{
$::g_nErrorNumber = 563;
}
elsif ($sError == 817)
{
$::g_nErrorNumber = 571;
}
elsif ($sError == 820)
{
$::g_nErrorNumber = 572;
}
elsif ($sError == 811)
{
$::g_nErrorNumber = 573;
}
else
{
$::g_nErrorNumber = 570;
}
return;
}
$pClient->RecordClientVersions({UploadVersion=>'NETQUOTEVAR:ACTINICSCRIPTRELEASE'});
}
}
sub LookUpAndRetrieve
{
my ($nFoundCount, $sOldErrors);
$nFoundCount = 0;
$sOldErrors = $::g_sInternalErrors;
my @listFile = ReadTheDir($::g_sPath);
if ($::g_sInternalErrors eq $sOldErrors)
{
my ($sFile, $sBase, $sExtension);
@listFile = sort (@listFile);
foreach $sFile (@listFile)
{
if ($sFile =~ /\.([^\.]+)$/)
{
$sBase = $`;
$sExtension = $1;
}
else
{
next;
}
if ($sExtension eq $::g_sFilenameExtension )
{
if ($sBase =~ /^$::g_sFilenameBase/)
{
$::g_Answer = $::g_sPath.$sFile;
$nFoundCount++;
}
}
}
if ($::g_Answer eq "")
{
$::g_nErrorNumber = 454;
$::g_Answer = $::g_sFilename;
$::g_OutputData = "0";
}
else
{
if ($::g_sAction eq "lookrt")
{
if($::g_sFilenameExtension eq "ord" ||
$::g_sFilenameExtension eq "inf")
{
chmod(0666, $::g_Answer);
}
if (open(NQFILE, "<$::g_Answer"))
{
my ($Buffer);
binmode NQFILE;
while ( read (NQFILE, $Buffer, 16384) )
{
$::g_OutputData .= $Buffer;
}
close (NQFILE);
{
use integer;
$::g_OutputData = sprintf('%12d', unpack('%32C*', $::g_OutputData)) . $::g_OutputData;
}
}
else
{
$::g_sInternalErrors .= "unable to read $::g_Answer $!, ";
$::g_nErrorNumber = 540;
$::g_Answer = $::g_sFilename;
}
if($::g_sFilenameExtension eq "ord" ||
$::g_sFilenameExtension eq "inf")
{
chmod(0200, $::g_Answer);
}
}
else
{
$::g_OutputData = $nFoundCount . ' ';
}
}
}
else
{
$::g_sInternalErrors .= "unable to read directory, ";
$::g_nErrorNumber = 541;
$::g_Answer = $::g_sFilename;
$::g_OutputData = "0";
}
my ($nState, $sFile, $nLength);
$nState = substr($::g_nErrorNumber, 0,3);
if ($nState == 200)
{
$sFile = $::g_Answer;
$sFile =~ s/[ \t\r\n]//;
$nLength = length $sFile;
if ($nLength == 0)
{
$::g_nErrorNumber = 454;
$::g_Answer = "none";
$::g_OutputData = "0";
}
}
}
sub DeleteFile
{
if ($::g_sFilenameBase eq "")
{
$::g_sInternalErrors .= "filename for delete is NULL, ";
$::g_nErrorNumber = 250;
return;
}
unless (-e $::g_sFilename)
{
$::g_nErrorNumber = 254;
$::g_Answer = $::g_sFilename;
return;
}
chmod(0666, $::g_sFilename);
if (! $::g_bActinicHostMode )
{
unless (-w $::g_sFilename)
{
$::g_nErrorNumber = 252;
$::g_sInternalErrors .= "tried to delete read-only file $::g_sFilename, ";
}
else
{
unlink ($::g_sFilename);
}
}
else
{
if (0 == unlink ($::g_sFilename))
{
eval
{
require AHDClient;
};
if ($@)
{
$::g_sInternalErrors .= "unable to load the daemon client library ($@)";
$::g_nErrorNumber = 560;
return;
}
my ($nStatus, $sError, $pClient) = new AHDClient($::g_sDaemonAddress, $::g_nDaemonPort, '../gk/acatalog/');
if ($nStatus != $::SUCCESS)
{
$::g_sInternalErrors .= "Unable to connect to the Host Daemon. $sError\n";
$::g_nErrorNumber = 561;
return;
}
($nStatus, $sError) = $pClient->SetUsernameAndPassword($::g_sUsername, $::g_sPassword);
if ($nStatus != $::SUCCESS)
{
$::g_sInternalErrors .= "Unable to log in to the Host Daemon. $sError\n";
if ($sError == 201)
{
$::g_nErrorNumber = 562;
}
elsif ($sError == 290)
{
$::g_nErrorNumber = 564;
}
else
{
$::g_nErrorNumber = 565;
}
$::g_nErrorNumber = 561;
return;
}
my $sName = $::g_sFilenameBase.".".$::g_sFilenameExtension;
($nStatus, $sError) = $pClient->DeleteFile($sName);
if ($nStatus != $::SUCCESS)
{
$::g_sInternalErrors .= "Unable to delete file. $sError\n";
if ($sError == 815)
{
$::g_nErrorNumber = 563;
}
elsif ($sError == 817)
{
$::g_nErrorNumber = 566;
}
elsif ($sError == 860)
{
$::g_nErrorNumber = 567;
}
elsif ($sError == 861)
{
$::g_nErrorNumber = 568;
}
else
{
$::g_nErrorNumber = 569;
}
return;
}
}
}
$::g_Answer = $::g_sFilename;
}
sub RenameFile
{
my $sNewFileName = $::g_UserData;
if ($sNewFileName =~ /\.\./ ||
$sNewFileName =~ /:/ 	 ||
$sNewFileName =~ /\// 	 ||
$sNewFileName =~ /\\/ 	 )
{
$::g_sInternalErrors .= "Attempt to access file outside of web space, ";
$::g_nErrorNumber = 455;
return;
}
$sNewFileName = $::g_sPath . $sNewFileName;
unless (-e $::g_sFilename)
{
$::g_sInternalErrors .= "File $::g_sFilename doesn't exist, ";
$::g_nErrorNumber = 254;
$::g_Answer = $::g_sFilename;
return;
}
my $mode = (stat($::g_sFilename))[2];
chmod(0666, $::g_sFilename);
if (rename ($::g_sFilename, $sNewFileName))
{
$::g_Answer = $sNewFileName;
}
else
{
$::g_Answer = $::g_sFilename;
$::g_sInternalErrors .= "Couldn't rename $::g_sFilename, ";
$::g_nErrorNumber = 252;
}
chmod($mode, $::g_sFilename);
}
sub GetFileDate
{
$::g_Answer = '';
$::g_UserData =~ s/'//g;                     # ' <emacs formatting> # strip any single quotes - they are passed from Cat because it is convenient formatting
my @listFiles = split(/,/, $::g_UserData);
my $sFile;
foreach $sFile (@listFiles)
{
my $sFilePath = $::g_sPath . $sFile;
if (!-e $sFilePath)
{
$::g_OutputData .= ",-";
}
else
{
my @stat = stat $sFilePath;
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst, $sDate);
($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($stat[9]);
$mon++;
$year += 1900;
$sDate = sprintf("%4.4d/%2.2d/%2.2d %2.2d:%2.2d:%2.2d %1.1d", $year, $mon, $mday, $hour, $min, $sec, $isdst);
$::g_OutputData .= "," . $sDate;
}
}
$::g_OutputData =~ s/^,//;
}
sub GetFileList
{
$::g_Answer = '';
$::g_sFilenameExtension =~ s/\./\\\./g;
my @listFiles = ReadTheDir($::g_sPath);
my $sFile;
foreach $sFile (@listFiles)
{
if ($sFile =~ /\.([^\.]+)$/)
{
if ($1 eq $::g_sFilenameExtension )
{
$::g_OutputData .= ',' . $sFile;
}
}
}
$::g_OutputData =~ s/^,//;
}
sub ReadTheDir
{
my $RTDInternalErrors = $::g_sInternalErrors;
$::g_sInternalErrors = "";
my $RDpath = $_[0];
if( opendir (NQDIR, "$RDpath") )
{
my @arglist = readdir (NQDIR);
closedir (NQDIR);
RecordErrors();
$::g_sInternalErrors = $RTDInternalErrors;
return (@arglist);
}
$::g_sInternalErrors .= "unable to read directory - 2nd open failed, ";
RecordErrors();
$::g_sInternalErrors = $RTDInternalErrors;
return (undef);
}
sub RecordErrors
{
if ( (length $::g_sInternalErrors) > 0 &&
$::g_bPathKnown)
{
open(NQFILE, ">>".$::g_sErrorFilename);
print NQFILE ("Program = ");
print NQFILE (substr($::prog_name.$::PAD_SPACE,0,8));
print NQFILE (", Program version = ");
print NQFILE (substr($::prog_ver.$::PAD_SPACE,0,6));
print NQFILE (", HTTP Server = ");
print NQFILE (substr($ENV{'SERVER_SOFTWARE'}.$::PAD_SPACE,0,30));
print NQFILE (", Return code = ");
print NQFILE (substr($::g_nErrorNumber.$::PAD_SPACE,0,20));
print NQFILE (", Date and Time = ");
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst)
= localtime(time);
$mon++;
$year += 1900;
my $sFormat = sprintf("%2.2d/%2.2d/%4.4d %2.2d:%2.2d:%2.2d", $mday, $mon, $year, $hour, $min, $sec);
print NQFILE ($sFormat);
$wday = $wday;
$yday = $yday;
$isdst = $isdst;
print NQFILE (", Internal Errors = ");
print NQFILE ($::g_sInternalErrors);
print NQFILE "\n";
close NQFILE;
chmod(0666, $::g_sErrorFilename);
}
}
sub SendResponse
{
if ($::g_Answer eq "")
{
$::g_Answer = substr($::PAD_SPACE,0,16);
}
else
{
$::g_Answer = substr($::g_Answer, length ($::g_sPath)); # Remove the path from $::g_Answer
}
my $SRAnswerLength = length $::g_Answer;
if ($SRAnswerLength < 10)
{
$SRAnswerLength = "0".$SRAnswerLength;
}
elsif ($SRAnswerLength > 99 ||
$SRAnswerLength < 1)
{
$::g_sInternalErrors .= "Answer is too small or too large, ";
RecordErrors();
}
my $SResponse = $::g_nErrorNumber.$SRAnswerLength.$::g_Answer.$::g_OutputData;
binmode STDOUT;
PrintHeader('application/octet-stream', (length $SResponse), undef, $::FALSE);
print $SResponse;
}
sub PrintHeader
{
my ($sType, $nLength, $sCookie, $bNoCache) = @_;
my (@expires, $day, $month, $now, $later, $expiry, @now, $sNow);
my (@days) = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
my (@months) = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
$now = time;
@now = gmtime($now);
$day = $days[$now[6]];
$month = $months[$now[4]];
$sNow = sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT", $day, $now[3],
$month, $now[5]+1900, $now[2], $now[1], $now[0]);
$later = $now + 2 * 365 * 24 * 3600;
@expires = gmtime($later);
$day = $days[$expires[6]];
$month = $months[$expires[4]];
$expiry = sprintf("%s, %02d-%s-%04d %02d:%02d:%02d GMT", $day, $expires[3],
$month, $expires[5]+1900, $expires[2], $expires[1], $expires[0]);
my $bCookie = ( (length $sCookie) > 0);
if($ENV{'PerlXS'} eq 'PerlIS')
{
print "HTTP/1.0 200 OK\n";
}
if ($bCookie)
{
print "Set-Cookie: ACTINIC_CART=" .
$sCookie . "; EXPIRES=" .
$expiry . "; PATH=/;\r\n";
print "Date: $sNow\r\n";
}
if ($bNoCache)
{
print "Pragma: no-cache\r\n";
}
print "Content-type: $sType\r\n";
print "Content-length: $nLength\r\n\r\n";
}
sub DebugOut
{
open (DBOUT, ">>output.txt");
print DBOUT $_[0] . "\n";
close DBOUT;
}
sub SecurePath
{
my ($sPath, $nCode) = @_;
if ($^O =~ /win/i)
{
if ($sPath =~ m|[!&<>\|*?()^;\${}\[\]\`\'\"\n\r]| ||
$sPath =~ m|\0|)
{
$::g_nErrorNumber = $nCode;
$::g_OutputData = $sPath;
SendResponse();
exit;
}
}
else
{
if ($sPath =~ m|[!&<>\|*?()^;\${}\[\]\`\'\"\\~\n\r]| ||
$sPath =~ m|\0|)
{
$::g_nErrorNumber = $nCode;
$::g_OutputData = $sPath;
SendResponse();
exit;
}
}
}
sub AuthenticateUser
{
my ($sUsername, $sPassword) = @_;
my ($sCorrectUsername, $sCorrectPassword) = ('5d028f034438438c34845a195b621564', 'b276f5a7c8b02db732ba111ee2623cf2');
if (!$sUsername ||
!$sPassword)
{
$::g_sInternalErrors .= "Invalid username/password attempt ($sUsername, $sPassword), ";
$::g_nErrorNumber = 453;
sleep $::DOS_SLEEP_DURATION;
RecordErrors();
SendResponse();
exit;
}
eval
{
require Digest::MD5;
import Digest::MD5 'md5_hex';
};
if ($@)
{
require di000001;
import Digest::Perl::MD5 'md5_hex';
}
if (!$::g_bActinicHostMode)
{
if (md5_hex($sUsername) ne $sCorrectUsername ||
md5_hex($sPassword) ne $sCorrectPassword)
{
$::g_sInternalErrors .= "Invalid username/password attempt ($sUsername, $sPassword), ";
$::g_nErrorNumber = 453;
sleep $::DOS_SLEEP_DURATION;
RecordErrors();
SendResponse();
exit;
}
}
else
{
eval 'require AHDClient;';
if ($@)
{
$::g_sInternalErrors .= 'An error occurred loading the AHDClient module.  ' . $@;
$::g_nErrorNumber = 560;
sleep $::DOS_SLEEP_DURATION;
SendResponse();
exit;
}
my ($nStatus, $sError, $pClient);
($nStatus, $sError, $pClient) = new_readonly AHDClient('../gk/acatalog/');
if ($nStatus!= $::SUCCESS)
{
$::g_sInternalErrors .= 'An error occured accessing the shop data.' . $sError;
$::g_nErrorNumber = 450;
sleep $::DOS_SLEEP_DURATION;
SendResponse();
exit;
}
($nStatus, $sError, my $pShop)= $pClient->GetShopDetailsFromUsernameAndPassword($sUsername, $sPassword);
if ($nStatus != $::SUCCESS)
{
$::g_sInternalErrors .= "Error accessing the configuration file, $sError.  ";
$::g_nErrorNumber = 450;
sleep $::DOS_SLEEP_DURATION;
SendResponse();
exit;
}
elsif (!defined($pShop))
{
$::g_sInternalErrors .= "Invalid username/password attempt.  $sError.  ";
$::g_nErrorNumber = 562;
sleep $::DOS_SLEEP_DURATION;
SendResponse();
exit;
}
if ($::g_sAction eq 'lookup')
{
if ($pShop->{DownloadVersion} ne 'NETQUOTEVAR:ACTINICSCRIPTRELEASE')
{
($nStatus, $sError, my $pWriteClient) = new AHDClient($::g_sDaemonAddress, $::g_nDaemonPort, '../gk/acatalog/');
if ($nStatus == $::SUCCESS)
{
$pWriteClient->SetUsernameAndPassword($sUsername, $sPassword);
$pWriteClient->RecordClientVersions({DownloadVersion=>'NETQUOTEVAR:ACTINICSCRIPTRELEASE'});
}
}
}
$::g_sPath = $pShop->{Path};
$::g_sShopID = $pShop->{ShopID};
$::g_bTrial  = $pShop->{TrialAccount};
$::g_sBaseURL  = $pShop->{BaseURL};
$::g_sUsername = $sUsername;
$::g_sPassword = $sPassword;
$::g_sPath =~ m|(.*?)([^/]+)$|;
my ($sDirPath, $sFile) = ($1, $2);
$sDirPath =~ s|/$||;
opendir (DIR, $sDirPath ? $sDirPath : './');
my @ShopFiles = grep { /^$sFile/ } readdir(DIR);
closedir(DIR);
if (! -e $::g_sPath &&
scalar @ShopFiles == 0)
{
$::g_sInternalErrors .= "path does not exist :$::g_sPath:, ";
$::g_nErrorNumber = 542;
$::g_bPathKnown = 0;
}
elsif (! -r $::g_sPath &&
(scalar @ShopFiles == 0 ||
(scalar @ShopFiles > 0 &&
! -r $sDirPath . '/' . $ShopFiles[0])))
{
$::g_sInternalErrors .= "path is not readable :$::g_sPath:, ";
$::g_nErrorNumber = 543;
$::g_bPathKnown = 0;
}
else
{
$::g_bPathKnown = 1;
}
}
}
sub GetPublicKey
{
my $sFilename = $::g_sPath . "nqset00.fil" ;
unless (open (SCRIPTFILE, "<$sFilename"))
{
$::g_OutputData = "";
return;
}
my $nCheckSum = <SCRIPTFILE>;
chomp $nCheckSum;
$nCheckSum =~ s/;$//;
my $sScript;
{
local $/;
$sScript = <SCRIPTFILE>;
}
close (SCRIPTFILE);
my $uTotal;
{
use integer;
$uTotal = unpack('%32C*', $sScript);
}
if ($nCheckSum != $uTotal)
{
$::g_OutputData = "";
return;
}
$sScript =~ s/\r//g;
if (!eval($sScript))
{
$::g_OutputData = "";
return;
}
my ($nCount, $sKey);
my $sKeyLength = $$::g_pSetupBlob{'KEY_LENGTH'};
my ($pKey) = $$::g_pSetupBlob{'PUBLIC_KEY_' . $sKeyLength . 'BIT'};
for ($nCount = ($sKeyLength / 8) - 1; $nCount >= 0; $nCount--)
{
$sKey .= sprintf('%2.2x', $$pKey[$nCount]);
}	
$::g_OutputData = $sKey;
}
sub GetOrderNum
{
eval ('require File::Copy;');
if ($@) 
{
$::g_sInternalErrors .= "Unable to load File::Copy module -  $@, ";
$::g_nErrorNumber = 999;				
return;
}
my $sUnLockFile = $::g_sPath . 'Order.num';
my $sBackupFile = $::g_sPath . 'Backup.num';
my $sQueryFile  = $::g_sPath . 'Query.num';
my $sLockFile   = $::g_sPath . 'OrderLock.num';
if (!-e $sUnLockFile &&
!-e $sLockFile &&
!-e $sBackupFile)
{
$::g_OutputData = -1;
return;
}
if (!-e $sUnLockFile &&
!-e $sLockFile &&
-e $sBackupFile)		
{
if (!File::Copy::copy($sBackupFile, $sUnLockFile))
{
$::g_sInternalErrors .= "Unable to copy of the backup file to unlock file -  $!, ";
$::g_nErrorNumber = 584;				
return;		
}			
}			
my $bGotCopy = $::FALSE;
my $nRetries = 20;
while ($nRetries > 0)
{	
if (File::Copy::copy($sUnLockFile, $sQueryFile))
{
$bGotCopy = $::TRUE;
last;			
}
$nRetries--;
sleep 2;
}
if (!$bGotCopy)
{
if (!-e $sBackupFile)
{
$::g_sInternalErrors .= "Backup file doesn't exist -  $!, ";
$::g_nErrorNumber = 584;				
return;			
}
if (!File::Copy::copy($sBackupFile, $sQueryFile))
{
$::g_sInternalErrors .= "Unable to get a copy of the backup file -  $!, ";
$::g_nErrorNumber = 584;				
return;		
}			
}
my $nByteLength = 4;
unless (open (LOCK, "<$sQueryFile"))
{
$::g_sInternalErrors .= "Unable to open the copy of the lock file -  $!, ";
$::g_nErrorNumber = 584;				
return;		
}
binmode LOCK;
my $nCounterBin;
unless ($nByteLength == read (LOCK, $nCounterBin, $nByteLength))
{
my $sError = $!;
close (LOCK);
unless (open (LOCK, "<$sBackupFile"))
{
$::g_sInternalErrors .= "Unable to open the backup file -  $!, ";
$::g_nErrorNumber = 584;				
return;			
}
binmode LOCK;
unless ($nByteLength == read (LOCK, $nCounterBin, $nByteLength))
{
$::g_sInternalErrors .= "Both lock and backup files are dead -  $sError -- $!, ";
$::g_nErrorNumber = 584;				
return;
}
}
close (LOCK);
chmod(0666, $sQueryFile);
unlink($sQueryFile);
$::g_OutputData = unpack("N", $nCounterBin);	
}
sub SetOrderNum
{
eval ('require File::Copy;');
if ($@) 
{
$::g_sInternalErrors .= "Unable to load File::Copy module -  $@, ";
$::g_nErrorNumber = 999;				
return;
}
my $sUnLockFile = $::g_sPath . 'Order.num';
my $sBackupFile = $::g_sPath . 'Backup.num';
my $sLockFile   = $::g_sPath . 'OrderLock.num';
if (!-e $sUnLockFile &&
!-e $sLockFile &&
!-e $sBackupFile)
{
unless (open (LOCK, ">$sUnLockFile"))
{
$::g_sInternalErrors .= "Unable to create the lock file -  $!, ";
$::g_nErrorNumber = 584;				
return;	
}
binmode LOCK;
my $nCounter = pack("N", $::g_UserData);
unless (print LOCK $nCounter)
{
$::g_sInternalErrors .= "Unable to write to the lock file -  $!, ";
$::g_nErrorNumber = 584;				
return;
}
if (!File::Copy::copy($sUnLockFile, $sBackupFile))
{
$::g_sInternalErrors .= "Unable to get a copy to the backup file -  $!, ";
$::g_nErrorNumber = 584;				
return;		
}					
close (LOCK);
sleep 2;			
return;
}
if (!-e $sUnLockFile &&
!-e $sLockFile &&
-e $sBackupFile)		
{
if (!File::Copy::copy($sBackupFile, $sUnLockFile))
{
$::g_sInternalErrors .= "Unable to copy of the backup file to unlock file -  $!, ";
$::g_nErrorNumber = 584;				
return;		
}			
}		
my $nDate;
my $bFileIsLocked = $::FALSE;
my $sRenameError;
my $nNumberBreakRetries = 1;
my $nByteLength = 4;
RETRY:
$bFileIsLocked = $::FALSE;
if ($nNumberBreakRetries < 0)
{
$::g_sInternalErrors .= "0 - Couldn't lock the file -  $sRenameError, ";
$::g_nErrorNumber = 585;				
return;
}
my $nRetries = 20;
while ($nRetries > 0)
{
if (rename($sUnLockFile, $sLockFile))
{
$bFileIsLocked = $::TRUE;
last;
}
$sRenameError = $!;
if (!defined $nDate)
{
my @tmp = stat $sLockFile;
$nDate = $tmp[9];
}
$nRetries--;
sleep 2;
}
if (!$bFileIsLocked)
{
if (-e $sLockFile)
{
my @tmp = stat $sLockFile;
if (!defined $nDate)
{
$::g_sInternalErrors .= "1 - Couldn't lock the file -  $sRenameError, ";
$::g_nErrorNumber = 585;				
return;
}
if (!defined $tmp[9])
{
$nNumberBreakRetries--;
sleep 2;
goto RETRY;
}
if ($nDate == $tmp[9])
{
if (!rename($sLockFile, $sUnLockFile))
{
$::g_sInternalErrors .= "Couldn't rename lock file -  $!, ";
$::g_nErrorNumber = 585;				
return;
}
}
$nNumberBreakRetries--;
sleep 2;
goto RETRY;
}
else
{
$nNumberBreakRetries--;
sleep 2;
goto RETRY;
}
}
unless (open (LOCK, "<$sLockFile"))
{
$::g_sInternalErrors .= "Couldn't open the lock file -  $!, ";
$::g_nErrorNumber = 585;				
return;
}
binmode LOCK;
my $nCounterBin;
unless ($nByteLength == read (LOCK, $nCounterBin, $nByteLength))
{
close (LOCK);
unless (open (LOCK, "<$sBackupFile"))
{
$::g_sInternalErrors .= "Couldn't open the backup file -  $!, ";
$::g_nErrorNumber = 585;				
return;
}
binmode LOCK;
unless ($nByteLength == read (LOCK, $nCounterBin, $nByteLength))
{
close (LOCK);
$::g_sInternalErrors .= "The backup file doesn't contain valid counter -  $!, ";
$::g_nErrorNumber = 585;				
return;
}
}
close (LOCK);
$nCounterBin = pack ("N", $::g_UserData);
unless (open (LOCK, ">$sLockFile"))
{
$::g_sInternalErrors .= "Couldn't open the lock file -  $!, ";
$::g_nErrorNumber = 585;				
return;
}
binmode LOCK;
unless (print LOCK $nCounterBin)
{
close (LOCK);
$::g_sInternalErrors .= "Couldn't write to the lock file -  $!, ";
$::g_nErrorNumber = 585;				
return;
}
close (LOCK);
unless (open (LOCK, ">$sBackupFile"))
{
$::g_sInternalErrors .= "Couldn't open the backup file -  $!, ";
$::g_nErrorNumber = 585;				
return;
}
binmode LOCK;
unless (print LOCK $nCounterBin)
{
close (LOCK);
$::g_sInternalErrors .= "Couldn't write to the backup file -  $!, ";
$::g_nErrorNumber = 585;				
return;
}
close (LOCK);
if (!rename ($sLockFile, $sUnLockFile))
{
$::g_sInternalErrors .= "Couldn't unlock the file -  $!, ";
$::g_nErrorNumber = 585;				
return;
}
}	