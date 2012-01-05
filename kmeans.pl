#!env perl
use strict;
use Data::Dumper;

my $sample_file = $ARGV[1];
my @centroids;
my @samples_to_centroids;
my @samples;
my $num_centroids = $ARGV[0];
my $num_changed = 0;
my $iter_counter = 0;
my $max_iter = 10;
my $dimensions = 0;

read_samples($sample_file, \@samples);
$dimensions = scalar @{$samples[0]};

die "cannot have more centroids than samples!\n"
    if $num_centroids > scalar @samples;


assign_centroids_random_points(\@centroids, \@samples, $num_centroids);

$samples_to_centroids[scalar @samples - 1] = 0;
@samples_to_centroids = map{0} @samples_to_centroids;

do {
    $num_changed = assign_samples_to_centroids(\@centroids,
                                               \@samples,
                                               \@samples_to_centroids);

    average_cenroids(\@centroids,
                     \@samples,
                     \@samples_to_centroids);

    print "changed = $num_changed\n";

} while($num_changed > 0 && $iter_counter++ < $max_iter) ;

print "centroids:\n", Dumper(\@centroids);
print "assignments:\n", Dumper(\@samples_to_centroids);

sub read_samples {
    my ($f, $s) = @_;
    open(F, $f) || die "cannot open file '$f'\n";
    while(<F>){
        push @$s, [ split(/\s+/, $_) ];
    }
    close F;
}

sub isin {
    my ($array, $v) = @_;
    my $howmany = scalar grep {$_ == $v} @$array;
    return $howmany > 0;
}

sub assign_centroids_random_points
{
    my ($centroids, $samples, $num) = @_;
    my $samples_n = scalar @$samples;

    my @randoms;
    my $n = $num;
    while($n > 0){
         my $r = int( rand() * $samples_n );
         if (!isin(\@randoms, $r))
         {
             push @randoms, $r;
             $n--;
         }
    }

    foreach my $n (0 .. $num - 1)
    {
        my $pos = $randoms[$n];
        push @$centroids, [map {@$_} $samples[$pos]];
    }
}

sub assign_samples_to_centroids {
    my ($c, $s, $s2c) = @_;
    my $numChanged = 0;

    for my $current_sample (0 .. scalar @{$s} - 1 ) {
        my $d = 1e31;
        my $chosen_centroid = 0;
        foreach my $centroid_n (0 .. scalar @{$c} - 1) {
            my $centroid_distance = vector_distance($c->[$centroid_n], $s->[$current_sample]);
            if ($centroid_distance < $d){
                $d = $centroid_distance;
                $chosen_centroid = $centroid_n;
            }
        }
        my $prev = $s2c->[$current_sample];
        $s2c->[$current_sample] = $chosen_centroid;
        $numChanged ++ if $prev != $chosen_centroid;
    }
    return $numChanged;
}

sub vector_distance {
    my ($a, $b) = @_;
    my $counter = scalar @$a - 1;
    my $val = 0.0;
    while ($counter-- >= 0){
        $val += ($a->[$counter] - $b->[$counter]) ** 2;
    }
    return $val ** .5;
}

sub add_to_first_vector {
    my ($save_to, $read_from) = @_;
    my $counter = scalar @{$save_to} - 1;
    while ($counter-- >= 0){
        $save_to->[$counter] += $read_from->[$counter];
    }
}

sub average_cenroids {
    my ($c, $s, $s2c) = @_;

    my %assignments;

    # clear each centroid 'sample'
    foreach my $centroid (@{$c})
    {
        foreach my $c_val (@{$centroid})
        {
            $c_val = 0;
        }
    }

    foreach my $current_sample_n (0 .. scalar @{$s} - 1 ) {
        $assignments{$s2c->[$current_sample_n]} ++;
        my $centroid_n = $s2c->[$current_sample_n];

        add_to_first_vector($c->[$centroid_n], $s->[$current_sample_n]);
    }

    foreach my $current_sample_n (0 .. scalar @{$s} - 1 ) {
        my $centroid_n = $s2c->[$current_sample_n];
        foreach my $v (@{$c->[$centroid_n]})
        {
            $v /= $assignments{$centroid_n};
        }
    }

}

