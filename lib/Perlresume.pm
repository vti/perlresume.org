package Perlresume;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Perlresume::MetaCPAN;
#use Perlresume::Kwalitee;

our $VERSION = '0.1';

my $mcpan = Perlresume::MetaCPAN->new;
#my $kwalitee = Perlresume::Kwalitee->new(dbh => database('cpants'));

set 'warnings' => 0;

hook 'database_connected' => sub {
    my $dbh = shift;
    $dbh->{sqlite_unicode} = 1;
};

get '/' => sub {
    if (my $author = params->{author}) {
        return redirect '/' . $author;
    }

    my $authors = load_last_searches();

    template 'index' => {authors => $authors};
};

get '/:author' => sub {
    my $id = uc params->{author};

    my $cpan_profile = $mcpan->fetch_author($id);

    if (!$cpan_profile) {
        status 'not_found';
        return template 'not_found';
    }

    my $author = find_or_create($cpan_profile);
    $author->{updated} = time;
    $author->{views}++;
    my $views = $author->{views};
    update_author($author);

    #my $kwalitee_profile = $kwalitee->fetch_author($id);

    template 'resume' => {
        title => $cpan_profile->{asciiname}
        ? $cpan_profile->{asciiname}
        : $cpan_profile->{name},
        %$cpan_profile,
        #%$kwalitee_profile,
        views => $author->{views}
    };
};

true;

sub find_or_create {
    my ($cpan_author) = @_;

    if (my $author =
        database('perlresume')->quick_select('resume', {pauseid => $cpan_author->{pauseid}}))
    {

        # TODO: remove me when everything is updated
        if (!$author->{asciiname}) {
            my $name =
                $cpan_author->{name}
              ? $cpan_author->{name}
              : $cpan_author->{asciiname};
            my $asciiname =
                $cpan_author->{asciiname}
              ? $cpan_author->{asciiname}
              : $cpan_author->{name};
            $author->{name}      = $name;
            $author->{asciiname} = $asciiname;

            database('perlresume')
              ->quick_update( 'resume', { pauseid => $author->{pauseid} },
                $author );
        }

        return $author;
    }

    my $name =
      $cpan_author->{name} ? $cpan_author->{name} : $cpan_author->{asciiname};
    my $asciiname =
        $cpan_author->{asciiname}
      ? $cpan_author->{asciiname}
      : $cpan_author->{name};

    database('perlresume')->quick_insert(
        'resume',
        {
            pauseid   => $cpan_author->{pauseid},
            asciiname => $asciiname,
            name      => $name,
            updated   => time
        }
    );

    return {pauseid => $cpan_author->{pauseid}, views => 0};
}

sub update_author {
    my ($author) = @_;

    database('perlresume')->quick_update('resume', {pauseid => $author->{pauseid}},
        $author);
}

sub load_last_searches {
    my $sth = database('perlresume')->prepare(
        'SELECT pauseid, name FROM resume ORDER BY updated DESC LIMIT 10',
    );
    $sth->execute;

    my $authors =
      [map { {pauseid => $_->[0], name => $_->[1]} }
          @{$sth->fetchall_arrayref}];

    return $authors;
}
