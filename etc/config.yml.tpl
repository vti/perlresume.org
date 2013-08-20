appname: "Perlresume"

layout: "main"

charset: "UTF-8"

template: "caml"

plugins:
    Database:
        connections:
            perlresume:
                driver: 'SQLite'
                database: '<%= $::base %>/perlresume.db'
            cpants:
                driver: 'SQLite'
                database: '<%= $::base %>/cpants_all.db'
