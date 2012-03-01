package Perlresume::Kwalitee;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = bless {@_}, $class;

    return $self;
}

sub fetch_author {
    my $self = shift;
    my ($pauseid) = @_;

    my $dbh = $self->{dbh};

    my $sth = $dbh->prepare(<<'');
SELECT
    average_kwalitee,
    rank,
    average_total_kwalitee,
    num_dists
FROM `author`
WHERE `pauseid` = ?

    $sth->execute($pauseid);

    my $result = $sth->fetchall_arrayref;

    return {} unless $result && @$result;

    return {
        kwalitee_average  => $result->[0]->[0],
        kwalitee_rank     => $result->[0]->[1],
        kwalitee_liga => $result->[0]->[3] > 5
        ? 'more than 5 dists liga'
        : 'less than 5 dists liga'
    };
}

1;
