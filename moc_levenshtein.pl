use strict;
use warnings;


sub min_of_n {
  my($min) = $_[0];

  my($current);
  foreach $current (@_) {
    $min = $current if ($current < $min);
  }

  return ($min);
}

sub croak {
  my($error_string) = @_;

  print "ERROR in Levenshtein: $error_string.\n";
}


# Stolen from Text:Levenshtein and modified.
# The perl Text module isn't necessarily installed on all web servers
# and the code is simple enough that it seems easier just to duplicate it

sub distance
{
    my $opt = pop(@_) if @_ > 0 && ref($_[-1]) eq 'HASH';
    croak "distance() takes 2 or more arguments" if @_ < 2;
    my ($s,@t)=@_;
    my @results;

    $opt = {} if not defined $opt;

	foreach my $t (@t) {
		push(@results, fastdistance($s, $t, $opt));
	}

	return wantarray ? @results : $results[0];
}

# This is the "Iterative with two matrix rows" version
# from the wikipedia page
# http://en.wikipedia.org/wiki/Levenshtein_distance#Computing_Levenshtein_distance
sub fastdistance
{
    my $opt = pop(@_) if @_ > 0 && ref($_[-1]) eq 'HASH';
    croak "fastdistance() takes 2 or 3 arguments" unless @_ == 2;
    my ($s, $t) = @_;
    my (@v0, @v1);
    my ($i, $j);

    $opt = {} if not defined $opt;

    return 0 if $s eq $t;
    return length($s) if !$t || length($t) == 0;
    return length($t) if !$s || length($s) == 0;

    my $s_length = length($s);
    my $t_length = length($t);

    for ($i = 0; $i < $t_length + 1; $i++) {
        $v0[$i] = $i;
    }

    for ($i = 0; $i < $s_length; $i++) {
        $v1[0] = $i + 1;

        for ($j = 0; $j < $t_length; $j++) {
            # my $cost = substr($s, $i, 1) eq substr($t, $j, 1) ? 0 : 1;
            my $cost = (substr($s, $i, 1) eq substr($t, $j, 1)) ? 0 : 1;
            $v1[$j + 1] = min_of_n(
                              $v1[$j] + 1,
                              $v0[$j + 1] + 1,
                              $v0[$j] + $cost,
                             );
        }

        for ($j = 0; $j < $t_length + 1; $j++) {
            $v0[$j] = $v1[$j];
        }
    }

    return $v1[ $t_length];
}

1;
