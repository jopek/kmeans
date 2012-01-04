#!env perl
use strict;


my $sample_file = $ARGV[0];
my @centroids;
my @samples_to_centroids;
my @samples;
my $num_changed = 0;
my $iter_counter = 0;
my $max_iter = 10;
my $dimensions = 0;

read_samples($sample_file, \@samples);
$dimensions = scalar $samples[0];

do {
    $num_changed = assign_samples_to_centroids(\@centroids,
                                               \@samples,
                                               \@samples_to_centroids);
    average_cenroids(\@centroids,
                     \@samples,
                     \@samples_to_centroids);

} while($num_changed > 0 && $iter_counter++ < $max_iter) ;

sub read_samples {
    my ($f, $s) = @_;
    open(F, $f) || die "cannot open file '$f'\n";
    while(<F>){
        push @$s, [ split(/\s+/, $_) ];
    }
    close F;
}

sub assign_samples_to_centroids {
    my ($c, $s, $s2c) = @_;
    my $numChanged = 0;

    $s2c = [];
    %assignmentCounter = ();

    for my $sample_n (0 .. scalar @{$s} - 1 ) {
        my $d = 1e31;
        my $chosen_centroid = 0;
        for my $centroid_n (0 .. scalar @{$c} - 1) {
            my $centroid_distance = vector_distance($c->[$centroid_n], $s->[$sample_n]);
            if ($centroid_distance < $d){
                $d = $centroid_distance;
                $chosen_centroid = $centroid_n;
            }
        }

        push @$s2c, $chosen_centroid;
    }
    return $numChanged;
}

sub vector_distance {
    my ($a, $b) = @_;
    my $counter = $#a;
    my $val = 0.0;
    while ($counter >= 0){
        $val += ($a->[$counter] + $b->[$counter]) ** 2;
    }
    return $val ** .5;
}

sub average_cenroids {

}

__DATA__

std::vector<id_type> assignmentCounter(centroids.size(), 0);

//find minimum using this pair
std::pair<id_type, float> minDist(1000, 1000.0);

// count the number of changed centroid assignments
id_type numChanged = 0;

// parallellizabe!
for(id_type sidx = 0; sidx < samples.size(); ++sidx)
{

    for(id_type cidx = 0; cidx < centroids.size(); ++cidx)
    {
        float dist = centroids[cidx].distanceTo(samples[sidx]);

        if ( dist < minDist.second ){
            minDist.first = cidx;
            minDist.second = dist;
        }
    }
    assignment_type prevAssignment = assignments[sidx];
    assignments[sidx] = minDist.first;
    if (prevAssignment != assignments[sidx])
        ++numChanged;

    // assigned centroid
    assignmentCounter[ assignments[sidx] ] ++;
}
log.i() << "  done in " << sw.seconds() << " seconds" << std::endl;

for (id_type cidx = 0; cidx < centroids.size(); ++cidx)
{
    if (assignmentCounter[cidx])
        log.i() << assignmentCounter[cidx]
            << " samples assigned to centroid " << cidx << std::endl;
}

return numChanged;

