package Array::Find;
BEGIN {
  $Array::Find::VERSION = '0.01';
}
# ABSTRACT: Find items in array, with several options

use 5.010;
use strict;
use warnings;

use List::Util qw(shuffle);

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(find_in_array);

our %SUBS;

$SUBS{find_in_array} = {
    summary       => 'Find items in array, with several options',
    description   => <<'_',

find_in_array looks for one or more items in one or more arrays and return an
array containing all or some results (empty arrayref if no results found). You
can specify several options, like maximum number of results, maximum number of
comparisons, searching by suffix/prefix, case sensitivity, etc. Consult the list
of arguments for more details.

Currently, items are compared using the Perl's eq operator, meaning they only
work with scalars and compare things asciibetically.

_
    args          => {
        item             => ['str' => {
            summary      => 'Item to find',
            description  => <<'_',

Currently can only be scalar. See also 'items' if you want to find several items
at once.

_
            arg_pos      => 0,
        }],
        array            => ['array' => {
            summary      => 'Array to find items in',
            description  => <<'_',

See also 'arrays' if you want to find in several arrays. Array elements can be
undef and will only match undef.

_
            arg_pos      => 1,
        }],
        items            => ['array' => {
            of           => 'str',
            summary      => "Just like 'item', except several",
            description  => <<'_',

Use this to find several items at once. Elements can be undef if you want to
search for undef.

Example: find_in_array(items => ["a", "b"], array => ["b", "a", "c", "a"]) will
return result ["b", "a", "a"].

_
        }],
        arrays            => ['array' => {
            of           => 'array', # XXX ['array*'=>{of=>'str'}]
            summary      => "Just like 'array', except several",
            description  => <<'_',

Use this to find several items at once.

Example: find_in_array(items => ["a", "b"], array => ["b", "a", "c", "a"]) will
return result ["b", "a", "a"].

_
        }],
        max_result       => ['int' => {
            summary      => "Set maximum number of results",
            description  => <<'_',

0 means unlimited (find in all elements of all arrays).

+N means find until results have N items. Example: find_in_array(item=>'a',
array=>['a', 'b', 'a', 'a'], max_result=>2) will return result ['a', 'a'].

-N is useful when looking for multiple items (see 'items' argument). It means
 find until N items to look for have been found. Example:
 find_in_array(items=>['a','b'], array=>['a', 'a', 'b', 'b'], max_results=>-2)
 will return result ['a', 'a', 'b']. As soon as 2 items to look for have been
 found it will stop.

_
        }],
        max_compare      => ['int' => {
            summary      => "Set maximum number of comparison",
            description  => <<'_',

Maximum number of elements in array(s) to look for, 0 means unlimited. Finding
will stop as soon as this limit is reached, regardless of max_result. Example:
find(item=>'a', array=>['q', 'w', 'e', 'a'], max_compare=>3) will not return
result.

_
        }],
        ci               => ['bool' => {
            default      => 0,
            summary      => "Set case insensitive",
        }],
        mode             => ['str' => {
            in           => ['exact', 'prefix', 'suffix', 'prefix|suffix',
                             'infix', 'regex'],
            default      => 'exact',
            summary      => "Comparison mode",
            description  => <<'_',

Exact match is the default, will only match 'ap' with 'ap'. Prefix matching will
also match 'ap' with 'ap', 'apple', and 'apricot'. Suffix matching will match
'le' with 'le' and 'apple'. Infix will only match 'ap' with 'claps' and not with
'ap', 'clap', or 'apple'. Regex will regard item as a regex and perform a regex
match on each element of array.

See also 'word_sep' which affects prefix/prefix/infix matching.
_
        }],
        word_sep         => ['str' => {
            summary      => "Define word separator",
            arg_aliases  => {
                ws => {},
            },
            description  => <<'_',

If set, item and array element will be regarded as a separated words. This will
affect prefix/suffix/infix matching. Example, with '.' as the word separator
and 'a.b' as the item, prefix matching will 'a.b', 'a.b.', and 'a.b.c'
(but not 'a.bc'). Suffix matching will match 'a.b', '.a.b', 'c.a.b' (but
not 'ca.b'). Infix matching will match 'c.a.b.c' and won't match 'a.b',
'a.b.c', or 'c.a.b'.

_
        }],
        shuffle          => ['bool' => {
            summary      => "Shuffle result",
        }],


    },
};
sub find_in_array {
    my %args = @_;

    # XXX schema
    my @items;
    push @items ,   $args{item}    if exists $args{item};
    push @items , @{$args{items}}  if exists $args{items};

    my @arrays;
    push @arrays,   $args{array}   if exists $args{array};
    push @arrays, @{$args{arrays}} if exists $args{arrays};

    my $ci          = $args{ci};
    my $mode        = $args{mode} // 'exact';
    my $ws          = $args{word_sep} // $args{ws};
    $ws             = undef if defined($ws) && $ws eq '';
    $ws             = lc($ws) if defined($ws) && $ci;
    my $ws_len      = defined($ws) ? length($ws) : undef;

    my $max_result  = $args{max_result};
    my $max_compare = $args{max_compare};

    my $num_compare;
    my %found_items; # for tracking which items have been found, for -max_result
    my @matched_els; # to avoid matching the same array element with multi items
    my @res;

  FIND:
    for my $i (0..$#items) {
        my $item = $ci ? lc($items[$i]) : $items[$i];
        if ($mode eq 'regex') {
            $item = qr/$item/ if ref($item) ne 'Regexp';
            $item = $ci ? qr/$item/i : $item; # XXX turn off i if !$ci
        }
        my $item_len = defined($item) ? length($item) : undef;

        for my $ia (0..$#arrays) {
            my $array = $arrays[$ia];
            for my $iel (0..@$array-1) {

                next if $matched_els[$ia] && $matched_els[$ia][$iel];
                $num_compare++;
                my $el0 = $array->[$iel];
                my $el = $ci ? lc($el0) : $el0;
                my $match;

                if (!defined($el)) {
                    $match = !defined($item);
                } elsif (!defined($item)) {
                    $match = !defined($el);
                } elsif ($mode eq 'exact') {
                    $match = $item eq $el;
                } elsif ($mode eq 'regex') {
                    $match = $el =~ $item;
                } else {
                    my $el_len = length($el);

                    if ($mode eq 'prefix' || $mode eq "prefix|suffix") {
                        my $idx = index($el, $item);
                        if (defined($ws)) {
                            $match ||=
                                # left side matches ^
                                $idx == 0 &&
                                # right side matches $ or
                                ($item_len+$idx == $el_len ||
                                # ws
                                 index($el, $ws, $item_len+$idx) ==
                                     $item_len+$idx);
                        } else {
                            $match ||= $idx == 0;
                        }
                    }

                    if ($mode eq 'suffix' || $mode eq "prefix|suffix"
                            && !$match) {
                        my $idx = rindex($el, $item);
                        if (defined($ws)) {
                            $match ||=
                                # right side matches $
                                $idx == $el_len-$item_len &&
                                # left-side matches ^ or
                                ($idx == 0 ||
                                # ws
                                 $idx >= $ws_len &&
                                     index($el, $ws, $idx-$ws_len) ==
                                         $idx-$ws_len);
                        } else {
                            $match ||= $idx == $el_len-$item_len;
                        }
                    }

                    if ($mode eq 'infix' && !$match) {
                        my $idx = index($el, $item);
                        if (defined($ws)) {
                            $match ||=
                                # right side matches ws
                                index($el, $ws, $item_len+$idx) ==
                                    $item_len+$idx &&
                                # left-side matches ws
                                 $idx >= $ws_len &&
                                     index($el, $ws, $idx-$ws_len) ==
                                         $idx-$ws_len;
                        } else {
                            $match ||= ($idx > 0 && $idx < $el_len-$item_len);
                        }
                    }
                }

                if ($match) {
                    push @res, $el0;
                    $matched_els[$ia] //= [];
                    $matched_els[$ia][$iel] = 1;
                }
                if (defined($max_compare) && $max_compare != 0) {
                    last FIND if $num_compare >= $max_compare;
                }
                if ($match) {
                    if (defined($max_result) && $max_result != 0) {
                        if ($max_result > 0) {
                            last FIND if @res >= $max_result;
                        } else {
                            $found_items{$i} //= 1;
                            last FIND if
                                scalar(keys %found_items) >= -$max_result;
                        }
                    }
                }

            }
        }
    }

    if ($args{shuffle}) {
        @res = shuffle(@res);
    }

    [200, "OK", \@res];
}

1;


=pod

=head1 NAME

Array::Find - Find items in array, with several options

=head1 VERSION

version 0.01

=head1 SYNOPSIS

 use Array::Find qw(find_in_array);
 use Data::Dump;

 # returns [STATUSCODE, ERRMSG, DATA]
 my $res = find_in_array(
     items      => [qw/a x/],
     array      => [qw/a b d a y x/],
     max_result => 2,
 );
 die $res->[1] if $res->[1] != 200;
 dd $res->[2]; # ['a', 'a']

 # find by prefix (or suffix, with/without word separator), in multiple arrays
 dd find_in_array(
     item       => 'a.b',
     mode       => 'prefix',
     word_sep   => '.',
     arrays     => [
         [qw/a a.b. a.b a.bb/],
         [qw/a.b.c b.c.d/],
     ],
 )->[2]; # ['a.b.', 'a.b', 'a.b.c']

=head1 DESCRIPTION

This module provides one subroutine: C<find_in_array> to find items in array.

This module's subroutines follow L<Sub::Spec> convention, which explains the
rather weird [STATUSCODE, ERRMSG, DATA] return value. Sub::Spec allows your
subroutines to be straightforwardly accessed via HTTP REST API and command-line
(complete with options parsing, help message, and bash completion), as well as
other features.

=head1 FUNCTIONS

None of the functions are exported by default, but they are exportable.

=head2 find_in_array(%args) -> [STATUSCODE, ERRMSG, RESULT]


Find items in array, with several options.

find_in_array looks for one or more items in one or more arrays and return an
array containing all or some results (empty arrayref if no results found). You
can specify several options, like maximum number of results, maximum number of
comparisons, searching by suffix/prefix, case sensitivity, etc. Consult the list
of arguments for more details.

Currently, items are compared using the Perl's eq operator, meaning they only
work with scalars and compare things asciibetically.

Returns a 3-element arrayref. STATUSCODE is 200 on success, or an error code
between 3xx-5xx (just like in HTTP). ERRMSG is a string containing error
message, RESULT is the actual result.

Arguments (C<*> denotes required arguments):

=over 4

=item * B<item> => I<str>

Item to find.

Currently can only be scalar. See also 'items' if you want to find several items
at once.

=item * B<array> => I<array>

Array to find items in.

See also 'arrays' if you want to find in several arrays. Array elements can be
undef and will only match undef.

=item * B<arrays> => I<array>

Just like 'array', except several.

Use this to find several items at once.

Example: find_in_array(items => ["a", "b"], array => ["b", "a", "c", "a"]) will
return result ["b", "a", "a"].

=item * B<ci> => I<bool> (default C<0>)

Set case insensitive.

=item * B<items> => I<array>

Just like 'item', except several.

Use this to find several items at once. Elements can be undef if you want to
search for undef.

Example: find_in_array(items => ["a", "b"], array => ["b", "a", "c", "a"]) will
return result ["b", "a", "a"].

=item * B<max_compare> => I<int>

Set maximum number of comparison.

Maximum number of elements in array(s) to look for, 0 means unlimited. Finding
will stop as soon as this limit is reached, regardless of max_result. Example:
find(item=>'a', array=>['q', 'w', 'e', 'a'], max_compare=>3) will not return
result.

=item * B<max_result> => I<int>

Set maximum number of results.

0 means unlimited (find in all elements of all arrays).

+N means find until results have N items. Example: find_in_array(item=>'a',
array=>['a', 'b', 'a', 'a'], max_result=>2) will return result ['a', 'a'].

-N is useful when looking for multiple items (see 'items' argument). It means
 find until N items to look for have been found. Example:
 find_in_array(items=>['a','b'], array=>['a', 'a', 'b', 'b'], max_results=>-2)
 will return result ['a', 'a', 'b']. As soon as 2 items to look for have been
 found it will stop.

=item * B<mode> => I<str> (default C<"exact">)

Value must be one of:

 ["exact", "prefix", "suffix", "prefix|suffix", "infix", "regex"]


Comparison mode.

Exact match is the default, will only match 'ap' with 'ap'. Prefix matching will
also match 'ap' with 'ap', 'apple', and 'apricot'. Suffix matching will match
'le' with 'le' and 'apple'. Infix will only match 'ap' with 'claps' and not with
'ap', 'clap', or 'apple'. Regex will regard item as a regex and perform a regex
match on each element of array.

See also 'word_sep' which affects prefix/prefix/infix matching.

=item * B<shuffle> => I<bool>

Shuffle result.

=item * B<word_sep> => I<str>

Aliases: B<ws>

Define word separator.

If set, item and array element will be regarded as a separated words. This will
affect prefix/suffix/infix matching. Example, with '.' as the word separator
and 'a.b' as the item, prefix matching will 'a.b', 'a.b.', and 'a.b.c'
(but not 'a.bc'). Suffix matching will match 'a.b', '.a.b', 'c.a.b' (but
not 'ca.b'). Infix matching will match 'c.a.b.c' and won't match 'a.b',
'a.b.c', or 'c.a.b'.

=back

=head1 SEE ALSO

L<List::Util>, L<List::MoreUtils>

L<Sub::Spec>

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__


