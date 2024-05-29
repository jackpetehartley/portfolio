#!/usr/bin/perl
use strict;
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
Init();
DispatchCommands();
exit;
sub Init
{
$::prog_name = "MailScript";
$::prog_ver = '$Revision: 18819 $';
$::prog_ver = substr($::prog_ver, 11);
$::prog_ver =~ s/ \$//;
$::FALSE = 0;
$::TRUE = 1;
$::DOS_SLEEP_DURATION = 2;
$::FAILURE 	= 0;
$::SUCCESS 	= 1;
$::NOTFOUND = 2;
umask (0177);
$::g_nErrorNumber = 200;
$::PAD_SPACE = " " x 40;
$::g_sSmtpServer 	  = 'localhost';
$::g_bPathKnown = 0;
my ($status, $sError, $sEnv, $unused);
($status, $sError, $sEnv, $unused, %::g_InputHash) = ACTINIC::ReadAndParseInput();	
if ($::SUCCESS != $status)
{
$::g_sInternalErrors .= "Input is invalid ";
$::g_nErrorNumber = 581;
RecordErrors();
SendResponse();
exit;
}
ValidateInput();
($status, $sError) = ACTINIC::AuthenticateUser($::g_InputHash{USER}, $::g_InputHash{PASS});
if ($status != $::SUCCESS)
{
$::g_sInternalErrors .= "Authentication failed ($::g_InputHash{USER}, $::g_InputHash{PASS}), ";
$::g_nErrorNumber = 453;
RecordErrors();
SendResponse();
exit;
}	
$::g_sPath = ACTINIC::GetPath();
ACTINIC::SecurePath($::g_sPath);
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
my %SupportedCommands = map { $_ => 1 } qw ( send );
unless ($SupportedCommands{$::g_InputHash{ACTION}})
{
$::g_sInternalErrors .= "unknown command :$::g_InputHash{ACTION}:, ";
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
}
sub DispatchCommands
{
if ($::g_InputHash{ACTION} eq "send")
{
my @Response = ACTINIC::ReadPromptFile($::g_sPath);
if ($Response[0] == $::SUCCESS)
{
@Response = ACTINIC::SendRichMail($::g_sSmtpServer, $::sMailTo, $::sMailSubject, $::sMailText, $::sMailHTML, $::sMailReturn);
if ($Response[0] != $::SUCCESS)
{	
$::g_sInternalErrors .= $Response[1];
$::g_nErrorNumber = 583;	
$::g_Answer = $::sMailTo;
}
}
else
{
$::g_sInternalErrors .= $Response[1];
$::g_nErrorNumber = 999;	
$::g_Answer = $::sMailTo;
}
$::g_OutputData = $Response[1];
}
else
{
$::g_sInternalErrors .= "script exception, ";
$::g_nErrorNumber = 999;
$::g_Answer = $::sMailTo;
}
RecordErrors();
SendResponse();
}
sub RecordErrors
{
if ( (length $::g_sInternalErrors) > 0 &&
$::g_bPathKnown)
{
ACTINIC::RecordErrors($::g_sInternalErrors, $::g_sPath);
}
}
sub ValidateInput
{
$::sMailTo			= $::g_InputHash{TO}; 
$::sMailSubject	= $::g_InputHash{SUBJECT};
$::sMailReturn		= $::g_InputHash{RETURN};
$::sMailText		= $::g_InputHash{TEXTDATA};
$::sMailHTML		= $::g_InputHash{HTMLDATA};
if ( (length $::sMailTo) < 5)
{
$::g_sInternalErrors .= "E-mail address too short (" . ($::sMailTo) . "), ";
$::g_nErrorNumber = 580;
}
if ((length $::sMailText) == 0 &&
(length $::sMailHTML) == 0)
{
$::g_sInternalErrors .= "The mail content is not defined (can't send empty mails) ";
$::g_nErrorNumber = 582;
}	
if ($::sMailHTML eq ' ')
{
$::sMailHTML = '';
}
if ( (length $::g_InputHash{USER}) > 12)
{
$::g_sInternalErrors .= "Parameters too large, user too long (" . (length $::g_InputHash{USER}) . "), ";
$::g_nErrorNumber = 455;
}
if ( (length $::g_InputHash{PASS}) > 12)
{
$::g_sInternalErrors .= "Parameters too large, password too long (" . (length $::g_InputHash{PASS}) . "), ";
$::g_nErrorNumber = 455;
}
}
sub SendResponse
{
if ($::g_Answer eq "")
{
$::g_Answer = substr($::PAD_SPACE,0,16);
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
ACTINIC::PrintHeader('application/octet-stream', (length $SResponse), undef, $::FALSE);
print $SResponse;
}