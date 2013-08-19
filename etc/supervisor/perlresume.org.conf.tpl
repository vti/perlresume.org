[program:perlresume.org]
user=<%= $::user %>
command=uwsgi <%= $::base %>/uwsgi/perlresume.org.uwsgi.ini
stdout_logfile=<%= $::base %>/logs/perlresume.org.uwsgi.log
stderr_logfile=<%= $::base %>/logs/perlresume.org.uwsgi_err.log
autostart=true
autorestart=true
redirect_stderr=true
startretries=10
stopwaitsecs = 60
stopsignal=INT
exitcodes=0
