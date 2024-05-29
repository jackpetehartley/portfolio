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
umask (0177);
use strict;
use Socket;
$::prog_name = "EXPLORER";
$::prog_ver = '$Revision: 18819 $';
$::prog_ver = substr($::prog_ver, 11);
$::prog_ver =~ s/ \$//;
$::FALSE 	= 0;
$::TRUE	 	= 1;
$::FAILURE 	= 0;
$::SUCCESS 	= 1;
$ACTINIC::FORM_URL_ENCODED 			= 0;
$ACTINIC::MODIFIED_FORM_URL_ENCODED	= 1;
$ACTINIC::HTML_ENCODED					= 2;
$::g_sEmailAddress = 'gk-printing@hotmail.co.uk';
$::g_sServerAddress = 'localhost';
$::g_sPathToAcatalog = '../gk/acatalog/';
$::g_pPrompts =
{
'IDS_SE_COULDNT_READ_DIRECTORY' => "Couldn't read the directory list for ",
'IDS_SE_INFO_FILE_PERMISSIONS' => "File Permissions",
'IDS_SE_INFO_FILE_PERMISSIONS_ACATALOG' => "Files in Online Store Folder",
'IDS_SE_INFO_FILE_PERMISSIONS_ACATALOG_ROOT' => "Files in root of Online Store Folder",
'IDS_SE_INFO_FILE_PERMISSIONS_CGI' => "Files in /cgi-bin",
'IDS_SE_INFO_FILE_PERMISSIONS_CGI_ROOT' => "Files in /cgi-bin/../",
'IDS_SE_INFO_SCRIPT_PERMISSIONS_ACATALOG' => "Check script permissions in Online Store Folder.",
'IDS_SE_CREATE_FILE' => 'Create file in Online Store Folder...',
'IDS_SE_SUCCESS' => 'Success',
'IDS_SE_FAILURE' => 'Failure',
'IDS_SE_CHMOD_FILE' => 'Chmod file...',
'IDS_SE_RENAME_FILE' => 'Rename file...',
'IDS_SE_REMOVE_FILE' => 'Remove file...',
'IDS_SE_AUTH_FAILURE' => 'Invalid username/password attempt',
'IDS_SE_INFO_PERL' => 'Perl Environment',
'IDS_SE_INFO_PERL_VERSION' => 'Perl Version',
'IDS_SE_INFO_NOT_INSTALLED' => 'Not installed',
'IDS_SE_INFO_INSTALLED' => 'Installed',
'IDS_SE_INFO_REAL_USER' => 'Real CGI User',
'IDS_SE_INFO_REAL_GROUP' => 'Real CGI Group',
'IDS_SE_INFO_EFF_USER' => 'Effective CGI User',
'IDS_SE_INFO_EFF_GROUP' => 'Effective CGI Group',
'IDS_SE_INFO_SCRIPTNAME' => 'Script name',
'IDS_SE_INFO_FTP_USER' => 'FTP User',
'IDS_SE_INFO_FTP_GROUP' => 'FTP Group',
'IDS_SE_INFO_ENV' => 'Server Environment',
'IDS_SE_INFO_SMTP' => 'SMTP Communication',
};
Init();
ProcessInput();
exit;
sub Init
{
my ($status, $message, $temp);
($status, $message, $::g_OriginalInputData, $temp, %::g_InputHash) = ReadAndParseInput();
if ($status != $::SUCCESS)
{
PrintPage($message);
exit;
}
AuthenticateUser($::g_InputHash{USER}, $::g_InputHash{PASS});
}
sub ProcessInput
{
my $sHTML;
$sHTML .= GetPerlEnv();
$sHTML .= GetFormatedEnv();
$sHTML .= GetAcatalogPermissions();
$sHTML .= GetPermissions();
$sHTML .= CheckSendMail();
PrintPage($sHTML);
}
sub AuthenticateUser
{
my ($sUsername, $sPassword) = @_;
my ($sCorrectUsername, $sCorrectPassword) = ('5d028f034438438c34845a195b621564', 'b276f5a7c8b02db732ba111ee2623cf2');
my ($sSupportUsername, $sSupportPassword) = ('2b90dd375486e278f32319aeed5524ce', '86521a90867b3a095f26c4250f086b95');
my $sReturn;
if (!$sUsername ||
!$sPassword)
{
$sReturn = $$::g_pPrompts{'IDS_SE_AUTH_FAILURE'} . " ($sUsername, $sPassword), ";
PrintPage($sReturn);
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
if (md5_hex($sUsername) ne $sCorrectUsername ||
md5_hex($sPassword) ne $sCorrectPassword)
{
if (md5_hex($sUsername) ne $sSupportUsername ||
md5_hex($sPassword) ne $sSupportPassword)
{
$sReturn = $$::g_pPrompts{'IDS_SE_AUTH_FAILURE'} . " ($sUsername, $sPassword), ";
PrintPage($sReturn);
exit;
}
}
}
sub GetAcatalogPermissions
{
my $sTestFileName = $::g_sPathToAcatalog . "ActinicTestFile.html";
my $sRenamedTestFile = $::g_sPathToAcatalog . "ActinicTestFileRenamed.html";
my $sHTML = "<H1>" . $$::g_pPrompts{'IDS_SE_INFO_SCRIPT_PERMISSIONS_ACATALOG'} . "</H1>";
$sHTML .= FormatSent($$::g_pPrompts{'IDS_SE_CREATE_FILE'});
unless (open(TESTFILE, ">>$sTestFileName"))
{
$sHTML .= FormatReceived($$::g_pPrompts{'IDS_SE_FAILURE'} . " - " . $!);
return $sHTML ;
}
unless (print TESTFILE "Test")
{
$sHTML .= FormatReceived($$::g_pPrompts{'IDS_SE_FAILURE'} . " - " . $!);
return $sHTML ;
}
close TESTFILE;
$sHTML .= FormatReceived($$::g_pPrompts{'IDS_SE_SUCCESS'});
$sHTML .= FormatSent($$::g_pPrompts{'IDS_SE_CHMOD_FILE'});
$sHTML .= TestReturnValue(chmod(0777, $sTestFileName));
$sHTML .= FormatSent($$::g_pPrompts{'IDS_SE_RENAME_FILE'});
$sHTML .= TestReturnValue(rename $sTestFileName, $sRenamedTestFile);
$sHTML .= FormatSent($$::g_pPrompts{'IDS_SE_REMOVE_FILE'});
$sHTML .= TestReturnValue(unlink $sRenamedTestFile);
return $sHTML;
}
sub TestReturnValue
{
my $bValue = shift;
my $sReturn = $bValue ? $$::g_pPrompts{'IDS_SE_SUCCESS'} : $$::g_pPrompts{'IDS_SE_FAILURE'} . " - " . $!;
return FormatReceived($sReturn);
}
sub GetPermissions
{
require Cwd;
my $sHTML = "<H1>" . $$::g_pPrompts{'IDS_SE_INFO_FILE_PERMISSIONS'} . "</H1>";
my $sCGIPath = Cwd::getcwd() . "/";
$sHTML .= "<H2>" . $$::g_pPrompts{'IDS_SE_INFO_FILE_PERMISSIONS_CGI'} . "</H2>";
$sHTML .=  DumpDirListing($sCGIPath);
chdir "../";
my $sCGIRoot = Cwd::getcwd() . "/";
$sHTML .= "<H2>" . $$::g_pPrompts{'IDS_SE_INFO_FILE_PERMISSIONS_CGI_ROOT'} . "</H2>";
$sHTML .=  DumpDirListing($sCGIRoot);
chdir $sCGIPath;
$sHTML .= "<H2>" . $$::g_pPrompts{'IDS_SE_INFO_FILE_PERMISSIONS_ACATALOG'} . "</H2>";
$sHTML .=  DumpDirListing($::g_sPathToAcatalog);
chdir $sCGIPath;
chdir $::g_sPathToAcatalog;
chdir "../";
my $sAcatalogRoot = Cwd::getcwd() . "/";
$sHTML .= "<H2>" . $$::g_pPrompts{'IDS_SE_INFO_FILE_PERMISSIONS_ACATALOG_ROOT'} . "</H2>";
$sHTML .=  DumpDirListing($sAcatalogRoot);
return($sHTML);
}
sub DumpDirListing
{
my $RDpath = $_[0];
my $sHTML;
if (!opendir (NQDIR, "$RDpath") )
{
$sHTML .= $$::g_pPrompts{'IDS_SE_COULDNT_READ_DIRECTORY'} . $RDpath;
return($sHTML);
}
my @aDirList = readdir (NQDIR);
closedir (NQDIR);
$sHTML .= "<B>$RDpath</B>";
$sHTML .= "<TABLE  BORDER=0>";
my $var;
foreach $var (@aDirList)
{
my @Results = stat($RDpath . $var);
$sHTML .= FormatLine($var, @Results) . "\n";
}
$sHTML .= "</TABLE><HR>";
return($sHTML);
}
sub FormatLine
{
my $sFilename = shift;
my @stat = @_;
my ($nMode, $nGroup, $nUser) = ($stat[2], $stat[5], $stat[4]);
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($stat[9]);
$mon++;
$year += 1900;
my $sDate = sprintf("%4.4d/%2.2d/%2.2d %2.2d:%2.2d:%2.2d ", $year, $mon, $mday, $hour, $min, $sec);
my $sPermission = FormatPerm($nMode);
my ($sGroup, $sUser) = GetUserAndGroup($nUser, $nGroup);
my $sLine = "<TR><TD>" . $sPermission . "</TD>" .
"<TD>" . $sUser . "</TD>" .
"<TD>" . $sGroup . "</TD>" .
"<TD>" . $stat[7] . "</TD>" .
"<TD>" . $sDate . "</TD>" .
"<TD><B>" . $sFilename. "</B></TD></TR>";
return($sLine);
}
sub GetUserAndGroup
{
my ($nUser, $nGroup) = @_;
my ($sGroup, $sUser);
if ($^O =~ /win/i)
{
eval 'require Win32;';
if (!$@)
{
my ($sServer, $nType);
Win32::LookupAccountSID("", $sUser, $sUser, $sServer, $nType);
$sGroup = $nGroup;
}
}
else
{
eval
{
$sUser = getpwuid($nUser);
$sGroup = getgrgid($nGroup);
}
}
return($sUser, $sGroup);
}
sub FormatPerm
{
my ($nMode) = @_;
my $sPerm = '-' x 9;
substr($sPerm, 0, 1) = 'r' if ($nMode & 00400);
substr($sPerm, 1, 1) = 'w' if ($nMode & 00200);
substr($sPerm, 2, 1) = 'x' if ($nMode & 00100);
substr($sPerm, 3, 1) = 'r' if ($nMode & 00040);
substr($sPerm, 4, 1) = 'w' if ($nMode & 00020);
substr($sPerm, 5, 1) = 'x' if ($nMode & 00010);
substr($sPerm, 6, 1) = 'r' if ($nMode & 00004);
substr($sPerm, 7, 1) = 'w' if ($nMode & 00002);
substr($sPerm, 8, 1) = 'x' if ($nMode & 00001);
substr($sPerm, 2, 1) = 's' if ($nMode & 04000);
substr($sPerm, 5, 1) = 's' if ($nMode & 02000);
substr($sPerm, 8, 1) = 't' if ($nMode & 01000);
return($sPerm);
}
sub GetPerlEnv
{
my $sHTML = "<H1>" . $$::g_pPrompts{'IDS_SE_INFO_PERL'} . "</H1>";
$sHTML .= "<TABLE BORDER=1>";
$sHTML .= "<TR><TD>" . $$::g_pPrompts{'IDS_SE_INFO_PERL_VERSION'} . "</TD><TD>" . $] . "</TD></TR>\n";
eval 'require Digest::MD5;';
my $sInstalled = $@ ? $$::g_pPrompts{'IDS_SE_INFO_NOT_INSTALLED'} : $$::g_pPrompts{'IDS_SE_INFO_INSTALLED'};
$sHTML .= "<TR><TD>Digest::MD5</TD><TD>" . $sInstalled . "</TD></TR>\n";
eval 'require ActEncrypt1024;';
$sInstalled = $@ ? $$::g_pPrompts{'IDS_SE_INFO_NOT_INSTALLED'} : $$::g_pPrompts{'IDS_SE_INFO_INSTALLED'};
$sHTML .= "<TR><TD>ActinicEncrypt1024</TD><TD>" . $sInstalled . "</TD></TR>\n";
my ($sUser, $sGroup, $sRUser, $sRGroup);
if ($^O =~ /win/i)
{
eval 'require Win32;';
$sUser = $@ ? "" : Win32::LoginName();
}
else
{
eval
{
($sRUser, $sRGroup) = GetUserAndGroup($<, $();
($sUser, $sGroup) = GetUserAndGroup($>, $));
}
}
$sHTML .= "<TR><TD>".$$::g_pPrompts{'IDS_SE_INFO_REAL_USER'}."</TD><TD>" . $sRUser . "</TD></TR>\n";
$sHTML .= "<TR><TD>".$$::g_pPrompts{'IDS_SE_INFO_REAL_GROUP'}."</TD><TD>" . $sRGroup . "</TD></TR>\n";
$sHTML .= "<TR><TD>".$$::g_pPrompts{'IDS_SE_INFO_EFF_USER'}."</TD><TD>" . $sUser . "</TD></TR>\n";
$sHTML .= "<TR><TD>".$$::g_pPrompts{'IDS_SE_INFO_EFF_GROUP'} ."</TD><TD>" . $sGroup . "</TD></TR>\n";
$sHTML .= "<TR><TD>".$$::g_pPrompts{'IDS_SE_INFO_SCRIPTNAME'}."</TD><TD>" . $0 . "</TD></TR>\n";
my ($sFtpUser, $sFtpGroup) = GetUserAndGroup((stat($0))[4, 5]);
$sHTML .= "<TR><TD>".$$::g_pPrompts{'IDS_SE_INFO_FTP_USER'}."</TD><TD>" . $sFtpUser . "</TD></TR>\n";
$sHTML .= "<TR><TD>".$$::g_pPrompts{'IDS_SE_INFO_FTP_GROUP'}."</TD><TD>" . $sFtpGroup . "</TD></TR>\n";
$sHTML .= "</TABLE>";
return($sHTML);
}
sub GetFormatedEnv
{
my $sHTML = "<H1>" . $$::g_pPrompts{'IDS_SE_INFO_ENV'} . "</H1>";
$sHTML .= "<TABLE BORDER=1>";
my $var;
foreach $var (sort(keys(%ENV)))
{
$sHTML .= "<TR><TD>" . $var . "</TD><TD>" . $ENV{$var} . "</TD></TR>\n";
}
$sHTML .= "</TABLE><HR>";
return($sHTML);
}
sub CheckSendMail
{
my $sHTML = "<H1>" . $$::g_pPrompts{'IDS_SE_INFO_SMTP'} . "</H1><BR>";
my ($nProto, $them, $nSmtpPort, $sMessage, $ServerIPAddress);
my $bPassed = $::TRUE;
if ($::g_sServerAddress eq '')
{
$sHTML .= FormatReceived("No SMTP server is specified.");
$bPassed = $::FALSE;
goto ERRORNOCLOSE;
}
my $sLocalhost = GetHostName();
if ($sLocalhost eq '')
{
$sLocalhost = 'localhost';
}
$sHTML .= FormatSent("Get host name...");
$sHTML .= FormatReceived("Host name is '$sLocalhost'");
$sHTML .= FormatSent("DNS lookup...");
$nProto = getprotobyname('tcp');
$nSmtpPort = 25;
$ServerIPAddress = inet_aton($::g_sServerAddress);
if (!defined $ServerIPAddress)
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERRORNOCLOSE;
}
$sHTML .= FormatReceived("OK");
$sHTML .= FormatSent("Create socket address...");
$them = sockaddr_in($nSmtpPort, $ServerIPAddress);
if (!defined $them)
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERRORNOCLOSE;
}
$sHTML .= FormatReceived("OK");
$sHTML .= FormatSent("Create socket...");
unless (socket(MYSOCKET, PF_INET, SOCK_STREAM, $nProto))
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERRORNOCLOSE;
}
$sHTML .= FormatReceived("OK");
$sHTML .= FormatSent("Connecting to socket...");
unless (connect(MYSOCKET, $them))
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
$sHTML .= FormatReceived("OK");
binmode MYSOCKET;
my($oldfh) = select(MYSOCKET);
$| = 1;
select($oldfh);
my $SMTPSocket = *MYSOCKET;
my $nResult;
$sHTML .= FormatSent("The connect message from the SMTP server...");
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
if (length $sMessage)
{
$sHTML .= FormatReceived($sMessage);
}
else
{
$sHTML .= FormatReceived('No response from the server.');
}
if ($nResult != $::SUCCESS)
{
$bPassed = $::FALSE;
goto ERROR;
}
$sHTML .= FormatSent("Sent: HELO $sLocalhost");
unless (print MYSOCKET "HELO $sLocalhost\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
$sHTML .= FormatReceived($sMessage);
if ($nResult != $::SUCCESS)
{
$bPassed = $::FALSE;
goto ERROR;
}
if ($::g_sEmailAddress ne "")
{
$sHTML .= FormatSent("Sent: MAIL FROM:&lt;" . $::g_sEmailAddress . ">");
unless (print MYSOCKET "MAIL FROM:<" . $::g_sEmailAddress . ">\r\n") # specify the origin (I will have the self as the origin)
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
$sHTML .= FormatReceived($sMessage);
if ($nResult != $::SUCCESS)
{
$bPassed = $::FALSE;
goto ERROR;
}
$sHTML .= FormatSent("Sent: RCPT TO:&lt;" . $::g_sEmailAddress . ">");
unless (print MYSOCKET "RCPT TO:<",$::g_sEmailAddress,">\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
$sHTML .= FormatReceived($sMessage);
if ($nResult != $::SUCCESS)
{
$bPassed = $::FALSE;
goto ERROR;
}
$sHTML .= FormatSent("Sent: DATA");
unless (print MYSOCKET "DATA\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
$sHTML .= FormatReceived($sMessage);
if ($nResult != $::SUCCESS)
{
$bPassed = $::FALSE;
goto ERROR;
}
$sHTML .= FormatSent("Sent: From: $::g_sEmailAddress");
unless (print MYSOCKET "From: $::g_sEmailAddress\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
$sHTML .= FormatSent("Sent: Subject: This is a test email from Actinic Catalog.");
unless (print MYSOCKET "Subject: This is a test email from Actinic Catalog.\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
$sHTML .= FormatSent("Sent: To: $::g_sEmailAddress");
unless (print MYSOCKET "To: $::g_sEmailAddress\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
$sHTML .= FormatSent("Sent: Reply-To: $::g_sEmailAddress");
unless (print MYSOCKET "Reply-To: $::g_sEmailAddress\r\n\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
$sHTML .= FormatSent("Sent: This is the test message from Actinic Catalog.");
unless (print MYSOCKET "This is the test message from Actinic Catalog.\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
$sHTML .= FormatSent("Sent: The email address and SMTP server you specified");
unless (print MYSOCKET "The email address and SMTP server you specified\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
$sHTML .= FormatSent("Sent: in the network preferences are correct.");
unless (print MYSOCKET "in the network preferences are correct.\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
$sHTML .= FormatSent("Sent: .");
unless (print MYSOCKET "\r\n.\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
$sHTML .= FormatReceived($sMessage);
if ($nResult != $::SUCCESS)
{
$bPassed = $::FALSE;
goto ERROR;
}
}
else
{
$sHTML .= FormatSent("NOOP");
unless (print MYSOCKET "NOOP\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
$sHTML .= FormatReceived($sMessage);
if ($nResult != $::SUCCESS)
{
$bPassed = $::FALSE;
goto ERROR;
}
}
sleep 1;
$sHTML .= FormatSent("QUIT");
unless (print MYSOCKET "QUIT\r\n")
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
$sHTML .= FormatReceived($sMessage);
if ($nResult != $::SUCCESS)
{
$sHTML .= FormatReceived("FAILED. $!");
$bPassed = $::FALSE;
goto ERROR;
}
ERROR:
sleep 1;
shutdown MYSOCKET, 1;
while ($sMessage = <MYSOCKET>)
{
$sHTML .= FormatReceived($sMessage);
}
close MYSOCKET;
ERRORNOCLOSE:
if ($bPassed)
{
$sHTML .= FormatSent('SMTP Test passed');
}
else
{
$sHTML .= FormatSent('SMTP Test failed');
}
$sHTML .= FormatSent('_____ End of SMTP Test ____');
return ($sHTML);
}
sub FormatSent
{
return($_[0] . "<BR>");
}
sub FormatReceived
{
return("<BLOCKQUOTE>$_[0]</BLOCKQUOTE>");
}
sub CheckSMTPResponse
{
my $pSocket = shift;
my ($sMessage, $sMsg, $sCode, $bMore, $nResult);
$nResult = $::SUCCESS;
do
{
$sMsg = readline($pSocket);
$sMsg =~ /^(\d\d\d)(.?)/;
$sCode = $1;
$bMore = $2 eq "-";
if (length $sMessage)
{
$sMessage .= "<BR>";
}
$sMessage .= $sMsg;
if (length $sCode < 3)
{
$nResult = $::FAILURE;
}
if ($sCode =~ /^[45]/)
{
$nResult = $::FAILURE;
}
} while ($bMore);
return ($nResult, $sMessage);
}
sub GetHostName
{
my $sLocalhost = $ENV{SERVER_NAME};
$sLocalhost =~ s/[^-a-zA-Z0-9.]//g;
if (!$sLocalhost)
{
$sLocalhost = $ENV{HOST};
$sLocalhost =~ s/[^-a-zA-Z0-9.]//g;
}
if (!$sLocalhost)
{
$sLocalhost = $ENV{HTTP_HOST};
$sLocalhost =~ s/[^-a-zA-Z0-9.]//g;
}
if (!$sLocalhost)
{
$sLocalhost = $ENV{LOCALDOMAIN};
$sLocalhost =~ s/[^-a-zA-Z0-9.]//g;
}
if (!$sLocalhost)
{
$sLocalhost = `hostname`;
$sLocalhost =~ s/[^-a-zA-Z0-9.]//g;
}
if (!$sLocalhost &&
$^O eq 'MSWin32')
{
my $sHost = `ipconfig`;
$sHost =~ /IP Address\D*([0-9.]*)/;
$sLocalhost = $1;
$sLocalhost =~ s/[^-a-zA-Z0-9.]//g;
}
return($sLocalhost);
}
sub PrintPage
{
my ($nLength, $sHTML, $sCookie);
($sHTML, $sCookie) = @_;
$nLength = length $sHTML;
binmode STDOUT;
PrintHeader('text/html', $nLength, $sCookie);
print $sHTML;
}
sub PrintHeader
{
my ($sType, $nLength, $sCookie) = @_;
my (@expires, $day, $month, $now, $later, @now, $sNow);
my (@days) = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
my (@months) = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
$now = time;
@now = gmtime($now);
$day = $days[$now[6]];
$month = $months[$now[4]];
$sNow = sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT", $day, $now[3],
$month, $now[5]+1900, $now[2], $now[1], $now[0]);
if($ENV{'PerlXS'} eq 'PerlIS')
{
print "HTTP/1.0 200 OK\n";
}
print "Date: $sNow\r\n";
print "Content-type: $sType\r\n";
print "Content-length: $nLength\r\n\r\n";
}
sub ReadAndParseInput
{
my ($InputData, $nInputLength);
if ( (length $::ENV{'QUERY_STRING'}) > 0)
{
$InputData = $::ENV{'QUERY_STRING'};
$nInputLength = length $InputData;
}
else
{
my ($nStep, $InputBuffer);
$nInputLength = 0;
$nStep = 0;
while ($nInputLength != $ENV{'CONTENT_LENGTH'})
{
binmode STDIN;
$nStep = read(STDIN, $InputBuffer, $ENV{'CONTENT_LENGTH'});  # Set $::g_InputData equal to user input
$nInputLength += $nStep;
$InputData .= $InputBuffer;
if (0 == $nStep)
{
last;
}
}
if ($nInputLength != $ENV{'CONTENT_LENGTH'})
{
return ($::FAILURE, "Bad input.  The data length actually read ($nInputLength) does not match the length specified " . $ENV{'CONTENT_LENGTH'} . "\n", '', '', 0, 0);
}
}
$InputData =~ s/&$//;
$InputData =~ s/=$/= /;
my ($OriginalInputData);
$OriginalInputData = $InputData;
if ($nInputLength == 0)
{
return ($::FAILURE, "The input is NULL", '', '', 0, 0);
}
my (@CheckData, %DecodedInput);
@CheckData = split (/[&=]/, $InputData);
if ($#CheckData % 2 != 1)
{
return ($::FAILURE, "Bad input string \"" . $InputData . "\".  Argument count " . $#CheckData . ".\n", '', '', 0, 0);
}
my %EncodedInput = split(/[&=]/, $InputData);
my ($key, $value);
while (($key, $value) = each %EncodedInput)
{
$key = DecodeText($key, $ACTINIC::FORM_URL_ENCODED);
$value = DecodeText($value, $ACTINIC::FORM_URL_ENCODED);
if ( ($key =~ /\0/ ||
$value =~ /\0/))
{
return ($::FAILURE, "Input contains invalid characters.", undef, undef, undef, undef);
}
$DecodedInput{$key} = $value;
}
return ($::SUCCESS, '', $OriginalInputData, '', %DecodedInput);
}
sub DecodeText
{
my ($sString, $eEncoding) = @_;
if ($eEncoding == $ACTINIC::MODIFIED_FORM_URL_ENCODED)
{
$sString =~ s/^a//;
$sString =~ s/_([A-Fa-f0-9]{2})/pack('c',hex($1))/ge;
}
elsif ($eEncoding == $ACTINIC::FORM_URL_ENCODED)
{
$sString =~ s/\+/ /g;
$sString =~ s/%([A-Fa-f0-9]{2})/pack('c',hex($1))/ge;
}
elsif ($eEncoding == $ACTINIC::HTML_ENCODED)
{
$sString =~ s/&#([0-9]+);/chr($1)/eg;
}
return ($sString);
}