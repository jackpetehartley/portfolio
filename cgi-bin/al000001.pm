#!perl
package ACTINIC;
require 5.002;
push (@INC, "cgi-bin");
require as000001;
require ad000001;
require ae000001;
require ac000001;
use Socket;
use strict;
umask (0177);
$ACTINIC::prog_name = 'ACTINIC.pm';
$ACTINIC::prog_name = $ACTINIC::prog_name;
$ACTINIC::prog_ver = '$Revision: 20560 $ ';
$ACTINIC::prog_ver = substr($ACTINIC::prog_ver, 11);
$ACTINIC::prog_ver =~ s/ \$//;
$ACTINIC::BILLCONTACT 	= "INVOICE";
$ACTINIC::SHIPCONTACT 	= "DELIVERY";
$ACTINIC::SHIPINFO 		= "SHIPPING";
$ACTINIC::TAXINFO 		= "TAX";
$ACTINIC::GENERALINFO 	= "GENERAL";
$ACTINIC::PAYMENTINFO 	= "PAYMENT";
$ACTINIC::LOCATIONINFO 	= "LOCATION";
$ACTINIC::FILE				= 0;
$ACTINIC::SDTOUT			= 1;
$ACTINIC::MEMORY			= 2;
$ACTINIC::s_bTraceSocket = $::FALSE;
$ACTINIC::s_bTraceSockFirstPass = $::TRUE;
$ACTINIC::s_bTraceFileFirstPass = $::TRUE;
$ACTINIC::ORDER_BLOB_MAGIC = hex('10');
$ACTINIC::ORDER_DETAIL_BLOB_MAGIC = hex("11");
$ACTINIC::FORM_URL_ENCODED 			= 0;
$ACTINIC::MODIFIED_FORM_URL_ENCODED	= 1;
$ACTINIC::HTML_ENCODED					= 2;
$ACTINIC::B2B = new ACTINIC_B2B();
$ACTINIC::USESAFE = $::TRUE;
$ACTINIC::USESAFEONLY = $::FALSE;
$ACTINIC::MAX_RETRY_COUNT      = 10;
$ACTINIC::RETRY_SLEEP_DURATION = 1;
$ACTINIC::DOS_SLEEP_DURATION = 2;
$ACTINIC::AssertIsActive = $::FALSE;
$ACTINIC::AssertIsLooping = $::FALSE;
$ACTINIC::ActinicHostMode = $::FALSE;
sub GetStoreFolderName
{
my $sStoreFolderName = $$::g_pSetupBlob{'CATALOG_URL'};
if ($sStoreFolderName =~ /([^\/\\]+)([\/\\]?)$/)
{
return $1;
}
else
{
}
return "";
}
sub GetActinicDate
{
my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst, $sDate);
($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime(time);
$mon++;
$year += 1900;
$sDate = sprintf("%4.4d/%2.2d/%2.2d %2.2d:%2.2d", $year, $mon, $mday, $hour, $min);
return($sDate);
}
sub FormatDate
{
my ($sDay, $sMonth, $sYear, $bEditable) = @_;
if (!defined $bEditable )
{
$bEditable = $::TRUE;
}
my $sDatePrompt = ACTINIC::GetPhrase(-1, $bEditable ? 2247 : 1912);
if ($sDatePrompt !~ s/dd/$sDay/i)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 1913), ACTINIC::GetPath());
}
if ($sDatePrompt !~ s/mm/$sMonth/i)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 1913), ACTINIC::GetPath());
}
if ($sDatePrompt !~ s/yy/$sYear/i)
{
ACTINIC::ReportError(ACTINIC::GetPhrase(-1, 1913), ACTINIC::GetPath());
}
return ($sDatePrompt);
}
sub InitMonthMap
{
%::g_MonthMap = (GetPhrase(-1, 0), 1,
GetPhrase(-1, 1), 2,
GetPhrase(-1, 2), 3,
GetPhrase(-1, 3), 4,
GetPhrase(-1, 4), 5,
GetPhrase(-1, 5), 6,
GetPhrase(-1, 6), 7,
GetPhrase(-1, 7), 8,
GetPhrase(-1, 8), 9,
GetPhrase(-1, 9), 10,
GetPhrase(-1, 10), 11,
GetPhrase(-1, 11), 12);
my ($key, $value);
while ( ($key, $value) = each %::g_MonthMap)
{
$::g_InverseMonthMap{$value} = $key;
}
@::gMonthList = sort {$::g_MonthMap{$a} <=> $::g_MonthMap{$b}} keys %::g_MonthMap;
}
sub GenerateComboHTML
{
my ($sName, $nDefault, $sFormat, $sStyle, @aItems) = @_;
if (!$sFormat)
{
$sFormat = "%d";
}
my $sItem;
my $sHTML = "<SELECT NAME='$sName' SIZE='1' $sStyle>\n";
foreach $sItem (@aItems)
{
if ($sItem eq $nDefault)
{
$sHTML .= '<OPTION SELECTED>' . sprintf($sFormat, $sItem) . "\n";
}
else
{
$sHTML .= '<OPTION>' . sprintf($sFormat, $sItem) . "\n";
}
}
$sHTML .= "</SELECT>";
return ($sHTML);
}
sub GetCountryName
{
my $sCode = $_[0];
return ($$::g_pLocationList{$sCode}{'NAME'});
}
sub IsValidIP
{
my $sToCheck 	= shift;
my $sRules		= shift;
my @aOctetsToCheck = split /\./, $sToCheck;
my $sError;
if (scalar @aOctetsToCheck != 4)
{
$sError = $sToCheck . " Invalid IP - the passed in IP does not have 4 octets.\r\n";
SendMail($::g_sSmtpServer,
$::g_pSetupBlob->{'EMAIL'},
"Invalid IP Address Rule",
$sError);
RecordErrors($sError, GetPath());
return $::FALSE;
}
$sRules =~ s/\s//;
my @aRules = split /,/, $sRules;
my $sIP;
foreach $sIP (@aRules)
{
my @aOctets = split /\./, $sIP;
if (scalar @aOctets != 4)
{
$sError .= join('.',@aOctets) . " IP address rule seems to be invalid - not 4 octets\r\n";
next;
}
my $nIndex;
my $bValid = $::TRUE;
for ($nIndex = 0; $nIndex < 4; $nIndex++)
{
if ($aOctets[$nIndex] eq "*")
{
next;
}
elsif ($aOctets[$nIndex] =~ /^\d+$/)
{
if ($aOctets[$nIndex] == $aOctetsToCheck[$nIndex])
{
next;
}
}
elsif ($aOctets[$nIndex] =~ /^(\d+)\-(\d+)$/)
{
if ($aOctetsToCheck[$nIndex] >= $1 &&
$aOctetsToCheck[$nIndex] <= $2)
{
next;
}
}
else
{
$sError .= join('.',@aOctets) . " IP address rule seems to be invalid - none of the octet rules can be applied\r\n";
last;
}
$bValid = $::FALSE;
last;
}
if ($bValid)
{
if (length $sError > 0)
{
RecordErrors($sError, GetPath());
SendMail($::g_sSmtpServer,
$::g_pSetupBlob->{'EMAIL'},
"Invalid IP Address Rule",
$sError);
}
return $::TRUE;
}
}
if (length $sError > 0)
{
RecordErrors($sError, GetPath());
SendMail($::g_sSmtpServer,
$::g_pSetupBlob->{'EMAIL'},
"Invalid IP Address Rule",
$sError);
}
return $::FALSE;
}
sub GetHostname
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
return ($sLocalhost);
}
sub HTTP_SendAndReceive
{
my ($sServer, $sPort, $sPath, $sContent, $sMethod) = @_;
if (!defined $sMethod)
{
$sMethod = "GET";
}
my $proto = getprotobyname('tcp');
my $ServerIP = inet_aton($sServer);
if (!defined $ServerIP)
{
return($::FAILURE, GetPhrase(-1, 13, "$sServer: $!"), '');
}
my $sin = sockaddr_in($sPort, $ServerIP);
if (!defined $sin)
{
return($::FAILURE, GetPhrase(-1, 14, $!), '');
}
unless (socket(MYSOCKET, PF_INET, SOCK_STREAM, $proto))
{
return($::FAILURE, GetPhrase(-1, 1935, $!), '');
}
unless (connect(MYSOCKET, $sin))
{
my $sError = GetPhrase(-1, 1934, $!);
close(MYSOCKET);
return($::FAILURE, $sError, '');
}
my $old_fh = select(MYSOCKET);
$| = 1; 		        # don't buffer output
select($old_fh);
binmode MYSOCKET;
print MYSOCKET "$sMethod $sPath HTTP/1.0\r\n";
print MYSOCKET "Content-Type: application/x-www-form-urlencoded\r\n";
print MYSOCKET "Content-Length: " . (length $sContent) ."\r\n";
print MYSOCKET "Accept: */*\r\n";
print MYSOCKET "User-Agent: ActinicEcommerce\r\n";
print MYSOCKET "\r\n";
print MYSOCKET $sContent;
my $sMessage = <MYSOCKET>;
chomp($sMessage);
if ($sMessage =~ /^HTTP.+\s([45].*)/)
{
close(MYSOCKET);
return($::FAILURE, GetPhrase(-1, 1936, $1), '');
}
my $sResponse;
{
local $/;
$sResponse = <MYSOCKET>;
}
close(MYSOCKET);
return($::SUCCESS, $sMessage, $sResponse);
}
sub HTTPS_SendAndReceive
{
my ($sServer, $sPort, $sPath, $sContent, $sMethod, $bCloseConnection, $ssl_socket, $sHeader) = @_;
if (!defined $sMethod)
{
$sMethod = "GET";
}
if (!defined $bCloseConnection)
{
$bCloseConnection = $::TRUE;
}
if (!defined $sHeader)
{
$sHeader .= "Content-Type: application/x-www-form-urlencoded\r\n";
$sHeader .= "Accept: */*\r\n";
$sHeader .= "User-Agent: ActinicEcommerce\r\n";
}
my $sData = "$sMethod $sPath HTTP/1.0\r\n";
$sData .= "Content-Length: " . (length $sContent) ."\r\n";
$sData .= $sHeader;
$sData .= "\r\n";
$sData .= $sContent;
my $sResponse;
my $nResult = $::SUCCESS;
my $sMessage = '';
if (!defined $ssl_socket)
{
eval
{
require Net::SSL;
$ssl_socket = new Net::SSL(PeerAddr => $sServer, PeerPort => $sPort);
if (!$ssl_socket)
{
$nResult = $::FAILURE;
$sMessage = GetPhrase(-1, 1934, $!);
}
};
if ($@)
{
require sc000001;
($nResult, $sMessage, $ssl_socket) = new ActinicSSL($sServer, $sPort);
}
}
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage, '');
}
if ($ssl_socket->isa('Net::SSL'))
{
$ssl_socket->print($sData);
my $buf ='';
while ($ssl_socket->read($buf, 1024))
{
$sResponse .= $buf;
}
$nResult = $::SUCCESS;
$sMessage = '';
$bCloseConnection = $::TRUE;
}
elsif ($ssl_socket->isa('ActinicSSL'))
{
($nResult, $sMessage) = $ssl_socket->send($sData);
my $sResponseLine;
while ($nResult == $::SUCCESS)
{
($nResult, $sMessage, $sResponseLine) = $ssl_socket->recv();
$sResponse .= $sResponseLine;
}
if ($nResult == $::EOF)
{
$nResult = $::SUCCESS;
}
$bCloseConnection = $::TRUE;
}
else
{
}
if ($bCloseConnection)
{
$ssl_socket->close();
undef $ssl_socket;
}
return($nResult, $sMessage, $sResponse, $ssl_socket);
}
sub HTTP_SplitHeaderAndContent
{
my ($sHTTPResponse) = @_;
my $nHeaderEnd = index($sHTTPResponse, "\r\n\r\n");
if($nHeaderEnd == -1)
{
return($::FALSE, 'Malformed HTTP response:' . $sHTTPResponse);
}
my $sHeader = substr($sHTTPResponse, 0, $nHeaderEnd + 2);
my $sContent = substr($sHTTPResponse, $nHeaderEnd + 4);
my @arrHeader = split(/\r\n/, $sHeader);
my ($sHeaderLine, $sHeaderType, $sHeaderValue);
my %hashHeader;
foreach $sHeaderLine(@arrHeader)
{
if($sHeaderLine ne '')
{
($sHeaderType, $sHeaderValue) = split(/: */, $sHeaderLine);
if($sHeaderValue)
{
$hashHeader{$sHeaderType} =
$sHeaderValue;
}
}
}
return($::TRUE, '', $sHeader, $sContent, \%hashHeader);
}
sub SendMail
{
if ($#_ < 3)
{
return($::FAILURE, GetPhrase(-1, 12, 'Actinic::SendMail'), 0, 0);
}
my ($sSmtpServer, $sEmailAddress, $sSubjectText, $sMessageText, $sReturnAddress) = @_;
return(SendRichMail($sSmtpServer, $sEmailAddress, $sSubjectText, $sMessageText, "", $sReturnAddress));
}
sub CheckSMTPResponse
{
my ($pSocket, $bDetail) = @_;
my ($sMessage, $sCode, $bMore, $nResult, @lDetails);
$nResult = $::SUCCESS;
do
{
my $sTemp;
$sMessage = readline($pSocket);
$sMessage =~ s/^(\d\d\d)(.?)//;
$sCode = $1;
$bMore = $2 eq "-";
if ($bDetail)
{
$sTemp = $sCode . ',' . $sMessage;
push @lDetails, $sTemp;
}
if (length $sCode < 3)
{
$nResult = $::FAILURE;
}
if ($sCode =~ /^[45]/)
{
$nResult = $::FAILURE;
}
} while ($bMore);
if ($bDetail)
{
return ($nResult, $sMessage, @lDetails);
}
else
{
return ($nResult, $sMessage);
}
}
sub SMTPAuthentication
{
my ($pSocket, $sReportedServerName, @lDetails) = @_;
my ($sOfferedMethods, @lsSupportedMethods, $sTemp, $sSelectedMethod, $sSelectedHandler, $sMessage, $nResult, $nCode, $sAnswer);
require sa000001;
$ActinicSMTPAuth::sServername = $sReportedServerName;
foreach $sTemp (@lDetails)
{
my ($sCode, $sMessage) = split(/,/, $sTemp);
if ($sTemp =~ /AUTH[ |=](.*)$/i)
{
$sOfferedMethods = $1;
last;
}
}
if (length $sOfferedMethods == 0)
{
return ($::FAILURE, "SMTP Authentication is not supported by this server!");
}
for( my $nI = 0; $nI <= $#ActinicSMTPAuth::lsProtocol; $nI++)
{
if ($sOfferedMethods =~ /$ActinicSMTPAuth::lsProtocol[$nI]/i)
{
$sSelectedMethod = $ActinicSMTPAuth::lsProtocol[$nI];
$sSelectedHandler = $ActinicSMTPAuth::lpHandler[$nI];
if (length $sSelectedMethod == 0)
{
return ($::FAILURE, "We couldn't find matching methods in Supported and Offered methods!");
}
my $sAuthTrailer;
($nResult, $sAuthTrailer) = &$sSelectedHandler(0, $sAnswer);
if ($nResult != $::SUCCESS)
{
return($::FAILURE, $sMessage);
}
$sTemp = "AUTH " . $sSelectedMethod . ' ' . $sAuthTrailer . "\r\n";
unless (print $pSocket $sTemp)
{
$sMessage = GetPhrase(-1, 18, 2, $!);
return($::FAILURE, $sMessage);
}
my $bNeedMore = $::TRUE;
for (my $nII = 1; 1; $nII++)
{
($nResult, $sMessage, @lDetails) = CheckSMTPResponse($pSocket, $::TRUE);
$lDetails[0] =~ /([^,]*),(.*)/;
$nCode = $1;
$sAnswer = $2;
if ($nCode == 235)
{
return ($::SUCCESS, '');
}
if ($nCode != 334)
{
last;
}
($nResult, $sTemp, $bNeedMore) = &$sSelectedHandler($nII, $sAnswer);
if ($nResult != $::SUCCESS)
{
return($::FAILURE, $sTemp);
}
unless (print $pSocket $sTemp)
{
$sMessage = GetPhrase(-1, 18, 2, $!);
return($::FAILURE, $sMessage);
}
}
}
}
return($::FAILURE, $nCode . ' ' . $sAnswer);
}
sub SendRichMail
{
if ($#_ < 4)
{
return($::FAILURE, GetPhrase(-1, 12, 'Actinic::SendRichMail'), 0, 0);
}
my ($sSmtpServer, $sEmailAddress, $sLocalError, $sSubjectText, $sMessageText, $sMessageHTML, $sBoundary, $sReturnAddress);
($sSmtpServer, $sEmailAddress, $sSubjectText, $sMessageText, $sMessageHTML, $sReturnAddress) = @_;
my (@lDetails);
if ($sSmtpServer eq '')
{
return($::FAILURE, GetPhrase(-1, 2306), 0, 0);
}
$sMessageText =~ s/\r\n/\n/g;
$sMessageText =~ s/\r/\n/g;
$sMessageText =~ s/\n/\r\n/g;
$sMessageHTML =~ s/\r\n/\n/g;
$sMessageHTML =~ s/\r/\n/g;
$sMessageHTML =~ s/\n/\r\n/g;
if (!$sReturnAddress)
{
$sReturnAddress = $sEmailAddress;
}
my ($nProto, $them, $nSmtpPort, $sLocalHost, $sMessage, $serverIP);
my $sLocalhost = GetHostname();
if ($sLocalhost eq '')
{
$sLocalhost = 'localhost';
}
$nProto = getprotobyname('tcp');
$nSmtpPort = 25;
$serverIP = inet_aton($sSmtpServer);
if (!defined $serverIP)
{
return($::FAILURE, GetPhrase(-1, 13, "$sSmtpServer: $!"), 0, 0);
}
$them = sockaddr_in($nSmtpPort, $serverIP);
if (!defined $them)
{
return($::FAILURE, GetPhrase(-1, 14, $!), 0, 0);
}
unless (socket(MYSOCKET, PF_INET, SOCK_STREAM, $nProto))
{
return($::FAILURE, GetPhrase(-1, 15, $!), 0, 0);
}
unless (connect(MYSOCKET, $them))
{
$sLocalError = GetPhrase(-1, 16, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
binmode MYSOCKET;
my($oldfh) = select(MYSOCKET);
$| = 1;
select($oldfh);
my $SMTPSocket = *MYSOCKET;
my $nResult;
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
$sMessage =~ /([^ ]*)/;
my $sReportedServerName = $1;
if ($nResult != $::SUCCESS)
{
$sLocalError = GetPhrase(-1, 17, 1, $sMessage);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
my $sHelloMsg = ($::bSTMPAuth == $::TRUE ? 'EHLO ' : 'HELO ') . "$sLocalhost\r\n";
unless (print MYSOCKET $sHelloMsg)
{
$sLocalError = GetPhrase(-1, 18, 1, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
($nResult, $sMessage, @lDetails) = CheckSMTPResponse($SMTPSocket, $::TRUE);
if ($nResult != $::SUCCESS)
{
$sLocalError = GetPhrase(-1, 17, 2, $sMessage);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
if ($::bSTMPAuth == $::TRUE)
{
($nResult, $sMessage) = SMTPAuthentication($SMTPSocket, $sReportedServerName, @lDetails);
if ($nResult != $::SUCCESS)
{
$sLocalError = GetPhrase(-1, 17, 1, $sMessage);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
}
unless (print MYSOCKET "MAIL FROM:<" . $sReturnAddress . ">\r\n")
{
$sLocalError = GetPhrase(-1, 18, 2, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
if ($nResult != $::SUCCESS)
{
$sLocalError = GetPhrase(-1, 17, 3, $sMessage);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
unless (print MYSOCKET "RCPT TO:<",$sEmailAddress,">\r\n")
{
$sLocalError = GetPhrase(-1, 18, 3, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
if ($nResult != $::SUCCESS)
{
$sLocalError = GetPhrase(-1, 17, 4, $sMessage);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
unless (print MYSOCKET "DATA\r\n")
{
$sLocalError = GetPhrase(-1, 18, 4, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
if ($nResult != $::SUCCESS)
{
$sLocalError = GetPhrase(-1, 17, 5, $sMessage);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
if ($sMessageText ne '' && $sMessageHTML ne '')
{
$sBoundary = "------------" . $::g_InputHash{ORDERNUMBER};
unless (print MYSOCKET "MIME-Version: 1.0\r\n")
{
$sLocalError = GetPhrase(-1, 18, 11, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
}
else
{
$sBoundary = "";
}
my ($month, $now, @now, $sNow);
my (@months) = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
$now = time;
@now = gmtime($now);
$month = $months[$now[4]];
$sNow = sprintf("%02d %s %04d %02d:%02d:%02d GMT", $now[3], $month, $now[5]+1900, $now[2], $now[1], $now[0]);
unless (print MYSOCKET "Date: $sNow\r\n")
{
$sLocalError = GetPhrase(-1, 18, 5, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
unless (print MYSOCKET "From: $sReturnAddress\r\n")
{
$sLocalError = GetPhrase(-1, 18, 5, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
unless (print MYSOCKET "Subject: $sSubjectText\r\n")
{
$sLocalError = GetPhrase(-1, 18, 6, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
unless (print MYSOCKET "To: $sEmailAddress\r\n")
{
$sLocalError = GetPhrase(-1, 18, 7, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
unless (print MYSOCKET "Reply-To: $sReturnAddress\r\n")
{
$sLocalError = GetPhrase(-1, 18, 8, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
if ($sBoundary ne '')
{
my $sContentMultipart = "Content-Type: multipart/alternative; ";
$sContentMultipart .= "boundary=\"" . $sBoundary . "\"\r\n\r\n";
unless (print MYSOCKET $sContentMultipart) # content-type
{
$sLocalError = GetPhrase(-1, 18, 12, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
}
else
{
my $sContentType = "Content-Type: text/plain; charset=ISO-8859-1\r\n";
$sContentType .= "Content-Transfer-Encoding: 8bit\r\n";
unless (print MYSOCKET $sContentType) # content-type
{
$sLocalError = GetPhrase(-1, 18, 12, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
}
unless (print MYSOCKET "\r\n")
{
$sLocalError = GetPhrase(-1, 18, 8, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
if ($sBoundary ne '')
{
my $sTextMultipart = "--" . $sBoundary . "\r\n";
$sTextMultipart .= "Content-Type: text/plain; charset=us-ascii\r\n";
$sTextMultipart .= "Content-Transfer-Encoding: 7bit\r\n\r\n" . $sMessageText . "\r\n\r\n";
unless (print MYSOCKET $sTextMultipart)
{
$sLocalError = GetPhrase(-1, 18, 13, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
my $sHTMLMultipart = "--" . $sBoundary . "\r\n";
$sHTMLMultipart .= "Content-Type: text/html; charset=us-ascii\r\n";
$sHTMLMultipart .= "Content-Transfer-Encoding: 7bit\r\n\r\n" . $sMessageHTML . "\r\n\r\n";
unless (print MYSOCKET $sHTMLMultipart)
{
$sLocalError = GetPhrase(-1, 18, 14, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
my $sEndMultipart = "--" . $sBoundary . "--\r\n";
unless (print MYSOCKET $sEndMultipart)
{
$sLocalError = GetPhrase(-1, 18, 15, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
}
else
{
unless (print MYSOCKET "$sMessageText\r\n")
{
$sLocalError = GetPhrase(-1, 17, 6, $sMessage);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
}
unless (print MYSOCKET "\r\n.\r\n")
{
$sLocalError = GetPhrase(-1, 18, 9, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
if ($nResult != $::SUCCESS)
{
$sLocalError = GetPhrase(-1, 17, 7, $sMessage);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
unless (print MYSOCKET "QUIT\r\n")
{
$sLocalError = GetPhrase(-1, 18, 10, $!);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
($nResult, $sMessage) = CheckSMTPResponse($SMTPSocket);
if ($nResult != $::SUCCESS)
{
$sLocalError = GetPhrase(-1, 17, 8, $sMessage);
close MYSOCKET;
return($::FAILURE, $sLocalError, 0, 0);
}
shutdown MYSOCKET, 1;
close MYSOCKET;
return($::SUCCESS, '', 0, 0);
}
sub GetScriptUrl
{
my $sScriptID = shift;
my $sCgiUrl = $$::g_pSetupBlob{CGI_URL};
if ($$::g_pSetupBlob{'USE_RELATIVE_CGI_URLS'})
{
$sCgiUrl =~ s/http(s?):\/\/[^\/]*\//\//;
}
$sCgiUrl .= "%s" . sprintf("%6.6d%s",$$::g_pSetupBlob{CGI_ID},$$::g_pSetupBlob{CGI_EXT});
$sCgiUrl = sprintf($sCgiUrl, $sScriptID);
return $sCgiUrl;
}
sub GetCookies
{
my ($sCookie, $sCookies);
$sCookies = $::ENV{'HTTP_COOKIE'};
my (@CookieList) = split(/;/, $sCookies);
my ($sLabel);
my ($sCartID, $sContactDetails);
foreach $sCookie (@CookieList)
{
$sCookie =~ s/^\s*//;
if ($sCookie =~ /^ACTINIC_CART/)
{
($sLabel, $sCartID) = split (/=/, $sCookie);
$sCartID =~ /([a-zA-Z0-9]+)/;
$sCartID = $1;
}
elsif ($sCookie =~ /^ACTINIC_CONTACT/)
{
($sLabel, $sContactDetails) = split (/=/, $sCookie);
$sContactDetails =~ s/^\s*"?//;        # "
$sContactDetails =~ s/"?\s*$//;        # "
}
elsif ($sCookie =~ /^ACTINIC_REFERRER=(.*)/)
{
my ($bDefined, $sAlternatePath) = IsCustomVarDefined('ACT_REFERRERCOOKIE_OFF');
if (!$bDefined &&
!IsCatalogFramed() &&
!$$::g_pSetupBlob{CLEAR_ALL_FRAMES})
{
$::g_sReferrer = DecodeText($1, $ACTINIC::FORM_URL_ENCODED);
}
}
}
if ($::g_sReferrer eq "")
{
$::g_sReferrer = $::ENV{"HTTP_REFERER"};
}
ParseReferrer();
my ($sDigest,$sBaseFile) = ACTINIC::CaccGetCookies();
if ($sDigest ||
$::g_InputHash{HASH})
{
$sContactDetails = "";
}
return ($sCartID, $sContactDetails);
}
sub ParseReferrer
{
my ($sURL);
$::g_bRealReferrer = $::TRUE;
$sURL = $::g_sReferrer;
if ((defined %::g_InputHash) &&
(defined $::g_InputHash{ACTINIC_REFERRER}))
{
$sURL = $::g_InputHash{ACTINIC_REFERRER};
}
$sURL =~ s/(.*)([\?|\&]ACTINIC_REFERRER=.*?)(\&.*|$)/$1$3/i;
if ((defined %::g_InputHash) &&
(defined $::g_InputHash{ACTINIC_REFERRER}))
{
$::g_InputHash{ACTINIC_REFERRER} = $sURL;
}
if (($sURL !~ /\/$/) &&
($sURL ne ""))
{
my @lFields = split('/',$sURL);
my $sFnam = pop @lFields;
if ($sFnam !~ /\./)
{
if ($sFnam =~ /\?/ ||
$sFnam =~ /&/)
{
$sURL = '';
}
else
{
$sURL .= '/';
}
}
else
{
pop @lFields;
my $sPrev = pop @lFields;
if ($sPrev=~ /^http(s?):/)
{
$sURL .= '/';
}
}
}
if ($sURL eq '')
{
if (ACTINIC::IsCatalogFramed())
{
$sURL = $$::g_pSetupBlob{CATALOG_URL} . $$::g_pSetupBlob{FRAMESET_PAGE};
}
else
{
$sURL = $$::g_pSetupBlob{CATALOG_URL} . $$::g_pSetupBlob{CATALOG_PAGE};
}
$::g_bRealReferrer = $::FALSE;
}
$sURL =~ s/COOKIE\=[^\&]*\&//;
if ((defined $::g_InputHash{challenge}) &&
(!defined $::g_InputHash{ACTINIC_REFERRER}))
{
$::g_InputHash{ACTINIC_REFERRER} = $sURL;
}
$::g_sReferrer = $sURL;
}
sub GetReferrer
{
return ($::g_sReferrer);
}
sub TrimHashEntries
{
my $pHash = $_[0];
my ($key, $value);
while ( ($key, $value) = each %$pHash)
{
$$pHash{$key} =~ s/^\s*(.*?)\s*$/$1/gs;
}
}
sub UUEncode
{
my ($sInput) = @_;
my $sOutput = "";
my ($i, $cByte, $nByteNo, $nLeftOver);
my @arrInput = unpack("C*", $sInput);
use integer;
my $sLookup = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
$nByteNo = 0;
foreach $cByte (@arrInput)
{
if($nByteNo == 0)
{
$sOutput .= substr($sLookup, ($cByte >> 2) & 63, 1);
$nLeftOver = ($cByte << 4) & 48;
$nByteNo++;
}
elsif($nByteNo == 1)
{
$sOutput .= substr($sLookup, $nLeftOver | (($cByte >> 4) & 15), 1);
$nLeftOver = ($cByte << 2) & 60;
$nByteNo++;
}
elsif($nByteNo == 2)
{
$sOutput .= substr($sLookup, $nLeftOver | (($cByte >> 6) & 3), 1);
$sOutput .= substr($sLookup, $cByte & 63, 1);
$nByteNo = 0;
}
}
if($nByteNo == 1)
{
$sOutput .= substr($sLookup, $nLeftOver, 1);
$sOutput .= '==';
}
elsif($nByteNo == 2)
{
$sOutput .= substr($sLookup, $nLeftOver, 1);
$sOutput .= '=';
}
return($sOutput);
}
sub SplitString
{
my ($sText, $nWidth, $sDelimiter) = @_;
my ($sOutput, $sTemp, $nStart, $nIndex);
$nStart = 0;
while($sText ne '')
{
$sTemp = substr($sText, 0, $nWidth + 1);
if($sTemp =~ / $/)
{
$sTemp =~ s/ $//;
$nStart = $nWidth + 1;
}
else
{
if(length($sTemp) <= $nWidth)
{
$sOutput .= $sTemp;
last;
}
$nIndex = rindex($sTemp, ' ');
if($nIndex == -1)
{
$sOutput .= $sTemp;
last;
}
$sTemp = substr($sTemp, 0, $nIndex);
$nStart = $nIndex + 1;
}
$sText = substr($sText, $nStart);
$sOutput .= $sTemp . $sDelimiter;
}
return($sOutput);
}
sub ProcessEscapableText
{
my ($sString) = @_;
my (@Response);
if ($sString !~ /!!</)
{
return (EncodeText($sString));
}
my $sNewString = '';
while ( $sString =~	m/(.*?)!!<(.*?)>!!(.*)/s )
{
@Response = EncodeText($1);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sNewString .= $Response[1] . $2;               # encode text + raw HTML
$sString = $3;
}
@Response = EncodeText($sString);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
$sNewString .= $Response[1];
return ($::SUCCESS, $sNewString, 0, 0);
}
sub EncodeText2
{
my @Response = EncodeText(@_);
return ($Response[1]);
}
sub EncodeText
{
my ($sString, $bHtmlEncoding, $bNBSP) = @_;
if (!defined $bHtmlEncoding)
{
$bHtmlEncoding = $::TRUE;
}
if (!defined $bNBSP)
{
$bNBSP = $::FALSE;
}
if ($bHtmlEncoding)
{
$sString =~ s/(\W)/sprintf('&#%d;', ord($1))/eg;
}
else
{
$sString =~ s/(\W)/sprintf('%%%2.2x', ord($1))/eg;
}
if ($bNBSP)
{
$sString =~ s/&#32;/&nbsp;/g;
}
return ($::SUCCESS, $sString, 0, 0);
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
else
{
}
return ($sString);
}
sub DecodeXOREncryption
{
my ($sOriginal, $sPassword) = @_;
my $sDest;
my $cOrigChar;
my $cChar;
my $nPwLen = length($sPassword);
my $nCount = 0;
my @aASCII = split(/ /, $sOriginal);
my $nASCII;
foreach $nASCII (@aASCII)
{
my $nIdx = ($nCount % $nPwLen);
$cChar = substr($sPassword, $nIdx, 1);
$cOrigChar = chr($nASCII);
$sDest .= chr(ord($cOrigChar) ^ ord($cChar));
$nCount++;
}
return($sDest);
}
sub TemplateFile
{
my ($sFilename, $pVariableTable, $bBinmode);
($sFilename, $pVariableTable, $bBinmode) = @_;
unless (open (TFFILE, "<$sFilename"))
{
return($::FAILURE, GetPhrase(-1, 21, $sFilename, $!), '', 0);
}
if (defined $bBinmode &&
$bBinmode == $::TRUE)
{
binmode TFFILE;
}
my ($sOutput);
{
local $/;
$sOutput = <TFFILE>;
}
close (TFFILE);
return (TemplateString($sOutput, $pVariableTable));
}
sub TemplateString
{
my ($sString, $pVariableTable);
($sString, $pVariableTable) = @_;
my ($key, $value);
my @aSortedKeys = sort {length $b <=> length $a} keys %$pVariableTable;
foreach $key (@aSortedKeys)
{
$value = $pVariableTable->{$key};
if ($key ne '')
{
$sString =~ s/$key/$value/isg;
}
}
return ($::SUCCESS, '', $sString, 0);
}
sub ReturnToLastPage
{
if ($_[1] ne '')
{
return (ReturnToLastPageEnhanced(@_));
}
else
{
return (ReturnToLastPagePlain(@_));
}
}
sub GroomError
{
if ($#_ != 0)
{
return (GroomError(ACTINIC::GetPhrase(-1, 12, 'GroomError')));
}
my ($sError) = @_;
my $sMessage;
if ($sError eq "")
{
return ($sError);
}
$sMessage = ACTINIC::GetPhrase(-1,1971, $::g_sErrorColor) . $sError . ACTINIC::GetPhrase(-1,1970);
$sError = ACTINIC::GetPhrase(-1,2178, $$::g_pSetupBlob{FORM_BACKGROUND_COLOR}, $sMessage);
$sError .= ACTINIC::GetPhrase(-1,2180);
return ($sError);
}
sub GroomHTML
{
my ($sHTML, $sMessage, $sScriptName);
my ($pInputHash, $temp, $sTitle, $pSetupBlob, $sWebSiteUrl, $sContentUrl);
($sMessage, $sTitle, $sWebSiteUrl, $sContentUrl, $pSetupBlob, $pInputHash) = @_;
my ($sPath, @Response, $Status, $Message);
$sPath = GetPath();
my (%VariableTable);
$VariableTable{$::VARPREFIX."BOUNCETITLE"} = $sTitle;
$VariableTable{$::VARPREFIX."BOUNCEMESSAGE"} = $sMessage;
@Response = TemplateFile($sPath."bounce.html", \%VariableTable);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
if( !$ACTINIC::B2B->Get('UserDigest') )
{
@Response = ACTINIC::MakeLinksAbsolute($sHTML, $::g_sWebSiteUrl, $::g_sContentUrl);
}
else
{
my $sBaseFile = $ACTINIC::B2B->Get('BaseFile');
my $smPath = ($sBaseFile) ? $sBaseFile : $::g_sContentUrl;
my $sCgiUrl = $::g_sAccountScript;
$sCgiUrl   .= ($::g_InputHash{SHOP} ? '?SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) . '&': '?');
$sCgiUrl   .= 'PRODUCTPAGE=';
@Response = ACTINIC::MakeLinksAbsolute($sHTML, $sCgiUrl, $smPath);
}
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
return ($::SUCCESS, '', $sHTML, 0);
}
sub ReturnToLastPagePlain
{
my ($sHTML, $nDelay, $sMessage, $sRefPage, $sScriptName, %InputHash, $temp, $sWebSiteUrl, $sContentUrl, $pSetupBlob);
($nDelay, $sMessage, $temp, $sWebSiteUrl, $sContentUrl, $pSetupBlob, %InputHash) = @_;
$sRefPage = $::Session->GetLastShopPage();
return (BounceToPagePlain($nDelay, $sMessage, $temp,
$sWebSiteUrl, $sContentUrl, $pSetupBlob, $sRefPage, \%InputHash));
}
sub BounceToPagePlain
{
my ($sHTML, $nDelay, $sMessage, $sRefPage, $sScriptName, $pInputHash);
my ($temp, $sWebSiteUrl, $sContentUrl, $pSetupBlob, $bClearFrames);
my $sReferrer;
($nDelay, $sMessage, $temp, $sWebSiteUrl, $sContentUrl, $pSetupBlob, $sRefPage, $pInputHash, $bClearFrames) = @_;
my ($sDigest,$sBaseFile) = ACTINIC::CaccGetCookies();
if( !$sDigest )
{
$sWebSiteUrl = $sContentUrl;
}
else
{
$sWebSiteUrl = $sBaseFile;
$sWebSiteUrl =~ s#/[^/]*$#/#;
}
if ($$::g_pSetupBlob{'SSL_USEAGE'} == "1" &&
defined $ENV{HTTPS} &&
$ENV{HTTPS} =~ /on/i)
{
$sWebSiteUrl = $$::g_pSetupBlob{'SSL_CATALOG_URL'};
}
if ($sRefPage eq '')
{
$sHTML = "<HTML>\n";
$sHTML .= "<BODY";
my ($bBgIsImage, $sBgImageFileName, $sBgColor) = GetPageBackgroundInfo();
if ($bBgIsImage &&
length $sBgImageFileName > 0)
{
$sHTML .= " BACKGROUND=\"" . $sWebSiteUrl . $sBgImageFileName . "\"";
}
elsif (length $sBgColor > 0)
{
$sHTML .= " BGCOLOR=\"" . $sBgColor . "\"";
}
if (length $$pSetupBlob{'FOREGROUND_COLOR'} > 0)
{
$sHTML .= " TEXT=\"" . $$pSetupBlob{'FOREGROUND_COLOR'} . "\""
}
if (length $$pSetupBlob{'LINK_COLOR'} > 0)
{
$sHTML .= " LINK=\"" . $$pSetupBlob{'LINK_COLOR'} . "\""
}
if (length $$pSetupBlob{'ALINK_COLOR'} > 0)
{
$sHTML .= " ALINK=\"" . $$pSetupBlob{'ALINK_COLOR'} . "\""
}
if (length $$pSetupBlob{'VLINK_COLOR'} > 0)
{
$sHTML .= " VLINK=\"" . $$pSetupBlob{'VLINK_COLOR'} . "\""
}
$sHTML .= "><BLOCKQUOTE>\n";
$sHTML .= $sMessage."<P>\n";
$sHTML .= GetPhrase(-1, 22) . "<BR></BLOCKQUOTE>\n";
}
else
{
$sHTML = "<HTML><HEAD>\n";
if( $sRefPage =~ /\?/ )
{
my $sBefore = "$`\?";
my $sAfter = "\&$'";
if (($nDelay >= 0) &&
(!IsStaticPage($sAfter)) &&
($sAfter !~ /ACTINIC_REFERRER/))
{
$sReferrer = "&ACTINIC_REFERRER=" . ACTINIC::EncodeText2(GetReferrer(),$::FALSE);
}
if( ACTINIC::IsCatalogFramed() &&
$sBefore =~ /$::g_sAccountScriptName/) # Catalog is framed and the business script is called, so we have to care about the framenavbar
{
my ($sProductPage, $sAnchor);
if ($sAfter =~ /(\?|\&)REFPAGE=\"?(.*?)(\#[a-zA-Z0-9\-_]+)?(\"|&|$)/)
{
$sAnchor = $3;
$sProductPage = $2;
$sAfter =~ s/(\?|\&)REFPAGE=\"?$sProductPage$sAnchor\"?//;
}
if ($sAfter =~ /(\?|\&)PRODUCTPAGE=\"?(.*?)(\#[a-zA-Z0-9\-_]+)?(\"|&|$)/)
{
$sAnchor = $3;
$sProductPage = $2;
$sAfter =~ s/(\?|\&)PRODUCTPAGE=\"?$sProductPage$sAnchor\"?//;
}
if ($sAfter =~ /(\?|\&)MAINFRAMEURL=\"?(.*?)(\#[a-zA-Z0-9\-_]+)?(\"|&|$)/)
{
$sAnchor = $3;
$sProductPage = $2;
$sAfter =~ s/(\?|\&)MAINFRAMEURL=\"?$sProductPage$sAnchor\"?//;
}
$sAfter =~ s/^\?/&/;
my $sOtherParams = $sAfter . $sReferrer . $sAnchor;
if (!$$pSetupBlob{'UNFRAMED_CHECKOUT'} == 1)
{
$sRefPage = $sBefore . 'PRODUCTPAGE=' . $sProductPage . $sOtherParams;
}
else
{
$sRefPage = $sBefore . 'MAINFRAMEURL=' . $sProductPage . "&PRODUCTPAGE=" . $$::g_pSetupBlob{'FRAMESET_PAGE'} . $sOtherParams;
}
}
if( ACTINIC::IsCatalogFramed() &&
$$::g_pSetupBlob{UNFRAMED_CHECKOUT} &&
$sBefore !~ /$::g_sAccountScriptName/)
{
$bClearFrames = 1;
}
if( $$pInputHash{MAINFRAMEURL} )
{
$sRefPage = $sBefore . 'MAINFRAMEURL=' . $$pInputHash{MAINFRAMEURL} . $sAfter . $sReferrer;
}
elsif( $$pInputHash{BASE}  )
{
$sRefPage = $sBefore . 'BASE=' . $$pInputHash{BASE} . $sAfter . $sReferrer;
}
}
if ($nDelay >= 0)
{
my $sMetaTag;
my $sReferrer = ACTINIC::GetReferrer();
if (!IsStaticPage($sRefPage) &&
$sRefPage !~ /ACTINIC_REFERRER/)
{
$sRefPage .= "&ACTINIC_REFERRER=" . ACTINIC::EncodeText2($sReferrer,$::FALSE);
}
if ($bClearFrames)
{
my $sTarget = $$::g_pSetupBlob{CLEAR_ALL_FRAMES} ? "top" : "parent";
$sMetaTag =
"<SCRIPT LANGUAGE=\"JAVASCRIPT\">\n" .
"<!-- hide from older browsers\n" .
"setTimeout(\"ForwardPage()\", " . 1000 * $nDelay . ");\n" .
"function ForwardPage()\n" .
"	{\n" .
"	var sURL = '$sRefPage';\n" .
"	$sTarget.location.replace(sURL);\n" .
"	}\n" .
"// -->\n" .
"</SCRIPT>\n";
}
else
{
$sMetaTag = "<META HTTP-EQUIV=\"refresh\" ";
$sMetaTag .= "CONTENT=\"$nDelay; URL=".$sRefPage."\">\n";
$sMetaTag .=
"<SCRIPT LANGUAGE=\"JAVASCRIPT\">\n" .
"<!-- hide from older browsers\n" .
"setTimeout(\"ForwardPage()\", " . 1000 * ($nDelay+1) . ");\n" .
"function ForwardPage()\n" .
"	{\n" .
"	var sURL = '$sRefPage';\n" .
"	location.replace(sURL);\n" .
"	}\n" .
"// -->\n" .
"</SCRIPT>\n";
}
$sHTML .= $sMetaTag;
}
$sHTML .= "</HEAD><BODY";
my ($bBgIsImage, $sBgImageFileName, $sBgColor) = GetPageBackgroundInfo();
if ($bBgIsImage &&
length $sBgImageFileName > 0)
{
$sHTML .= " BACKGROUND=\"" . $sWebSiteUrl . $sBgImageFileName . "\"";
}
elsif (length $sBgColor > 0)
{
$sHTML .= " BGCOLOR=\"" . $sBgColor . "\"";
}
if (length $$pSetupBlob{'FOREGROUND_COLOR'} > 0)
{
$sHTML .= " TEXT=\"" . $$pSetupBlob{'FOREGROUND_COLOR'} . "\""
}
if (length $$pSetupBlob{'LINK_COLOR'} > 0)
{
$sHTML .= " LINK=\"" . $$pSetupBlob{'LINK_COLOR'} . "\""
}
if (length $$pSetupBlob{'ALINK_COLOR'} > 0)
{
$sHTML .= " ALINK=\"" . $$pSetupBlob{'ALINK_COLOR'} . "\""
}
if (length $$pSetupBlob{'VLINK_COLOR'} > 0)
{
$sHTML .= " VLINK=\"" . $$pSetupBlob{'VLINK_COLOR'} . "\""
}
$sHTML .= "><BLOCKQUOTE>\n";
$sHTML .= $sMessage."<P>\n";
my $sBounceSentence;
if ($nDelay >= 0)
{
$sBounceSentence = GetPhrase(-1, 23, $sRefPage) . "\n";
}
else
{
$sBounceSentence = GetPhrase(-1, 161, $sRefPage) . "\n";
}
if ($bClearFrames)
{
$sBounceSentence =~ s/(HREF=)/TARGET="_parent" $1/i;
}
$sHTML .= "<NOSCRIPT>" . $sBounceSentence . "</NOSCRIPT><BLOCKQUOTE>";
}
$sHTML .= "</BODY>\n</HTML>\n";
return ($::SUCCESS, '', $sHTML, 0);
}
sub GetPageBackgroundInfo
{
my ($bIsBgColorFlagDefined, $bIsBgColorUsed) = ACTINIC::IsCustomVarDefined( 'IsBackgroundColor' );
my ($bIsBgImageDefined, $sBgImageFileName) = ACTINIC::IsCustomVarDefined( 'BackgroundImageFileName' );
my $bBgIsImage = (($bIsBgImageDefined && (length $sBgImageFileName > 0)) &&
($bIsBgColorFlagDefined && !$bIsBgColorUsed));
return ($bBgIsImage, $sBgImageFileName, $$::g_pSetupBlob{'BACKGROUND_COLOR'});
}
sub ReturnToLastPageEnhanced
{
my (%InputHash, $sTitle, $sMessage, $pSetupBlob, $sContentUrl, $sWebSiteUrl, $sRefPage, $nDelay);
($nDelay, $sMessage, $sTitle, $sWebSiteUrl, $sContentUrl, $pSetupBlob, %InputHash) = @_;
$sRefPage = $::Session->GetLastShopPage();
return (BounceToPageEnhanced($nDelay, $sMessage, $sTitle,
$sWebSiteUrl, $sContentUrl, $pSetupBlob, $sRefPage, \%InputHash));
}
sub RestoreFrameURL
{
my ($sUrl) = @_;
if (IsPartOfFrameset())
{
return ($sUrl);
}
if ($$::g_pSetupBlob{CLEAR_ALL_FRAMES} &&
$$::g_pSetupBlob{UNFRAMED_CHECKOUT_URL})
{
return ($$::g_pSetupBlob{UNFRAMED_CHECKOUT_URL});
}
if (!IsCatalogFramed())
{
return ($sUrl);
}
if (IsStaticPage($sUrl))
{
if (($sUrl =~ /\/$$::g_pSetupBlob{'FRAMESET_PAGE'}/) ||
($sUrl =~ /\/$$::g_pSetupBlob{'B2B_LOGONPAGE'}/))
{
return ($sUrl);
}
else
{
$sUrl =~ s/.*\/([^\/\=]+$)/$1/;
if ($sUrl eq $$::g_pSetupBlob{CATALOG_PAGE})
{
$sUrl = $::Session->GetBaseUrl() . $$::g_pSetupBlob{FRAMESET_PAGE};
}
else
{
$sUrl = $::Session->GetBaseUrl() . $$::g_pSetupBlob{FRAMESET_PAGE} . "?" . $sUrl . "&CatalogBody";
}
return ($sUrl);
}
}
my ($sBefore, $sAfter) = split(/\?/, $sUrl);
if ($sBefore !~ /$::g_sAccountScriptName/)
{
return ($sUrl);
}
if ($sAfter eq "")
{
my ($sBodyPage, $sProductPage) = ACTINIC::CAccCatalogBody();
return("MAINFRAMEURL=$sBodyPage" . "&PRODUCTPAGE=$sProductPage");
}
$sAfter = "&" . $sAfter;
if ($sAfter =~ /&MAINFRAMEURL=/)
{
return ($sUrl);
}
my ($sProductPage, $sAnchor);
if ($sAfter =~ s/&REFPAGE=\"?(.*?)(\#[a-zA-Z0-9\-_]+)?(\".*|&.*|$)/$3/)
{
$sAnchor = $2;
$sProductPage = $1;
}
if ($sAfter =~ s/&PRODUCTPAGE=\"?(.*?)(\#[a-zA-Z0-9\-_]+)?(\".*|&.*|$)/$3/)
{
$sAnchor = $2;
$sProductPage = $1;
}
if ($sAfter !~ /&ACTINIC_REFERRER=/)
{
$sAfter .= "&ACTINIC_REFERRER=" . ACTINIC::EncodeText2(ACTINIC::GetReferrer(),$::FALSE);
}
$sUrl = $sBefore . '?MAINFRAMEURL=' . $sProductPage . "&PRODUCTPAGE=" . $$::g_pSetupBlob{'FRAMESET_PAGE'} . $sAfter . $sAnchor;
return ($sUrl);
}
sub BounceToPageEnhanced
{
my ($sHTML, $nDelay, $sMessage, $sScriptName);
my ($pInputHash, $temp, $sTitle, $sMetaTag, $pSetupBlob, $sWebSiteUrl, $sContentUrl, $sRefPage, $bClearFrames);
($nDelay, $sMessage, $sTitle, $sWebSiteUrl, $sContentUrl, $pSetupBlob, , $sRefPage, $pInputHash, $bClearFrames) = @_;
if( !IsPartOfFrameset() )
{
$bClearFrames = $::FALSE;
}
if ($sRefPage eq '')
{
$sMessage .= "<P>\n";
$sMessage .= GetPhrase(-1, 22) . "<BR>\n";
$sMetaTag = '';
}
else
{
if( $sRefPage =~ /\?/ )
{
my $sBefore = "$`\?";
my $sAfter = "\&$'";
if( ACTINIC::IsCatalogFramed() and
!$$::g_pSetupBlob{UNFRAMED_CHECKOUT} )
{
$sRefPage =~ s/(PRODUCTPAGE\=\"?)$$::g_pSetupBlob{FRAMESET_PAGE}(\"?)/$1$$::g_pSetupBlob{'CATALOG_PAGE'}$2/;
}
$sBefore = "$`\?";
$sAfter = "\&$'";
if( $$pInputHash{MAINFRAMEURL} )
{
$sRefPage = $sBefore . 'MAINFRAMEURL=' . $$pInputHash{MAINFRAMEURL} . $sAfter;
}
elsif( $$pInputHash{BASE}  )
{
$sRefPage = $sBefore . 'BASE=' . $$pInputHash{BASE} . $sAfter;
}
}
if ($nDelay >= 0)
{
if ($bClearFrames)
{
my $sTarget = $$::g_pSetupBlob{CLEAR_ALL_FRAMES} ? "top" : "parent";
$sMetaTag =
"<SCRIPT LANGUAGE=\"JAVASCRIPT\">\n" .
"<!-- hide from older browsers\n" .
"setTimeout(\"ForwardPage()\", " . 1000 * $nDelay . ");\n" .
"function ForwardPage()\n" .
"	{\n" .
"	$sTarget.location.replace('$sRefPage');\n" .
"	}\n" .
"// -->\n" .
"</SCRIPT>\n";
}
else
{
$sMetaTag = "<META HTTP-EQUIV=\"refresh\" ";
$sMetaTag .= "CONTENT=\"$nDelay; URL=".$sRefPage."\">\n";
}
}
$sMessage .= "<P>\n";
my $sBounceSentence;
if ($nDelay >= 0)
{
$sBounceSentence = GetPhrase(-1, 23, $sRefPage) . "\n";
}
else
{
$sBounceSentence = GetPhrase(-1, 161, $sRefPage) . "\n";
}
if ($bClearFrames)
{
my $sTarget = $$::g_pSetupBlob{CLEAR_ALL_FRAMES} ? "_top" : "_parent";
$sBounceSentence =~ s/(HREF=)/TARGET="$sTarget" $1/i;
}
$sMessage .= $sBounceSentence;
}
my ($sPath, @Response, $Status, $Message);
$sPath = GetPath();
my (%VariableTable);
$VariableTable{$::VARPREFIX."BOUNCETITLE"} = $sTitle;
$VariableTable{$::VARPREFIX."BOUNCEMESSAGE"} = $sMessage;
@Response = TemplateFile($sPath."bounce.html", \%VariableTable);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
my $smPath = $sContentUrl;
my $sCgiUrl = $sWebSiteUrl;
my ($sDigest,$sBaseFile) = ACTINIC::CaccGetCookies();
if( $sDigest )
{
$smPath = ($sBaseFile) ? $sBaseFile : $sContentUrl;
$sCgiUrl = $::g_sAccountScript;
$sCgiUrl   .= $::g_InputHash{SHOP} ? '?SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) . '&' : '?';
$sCgiUrl   .= 'PRODUCTPAGE=';
}
@Response = MakeLinksAbsolute($sHTML, $sCgiUrl, $smPath);
($Status, $Message, $sHTML) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
my ($sSearchTag, $sReplaceTag);
$sSearchTag = '</TITLE>';
$sReplaceTag = $sSearchTag . "\n" . $sMetaTag;
$sHTML =~ s/$sSearchTag/$sReplaceTag/ig;
return ($::SUCCESS, '', $sHTML, 0);
}
sub UpdateDisplay
{
my ($sHTML, $OriginalInputData, $sCookie, $bNoCacheFlag, $sContactDetailsCookie, $sCartCookie) = @_;
if (!defined $sCookie)
{
$sCookie = '';
}
if (!defined $bNoCacheFlag)
{
$bNoCacheFlag = $::TRUE;
}
my ($sSearch, $sReplace, $sPageHistory);
$sSearch = $::VARPREFIX."REFPAGE";
$sPageHistory = $::Session->GetLastShopPage() ;
$sReplace = "<INPUT TYPE=HIDDEN NAME=REFPAGE VALUE=\"$sPageHistory\">\n" ;
$sHTML =~ s/$sSearch/$sReplace/;
my ($sTemp, $sEncodedRef) = ACTINIC::EncodeText($sPageHistory, $::FALSE);
if (($$::g_pSetupBlob{SSL_USEAGE} == 1) &&
($sPageHistory !~ /(\?|&)ACTINIC_REFERRER=/))
{
$sEncodedRef .= "&ACTINIC_REFERRER=" . EncodeText2(GetReferrer(), $::FALSE);
}
$sHTML =~ s/(\?ACTION=[^'"]+)/$1&REFPAGE=$sEncodedRef/gi;
$sHTML =~ s/(<FORM\sNAME\s*=\s*simplesearch[^>]*>)/$1$sReplace/gi;
my $sURL = ACTINIC::EncodeText2($::Session->GetLastShopPage(), $::FALSE);
$sHTML =~ s/(['"]\&ACTINIC_REFERRER\=["']\s*\+)\s*escape\(location\.href\)/$1\'$sURL\'/;
srand();
my ($Random) = rand();
$sHTML =~ s/NETQUOTEVAR:RANDOM/$Random/g;
SaveSessionAndPrintPage($sHTML, $sCookie, $bNoCacheFlag, $sContactDetailsCookie, $::FALSE, $sCartCookie);
}
sub PrintNonParsedHeader
{
$|=1;
print "Content-type: " . $_[0] . "\n";
print $::ENV{SERVER_PROTOCOL} . " 200 OK\n";
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
}
sub PrintHeader
{
my ($sType, $nLength, $sCookie, $bNoCache, $sContactDetailsCookie, $sCartCookie) = @_;
my $sNow = GenerateCookieDate();
my $sExpiry = GenerateCookieDate(2 * 365 * 24);
my $nCartExpiryOffset = 28;
if ($$::g_pSetupBlob{'CART_EXPIRY'})
{
$nCartExpiryOffset = $$::g_pSetupBlob{'CART_EXPIRY'};
};
my $sCartExpiry = GenerateCookieDate($nCartExpiryOffset);
my $sSessionIdExpiry = $sCartExpiry;
if (!$ACTINIC::B2B->Get('UserDigest') &&
($$::g_pSetupBlob{'UNREG_SHOPPING_LIST'} == 1) &&
$::Session->{_NEWESTSAVEDCARTTIME})
{
my $nF = $::Session->{_NEWESTSAVEDCARTTIME} / (60 * 60);
my $nN = time / (60 * 60);
my $nS = ($nF + ($$::g_pSetupBlob{'UNREG_SHOPPING_LIST_EXPIRY'} * 24));
if (($nS - $nN) > $sCartExpiry)
{
$sSessionIdExpiry = GenerateCookieDate($nS - $nN);
}
}
my $bCookieIsSent = $::FALSE;
my ($sCurrentCookie);
if ((!$ACTINIC::AssertIsActive) &&
(defined $::Session))
{
$sCurrentCookie = $::Session->{_OLDSESSIONID};
}
my $bCookie = (length $sCookie > 0);
if($ENV{'PerlXS'} eq 'PerlIS')
{
print "HTTP/1.0 200 OK\n";
}
print "Content-type: $sType\r\n";
print "Content-length: $nLength\r\n";
print "Date: $sNow\r\n";
if ($bNoCache)
{
print "Cache-Control: no-cache\r\n";
print "Pragma: no-cache\r\n";
}
if (defined $::g_InputHash{'COOKIE'})
{
$bCookie = $::TRUE;
$sCookie = $sCurrentCookie;
}
if ($bCookie)
{
print "Set-Cookie: ACTINIC_CART=" .
$sCookie . "; EXPIRES=" .
$sSessionIdExpiry . "; PATH=/;\r\n";
$bCookieIsSent = $::TRUE;
}
if (!$ACTINIC::AssertIsActive)
{
my $sBusinessCookie = ACTINIC::CAccBusinessCookie();
if ($sBusinessCookie eq "-" and $sContactDetailsCookie)
{
print "Set-Cookie: " . $sContactDetailsCookie .
"; EXPIRES=" . $sExpiry . "; PATH=/;\r\n";
$bCookieIsSent = $::TRUE;
}
else
{
print "Set-Cookie: ACTINIC_BUSINESS=" . $sBusinessCookie .
"; PATH=/;\r\n";
$bCookieIsSent = $::TRUE;
}
if ($::ACT_ADB)
{
print $::ACT_ADB->Header();
$bCookieIsSent = $::TRUE;
}
}
if ($sCartCookie ne '')
{
print "Set-Cookie: " . $sCartCookie .
"; EXPIRES=" . $sCartExpiry .
"; PATH=/;\r\n";
$bCookieIsSent = $::TRUE;
}
if ($bCookieIsSent &&
$$::g_pSetupBlob{P3P_COMPACT_POLICY})
{
print "P3P: CP=\"" . $$::g_pSetupBlob{P3P_COMPACT_POLICY} . "\"\r\n";
}
print "\r\n";
}
sub GenerateCookieDate
{
my $offset = shift;
if (!$offset)
{
$offset = 0;
}
my (@date, $day, $month, $now, $later, $sDate);
my (@days) = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
my (@months) = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
$now = time;
$later = $now + $offset *3600;
@date = gmtime($later);
$day = $days[$date[6]];
$month = $months[$date[4]];
$sDate = sprintf("%s, %02d-%s-%04d %02d:%02d:%02d GMT", $day, $date[3],
$month, $date[5]+1900, $date[2], $date[1], $date[0]);
return $sDate;
}
sub SaveSessionAndPrintPage
{
my ($sHTML, $sCookie, $bNoCacheFlag, $sContactDetailsCookie, $bSkipXMLParsing, $sCartCookie) = @_;
$::Session->SaveSession();
PrintPage($sHTML, $::Session->GetSessionID(), $bNoCacheFlag, $sContactDetailsCookie, $bSkipXMLParsing, $sCartCookie);
}
sub PrintPage
{
if ($::s_nErrorRecursionCounter > 10)
{
$ACTINIC::AssertIsActive = $::TRUE;
}
$::s_nErrorRecursionCounter++;
my $nLength;
my ($sHTML, $sNotUsed, $bNoCacheFlag, $sContactDetailsCookie, $bSkipXMLParsing, $sCartCookie) = @_;
my $sCookie = "";
if (defined $::Session)
{
$sCookie = $::Session->GetSessionID();
}
if (!$ACTINIC::AssertIsActive &&
!$bSkipXMLParsing)
{
$sHTML = ACTINIC::ParseXML($sHTML);
}
$nLength = length $sHTML;
if (!defined $bNoCacheFlag)
{
$bNoCacheFlag = $::TRUE;
}
binmode STDOUT;
PrintHeader('text/html', $nLength, $sCookie, $bNoCacheFlag, $sContactDetailsCookie, $sCartCookie);
print $sHTML;
}
sub PrintText
{
my $sText = $_[0];
my $nLength = length $sText;
binmode STDOUT;
PrintHeader('text/plain', $nLength, undef, $::FALSE);
print $sText;
}
sub ReportError
{
my ($sMessage, $sPath);
($sMessage, $sPath) = @_;
RecordErrors(@_);
TerminalError($_[0]);
}
sub RecordErrors
{
my ($sMessage, $sPath);
($sMessage, $sPath) = @_;
my ($sPad, $sFile);
$sPad = " "x100;
$sFile = $sPath."error.err";
SecurePath($sFile);
open(NQFILE, ">>".$sFile);
print NQFILE ("Program = ");
print NQFILE (substr($::prog_name.$sPad,0,8));
print NQFILE (", Program version = ");
print NQFILE (substr($::prog_ver.$sPad,0,6));
print NQFILE (", HTTP Server = ");
print NQFILE (substr($::ENV{'SERVER_SOFTWARE'}.$sPad,0,30));
print NQFILE (", Return code = ");
print NQFILE (substr("999".$sPad,0,20));
print NQFILE (", Date and Time = ");
print NQFILE ACTINIC::GetActinicDate();
print NQFILE (", Internal Errors = ");
print NQFILE ($sMessage);
print NQFILE "\n";
close NQFILE;
ChangeAccess("rw", $sFile);
}
sub TerminalError
{
my ($sError, $sHTML);
($sError) = @_;
$sHTML  = "<HTML><TITLE>Actinic</TITLE><BODY>";
if (defined $::g_pPromptList)
{
$sHTML .= "<H1>" . GetPhrase(-1, 24) . "</H1>";
$sHTML .= "<HR>" . GetPhrase(-1, 25) . ": $sError<HR>";
$sHTML .= GetPhrase(-1, 26);
}
else
{
$sHTML .= "<H1>" . "A General Script Error Occurred" . "</H1>";
$sHTML .= "<HR>" . "Error" . ": $sError<HR>";
$sHTML .= "Press the Browser back button and try again or contact the site owner.";
}
$sHTML .= "</BODY></HTML>";
$ACTINIC::AssertIsActive = $::TRUE;
PrintPage($sHTML, undef, $::TRUE);
exit;
}
sub LogData
{
my $sLogData = shift;
my $nDebugClass = shift;
if ($::DEBUG_CLASS_FILTER &
$nDebugClass)
{
ACTINIC::RecordErrors($sLogData, ACTINIC::GetPath());
}
}
sub MakeLinksAbsolute
{
my ($sHTML, $sWebSiteUrl, $sContentUrl, $Status, $Message, @Response);
($sHTML, $sWebSiteUrl, $sContentUrl) = @_;
$sHTML =~ s/<A([^>]*?)HREF=(['"])?(?!http(s?):|mailto:|ftp:|#|\/|javascript:)([^'"\s]+)(['"\s])/<A$1HREF=$2$sWebSiteUrl$3$4$5/gi;
$sHTML =~ s/<FRAME([^>]*?)SRC=(['"])?(?!http(s?):|mailto:|ftp:|#)([^'"\/][^'"\s]+)(["\s])/<FRAME$1SRC=$2$sWebSiteUrl$3$4$5/gi;
$sHTML = MakeExtendedInfoLinksAbsolute($sHTML, $sWebSiteUrl);
return ($::SUCCESS, '', $sHTML);
}
sub MakeExtendedInfoLinksAbsolute
{
my ($sSearch, $sHTML, $sWebSiteUrl);
($sHTML, $sWebSiteUrl) = @_;
$sSearch = ACTINIC::GetPhrase(-1, 2175);
$sSearch =~ s/(.*\().*$/$1/;
$sSearch = quotemeta $sSearch;
$sHTML =~ s/=(["']$sSearch['"])([^'"\s]+)/=$1$sWebSiteUrl$2$3/gi;
return ($sHTML);
}
sub GetScriptNameRegexp
{
my (@ScriptPathParts) = split /(\\|\/)/, $::ENV{"SCRIPT_NAME"};
my ($sScriptBase);
$sScriptBase = substr($ScriptPathParts[$#ScriptPathParts], 2);
return ("(ca|os|nq|ts|cp|ss|sh|bb|md|cm|ms|se|rs)$sScriptBase");
}
sub GetStaticPageRegexp
{
return ("(\.((s?)html|htm|js|php(3?)|css|vrml|asp|cfm))\$|(\/\$)");
}
sub IsStaticPage
{
my ($sURL) = @_;
if ($sURL =~ /(\?|\#)/)
{
$sURL = $`;
}
if ($sURL =~ /\%[0-9A-Fa-f]{2}/)
{
$sURL = DecodeText($sURL, $ACTINIC::FORM_URL_ENCODED);
}
my $sRegExp = GetScriptNameRegexp();
my $sPageRegExp = GetStaticPageRegexp();
if( $sURL =~ /$sPageRegExp/i and $sURL !~ /$sRegExp/ )
{
return ($::TRUE);
}
return ($::FALSE);
}
sub IsFramePage
{
my ($sPageName) = @_;
if ($sPageName =~ /\%[0-9A-Fa-f]{2}/)
{
$sPageName = DecodeText($sPageName, $ACTINIC::FORM_URL_ENCODED);
}
my ($sRegExp);
my ($bCusFrame, $sCusFramePages) = ACTINIC::IsCustomVarDefined('ACT_CUSTOM_FRAME_PAGES');
if (IsCatalogFramed())
{
$sRegExp = "framenavbar.html|" . $$::g_pSetupBlob{FRAMESET_PAGE};
}
if ($bCusFrame)
{
$sCusFramePages = join("|", split(",", $sCusFramePages));
$sRegExp .= "|" . $sCusFramePages;
}
if( $sPageName =~ /$sRegExp/i)
{
return ($::TRUE);
}
return ($::FALSE);
}
sub Modulus
{
my ($nA, $nB) = @_;
my $nC = $nA - $nB * int($nA / $nB);
return($nC);
}
sub JoinHashes
{
my ($rhash1, $rhash2, $bOperation, $rhashOutput) = @_;
undef %$rhashOutput;
if ($bOperation == $::INTERSECT)					 # AND join (INTERSECTION)
{
foreach (keys %$rhash1)
{
$$rhashOutput{$_} = 0 if exists $$rhash2{$_};
}
}
else														 # OR join (UNION)
{
%$rhashOutput = %$rhash1;
foreach (keys %$rhash2)
{
$$rhashOutput{$_} = 0;
}
}
}
sub ReadTheDir
{
my ($sPath, @FileList);
($sPath) = @_;
SecurePath($sPath);
if( opendir (NQDIR, "$sPath") )
{
@FileList = readdir (NQDIR);
closedir (NQDIR);
return ($::SUCCESS, '', @FileList);
}
if ($^O ne "MSWin32")
{
return($::FAILURE, GetPhrase(-1, 31, $sPath, $!), 0, 0);
}
my ($sDosPath, $sCommand);
$sDosPath = $sPath;
$sDosPath =~ s/\//\\/g;
$sCommand = "dir /B \"$sDosPath\"";
unless (open (PIPE, $sCommand . " |"))
{
return($::FAILURE, GetPhrase(-1, 32, $sPath, $!), 0, 0);
}
@FileList = <PIPE>;
chomp @FileList;
close (PIPE);
if ($#FileList == 0 &&
$FileList[0] =~ m/File Not Found/i)
{
my ($sMessage);
$sMessage = $FileList[0];
return($::FAILURE, GetPhrase(-1, 32, $sPath, $sMessage), 0, 0);
}
return ($::SUCCESS, '', @FileList);
}
sub IsCatalogFramed
{
return($$::g_pSetupBlob{USE_FRAMES});
}
sub IsBrochureFramed
{
return($$::g_pSetupBlob{BROCHURE_USE_FRAMES});
}
sub CheckFileExists
{
my ($sFileName, $sPath);
($sFileName, $sPath) = @_;
my $sFile = $sPath . $sFileName;
return (-e $sFile && -r $sFile);
}
sub GetCatalogBasePageName
{
my ($sPath, $sBasePageName);
($sPath) = @_;
$sBasePageName = $$::g_pSetupBlob{CATALOG_PAGE};
return ($::SUCCESS, "", $sBasePageName);
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
if ($key !~ /BLOB/i)
{
if (($value =~ /[\(\)]/) ||
($value =~ /[<>]/))
{
return ($::FAILURE, "Input contains invalid characters.", undef, undef, undef, undef);
}
}
$key = DecodeText($key, $ACTINIC::FORM_URL_ENCODED);
$value = DecodeText($value, $ACTINIC::FORM_URL_ENCODED);
if ($key =~ /\0/)
{
return ($::FAILURE, "Input contains invalid characters.", undef, undef, undef, undef);
}
if ($key !~ /BLOB/i)
{
if ($value =~ /\0/)
{
return ($::FAILURE, "Input contains invalid characters.", undef, undef, undef, undef);
}
if ($key !~ /TEXTDATA/i)
{
if (($value =~ /.*?\((.*)\)/s) &&
($::eRBDataLimit < length $1))
{
while($value =~ s/(\()(.*?)(\))/\{$2\}/gs) {}
}
if (($value =~ /.*?\<(.*)\>/s) &&
($::eABDataLimit < length $1))
{
while($value =~ s/(\<)(.*?)(\>)/\[$2\]/gs) {}
}
}
}
$DecodedInput{$key} = $value;
}
my ($status, $sError) = ProcessPath($DecodedInput{SHOP}, \%DecodedInput);
if ($status != $::SUCCESS)
{
return ($status, $sError);
}
return ($::SUCCESS, '', $OriginalInputData, '', %DecodedInput);
}
sub ProcessPath
{
my ($sShopID, $rhInput) = @_;
my ($status, $sError);
my $sInitialPath = '../gk/acatalog/';
if (!$::FALSE)
{
$ACTINIC::s_sPath = $sInitialPath;
}
else
{
if ($sShopID eq '' &&
($$rhInput{ACTION} =~ /^AUTHORIZE/ || $$rhInput{ACTION} eq 'OCC_VALIDATE'))
{
if(defined $$rhInput{PATH} && $$rhInput{PATH} ne '')
{
$ACTINIC::s_sPath = $$rhInput{PATH};
return ($::SUCCESS, undef);
}
}
eval
{
require AHDClient;
};
if ($@)
{
return ($::FAILURE, 'An error occurred loading the AHDClient module.  ' . $@);
}
my ($nStatus, $pClient);
($nStatus, $sError, $pClient) = new_readonly AHDClient($sInitialPath);
if ($nStatus!= $::SUCCESS)
{
return($nStatus, $sError);
}
($status, $sError, my $pShop) = $pClient->GetShopDetails($sShopID);
if ($status != $::SUCCESS)
{
return ($status, $sError);
}
if (!defined($pShop))
{
return ($::BADDATA, $sError);
}
$ACTINIC::s_sPath = $pShop->{Path};
}
return ($::SUCCESS, undef);
}
sub CheckSafeFilePath
{
my ($sFilePath) = @_;
if ($sFilePath ne $$::g_pSetupBlob{'HOMEPAGEURL'})
{
if (($sFilePath =~ /\//) ||
($sFilePath =~ /\\/))
{
ReportError(ACTINIC::GetPhrase(-1,2248, $sFilePath), GetPath());
}
}
}
sub GetSectionBlobName
{
if ($_[0] !~ /^(\d+)$/)
{
return ($::FAILURE, GetPhrase(-1, 306));
}
my $nID = $1;
return ($::SUCCESS, undef, sprintf('A000%d.cat', $nID));
}
sub GetHierarchicalCustomVar
{
my ($pProduct, $sCustomVar, $sSectionBlobName) = @_;
if (defined $pProduct->{'CUSTOMVARS'}{$sCustomVar})
{
return ($pProduct->{'CUSTOMVARS'}{$sCustomVar});
}
my ($nStatus, $sMessage, $rhashSection);
($nStatus, $sMessage, $rhashSection) = GetSectionHash($sSectionBlobName);
if ($nStatus == $::FAILURE)
{
ACTINIC::ReportError($sMessage, GetPath());
}
if (defined ${$rhashSection->{'CUSTOMVARS'}}{$sCustomVar})
{
return ($rhashSection->{'CUSTOMVARS'}{$sCustomVar});
}
my $nSectionID;
foreach $nSectionID (@{$rhashSection->{'PARENT_SECTIONS'}})
{
($nStatus, $sMessage, $sSectionBlobName) = ACTINIC::GetSectionBlobName($nSectionID);
if ($nStatus == $::FAILURE)
{
ACTINIC::ReportError($sMessage, GetPath());
}
($nStatus, $sMessage, $rhashSection) = GetSectionHash($sSectionBlobName);
if ($nStatus == $::FAILURE)
{
ACTINIC::ReportError($sMessage, GetPath());
}
if (defined $rhashSection->{'CUSTOMVARS'}{$sCustomVar})
{
return ($rhashSection->{'CUSTOMVARS'}{$sCustomVar});
}
}
my $sValue;
($nStatus, $sValue) = IsCustomVarDefined($sCustomVar);
if ($nStatus)
{
return ($sValue);
}
return ('??????');
}
sub ParseOnlinePriceTemplate
{
my ($sPriceTemplate) = @_;
$sPriceTemplate =~ s/%0d\s*//g;
$sPriceTemplate = ACTINIC::DecodeText($sPriceTemplate, $ACTINIC::FORM_URL_ENCODED);
my (undef, $ptreePriceTemplate) = ACTINIC::PreProcessXMLTemplateString($sPriceTemplate);
my $elemAll = $ptreePriceTemplate->[0];
my $elemOnlinePrices = ($elemAll->GetTag() eq 'OnlinePrices') ?
$elemAll :	$elemAll->FindNode('OnlinePrices');
if (!defined $elemOnlinePrices)
{
return ($::FAILURE, GetPhrase(-1, 2451, 'OnlinePrices'));
}
my $elemRetailPrices = $elemOnlinePrices->FindNode('RetailPrices');
if (!defined $elemRetailPrices)
{
return ($::FAILURE, GetPhrase(-1, 2451, 'RetailPrices'));
}
my $elemCustomerPrices = $elemOnlinePrices->FindNode('CustomerPrices');
if (!defined $elemCustomerPrices)
{
return ($::FAILURE, GetPhrase(-1, 2451, 'CustomerPrices'));
}
return ($::SUCCESS, '', $elemOnlinePrices, $elemRetailPrices, $elemCustomerPrices);
}
sub GetSectionHash
{
my ($sSectionBlobFileName) = @_;
if (!defined $::g_pSectionList{$sSectionBlobFileName})
{
my @Response = ReadSectionFile(GetPath().$sSectionBlobFileName);
if ($Response[0] != $::SUCCESS)
{
return ($::NOTFOUND, GetPhrase(-1, 2452, $sSectionBlobFileName));
}
if (${$::g_pSectionList{$sSectionBlobFileName}}{VERSION} != $::g_nSectionBlobVersion)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, ${$::g_pSectionList{$sSectionBlobFileName}}{VERSION}, "Section blob",  $::g_nSectionBlobVersion));
}
}
return ($::SUCCESS, '', $::g_pSectionList{$sSectionBlobFileName});
}
sub GetProduct
{
my ($ProductRef, $sSectionBlobFilename, $sPath);
($ProductRef, $sSectionBlobFilename, $sPath) = @_;
if (length $ProductRef == 0)
{
return ($::FAILURE, GetPhrase(-1, 37), 0, 0);
}
my $sOrigProdRef = $ProductRef;
$sOrigProdRef =~ s/^\d+\!//g;
my ($bInMemory);
$bInMemory = defined $::g_pSectionList{$sSectionBlobFilename};
my (@Response, $Status, $Message);
if (!$bInMemory)
{
@Response = ReadSectionFile($sPath.$sSectionBlobFilename);
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
return ($::NOTFOUND, GetPhrase(-1, 173, $ProductRef), \%::g_DeletedProduct);
}
if (${$::g_pSectionList{$sSectionBlobFilename}}{VERSION} != $::g_nSectionBlobVersion)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, ${$::g_pSectionList{$sSectionBlobFilename}}{VERSION}, "Section blob",  $::g_nSectionBlobVersion));
}
}
if (!defined ${$::g_pSectionList{$sSectionBlobFilename}}{$sOrigProdRef})
{
my $sSID;
my $sSectionBlobName;
($Status, $sSID) = LookUpSectionID($sPath, $sOrigProdRef);
if ($Status == $::SUCCESS)
{
($Status, $Message, $sSectionBlobName) = GetSectionBlobName($sSID);
if ($Status == $::FAILURE)
{
return ($Status, $Message, \%::g_DeletedProduct);
}
if (($sSectionBlobName eq $sSectionBlobFilename) ||
((defined $::g_pSectionList{$sSectionBlobName}) &&
(!defined ${$::g_pSectionList{$sSectionBlobName}}{$sOrigProdRef})))
{
return ($::NOTFOUND, GetPhrase(-1, 173, $ProductRef), \%::g_DeletedProduct);
}
return (GetProduct($sOrigProdRef, $sSectionBlobName, $sPath));
}
return ($::NOTFOUND, GetPhrase(-1, 173, $ProductRef), \%::g_DeletedProduct);
}
return ($::SUCCESS, '', ${$::g_pSectionList{$sSectionBlobFilename}}{$sOrigProdRef});
}
sub LookUpSectionID
{
my ($sPath, $sProdRef) = @_;
my %Product;
my $rFile = \*PRODUCTINDEX;
my $sFilename = $sPath . "oldprod.fil";
my ($status, $sError) = ACTINIC::InitIndex($sFilename, $rFile, $::g_nSearchIndexVersion);
if ($status != $::SUCCESS)
{
ACTINIC::TerminalError($sError);
}
($status, $sError) = ACTINIC::ProductSearch($sProdRef, $rFile, $sFilename, \%Product);
if ($status != $::SUCCESS)
{
ACTINIC::CleanupIndex($rFile);
return ($::FAILURE, 0);
}
return ($::SUCCESS, $Product{SID});
}
sub GetProductReferenceFromVariant
{
my ($sInvalidProductReference) = "'";
my ($sVariantCode, $sSectionBlobFilename, $sPath);
($sVariantCode, $sSectionBlobFilename, $sPath) = @_;
my ($bInMemory);
$bInMemory = defined $::g_pVariantList{$sSectionBlobFilename};
my (@Response, $Status, $Message);
if (!$bInMemory)
{
@Response = ReadSectionFile($sPath.$sSectionBlobFilename);
($Status, $Message) = @Response;
if ($Status != $::SUCCESS)
{
return (@Response);
}
my $nVersion = 0;
if (${$::g_pVariantList{$sSectionBlobFilename}}{VERSION} != $nVersion)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, ${$::g_pVariantList{$sSectionBlobFilename}}{VERSION} ,"Variant blob", $nVersion ));
}
}
if (!defined ${$::g_pVariantList{$sSectionBlobFilename}}{$sVariantCode})
{
return ($::FAILURE, GetPhrase(-1, 190, $sVariantCode), $sInvalidProductReference);
}
return ($::SUCCESS, undef, ${$::g_pVariantList{$sSectionBlobFilename}}{$sVariantCode});
}
sub ReadSetupFile
{
my @Response = ReadConfigurationFile($_[0]."nqset00.fil",'$g_pSetupBlob');
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($$::g_pSetupBlob{VERSION} != $::g_nSetupBlobVersion)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, $$::g_pSetupBlob{VERSION}, "Setup blob", $::g_nSetupBlobVersion ));
}
my $nMinorVersion = 1;
if ($$::g_pSetupBlob{MINOR_VERSION} < $nMinorVersion)
{
return ($::FAILURE, "Setup blob minor version number is " . $$::g_pSetupBlob{MINOR_VERSION} .
", but minor version $nMinorVersion is required.", 0, 0);
}
$::g_sRequiredColor	= $$::g_pSetupBlob{REQUIRED_COLOR};
$::g_sErrorColor		= $$::g_pSetupBlob{ERRORHIGHLIGHTCOLOR};
my $sCgiUrl = $$::g_pSetupBlob{CGI_URL};
my $sSSLCgiUrl = "";
if ($$::g_pSetupBlob{USE_SSL})
{
$sSSLCgiUrl = $$::g_pSetupBlob{SSL_CGI_URL};
}
if ($$::g_pSetupBlob{'USE_RELATIVE_CGI_URLS'})
{
$sCgiUrl =~ s/http(s?):\/\/[^\/]*\//\//;
$sSSLCgiUrl =~ s/http(s?):\/\/[^\/]*\//\//;
}
my $sCgiName = "%s" . sprintf("%6.6d%s",$$::g_pSetupBlob{CGI_ID},$$::g_pSetupBlob{CGI_EXT});
$sCgiUrl .= $sCgiName;
$sSSLCgiUrl .= $sCgiName;
$::g_sAccountScript 	= sprintf($sCgiUrl, "bb");
$::g_sAccountScriptName = sprintf($sCgiName, "bb");
$::g_sOrderScript 	= sprintf($sCgiUrl, "os");
$::g_sSearchScript  	= sprintf($sCgiUrl, "ss");
$::g_sCartScript  	= sprintf($sCgiUrl, "ca");
$::g_sSearchHighLightScript = sprintf($sCgiUrl, "sh");
$::g_sSSLSearchScript= sprintf($sSSLCgiUrl, "ss");
return ($::SUCCESS, "", 0, 0);
}
sub ReadCatalogFile
{
my @Response = ReadConfigurationFile($_[0]."A000.cat",'$g_pCatalogBlob');
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($$::g_pCatalogBlob{VERSION} != $::g_nCatalogBlobVersion)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, $$::g_pCatalogBlob{VERSION}, "Catalog blob", $::g_nCatalogBlobVersion ));
}
return ($::SUCCESS, "", 0, 0);
}
sub ReadDiscountBlob
{
my @Response = ReadConfigurationFile($_[0]."discounts.fil",'$g_pDiscountBlob');
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($$::g_pDiscountBlob{VERSION} != $::g_nDiscountBlobVersion)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, $$::g_pDiscountBlob{VERSION}, "Discount blob", $::g_nDiscountBlobVersion ));
}
return ($::SUCCESS, "", 0, 0);
}
sub IsCustomVarDefined
{
my $sVarname = $_[0];
if (!defined $::g_pCatalogBlob)
{
my ($nStatus, $sMessage) = ReadCatalogFile(GetPath());
if ($nStatus != $::SUCCESS)
{
TerminalError($sMessage);
}
}
if (!defined $::g_pCatalogBlob->{CUSTOMVARS}{$sVarname})
{
return($::FALSE, "");
}
else
{
return($::TRUE, $::g_pCatalogBlob->{CUSTOMVARS}{$sVarname});
}
}
sub ReadPaymentFile
{
my @Response = ReadConfigurationFile($_[0]."payment.fil",'$g_pPaymentList');
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($$::g_pPaymentList{VERSION} != $::g_nPaymentBlobVersion)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, $$::g_pPaymentList{VERSION}, "Location blob", $::g_nPaymentBlobVersion ));
}
return ($::SUCCESS, "", 0, 0);
}
sub ReadLocationsFile
{
my @Response = ReadConfigurationFile($_[0]."locations.fil",'$g_pLocationList');
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($$::g_pLocationList{VERSION} != $::g_nLocationBlobVersion)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, $$::g_pLocationList{VERSION}, "Location blob", $::g_nLocationBlobVersion));
}
return ($::SUCCESS, "", 0, 0);
}
sub ReadSearchSetupFile
{
my @Response = ReadConfigurationFile($_[0]."search.fil",'$g_pSearchSetup');
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($$::g_pSearchSetup{VERSION} != $::g_nSearchSetupBlobVersion)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, $$::g_pSearchSetup{VERSION}, "Search setup blob", $::g_nSearchSetupBlobVersion));
}
return ($::SUCCESS, "", 0, 0);
}
sub ReadTaxSetupFile
{
my @Response = ReadConfigurationFile($_[0]."taxsetup.fil",'$g_pTaxSetupBlob','$g_pTaxesBlob','$g_pTaxZonesBlob','$g_pTaxZoneMembersTable');
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($$::g_pTaxSetupBlob{VERSION} != $::g_nTaxSetupBlobVersion)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, $$::g_pTaxSetupBlob{VERSION}, "Tax setup blob", $::g_nTaxSetupBlobVersion));
}
return ($::SUCCESS, "", 0, 0);
}
sub ReadSSPSetupFile
{
my @Response = ReadConfigurationFile($_[0]."sspsetup.fil",'$g_pSSPSetupBlob');
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($$::g_pSSPSetupBlob{VERSION} != $::g_nSSPSetupBlobVersion)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, $$::g_pSSPSetupBlob{VERSION}, "SSP setup blob", $::g_nSSPSetupBlobVersion ));
}
return ($::SUCCESS, "", 0, 0);
}
sub ReadSectionFile
{
my @Response = ReadConfigurationFile(@_,'%g_pSectionList');
if ($Response[0] != $::SUCCESS)
{
$Response[0] = $::NOTFOUND;
return (@Response);
}
return ($::SUCCESS, "", 0, 0);
}
sub ReadPhaseFile
{
my @Response = ReadConfigurationFile($_[0]."phase.fil",'$g_pPhaseList');
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($$::g_pPhaseList{VERSION} != 0)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, $$::g_pPhaseList{VERSION}, "Phase blob", 0));
}
return ($::SUCCESS, "", 0, 0);
}
sub ReadPromptFile
{
my @Response = ReadConfigurationFile($_[0]."prompt.fil",'$g_pPromptList');
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
if ($$::g_pPromptList{VERSION} != 0)
{
return ($::FAILURE, sprintf($::g_sCompabilityError, $$::g_pPromptList{VERSION}, "Prompt blob", 0));
}
$::g_sCancelButtonLabel 	= GetPhrase(-1, 505);
$::g_sConfirmButtonLabel 	= GetPhrase(-1, 153);
$::g_sAddToButtonLabel 		= GetPhrase(-1, 154);
$::g_sEditButtonLabel 		= GetPhrase(-1, 155);
$::g_sRemoveButtonLabel 	= GetPhrase(-1, 156);
$::g_sSearchButtonLabel 	= GetPhrase(-1, 157);
$::g_sSaveShoppingListLabel 	= GetPhrase(-1, 2164);
$::g_sGetShoppingListLabel 	= GetPhrase(-1, 2165);
$::g_sUpdateCartLabel			= GetPhrase(-1, 2166);
$::g_sCheckoutNowLabel			= GetPhrase(-1, 184);
$::g_sContinueShoppingLabel	= GetPhrase(-1, 47);
$::g_sSendCouponLabel			= GetPhrase(-1, 2356);
$::g_sSendMailLabel				= GetPhrase(-1, 2374);
$::g_sCompabilityError		= GetPhrase(-1, 2219);
%::g_DeletedProduct =
(
'REFERENCE' => ' ',
'NAME' => ACTINIC::GetPhrase(-1, 174),
'PRICE' => 0,
'MIN' => 1,
'MAX' => 0,
'TAX_TREATMENT' => $ActinicOrder::ZERO
);
my @keys = keys %{$::g_pPromptList};
my $list = join(' ', @keys);
my @scratch = ($list =~ m/([-0-9]+),(\d+) /g);
while ($#scratch != -1)
{
my $nPhraseID = pop @scratch;
push (@{$::g_PhraseIndex{pop @scratch}}, $nPhraseID);
}
return ($::SUCCESS, "", 0, 0);
}
sub ReadConfigurationFile
{
my $sFilename = shift;
my $pShared   = \@_;
my @Response = ReadAndVerifyFile($sFilename);
if ($Response[0] != $::SUCCESS)
{
return(@Response);
}
if( !$ACTINIC::USESAFE or $#$pShared < 0 )
{
if (eval($Response[2]) != $::SUCCESS)
{
return ($::FAILURE, "Error loading configuration file $sFilename. $@", 0, 0);
}
}
else
{
@Response = EvalInSafe($Response[2],$ACTINIC::USESAFEONLY,$pShared);
if( $Response[0] != $::SUCCESS)
{
return ($::FAILURE, "Error loading configuration file $sFilename. $Response[1]", 0, 0);
}
}
return ($::SUCCESS, "", 0, 0);
}
sub ReadAndVerifyFile
{
my ($sFilename);
($sFilename) = @_;
unless (open (SCRIPTFILE, "<$sFilename"))
{
return ($::FAILURE, "Error opening configuration file $sFilename. $!", 0, 0);
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
return ($::FAILURE, "$sFilename is corrupt.  The signature is invalid.", 0, 0);
}
$sScript =~ s/\r//g;
return ($::SUCCESS, "", $sScript, 0);
}
sub GetBuyerAndAccount
{
my ($sDigest) = @_;
if($sDigest eq '')
{
return($::NOTFOUND);
}
my ($Status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sDigest, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return ($Status, $sMessage);
}
my $pAccount;
($Status, $sMessage, $pAccount) = ACTINIC::GetCustomerAccount($$pBuyer{AccountID}, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return ($Status, $sMessage);
}
return($::SUCCESS, '', $pBuyer, $pAccount);
}
sub GetCustomerAddressLists
{
my($pBuyer, $pAccount, $bSkipLocationCheck) = @_;
my ($Status, $sMessage, $pAddress, @listValidInvoiceAddresses, @listValidDeliveryAddresses);
my @listAddressIDs = split(/,/, $$pAccount{AddressList});
my $nAddressID;
my $nSingleInvoiceID = -1;
if( $pAccount->{InvoiceAddressRule} == 1)
{
$nSingleInvoiceID = $pAccount->{InvoiceAddress};
}
elsif($pBuyer->{InvoiceAddressRule} == 0)
{
$nSingleInvoiceID = $pBuyer->{InvoiceAddressID};
}
my $nSingleDeliveryID = $pBuyer->{DeliveryAddressRule} == 0 ?
$pBuyer->{DeliveryAddressID} : -1;
foreach $nAddressID (@listAddressIDs)
{
($Status, $sMessage, $pAddress) = ACTINIC::GetCustomerAddress($$pBuyer{AccountID}, $nAddressID, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
ACTINIC::CloseCustomerAddressIndex(); # The customer index is left open for multiple access, so clean it up here
return ($::FAILURE, "The format of the address information stored on the server (oldaddress.fil) is invalid. The reported error was: " . $sMessage, "");
}
if($pAddress->{ValidAsInvoiceAddress})
{
my $bValidAddress = $::FALSE;
if($::g_pLocationList->{EXPECT_INVOICE})
{
if($bSkipLocationCheck)
{
$bValidAddress = $::TRUE;
}
elsif($::g_LocationInfo{INVOICE_COUNTRY_CODE} eq '' ||
$::g_LocationInfo{INVOICE_COUNTRY_CODE} eq $ActinicOrder::REGION_NOT_SUPPLIED ||
($pAddress->{CountryCode} eq $::g_LocationInfo{INVOICE_COUNTRY_CODE} &&
($::g_LocationInfo{INVOICE_REGION_CODE} eq $ActinicOrder::UNDEFINED_REGION ||
$pAddress->{StateCode} eq $::g_LocationInfo{INVOICE_REGION_CODE})))
{
$bValidAddress = $::TRUE;
}
}
else
{
$bValidAddress = $::TRUE;
}
if(($nSingleInvoiceID == -1 && $bValidAddress) ||
$nSingleInvoiceID == $pAddress->{ID})
{
push @listValidInvoiceAddresses, $pAddress;
}
}
if($pAddress->{ValidAsDeliveryAddress})
{
my $bValidAddress = $::FALSE;
if($::g_pLocationList->{EXPECT_DELIVERY})
{
if($bSkipLocationCheck)
{
$bValidAddress = $::TRUE;
}
elsif($::g_LocationInfo{DELIVERY_COUNTRY_CODE} eq '' ||
($::g_LocationInfo{DELIVERY_COUNTRY_CODE} eq $ActinicOrder::REGION_NOT_SUPPLIED ||
$pAddress->{CountryCode} eq $::g_LocationInfo{DELIVERY_COUNTRY_CODE}) &&
($::g_LocationInfo{DELIVERY_REGION_CODE} eq $ActinicOrder::UNDEFINED_REGION ||
$pAddress->{StateCode} eq $::g_LocationInfo{DELIVERY_REGION_CODE}))
{
$bValidAddress = $::TRUE;
}
}
else
{
$bValidAddress = $::TRUE;
}
if(($nSingleDeliveryID == -1 && $bValidAddress) ||
$nSingleDeliveryID == $pAddress->{ID})
{
push @listValidDeliveryAddresses, $pAddress;
}
}
}
return($::SUCCESS, '', \@listValidInvoiceAddresses, \@listValidDeliveryAddresses,
$nSingleInvoiceID, $nSingleDeliveryID);
}
sub GetBuyer
{
my ($sDigest, $sPath) = @_;
if ($sDigest eq $ACTINIC::BuyerDigest)
{
return ($::SUCCESS, undef, \%ACTINIC::Buyer);
}
undef %ACTINIC::Buyer;
undef $ACTINIC::BuyerDigest;
my $rFile = \*BUYERINDEX;
my $sFilename = $sPath . "oldbuyer.fil";
my ($status, $sMessage) = InitIndex($sFilename, $rFile, 0);
if ($status != $::SUCCESS)
{
return ($status, $sMessage);
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
my $sUserName = $ACTINIC::B2B->Get('UserName');
my $sUserHash = md5_hex($sUserName . $sDigest);
my $sUserKey = $ACTINIC::B2B->Get('UserKey');
my $sValue;
($status, $sMessage, $sValue) = IndexSearch($sUserHash, 2, $rFile, $sFilename);
if ($status != $::SUCCESS)
{
if ($status == $::NOTFOUND)
{
$sMessage = ACTINIC::GetPhrase(-1, 2268);
}
CleanupIndex($rFile);
return ($status, $sMessage);
}
CleanupIndex($rFile);
if ($sUserKey)
{
$sUserKey =~ s/([A-Fa-f0-9]{2})/pack("C",hex($1))/ge;
my @PrivateKey = unpack('C*',$sUserKey);
my ($sLength, $sDetails) = split(/ /, $sValue);
$sDetails =~ s/([A-Fa-f0-9]{2})/pack("C",hex($1))/ge;
ActinicEncrypt::InitEncrypt(@{$$::g_pSetupBlob{PUBLIC_KEY_128BIT}});
$sDetails = ActinicEncrypt::DecryptSafer($sDetails, @PrivateKey);
$sValue = substr($sDetails,0,$sLength);
}
$sValue =~ s/([^ ])$/$1 /;
$sValue .= 'a';
my @Details = split(/ /, $sValue);
pop @Details;
my @Labels = qw (ID AccountID Status InvoiceAddressRule InvoiceAddressID DeliveryAddressRule
DeliveryAddressID MaximumOrderValue EmailOnOrder LimitOrderValue HideRetailPrices
EmailAddress Name FirstName LastName Salutation Title TelephoneNumber MobileNumber FaxNumber);
if( $sUserKey )
{
push @Labels,'AccountKey';
}
if ($#Details != $#Labels)
{
return($::BADDATA, ACTINIC::GetPhrase(-1, 2073), undef);
}
my $nIndex;
foreach ($nIndex = 0; $nIndex <= $#Details; $nIndex++)
{
$ACTINIC::Buyer{$Labels[$nIndex]} = DecodeText($Details[$nIndex], $ACTINIC::FORM_URL_ENCODED);
}
if( $sUserKey )
{
$ACTINIC::B2B->Set('AccountKey',$ACTINIC::Buyer{AccountKey});
}
$ACTINIC::BuyerDigest = $sDigest;
return ($::SUCCESS, undef, \%ACTINIC::Buyer);
}
sub GetCustomerAccount
{
my ($nID, $sPath) = @_;
if ($nID == $ACTINIC::AccountID)
{
return ($::SUCCESS, undef, \%ACTINIC::Account);
}
undef %ACTINIC::Account;
undef $ACTINIC::AccountID;
my $rFile = \*ACCOUNTINDEX;
my $sFilename = $sPath . "oldaccount.fil";
my ($status, $sMessage) = InitIndex($sFilename, $rFile, 0);
if ($status != $::SUCCESS)
{
return ($status, $sMessage);
}
my $sValue;
($status, $sMessage, $sValue) = IndexSearch($nID, 2, $rFile, $sFilename);
if ($status != $::SUCCESS)
{
if ($status == $::NOTFOUND)
{
$sMessage = ACTINIC::GetPhrase(-1, 2269);
}
CleanupIndex($rFile);
return ($status, $sMessage);
}
CleanupIndex($rFile);
my $sAccountKey = $ACTINIC::B2B->Get('AccountKey');
if( $sAccountKey )
{
$sAccountKey =~ s/([A-Fa-f0-9]{2})/pack("C",hex($1))/ge;
my @PrivateKey = unpack('C*',$sAccountKey);
my ($sLength, $sDetails) = split(/ /, $sValue);
$sDetails =~ s/([A-Fa-f0-9]{2})/pack("C",hex($1))/ge;
ActinicEncrypt::InitEncrypt(@{$$::g_pSetupBlob{PUBLIC_KEY_128BIT}});
$sDetails = ActinicEncrypt::DecryptSafer($sDetails, @PrivateKey);
$sValue = substr($sDetails,0,$sLength);
}
$sValue =~ s/([^ ])$/$1 /;
$sValue .= 'a';
my @Details = split(/ /, $sValue);
pop @Details;
my @Labels = qw (EmailOnOrder InvoiceAddressRule Status InvoiceAddress PriceSchedule DefaultPaymentMethod
AccountName EmailAddress TelephoneNumber MobileNumber FaxNumber Name FirstName LastName Salutation Title AddressList);
my $nIndex;
foreach ($nIndex = 0; $nIndex <= $#Details; $nIndex++)
{
$ACTINIC::Account{$Labels[$nIndex]} = DecodeText($Details[$nIndex], $ACTINIC::FORM_URL_ENCODED);
}
$ACTINIC::AccountID = $nID;
return ($::SUCCESS, undef, \%ACTINIC::Account);
}
sub GetCustomerAddress
{
my ($nAccountID, $nAddressID, $sPath) = @_;
my $sIdentifier = $nAccountID . ":" . $nAddressID;
if (defined $ACTINIC::Addresses{$sIdentifier})
{
return ($::SUCCESS, undef, $ACTINIC::Addresses{$sIdentifier});
}
my $sFilename = $sPath . "oldaddress.fil";
if (!defined $ACTINIC::rAddressFileHandle)
{
$ACTINIC::rAddressFileHandle = \*ADDRESSINDEX;
my ($status, $sMessage) = InitIndex($sFilename, $ACTINIC::rAddressFileHandle, 1);
if ($status != $::SUCCESS)
{
return ($status, $sMessage);
}
}
my ($status, $sMessage, $sValue) = IndexSearch($sIdentifier, 2, $ACTINIC::rAddressFileHandle, $sFilename);
if ($status != $::SUCCESS)
{
if ($status == $::NOTFOUND)
{
$sMessage = ACTINIC::GetPhrase(-1, 2270);
}
CleanupIndex($ACTINIC::rAddressFileHandle);
undef $ACTINIC::rAddressFileHandle;
return ($status, $sMessage);
}
my $sAccountKey = $ACTINIC::B2B->Get('AccountKey');
if( $sAccountKey )
{
$sAccountKey =~ s/([A-Fa-f0-9]{2})/pack("C",hex($1))/ge;
my @PrivateKey = unpack('C*',$sAccountKey);
my ($sLength, $sDetails) = split(/ /, $sValue);
$sDetails =~ s/([A-Fa-f0-9]{2})/pack("C",hex($1))/ge;
ActinicEncrypt::InitEncrypt(@{$$::g_pSetupBlob{PUBLIC_KEY_128BIT}});
$sDetails = ActinicEncrypt::DecryptSafer($sDetails, @PrivateKey);
$sValue = substr($sDetails,0,$sLength);
}
$sValue =~ s/([^ ])$/$1 /;
$sValue .= 'a';
my @Details = split(/ /, $sValue);
pop @Details;
my @Labels = qw (ValidAsInvoiceAddress ValidAsDeliveryAddress ExemptTax1 ExemptTax2 CountryCode StateCode Name
Line1 Line2 Line3 Line4 PostCode Tax1ExemptData Tax2ExemptData Tax1ID Tax2ID nResidential);
my $nIndex;
foreach ($nIndex = 0; $nIndex <= $#Details; $nIndex++)
{
$ACTINIC::Addresses{$sIdentifier}{$Labels[$nIndex]} = DecodeText($Details[$nIndex], $ACTINIC::FORM_URL_ENCODED);
}
$ACTINIC::Addresses{$sIdentifier}{ID} = $nAddressID;
return ($::SUCCESS, undef, $ACTINIC::Addresses{$sIdentifier});
}
sub CloseCustomerAddressIndex
{
if (defined $ACTINIC::rAddressFileHandle)
{
CleanupIndex($ACTINIC::rAddressFileHandle);
undef $ACTINIC::rAddressFileHandle;
}
}
sub InitIndex
{
my ($sPath, $rFileHandle, $nExpectedVersion) = @_;
my ($status, $sError);
my $nRetryCount = $ACTINIC::MAX_RETRY_COUNT;
$status = $::SUCCESS;
while ($nRetryCount--)
{
unless (open ($rFileHandle, "<$sPath"))
{
$sError = $!;
sleep $ACTINIC::RETRY_SLEEP_DURATION;
$status = $::FAILURE;
$sError = ACTINIC::GetPhrase(-1, 282, $sPath, $sError);
next;
}
binmode $rFileHandle;
my $sBuffer;
unless (read($rFileHandle, $sBuffer, 4) == 4) # read the blob version number (a short)
{
$sError = $!;
close ($rFileHandle);
return ($::FAILURE, ACTINIC::GetPhrase(-1, 283, $sPath, $sError));
}
my ($nVersion) = unpack("n", $sBuffer);
if ($nVersion != $nExpectedVersion)
{
close($rFileHandle);
sleep $ACTINIC::RETRY_SLEEP_DURATION;
$status = $::FAILURE;
$sError = ACTINIC::GetPhrase(-1, 284, $sPath, $nExpectedVersion, $nVersion);
next;
}
last;
}
return($status, $sError);
}
sub CleanupIndex
{
close ($_[0]);
}
sub IndexSearch
{
my ($sKey, $nLocation, $rFile, $sFileName, $bExactMatch) = @_;
if ($#_ < 4)
{
$bExactMatch = $::FALSE;
}
my ($nDependencies, $nCount, $nRefs, $sRefs, $sBuff, $sFragment, $sValue);
my ($nIndex, $sSeek, $nHere, $nLength, $sNext, $nRead);
unless (seek($rFile, $nLocation, 0))
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 285, $sFileName, $!));
}
unless (read($rFile, $sBuff, 2) == 2)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 285, $sFileName, $!));
}
($nCount) = unpack("n", $sBuff);
for ($nIndex = 0; $nIndex < $nCount; $nIndex++)
{
unless (read($rFile, $sBuff, 2) == 2)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 285, $sFileName, $!));
}
($nLength) = unpack("n", $sBuff);
unless (read ($rFile, $sValue, $nLength) == $nLength)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 285, $sFileName, $!));
}
unless (read($rFile, $sBuff, 1) == 1)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 285, $sFileName, $!));
}
($nRefs) = unpack("C", $sBuff);
$sRefs = "";
if ($nRefs > 0)
{
unless (read($rFile, $sRefs, $nRefs) == $nRefs)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 285, $sFileName, $!));
}
}
if ($sKey eq "")
{
return ($::SUCCESS, undef, $sValue);
}
}
unless (read($rFile, $sBuff, 2) == 2)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 285, $sFileName, $!));
}
$nDependencies = unpack("n", $sBuff);
for ($nIndex = 0; $nIndex < $nDependencies; $nIndex++)
{
unless (read($rFile, $sBuff, 1) == 1)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 285, $sFileName, $!));
}
$nLength = unpack("C", $sBuff);
unless (read($rFile, $sFragment, $nLength) == $nLength)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 285, $sFileName, $!));
}
unless (read($rFile, $sSeek, 4) == 4)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 285, $sFileName, $!));
}
if (!$bExactMatch)
{
$sFragment = substr($sFragment, 0, length($sKey));
}
my $sQuotedFragment = quotemeta($sFragment);
if ($sKey =~ m/^$sQuotedFragment/) # Does it match?
{
$sNext = $';
$nHere = tell($rFile);
my ($status, $sError, $sValue) = IndexSearch($sNext, unpack("N", $sSeek), $rFile, $sFileName, $bExactMatch);
if ($status == $::FAILURE ||
$status == $::SUCCESS)
{
return ($status, $sError, $sValue);
}
unless (seek($rFile, $nHere, 0))
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 285, $sFileName, $!));
}
}
if ($sFragment gt $sKey)
{
last;
}
}
return ($::NOTFOUND, 'Item not found in index');
}
sub ProductSearch
{
my ($sProductReference, $rFile, $sFilename, $rhashProduct) = @_;
undef %$rhashProduct;
my ($Status, $sMessage, $sValue) = ACTINIC::IndexSearch($sProductReference, 2, $rFile, $sFilename, $::TRUE);
if ($Status != $::SUCCESS)
{
if ($Status == $::NOTFOUND)
{
$sMessage = ACTINIC::GetPhrase(-1, 2267);
}
return ($Status, $sMessage);
}
unless ($sValue =~ /^(\S+) (\d+) (\d+) (\S+) (\d+) (.+)/s)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 255, $sValue));
}
$$rhashProduct{CURRENCY} = $1;
$$rhashProduct{DECIMALS} = $2;
$$rhashProduct{PRICE}    = $3;
$$rhashProduct{ANCHOR}   = $4;
my $nLength = $5;
my $sBuffer = $6;
$$rhashProduct{NAME} = substr($sBuffer, 0, $nLength);
substr($sBuffer, 0, $nLength + 1) = '';
unless ($sBuffer =~ /^(\d+) (.+)/s)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 255, $sValue));
}
$nLength = $1;
$sBuffer = $2;
$$rhashProduct{DESCRIPTION} = substr($sBuffer, 0, $nLength);
substr($sBuffer, 0, $nLength + 1) = '';
unless ($sBuffer =~ /^(\d+) (.+)/s)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 255, $sValue));
}
$$rhashProduct{SID} = $1;
$sBuffer = $2;
unless ($sBuffer =~ /^(\d+) (.+)/s)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 255, $sValue));
}
$nLength = $1;
$sBuffer = $2;
$$rhashProduct{SECTION} = substr($sBuffer, 0, $nLength);
substr($sBuffer, 0, $nLength + 1) = '';
unless ($sBuffer =~ /^(\d+) (.*)/s)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 255, $sValue));
}
$nLength = $1;
$sBuffer = $2;
$$rhashProduct{IMAGE} = substr($sBuffer, 0, $nLength);
substr($sBuffer, 0, $nLength + 1) = '';
my $rhashProperties = {};
my $sProperty;
until ($sBuffer !~ /^(\d+) (.+)/s)
{
$nLength = $1;
$sBuffer = $2;
$sProperty = substr($sBuffer, 0, $nLength);
unless ($sProperty =~ /([^!]+)!(.*)/)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 255, $sValue));
}
$$rhashProperties{$1} .= $2 . "!";
substr($sBuffer, 0, $nLength + 1) = '';
}
$$rhashProduct{PROPERTIES} = $rhashProperties;
return ($::SUCCESS);
}
sub GetCurrentScheduleID
{
my $nScheduleID;
my ($Status, $sMessage, $pBuyer, $pAccount);
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if ($sDigest)
{
my ($Status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sDigest, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return ($Status, $sMessage);
}
($Status, $sMessage, $pAccount) = ACTINIC::GetCustomerAccount($pBuyer->{AccountID}, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return ($Status, $sMessage);
}
$nScheduleID = $pAccount->{PriceSchedule};
}
else
{
$nScheduleID = $ActinicOrder::RETAILID;
}
return ($::SUCCESS, '', $nScheduleID);
}
sub IsProductVisible
{
my $sProdRef		= shift;
my $nScheduleID	= shift;
my ($nStatus, $sMessage);
if (!$nScheduleID)
{
($nStatus, $sMessage, $nScheduleID) = GetCurrentScheduleID();
if ($nStatus != $::SUCCESS)
{
TerminalError($sMessage);
}
}
if (!IsPriceScheduleConstrained($nScheduleID))
{
return $::TRUE;
}
require sl000001;
my $sPath = GetSecurePath();
my $rPriceScheduleHits = {};
($nStatus, $sMessage) = Search::SearchPriceSchedule($sPath, $nScheduleID, $rPriceScheduleHits);
if ($nStatus != $::SUCCESS)
{
TerminalError($sMessage);
}
return (exists $rPriceScheduleHits->{$sProdRef});
}
sub IsPriceScheduleConstrained
{
my $nScheduleID = shift;
if (!$::g_pSearchSetup)
{
my $sPath = GetSecurePath();
my ($Status, $sError) = ReadSearchSetupFile($sPath);
if ($Status != $::SUCCESS)
{
ReportError($sError, $sPath);
}
}
my $phashPriceScheduleHides = $::g_pSearchSetup->{PRICE_SCH_HIDES};
return $phashPriceScheduleHides->{$nScheduleID};
}
sub GetPhrase
{
no strict 'refs';
my ($nPhase, $nPrompt, @args);
if ($#_ < 1)
{
$nPhase = -1;
$nPrompt = 12;
@args = ('GetPhrase');
}
else
{
($nPhase, $nPrompt, @args) = @_;
}
my ($sPhrase);
if (defined $::g_pPromptList)
{
$sPhrase = $$::g_pPromptList{"$nPhase,$nPrompt"}{PROMPT};
}
elsif (defined $::g_InputHash{"PHRASE$nPhase,$nPrompt"})
{
$sPhrase = $::g_InputHash{"PHRASE$nPhase,$nPrompt"};
}
else
{
return ("Phrases not read yet ($nPhase,$nPrompt) {" . join(', ', @args) . "}.");
}
if (defined $sPhrase &&
$#args > -1)
{
$sPhrase = sprintf($sPhrase, @args);
}
if (defined $sPhrase)
{
return ($sPhrase);
}
return ("Phrase not found ($nPhase,$nPrompt) {" . join(', ', @args) . "}!!");
}
sub GetRequiredMessage
{
return
(
GetPhrase(-1, 55, "\"<B>" .  ACTINIC::GetPhrase(-1, 1971,  $::g_sRequiredColor) .
GetPhrase($_[0], $_[1]) . ACTINIC::GetPhrase(-1, 1970) . "</B>\"") . "<BR>\n"
);
}
sub GetLengthFailureMessage
{
return
(
GetPhrase(-1, 2299, "\"<B>" .  ACTINIC::GetPhrase(-1, 1971,  $::g_sRequiredColor) .
GetPhrase($_[0], $_[1]) . ACTINIC::GetPhrase(-1, 1970) . "</B>\"", $_[2]) . "<BR>\n"
);
}
sub IsPromptRequired
{
no strict 'refs';
if ($#_ != 1)
{
return ($::FALSE);
}
my ($nPhase, $nPrompt) = @_;
return ($$::g_pPromptList{"$nPhase,$nPrompt"}{STATUS} == $::REQUIRED ? $::TRUE : $::FALSE); # return it's required status
}
sub IsPromptHidden
{
no strict 'refs';
if ($#_ != 1)
{
return ($::FALSE);
}
my ($nPhase, $nPrompt) = @_;
return ($$::g_pPromptList{"$nPhase,$nPrompt"}{STATUS} == $::HIDDEN ? $::TRUE : $::FALSE); # return it's hidden status
}
sub ChangeAccess
{
my $OldMask = umask(0);
my ($mode, $file, $nCount);
($mode, $file) = @_;
SecurePath($file);
if ($mode eq '')
{
$nCount = chmod 0200, $file;
}
elsif ($mode eq "rw")
{
$nCount = chmod 0666, $file;
}
elsif ($mode eq "r")
{
$nCount = chmod 0644, $file;
}
umask($OldMask);
return ($nCount);
}
sub CleanFileName
{
my $nam = shift;
$nam =~ tr/a-zA-Z0-9\.\_\-/_/c;
return $nam;
}
sub SecurePath2
{
my ($sPath) = $_[0];
if ($^O =~ /win/i)
{
if ($sPath =~ m|[!&<>\|*?()^;\${}\[\]\`\'\"\n\r]| ||
$sPath =~ m|\0|)
{
return("\"$sPath\" contains invalid characters.");
}
}
else
{
if ($sPath =~ m|[!&<>\|*?()^;\${}\[\]\`\'\"\\~\n\r]| ||
$sPath =~ m|\0|)
{
return("\"$sPath\" contains invalid characters.");
}
}
return (undef);
}
sub SecurePath
{
my $sError = SecurePath2(@_);
if ($sError)
{
TerminalError($sError);
}
}
sub CheckForShellCharacters
{
my ($sValue) = $_[0];
if ($sValue =~ m|[!&<>\|*?()^;\${}\[\]\`\'\"\\~\n\r]| ||
$sValue =~ m|\0|)
{
return ("\"$sValue\" contains invalid characters.");
}
return (undef);
}
sub GetPath
{
return ($ACTINIC::s_sPath);
}
sub GetSecurePath
{
my $sPath = GetPath();
SecurePath($sPath);
if (!$sPath)
{
TerminalError("Path not found.");
}
if (!-e $sPath ||
!-d $sPath)
{
TerminalError("Invalid path.");
}
return $sPath;
}
sub AuthenticateUser
{
my ($sUsername, $sPassword) = @_;
my ($sCorrectUsername, $sCorrectPassword) = ('5d028f034438438c34845a195b621564', 'b276f5a7c8b02db732ba111ee2623cf2');
if (!$sUsername ||
!$sPassword)
{
sleep $ACTINIC::DOS_SLEEP_DURATION;
return ($::FAILURE, ACTINIC::GetPhrase(-1, 2033));
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
if (!$::FALSE)
{
if ($sCorrectUsername ne md5_hex($sUsername) ||
$sCorrectPassword ne md5_hex($sPassword))
{
sleep $ACTINIC::DOS_SLEEP_DURATION;
return ($::FAILURE, ACTINIC::GetPhrase(-1, 2034));
}
}
else
{
eval 'require AHDClient;';
if ($@)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 2033) . '  ' . $@);
}
my ($nStatus, $sError, $pClient);
($nStatus, $sError, $pClient) = new_readonly AHDClient('../gk/acatalog/');
if ($nStatus!= $::SUCCESS)
{
return($nStatus, $sError);
}
($nStatus, $sError, my $pShop)= $pClient->GetShopDetailsFromUsernameAndPassword($sUsername, $sPassword);
if (!defined($pShop))
{
sleep $ACTINIC::DOS_SLEEP_DURATION;
return ($::BADDATA, $sError);
}
elsif ($nStatus != $::SUCCESS)
{
return ($nStatus, $sError);
}
}
return ($::SUCCESS, undef);
}
sub OpenWriteBlob
{
my ($sFilename) = @_;
if (length $sFilename > 0 &&
$sFilename ne "memory")
{
SecurePath($sFilename);
unless (open (WBFILE, ">$sFilename"))
{
return ($::FAILURE, "Unable to open $sFilename for writing: $!\n", 0, 0);
}
binmode WBFILE;
$ACTINIC::s_WBStyle = $ACTINIC::FILE;
}
elsif ($sFilename eq "memory")
{
$ACTINIC::s_WBBuffer = '';
$ACTINIC::s_WBStyle = $ACTINIC::MEMORY;
}
return ($::SUCCESS, '', 0, 0);
}
sub WriteBlob
{
my ($FieldList, $FieldType) = @_;
my ($Field, $Type, @Response, $i, $nTotal);
for($i = 0; $i <= $#{$FieldList}; $i++)
{
$Type = $$FieldType[$i];
$Field = $$FieldList[$i];
if ($Type == $::RBBYTE)
{
@Response = WriteByte($Field);
}
elsif ($Type == $::RBWORD)
{
@Response = WriteWord($Field);
}
elsif ($Type == $::RBDWORD)
{
@Response = WriteDoubleWord($Field);
}
elsif ($Type == $::RBQWORD)
{
@Response = WriteQuadWord($Field);
}
elsif ($Type == $::RBSTRING)
{
@Response = WriteString($Field);
}
else
{
return ($::FAILURE, "Unknown field type $Type\n", 0, 0);
}
my ($Status, $Message, $nLength);
($Status, $Message, $nLength) = @Response;
$nTotal += $nLength;
if ($Status != $::SUCCESS)
{
return ($Status, $Message, 0, 0);
}
}
return ($::SUCCESS, '', 0, 0);
}
sub CloseWriteBlob
{
if ($ACTINIC::s_WBStyle == $ACTINIC::FILE)
{
close (WBFILE);
}
else
{
return ($::SUCCESS, '', $ACTINIC::s_WBBuffer, 0);
}
return ($::SUCCESS, '', 0);
}
sub WriteByte
{
my ($SIZE, $Byte, $Data);
$SIZE = 1;
($Byte) = @_;
$Data = 0;
$Data = pack ("C", $Byte);
if ($ACTINIC::s_WBStyle == $ACTINIC::FILE)
{
unless (print WBFILE $Data)
{
return ($::FAILURE, "Error writing a byte to the file: $!\n", 0);
}
}
else
{
$ACTINIC::s_WBBuffer .= $Data;
}
return ($::SUCCESS, '', length $Data);
}
sub WriteWord
{
my ($SIZE, $Word, $Data);
$SIZE = 2;
($Word) = @_;
$Data = 0;
$Data = pack ("n", $Word);
if ($ACTINIC::s_WBStyle == $ACTINIC::FILE)
{
unless (print WBFILE $Data)
{
return ($::FAILURE, "Error writing a word to the file: $!\n", 0);
}
}
else
{
$ACTINIC::s_WBBuffer .= $Data;
}
return ($::SUCCESS, '', length $Data);
}
sub WriteDoubleWord
{
my ($SIZE, $DWord, $Data);
$SIZE = 4;
($DWord) = @_;
$Data = 0;
$Data = pack ("N", $DWord);
if ($ACTINIC::s_WBStyle == $ACTINIC::FILE)
{
unless (print WBFILE $Data)
{
return ($::FAILURE, "Error writing a double word to the file: $!\n", 0);
}
}
else
{
$ACTINIC::s_WBBuffer .= $Data;
}
return ($::SUCCESS, '', length $Data);
}
sub WriteQuadWord
{
my ($SIZE, $QuadWord, $Data);
$SIZE = 8;
($QuadWord) = @_;
$Data = 0;
my $nPadding = ($QuadWord < 0) ? 255 : 0;
my (@Bytes);
$Bytes[0] = $nPadding;
$Bytes[1] = $nPadding;
$Bytes[2] = $nPadding;
$Bytes[3] = $nPadding;
$Bytes[4] = ($QuadWord & hex("ff000000"))				>> 24;
$Bytes[5] = ($QuadWord & hex("ff0000"))				>> 16;
$Bytes[6] = ($QuadWord & hex("ff00"))					>>  8;
$Bytes[7] = ($QuadWord & hex("ff"));
$Data = pack ("C8", @Bytes);
if ($ACTINIC::s_WBStyle == $ACTINIC::FILE)
{
unless (print WBFILE $Data)
{
return ($::FAILURE, "Error writing a 8 byte word to the file: $!\n", 0);
}
}
else
{
$ACTINIC::s_WBBuffer .= $Data;
}
return ($::SUCCESS, '', length $Data);
}
sub WriteString
{
my ($String, $Data, $nLength);
($String) = @_;
$Data = 0;
$nLength = length $String;
my (@Response);
@Response = WriteWord($nLength);
if (!$Response[0])
{
return (@Response);
}
my ($nByteLength);
$nByteLength = 2 * $nLength;
if ($nByteLength > 0)
{
my ($Pack, @Characters);
$Pack = "a".($nByteLength / 2);
$Data = pack ($Pack, $String);
$Pack = "C".$nByteLength;
@Characters = unpack ($Pack, $Data);
$Pack = "xC" x ($nByteLength / 2);
$Data = pack ($Pack, @Characters);
if ($ACTINIC::s_WBStyle == $ACTINIC::FILE)
{
unless (print WBFILE $Data)
{
return ($::FAILURE, "Error writing a string to the file: $!\n", 0);
}
if ($nByteLength > 4096)
{
return ($::FAILURE, "Error writing a string from the file: string is ".
"\n\tlonger than 4K - probably bad format or bad version\n", 0);
}
}
else
{
$ACTINIC::s_WBBuffer .= $Data;
}
}
return ($::SUCCESS, '', length $Data);
}
sub GetPlugInScript
{
my ($sScriptName) = @_;
my ($sFilename) = ACTINIC::GetPath() . $sScriptName;
my @Response = ACTINIC::ReadAndVerifyFile($sFilename);
return (@Response);
}
sub EvalInSafe
{
return ::EvalInSafe(@_);
}
package main;
sub EvalInSafe
{
my $sScript = shift;
my $bForce  = shift;
my $pShare  = shift;
my $Result;
eval 'require Safe';
if( $@ )
{
if( $bForce )
{
return ($::FAILURE, "Cannot load Safe.pm");
}
$Result = eval($sScript);
}
else
{
my $pCnt = new Safe();
$pCnt->share('$SUCCESS','$FAILURE');
$pCnt->share(@$pShare);
$Result = $pCnt->reval($sScript);
}
if( $@ )
{
$Result = $::FAILURE;
}
return ($Result,$@);
}
package ACTINIC;
sub HighlightWords
{
my ($sWords, $sStart, $sEnd, $rsHTML) = @_;
my @Patterns = ();
my @Words = split /\s+?/,$sWords;
for (@Words)
{
s/\'/\&#39;/g;          # apostrophe in match pattern: O'Reilly
s/-/\&#45;/g;
s/\./\&#46;/g;
s/_/ /g;
s/([\xc0-\xff])/sprintf('(&#%d;|&#%d;)', ord($1), ord($1) + (ord($1) < 224 ? 32 : -32))/eg;
if ($_ =~ m/^\d+$/)
{
push @Patterns, "\\b$_\[^;\]*?\\b(?!;)";
}
elsif ($_ ne '')
{
push @Patterns, '([^\w;]' . $_ . '|^' . $_ . ')[\w\#\&\;]*';
}
}
my $nFragmentCount = 0;
$$rsHTML =~ s'\<title\>.+?\<\/title\>|\<script.+?\<\/script\>'
$nFragmentCount++;
$ACTINIC::B2B->SetXML("ProtectFragment_$nFragmentCount", $&);
"<Actinic:ProtectFragment_$nFragmentCount/>";
'gesi;
my $sPattern;
foreach $sPattern (@Patterns)
{
$$rsHTML =~ s'\>(.*?)\<'
my $t = $1;
$t =~ s/($sPattern)/$sStart$1$sEnd/gsi;
">$t<";
'gesi;                                    # '
}
}
sub DeterminePricesToShow
{
my $nAccountSchedule = -1;
my $bShowCustomerPrices = $::FALSE;
my $bShowRetailPrices = $::TRUE;
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if($sDigest ne '')
{
my ($Status, $Message, $pBuyer) = ACTINIC::GetBuyer($sDigest, ACTINIC::GetPath());
if ($Status == $::SUCCESS)
{
my $pAccount;
($Status, $Message, $pAccount) = ACTINIC::GetCustomerAccount($$pBuyer{AccountID}, ACTINIC::GetPath());
if ($Status == $::SUCCESS)
{
if( $pAccount->{PriceSchedule} != $ActinicOrder::RETAILID )
{
$nAccountSchedule = $pAccount->{PriceSchedule};
$bShowRetailPrices = !$pBuyer->{HideRetailPrices};
$bShowCustomerPrices = $::TRUE;
}
}
}
}
return($bShowRetailPrices, $bShowCustomerPrices, $nAccountSchedule);
}
sub GetVariantList
{
my ($sProductRef) = @_;
my ($VariantList, $sLine, $k, $i);
foreach $k (keys %::g_InputHash)
{
if( $k =~ /^(vb?_?)\Q$sProductRef\E\_/ )
{
my $sVariantSpec = $';
my $cnt = $sVariantSpec =~ tr/_/_/;
if( $cnt == 0 )
{
$VariantList->[$sVariantSpec] = $::g_InputHash{$k};
$sLine .= "<INPUT TYPE=HIDDEN NAME=\"v_$sProductRef" . "_" . "$sVariantSpec\" VALUE=\"$::g_InputHash{$k}\">";
}
elsif( $cnt == 1 )
{
my ($sAttribute,$sValue) = split('_',$sVariantSpec);
$VariantList->[$sAttribute] = $sValue;
$sLine .= "<INPUT TYPE=HIDDEN NAME=\"v_$sProductRef" . "_" . "$sAttribute\" VALUE=\"$sValue\">";
}
else
{
my @sVarSpecItems = split('_',$sVariantSpec);
for( $i=0; $i<=$#sVarSpecItems; $i+=2)
{
$VariantList->[$sVarSpecItems[$i]] = $sVarSpecItems[$i+1];
$sLine .= "<INPUT TYPE=HIDDEN NAME=\"v_$sProductRef" . "_" . "$sVarSpecItems[$i]\" VALUE=\"$sVarSpecItems[$i+1]\">";
}
}
}
}
return($VariantList, $sLine);
}
sub CaccGetCookies
{
my ($sCookie, $sCookies);
my $sReferer = ACTINIC::GetReferrer();
$sReferer =~ s/\?.*//;
if( $::g_InputHash{USER} and $::g_InputHash{HASH} and !$::g_InputHash{ORDERHASH})
{
return ($ACTINIC::B2B->Get('UserIDCookie'),$ACTINIC::B2B->Get('BaseFile'));
}
if( ACTINIC::IsStaticPage($sReferer) &&
$sReferer != "/")
{
$ACTINIC::B2B->Clear('BaseFile');
$ACTINIC::B2B->Clear('UserIDCookie');
$ACTINIC::B2B->Clear('UserName');
$ACTINIC::B2B->Set('ClearIDCookie','CLEAR');
$ACTINIC::B2B->Set('ClearUserCookie','CLEAR');
return ('','');
}
$sCookies = $::ENV{'HTTP_COOKIE'};
my (@CookieList) = split(/;/, $sCookies);
my ($sDigest,$sBaseFile);
foreach $sCookie (@CookieList)
{
$sCookie =~ s/^\s*//;
if( $sCookie =~ /^ACTINIC_BUSINESS/ )
{
my ($sLabel, $sCookieValue) = split (/=/, $sCookie);
$sCookieValue =~ s/^\s*\"?//;
$sCookieValue =~ s/\"?\s*$//;
my $sCookieText = ACTINIC::DecodeText($sCookieValue, $ACTINIC::FORM_URL_ENCODED);
my (@Fields) = split("\n",$sCookieText);
my $sField;
foreach $sField (@Fields)
{
my ($sName,$sData) = split("\t",$sField);
$sData =~ s/^\s*\"?//;
$sData =~ s/\"?\s*$//;
if( $sData eq "" )
{
next;
}
for ($sName)
{
/^ACCOUNT/ and do
{
$sDigest = $sData;
last;
};
/^BASEFILE/ and do
{
$sBaseFile = $sData;
last;
};
/^USERNAME/ and do
{
$ACTINIC::B2B->Set('UserName',$sData);
last;
};
/^PRODUCTPAGE/ and do
{
$ACTINIC::B2B->Set('ProductPage',$sData);
last;
};
/^CHALLENGE/ and do
{
$ACTINIC::B2B->Set('UserKey',$sData);
last;
};
last;
}
}
last;
}
}
if( !$sDigest )
{
$ACTINIC::B2B->Clear('UserIDCookie');
$ACTINIC::B2B->Clear('UserName');
$ACTINIC::B2B->Clear('UserDigest');
$ACTINIC::B2B->Clear('ProductPage');
return ('',$sBaseFile);
}
return ($sDigest,$sBaseFile);
}
sub IsPartOfFrameset
{
my $sOrderScript = sprintf("os%6.6d%s",$$::g_pSetupBlob{CGI_ID},$$::g_pSetupBlob{CGI_EXT});
if( ($::g_InputHash{USER} and $::g_InputHash{HASH}) or
(!IsCatalogFramed() && !$$::g_pSetupBlob{CLEAR_ALL_FRAMES}) or
($::prog_name =~ /^ORDERSCR/ and
$$::g_pSetupBlob{UNFRAMED_CHECKOUT} ) )
{
return $::FALSE;
}
return $::TRUE;
}
sub CAccBusinessCookie
{
my $sCookie = "";
$sCookie .= "BASEFILE\t" . $ACTINIC::B2B->Get('BaseFile') .	"\n";
if ( $ACTINIC::B2B->Get('ClearIDCookie') )
{
return (ACTINIC::EncodeText2($sCookie,0));
}
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if ( $sDigest )
{
if ( $sDigest eq "." )
{
$sDigest = "";
}
if( $sDigest eq "" )
{
return (ACTINIC::EncodeText2($sCookie,0));
}
$sCookie .= "ACCOUNT\t$sDigest\n";
}
else
{
return ("-");
}
if ( $ACTINIC::B2B->Get('ClearUserCookie') )
{
$sCookie .= "USERNAME\t\n";
}
else
{
$sCookie .= "USERNAME\t" . $ACTINIC::B2B->Get('UserName') . "\n";
}
$sCookie .= "PRODUCTPAGE\t" . $ACTINIC::B2B->Get('ProductPage') .	"\n";
$sCookie .= "CHALLENGE\t" . $ACTINIC::B2B->Get('UserKey') . "\n";
return (ACTINIC::EncodeText2($sCookie,0));
}
sub CAccLogin
{
my ($sDigest,$sBaseFile,$Md5, $bLoggingIn);
$ACTINIC::B2B->Clear('UserIDCookie');
if( $::g_InputHash{USER} and $::g_InputHash{HASH} )
{
$sBaseFile = ACTINIC::GetReferrer();
$sDigest = $::g_InputHash{HASH};
$ACTINIC::B2B->Set('UserIDCookie',$sDigest);
$ACTINIC::B2B->Set('UserName',$::g_InputHash{USER});
$ACTINIC::B2B->Set('BaseFile', $sBaseFile);
if( $::g_InputHash{challengeout} )
{
$ACTINIC::B2B->Set('UserKey',$::g_InputHash{challengeout});
}
else
{
$ACTINIC::B2B->Set('UserKey',$::g_InputHash{challenge});
}
$bLoggingIn = $::TRUE;
$::g_bJustAfterLogin = $::TRUE;
}
else
{
$bLoggingIn = $::FALSE;
my $sReferer = ACTINIC::GetReferrer();
$sReferer =~ s/\?.*//;
if( ACTINIC::IsStaticPage($sReferer) &&
$sReferer != "/")
{
$sDigest = "";
$ACTINIC::B2B->Clear('BaseFile');
$ACTINIC::B2B->Clear('UserIDCookie');
$ACTINIC::B2B->Set('ClearIDCookie','CLEAR');
$ACTINIC::B2B->Set('ClearUserCookie','CLEAR');
}
else
{
($sDigest,$sBaseFile) = ACTINIC::CaccGetCookies();
$ACTINIC::B2B->Set('BaseFile',$sBaseFile);
}
}
my ($Status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sDigest, ACTINIC::GetPath());
if ($Status == $::BADDATA)
{
my ($Status, $sMessage, $sHTML) = ACTINIC::BounceToPageEnhanced(7, ACTINIC::GetPhrase(-1, 1962) . $sMessage . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2055),
'',
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob,
$::g_sWebSiteUrl.$$::g_pSetupBlob{B2B_LOGONPAGE},
\%::g_InputHash);
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
ACTINIC::UpdateDisplay($sHTML, $::g_OriginalInputData, $::Session->GetSessionID());
exit;
}
if ($Status != $::SUCCESS &&
$Status != $::NOTFOUND)
{
my ($Status, $sMessage, $sHTML) = ACTINIC::ReturnToLastPage(7, ACTINIC::GetPhrase(-1, 1962) . $sMessage . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2055), ACTINIC::GetPhrase(-1, 141),
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, \%::g_InputHash);
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
ACTINIC::UpdateDisplay($sHTML, $::g_OriginalInputData, $::Session->GetSessionID());
exit;
}
if( $sDigest &&
$Status != $::NOTFOUND)
{
my $pAccount;
($Status, $sMessage, $pAccount) = ACTINIC::GetCustomerAccount($$pBuyer{AccountID}, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
my ($Status, $sMessage, $sHTML) = ACTINIC::ReturnToLastPage(7, ACTINIC::GetPhrase(-1, 1962) . $sMessage . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2055), ACTINIC::GetPhrase(-1, 141),
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, \%::g_InputHash);
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
ACTINIC::UpdateDisplay($sHTML, $::g_OriginalInputData, $::Session->GetSessionID());
exit;
}
if( $$pAccount{Status} != 0 )
{
my ($Status, $sError, $sHTML) = ACTINIC::BounceToPageEnhanced(7, ACTINIC::GetPhrase(-1, 1962) . ACTINIC::GetPhrase(-1, 214, $$pAccount{AccountName}) . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2055),
'',
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob,
$::g_sWebSiteUrl.$$::g_pSetupBlob{B2B_LOGONPAGE},
\%::g_InputHash);
ACTINIC::PrintPage($sHTML, $::Session->GetSessionID(), $::FALSE);
exit;
}
elsif ( $$pBuyer{Status} != 0 )
{
my ($Status, $sError, $sHTML) = ACTINIC::BounceToPageEnhanced(7, ACTINIC::GetPhrase(-1, 1962) . ACTINIC::GetPhrase(-1, 215, $$pBuyer{Name},$$pAccount{AccountName}) . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2055),
'',
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob,
$::g_sWebSiteUrl.$$::g_pSetupBlob{B2B_LOGONPAGE},
\%::g_InputHash);
ACTINIC::PrintPage($sHTML, $::Session->GetSessionID(), $::FALSE);
exit;
}
$ACTINIC::B2B->Set('UserDigest',$sDigest);
if($bLoggingIn)
{
($Status, $sMessage) = CaccSetCheckoutFields($pBuyer, $pAccount);
if($Status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
$::Session->SetDigest($sDigest);
}
ACTINIC::CloseCustomerAddressIndex(); # The customer index is left open for multiple access, so clean it up here
}
else
{
my $sMessage;
if ($sDigest)
{
$sMessage = ACTINIC::GetPhrase(-1, 216);
}
else
{
$sMessage = ACTINIC::GetPhrase(-1, 52);
}
RecordErrors($sMessage, ACTINIC::GetPath());
$::g_sContentUrl = $::Session->GetBaseUrl();
if ($::g_sContentUrl =~ /\/$/)
{
$::g_sContentUrl .= $$::g_pSetupBlob{B2B_LOGONPAGE};
}
my ($Status, $sError, $sHTML) = ACTINIC::BounceToPageEnhanced(7, ACTINIC::GetPhrase(-1, 1962) . $sMessage . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2055), ACTINIC::GetPhrase(-1, 208),
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob,
$::g_sContentUrl,
\%::g_InputHash,$::TRUE);
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sError, ACTINIC::GetPath());
}
$::g_bLoginPage = $::TRUE;
PrintPage($sHTML, $::Session->GetSessionID(), $::TRUE);
exit;
}
}
sub CAccCatalogBody
{
my $sProductPage = $$::g_pSetupBlob{'CATALOG_PAGE'};
if( $::g_InputHash{PRODUCTPAGE} =~ /\S/ )
{
$sProductPage = $::g_InputHash{PRODUCTPAGE};
}
my $sFramePage = $sProductPage;
if( ACTINIC::IsCatalogFramed() )
{
$sFramePage = $$::g_pSetupBlob{FRAMESET_PAGE};
}
return ($sProductPage,$sFramePage);
}
sub CaccSetCheckoutFields
{
my ($pBuyer, $pAccount) = @_;
my ($Status, $sMessage, $pInvoiceAddress, $pDeliveryAddress, $nInvoiceAddressID, $nDeliveryAddressID);
my (%hashBillAddress, %hashShipAddress, %hashShipInfo, %hashTaxInfo,
%hashGeneralInfo, %hashPaymentInfo, %hashLocationInfo);
$nInvoiceAddressID = -1;
$nDeliveryAddressID = -1;
ActinicOrder::ParseAdvancedTax();
$hashBillAddress{'REMEMBERME'} = $::FALSE;
$hashBillAddress{'COMPANY'} = $pAccount->{AccountName};
$hashPaymentInfo{'METHOD'} 		= ActinicOrder::EnumToPaymentString($pAccount->{DefaultPaymentMethod});
$hashPaymentInfo{'SCHEDULE'} 	= $pAccount->{PriceSchedule};
if($pAccount->{InvoiceAddressRule} == 1)
{
$nInvoiceAddressID = $pAccount->{InvoiceAddress};
$hashBillAddress{'NAME'}		= $pAccount->{Name};
$hashBillAddress{'SALUTATION'}= $pAccount->{Salutation};
$hashBillAddress{'JOBTITLE'}	= $pAccount->{Title};
$hashBillAddress{'PHONE'}		= $pAccount->{TelephoneNumber};
$hashBillAddress{'FAX'}			= $pAccount->{FaxNumber};
$hashBillAddress{'EMAIL'}		= $pAccount->{EmailAddress};
}
else
{
if($pBuyer->{InvoiceAddressRule} == 0)
{
$nInvoiceAddressID = $pBuyer->{InvoiceAddressID};
}
$hashBillAddress{'NAME'}		= $pBuyer->{Name};
$hashBillAddress{'SALUTATION'}= $pBuyer->{Salutation};
$hashBillAddress{'JOBTITLE'}	= $pBuyer->{Title};
$hashBillAddress{'PHONE'}		= $pBuyer->{TelephoneNumber};
$hashBillAddress{'FAX'}			= $pBuyer->{FaxNumber};
$hashBillAddress{'EMAIL'}		= $pBuyer->{EmailAddress};
}
if($nInvoiceAddressID != -1)
{
($Status, $sMessage, $pInvoiceAddress) =
ACTINIC::GetCustomerAddress($pBuyer->{AccountID}, $nInvoiceAddressID, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return($Status, $sMessage);
}
$hashBillAddress{'ADDRESS1'}				= $pInvoiceAddress->{Line1};
$hashBillAddress{'ADDRESS2'}				= $pInvoiceAddress->{Line2};
$hashBillAddress{'ADDRESS3'}				= $pInvoiceAddress->{Line3};
$hashBillAddress{'ADDRESS4'}				= $pInvoiceAddress->{Line4};
$hashBillAddress{'COUNTRY'}				= ACTINIC::GetCountryName($pInvoiceAddress->{CountryCode});
$hashBillAddress{'POSTALCODE'}			= $pInvoiceAddress->{PostCode};
$hashLocationInfo{'INVOICEADDRESS4'}	= $pInvoiceAddress->{Line4};
$hashLocationInfo{'INVOICEPOSTALCODE'}	= $pInvoiceAddress->{PostCode};
$hashLocationInfo{'INVOICERESIDENTIAL'}	= $pInvoiceAddress->{nResidential};
$hashLocationInfo{INVOICE_COUNTRY_CODE}	= $pInvoiceAddress->{CountryCode};
$hashLocationInfo{INVOICE_REGION_CODE}  = $pInvoiceAddress->{StateCode} eq '' ?
$ActinicOrder::UNDEFINED_REGION :
$pInvoiceAddress->{StateCode};
if($::g_pTaxSetupBlob{TAX_BY} != $::eTaxByDelivery)
{
$hashTaxInfo{'EXEMPT1'} 	= $pInvoiceAddress->{ExemptTax1} == 0 ? $::FALSE : $::TRUE;
$hashTaxInfo{'EXEMPT2'} 	= $pInvoiceAddress->{ExemptTax2} == 0 ? $::FALSE : $::TRUE;
if($hashTaxInfo{'EXEMPT1'})
{
$hashTaxInfo{'EXEMPT1DATA'} 	= $pInvoiceAddress->{Tax1ExemptData};
}
if($hashTaxInfo{'EXEMPT2'})
{
$hashTaxInfo{'EXEMPT2DATA'} 	= $pInvoiceAddress->{Tax2ExemptData};
}
}
}
if($pBuyer->{DeliveryAddressRule} == 0)
{
$nDeliveryAddressID = $pBuyer->{DeliveryAddressID};
($Status, $sMessage, $pDeliveryAddress) =
ACTINIC::GetCustomerAddress($pBuyer->{AccountID}, $nDeliveryAddressID, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return($Status, $sMessage);
}
$hashShipAddress{'NAME'}		= $pBuyer->{Name};
$hashShipAddress{'SALUTATION'}= $pBuyer->{Salutation};
$hashShipAddress{'JOBTITLE'}	= $pBuyer->{Title};
$hashShipAddress{'PHONE'}		= $pBuyer->{TelephoneNumber};
$hashShipAddress{'FAX'}			= $pBuyer->{FaxNumber};
$hashShipAddress{'EMAIL'}		= $pBuyer->{EmailAddress};
$hashShipAddress{'ADDRESS1'}				= $pDeliveryAddress->{Line1};
$hashShipAddress{'ADDRESS2'}				= $pDeliveryAddress->{Line2};
$hashShipAddress{'ADDRESS3'}				= $pDeliveryAddress->{Line3};
$hashLocationInfo{'DELIVERADDRESS3'}	= $pDeliveryAddress->{Line3};
$hashShipAddress{'ADDRESS4'}				= $pDeliveryAddress->{Line4};
$hashLocationInfo{'DELIVERADDRESS4'}	= $pDeliveryAddress->{Line4};
$hashShipAddress{'COUNTRY'}				= ACTINIC::GetCountryName($pDeliveryAddress->{CountryCode});
$hashShipAddress{'POSTALCODE'}			= $pDeliveryAddress->{PostCode};
$hashLocationInfo{'DELIVERPOSTALCODE'}		= $pDeliveryAddress->{PostCode};
$hashLocationInfo{DELIVERY_COUNTRY_CODE}	= $pDeliveryAddress->{CountryCode};
$hashLocationInfo{DELIVERY_REGION_CODE} = $pDeliveryAddress->{StateCode} eq '' ?
$ActinicOrder::UNDEFINED_REGION :
$pDeliveryAddress->{StateCode};
if($nInvoiceAddressID != -1)
{
if($nInvoiceAddressID == $nDeliveryAddressID)
{
$hashLocationInfo{'SEPARATESHIP'}	= $::FALSE;
$hashShipAddress{'SEPARATESHIP'}		= $::FALSE;
}
else
{
$hashLocationInfo{'SEPARATESHIP'}	= $::TRUE;
$hashShipAddress{'SEPARATESHIP'}		= $::TRUE;
}
}
if($::g_pTaxSetupBlob{TAX_BY} == $::eTaxByDelivery)
{
$hashTaxInfo{'EXEMPT1'} 	= $pDeliveryAddress->{ExemptTax1} == 0 ? $::FALSE : $::TRUE;
$hashTaxInfo{'EXEMPT2'} 	= $pDeliveryAddress->{ExemptTax2} == 0 ? $::FALSE : $::TRUE;
if($hashTaxInfo{'EXEMPT1'})
{
$hashTaxInfo{'EXEMPT1DATA'} 	= $pDeliveryAddress->{Tax1ExemptData};
}
if($hashTaxInfo{'EXEMPT2'})
{
$hashTaxInfo{'EXEMPT2DATA'} 	= $pDeliveryAddress->{Tax2ExemptData};
}
}
}
my @Response = $::Session->UpdateCheckoutInfo(
\%hashBillAddress, \%hashShipAddress, \%hashShipInfo, \%hashTaxInfo,
\%hashGeneralInfo, \%hashPaymentInfo, \%hashLocationInfo);
if ($Response[0] != $::SUCCESS)
{
return (@Response);
}
no strict 'refs';
%::g_BillContact	= %hashBillAddress;
%::g_ShipContact	= %hashShipAddress;
%::g_ShipInfo		= %hashShipInfo;
%::g_TaxInfo		= %hashTaxInfo;
%::g_GeneralInfo	= %hashGeneralInfo;
%::g_PaymentInfo	= %hashPaymentInfo;
%::g_LocationInfo = %hashLocationInfo;
return($::SUCCESS, '');
}
sub CAccFindUser
{
my ($sDigest,$sBaseFile) = ACTINIC::CaccGetCookies();
if (!$sDigest)
{
return ("");
}
my ($Status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sDigest, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return ("");
}
my $pAccount;
($Status, $sMessage, $pAccount) = ACTINIC::GetCustomerAccount($$pBuyer{AccountID}, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
return ("");
}
if( $$pAccount{Status} == 0 &&
$$pBuyer{Status} == 0 )
{
$ACTINIC::B2B->Set('BaseFile',$sBaseFile);
return ($sDigest);
}
return ("");
}
sub ParseXML
{
my $sHTML = shift;
my $sDigest = $ACTINIC::B2B->Get('UserDigest');
if( !$sDigest )
{
$sDigest = $ACTINIC::B2B->Set('UserDigest',ACTINIC::CAccFindUser());
}
if( $sDigest )
{
my ($Status, $sMessage, $pBuyer) = ACTINIC::GetBuyer($sDigest, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
my $pAccount;
($Status, $sMessage, $pAccount) = ACTINIC::GetCustomerAccount($$pBuyer{AccountID}, ACTINIC::GetPath());
if ($Status != $::SUCCESS)
{
ACTINIC::ReportError($sMessage, ACTINIC::GetPath());
}
my $sBuyer = $$pBuyer{Name};
my $sAccount = $$pAccount{AccountName};
$ACTINIC::B2B->SetXML('BUYER',      $sBuyer);
$ACTINIC::B2B->SetXML('ACCOUNT',    $sAccount);
$ACTINIC::B2B->SetXML('NOWSERVING', ACTINIC::GetPhrase(-1, 212, ACTINIC::GetPhrase(-1, 1968, $$::g_pSetupBlob{FOREGROUND_COLOR}), $sBuyer, ACTINIC::GetPhrase(-1, 1970)));
$ACTINIC::B2B->SetXML('CURRACCOUNT',ACTINIC::GetPhrase(-1, 213, ACTINIC::GetPhrase(-1, 1968, $$::g_pSetupBlob{FOREGROUND_COLOR}), $sAccount, ACTINIC::GetPhrase(-1, 1970)));
$ACTINIC::B2B->SetXML('WELCOME',    ACTINIC::GetPhrase(-1, 210, $$::g_pSetupBlob{FORM_BACKGROUND_COLOR}, ACTINIC::GetPhrase(-1, 1969, $$::g_pSetupBlob{FOREGROUND_COLOR}), $sBuyer, ACTINIC::GetPhrase(-1, 1970)));
my $sShop = $::g_InputHash{SHOP} ? '&SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) : '';
my $sTarget = '_self';
my $sOrderScript = sprintf("os%6.6d%s",$$::g_pSetupBlob{CGI_ID},$$::g_pSetupBlob{CGI_EXT});
if( ACTINIC::IsCatalogFramed() and
!(($::ENV{SCRIPT_NAME} =~ /\/$sOrderScript$/ and
$$::g_pSetupBlob{UNFRAMED_CHECKOUT} )) )
{
$sTarget = '_parent';
}
$ACTINIC::B2B->SetXML('LOGOUT', ACTINIC::GetPhrase(-1, 2283, $::g_sAccountScript, $sShop, $sTarget,
ACTINIC::GetPhrase(-1, 217, ACTINIC::GetPhrase(-1, 1968, $$::g_pSetupBlob{LINK_COLOR}),
ACTINIC::GetPhrase(-1, 1970))));
$ACTINIC::B2B->SetXML('LOGOUT_SIMPLE',
"&nbsp;<A HREF=\"$::g_sAccountScript\?ACTION=LOGOUT" .
$sShop
. '" TARGET="' . $sTarget . '">'
. ACTINIC::GetPhrase(-1, 217, ACTINIC::GetPhrase(-1, 1968, $$::g_pSetupBlob{LINK_COLOR}), ACTINIC::GetPhrase(-1, 1970))
. "</A>");
$sTarget = '_self';
if( ACTINIC::IsBrochureFramed())
{
$sTarget = '_parent';
}
$ACTINIC::B2B->SetXML('BROCHURE_LOGOUT', ACTINIC::GetPhrase(-1, 2283, $::g_sAccountScript, $sShop, $sTarget,
ACTINIC::GetPhrase(-1, 217, ACTINIC::GetPhrase(-1, 1968, $$::g_pSetupBlob{LINK_COLOR}),
ACTINIC::GetPhrase(-1, 1970))));
$ACTINIC::B2B->SetXML('BROCHURE_LOGOUT_SIMPLE',
"&nbsp;<A HREF=\"$::g_sAccountScript\?ACTION=LOGOUT" .
$sShop
. '" TARGET="' . $sTarget . '">'
. ACTINIC::GetPhrase(-1, 217, ACTINIC::GetPhrase(-1, 1968, $$::g_pSetupBlob{LINK_COLOR}), ACTINIC::GetPhrase(-1, 1970))
. "</A>");
}
return (ParseXMLCore($sHTML));
}
sub ParseXMLCore
{
my $sStringToParse = shift;
eval
{
require ax000001;
};
if ($@)
{
ReportError($@, GetPath());
}
my $pXML = new ACTINIC_PXML();
my ($sParsedHTML, $pTree) = $pXML->Parse($sStringToParse);
return ($sParsedHTML);
}
sub PreProcessXMLTemplateString
{
my $sStringToParse = shift;
eval
{
require ax000001;
};
if ($@)
{
ReportError($@, GetPath());
}
my $pXML = new PXML();
my @Response = $pXML->Parse($sStringToParse, "Actinic:");
return (@Response);
}
sub PreProcessXMLTemplate
{
my $sFilename = shift;
eval
{
require ax000001;
};
if ($@)
{
return ($::FAILURE, $@);
}
my $pXML = new PXML();
my @Response = $pXML->ParseFile($sFilename, "Actinic:");
return (@Response);
}
sub ReplaceActinicVars
{
my ($sText, $rhValues) = @_;
my $sVarPrefix = 'Actinic:';
my $sSubstituted = '';
while ($sText =~ m|(<\s*$sVarPrefix)(\w+)|)
{
$sSubstituted .= $`;
if (defined $rhValues->{$2})
{
my $sVarName = $2;
$sSubstituted .= $rhValues->{$2};
$sText = substr($sText, (length $`) + length($1) + length($2));
if ($sText =~ m|(^[^>]*?/>)|)
{
$sText = substr($sText, length($1));
}
elsif ($sText =~ m|(<\s*/$sVarPrefix$sVarName\s*>)|)
{
$sText = substr($sText, (length $`) + length($1));
}
}
else
{
$sSubstituted .= $1 . $2;
$sText = substr($sText, (length $`) + length($1) + length($2));
if ($sText =~ m|(^[^>]*?>)|)
{
$sSubstituted .= $1;
$sText = substr($sText, length($1));
}
}
}
$sSubstituted .= $sText;
return ($::SUCCESS, '', $sSubstituted);
}
sub GetDigitalContent
{
my ($pCartList) = shift;
my ($bAlways) = shift;
my $pOrderDetail;
my @Response;
my $nExpiry;
if (!defined $bAlways ||
length $bAlways == 0)
{
$bAlways = $::FALSE;
}
$nExpiry = $$::g_pSetupBlob{'DD_EXPIRY_TIME'};
if (($nExpiry <= 0) ||
(!$::Session->IsPaymentMade() &&
($bAlways != $::TRUE))	||
$::Session->IsIPCheckFailed())
{
return($::SUCCESS, "", {}, 0);
}
my @ProdRefs;
foreach $pOrderDetail (@$pCartList)
{
push @ProdRefs, $$pOrderDetail{'PRODUCT_REFERENCE'};
my %CurrentItem = %$pOrderDetail;
my ($Status, $Message, $sSectionBlobName) = ACTINIC::GetSectionBlobName($CurrentItem{SID});
if ($Status == $::FAILURE)
{
return ($Status, $Message);
}
@Response = ACTINIC::GetProduct($CurrentItem{"PRODUCT_REFERENCE"}, $sSectionBlobName,
ACTINIC::GetPath());
my $pProduct;
($Status, $Message, $pProduct) = @Response;
if ($Status == $::FAILURE)
{
return (@Response);
}
if( $pProduct->{COMPONENTS} )
{
my $VariantList = ActinicOrder::GetCartVariantList(\%CurrentItem);
my %Component;
my $pComponent;
my $nIndex = 1;
foreach $pComponent (@{$pProduct->{COMPONENTS}})
{
@Response = ActinicOrder::FindComponent($pComponent, $VariantList);
($Status, %Component) = @Response;
if ($Status != $::SUCCESS)
{
return ($Status, $Component{text}, {}, 0);
}
push @ProdRefs, $Component{code};
}
}
}
eval "require dd000001;";
if ($@)
{
return ($::FAILURE, "Error loading digital download module. $@", {}, 0);
}
@Response = DigitalDownload::GetContentList($nExpiry, \@ProdRefs);
return(@Response);
}
package ACTINIC_B2B;
use strict;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $Self  = {};
bless ($Self, $Class);
$Self->{XML} = {};
return $Self;
}
sub Set
{
my $Self = shift;
my $sName = shift;
my $sValue = shift;
$Self->{$sName} = $sValue;
return $sValue;
}
sub Clear
{
my $Self = shift;
my $sName = shift;
$Self->{$sName} = undef;
}
sub Get
{
my $Self = shift;
my $sName = shift;
return $Self->{$sName};
}
sub SetXML
{
my $Self = shift;
my $sName = shift;
my $sValue = shift;
$Self->{XML}->{$sName} = $sValue;
return $sValue;
}
sub AppendXML
{
my $Self = shift;
my $sName = shift;
my $sValue = shift;
$Self->{XML}->{$sName} .= $sValue;
return $Self->{XML}->{$sName};
}
sub GetXML
{
my $Self = shift;
my $sName = shift;
return $Self->{XML}->{$sName};
}
sub ClearXML
{
my $Self = shift;
$Self->{XML} = undef;
}
package SSLConnection;
use strict;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $Self  = {};
bless ($Self, $Class);
$Self->{_SERVER} = shift;
$Self->{_PORT} = shift;
$Self->{_PATH} = shift;
$Self->{_HEADER} = {};
$Self->{_METHOD} = "GET";
$Self->{_CONNECT_STATUS} = $::FALSE;
$Self->{_CONNECT_ERROR_MESSAGE} = "SSLConnection::SendRequest() must be called first.";
$Self->{_HEADER}->{"Content-Type"} = "application/x-www-form-urlencoded";
$Self->{_HEADER}->{"Accept"} = "*/*";
$Self->{_HEADER}->{"User-Agent"} = "ActinicEcommerce";
$Self->{_HEADER}->{"Connection"} = "close";
$Self->{_HEADER}->{"Pragma"} = "no-cache";
return $Self;
}
sub SetHeaderValue
{
my $Self = shift @_;
my $sParam = shift @_;
my $sValue = shift @_;
$Self->{_HEADER}->{$sParam} = $sValue;
}	
sub SetRequestMethod
{
my $Self = shift @_;
my $sMethod = shift @_;
$Self->{_METHOD} = $sMethod;
}	
sub GetConnectStatus
{
my $Self = shift @_;
return($Self->{_CONNECT_STATUS});
}	
sub GetResponseHeader
{
my $Self = shift @_;
return($Self->{_RESPONSE_HEADER_STRING});
}	
sub GetResponseContent
{
my $Self = shift @_;
return($Self->{_RESPONSE_CONTENT_STRING});
}	
sub GetHeaderHash
{
my $Self = shift @_;
return($Self->{_RESPONSE_HEADER_HASH});
}		
sub GetHeaderString
{
my $Self = shift @_;
my $sHeader;
my $sParam;
foreach $sParam (keys %{$Self->{_HEADER}})
{
$sHeader .= sprintf("%s: %s\r\n", $sParam, $Self->{_HEADER}->{$sParam});
}
return($sHeader);
}
sub SendRequest
{
my $Self = shift @_;
my $sContent = shift @_;
my ($nResult, $sMessage, $sResponse, $ssl_socket); 
($nResult, $sMessage, $sResponse, $ssl_socket) = ACTINIC::HTTPS_SendAndReceive(
$Self->{_SERVER}, 
$Self->{_PORT}, 
$Self->{_PATH}, 
$sContent,
$Self->{_METHOD},
$::TRUE,
$ssl_socket,
$Self->GetHeaderString());
if ($nResult != $::SUCCESS)
{
$Self->{_CONNECT_STATUS} = $::FALSE;
$Self->{_CONNECT_ERROR_MESSAGE} = $sMessage;
return;
}
(	$Self->{_CONNECT_STATUS}, 
$Self->{_CONNECT_ERROR_MESSAGE}, 
$Self->{_RESPONSE_HEADER_STRING}, 
$Self->{_RESPONSE_CONTENT_STRING}, 
$Self->{_RESPONSE_HEADER_HASH}) = ACTINIC::HTTP_SplitHeaderAndContent($sResponse);
return ($sMessage, $sResponse);
}
1;