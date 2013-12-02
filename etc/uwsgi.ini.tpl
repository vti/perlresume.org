[uwsgi]
home=<%= $base %>/app-current/
chdir=<%= $base %>/app-current/
master=True
disable-logging=True
vacuum=True
pidfile=<%= $base %>/uwsgi/uwsgi.pid
max-requests=5000
socket=<%= $uwsgi_listen %>
processes=8


plugins=psgi
psgi=<%= $base %>/app-current/bin/app.pl
