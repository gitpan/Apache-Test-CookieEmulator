package Apache::Test::CookieEmulator;

use vars qw($VERSION);
$VERSION = do { my @r = (q$Revision: 0.04 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

# Oh!, we really don't live in this package

package Apache::Cookie;
use vars qw($Cookies);
use strict;

$Cookies = {};

# emluation is fairly complete
# cookies can be created, altered and removed
#
sub fetch { return wantarray ? %{$Cookies} : $Cookies; }
sub path {&do_this;}
sub expires {&do_this;}
sub secure {&do_this;}
sub name {&do_this;}
sub domain {&do_this;}
sub value {
  my ($self, $val) = @_;
  $self->{-value} = $val if defined $val;
  if (defined $self->{-value}) {
    return wantarray ? @{$self->{-value}} : $self->{-value}->[0]
  } else {
    return wantarray ? () : '';
  }
}
sub new {
  my $proto = shift;	# bless into Apache::Cookie
  shift;		# waste reference to $r;
  my @vals = @_;
  my $self = {@vals};
  my $class = ref($proto) || $proto;
# make sure values are in array format
  my $val = $self->{-value};;
  if (defined $val) {
    $val = $self->{-value};
    if (ref($val) eq 'ARRAY') {
      @vals = @$val;
    } elsif (ref($val) eq 'HASH') {
      @vals = %$val;
    } elsif (!ref($val)) {
      @vals = ($val);	# it's a plain SCALAR
    }	# hmm.... must be a SCALAR ref or CODE ref
    $self->{-value} = [@vals];
  }
  bless $self, $class;
  return $self;
}
sub bake {
  my $self = shift;
  if ( defined $self->{-value} ) {
    $Cookies->{$self->{-name}} = $self;
  } else {
    delete $Cookies->{$self->{-name}};
  }
}
sub parse {		# pretty much taken from CGI::Cookie v1.20 by Lincoln Stein
  my ($self,$raw_cookie) = @_;
  if ($raw_cookie) {
    my $class = ref($self) || $self;
    my %results;

    my(@pairs) = split("; ?",$raw_cookie);
    foreach (@pairs) {
      s/\s*(.*?)\s*/$1/;
      my($key,$value) = split("=",$_,2);
    # Some foreign cookies are not in name=value format, so ignore
    # them.
      next if !defined($value);
      my @values = ();
      if ($value ne '') {
        @values = map unescape($_),split(/[&;]/,$value.'&dmy');
        pop @values;
      }
      $key = unescape($key);
      # A bug in Netscape can cause several cookies with same name to
      # appear.  The FIRST one in HTTP_COOKIE is the most recent version.
      $results{$key} ||= $self->new(undef,-name=>$key,-value=>\@values);
    }
    $self = \%results;
    bless $self, $class;
    $Cookies = $self;
  }
  @_ = ($self);
  goto &fetch;
}
sub remove {
  my ($self,$name) = @_;
  if ($name) {
    delete $Cookies->{$name} if exists $Cookies->{$name};
  } else {
    delete $Cookies->{$self->{-name}}
	if exists $Cookies->{$self->{-name}};
  }
}

sub as_string {
  my $self = shift;
  return '' unless $self->name;
  my %cook = %$self;
  my $cook = ($cook{-name}) ? escape($cook{-name}) . '=' : '';
  if ($cook{-value}) {
    my $i = '';
    foreach(@{$cook{-value}}) {
      $cook .= $i . escape($_);
      $i = '&'; 
    }
  }  
  foreach(qw(domain path expires)) {
    $cook .= "; $_=" . $cook{"-$_"} if $cook{"-$_"};
  }
  $cook .= ($cook{-secure}) ? '; secure' : '';
}

### helpers
sub do_this {
  (caller(1))[3] =~ /[^:]+$/;
  splice(@_,1,0,'-'.$&);
  goto &cookie_item;
}
# get or set a named item in cookie hash
sub cookie_item {
  my($self,$item,$val) = @_;
  if ( defined $val ) {
#
# Darn! this modifies a cookie item if user is generating
# a replacement cookie and has not yet "baked" it... 
# Don't see how this can hurt in the real world...  MAR 9-2-02
    if ( $item eq '-name' &&
	 exists $Cookies->{$self->{-name}} ) {
      $Cookies->{$val} = $Cookies->{$self->{-name}};
      delete  $Cookies->{$self->{-name}};
    }
    $self->{$item} = $val;
  }
  return (exists $self->{$item}) ? $self->{$item} : '';
}
sub escape {
  my ($x) = @_;
  return undef unless defined($x);
  $x =~ s/([^a-zA-Z0-9_.-])/uc sprintf("%%%02x",ord($1))/eg;
  return $x;
}
# unescape URL-data, but leave +'s alone
sub unescape {  
  my ($x) = @_;
  return undef unless defined($x);
  $x =~ tr/+/ /;       # pluses become spaces
  $x =~ s/%([0-9a-fA-F]{2})/pack("c",hex($1))/ge;
  return $x;
}
1
__END__

=head1 NAME

  Test::Apache::CookieEmulator - test tool for Cookies without httpd

=head1 SYNOPSIS

  use Test::Apache::CookieEmulator;

  loads into Apache::Cookie namespace

=head1 DESCRIPTION

This module assists authors of Apache::* modules write test suites that 
would use B<Apache::Cookie> without actually having to run and query
a server to test the cookie methods. Loaded in the test script after the
author's target module is loaded, B<Test::Apache::CookieEmulator>

Usage is the same as B<Apache::Cookie>

=head1 METHODS

Implements all methods of Apache::Cookie

See man Apache::Cookie for details of usage.

=over 4

=item remove	-- new method

Delete the given named cookie or the cookie represented by the pointer

  $cookie->remove;

  Apache::Cookie->remove('name required');

  $cookie->remove('some name');
	for test purposes, same as:
    $cookie = Apache::Cookie->new($r,
	-name	=> 'some name',
    );
    $cookie->bake;

=item new

  $cookie = Apache::Cookie->new($r,
	-name	 => 'some name',
	-value	 => 'my value',
	-expires => 'text for testing',
	-path	 => 'some path',
	-domain	 => 'some.domain',
	-secure	 => 1,
  );

The B<Apache> request object, B<$r>, is not used and may be undef.

=item bake

  Store the cookie in local memory.

  $cookie->bake;

=item fetch

  Return cookie values from local memory

  $cookies = Apache::Cookie->fetch;	# hash ref
  %cookies = Apache::Cookie->fetch;

=item as_string

  Format the cookie object as a string, 
  same as Apache::Cookie

=item parse

  The same as fetch unless a cookie string is present.

  $cookies = Apache::Cookie->fetch(raw cookie string);
  %cookies = Apache::Cookie->fetch(raw cookie string)

  Cookie memory is cleared and replaced with the contents
  of the parsed "raw cookie string".

=item name, value, domain, path, expires, secure

  Get or set the value of the designated cookie.
  These are all just text strings for test use,
  no date conversion is done for "expires".
  "value" accepts SCALARS, HASHrefs, ARRAYrefs

=back

=head1 SEE ALSO

Apache::Cookie(3)

=head1 AUTHOR

Michael Robinton michael@bizsystems.com

=head1 COPYRIGHT and LICENSE

  Copyright 2002 Michael Robinton, BizSystems.

This module is free software; you can redistribute it and/or modify it
under the terms of either:

  a) the GNU General Public License as published by the Free Software
  Foundation; either version 1, or (at your option) any later version,
  
  or

  b) the "Artistic License" which comes with this module.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
the GNU General Public License or the Artistic License for more details.

You should have received a copy of the Artistic License with this
module, in the file ARTISTIC.  If not, I'll be glad to provide one.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

=cut
