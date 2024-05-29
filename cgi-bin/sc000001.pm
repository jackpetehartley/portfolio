#!perl
package ActinicSSL;
require 5.002;
push (@INC, "cgi-bin");
use Socket;
use strict;
require al000001;
require ac000001;
$ActinicSSL::RAND_POOL = [];
$ActinicSSL::RAND_CNT = 0;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $sServer = shift;
my $sPort = shift;
my $Self  = {};
bless ($Self, $Class);
my ($nResult, $sMessage) = $Self->open($sServer, $sPort);
if ($nResult != $::SUCCESS)
{
$! = $sMessage;
return ($nResult, $sMessage);
}
$Self->{_PEND} = undef;
$Self->{_PENDLEN} = 0;
$Self->{_PENDSTART} = 0;
$Self->{_HANDSHAKES} = undef;
$Self->{_SERVER_RANDOM}[31] = undef;
$Self->{_CLIENT_RANDOM}[31] = undef;
$Self->{_SERVER_KEY_EXCHANGE} = undef;
$Self->{_CERT_REQUESTED} = $::FALSE;
$Self->{_SERVER_CERT} = undef;
$Self->{_SEQ_NUM_READ} = 0;
$Self->{_SEQ_NUM_WRITE} = 0;
$Self->{_MASTER_SECRET} = undef;
$Self->{_CLIENT_WRITE_MAC_SECRET}[15] = shift;
$Self->{_SERVER_WRITE_MAC_SECRET}[15] = shift;
$Self->{_CLIENT_WRITE_KEY} = undef;
$Self->{_SERVER_WRITE_KEY} = undef;
$Self->{_PAD1}[47] = undef;
$Self->{_PAD2}[47] = undef;
$Self->{_PAD1_SHA}[39] = undef;
$Self->{_PAD2_SHA}[39] = undef;
$Self->{_RC4_READ} = undef;
$Self->{_RC4_WRITE} = undef;
$Self->{_MASTER_MD5} = instantiateMD5Object();
$Self->{_MASTER_SHA1} = instantiateSHA1Object();
$Self->init();
($nResult, $sMessage) = $Self->negotiate();
if ($nResult != $::SUCCESS)
{
return $::FAILURE, $sMessage;
}
return ($::SUCCESS, '', $Self);
}
sub instantiateMD5Object
{
my $sClassName;
eval
{
require Digest::MD5;
$sClassName = 'Digest::MD5';
};
if ($@)
{
require di000001;
$sClassName = 'Digest::Perl::MD5';
}
return $sClassName->new();
}
sub instantiateSHA1Object()
{
my $sClassName;
eval
{
require Digest::SHA1;
$sClassName = 'Digest::SHA1';
};
if ($@)
{
return SHA1Digest::new('SHA1Digest');
}
return $sClassName->new();
}
sub init
{
my $Self = shift;
my $i;
for($i = 0; $i < scalar(@{$Self->{_PAD1}}); $i++)
{
$Self->{_PAD1}->[$i] = 0x36;
}
for($i = 0; $i < scalar(@{$Self->{_PAD2}}); $i++)
{
$Self->{_PAD2}->[$i] = 0x5C;
}
for($i = 0; $i < scalar(@{$Self->{_PAD1_SHA}}); $i++)
{
$Self->{_PAD1_SHA}->[$i] = 0x36;
}
for($i = 0; $i < scalar(@{$Self->{_PAD2_SHA}}); $i++)
{
$Self->{_PAD2_SHA}->[$i] = 0x5C;
}
my $md5 = instantiateMD5Object();
Utils::getRandomBytes($ActinicSSL::RAND_POOL, 0, 10);
$md5->add(Utils::ByteArrayToString($ActinicSSL::RAND_POOL));
my $gmt = time();
$ActinicSSL::RAND_POOL = Utils::intToBytes($gmt, 4);
$md5->add(Utils::ByteArrayToString($ActinicSSL::RAND_POOL));
Utils::getRandomBytes($ActinicSSL::RAND_POOL, 0, 4);
$md5->add(Utils::ByteArrayToString($ActinicSSL::RAND_POOL));
Utils::getRandomBytes($ActinicSSL::RAND_POOL, 0, 4);
$md5->add(Utils::ByteArrayToString($ActinicSSL::RAND_POOL));
Utils::getRandomBytes($ActinicSSL::RAND_POOL, 0, 4);
$md5->add(Utils::ByteArrayToString($ActinicSSL::RAND_POOL));
$ActinicSSL::RAND_POOL = Utils::StringToByteArray($md5->digest());
return ($::SUCCESS, '');
}
sub negotiate
{
my $Self = shift;
my ($nResult, $sMessage) = $Self->writeClientHello();
if ($nResult != $::SUCCESS)
{
return ($::FAILURE, $sMessage);
}
($nResult, $sMessage) = $Self->readServerHandShakes();
if ($nResult != $::SUCCESS)
{
return ($::FAILURE, $sMessage);
}
($nResult, $sMessage) = $Self->sendClientHandshakes();
if ($nResult != $::SUCCESS)
{
return ($::FAILURE, $sMessage);
}
($nResult, $sMessage) = $Self->readServerFinished();
if ($nResult != $::SUCCESS)
{
return ($::FAILURE, $sMessage);
}
return ($::SUCCESS, '');
}
sub writeClientHello
{
my $Self = shift;
my @out;
push @out, 0x03;
push @out, 0x00;
$Self->{_CLIENT_RANDOM} = [];
my $gmt = time();
my $raBytes = Utils::intToBytes($gmt, 4);
push @{$Self->{_CLIENT_RANDOM}}, @$raBytes;
my $i;
my $random_byte;
for ($i = 0; $i < 28; $i++)
{
$random_byte = int(rand(256));
push @{$Self->{_CLIENT_RANDOM}}, $random_byte;
}
push @out, @{$Self->{_CLIENT_RANDOM}};
push @out, 0x00;
push @out, 0x00;
push @out, 0x04;
push @out, 0x00;
push @out, 0x04;
push @out, 0x00;
push @out, 0x03;
push @out, 0x01;
push @out, 0x00;
my ($nResult, $sMessage) = $Self->writeHandShake(1, \@out);
return ($nResult, $sMessage);
}
sub readServerHandShakes
{
my $Self = shift;
my ($nResult, $sMessage);
while ($::TRUE)
{
my $raRecord;
($nResult, $sMessage, $raRecord) = $Self->readHandShake();
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
push @{$Self->{_HANDSHAKES}}, @$raRecord;
my @aData;
Utils::arrayCopy($raRecord, 4, \@aData, 0, scalar(@$raRecord) - 4);
my $type = $$raRecord[0];
if ($type == 2)
{
my $ver_major = $$raRecord[4];
my $ver_minor = $$raRecord[5];
my $server_random_length = 32;
Utils::arrayCopy($raRecord, 6, $Self->{_SERVER_RANDOM}, 0, $server_random_length);
my $info_idx_base = 6 + $server_random_length + $$raRecord[6 + $server_random_length];
my $chiper_high = $$raRecord[$info_idx_base + 1];
my $chiper_low = $$raRecord[$info_idx_base + 2];
if ($chiper_low != 0x04 && $chiper_high == 0x00) # NOT SSL_RSA_WITH_RC4_128_MD5
{
return ($::FAILURE, 'Unimplemented encryption method requested.');
}
my $compressionMethod = $$raRecord[$info_idx_base + 3];
if ($compressionMethod != 0x0)
{
return ($::FAILURE, 'No compression method is implemented.');
}
next;
}
if ($type == 11)
{
my $numcertbytes = (($$raRecord[4] & 0xff) << 16) | (($$raRecord[5] & 0xff) << 8) | ($$raRecord[6] & 0xff);
my $numcerts = 0;
my $last_cert;
my $this_cert;
my $i;
for ($i = 0; $i < $numcertbytes;)
{
my $certlen = (($$raRecord[7 + $i] & 0xff) << 16) | (($$raRecord[7 + $i + 1] & 0xff) << 8) | ($$raRecord[7 + $i + 2] & 0xff);
my @aRecord = @$raRecord[(7 + $i + 3)..(7 + $i + 3 + $certlen - 1)];
my $dIn = DERInputStream::new('DERInputStream', \@aRecord);
$this_cert = X509CertificateStructure::new('X509CertificateStructure', $dIn->readObject());
if (!defined($Self->{_SERVER_CERT}))
{
$Self->{_SERVER_CERT} = $this_cert;
last;
}
else
{
if ($certlen + 3 + $i < $numcertbytes)
{
}
my $bIsSignedBy;
($nResult, $sMessage, $bIsSignedBy) = $Self->isSignedBy($last_cert, $this_cert->getSubjectPublicKeyInfo());
if (!$bIsSignedBy)
{
return ($::FAILURE, "The server sent a broken chain of certificates");
}
}
$last_cert = $this_cert;
$i += $certlen + 3;
$numcerts++;
}
next;
}
if ($type == 12)
{
$Self->{_SERVER_KEY_EXCHANGE} = $raRecord;
next;
}
if ($type == 13)
{
$Self->{_CERT_REQUESTED} = $::TRUE;
next;
}
if ($type == 14)
{
return ($::SUCCESS, '');
}
return ($::FAILURE, "Invalid server response type: $type");
}
}
sub sendClientHandshakes
{
my $Self = shift;
my (@out, $nResult, $sMessage);
if ($Self->{_CERT_REQUESTED})
{
push @out, 0x0;
push @out, 0x0;
push @out, 0x0;
$Self->writeHandShake(11, \@out);
}
my @pre_master_secret = ();
$pre_master_secret[47] = undef;
$pre_master_secret[0] = 0x03;
$pre_master_secret[1] = 0x00;
Utils::getRandomBytes(\@pre_master_secret, 2, scalar(@pre_master_secret) - 2);
my $encrypted_pre_master_secret;
my $pki = $Self->{_SERVER_CERT}->getSubjectPublicKeyInfo();
my $rsa_pks = RSAPublicKeyStructure::new('RSAPublicKeyStructure', $pki->getPublicKey());
my $modulus = $rsa_pks->getModulus();
my $exponent = $rsa_pks->getPublicExponent();
if (defined($Self->{_SERVER_KEY_EXCHANGE}))
{
my $serverKeyExchange = $$Self->{_SERVER_KEY_EXCHANGE};
my $rsa = PKCS1::new('PKCS1', RSAEngine::new('RSAEngine'));
$rsa->init($::FALSE, RSAKeyParameters::new('RSAKeyParameters', $::FALSE, $modulus, $exponent));
$rsa = PKCS1::new('PKCS1', RSAEngine::new('RSAEngine'));
$rsa->init($::FALSE, RSAKeyParameters::new('RSAKeyParameters', $::FALSE, $modulus, $exponent));
my $modulus_size = (($$serverKeyExchange[4] & 0xff) << 8) | ($$serverKeyExchange[5] & 0xff);
my @b_modulus;
Utils::arrayCopy($serverKeyExchange, 6, \@b_modulus, 0, $modulus_size);
my $modulus = BigInteger::new('BigInteger', \@b_modulus);
my $exponent_size = (($$serverKeyExchange[6 + $modulus_size] & 0xff) << 8) | ($$serverKeyExchange[7 + $modulus_size] & 0xff);
my @b_exponent;
Utils::arrayCopy($serverKeyExchange, 8 + $modulus_size, \@b_exponent, 0, $exponent_size);
$exponent = BigInteger::new('BigInteger', \@b_exponent);
}
my $rsa = PKCS1::new('PKCS1', RSAEngine::new('RSAEngine'));
$rsa->init($::TRUE, RSAKeyParameters::new('RSAKeyParameters', $::FALSE, $modulus, $exponent));
($nResult, $sMessage, $encrypted_pre_master_secret) = $rsa->processBlock(\@pre_master_secret, 0, scalar(@pre_master_secret));
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
$Self->writeHandShake(16, $encrypted_pre_master_secret);
$Self->writeRecord([0x01], 0, 1, 20);
$Self->{_SEQ_NUM_WRITE} = 0;
push @{$Self->{_MASTER_SECRET}}, @{$Self->md5([\@pre_master_secret, $Self->sha([[0x41], \@pre_master_secret, $Self->{_CLIENT_RANDOM}, $Self->{_SERVER_RANDOM}])])};
push @{$Self->{_MASTER_SECRET}}, @{$Self->md5([\@pre_master_secret, $Self->sha([[0x42, 0x42], \@pre_master_secret, $Self->{_CLIENT_RANDOM}, $Self->{_SERVER_RANDOM}])])};
push @{$Self->{_MASTER_SECRET}}, @{$Self->md5([\@pre_master_secret, $Self->sha([[0x43, 0x43, 0x43], \@pre_master_secret, $Self->{_CLIENT_RANDOM}, $Self->{_SERVER_RANDOM}])])};
my $i = 0;
my $key_material = [];
for($i = 0; scalar(@$key_material) < 72; $i++)
{
my $crap = [];
my $j;
for($j = 0; $j < $i + 1; $j++)
{
$crap->[$j] = (0x41 + $i);
}
push @$key_material, @{$Self->md5([$Self->{_MASTER_SECRET}, $Self->sha([$crap, $Self->{_MASTER_SECRET}, $Self->{_SERVER_RANDOM}, $Self->{_CLIENT_RANDOM}])])};
}
$Self->{_CLIENT_WRITE_KEY} = [];
$Self->{_SERVER_WRITE_KEY} = [];
$Self->{_CLIENT_WRITE_MAC_SECRET} = [];
$Self->{_SERVER_WRITE_MAC_SECRET} = [];
Utils::arrayCopy($key_material, 0,  $Self->{_CLIENT_WRITE_MAC_SECRET}, 0, 16);
Utils::arrayCopy($key_material, 16, $Self->{_SERVER_WRITE_MAC_SECRET}, 0, 16);
Utils::arrayCopy($key_material, 32, $Self->{_CLIENT_WRITE_KEY}, 0, 16);
Utils::arrayCopy($key_material, 48, $Self->{_SERVER_WRITE_KEY}, 0, 16);
$Self->{_RC4_WRITE} = RC4Engine::new('RC4Engine');
$Self->{_RC4_WRITE}->init($::TRUE, $Self->{_CLIENT_WRITE_KEY});
$Self->{_RC4_READ} = RC4Engine::new('RC4Engine');
$Self->{_RC4_READ}->init($::FALSE, $Self->{_SERVER_WRITE_KEY});
my @handshakeData;
push @handshakeData, @{$Self->md5([$Self->{_MASTER_SECRET}, $Self->{_PAD2}, $Self->md5([$Self->{_HANDSHAKES}, [0x43, 0x4C, 0x4E, 0x54], $Self->{_MASTER_SECRET}, $Self->{_PAD1}])])};
push @handshakeData, @{$Self->sha([$Self->{_MASTER_SECRET}, $Self->{_PAD2_SHA}, $Self->sha([$Self->{_HANDSHAKES}, [0x43, 0x4C, 0x4E, 0x54], $Self->{_MASTER_SECRET}, $Self->{_PAD1_SHA}])])};
$Self->writeHandShake(20, \@handshakeData)
}
sub readServerFinished()
{
my $Self = shift;
my ($nResult, $sMessage);
my $rec;
($nResult, $sMessage, $rec) = $Self->readHandShake();
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
if ($rec->[0] != 20)
{
return ($::FAILURE, "SSLException: expecting server Finished message, but got message of type $rec->[0]");
}
my @expectedFinished;
push @expectedFinished, @{$Self->md5([$Self->{_MASTER_SECRET}, $Self->{_PAD2}, $Self->md5([$Self->{_HANDSHAKES}, [0x53, 0x52, 0x56, 0x52], $Self->{_MASTER_SECRET}, $Self->{_PAD1}])])};
push @expectedFinished, @{$Self->sha([$Self->{_MASTER_SECRET}, $Self->{_PAD2_SHA}, $Self->sha([$Self->{_HANDSHAKES}, [0x53, 0x52, 0x56, 0x52], $Self->{_MASTER_SECRET}, $Self->{_PAD1_SHA}])])};
my $i;
for($i = 0; $i < scalar(@expectedFinished); $i++)
{
if ($expectedFinished[$i] != $rec->[$i + 4])
{
return ($::FAILURE, "SSLException: server Finished message mismatch!");
}
}
return ($::SUCCESS, '');
}
sub isSignedBy
{
my $Self = shift;
my $signee = shift;
my $signer = shift;
my $hash;
my $signature_algorithm_oid = $signee->getSignatureAlgorithm()->getObjectId()->getId();
if ($signature_algorithm_oid == "1.2.840.113549.1.1.4")
{
return ($::FALSE, "Signature algorithm $signature_algorithm_oid is not implemented yet");
}
elsif ($signature_algorithm_oid == "1.2.840.113549.1.1.2")
{
return ($::FALSE, "Signature algorithm $signature_algorithm_oid is not implemented yet");
}
elsif ($signature_algorithm_oid == "1.2.840.113549.1.1.5")
{
$hash = $Self->instantiateSHA1Object();
}
else
{
return ($::FALSE, "Unsupported signature algorithm: $signature_algorithm_oid");
}
my $ED = $signee->getSignature()->getBytes();
my $pki = $signer;
my $rsa_pks = RSAPublicKeyStructure::new('RSAPublicKeyStructure', $pki->getPublicKey());
my $modulus = $rsa_pks->getModulus();
my $exponent = $rsa_pks->getPublicExponent();
my $rsa = PKCS1::new('PKCS1', RSAEngine::new('RSAEngine'));
$rsa->init($::FALSE, RSAKeyParameters::new('RSAKeyParameters', $::FALSE, $modulus, $exponent));
my ($nResult, $sMessage, $D) = $rsa->processBlock($ED, 0, scalar(@$ED)); #byte[]
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
my $beris = DERInputStream::new('DERInputStream', $D);
my $derob = $beris->readObject();
my $deros = $derob->getObjectAt(1);
my $MD = $deros->getOctets();
return ($::SUCCESS, '', $::TRUE);
}
sub open
{
my $Self = shift;
my $sServer = shift;
my $sPort = shift;
my $proto = getprotobyname('tcp');
my $ServerIP = inet_aton($sServer);
if (!defined $ServerIP)
{
return($::FAILURE, ACTINIC::GetPhrase(-1, 13, "$sServer: $!"));
}
my $sin = sockaddr_in($sPort, $ServerIP);
if (!defined $sin)
{
return($::FAILURE, ACTINIC::GetPhrase(-1, 14, $!));
}
my $ssl_socket = *SSLSOCKET;
unless (socket($ssl_socket, PF_INET, SOCK_STREAM, $proto))
{
return($::FAILURE, ACTINIC::GetPhrase(-1, 1935, $!));
}
unless (connect($ssl_socket, $sin))
{
my $sError = ACTINIC::GetPhrase(-1, 1934, $!);
close($ssl_socket);
return($::FAILURE, $sError);
}
my $old_fh = select($ssl_socket);
$| = 1; 		        # don't buffer output
select($old_fh);
binmode $ssl_socket;
$Self->{_SSLSOCKET} = $ssl_socket;
return ($::SUCCESS, '');
}
sub close
{
my $Self = shift;
my ($nResult, $sMessage);
($nResult, $sMessage) = $Self->send([0x1,0x0], 0, 2, 21);
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
my $ssl_socket = $Self->{_SSLSOCKET};
close($ssl_socket);
return ($::SUCCESS, '');
}
sub send
{
my $Self = shift;
my $sContent = shift;
my $payload = Utils::StringToByteArray($sContent);
return ($Self->writeRecord($payload, 0, scalar(@$payload), 23));
}
sub recv
{
my $Self = shift;
my ($nResult, $sMessage, $payload) = $Self->readRecord();
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
my $sResponse = Utils::ByteArrayToString($payload, 0, scalar(@$payload));
return ($::SUCCESS, '', $sResponse);
}
sub writeHandShake
{
my $Self = shift;
my $type = shift;
my $raPayload = shift;
my $ssl_socket = $Self->{_SSLSOCKET};
my $raBytes = Utils::intToBytes(scalar(@$raPayload), 3);
my @real_payload;
push @real_payload, $type & 0xFF;
push @real_payload, @$raBytes;
push @real_payload, @$raPayload;
push @{$Self->{_HANDSHAKES}}, @real_payload;
return $Self->writeRecord(\@real_payload, 0, scalar(@real_payload), 22);
}
sub writeRecord
{
my $Self = shift;
my $raPayload = shift;
my $off = shift;
my $len = shift;
my $type = shift;
my ($nResult, $sMessage);
my $ssl_socket = $Self->{_SSLSOCKET};
if ($len > (1 << 14))
{
($nResult, $sMessage) = $Self->writeRecord($raPayload, $off, (1 << 14), $type);
if ($nResult == $::SUCCESS)
{
($nResult, $sMessage) =	$Self->writeRecord($raPayload, $off + (1 << 14), $len - (1 << 14), $type);
}
return ($nResult, $sMessage);
}
my $value = 0x0300;
my $message = '';
$message .= chr($type);
$message .= Utils::ByteArrayToString(Utils::intToBytes($value, 2));
if (!defined($Self->{_RC4_WRITE}))
{
$message .= Utils::ByteArrayToString(Utils::intToBytes($len, 2));
my @payload = @$raPayload[($off)..($off + $len - 1)];
$message .= Utils::ByteArrayToString(\@payload);
}
else
{
my $MAC = $Self->computeMAC($type, $raPayload, $off, $len, $Self->{_CLIENT_WRITE_MAC_SECRET}, $Self->{_SEQ_NUM_WRITE});
my $encryptedPayload = [];
$encryptedPayload->[scalar(@$MAC) + $len - 1] = undef;
($nResult, $sMessage) = $Self->{_RC4_WRITE}->processBytes($raPayload, $off, $len, $encryptedPayload, 0);
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
($nResult, $sMessage) = $Self->{_RC4_WRITE}->processBytes($MAC, 0, scalar(@$MAC), $encryptedPayload, $len);
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
$message .= Utils::ByteArrayToString(Utils::intToBytes(scalar(@$encryptedPayload), 2));
$message .= Utils::ByteArrayToString($encryptedPayload);
}
print $ssl_socket $message;
$Self->{_SEQ_NUM_WRITE}++;
return ($::SUCCESS, '');
}
sub readHandShake
{
my $Self = shift;
my ($nResult, $sMessage);
my ($type, $len, @rec);
my ($len1, $len2, $len3);
my $ssl_socket = $Self->{_SSLSOCKET};
($nResult, $sMessage, $type) = $Self->readInput();
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
($nResult, $sMessage, $len1) = $Self->readInput();
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
($nResult, $sMessage, $len2) = $Self->readInput();
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
($nResult, $sMessage, $len3) = $Self->readInput();
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
$len = (($len1 & 0xff) << 16) | (($len2 & 0xff) << 8) | ($len3 & 0xff);
push @rec, $type;
push @rec, (($len & 0x00ff0000) >> 16) & 0xff;
push @rec, (($len & 0x0000ff00) >> 8) & 0xff;
push @rec, $len & 0x000000ff;
if ($len > 0)
{
($nResult, $sMessage) =	$Self->readInput(\@rec, 4, $len);
if ($nResult != $::SUCCESS)
{
return ($nResult, $sMessage);
}
}
return ($::SUCCESS, '', \@rec);
}
sub readRecord
{
my $Self = shift;
my $ssl_socket = $Self->{_SSLSOCKET};
my $type;
my $length = read($ssl_socket, $type, 1);
$type = ord($type);
if ($length != 1)
{
return ($::EOF, 'End of stream.');
}
my ($ver_major, $ver_minor);
$length = read($ssl_socket, $ver_major, 1);
$length = read($ssl_socket, $ver_minor, 1);
my ($lenBytes);
$length = read($ssl_socket, $lenBytes, 2);
my $sBytes = Utils::StringToByteArray($lenBytes);
my $len = Utils::bytesToInt($sBytes);
my $ret;
$length = read($ssl_socket, $ret, $len);
my $raPayload = Utils::StringToByteArray($ret);
if ($type == 20)
{
$Self->{_SEQ_NUM_READ} = 0;
return $Self->readRecord();
}
my $decrypted_payload = [];
if (!defined($Self->{_RC4_READ}))
{
$decrypted_payload = $raPayload;
}
else
{
$decrypted_payload->[$len - 16 - 1] = undef;
$Self->{_RC4_READ}->processBytes($raPayload, 0, $len - 16, $decrypted_payload, 0);
my $MAC = [];
$MAC->[15] = undef;
$Self->{_RC4_READ}->processBytes($raPayload, $len - 16, 16, $MAC, 0);
my $ourMAC = $Self->computeMAC($type, $decrypted_payload, 0, scalar(@$decrypted_payload), $Self->{_SERVER_WRITE_MAC_SECRET}, $Self->{_SEQ_NUM_READ}++);
my $i;
for($i = 0; $i < scalar(@$MAC); $i++)
{
if ($MAC->[$i] != $ourMAC->[$i])
{
return ($::FAILURE, "SSLException: MAC mismatch on byte $i: got $MAC->[$i] expecting $ourMAC->[$i]");
}
}
}
if ($type == 21)
{
if ($decrypted_payload->[1] > 1)
{
return ($::FAILURE, "SSLException : got SSL ALERT message, level=$decrypted_payload->[0] code=$decrypted_payload->[1]");
}
elsif ($decrypted_payload->[1] == 0)
{
return ($::EOF, "Server requested connection closure");
}
else
{
return $Self->readRecord();
}
}
elsif ($type == 22)
{
}
elsif ($type != 23)
{
return readRecord();
}
return ($::SUCCESS, '', $decrypted_payload);
}
sub readInput
{
my $Self = shift;
my $raBytes = shift;
my $off = shift;
my $len = shift;
if (defined($raBytes))
{
return $Self->readInputEx($raBytes, $off, $len);
}
my @aBytes;
my ($nResult, $sMessage, $length) = $Self->readInputEx(\@aBytes, 0, 1);
if ($length != 1 ||
$nResult != $::SUCCESS)
{
return ($::FAILURE, 'Read error', -1);
}
return ($::SUCCESS, '', $aBytes[0]);
}
sub readInputEx
{
my $Self = shift;
my $raBytes = shift;
my $off = shift;
my $len = shift;
my ($nResult, $sMessage);
if ($Self->{_PENDLEN} == 0)
{
($nResult, $sMessage, $Self->{_PEND}) = $Self->readRecord();
if (!defined($Self->{_PEND}) ||
$nResult != $::SUCCESS)
{
return ($::FAILURE, $sMessage, -1);
}
$Self->{_PENDSTART} = 0;
$Self->{_PENDLEN} = scalar(@{$Self->{_PEND}});
}
my $ret = $len <= $Self->{_PENDLEN} ? $len : $Self->{_PENDLEN};
Utils::arrayCopy($Self->{_PEND}, $Self->{_PENDSTART}, $raBytes, $off, $len);
$Self->{_PENDLEN} -= $ret;
$Self->{_PENDSTART} += $ret;
return ($::SUCCESS, '', $ret);
}
sub sha
{
my $Self = shift;
my $inputs = shift;
$Self->{_MASTER_SHA1}->reset();
my $i;
for($i = 0; $i < scalar(@$inputs); $i++)
{
$Self->{_MASTER_SHA1}->add(Utils::ByteArrayToString($inputs->[$i]));
}
return Utils::StringToByteArray($Self->{_MASTER_SHA1}->digest());
}
sub md5
{
my $Self = shift;
my $inputs = shift;
$Self->{_MASTER_MD5}->reset();
my $i;
for($i = 0; $i < scalar(@$inputs); $i++)
{
$Self->{_MASTER_MD5}->add(Utils::ByteArrayToString($inputs->[$i]));
}
return Utils::StringToByteArray($Self->{_MASTER_MD5}->digest());
}
sub computeMAC
{
my $Self = shift;
my $type = shift;
my $payload = shift;
my $off = shift;
my $len = shift;
my $MAC_secret = shift;
my $seq_num = shift;
my $MAC = [];
$MAC->[15] = undef;
my $md5 = instantiateMD5Object();
$md5->add(Utils::ByteArrayToString($MAC_secret));
$md5->add(Utils::ByteArrayToString($Self->{_PAD1}));
my $b = [];
push @$b, (0x00, 0x00, 0x00, 0x00);
push @$b, @{Utils::intToBytes($seq_num, 4)};
$b->[8] = $type;
my $len_bytes = Utils::intToBytes($len, 2);
Utils::arrayCopy($len_bytes, 0, $b, 9, 2);
$md5->add(Utils::ByteArrayToString($b));
my @aPayload = @$payload[($off)..($off + $len - 1)];
$md5->add(Utils::ByteArrayToString(\@aPayload));
$MAC = Utils::StringToByteArray($md5->digest());
$md5->reset();
$md5->add(Utils::ByteArrayToString($MAC_secret));
$md5->add(Utils::ByteArrayToString($Self->{_PAD2}));
$md5->add(Utils::ByteArrayToString($MAC));
$MAC = Utils::StringToByteArray($md5->digest());
return $MAC;
}
package X509CertificateStructure;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $sequence = shift;
my $Self  = {};
bless ($Self, $Class);
if ($sequence->getSize() == 3)
{
$Self->{_TBS_CERT} = TBSCertificateStructure::new('TBSCertificateStructure', $sequence->getObjectAt(0));
$Self->{_SIG_ALG_ID} = AlgorithmIdentifier::new('AlgorithmIdentifier', $sequence->getObjectAt(1));
$Self->{_SIG} = $sequence->getObjectAt(2);
}
return $Self;
}
sub getSubjectPublicKeyInfo
{
my $Self = shift;
return $Self->{_TBS_CERT}->getSubjectPublicKeyInfo();
}
sub getTBSCertificate
{
my $Self = shift;
return $Self->{_TBS_CERT};
}
sub getSignatureAlgorithm
{
my $Self = shift;
return $Self->{_SIG_ALG_ID};
}
sub getSignature
{
my $Self = shift;
return $Self->{_SIG};
}
package TBSCertificateStructure;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $sequence = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_VERSION} = undef;
$Self->{_SERIAL_NUMBER} = undef;
$Self->{_SIGNATURE} = undef;
$Self->{_ISSUER} = undef;
$Self->{_START_DATE} = undef;
$Self->{_END_DATE} = undef;
$Self->{_SUBJECT} = undef;
$Self->{_SUBJECT_PUBLIC_KEY_INFO} = undef;
$Self->{_ISSUER_UNIQUE_ID} = undef;
$Self->{_SUBJECT_UNIQUE_ID} = undef;
$Self->{_EXTENSIONS} = undef;
my $sequenceStart = 0;
if ($sequence->getObjectAt(0)->isa("DERTaggedObject"))
{
}
else
{
$sequenceStart = -1;          # field 0 is missing!
}
$Self->{_SUBJECT_PUBLIC_KEY_INFO} = SubjectPublicKeyInfo::new('SubjectPublicKeyInfo', $sequence->getObjectAt($sequenceStart + 6));
return $Self;
}
sub getSubjectPublicKeyInfo
{
my $Self = shift;
return $Self->{_SUBJECT_PUBLIC_KEY_INFO};
}
package DERInputStream;
$DERInputStream::BOOLEAN             = 0x01;
$DERInputStream::INTEGER             = 0x02;
$DERInputStream::BIT_STRING          = 0x03;
$DERInputStream::OCTET_STRING        = 0x04;
$DERInputStream::NULL                = 0x05;
$DERInputStream::OBJECT_IDENTIFIER   = 0x06;
$DERInputStream::ENUMERATED          = 0x0a;
$DERInputStream::SEQUENCE            = 0x10;
$DERInputStream::SET                 = 0x11;
$DERInputStream::CONSTRUCTED         = 0x20;
$DERInputStream::TAGGED              = 0x80;
$DERInputStream::PRINTABLE_STRING    = 0x13;
$DERInputStream::T61_STRING          = 0x14;
$DERInputStream::IA5_STRING          = 0x16;
$DERInputStream::UTC_TIME            = 0x17;
$DERInputStream::GENERALIZED_TIME    = 0x18;
$DERInputStream::VISIBLE_STRING      = 0x1a;
$DERInputStream::UNIVERSAL_STRING    = 0x1c;
$DERInputStream::BMP_STRING          = 0x1e;
$DERInputStream::UTF8_STRING         = 0x0c;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
$Self->{_POINTER} = 0;
return $Self;
}
sub readFromStream
{
my $Self = shift;
my $length = shift;
if (!defined($length))
{
$length = 1;
}
if ($Self->available() < $length)
{
return undef;
}
my @result = @{$Self->{_BYTES}}[($Self->{_POINTER})..($Self->{_POINTER} + $length - 1)];
$Self->{_POINTER} += $length;
return \@result;
}
sub available
{
my $Self = shift;
return scalar(@{$Self->{_BYTES}}) - $Self->{_POINTER};
}
sub readObject
{
my $Self = shift;
my ($tag, $contentLength, $bytes);
$tag = $Self->readFromStream();
if (!defined($tag))
{
return undef;
}
$tag = $tag->[0];
if ($tag == -1)
{
die;
}
$contentLength = $Self->readLength();
$bytes = $Self->readFromStream($contentLength);
return $Self->buildObject($tag, $bytes);
}
sub readLength
{
my $Self = shift;
my $socket = $Self->{_SOCKET};
my $contentLength = $Self->readFromStream();
if (!defined($contentLength))
{
return undef;
}
$contentLength = $contentLength->[0];
if ($contentLength < 0)
{
die;
}
if ($contentLength == 0x80)
{
return -1;
}
if ($contentLength > 127)
{
my $size = $contentLength & 0x7f;
$contentLength = 0;
my $i;
for ($i = 0; $i < $size; $i++)
{
my $next = $Self->readFromStream()->[0];
if ($next < 0)
{
die;
}
$contentLength = ($contentLength << 8) + $next;
}
}
return $contentLength;
}
sub buildObject
{
my $Self = shift;
my $tag = shift;
my $bytes = shift;
my ($dIn);
if ($tag == ($DERInputStream::NULL))
{
return undef;
}
if ($tag == ($DERInputStream::SEQUENCE | $DERInputStream::CONSTRUCTED))
{
$dIn = new DERInputStream($bytes);
my $seq = DERConstructedSequence::new('DERConstructedSequence');
my $object = $dIn->readObject();
while (defined($object))
{
$seq->addObject($object);
$object = $dIn->readObject();
}
return $seq;
}
if ($tag == ($DERInputStream::SET | $DERInputStream::CONSTRUCTED))
{
$dIn = new DERInputStream($bytes);
my $set = DERSet::new('DERSet');
my $object = $dIn->readObject();
while (defined($object))
{
$set->addObject($object);
$object = $dIn->readObject();
}
return $object;
}
if ($tag == ($DERInputStream::SET | $DERInputStream::CONSTRUCTED))
{
}
if ($tag == ($DERInputStream::BOOLEAN))
{
return DERBoolean::new('DERBoolean', $bytes);
}
if ($tag == ($DERInputStream::INTEGER))
{
return DERInteger::new('DERInteger', $bytes);
}
if ($tag == ($DERInputStream::ENUMERATED))
{
return DEREnumerated::new('DEREnumerated', $bytes);
}
if ($tag == ($DERInputStream::OBJECT_IDENTIFIER))
{
return DERObjectIdentifier::new('DERObjectIdentifier', $bytes);
}
if ($tag == ($DERInputStream::BIT_STRING))
{
my $padBits = $$bytes[0];
my @data;
Utils::arrayCopy($bytes, 1, \@data, 0, scalar(@$bytes) - 1);
return DERBitString::new('DERBitString', \@data, $padBits);
}
if ($tag == ($DERInputStream::UTF8_STRING))
{
return DERUTF8String::new('DERUTF8String', $bytes);
}
if ($tag == ($DERInputStream::PRINTABLE_STRING))
{
return DERPrintableString::new('DERPrintableString', $bytes);
}
if ($tag == ($DERInputStream::IA5_STRING))
{
return DERIA5String::new('DERIA5String', $bytes);
}
if ($tag == ($DERInputStream::T61_STRING))
{
return DERT61String::new('DERT61String', $bytes);
}
if ($tag == ($DERInputStream::VISIBLE_STRING))
{
return DERVisibleString::new('DERVisibleString', $bytes);
}
if ($tag == ($DERInputStream::UNIVERSAL_STRING))
{
return DERUniversalString::new('DERUniversalString', $bytes);
}
if ($tag == ($DERInputStream::BMP_STRING))
{
return DERBMPString::new('DERBMPString', $bytes);
}
if ($tag == ($DERInputStream::OCTET_STRING))
{
return DEROctetString::new('DEROctetString', $bytes);
}
if ($tag == ($DERInputStream::UTC_TIME))
{
return DERUTCTime::new('DERUTCTime', $bytes);
}
if ($tag == ($DERInputStream::GENERALIZED_TIME))
{
return DERGeneralizedTime::new('DERGeneralizedTime', $bytes);
}
if (($tag & ($DERInputStream::TAGGED | $DERInputStream::CONSTRUCTED)) != 0)
{
if (($tag & 0x1f) == 0x1f)
{
die;
}
if (scalar(@$bytes) == 0)        # empty tag!
{
return DERTaggedObject::new('DERTaggedObject', $tag & 0x1f);
}
if (($tag & $DERInputStream::CONSTRUCTED) == 0)
{
return DERTaggedObject::new('DERTaggedObject', $::FALSE, $tag & 0x1f, new DEROctetString($bytes));
}
$dIn = new DERInputStream($bytes);
my $dObj = $dIn->readObject();
if ($dIn->available() == 0)
{
return DERTaggedObject::new('DERTaggedObject', $tag & 0x1f, $dObj);
}
my $seq = DERConstructedSequence::new('DERConstructedSequence');
while (defined($dObj))
{
$seq->addObject($dObj);
$dObj = $dIn->readObject();
}
return DERTaggedObject::new('DERTaggedObject', $::FALSE, $tag & 0x1f, $seq);
}
return DERUnknownTag::new('DERUnknownTag', $tag, $bytes);
}
package BERInputStream;
@BERInputStream::ISA = ('DERInputStream');
sub readObject
{
my $Self = shift;
my ($tag, $contentLength, $bytes);
$tag = $Self->readFromStream()->[0];
if ($tag == -1)
{
die;
}
$contentLength = $Self->readLength();
if ($contentLength < 0)
{
return undef;
}
else
{
if ($tag == 0 && $contentLength == 0)
{
return undef;
}
$bytes = readFromStream($contentLength);
return $Self->buildObject($tag, $bytes);
}
}
package DERConstructedSequence;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $Self  = {};
bless ($Self, $Class);
$Self->{_SEQUENCE} = ();
return $Self;
}
sub addObject
{
my $Self = shift;
my $object = shift;
push(@{$Self->{_SEQUENCE}}, $object);
}
sub getObjectAt
{
my $Self = shift;
my $index = shift;
return $Self->{_SEQUENCE}->[$index];
}
sub getSize
{
my $Self = shift;
return scalar(@{$Self->{_SEQUENCE}});
}
package DERSet;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $Self  = {};
bless ($Self, $Class);
$Self->{_SET} = ();
return $Self;
}
sub addObject
{
my $Self = shift;
my $object = shift;
push(@{$Self->{_SET}}, $object);
}
package SubjectPublicKeyInfo;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $sequence = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_ALG_ID} = AlgorithmIdentifier::new('AlgorithmIdentifier', $sequence->getObjectAt(0));
$Self->{_KEY_DATA} = $sequence->getObjectAt(1);
return $Self;
}
sub getPublicKey
{
my $Self = shift;
my $dIn = DERInputStream::new('DERInputStream', $Self->{_KEY_DATA}->getBytes());
return $dIn->readObject();
}
package DERInteger;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
sub getValue
{
my $Self = shift;
return BigInteger::new('BigInteger', $Self->{_BYTES});
}
package DERBitString;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $padBits = shift;
if (!defined($padBits))
{
$padBits = 0;
}
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
$Self->{_PADBITS} = $padBits;
return $Self;
}
sub getBytes
{
my $Self = shift;
return $Self->{_BYTES};
}
package DERBoolean;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
package DERObjectIdentifier;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
my $head = $$bytes[0] & 0xff;
my $objId = '';
my $value = 0;
my $first = $::TRUE;
my $i;
for ($i = 0; $i != scalar(@$bytes); $i++)
{
my $b = $$bytes[$i] & 0xff;
$value = $value * 128 + ($b & 0x7f);
if (($b & 0x80) == 0)
{
if ($first)
{
if (int($value / 40) == 0)
{
$objId .= '0';
}
elsif (int($value / 40) == 1)
{
$objId .= '1';
$value -= 40;
}
else
{
$objId .= '2';
$value -= 80;
}
$first = $::FALSE;
}
$objId .= '.';
$objId .= $value;
$value = 0;
}
}
$Self->{_IDENTIFIER} = $objId;
return $Self;
}
sub getId
{
my $Self = shift;
return $Self->{_IDENTIFIER};
}
package DEREnumerated;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
package DERUTF8String;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
package DERPrintableString;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
package DERIA5String;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
package DERT61String;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
package DERVisibleString;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
package DERUniversalString;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
package DERBMPString;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
package DEROctetString;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
sub getOctets
{
my $Self = shift;
return $Self->{_BYTES};
}
package DERUTCTime;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
package DERGeneralizedTime;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
package DERTaggedObject;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $bytes;
return $Self;
}
package DERUnknownTag;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $tag = shift;
my $bytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_TAG} = $tag;
$Self->{_BYTES} = $bytes;
return $Self;
}
package AlgorithmIdentifier;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $sequence = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_OBJECT_ID} = $sequence->getObjectAt(0);
if ($sequence->getSize() == 2)
{
$Self->{_PARAMETERS_DEFINED} = $::TRUE;
$Self->{_PARAMETERS} = $sequence->getObjectAt(1);
}
else
{
$Self->{_PARAMETERS} = undef;
}
return $Self;
}
sub getObjectId
{
my $Self = shift;
return $Self->{_OBJECT_ID};
}
package Utils;
sub arrayCopy
{
my $raSrc = shift;
my $srcPos = shift;
my $raDest = shift;
my $destPos = shift;
my $length = shift;
@$raDest[($destPos)..($destPos + $length - 1)] = @$raSrc[($srcPos)..($srcPos + $length - 1)];
}
sub intToBytes
{
my $val = shift;
my $num = shift;
my @bytes;
my $i;
for($i = 0; $i < $num; $i++)
{
my $value = ($val & (0xFF << ($i * 8))) >> ($i * 8);
unshift @bytes, $value;
}
return \@bytes;
}
sub bytesToInt
{
my $raBytes = shift;
my $value = 0;
my $length = scalar(@$raBytes);
my $i;
for ($i = 0; $i < $length; $i++)
{
$value |= @$raBytes[$i] << (($length - $i - 1) * 8);
}
return $value;
}
sub StringToByteArray
{
my $bytes = shift;
my $i;
my @aBytes;
for ($i = 0; $i < length($bytes); $i++)
{
$aBytes[$i] = ord(substr($bytes, $i, 1));
}
return \@aBytes;
}
sub ByteArrayToString
{
my $raBytes = shift;
my $Result;
my $length = scalar(@$raBytes);
my $i;
for ($i = 0; $i < $length; $i++)
{
$Result .= chr($$raBytes[$i]);
}
return $Result;
}
sub chopOverflow
{
my $value = shift;
my $m = 1 + ~0;
my $result = $value - $m * int($value/$m);
return $result;
}
sub getRandomBytes
{
my $raBytes = shift;
my $offset = shift;
my $len = shift;
my $md5 = ActinicSSL::instantiateMD5Object();
my $b2 = [];
while ($len > 0)
{
$md5->reset();
$md5->add(ByteArrayToString($ActinicSSL::RAND_POOL));
push @$b2, (0x00, 0x00, 0x00, 0x00);
push @$b2, @{Utils::intToBytes($ActinicSSL::RAND_CNT++, 4)};
$md5->add(ByteArrayToString($b2));
$b2 = StringToByteArray($md5->digest());
my $n = $len < 16 ? $len : 16;
Utils::arrayCopy($b2, 0, $raBytes, $offset, $n);
$len -= $n;
$offset += $n;
}
}
package RSAEngine;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $Self  = {};
bless ($Self, $Class);
return $Self;
}
sub init
{
my $Self = shift;
my $forEncryption = shift;
my $parameter = shift;
$Self->{_FOR_ENCRYPTION} = $forEncryption;
$Self->{_KEY} = $parameter;
}
sub getInputBlockSize
{
my $Self = shift;
if ($Self->{_FOR_ENCRYPTION})
{
return 127;
}
else
{
return 128;
}
}
sub getOutputBlockSize
{
my $Self = shift;
if ($Self->{_FOR_ENCRYPTION})
{
return 128;
}
else
{
return 127;
}
}
sub processBlock
{
my $Self = shift;
my $in = shift;
my $inOff = shift;
my $inLen = shift;
my $i;
if ($inLen > ($Self->getInputBlockSize() + 1))
{
return ($::FAILURE, "DataLengthException: input too large for RSA cipher.");
}
elsif ($inLen == ($Self->getInputBlockSize() + 1) && ($$in[$inOff] & 0x80) != 0)
{
return ($::FAILURE, "DataLengthException: input too large for RSA cipher.");
}
my @block;
Utils::arrayCopy($in, $inOff, \@block, 0, $inLen);
my $input = BigInteger::new('BigInteger', \@block);
my $output;
if ($Self->{_KEY}->isa('RSAPrivateCrtKeyParameters'))
{
}
else
{
$output = $input->modPow($Self->{_KEY}->getExponent(), $Self->{_KEY}->getModulus())->getBytes();
}
if ($Self->{_FOR_ENCRYPTION})
{
if ($$output[0] == 0 &&
scalar(@$output) > $Self->getOutputBlockSize())        # have ended up with an extra zero byte, copy down.
{
my @tmp;
Utils::arrayCopy($output, 1, \@tmp, 0, scalar(@$output) - 1);
return ($::SUCCESS, '', \@tmp);
}
if (scalar(@$output) < $Self->getOutputBlockSize())     # have ended up with less bytes than normal, lengthen
{
my @tmp;
Utils::arrayCopy($output, 0, \@tmp, $Self->getOutputBlockSize() - scalar(@$output), scalar(@$output));
return ($::SUCCESS, '', \@tmp);
}
}
else
{
if ($$output[0] == 0)        # have ended up with an extra zero byte, copy down.
{
my @tmp;
Utils::arrayCopy($output, 1, \@tmp, 0, scalar(@$output) - 1);
return ($::SUCCESS, '', \@tmp);
}
}
return ($::SUCCESS, '', $output);
}
package PKCS1;
$PKCS1::HEADER_LENGTH = 10;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $engine = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_ENGINE} = $engine;
return $Self;
}
sub init
{
my $Self = shift;
my $forEncryption = shift;
my $parameter = shift;
$Self->{_ENGINE}->init($forEncryption, $parameter);
$Self->{_FOR_PRIVATE_KEY} = $parameter->isPrivate();
$Self->{_FOR_ENCRYPTION} = $forEncryption;
}
sub processBlock
{
my $Self = shift;
my $in = shift;
my $inOff = shift;
my $inLen = shift;
return $Self->{_FOR_ENCRYPTION} ? $Self->encodeBlock($in, $inOff, $inLen) : $Self->decodeBlock($in, $inOff, $inLen);
}
sub encodeBlock
{
my $Self = shift;
my $in = shift;
my $inOff = shift;
my $inLen = shift;
my $blockSize = $Self->{_ENGINE}->getInputBlockSize();
my @block;
my $i;
if ($Self->{_FOR_PRIVATE_KEY})
{
$block[0] = 0x01;
for ($i = 1; $i < $blockSize - $inLen - 1; $i++)
{
$block[$i] = 0xFF;
}
}
else
{
Utils::getRandomBytes(\@block, 0, $Self->{_ENGINE}->getInputBlockSize());
$block[0] = 0x02;
for ($i = 1; $i != $blockSize - $inLen - 1; $i++)
{
while ($block[$i] == 0)
{
Utils::getRandomBytes(\@block, $i, 1);
}
}
}
$block[$blockSize - $inLen - 1] = 0x00;
Utils::arrayCopy($in, $inOff, \@block, $blockSize - $inLen, $inLen);
return $Self->{_ENGINE}->processBlock(\@block, 0, $blockSize);
}
sub decodeBlock
{
my $Self = shift;
my $in = shift;
my $inOff = shift;
my $inLen = shift;
my $block = $Self->{_ENGINE}->processBlock($in, $inOff, $inLen);
if (scalar(@$block) < $Self->getOutputBlockSize())
{
return ($::FAILURE, "block truncated");
}
if ($$block[0] != 1 &&
$$block[0] != 2)
{
return ($::FAILURE, "InvalidCipherTextException: unknown block type");
}
my $start;
for ($start = 1; $start != scalar(@$block); $start++)
{
if ($$block[$start] == 0)
{
last;
}
}
$start++;
if ($start >= scalar(@$block) ||
$start < $PKCS1::HEADER_LENGTH)
{
return ($::FAILURE, "InvalidCipherTextException: no data in block");
}
my @result;
Utils::arrayCopy($block, $start, \@result, 0, scalar(@$block) - $start);
return ($::SUCCESS, '', \@result);
}
sub getInputBlockSize
{
my $Self = shift;
return $Self->{_ENGINE}->getInputBlockSize() - ($Self->{_FOR_ENCRYPTION} ? $PKCS1::HEADER_LENGTH : 0);
}
sub getOutputBlockSize
{
my $Self = shift;
return $Self->{_ENGINE}->getOutputBlockSize() - ($Self->{_FOR_ENCRYPTION} ? 0 : $PKCS1::HEADER_LENGTH);
}
package RSAPublicKeyStructure;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $sequence = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_MODULUS} = $sequence->getObjectAt(0)->getValue();
$Self->{_PUBLIC_EXPONENT} = $sequence->getObjectAt(1)->getValue();
return $Self;
}
sub getModulus
{
my $Self = shift;
return $Self->{_MODULUS};
}
sub getPublicExponent
{
my $Self = shift;
return $Self->{_PUBLIC_EXPONENT};
}
package RSAKeyParameters;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $isPrivate = shift;
my $modulus = shift;
my $exponent = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_IS_PRIVATE} = $isPrivate;
$Self->{_MODULUS} = $modulus;
$Self->{_EXPONENT} = $exponent;
return $Self;
}
sub isPrivate
{
my $Self = shift;
return $Self->{_IS_PRIVATE};
}
sub getModulus
{
my $Self = shift;
return $Self->{_MODULUS};
}
sub getExponent
{
my $Self = shift;
return $Self->{_EXPONENT};
}
package GeneralDigest;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $Self  = {};
bless ($Self, $Class);
$Self->init();
return $Self;
}
sub init
{
my $Self = shift;
my $i;
$Self->{_X_BUFF} = ();
for ($i = 0; $i < 4; $i++ )
{
push @{$Self->{_X_BUFF}}, 0;
}
$Self->{_X_BUFF_OFF} = 0;
$Self->{_BYTE_COUNT} = undef;
}
sub update
{
my $Self = shift;
my $in = shift;
$Self->{_X_BUFF}->[$Self->{_X_BUFF_OFF}++] = $in;
if ($Self->{_X_BUFF_OFF} == scalar(@{$Self->{_X_BUFF}}))
{
$Self->processWord($Self->{_X_BUFF}, 0);
$Self->{_X_BUFF_OFF} = 0;
}
$Self->{_BYTE_COUNT}++;
}
sub updateEx
{
my $Self = shift;
my $aIn = shift;
my $inOff = shift;
my $len = shift;
while (($Self->{_X_BUFF_OFF} != 0)
&& ($len > 0))
{
$Self->update($aIn->[$inOff]);
$inOff++;
$len--;
}
while ($len > scalar(@{$Self->{_X_BUFF}}))
{
$Self->processWord($aIn, $inOff);
$inOff += scalar(@{$Self->{_X_BUFF}});
$len -= scalar(@{$Self->{_X_BUFF}});
$Self->{_BYTE_COUNT} += scalar(@{$Self->{_X_BUFF}});
}
while ($len > 0)
{
$Self->update($aIn->[$inOff]);
$inOff++;
$len--;
}
}
sub finish
{
my $Self = shift;
my $bitLength = ($Self->{_BYTE_COUNT} << 3);
$Self->update(128);
while ($Self->{_X_BUFF_OFF} != 0)
{
$Self->update(0);
}
$Self->processLength($bitLength);
$Self->processBlock();
}
sub reset()
{
my $Self = shift;
$Self->{_BYTE_COUNT} = 0;
$Self->{_X_BUFF_OFF} = 0;
my $i;
for ($i = 0; $i < scalar(@{$Self->{_X_BUFF}}); $i++)
{
$Self->{_X_BUFF}->[$i] = 0;
}
}
package SHA1Digest;
@SHA1Digest::ISA = ('GeneralDigest');
$SHA1Digest::DIGEST_LENGTH = 20;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $sequence = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->init();
$Self->reset();
return $Self;
}
sub init
{
my $Self = shift;
$Self->GeneralDigest::init();
my $i;
$Self->{_X} = ();
for ($i = 0; $i < 80; $i++ )
{
push @{$Self->{_X}}, 0;
}
$Self->{_X_OFF} = 0;
}
sub add
{
my $Self = shift;
my $string = shift;
$Self->updateEx(Utils::StringToByteArray($string), 0, length($string));
}
sub digest
{
my $Self = shift;
my @aResult;
$Self->doFinal(\@aResult, 0);
return Utils::ByteArrayToString(\@aResult);
}
sub reset
{
my $Self = shift;
$Self->{_BYTE_COUNT} = 0;
$Self->{_H1} = 0x67452301;
$Self->{_H2} = 0xefcdab89;
$Self->{_H3} = 0x98badcfe;
$Self->{_H4} = 0x10325476;
$Self->{_H5} = 0xc3d2e1f0;
$Self->{_X_OFF} = 0;
my $i;
for ($i = 0; $i != scalar(@{$Self->{_X}}); $i++)
{
$Self->{_X}->[$i] = 0;
}
}
sub processWord
{
my $Self = shift;
my $raIn = shift;
my $inOff = shift;
$Self->{_X}->[$Self->{_X_OFF}++] = (($raIn->[$inOff] & 0xff) << 24) | (($raIn->[$inOff + 1] & 0xff) << 16)
| (($raIn->[$inOff + 2] & 0xff) << 8) | (($raIn->[$inOff + 3] & 0xff));
if ($Self->{_X_OFF} == 16)
{
$Self->processBlock();
}
}
sub unpackWord
{
my $Self = shift;
my $word = shift;
my $raOut = shift;
my $outOff = shift;
$raOut->[$outOff]     = (($word & 0xff000000) >> 24);
$raOut->[$outOff + 1] = (($word  & 0x00ff0000) >> 16);
$raOut->[$outOff + 2] = (($word & 0x0000ff00) >> 8);
$raOut->[$outOff + 3] = $word & 0x000000ff;
}
sub processLength
{
my $Self = shift;
my $bitLength = shift;
if ($Self->{_X_OFF} > 14)
{
$Self->processBlock();
}
$Self->{_X}->[14] = 0;#$bitLength >> 32;
$Self->{_X}->[15] = $bitLength & 0xffffffff;
}
sub doFinal
{
my $Self = shift;
my $raOut = shift;
my $outOff = shift;
$Self->finish();
$Self->unpackWord($Self->{_H1}, $raOut, $outOff);
$Self->unpackWord($Self->{_H2}, $raOut, $outOff + 4);
$Self->unpackWord($Self->{_H3}, $raOut, $outOff + 8);
$Self->unpackWord($Self->{_H4}, $raOut, $outOff + 12);
$Self->unpackWord($Self->{_H5}, $raOut, $outOff + 16);
$Self->reset();
return $SHA1Digest::DIGEST_LENGTH;
}
$SHA1Digest::Y1 = 0x5a827999;
$SHA1Digest::Y2 = 0x6ed9eba1;
$SHA1Digest::Y3 = 0x8f1bbcdc;
$SHA1Digest::Y4 = 0xca62c1d6;
sub f
{
my $Self = shift;
my $u = shift;
my $v = shift;
my $w = shift;
return (($u & $v) | ((~$u) & $w));
}
sub h
{
my $Self = shift;
my $u = shift;
my $v = shift;
my $w = shift;
return ($u ^ $v ^ $w);
}
sub g
{
my $Self = shift;
my $u = shift;
my $v = shift;
my $w = shift;
return (($u & $v) | ($u & $w) | ($v & $w));
}
sub rotateLeft
{
my $Self = shift;
my $x = shift;
my $n = shift;
return ($x << $n) | ((2**$n-1) & ($x >> (32 - $n)));
}
sub processBlock()
{
my $Self = shift;
my $i;
for ($i = 16; $i <= 79; $i++)
{
$Self->{_X}->[$i] = $Self->rotateLeft(($Self->{_X}->[$i - 3] ^ $Self->{_X}->[$i - 8] ^ $Self->{_X}->[$i - 14] ^ $Self->{_X}->[$i - 16]), 1);
}
my $A = $Self->{_H1};
my $B = $Self->{_H2};
my $C = $Self->{_H3};
my $D = $Self->{_H4};
my $E = $Self->{_H5};
my $j;
for ($j = 0; $j <= 19; $j++)
{
my $t = $Self->rotateLeft($A, 5) + $Self->f($B, $C, $D) + $E + $Self->{_X}->[$j] + $SHA1Digest::Y1;
$t = Utils::chopOverflow($t);
$E = $D;
$D = $C;
$C = $Self->rotateLeft($B, 30);
$B = $A;
$A = $t;
}
for ($j = 20; $j <= 39; $j++)
{
my $t = $Self->rotateLeft($A, 5) + $Self->h($B, $C, $D) + $E + $Self->{_X}->[$j] + $SHA1Digest::Y2;
$t = Utils::chopOverflow($t);
$E = $D;
$D = $C;
$C = $Self->rotateLeft($B, 30);
$B = $A;
$A = $t;
}
for ($j = 40; $j <= 59; $j++)
{
my $t = $Self->rotateLeft($A, 5) + $Self->g($B, $C, $D) + $E + $Self->{_X}->[$j] + $SHA1Digest::Y3;
$t = Utils::chopOverflow($t);
$E = $D;
$D = $C;
$C = $Self->rotateLeft($B, 30);
$B = $A;
$A = $t;
}
for ($j = 60; $j <= 79; $j++)
{
my $t = $Self->rotateLeft($A, 5) + $Self->h($B, $C, $D) + $E + $Self->{_X}->[$j] + $SHA1Digest::Y4;
$t = Utils::chopOverflow($t);
$E = $D;
$D = $C;
$C = $Self->rotateLeft($B, 30);
$B = $A;
$A = $t;
}
$Self->{_H1} += $A;
$Self->{_H2} += $B;
$Self->{_H3} += $C;
$Self->{_H4} += $D;
$Self->{_H5} += $E;
$Self->{_H1} = Utils::chopOverflow($Self->{_H1});
$Self->{_H2} = Utils::chopOverflow($Self->{_H2});
$Self->{_H3} = Utils::chopOverflow($Self->{_H3});
$Self->{_H4} = Utils::chopOverflow($Self->{_H4});
$Self->{_H5} = Utils::chopOverflow($Self->{_H5});
$Self->{_X_OFF} = 0;
for ($i = 0; $i != scalar(@{$Self->{_X}}); $i++)
{
$Self->{_X}->[$i] = 0;
}
}
package RC4Engine;
$RC4Engine::STATE_LENGTH = 256;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $Self  = {};
bless ($Self, $Class);
$Self->{_ENGINE_STATE} = undef;
$Self->{_X} = 0;
$Self->{_Y} = 0;
$Self->{_WORKING_KEY} = undef;
return $Self;
}
sub init
{
my $Self = shift;
my $forEncryption = shift;
my $key = shift;
$Self->{_WORKING_KEY} = $key;
$Self->setKey($Self->{_WORKING_KEY});
}
sub returnByte
{
my $Self = shift;
my $in = shift;
$Self->{_X} = ($Self->{_X} + 1) & 0xff;
$Self->{_Y} = ($Self->{_ENGINE_STATE}->[$Self->{_X}] + $Self->{_Y}) & 0xff;
my $tmp = $Self->{_ENGINE_STATE}->[$Self->{_X}];
$Self->{_ENGINE_STATE}->[$Self->{_X}] = $Self->{_ENGINE_STATE}->[$Self->{_Y}];
$Self->{_ENGINE_STATE}->[$Self->{_Y}] = $tmp;
return ($in ^ $Self->{_ENGINE_STATE}->[($Self->{_ENGINE_STATE}->[$Self->{_X}] + $Self->{_ENGINE_STATE}->[$Self->{_Y}]) & 0xff]);
}
sub processBytes
{
my $Self = shift;
my $raIn = shift;
my $inOff = shift;
my $len = shift;
my $raOut = shift;
my $outOff = shift;
if (($inOff + $len) > scalar(@$raIn))
{
return ($::FAILURE, "DataLengthException: input buffer too short");
}
if (($outOff + $len) > scalar(@$raOut))
{
return ($::FAILURE, "DataLengthException: output buffer too short");
}
my $i;
for ($i = 0; $i < $len ; $i++)
{
$Self->{_X} = ($Self->{_X} + 1) & 0xff;
$Self->{_Y} = ($Self->{_ENGINE_STATE}->[$Self->{_X}] + $Self->{_Y}) & 0xff;
my $tmp = $Self->{_ENGINE_STATE}->[$Self->{_X}];
$Self->{_ENGINE_STATE}->[$Self->{_X}] = $Self->{_ENGINE_STATE}->[$Self->{_Y}];
$Self->{_ENGINE_STATE}->[$Self->{_Y}] = $tmp;
$raOut->[$i + $outOff] = ($raIn->[$i + $inOff] ^ $Self->{_ENGINE_STATE}->[($Self->{_ENGINE_STATE}->[$Self->{_X}] + $Self->{_ENGINE_STATE}->[$Self->{_Y}]) & 0xff]);
}
return ($::SUCCESS, '');
}
sub reset
{
my $Self = shift;
$Self->setKey($Self->{_WORKING_KEY});
}
sub setKey
{
my $Self = shift;
my $raKeyBytes = shift;
$Self->{_WORKING_KEY} = $raKeyBytes;
$Self->{_X} = 0;
$Self->{_Y} = 0;
my $i;
for ($i = 0; $i < $RC4Engine::STATE_LENGTH; $i++)
{
$Self->{_ENGINE_STATE}->[$i] = $i;
}
my $i1 = 0;
my $i2 = 0;
for ($i = 0; $i < $RC4Engine::STATE_LENGTH; $i++)
{
$i2 = (($Self->{_WORKING_KEY}->[$i1] & 0xff) + $Self->{_ENGINE_STATE}->[$i] + $i2) & 0xff;
my $tmp = $Self->{_ENGINE_STATE}->[$i];
$Self->{_ENGINE_STATE}->[$i] = $Self->{_ENGINE_STATE}->[$i2];
$Self->{_ENGINE_STATE}->[$i2] = $tmp;
$i1 = ($i1 + 1) % scalar(@{$Self->{_WORKING_KEY}});
}
}
package BigInteger;
sub new
{
my $Proto = shift;
my $Class = ref($Proto) || $Proto;
my $raBytes = shift;
my $Self  = {};
bless ($Self, $Class);
$Self->{_BYTES} = $raBytes;
$Self->{_VALUE} = ActinicDiffie::FromBytes(reverse @$raBytes);
return $Self;
}
sub modPow
{
my $bigValue = shift;
my $bigPower = shift;
my $bigModulo = shift;
my $bigResult = ActinicDiffie::ModPow($bigValue->getValue(), $bigPower->getValue(), $bigModulo->getValue());
my $raResult = BigInteger::toByteArray($bigResult);
return new BigInteger($raResult);
}
sub getValue
{
my $Self = shift;
return $Self->{_VALUE};
}
sub getBytes
{
my $Self = shift;
return $Self->{_BYTES};
}
sub toByteArray
{
my	$nNumber = shift;
my @bResult,
my $nPos = 0;
while (!($nNumber eq '+0'))
{
$bResult[$nPos] = ActinicDiffie::bmod($nNumber, '256');
$nNumber = ActinicDiffie::bdiv($nNumber, '256');
$nPos++;
}
@bResult = reverse @bResult;
return(\@bResult);
}
1;