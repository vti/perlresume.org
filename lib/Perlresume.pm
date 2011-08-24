package Perlresume;
use Dancer ':syntax';
use MetaCPAN::API;
use Try::Tiny;
use Time::Piece;

our $VERSION = '0.1';

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

    template 'resume' => $author;
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

    $date = Time::Piece->strptime($date, '%Y-%m-%dT%H:%M:%S');

    return $date->year;
}
