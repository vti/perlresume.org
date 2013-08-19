use Term::ReadKey;
use YAML ();
use Rex -feature => '0.42';

my $config = YAML::LoadFile('Rexfile.yml');

user $config->{user};
port $config->{port};

chomp(my $ls_files = <<'EOF');
    SM=`git submodule foreach pwd |           \
        grep 'Entering' |                     \
        sed "s/\(Entering '\|'$\)//g" |       \
        while read dir; do                    \
            cd $dir > /dev/null;              \
            git ls-files | sed "s?^?$dir\/?"; \
            cd - > /dev/null;                 \
        done`                                 \
    LS=`git ls-files`;                        \
    echo $SM $LS
EOF

sub _get_last_commit {
    my $last_commit = run 'git log | head -1';
    my ($sha1) = $last_commit =~ m/commit (.{5})/;
    return $sha1;
}

set connection => 'OpenSSH';

task 'upload' => sub {
    my $archive;
    LOCAL {
        my $sha1 = _get_last_commit();

        my $prefix = "$config->{app}-$sha1";
        $archive = "$prefix.tar.gz";

        my @files = run "$ls_files";
        run "tar --transform 's,^,$prefix/,' -czf $archive @files";
    };

    my $base = "$config->{base}/www";

    upload $archive, "$base/";

    run "tar xzf $base/$archive -C $base/";
    die 'tar failed' if $?;

    run "rm $base/$archive";
};

task 'switch' => sub {
    my $base = $config->{base};

    my $sha1 = _get_last_commit();

    my $latest_release = "$config->{app}-$sha1";

    rm "$base/www/$config->{app}";
    ln "$base/www/$latest_release", "$base/www/$config->{app}";
};

task 'uwsgi' => sub {
    file "$config->{base}/uwsgi/$config->{app}.uwsgi.ini",
      content => template(
        'etc/uwsgi/uwsgi.ini.tpl',
        base         => $config->{base},
        uwsgi_listen => $config->{uwsgi_listen}
      );
};

task 'supervisor' => sub {
    #sudo_password read_password();
    #sudo sub {
    #sub {
        file "/etc/supervisor/conf.d/$config->{app}.conf",
          content => template(
            "etc/supervisor/$config->{app}.conf.tpl",
            user => $config->{user},
            base => $config->{base}
          );

        run 'supervisorctl reread';
        #};
};

task 'start' => sub {
    sudo_password read_password();
    sudo sub { run "supervisorctl start $config->{app}" };
};

task 'restart' => sub {
    sudo_password read_password();
    sudo sub { run "supervisorctl restart $config->{app}" };
};

task 'setup' => sub {
    transaction {
        do_task [qw/upload uwsgi supervisor switch/];
    };
};

sub read_password {
    print "Password please: ";
    ReadMode "noecho";    # don't echo anything
    my $password = <STDIN>;
    chomp $password;
    ReadMode 0;           # reset terminal so it echo again
    return $password;
}
