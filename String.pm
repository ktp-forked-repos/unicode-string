package Unicode::String;

# Copyright (c) 1997, Gisle Aas.

use strict;
use vars qw($VERSION @ISA @EXPORT_OK);
use Carp;

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);

@EXPORT_OK = qw(utf16 utf8 utf7 ucs2 ucs4 latin1 uchr);

$VERSION = sprintf("%d.%02d", q$Revision$ =~ /(\d+)\.(\d+)/);

bootstrap Unicode::String $VERSION;

use overload ( '""' => \&as_string,
	       '.=' => \&append,
               '.'  => \&concat,
               'x'  => \&repeat,
	       '='  => \&copy,
               'fallback' => 1 );

my %stringify = (
   unicode => \&utf16,
   utf16   => \&utf16,
   utf8    => \&utf8,
   utf7    => \&utf7,
   ucs4    => \&ucs4,
   latin1  => \&latin1,
   'hex'   => \&hex,
);

my $stringify_as = \&utf8;

sub new
{
    my $class = shift;
    my $str;
    my $self = bless \$str, $class;
    &$stringify_as($self, shift) if @_;
    $self;
}

sub repeat
{
    my($self, $count) = @_;
    my $class = ref($self);
    $class->new($$self x $count);
}

sub concat
{
    my($self, $other) = @_;
    my $class = ref($self);
    unless (UNIVERSAL::isa($other, 'Unicode::String')) {
	$other = Unicode::String->new($other);
    }
    $class->new($$self . $$other);
}

sub append
{
    my($self, $other) = @_;
    unless (UNIVERSAL::isa($other, 'Unicode::String')) {
	$other = Unicode::String->new($other);
    }
    $$self .= $$other;
    $self;
}

sub copy
{
    my($self) = @_;
    my $class = ref($self);
    my $copy = $$self;
    bless \$copy, $class;
}


sub as_string
{
    &$stringify_as($_[0]);
}


sub stringify_as
{
    my $class;
    if (@_ > 1) {
	$class = shift;
	$class = ref($class) if ref($class);
    } else {
	$class = "Unicode::String";
    }
    my $as = shift;
    croak("Don't know how to stringify as '$as'")
        unless exists $stringify{$as};
    $stringify_as = $stringify{$as};
}


sub utf16
{
    my $self = shift;
    unless (ref $self) {
	my $u = new Unicode::String;
	$u->utf16($self);
	return $u;
    }
    my $old = $$self;;
    if (@_) {
	$$self = shift;
    }
    $old;
}

*ucs2 = \&utf16;


sub ucs4
{
    my $self = shift;
    unless (ref $self) {
	my $u = new Unicode::String;
	$u->ucs4($self);
	return $u;
    }
    my $old = pack("N*", $self->ord);
    if (@_) {
	$$self = "";
	for (unpack("N*", shift)) {
	    $self->append(uchr($_));
	}
    }
    $old;
}


sub utf8
{
    my $self = shift;
    unless (ref $self) {
	# act as ctor
	my $u = new Unicode::String;
	$u->utf8($self);
	return $u;
    }

    my $old;
    if (defined $$self) {
	# encode UTF-8
	my $uc;
	for $uc (unpack("n*", $$self)) {
	    if ($uc < 0x80) {
		# 1 byte representation
		$old .= chr($uc);
	    } elsif ($uc < 0x800) {
		# 2 byte representation
		$old .= chr(0xC0 | ($uc >> 6)) .
                        chr(0x80 | ($uc & 0x3F));
	    } else {
		# 3 byte representation
		$old .= chr(0xE0 | ($uc >> 12)) .
		        chr(0x80 | (($uc >> 6) & 0x3F)) .
			chr(0x80 | ($uc & 0x3F));
	    }
	}
    }

    if (@_) {
	if (defined $_[0]) {
	    $$self = "";
	    my $bytes = shift;
	    $bytes =~ s/^[\200-\277]+//;  # can't start with 10xxxxxx
	    while (length $bytes) {
		if ($bytes =~ s/^([\000-\177]+)//) {
		    $$self .= pack("n*", unpack("C*", $1));
		} elsif ($bytes =~ s/^([\300-\337])([\200-\277])//) {
		    my($b1,$b2) = (ord($1), ord($2));
		    $$self .= pack("n", (($b1 & 0x1F) << 6) | ($b2 & 0x3F));
		} elsif ($bytes =~ s/^([\340-\357])([\200-\277])([\200-\277])//) {
		    my($b1,$b2,$b3) = (ord($1), ord($2), ord($3));
		    $$self .= pack("n", (($b1 & 0x0F) << 12) |
                                        (($b2 & 0x3F) <<  6) |
				         ($b3 & 0x3F));
		} else {
		    croak "Bad UTF-8 data";
		}
	    }
	} else {
	    $$self = undef;
	}
    }

    $old;
}


sub latin1_old   # implemented as XS now
{
    my $self = shift;
    unless (ref $self) {
	# act as ctor
	my $u = new Unicode::String;
	$u->latin1($self);
	return $u;
    }

    my $old;
    # XXX: should really check that none of the chars > 256
    $old = pack("C*", unpack("n*", $$self)) if defined $$self;

    if (@_) {
	# set the value
	if (defined $_[0]) {
	    $$self = pack("n*", unpack("C*", $_[0]));
	} else {
	    $$self = undef;
	}
    }
    $old;
}


sub hex
{
    my $self = shift;
    unless (ref $self) {
	my $u = new Unicode::String;
	$u->hex($self);
	return $u;
    }
    my $old;
    if (defined $$self) {
	$old = unpack("H*", $$self);
	$old =~ s/(....)/U+$1 /g;
	$old =~ s/\s+$//;
    }
    if (@_) {
	my $new = shift;
	$new =~ tr/0-9A-Fa-f//cd;  # leave only hex chars
	$$self = pack("H*", $new);
    }
    $old;
}


sub length
{
    my $self = shift;
    length($$self) / 2;
}


sub unpack
{
    my $self = shift;
    unpack("n*", $$self)
}


sub pack
{
    my $self = shift;
    $$self = pack("n*", @_);
    $self;
}


sub ord
{
    my $self = shift;
    return () unless defined $$self;

    my $array = wantarray;
    my @ret;
    my @chars;
    if ($array) {
        @chars = unpack("n*", $$self);
    } else {
	@chars = unpack("n2", $$self);
    }

    while (@chars) {
	my $first = shift(@chars);
	if ($first >= 0xD800 && $first <= 0xDFFF) { 	# surrogate
	    my $second = shift(@chars);
	    #print "F=$first S=$second\n";
	    if ($first >= 0xDC00 || $second < 0xDC00 || $second > 0xDFFF) {
		carp(sprintf("Bad surrogate pair (U+%04x U+%04x)",
			     $first, $second));
		unshift(@chars, $second);
		next;
	    }
	    push(@ret, ($first-0xD800)*0x400 + ($second-0xDC00) + 0x10000);
	} else {
	    push(@ret, $first);
	}
	last unless $array;
    }
    $array ? @ret : $ret[0];
}


sub uchr
{
    my($self,$val) = @_;
    unless (ref $self) {
	# act as ctor
	my $u = new Unicode::String;
	return $u->uchr($self);
    }
    if ($val > 0xFFFF) {
	# must be represented by a surrogate pair
	return undef if $val > 0x10FFFF;  # Unicode limit
	$val -= 0x10000;
	my $h = int($val / 0x400) + 0xD800;
	my $l = ($val % 0x400) + 0xDC00;
	$$self = pack("n2", $h, $l);
    } else {
	$$self = pack("n", $val);
    }
    $self;
}


sub substr
{
    my($self, $offset, $length) = @_;
    $offset *= 2;
    $length *= 2;
    my $substr = substr($$self, $offset, $length);
    bless \$substr, ref($self);
}

1;
