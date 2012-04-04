package Perlresume::MetaCPAN;

use strict;
use warnings;

my $METACPAN = 'http://api.metacpan.org/v0';

use Try::Tiny;
use LWP::UserAgent;
use JSON ();
use MetaCPAN::API;
use Time::Piece;

sub new {
    my $class = shift;

    my $self = {@_};
    bless $self, $class;

    return $self;
}

sub fetch_author {
    my $self = shift;
    my ($id) = @_;

    my $mcpan = MetaCPAN::API->new;

    my $author = try { $mcpan->author($id) };
    return unless $author;

    $author->{dist_count}           = $self->fetch_dist_count($id);
    $author->{first_release_year}   = $self->fetch_first_release_year($id);
    $author->{favorited_dist_count} = $self->fetch_favorited_dist_count($id);
    ($author->{dists_users_count}, $author->{dists_users}) =
      $self->fetch_dists_users_count($id);

    $author->{email} = $author->{email}->[0]
      if defined $author->{email};
    $author->{website} = $author->{website}->[0]
      if defined $author->{website};

    $author->{contacts} = [];
    foreach my $profile (@{$author->{profile}}) {
        push @{$author->{contacts}},
          { $profile->{name} => 1,
            id               => $profile->{id}
          };

        if ($profile->{name} eq 'github') {
            $author->{has_github_account} = {id => $profile->{id}};
        }
    }

    $author->{profiles} = 1 if @{$author->{contacts}};

    if (my $latest_release = $self->fetch_latest_release($id)) {
        $author->{latest_release} = $latest_release;
    }

    return $author;
}

sub fetch_dist_count {
    my $self = shift;
    my ($id) = @_;

    my $mcpan = MetaCPAN::API->new;

    my $result = $mcpan->fetch(
        'release/_search',
        q    => "author:$id AND status:latest",
        size => 0
    );

    return $result->{hits}->{total};
}

sub fetch_first_release_year {
    my $self = shift;
    my ($id) = @_;

    my $mcpan = MetaCPAN::API->new;

    my $result = $mcpan->fetch(
        'release/_search',
        q    => "author:$id",
        sort => 'date',
        size => 1
    );

    my $date = $result->{hits}->{hits}->[0]->{_source}->{date};
    return 0 unless defined $date;

    $date = try { Time::Piece->strptime($date, '%Y-%m-%dT%H:%M:%S') };
    return 0 unless defined $date;

    return $date->year;
}

sub fetch_favorited_dist_count {
    my $self = shift;
    my ($id) = @_;

    my $mcpan = MetaCPAN::API->new;

    my $result = $mcpan->fetch(
        'favorite/_search',
        q    => "author:$id",
        size => 0
    );

    return $result->{hits}->{total};
}

sub fetch_dists_users_count {
    my $self = shift;
    my ($id) = @_;

    my $ua = LWP::UserAgent->new;

    my $response = $ua->post(
        "$METACPAN/release/_search",
        Content => JSON::encode_json(
            {   query => {
                    filtered => {
                        query  => {"match_all" => {}},
                        filter => {
                            and => [
                                {term => {'release.status'     => 'latest'}},
                                {term => {'release.authorized' => \1}},
                                {term => {"release.author"     => $id}}
                            ]
                        }
                    }
                },
                fields => ['distribution'],
                size   => 999,
                from   => 0,
                sort   => [{date => 'desc'}],
            }
        )
    );
    die $response->status_line unless $response->is_success;

    my $res = JSON::decode_json($response->decoded_content);

    my @modules;
    foreach my $module (@{$res->{hits}{hits}}) {
        my $name = $module->{fields}{distribution};
        $name =~ s/-/::/g;
        push @modules, $name;
    }

    return 0 unless @modules;

    $response = $ua->post(
        "$METACPAN/release/_search",
        Content => JSON::encode_json {
            query => {
                filtered => {
                    query  => {"match_all" => {}},
                    filter => {
                        and => [
                            {term => {'release.status'     => 'latest'}},
                            {term => {'release.authorized' => \1}},
                            {   terms =>
                                  {'release.dependency.module' => \@modules}
                            },
                            {   not => {
                                    filter => {
                                        and => [
                                            {   term =>
                                                  {'release.author' => $id}
                                            }
                                        ]
                                    }
                                }
                            }
                        ],
                    }
                }
            },
            size => 999
        }
    );

    die $response->status_line unless $response->is_success;

    $res = JSON::decode_json($response->decoded_content);

    my @distributions =
      map { $_->{_source}->{distribution} } @{$res->{hits}->{hits}};

    if (@distributions > 50) {
        @distributions = splice @distributions, 0, 49;
        push @distributions, '...';
    }

    return ($res->{hits}->{total}, join "  ", @distributions);
}

sub fetch_latest_release {
    my $self = shift;
    my ($id) = @_;

    my $mcpan = MetaCPAN::API->new;

    my $result = $mcpan->fetch(
        'release/_search',
        q      => "author:$id",
        filter => 'status:latest',
        fields => 'distribution,name,date',
        sort   => 'date:desc',
        size   => 1
    );

    my $fields = $result->{hits}->{hits}->[0]->{fields};

    my $date = $fields->{date};
    return unless defined $date;

    $date =~ s/\..*$//;
    $date = try { Time::Piece->strptime($date, '%Y-%m-%dT%H:%M:%S') };
    return unless defined $date;
    $date = $date->strftime('%d %b %Y');

    return {
        distribution => $fields->{distribution},
        name         => $fields->{name},
        date         => $date
    };
}

1;
