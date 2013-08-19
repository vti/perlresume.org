[program:perlresume.org]
user=<%= $::user %>
command=uwsgi <%= $::base %>/perlresume.org/uwsgi.ini
stdout_logfile=<%= $::base %>/perlresume.org/logs/uwsgi.log
stderr_logfile=<%= $::base %>/perlresume.org/logs/uwsgi_err.log
autostart=true
autorestart=true
redirect_stderr=true
startretries=10
stopwaitsecs = 60
stopsignal=INT
exitcodes=0
