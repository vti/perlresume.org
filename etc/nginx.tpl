server {
        server_name <%= $::server_name %>;

        access_log  <%= $::access_log %>;
        error_log   <%= $::error_log %>;

        root <%= $::root %>;

        location / {
                client_max_body_size 10M;
                client_body_buffer_size 128k;

                try_files $uri @proxy;
                access_log off;
                expires max;
        }

        location @proxy {
                include uwsgi_params;

                uwsgi_param X-Real-IP $remote_addr;
                uwsgi_param Host $http_host;
                uwsgi_modifier1 5;

                uwsgi_pass <%= $::uwsgi_pass %>;
        }
}
