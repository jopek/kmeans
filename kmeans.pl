#!env perl
use strict;
use Data::Dumper;

# plot usign gnuplot:
# gnuplot -e 'plot "< grep '^S' random_points_clustered_1k" using 2:3:4 lc variable, "< grep '^C' random_points_clustered_1k" using 3:4:2 with labels'

my $config = {
    output_file => $ARGV[2],
    output_file_suffix => ".out",
    sample_file => $ARGV[1],
    num_centroids => $ARGV[0],
    max_iter => 50,
    print_each_subresult => 1,
    use_iteration_for_outfilename => 1,
};

my $result = cluster_samplesfile($config);
print_results($result, $config);



# ======================================


sub print_results {
    my $res = shift;
    my $cfg = shift;
    my $fn ;

    $cfg->{output_filehandle} = \*STDOUT;

    if (defined $cfg->{output_file}) {
        $fn = $cfg->{output_file};
        if (defined $cfg->{use_iteration_for_outfilename}
            && $cfg->{use_iteration_for_outfilename} != 0){
            $fn .= sprintf "%03d", ${$res->{iterations}};
        }

        if (defined $cfg->{output_file_suffix}
            && $cfg->{output_file_suffix} ne "" )
        {
            $fn .= $cfg->{output_file_suffix};
        }

        open ($cfg->{output_filehandle}, ">", $fn) ||
            die "cannot open $fn: $?\n";
    }

    print_results_assignments($res, $cfg);
    print_results_initialcentroids($res, $cfg);
    print_results_centroids($res, $cfg);

    if (defined $cfg->{output_file}) {
        close $cfg->{output_filehandle};
    }

}

sub print_results_initialcentroids {
    my $results = shift;
    my $cfg = shift;
    my $fh = $cfg->{output_filehandle};
    my $n;

    $n=0;
    foreach my $centroid (@{$results->{initial_centroids} }) {
        print $fh "IC $n @{$centroid} \n";
        $n++;
    }

}

sub print_results_assignments {
    my $results = shift;
    my $cfg = shift;
    my $fh = $cfg->{output_filehandle};
    my $n;

    $n=0;
    foreach my $smpl (@{$results->{samples}} ) {
        print $fh "S @{$smpl} " . $results->{assignments}[$n] . "\n";
        $n++;
    }

}

sub print_results_centroids {
    my $results = shift;
    my $cfg = shift;
    my $fh = $cfg->{output_filehandle};
    my $n;

    $n=0;
    foreach my $centroid (@{$results->{centroids} }) {
        my $stddev = 0;
        foreach my $sample (@{ $results->{samples} } ) {
            $stddev += vector_distance($centroid, $sample);
        }

        #push @{ $results->{stddevs} }, $stddev;

        # not really stddev, but something similar
        $stddev /= scalar @{ $results->{samples} };
        print $fh "C $n @{$centroid} $stddev\n";
        $n++;
    }

}

sub cluster_samplesfile {
    my $cfg = shift;

    my $samples = [];
    read_samples($cfg->{sample_file}, $samples);

    die "cannot have more centroids than samples!\n"
        if $cfg->{num_centroids} > scalar @$samples;
    return cluster_samples($cfg, $samples);
}

sub cluster_samples {
    my ($cfg, $samples) = @_ ;

    my $centroids = [];
    my $samples_to_centroids = [];
    my $num_changed = 0;
    my $num_centroids = $cfg->{num_centroids};
    my $iter_counter => 0,
    my $initial_centroids = [];
    my $results = {};

    assign_centroids_random_points($centroids, $samples, $num_centroids);

    # deep copy
    foreach(@$centroids){
        push @$initial_centroids, [map {@$_} $_];
    }

    $samples_to_centroids->[scalar @{$samples} - 1] = 0;
    @$samples_to_centroids = map{0} @$samples_to_centroids;

    # references... can return any time!
    $results = {
        centroids => $centroids,
        assignments => $samples_to_centroids,
        initial_centroids => $initial_centroids,
        samples => $samples,
        iterations => \$iter_counter
    };

    while(1) {
        $iter_counter++;

        print STDERR "iteration $iter_counter : ";
        $num_changed = assign_samples_to_centroids($centroids,
                                                   $samples,
                                                   $samples_to_centroids);

        print STDERR "$num_changed changed\n";
        last if ($num_changed == 0 || $iter_counter == $cfg->{max_iter} );
        $cfg->{print_each_subresult} && print_results($results, $cfg);

        average_cenroids($centroids,
                         $samples,
                         $samples_to_centroids);
    }

    return $results ;

}

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
    while($n > 0) {
        my $r = int( rand() * $samples_n );
        if (!isin(\@randoms, $r)) {
            push @randoms, $r;
            $n--;
        }
    }

    foreach my $n (0 .. $num - 1) {
        my $pos = $randoms[$n];
        push @$centroids, [map {@$_} $samples->[$pos]];
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
    while ($counter-- >= 0) {
        $val += ($a->[$counter] - $b->[$counter]) ** 2;
    }
    return $val ** .5;
}

sub add_to_first_vector {
    my ($save_to, $read_from) = @_;
    my $counter = scalar @{$save_to} - 1;
    while ($counter-- >= 0) {
        $save_to->[$counter] += $read_from->[$counter];
    }
}

sub average_cenroids {
    my ($c, $s, $s2c) = @_;

    my %assignment_counter;

# clear each centroid 'sample'
    foreach my $centroid (@{$c}) {
        foreach my $c_val (@{$centroid}) {
            $c_val = 0;
        }
    }

    foreach my $current_sample_n (0 .. scalar @{$s} - 1 ) {
        $assignment_counter{$s2c->[$current_sample_n]} ++;
        my $centroid_n = $s2c->[$current_sample_n];

        add_to_first_vector($c->[$centroid_n], $s->[$current_sample_n]);
    }

    foreach my $centroid_n (sort keys %assignment_counter ) {
        foreach my $v (@{$c->[$centroid_n]}) {
            $v /= $assignment_counter{$centroid_n};
        }
    }

}


