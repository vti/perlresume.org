package Perlresume;
use Dancer ':syntax';
use MetaCPAN::API;
use Try::Tiny;
use Time::Piece;
use LWP::UserAgent;
use JSON ();

our $VERSION = '0.1';

my $METACPAN = 'http://api.metacpan.org/v0';

get '/' => sub {
    if (my $author = params->{author}) {
        redirect '/' . $author;
    }

    template 'index';
};

get '/:author' => sub {
    my $id = uc params->{author};

    my $author = fetch_author($id);

    if (!$author) {
        status 'not_found';
        return template 'not_found';
    }

    $author->{dist_count} = fetch_dist_count($id);

    $author->{email} = $author->{email}->[0] if defined $author->{email};
    $author->{website} = $author->{website}->[0] if defined $author->{website};

    $author->{contacts} = [];
    foreach my $profile (@{$author->{profile}}) {
        push @{$author->{contacts}},
          { $profile->{name} => 1,
            id               => $profile->{id}
          };
    }

    $author->{profiles} = 1 if @{$author->{contacts}};

    $author->{first_release_year} = fetch_first_release_year($id);
    $author->{favorited_dist_count} = fetch_favorited_dist_count($id);

    $author->{dists_users_count} = fetch_dists_users_count($id);

    template 'resume' => {
        %$author,
        title => $author->{asciiname} ? $author->{asciiname} : $author->{name}
    };
};

true;

sub fetch_author {
    my ($id) = @_;

    my $mcpan  = MetaCPAN::API->new;

    return try { $mcpan->author($id) };
}

sub fetch_dist_count {
    my ($id) = @_;

    my $mcpan = MetaCPAN::API->new;

    my $result = $mcpan->fetch(
        'release/_search',
        q    => "author:$id AND status:latest",
        size => 0
    );

    return $result->{hits}->{total};
}

sub fetch_favorited_dist_count {
    my ($id) = @_;

    my $mcpan = MetaCPAN::API->new;

    my $result = $mcpan->fetch(
        'favorite/_search',
        q    => "author:$id",
        size => 0
    );

    return $result->{hits}->{total};
}

sub fetch_first_release_year {
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

    $date = Time::Piece->strptime($date, '%Y-%m-%dT%H:%M:%S');

    return $date->year;
}

sub fetch_dists_users_count {
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
                size => 999,
                from => 0,
                sort => [{date => 'desc'}],
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
                                  {"release.dependency.module" => \@modules}
                            }
                        ]
                    }
                }
            },
            size => 0,
            from => 0,
            #sort => [{date => 'desc'}],
        }
    );

    die $response->status_line unless $response->is_success;

    $res = JSON::decode_json($response->decoded_content);

    return $res->{hits}->{total};
}
