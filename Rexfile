use Term::ReadKey;
use YAML ();
use Rex -feature => '0.42';
use Rex::Transaction;

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

sub run_or_die {
    my $output = run @_;
    die "Command failed: $output" if $?;
}

set connection => 'OpenSSH';

task 'upload_archive' => sub {
    my $latest_release;
    my $archive;
    LOCAL {
        my $sha1 = get_last_commit();

        my $prefix = $latest_release = "app-$sha1";
        $archive = "$prefix.tar.gz";

        my @files = run "$ls_files";
        run_or_die "tar --transform 's,^,$prefix/,' -czf $archive @files";
    };

    my $base = "$config->{base}";
    mkdir $base;

    upload $archive, "$base/";

    run_or_die "tar xzf $base/$archive -C $base/";
    die 'tar failed' if $?;

    run "rm $base/$archive";

    # Prepare database & config
    mkdir "$config->{base}/db";
    file "$config->{base}/$latest_release/config.yml",
      content => template('etc/config.yml.tpl', base => "$config->{base}/db");
};

task 'installdeps' => sub {
    my $sha1           = get_last_commit();
    my $latest_release = "app-$sha1";

    run_or_die "cd $config->{base}/$latest_release; perl $config->{cpanm} --installdeps -L ../perl5 .";
};

task 'switch' => sub {
    my $base = $config->{base};

    my $sha1 = get_last_commit();

    my $latest_release = "app-$sha1";

    rm "$base/app-current";
    ln "$base/$latest_release", "$base/app-current";
};

task 'rollout' => sub {
    transaction {
        upload_archive();
        installdeps();
        switch();
        restart();
    };
};

task 'start' => sub {
    sudo_password read_password();
    sudo sub { run "supervisorctl start $config->{name}" };
};

task 'restart' => sub {
    sudo_password read_password();
    sudo sub { run "supervisorctl restart $config->{name}" };
};

task 'setup_uwsgi' => sub {
    mkdir "$config->{base}/uwsgi/";
    file "$config->{base}/uwsgi/uwsgi.ini",
      content => template(
        'etc/uwsgi.ini.tpl',
        base         => $config->{base},
        uwsgi_listen => $config->{uwsgi_listen}
      );
};

task 'setup_nginx' => sub {
    sudo_password read_password();
    sudo sub {
        file "/etc/nginx/sites-available/$config->{name}",
          content => template(
            'etc/nginx.tpl',
            server_name => $config->{name},
            access_log  => "$config->{base}/logs/access.log",
            error_log   => "$config->{base}/logs/error.log",
            root        => "$config->{base}/app-current/public",
            uwsgi_pass  => $config->{uwsgi_listen}
          );
        rm "/etc/nginx/sites-enabled/$config->{name}";
        ln "/etc/nginx/sites-available/$config->{name}",
          "/etc/nginx/sites-enabled/$config->{name}";
        mkdir "$config->{base}/logs/";
        run_or_die "/etc/init.d/nginx restart";
    };
};

task 'setup_supervisor' => sub {
    sudo_password read_password();
    sudo sub {
        file "/etc/supervisor/conf.d/$config->{name}.conf",
          content => template(
            "etc/supervisor.conf.tpl",
            user => $config->{user},
            base => $config->{base}
          );
        run_or_die 'supervisorctl update';
    };
};

task 'setup' => sub {
    transaction {};
};

sub get_last_commit {
    my $last_commit = `git log | head -1`;
    my ($sha1) = $last_commit =~ m/commit (.{5})/;
    die 'cannot get latest commit' unless $sha1;
    return $sha1;
}

sub read_password {
    return $config->{sudo_password} if $config->{sudo_password};

    print "Password please: ";
    ReadMode "noecho";    # don't echo anything
    my $password = <STDIN>;
    chomp $password;
    ReadMode 0;           # reset terminal so it echo again
    return $password;
}
