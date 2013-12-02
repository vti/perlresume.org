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

sub file_update_if_needed {
    my ($file, %options) = @_;

    my $content = $options{content} || cat $options{source};

    if (!is_file($file) || $content ne cat $file) {
        if (is_file($file)) {
            Rex::Logger::info("Back up old config");
            mv $file, $file . ".prev";
        }

        Rex::Logger::info("Writing configuration file");
        file $file, content => $content;

        return 1;
    }
    else {
        if (is_file "$file.prev") {
            Rex::Logger::info("Removing outdated backup");

            rm "$file.prev";
        }

        Rex::Logger::info("Files are same. Skipping");

        return 0;
    }
}

sub file_rollback_if_needed {
    my ($file) = @_;

    if (!is_file("$file.prev")) {
        Rex::Logger::info("Nothing to rollback");
        return 0;
    }

    mv "$file.prev", $file;
    return 1;
}

set connection => 'OpenSSH';

task 'upload_archive' => sub {
    my $sha1 = get_last_commit();
    my $latest_release = "app-$sha1";

    if (is_dir("$config->{base}/$latest_release")) {
        Rex::Logger::info("Already uploaded");
        return;
    }

    my $archive;
    LOCAL {
        $archive = "$latest_release.tar.gz";

        my @files = run "$ls_files";
        run_or_die "tar --transform 's,^,$latest_release/,' -czf $archive @files";
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

    if (readlink("$base/app-current", "$base/$latest_release")) {
        Rex::Logger::info("Already switched");
    }
    else {
        rm "$base/app-current";
        ln "$base/$latest_release", "$base/app-current";

        run_or_die "supervisorctl restart $config->{app}";
    }
};

task 'uwsgi_rollout' => sub {
    mkdir "$config->{base}/uwsgi/";

    my $content = template(
        'etc/uwsgi.ini.tpl',
        base         => $config->{base},
        uwsgi_listen => $config->{uwsgi_listen}
    );

    file_update_if_needed "$config->{base}/uwsgi/uwsgi.ini",
      content => $content;
};

task 'uwsgi_rollback' => sub {
    my $file = "$config->{base}/uwsgi/uwsgi.ini";

    file_rollback_if_needed $file;
};

task 'nginx_rollout' => sub {
    my $content = template(
        'etc/nginx.tpl',
        server_name => $config->{name},
        access_log  => "$config->{base}/logs/access.log",
        error_log   => "$config->{base}/logs/error.log",
        root        => "$config->{base}/app-current/public",
        uwsgi_pass  => $config->{uwsgi_listen}
    );

    my $path_to_config = "/etc/nginx/sites-available/$config->{name}";

    sudo_password read_password();
    sudo sub {
        if (file_update_if_needed $path_to_config, content => $content) {
            service nginx => 'restart';
        }
    };
};

task 'nginx_rollback' => sub {
    my $path_to_config = "/etc/nginx/sites-available/$config->{name}";

    sudo_password read_password();
    sudo sub {
        if (file_rollback_if_needed $path_to_config) {
            rm "/etc/nginx/sites-enabled/$config->{name}";
            ln "/etc/nginx/sites-available/$config->{name}",
              "/etc/nginx/sites-enabled/$config->{name}";

            mkdir "$config->{base}/logs/";

            service nginx => 'restart';
        }
    };
};

task 'supervisor_rollout' => sub {
    my $path_to_config ="/etc/supervisor/conf.d/$config->{name}.conf";

    my $content = template(
      "etc/supervisor.conf.tpl",
      user => $config->{user},
      base => $config->{base}
    );

    sudo_password read_password();
    sudo sub {
        if (file_update_if_needed $path_to_config, content => $content) {
            run_or_die 'supervisorctl update';
        }
    };
};

task 'supervisor_rollback' => sub {
    my $path_to_config = "/etc/supervisor/conf.d/$config->{name}.conf";

    sudo_password read_password();
    sudo sub {
        if (file_rollback_if_needed $path_to_config) {
            run_or_die 'supervisorctl update';
        }
    };
};

task 'rollout' => sub {
    transaction {
        upload_archive();
        installdeps();
        uwsgi_rollout();
        nginx_rollout();
        switch();
    };
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
