# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
use diagnostics;
######################### We start with some black magic to print on failure.
# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..47\n"; }
END {print "not ok 1\n" unless $loaded;}

use Apache::Test::CookieEmulator;
$loaded = 1;
print "ok 1\n";
######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

$test = 2;

*escape = \&Apache::Cookie::escape;

sub ok {
  print "ok $test\n";
  ++$test;
}

# input is array of cookie values
sub fake_cookie {
  my $cookie = {@_};
  my (@vals,$val);
  if ( exists $cookie->{-value} && defined $cookie->{-value} ) {
    $val = $cookie->{-value};
    if (ref($val) eq 'HASH') {
      @vals = %$val;
    } elsif (ref($val) eq 'ARRAY') {
      @vals = @$val;
    }
  } else {
    @vals = ($val);
  }
  $cookie->{-value} = [@vals];
  return $cookie;
}

# input is pointer to cookie hash or array

=pod

sub cook2text {
  my $cp = shift;
  my %cook = %$cp;
  my $cook = ($cook{-name}) ? escape($cook{-name}) . '=' : '';
  if ($cook{-value}) {
    my $i = 0;
    while (1) {
      $cook .= escape($cook{-value}->[$i]);
      last if ++$i > $#{$cook{-value}};
    } continue {
      $cook .= '&';
    }
  }
  foreach(qw(domain path expires)) {
    $cook .= "; $_=" . $cook{"-$_"} if $cook{"-$_"};
  }
  $cook .= ($cook{-secure}) ? '; secure' : '';
}

=cut

sub cook2text {		# inspired by  CGI::Cookie, Lincoln D. Stein.
  my $cp = shift;
  return '' unless $cp->{-name};

  my @constant_values;

  push(@constant_values,'domain='.$cp->{-domain})
	if exists $cp->{-domain} && defined $cp->{-domain};
  push(@constant_values,'path='.$cp->{-path})
	if exists $cp->{-path} && defined $cp->{-path};
  push(@constant_values,'expires='.$cp->{-expires})
	if exists $cp->{-expires} && defined $cp->{-expires};
  push(@constant_values,'secure') 
	if exists $cp->{-secure} && $cp->{-secure};

  my($key) = escape($cp->{-name});
  my($cookie) = (exists $cp->{-value} && defined $cp->{-value})
	? join("=",$key,join("&",map escape($_),@{$cp->{-value}}))
	: '';
  return join("; ",$cookie,@constant_values);
}

my $r = undef;			# never used

### cookie tests

my %testcookie = (
	-name	=> "testcookie",
	-value	=> ['some value'],
	-path	=> '/a/path',
	-expires,  '+3m',
	-secure	=> '1',
	-domain	=> 'foo.com',
);

my %tc2 = (
	-name	=> "tc2",
	-value	=> ['2some value'],
	-path	=> '2/a/path',
	-expires,  '2+3m',
	-secure	=> '21',
);

my %tc3 = (
	-name	=> 'tc3',
	-value	=> ['value 3'],
);	# small cookie

my %tcd = (		# will cause removal
	-name	=> 'testcookie',
);

my $finder = {
	testcookie	=> \%testcookie,
	tc2		=> \%tc2,
	tc3		=> \%tc3,
};

# input is cookie name
sub check_cook {
  my ($name,$cookie) = @_;
  my $expected = cook2text($finder->{$name});
  print "bad cookie value,
results:  $_
   ne
expected: $expected\nnot "
	unless $expected eq ($_ = $cookie->as_string);
  &ok;
}

## test 2	test internal cookie generation
my $fake = fake_cookie(%testcookie);
my $expected = cook2text(\%testcookie);
print "internal test implementation failed
fake: $_
   ne
cook: $expected\nnot "
	unless $expected eq ($_ = cook2text($fake));
&ok;

## test 3	check cookie generation
my $cookie = Apache::Cookie->new($r,%testcookie);
print "failed to create cookie,
results:  $_
   ne
expected: $expected\nnot "
	unless $expected eq ($_ = cook2text($cookie));
&ok;

## test 4	check as_string
print "as_string failure:
results:  $_
   ne
expected: $expected\nnot "
	unless $expected eq ($_ = $cookie->as_string);
&ok;

## test 5	fetch should fail

my $cookies = Apache::Cookie->fetch;
print "found unwanted cookies\nnot "
	if scalar %$cookies;
&ok;

## test 6	insert cookie and check value
$cookie->bake;
my %cookies = Apache::Cookie->fetch;
my $count = 0;
foreach (keys %cookies) {
  ++$count;
  check_cook($_,$cookies{$_});
}

## test 7	count should be one
print "bad cookie count $count\nnot "
	unless $count == 1;
&ok;

## test 8 - 10	add and check all cookies
my @cooks = keys %{$finder};
foreach(@cooks) {
  my $cookie = Apache::Cookie->new($r,%{$finder->{$_}});
  $cookie->bake;
}

# one of the cookies was a duplicate
# also check that "parse" is a stand in for "fetch"
%cookies = Apache::Cookie->parse;
$count = 0;
foreach (keys %cookies) {
  ++$count;
  check_cook($_,$cookies{$_});
}

## test 11	3 cookies
print "bad cookie count $count\nnot "
	unless $count == @cooks;
&ok;

## test 12 - 13	delete a cookie with bake
$cookie = Apache::Cookie->new($r,%tcd);
$cookie->bake;
%cookies = Apache::Cookie->fetch;
$count = 0;
foreach (keys %cookies) {
  ++$count;
  check_cook($_,$cookies{$_});
}

## test 14	2 cookies
print "bad cookie count $count\nnot "
        unless $count == @cooks -1;
&ok;

## test 15 - 16	remaining cookies should be...
foreach my $x (qw(tc2 tc3)) {
  check_cook($x,$cookies{$x});
}

## test 17	remove a cookie directly, use hash pointer
$cookies{tc2}->remove;
$cookies = Apache::Cookie->fetch;
$count = 0;
foreach (keys %$cookies) {
  ++$count;
  check_cook($_,$cookies->{$_});
}

## test 18	1 cookie left
print "bad cookie count $count\nnot "
        unless $count == 1;
&ok;

## test 19 - 21	add and check all cookies
foreach(keys %$finder) {
  my $cookie = Apache::Cookie->new($r,%{$finder->{$_}});
  $cookie->bake;
}
$cookies = Apache::Cookie->fetch;
$count = 0;
foreach (keys %$cookies) {
  ++$count;
  check_cook($_,$cookies->{$_});
}

## test 22	should be 3 cookies
print "bad cookie count $count\nnot "
	unless $count == 3;
&ok;

## test 23	remove by name
$cookies->{tc2}->remove('testcookie');
$cookies->{tc2}->remove('tc3');
$cookies = Apache::Cookie->fetch;
$count = 0;
foreach (keys %$cookies) {
  ++$count;
  check_cook($_,$cookies->{$_});
}
 
## test 24      1 cookie left
print "bad cookie count $count\nnot "
        unless $count == 1;
&ok;

## test 25	remaining cookie should be tc2
print "cookie missing\nnot "
	unless exists $cookies->{tc2};
&ok;

## test 26 - 29	test fetch
my @keys = qw(path domain secure expires );
foreach (@keys) {
  my $cv = $tc2{"-$_"} || '';
  print "bad value for tc2 -$_ : $cv\nnot "
	unless $cookies->{tc2}->$_ eq $cv;
  &ok;
}

## test 30	check values
my $err;
my @values = $cookies->{tc2}->value;
foreach(0..$#values) {
  unless ($tc2{-value}->[$_] eq $values[$_]) {
    $err = $tc2{-value}->[$_]. " ne " . ($values[$_]) . "\n";
  }
}
print $err . 'not ' if $err;
&ok;

## test 31	last one, a bit redundant
print "bad value for tc2 -name : $_\nnot "
	unless ($_ = $cookies->{tc2}->{-name});
&ok;

## test 32 - 35	test put
my $start = $count;
foreach(@keys) {
  $cookies->{tc2}->$_(++$count);
}
$count = $start;
foreach(@keys) {
  print "results:  ",$cookies->{tc2}->$_, "\n   ne\nexpected: ",$start,"\nnot "
	unless $cookies->{tc2}->$_ == ++$count;
  &ok;
}

## test 36	test put of values
$cookies->{tc2}->value([@keys]);
@values = $cookies->{tc2}->value;
foreach(0..$#keys) {
  unless ($keys[$_] eq $values[$_]) {
    print "value array not stored\nnot ";
    last;
  }
}
&ok;	 

# trailing action
$_  = [reverse @keys];
$cookies->{tc2}->value($_);

## test 37	change the name
$cookies->{tc2}->name('newname');
$cookies = Apache::Cookie->fetch;
print "failed to change name\nnot "
	if exists $cookies->{tc2};
&ok;

## test 38 - 41	recheck under new name, should work
$count = $start;
foreach(@keys) {
  print "results:  ",$cookies->{newname}->$_, "\n   ne\nexpected: ",$start,"\nnot "
        unless $cookies->{newname}->$_ == ++$count;
  &ok;
}

## test 42	check returned hash
my %hash = $cookies->{newname}->value;
foreach(my $i=0; $i<=$#keys; $i+=2) {
  unless ($keys[$i] eq $hash{$keys[$i+1]}) {
    print "value hash not stored\nnot ";
    last;
  }
}
&ok;

## test 43 - 44	check that parse can handle a new cookie string
my $cook1 = 'Cookie1=foo&bar&stuff&more';
my $cook2 = 'Cookie2=some%40email.com' ;
my %cook1 = (
	-name	=> 'Cookie1',
	-value	=> [qw( foo bar stuff more)],
);
my %cook2 = (
	-name	=> 'Cookie2',
	-value	=> ['some@email.com'],
);
$finder->{Cookie1} = \%cook1;
$finder->{Cookie2} = \%cook2;

$cookies = Apache::Cookie->parse($cook1 .'; '. $cook2);
$count = 0;
foreach $_ (keys %{$cookies}) {
  check_cook($_, $cookies->{$_});
  ++$count;
}

## test 45	count should be two
print "bad cookie count $count\nnot "
        unless $count == 2;
&ok;

## test 46	repeat with only one cookie string
$count = 0;
$cookies = $cookies->parse($cook2);
foreach $_ (keys %{$cookies}) {
  check_cook($_, $cookies->{$_});
  ++$count;
}

## test 47      count should be one
print "bad cookie count $count\nnot "
        unless $count == 1;
&ok;
