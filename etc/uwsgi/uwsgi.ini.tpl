[uwsgi]
home=<%= $base %>/www/perlresume.org/
chdir=<%= $base %>/www/perlresume.org/
master=True
disable-logging=True
vacuum=True
pidfile=<%= $base %>/run/uwsgi.pid
max-requests=5000
socket=<%= $uwsgi_listen %>
processes=8

plugins=psgi
psgi=<%= $base %>/www/perlresume.org/app.psgi
