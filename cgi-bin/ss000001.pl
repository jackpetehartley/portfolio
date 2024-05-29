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
require sl000001;
require ao000001;
require sm000001;
use strict;
$::prog_name = "SearchScript";
$::prog_name = $::prog_name;
$::prog_ver = '$Revision: 18819 $ ';
$::prog_ver = substr($::prog_ver, 11);
$::prog_ver =~ s/ \$//;
my $nFILEVERSION = 1;
my $sPath = Init();
my ($status, $sError);
my $TRUE_RESULT  =  1;
my $FALSE_RESULT =  0;
my $SKIP_RESULT  = -1;
my $UI_TEXTBOX        = 0;
my $UI_RADIOBUTTON    = 1;
my $UI_CHECKBOX       = 2;
my $UI_DROPDOWNLIST   = 3;
my $UI_LIST           = 4;
my $nSearchNumber = '';
my $sSearchFile = $sPath . "customsearch";
if (exists $::g_InputHash{PRODREF})
{
my $sProdRef = ACTINIC::DecodeText($::g_InputHash{PRODREF}, $ACTINIC::FORM_URL_ENCODED);
my $sHTML = DirectLinkToProduct($sPath, $sProdRef);
ACTINIC::SaveSessionAndPrintPage($sHTML, "");
exit;
}
elsif (exists $::g_InputHash{SECTIONID})
{
my $sSection = ACTINIC::DecodeText($::g_InputHash{SECTIONID}, $ACTINIC::FORM_URL_ENCODED);
my $sHTML = DisplayDirectLinkPage($sSection, $::TRUE );
$::g_bLoginPage = $::TRUE;
ACTINIC::SaveSessionAndPrintPage($sHTML, "");
exit;
}
if (exists $::g_InputHash{SN})
{
$nSearchNumber = $::g_InputHash{SN};
unless ($nSearchNumber =~ /^\d*$/)
{
my $filelog = ACTINIC::GetPhrase(-1, 325, $nSearchNumber);
SearchError($filelog);
exit;
}
ACTINIC::LogData("Using custom search $nSearchNumber", $::DC_SEARCH);
}
$sSearchFile .= "$nSearchNumber.fil";
unless (open SFILE, "<$sSearchFile")
{
my $filelog = ACTINIC::GetPhrase(-1, 21, $sSearchFile, $!);
SearchError($filelog);
exit;
}
my @SearchCmd = <SFILE>;
close SFILE;
push @SearchCmd, "PriceSchedule\n";
push @SearchCmd, "And\n";
my $nFileVersion = shift (@SearchCmd);
unless ($nFileVersion == $nFILEVERSION)
{
my $filelog = ACTINIC::GetPhrase(-1, 326, $nFILEVERSION, $nFileVersion);
SearchError($filelog);
exit;
}
ACTINIC::LogData("Search command file version = $nFileVersion", $::DC_SEARCH);
if ($::g_InputHash{GROUPONLY})
{
@SearchCmd = ();
push @SearchCmd, "ProductGroup!PG\n";
}
my %MatchWords;
my %UsedValues;
my @ResultsStack;
my $bValidSearch = 0;
my $bPriceSearch = $::FALSE;
SearchMain(\@SearchCmd, \$bValidSearch, \$bPriceSearch, \%MatchWords, \@ResultsStack);
my %NullSet;
my $rhashResults = \%NullSet;
if ($#ResultsStack == -1)
{
ACTINIC::LogData("Null (not empty) results stack!", $::DC_SEARCH);
}
elsif ($#ResultsStack == 0)
{
my $rArray = pop @ResultsStack;
if ($rArray->[0] == $TRUE_RESULT)
{
$rhashResults = $rArray->[1];
ACTINIC::LogData("Search resulted in a single result list (everything worked as expected).", $::DC_SEARCH);
}
else
{
ACTINIC::LogData("Search resulted in an empty result list (everything worked as expected).", $::DC_SEARCH);
}
}
else
{
ACTINIC::LogData("Search resulted in a set of result lists.  They should have been combined into a single list by now.  We will combine them at this point.", $::DC_SEARCH);
my $pLine;
my @ResultHashes;
foreach $pLine (@ResultsStack)
{
my ($nStatus, $rhashtemp) = @{$pLine};
ACTINIC::LogData("Result status was $nStatus", $::DC_SEARCH);
if (($nStatus == $FALSE_RESULT) and
($::g_InputHash{GB} eq 'A'))
{
@ResultHashes = ();
ACTINIC::LogData("Exiting loop - one of the lists to be combined is empty and the join is an INTERSECTION.  Using an empty set.", $::DC_SEARCH);
last;
}
elsif ($nStatus != $TRUE_RESULT)
{
ACTINIC::LogData("Skipping set of irrelevant results (SKIP set).", $::DC_SEARCH);
next;
}
else
{
push @ResultHashes, $rhashtemp;
ACTINIC::LogData("Found a result set.", $::DC_SEARCH);
}
}
if ($#ResultHashes == -1)
{
$rhashResults = \%NullSet;
ACTINIC::LogData("No populated results were found.  Using a null set.", $::DC_SEARCH);
}
else
{
ACTINIC::LogData("Found multiple results sets.  Combining results with global join operation ($::g_InputHash{GB}).", $::DC_SEARCH);
$rhashResults = shift @ResultHashes;
my $bJoin = ($::g_InputHash{GB} eq 'A') ? $::INTERSECT : $::UNION;
while (@ResultHashes)
{
my $rPrevious = $rhashResults;
my $rCurrent = shift @ResultHashes;
JoinSearchResults($rPrevious, $rCurrent, $bJoin, $rhashResults);
}
}
}
if (!$bValidSearch)
{
my $sError;
my $sStart = ACTINIC::EncodeText2(ACTINIC::GetPhrase(-1, 113), $::FALSE);
if ($bPriceSearch &&
$::g_InputHash{ACTION})
{
$sError = ACTINIC::GetPhrase(-1, 245);
}
else
{
$sError = ACTINIC::GetPhrase(-1, 2085);
}
SearchError($sError, $::FALSE);
exit;
}
my $nPageNumber = $::g_InputHash{PN};
my @StringTemp = keys %MatchWords;
my $sWords = join (' ', @StringTemp);
($status, $sError) = DisplayResults($sPath, $rhashResults, $nPageNumber, $sWords);
if ($status != $::SUCCESS)
{
SearchError($sError, $status != $::NOTFOUND);
exit;
}
exit;
sub Init
{
my ($status, $sError, $unused);
($status, $sError, $::g_OriginalInputData, $unused, %::g_InputHash) = ACTINIC::ReadAndParseInput();
if ($::SUCCESS != $status)
{
ACTINIC::TerminalError($sError);
}
my $sPath = ACTINIC::GetPath();
ACTINIC::SecurePath($sPath);
if (!$sPath)
{
ACTINIC::TerminalError("Path not found.");
}
if (!-e $sPath ||
!-d $sPath)
{
ACTINIC::TerminalError("Invalid path.");
}
($status, $sError) = ACTINIC::ReadPromptFile($sPath);
if ($status != $::SUCCESS)
{
ACTINIC::ReportError($sError, $sPath);
}
($status, $sError) = ACTINIC::ReadSetupFile($sPath);
if ($status != $::SUCCESS)
{
ACTINIC::ReportError($sError, $sPath);
}
($status, $sError) = ACTINIC::ReadSearchSetupFile($sPath);
if ($status != $::SUCCESS)
{
ACTINIC::ReportError($sError, $sPath);
}
($status, $sError) = ACTINIC::ReadCatalogFile($sPath);
if ($status != $::SUCCESS)
{
ACTINIC::ReportError($sError, $sPath);
}
my ($sCartID, $sContactDetails) = ACTINIC::GetCookies();
$::Session = new Session($sCartID, $sContactDetails, ACTINIC::GetPath(), $::TRUE);
$::g_sWebSiteUrl = $::Session->GetBaseUrl();
$::g_sContentUrl = $::g_sWebSiteUrl;
my ($sUserDigest, $sBaseFile);
$sUserDigest = $ACTINIC::B2B->Get('UserDigest');
if (!$sUserDigest)
{
($sUserDigest, $sBaseFile) = ACTINIC::CaccGetCookies();
$ACTINIC::B2B->Set('UserDigest',$sUserDigest);
$ACTINIC::B2B->Set('BaseFile',  $sBaseFile);
}
if ($sUserDigest)
{
$sBaseFile   = $ACTINIC::B2B->Get('BaseFile');
($::g_sWebSiteUrl, $::g_sContentUrl) = ($sBaseFile, $sBaseFile);
}
elsif( $::g_InputHash{BASE} )
{
($::g_sWebSiteUrl, $::g_sContentUrl) = ($::g_InputHash{BASE}, $::g_InputHash{BASE});
}
return ($sPath);
}
sub ParseSearchInput
{
my ($rhashResults) = @_;
my @EncodedInput = split (/[&=]/, $::g_OriginalInputData);
if ($#EncodedInput % 2 != 1)
{
return ($::FAILURE, "Bad input string \"" . $::g_OriginalInputData . "\".  Argument count " . $#EncodedInput . ".\n", '', '', 0, 0);
}
my ($key, $value);
while (@EncodedInput)
{
$key = ACTINIC::DecodeText(shift @EncodedInput, $ACTINIC::FORM_URL_ENCODED);
$value = ACTINIC::DecodeText(shift @EncodedInput, $ACTINIC::FORM_URL_ENCODED);
if (exists $$rhashResults{$key})
{
push @{$$rhashResults{$key}}, $value;
}
else
{
$$rhashResults{$key} = [$value];
}
}
return ($::SUCCESS, '');
}
sub SearchMain
{
my ($plistSearchCommands, $pbValidSearch, $pbPriceSearch, $pmapKeywordsFound, $pResultsStack) = @_;
my $sPath = ACTINIC::GetPath();
ACTINIC::LogData("Search command: \n" . join("", @$plistSearchCommands), $::DC_SEARCH);
my ($sLine, %mapInputKeyToValueArray);
foreach $sLine (@$plistSearchCommands)
{
chomp $sLine;
ACTINIC::LogData("\n\nProcessing command: $sLine", $::DC_SEARCH);
my ($sCmd, $sSearchControlName, $sKeywordBooleanControlName) = split ('!', $sLine);
ACTINIC::LogData("Command parsed: Command='$sCmd', Search Control Name='$sSearchControlName', Keyword Join Control Name='$sKeywordBooleanControlName'", $::DC_SEARCH);
my $sSearchValue = '';
if ($sSearchControlName)
{
if (exists $::g_InputHash{$sSearchControlName})
{
$sSearchValue = $::g_InputHash{$sSearchControlName};
}
ACTINIC::LogData("Search parameter value ='$sSearchValue'", $::DC_SEARCH);
}
$sSearchValue =~ s/^\s*//o;
$sSearchValue =~ s/\s*$//o;
my $sKeywordBooleanOperation = '';
if ($sKeywordBooleanControlName)
{
if (exists $::g_InputHash{$sKeywordBooleanControlName})
{
$sKeywordBooleanOperation = $::g_InputHash{$sKeywordBooleanControlName};
}
ACTINIC::LogData("Keyword join value ='$sKeywordBooleanOperation'", $::DC_SEARCH);
}
if ($sCmd eq 'Text')
{
ACTINIC::LogData("Doing a keyword search.", $::DC_SEARCH);
my $bText = $::UNION;
ACTINIC::LogData("Defaulting to joining keywords with UNION.", $::DC_SEARCH);
if ($sKeywordBooleanOperation eq 'A')
{
$bText = $::INTERSECT;
ACTINIC::LogData("Overriding join method with INTERSECTION.", $::DC_SEARCH);
}
elsif ($sKeywordBooleanOperation ne 'O')
{
my $sError = ACTINIC::GetPhrase(-1, 244);
SearchError($sError);
exit;
}
if ($sSearchValue eq '')
{
ACTINIC::LogData("Searcher doesn't care about keywords.", $::DC_SEARCH);
next;
}
$$pbValidSearch = 1;
my $pTextHits = {};
($status, $sError) = Search::SearchText($sPath, \$sSearchValue, $bText, $pTextHits);
if ($status != $::SUCCESS)
{
SearchError($sError);
exit;
}
if (scalar (keys %$pTextHits))
{
push @$pResultsStack, [$TRUE_RESULT, $pTextHits];
my @matches = split (' ', $sSearchValue);
my $word;
foreach $word (@matches)
{
$$pmapKeywordsFound{$word} = 1;
}
if ($::DEBUG_CLASS_FILTER & $::DC_SEARCH)
{
my @Results = keys %$pTextHits;
my $nResults = scalar (@Results);
my $sResults = join (';', @Results);
ACTINIC::LogData("The keyword search yielded $nResults hits\n    $sResults\n", $::DC_SEARCH);
}
}
else
{
push @$pResultsStack, [$FALSE_RESULT];
ACTINIC::LogData("The keyword search yielded no hits.", $::DC_SEARCH);
}
}
elsif ($sCmd eq 'Price')
{
ACTINIC::LogData("Doing a price range search.", $::DC_SEARCH);
$$pbPriceSearch = $::TRUE;
my $pPriceHits = {};
my $nPriceBand = $sSearchValue;
if (defined $nPriceBand &&
($nPriceBand != $::ANY_PRICE_BAND))
{
ACTINIC::LogData("Searching price band $nPriceBand.", $::DC_SEARCH);
$$pbValidSearch = 1;
($status, $sError) = Search::SearchPrice($sPath, $nPriceBand, $pPriceHits);
if ($status != $::SUCCESS)
{
SearchError($sError);
exit;
}
if (scalar (keys %$pPriceHits))
{
push @$pResultsStack, [$TRUE_RESULT, $pPriceHits];
if ($::DEBUG_CLASS_FILTER & $::DC_SEARCH)
{
my @Results = keys %$pPriceHits;
my $nResults = scalar (@Results);
my $sResults = join (';', @Results);
ACTINIC::LogData("The price range search yielded $nResults hits\n    $sResults\n", $::DC_SEARCH);
}
}
else
{
ACTINIC::LogData("Price band search yielded no hits.", $::DC_SEARCH);
push @$pResultsStack, [$FALSE_RESULT];
}
}
else
{
ACTINIC::LogData("Searcher doesn't care about price range.", $::DC_SEARCH);
push @$pResultsStack, [$SKIP_RESULT];
}
}
elsif (($sCmd eq 'Text Property') ||
($sCmd eq 'Integer') ||
($sCmd eq 'Date'))
{
ACTINIC::LogData("Doing arbitrary property search.  Property type='$sCmd'.", $::DC_SEARCH);
unless (exists $$::g_pSearchSetup{$sSearchControlName})
{
my $sError = ACTINIC::GetPhrase(-1, 327, $sSearchControlName);
SearchError($sError);
exit;
}
my $pBlobParam = $$::g_pSearchSetup{$sSearchControlName};
ACTINIC::LogData("Control UIType = $pBlobParam->{UIType}.", $::DC_SEARCH);
ACTINIC::LogData("Control Optional = $pBlobParam->{Optional}.", $::DC_SEARCH);
ACTINIC::LogData("Control MultiSelect = $pBlobParam->{MultiSelect}.", $::DC_SEARCH);
ACTINIC::LogData("Control Label = $pBlobParam->{Label}.", $::DC_SEARCH);
unless (scalar (keys %mapInputKeyToValueArray))
{
($status, $sError) = ParseSearchInput(\%mapInputKeyToValueArray);
if ($status != $::SUCCESS)
{
SearchError($sError);
exit;
}
}
my $pmapProductReferenceToMatchingProperties = {};
my %mapFoundProductsToZero;
my $sCurrentValueOfMultiple = '';
my @listAllValuesForControl = ();
if ($mapInputKeyToValueArray{$sSearchControlName})
{
@listAllValuesForControl = @{$mapInputKeyToValueArray{$sSearchControlName}};
}
while (@listAllValuesForControl)
{
$sCurrentValueOfMultiple = shift @listAllValuesForControl;
ACTINIC::LogData("Searching for property value '$sCurrentValueOfMultiple'.", $::DC_SEARCH);
if (($sCurrentValueOfMultiple eq '') &&
(!$$pBlobParam{Optional}))
{
my $sError = ACTINIC::GetPhrase(-1, 328, $$pBlobParam{Label});
SearchError($sError);
exit;
}
if (($sCurrentValueOfMultiple eq 'on') &&
($$pBlobParam{UIType} == $UI_CHECKBOX))
{
$sCurrentValueOfMultiple = '';
ACTINIC::LogData("Checkbox converted on to 'any' (searcher doesn't care about value).", $::DC_SEARCH);
}
if (exists $UsedValues{$sSearchControlName})
{
if (($UsedValues{$sSearchControlName} != $sCurrentValueOfMultiple) &&
(!$$pBlobParam{MultiSelect})) # and the control is not a multi-select
{
my $sError = ACTINIC::GetPhrase(-1, 329, $$pBlobParam{Label});
SearchError($sError);
exit;
}
}
$UsedValues{$sSearchControlName} = $sCurrentValueOfMultiple;
if (($sCmd eq 'Integer') &&
($sCurrentValueOfMultiple ne '')) # and the value is not blank (i.e. not ignored)
{
unless ($sCurrentValueOfMultiple =~ /^[-+]?\d+$/o)
{
my $sError = ACTINIC::GetPhrase(-1, 330, $sCurrentValueOfMultiple, $$pBlobParam{Label});
SearchError($sError);
exit;
}
}
elsif (($sCmd eq 'Date') &&
$sCurrentValueOfMultiple)
{
unless ($sCurrentValueOfMultiple =~ /\d{8}/o) # must be of the format YYYYMMDD (i.e. 8 digits)
{
my $sError = ACTINIC::GetPhrase(-1, 331, $sCurrentValueOfMultiple, $$pBlobParam{Label});
SearchError($sError);
exit;
}
}
else
{
}
if ($sCurrentValueOfMultiple ne '')
{
$$pbValidSearch = 1;
undef %mapFoundProductsToZero;
($status, $sError) = Search::SearchProperty($sPath, $sSearchControlName, $sCurrentValueOfMultiple, \%mapFoundProductsToZero);
if ($status != $::SUCCESS)
{
SearchError($sError);
exit;
}
ACTINIC::LogData("Property search '$sSearchControlName' = '$sCurrentValueOfMultiple'.", $::DC_SEARCH);
my $sProductReference;
my $sLabel = ACTINIC::EncodeText2($pBlobParam->{Label}) . ": " . ACTINIC::EncodeText2($sCurrentValueOfMultiple) . "<BR>";
foreach $sProductReference (keys %mapFoundProductsToZero)
{
unless (exists $pmapProductReferenceToMatchingProperties->{$sProductReference})
{
$pmapProductReferenceToMatchingProperties->{$sProductReference} = [];
}
push @{$pmapProductReferenceToMatchingProperties->{$sProductReference}}, $sLabel;
}
if ($::DEBUG_CLASS_FILTER & $::DC_SEARCH)
{
my @Results = keys %mapFoundProductsToZero;
my $nResults = scalar (@Results);
my $sResults = join (';', @Results);
ACTINIC::LogData("The property search yielded $nResults hits for '$sSearchControlName' = '$sCurrentValueOfMultiple'\n    $sResults\n", $::DC_SEARCH);
}
}
else
{
@listAllValuesForControl = ();
ACTINIC::LogData("Property search for '$sSearchControlName' being ignored (searcher doesn't care about value).", $::DC_SEARCH);
}
}
if ($sCurrentValueOfMultiple eq '')
{
ACTINIC::LogData("Property search for '$sSearchControlName' being ignored (searcher doesn't care about value).", $::DC_SEARCH);
push @$pResultsStack, [$SKIP_RESULT];
}
elsif (scalar (keys %$pmapProductReferenceToMatchingProperties))
{
if ($::DEBUG_CLASS_FILTER & $::DC_SEARCH)
{
my @Results = keys %$pmapProductReferenceToMatchingProperties;
my $nResults = scalar (@Results);
my $sResults = join (';', @Results);
ACTINIC::LogData("The property search yielded $nResults total hits\n    $sResults\n", $::DC_SEARCH);
}
push @$pResultsStack, [$TRUE_RESULT, $pmapProductReferenceToMatchingProperties];
}
else
{
ACTINIC::LogData("Property search for '$sSearchControlName' resulted in no hits.", $::DC_SEARCH);
push @$pResultsStack, [$FALSE_RESULT];
}
}
elsif ($sCmd eq 'Section')
{
ACTINIC::LogData("Doing section search.", $::DC_SEARCH);
my $pSectionHits = {};
if ($sSearchValue)
{
$$pbValidSearch = 1;
($status, $sError) = Search::SearchSection($sPath, $sSearchValue, $pSectionHits);
if ($status != $::SUCCESS)
{
SearchError($sError);
exit;
}
if (scalar (keys %$pSectionHits))
{
if ($::DEBUG_CLASS_FILTER & $::DC_SEARCH)
{
my @Results = keys %$pSectionHits;
my $nResults = scalar (@Results);
my $sResults = join (';', @Results);
ACTINIC::LogData("The section search for '$sSearchValue' yielded $nResults total hits\n    $sResults\n", $::DC_SEARCH);
}
push @$pResultsStack, [$TRUE_RESULT, $pSectionHits];
}
else
{
ACTINIC::LogData("Section search for '$sSearchValue' resulted in no hits.", $::DC_SEARCH);
push @$pResultsStack, [$FALSE_RESULT];
}
}
else
{
ACTINIC::LogData("Section search being ignored (searcher doesn't care about value).", $::DC_SEARCH);
push @$pResultsStack, [$SKIP_RESULT];
}
}
elsif ($sCmd eq 'ProductGroup')
{
ACTINIC::LogData("Doing product group search.", $::DC_SEARCH);
my $pGroupHits = {};
if ($sSearchValue)
{
$$pbValidSearch = 1;
($status, $sError) = Search::SearchProductGroup($sPath, $sSearchValue, $pGroupHits);
if ($status != $::SUCCESS)
{
SearchError($sError);
exit;
}
if (scalar (keys %$pGroupHits))
{
if ($::DEBUG_CLASS_FILTER & $::DC_SEARCH)
{
my @Results = keys %$pGroupHits;
my $nResults = scalar (@Results);
my $sResults = join (';', @Results);
ACTINIC::LogData("The product group search for '$sSearchValue' yielded $nResults total hits\n    $sResults\n", $::DC_SEARCH);
}
push @$pResultsStack, [$TRUE_RESULT, $pGroupHits];
}
else
{
ACTINIC::LogData("Product Group search for '$sSearchValue' resulted in no hits.", $::DC_SEARCH);
push @$pResultsStack, [$FALSE_RESULT];
}
}
else
{
ACTINIC::LogData("Product group search being ignored (searcher doesn't care about value).", $::DC_SEARCH);
push @$pResultsStack, [$SKIP_RESULT];
}
}
elsif ($sCmd eq 'PriceSchedule')
{
ACTINIC::LogData("Doing price schedule search.", $::DC_SEARCH);
my $nScheduleID;
($status, $sError, $nScheduleID) = ACTINIC::GetCurrentScheduleID();
if ($status != $::SUCCESS)
{
SearchError($sError);
exit;
}
ACTINIC::LogData("Searching for products hidden for price schedule $nScheduleID.", $::DC_SEARCH);
if (ACTINIC::IsPriceScheduleConstrained($nScheduleID))
{
my $pPriceScheduleHits = {};
($status, $sError) = Search::SearchPriceSchedule($sPath, $nScheduleID, $pPriceScheduleHits);
if ($status != $::SUCCESS)
{
SearchError($sError);
exit;
}
push @$pResultsStack, [$TRUE_RESULT, $pPriceScheduleHits];
if ($::DEBUG_CLASS_FILTER & $::DC_SEARCH)
{
my @Results = keys %$pPriceScheduleHits;
my $nResults = scalar (@Results);
my $sResults = join (';', @Results);
ACTINIC::LogData("The price schedule search for '$nScheduleID' yielded $nResults hits\n    $sResults\n", $::DC_SEARCH);
}
}
else
{
ACTINIC::LogData("There are no price schedule based restraints on the product set.", $::DC_SEARCH);
push @$pResultsStack, [$SKIP_RESULT];
}
}
elsif ($sCmd eq 'And')
{
ACTINIC::LogData("Doing an intersection combine of search results (and).", $::DC_SEARCH);
if ($#$pResultsStack < 1)
{
ACTINIC::LogData("There are no sets to combine.", $::DC_SEARCH);
}
else
{
my $pArray1 = pop @$pResultsStack;
my $pArray2 = pop @$pResultsStack;
if ($pArray1->[0] == $SKIP_RESULT)
{
ACTINIC::LogData("List 1 contains the results of a search that was ignored by the searcher.  Using list 2.", $::DC_SEARCH);
push @$pResultsStack, $pArray2;
}
elsif ($pArray2->[0] == $SKIP_RESULT)
{
ACTINIC::LogData("List 2 contains the results of a search that was ignored by the searcher.  Using list 1.", $::DC_SEARCH);
push @$pResultsStack, $pArray1;
}
elsif ( ( $pArray1->[0] == $FALSE_RESULT) ||
( $pArray2->[0] == $FALSE_RESULT))
{
ACTINIC::LogData("Both lists are empty sets.  The combined list is an empty set", $::DC_SEARCH);
push @$pResultsStack, [$FALSE_RESULT];
}
else
{
ACTINIC::LogData("Both lists are populated with results.  Combining the list.  Length of list 1 = "
. (scalar keys %{$pArray1->[1]}) . ".  Length of list 2 = " . (scalar keys %{$pArray2->[1]}) . ".", $::DC_SEARCH);
my $pJoins = {};
JoinSearchResults( $pArray1->[1], $pArray2->[1], $::INTERSECT, $pJoins);
if (scalar (keys %$pJoins))
{
if ($::DEBUG_CLASS_FILTER & $::DC_SEARCH)
{
my @Results = keys %$pJoins;
my $nResults = scalar (@Results);
my $sResults = join (';', @Results);
ACTINIC::LogData("The combined list yielded $nResults hits\n    $sResults\n", $::DC_SEARCH);
}
push @$pResultsStack, [$TRUE_RESULT, $pJoins];
}
else
{
ACTINIC::LogData("The combined list is empty.", $::DC_SEARCH);
push @$pResultsStack, [$FALSE_RESULT];
}
}
}
}
elsif ($sCmd eq 'Or')
{
ACTINIC::LogData("Doing a union combine of search results (or).", $::DC_SEARCH);
if ($#$pResultsStack < 1)
{
ACTINIC::LogData("There are no sets to combine.", $::DC_SEARCH);
}
else
{
my $pArray1 = pop @$pResultsStack;
my $pArray2 = pop @$pResultsStack;
if ($pArray1->[0] == $FALSE_RESULT)
{
ACTINIC::LogData("List 1 is empty.  Using list 2.", $::DC_SEARCH);
push @$pResultsStack, $pArray2;
}
elsif ($pArray2->[0] == $FALSE_RESULT)
{
ACTINIC::LogData("List 2 is empty.  Using list 1.", $::DC_SEARCH);
push @$pResultsStack, $pArray1;
}
elsif ($pArray1->[0] == $SKIP_RESULT) # the first result set in ignored (no search criteria selected by the customer)
{
if ($pArray2->[0] == $SKIP_RESULT)
{
ACTINIC::LogData("Both list 1 and list 2 contain results of a search that is being ignored by the searcher.  The combined list is ignored as well.", $::DC_SEARCH);
push @$pResultsStack, [$SKIP_RESULT];
}
else
{
ACTINIC::LogData("List 1 contains results of a search that is being ignored by the searcher.  Using list 2.", $::DC_SEARCH);
push @$pResultsStack, $pArray2;
}
}
elsif ($pArray2->[0] == $SKIP_RESULT) # the second set is ignored (but if we are here, the first set is meaningful)
{
ACTINIC::LogData("List 2 contains results of a search that is being ignored by the searcher.  Using list 1.", $::DC_SEARCH);
push @$pResultsStack, $pArray1;
}
else
{
ACTINIC::LogData("Both lists are populated with results.  Combining the list.  Length of list 1 = "
. (scalar keys %{$pArray1->[1]}) . ".  Length of list 2 = " . (scalar keys %{$pArray2->[1]}) . ".", $::DC_SEARCH);
my $pJoins = {};
JoinSearchResults($pArray1->[1], $pArray2->[1], $::UNION, $pJoins);
if (scalar (keys %$pJoins))
{
if ($::DEBUG_CLASS_FILTER & $::DC_SEARCH)
{
my @Results = keys %$pJoins;
my $nResults = scalar (@Results);
my $sResults = join (';', @Results);
ACTINIC::LogData("The combined list yielded $nResults hits\n    $sResults\n", $::DC_SEARCH);
}
push @$pResultsStack, [$TRUE_RESULT, $pJoins];
}
else
{
ACTINIC::LogData("The combined list is empty.", $::DC_SEARCH);
push @$pResultsStack, [$FALSE_RESULT];
}
}
}
}
else
{
ACTINIC::LogData("Unknown search command.", $::DC_SEARCH);
my $sError = ACTINIC::GetPhrase(-1, 332, $sCmd, $sSearchFile);
SearchError($sError);
exit;
}
}
}
sub SearchError
{
my ($sMessage, $bWriteIntoLog) = @_;
if (!defined($bWriteIntoLog))
{
$bWriteIntoLog = $::TRUE;
}
my ($status, $sError, $sHTML) = ACTINIC::BounceToPageEnhanced(5, ACTINIC::GetPhrase(-1, 1962) . $sMessage . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2047),
'',
$::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $::Session->GetLastShopPage(), \%::g_InputHash,
$::FALSE);
if ($bWriteIntoLog)
{
ACTINIC::RecordErrors($sMessage, ACTINIC::GetPath());
}
else
{
ACTINIC::LogData($sMessage, $::DC_SEARCH);
}
ACTINIC::UpdateDisplay($sHTML, $::g_OriginalInputData);
}
sub DisplayResults
{
my ($sPath, $rhashResults, $nPageNumber, $sSearchStrings) = @_;
my @Results = sort keys %$rhashResults;
if ($#Results == -1)
{
return ($::NOTFOUND, ACTINIC::GetPhrase(-1, 267));
}
my $sFilename = $sPath . "results.html";
unless (open (TFFILE, "<$sFilename"))
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 21, $sFilename, $!));
}
my ($sHTML);
{
local $/;
$sHTML = <TFFILE>;
}
close (TFFILE);
my $sUrl = $::Session->GetBaseUrl();
if( $sUrl )
{
my $sReferer = $sUrl;
$sUrl =~ s/\/[^\/]*$/\//;
my $sStart = ACTINIC::EncodeText2(ACTINIC::GetPhrase(-1, 113), $::FALSE);
$sHTML =~ s/\?ACTION\=$sStart/\?ACTION\=$sStart\&BASE\=$sUrl/g;
my ($status, $sMessage, $sPageHistory);
$sPageHistory =$::Session->GetLastPage();
my $sReplace = "<INPUT TYPE=HIDDEN NAME=REFPAGE VALUE=\"$sPageHistory\">\n";
$sHTML =~ s/(<FORM\s[^>]*>)/$1$sReplace/gi;
}
unless ($sHTML =~ /<Actinic:SEARCH_RESULTS>(.*?)<\/Actinic:SEARCH_RESULTS>/si)
{
return ($::FAILURE, ACTINIC::GetPhrase(-1, 262));
}
my $sRepeatXML = $1;
my ($nMin, $nMax);
my $nResultsLimit = $$::g_pSearchSetup{SEARCH_RESULTS_PER_PAGE};
my $bResultsLimited = (0 != $nResultsLimit);
if (!$bResultsLimited)
{
$nMin = 0;
$nMax = $#Results + 1;
}
else
{
$nMin = $nPageNumber * $nResultsLimit;
$nMax = ($nPageNumber + 1) * $nResultsLimit;
}
if ($nMax > $#Results + 1)
{
$nMax = $#Results + 1;
}
my ($status, $sError, $sResults) = SearchResultsParser($sPath, $sRepeatXML, \@Results, $nMin, $nMax, $sSearchStrings, $rhashResults);
if ($status != $::SUCCESS)
{
return ($status, $sError);
}
$sHTML =~ s/<Actinic:SEARCH_RESULTS>.*?<\/Actinic:SEARCH_RESULTS>/$sResults/si;
my $sSummary = ACTINIC::GetPhrase(-1, 264, $nMin + 1, $nMax, ($#Results + 1));
my $sContinue;
if ($bResultsLimited)
{
my $sCustomNumber = '';
if (exists $::g_InputHash{SN})
{
$sCustomNumber = "&SN=$::g_InputHash{SN}";
}
my $sCustomSection = '';
if (exists $::g_InputHash{SX})
{
$sCustomSection = "&SX=$::g_InputHash{SX}";
}
my $sScript = sprintf('%s?TB=%s&GB=%s&SS=%s%s%s&PR=%s&PG=%s',
$::g_sSearchScript,
$::g_InputHash{TB},
$::g_InputHash{GB},
ACTINIC::EncodeText2($::g_InputHash{SS}, $::FALSE),
$sCustomNumber,
$sCustomSection,
$::g_InputHash{PR},
$::g_InputHash{PG});
if (defined $::g_InputHash{GROUPONLY})
{
$sScript .= "&GROUPONLY=1";
}
my %mapInputKeyToValueArray;
($status, $sError) = ParseSearchInput(\%mapInputKeyToValueArray);
if ($status != $::SUCCESS)
{
return ($status, $sError);
}
my ($sCgiParam, $plistValues);
while (($sCgiParam, $plistValues) = each %mapInputKeyToValueArray)
{
if ($sCgiParam =~ /S_.+\d+_\d+/)
{
my $sValue;
foreach $sValue (@$plistValues)
{
$sScript .= "&" . ACTINIC::EncodeText2($sCgiParam, $::FALSE) . "=" . ACTINIC::EncodeText2($sValue, $::FALSE);
}
}
}
my $sPathAndHistory = "&REFPAGE=" . ACTINIC::EncodeText2($::Session->GetLastShopPage(), $::FALSE) .
($::g_InputHash{SHOP} ? "&SHOP=" . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) : "");
$sScript .= $sPathAndHistory;
my $sLinkFormat = '<A HREF="%s">';
my $sLink;
if (0 != $nPageNumber)
{
$sLink = $sScript . "&PN=" . ($nPageNumber - 1);
$sLink = sprintf($sLinkFormat, $sLink);
$sContinue .= $sLink . ACTINIC::GetPhrase(-1, 265, $nResultsLimit) . "</A>"; # add the "Last 20" link
}
my $nPage;
my $nMaxPageCount = ActinicOrder::RoundTax(($#Results + 1) / $nResultsLimit, $ActinicOrder::CEILING);
my $sPageLabel;
for ($nPage = 0; $nPage < $nMaxPageCount; $nPage++)
{
$sPageLabel = ($nPage * $nResultsLimit + 1) . '-' . ((($nPage + 1) * $nResultsLimit) > ($#Results + 1) ? $#Results + 1 : ($nPage + 1) * $nResultsLimit);
$sLink = $sScript . "&PN=" . $nPage;
$sLink = sprintf($sLinkFormat, $sLink);
if ($nPage == $nPageNumber)
{
$sContinue .= " " . $sPageLabel;
}
else
{
$sContinue .= " " . $sLink . $sPageLabel . "</A>";
}
}
if ($nMaxPageCount != $nPageNumber + 1)
{
$sLink = $sScript . "&PN=" . ($nPageNumber + 1);
$sLink = sprintf($sLinkFormat, $sLink);
$sContinue .= " " . $sLink . ACTINIC::GetPhrase(-1, 266, $nResultsLimit) . "</A>"; # add the "Next 20" link
}
if (1 == $nMaxPageCount)
{
undef $sContinue;
}
}
$ACTINIC::B2B->ClearXML();
$ACTINIC::B2B->SetXML('S_SUMMARY',$sSummary);
$ACTINIC::B2B->SetXML('S_CONTINUE',$sContinue);
$sHTML = ACTINIC::ParseXML($sHTML);
if( !$ACTINIC::B2B->Get('UserDigest') )
{
($status, $sError, $sHTML) = ACTINIC::MakeLinksAbsolute($sHTML, $::g_sWebSiteUrl, $::g_sContentUrl);
}
else
{
my $sBaseFile = $ACTINIC::B2B->Get('BaseFile');
my $smPath = ($sBaseFile) ? $sBaseFile : $::g_sContentUrl;
my $sCgiUrl = $::g_sAccountScript;
$sCgiUrl   .= ($::g_InputHash{SHOP} ? '?SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) . '&' : '?');
$sCgiUrl   .= 'PRODUCTPAGE=';
($status, $sError, $sHTML) = ACTINIC::MakeLinksAbsolute($sHTML, $sCgiUrl, $smPath);
}
if ($status != $::SUCCESS)
{
return ($status, $sError);
}
ACTINIC::SaveSessionAndPrintPage($sHTML, undef, $::FALSE);
return ($::SUCCESS);
}
sub SearchResultsParser
{
my ($sPath, $sResultMarkup, $rarrResults, $nMin, $nMax, $sSearchStrings, $pmapResultProdRefToMatchingProperties) = @_;
my $rFile = \*PRODUCTINDEX;
my $sFilename = $sPath . "oldprod.fil";
my ($status, $sError) = ACTINIC::InitIndex($sFilename, $rFile, $::g_nSearchIndexVersion);
if ($status != $::SUCCESS)
{
return($status, $sError);
}
my $sScript;
if ($$::g_pSearchSetup{SEARCH_SHOW_HIGHLIGHT})
{
if ($ACTINIC::B2B->Get('UserDigest'))
{
$sScript = sprintf('%s?REFPAGE=%s&WD=%s%s&PRODUCTPAGE=',
$::g_sAccountScript,
ACTINIC::EncodeText2($::Session->GetLastPage(), $::FALSE),
ACTINIC::EncodeText2($sSearchStrings, $::FALSE),
($::g_InputHash{SHOP} ? "&SHOP=" . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) : ""));
}
else
{
$sScript = sprintf('%s?REFPAGE=%s&WD=%s%s&PN=',
$::g_sSearchHighLightScript,
ACTINIC::EncodeText2($::Session->GetLastPage(), $::FALSE),
ACTINIC::EncodeText2($sSearchStrings, $::FALSE),
($::g_InputHash{SHOP} ? "&SHOP=" . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) : ""));
}
}
else
{
if ($ACTINIC::B2B->Get('UserDigest'))
{
$sScript = sprintf('%s?REFPAGE=%s&WD=%s%s&PRODUCTPAGE=',
$::g_sAccountScript,
ACTINIC::EncodeText2($::Session->GetLastPage(), $::FALSE),
ACTINIC::EncodeText2($sSearchStrings, $::FALSE),
($::g_InputHash{SHOP} ? "&SHOP=" . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) : ""));
}
}
my ($sDummy, $pTree) = ACTINIC::PreProcessXMLTemplateString($sResultMarkup);
my $pXML = new Element({"_CONTENT" => $pTree});
my $sImageLineHTML 	= ACTINIC_PXML::GetTemplateFragment($pXML, "ImageLine");
my $nCount;
my $sHTML;
my $sTemp;
my %Product;
for ($nCount = $nMin; $nCount < $nMax; $nCount++)
{
($status, $sError) = ACTINIC::ProductSearch($$rarrResults[$nCount], $rFile, $sFilename, \%Product);
if ($status == $::FAILURE)
{
ACTINIC::CleanupIndex($rFile);
return($status, $sError);
}
if ($status == $::NOTFOUND)
{
ACTINIC::CleanupIndex($rFile);
return($status, ACTINIC::GetPhrase(-1, 263));
}
$ACTINIC::B2B->SetXML('S_ITEM', ($nCount + 1));
my $sImage;
if ($$::g_pSetupBlob{SEARCH_DISPLAYS_IMAGE} &&
(length $Product{IMAGE} > 0))
{
my %hVarTable;
$hVarTable{"NETQUOTEVAR:THUMBNAIL"} = $Product{IMAGE};
if ($$::g_pSetupBlob{SEARCH_USE_THUMBNAIL})
{
my $sWidth  = $$::g_pSetupBlob{SEARCH_THUMBNAIL_WIDTH}  == 0 ? "" : sprintf("width=%d ",  $$::g_pSetupBlob{SEARCH_THUMBNAIL_WIDTH});
my $sHeight = $$::g_pSetupBlob{SEARCH_THUMBNAIL_HEIGHT} == 0 ? "" : sprintf("height=%d ", $$::g_pSetupBlob{SEARCH_THUMBNAIL_HEIGHT});
$hVarTable{"NETQUOTEVAR:THUMBNAILSIZE"} = $sWidth . $sHeight;
}
($status, $sError, $sImage) = ACTINIC::TemplateString($sImageLineHTML, \%hVarTable);
if ($status != $::SUCCESS)
{
ACTINIC::CleanupIndex($rFile);
return($status, $sTemp);
}
}
$ACTINIC::B2B->SetXML('ImageLine', $sImage);
if ($$::g_pSearchSetup{SEARCH_SHOW_HIGHLIGHT} &&
$sSearchStrings)
{
$Product{ANCHOR} =~ /([^\#]*)(.*)/;
my $sAnchor = $2;
$ACTINIC::B2B->SetXML('S_LINK', sprintf('<A HREF="%s">', $sScript . ACTINIC::EncodeText2($Product{ANCHOR}, $::FALSE) . $sAnchor));
}
else
{
$ACTINIC::B2B->SetXML('S_LINK', sprintf('<A HREF="%s">', $Product{ANCHOR}));
}
$sTemp = "";
if ($$::g_pSearchSetup{SEARCH_SHOW_NAME})
{
($status, $sTemp) = ACTINIC::ProcessEscapableText($Product{NAME});
if ($status != $::SUCCESS)
{
ACTINIC::CleanupIndex($rFile);
return($status, $sTemp);
}
}
else
{
$sTemp = ACTINIC::GetPhrase(-1, 278);
}
$ACTINIC::B2B->SetXML('S_PNAME', $sTemp);
$sTemp = "";
if ($$::g_pSearchSetup{SEARCH_SHOW_SECTION})
{
($status, $sTemp) = ACTINIC::ProcessEscapableText($Product{SECTION});
if ($status != $::SUCCESS)
{
ACTINIC::CleanupIndex($rFile);
return($status, $sTemp);
}
$sTemp = "($sTemp)";
}
$ACTINIC::B2B->SetXML('S_SNAME', $sTemp);
$sTemp = "";
if ($$::g_pSearchSetup{SEARCH_SHOW_DESCRIPTION})
{
($status, $sTemp) = ACTINIC::ProcessEscapableText($Product{DESCRIPTION});
if ($status != $::SUCCESS)
{
ACTINIC::CleanupIndex($rFile);
return($status, $sTemp);
}
}
$ACTINIC::B2B->SetXML('S_DESCR', $sTemp);
$sTemp = "";
if ($$::g_pSearchSetup{SEARCH_SHOW_PRICE} &&
$$::g_pSetupBlob{PRICES_DISPLAYED} &&
$Product{PRICE} != 0)
{
($status, $sError, $sTemp) = ActinicOrder::FormatPrice($Product{PRICE}, $::TRUE, $::g_pCatalogBlob);
if ($status != $::SUCCESS)
{
ACTINIC::CleanupIndex($rFile);
return($status, $sError);
}
}
$ACTINIC::B2B->SetXML('S_PRICE', $sTemp);
$sTemp = "";
if ($$::g_pSearchSetup{SEARCH_SHOW_PROPERTY} && # does the user want it? and
ref($pmapResultProdRefToMatchingProperties->{$rarrResults->[$nCount]}) eq "ARRAY")
{
my $sLine;
foreach $sLine (@{$pmapResultProdRefToMatchingProperties->{$rarrResults->[$nCount]}})
{
$sTemp .= $sLine;
}
}
$ACTINIC::B2B->SetXML('S_PROP', $sTemp);
$sHTML .= ACTINIC::ParseXML($sResultMarkup);
}
ACTINIC::CleanupIndex($rFile);
return ($::SUCCESS, undef, $sHTML);
}
sub DirectLinkToProduct
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
if ($status == $::FAILURE)
{
ACTINIC::CleanupIndex($rFile);
SearchError($sError);
}
if ($status == $::NOTFOUND)
{
ACTINIC::CleanupIndex($rFile);
my ($status, $sError, $sHTML) = ACTINIC::BounceToPageEnhanced(5, ACTINIC::GetPhrase(-1, 1962) . ACTINIC::GetPhrase(-1, 1965, $sProdRef) . ACTINIC::GetPhrase(-1, 1970) . ACTINIC::GetPhrase(-1, 2048),
'', $::g_sWebSiteUrl, $::g_sContentUrl,
$::g_pSetupBlob, ACTINIC::GetReferrer(), \%::g_InputHash, $::FALSE);
return($sHTML);
}
my $sLink = $Product{ANCHOR};
ACTINIC::CleanupIndex($rFile);
return(DisplayDirectLinkPage($sLink, $::FALSE, $sProdRef));
}
sub DisplayDirectLinkPage
{
my $sLink		= shift;
my $bClearFrames = shift;
my $sProdRef	= shift;
my $sBaseFile = $ACTINIC::B2B->Get('BaseFile');
my $sReferrer = ACTINIC::GetReferrer();
my $sCgiUrl = $::g_sAccountScript;
$sCgiUrl   .= ($::g_InputHash{SHOP} ? '?SHOP=' . ACTINIC::EncodeText2($::g_InputHash{SHOP}, $::FALSE) . '&' : '?');
$sReferrer = $::Session->GetBaseUrl();
if ($ACTINIC::B2B->Get('UserDigest'))
{
$sLink =~ /([^\#]*)(.*)/;
my $sAnchor = $2;
$sLink = !$bClearFrames || $::g_InputHash{NOCLEARFRAMES} ||
!$$::g_pSetupBlob{USE_FRAMES} ?
$sCgiUrl . "PRODUCTPAGE=" . ACTINIC::EncodeText2($sLink, $::FALSE) :
$sCgiUrl . "MAINFRAMEURL=" . ACTINIC::EncodeText2($sLink, $::FALSE);
if ($sProdRef)
{
$sLink .= "&PRODUCTREF=" . $sProdRef;
}
if ($sAnchor)
{
$sLink .= $sAnchor;
}
}
else
{
if ($$::g_pSetupBlob{B2B_MODE} &&
!$::g_InputHash{NOLOGIN})
{
my @Response = ACTINIC::TemplateFile(ACTINIC::GetPath() . $$::g_pSetupBlob{B2B_LOGONPAGE});
if ($Response[0] != $::SUCCESS)
{
ACTINIC::TerminalError($Response[1]);
}
$sLink =~ /([^\#]*)(.*)/;
my $sAnchor = $2;
my $sReplace = $$::g_pSetupBlob{USE_FRAMES} ? "<INPUT TYPE=HIDDEN NAME=MAINFRAMEURL VALUE=\"".  $sLink . "\">" :
"<INPUT TYPE=HIDDEN NAME=PRODUCTPAGE VALUE=\"". $sLink . "\">";
if ($::g_InputHash{TARGET} eq "BROCHURE")
{
$sReplace = "<INPUT TYPE=HIDDEN NAME=BROCHUREMAINFRAMEURL VALUE=\"".  $sLink . "\">";
}
if ($sProdRef)
{
$sReplace .= "<INPUT TYPE=HIDDEN NAME=PRODUCTREF VALUE=\"". $sProdRef . "\">";
}
$sReplace .= "<INPUT TYPE=HIDDEN NAME=\"ACTINIC_REFERRER\" VALUE=\"$sReferrer\">";
$Response[2] =~ s/<FORM([^>]+ACTION\s*?=\s*?["'])\s*?(.*?$::g_sAccountScriptName)\s*?(["'][^>]*?>)/<FORM$1$2$sAnchor$3$sReplace/gi; #'
if ($sProdRef)
{
if (ACTINIC::IsPriceScheduleConstrained($ActinicOrder::RETAILID) &&
!ACTINIC::IsProductVisible($sProdRef, $ActinicOrder::RETAILID))
{
$ACTINIC::B2B->SetXML('PRODUCTNOTAVAILABLE', ACTINIC::GetPhrase(-1, 2176));# add the 'Product is not available for retail' warning to the page
}
}
my $sSearch = $$::g_pSetupBlob{USE_FRAMES} ? $$::g_pSetupBlob{FRAMESET_PAGE} : $$::g_pSetupBlob{CATALOG_PAGE};
$sReplace = !$$::g_pSetupBlob{USE_FRAMES} || $::g_InputHash{TARGET} eq "BROCHURE" ? $sLink :
$sCgiUrl . "ACTION=DIRECTLINK&MAINFRAMEURL=" . ACTINIC::EncodeText2($::g_sContentUrl . $sLink, $::FALSE) .
"&ACTINIC_REFERRER=" . ACTINIC::EncodeText2($sReferrer , $::FALSE);
$Response[2] =~ s/(<A[^>]*?HREF\s?=\s?["'].*?)$sSearch(["']\s?>)/$1$sReplace$2/gi; #'
if ($$::g_pSetupBlob{USE_SSL} &&
($$::g_pSetupBlob{SSL_USEAGE} == 1))
{
if ($sProdRef)
{
$sReplace = sprintf("%s?PRODREF=%s", $::g_sSSLSearchScript, $sProdRef);
}
else
{
$sReplace = sprintf("%s?SECTIONID=%s", $::g_sSSLSearchScript, $sLink);
}
$Response[2] =~ s/NETQUOTEVAR:SSLREDIRECT/$sReplace/;
}
return($Response[2]);
}
else
{
if (($sLink eq $$::g_pSetupBlob{CATALOG_PAGE}) &&
($$::g_pSetupBlob{USE_FRAMES}))
{
$sLink = $$::g_pSetupBlob{FRAMESET_PAGE};
}
$sLink = $::g_sContentUrl . $sLink;
}
}
my @Response = ACTINIC::BounceToPagePlain(0, undef, undef, $::g_sWebSiteUrl,
$::g_sContentUrl, $::g_pSetupBlob, $sLink, \%::g_InputHash);
if ($Response[0] != $::SUCCESS)
{
ACTINIC::ReportError($Response[1], ACTINIC::GetPath());
}
return($Response[2]);
}
sub JoinSearchResults
{
my ($phash1, $phash2, $bOperation, $phashOutput) = @_;
undef %$phashOutput;
my $sProductReference;
if ($bOperation == $::INTERSECT)
{
foreach $sProductReference (keys %$phash1)
{
if (exists $phash2->{$sProductReference})
{
$phashOutput->{$sProductReference} = [];
if (ref($phash1->{$sProductReference}) eq "ARRAY")
{
push @{$phashOutput->{$sProductReference}}, @{$phash1->{$sProductReference}};
}
if (ref($phash2->{$sProductReference}) eq "ARRAY")
{
push @{$phashOutput->{$sProductReference}}, @{$phash2->{$sProductReference}};
}
}
}
}
else
{
%$phashOutput = %$phash1;
foreach $sProductReference (keys %$phash2)
{
unless (exists $phashOutput->{$sProductReference} &&
ref($phashOutput->{$sProductReference}) eq "ARRAY")
{
$phashOutput->{$sProductReference} = [];
}
if (ref($phash2->{$sProductReference}) eq "ARRAY")		      # if list two contains a list of matching product properties,
{
push @{$phashOutput->{$sProductReference}}, @{$phash2->{$sProductReference}};
}
}
}
}