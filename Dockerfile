FROM ubuntu as base
# Setup Dependecies
RUN apt-get update && apt-get upgrade -y --fix-missing
RUN apt-get install -y apt-utils vim curl apache2 apache2-utils 
RUN apt-get install -y python3 
RUN ln /usr/bin/python3 /usr/bin/python 
RUN apt-get install -y python3-pip
RUN ln -sf /usr/bin/pip3 /usr/bin/pip 
RUN pip install --upgrade pip 
RUN apt-get install -y build-essential libsasl2-dev libldap2-dev libssl-dev
# RUN pip install django-ptvsd
RUN apt-get install -y subversion
ARG DEBIAN_FRONTEND=noninteractive
# Setup Phppgadmin
RUN apt-get -y install postgresql postgresql-contrib phppgadmin
ADD /docker-asset/phppgadmin.conf /etc/apache2/conf-available/phppgadmin.conf
ADD /docker-asset/config.inc.php /etc/phppgadmin/config.inc.php
# Other Dependencies
RUN apt-get install -y awscli
ADD /docker-asset/packages-microsoft-prod.deb /home
RUN dpkg -i /home/packages-microsoft-prod.deb
RUN apt-get update
RUN apt-get install -y powershell
RUN pwsh --command "install-module -Name VMware.PowerCLI -Scope AllUsers -Force"
RUN mkdir -p /var/www/.local/share
RUN chmod 777 -R /var/www/.local/share
# Setup Postgres
USER postgres
RUN service postgresql start &&\
    psql --command "CREATE USER root WITH SUPERUSER PASSWORD 'Aa12!@#%^&';" &&\
    createdb -O root project
USER root
VOLUME ["/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql"]
EXPOSE 5432
EXPOSE 80
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf
RUN /etc/init.d/postgresql restart
RUN /etc/init.d/apache2 start
# Setup Django project
RUN mkdir /opt/project
ADD /project /opt/project
RUN chmod 777 -R /opt/project
RUN pip install -r /opt/project/requirementsLinux.txt
RUN ["chmod", "+x", "/opt/project/sync_projectdb.sh"]
RUN service postgresql start &&\
    ./opt/project/sync_projectdb.sh
RUN python /opt/project/manage.py collectstatic
RUN chmod 777 -R /var/www/project
# Setup Cron
RUN bin/bash -c 'echo "# project Job Definition" >> /etc/crontab'
RUN bin/bash -c 'echo "*/45 * * * *   root /usr/bin/python /opt/project/manage.py serviceA" >> /etc/crontab'
RUN bin/bash -c 'echo "0    0 * * 1-5 root /usr/bin/python /opt/project/manage.py serviceB" >> /etc/crontab'
RUN /etc/init.d/cron start
############################
# ENVIRONTMENT DEVELOPMENT #
############################
FROM base as development
RUN pip install debugpy
ADD /docker-asset/serverStart.sh /home/serverStart.sh
CMD ["/bin/bash", "-c", "/home/serverStart.sh && tail -f /dev/null"]
############################
# ENVIRONTMENT  PRODUCTION #
############################
FROM base as production
# Setup WSGI
RUN apt-get install -y python3 libapache2-mod-wsgi-py3 
RUN a2enmod file_cache
RUN a2enmod proxy_http
ADD /docker-asset/site-config.conf /etc/apache2/sites-available/000-default.conf
ADD /docker-asset/hosts /etc/hosts
RUN /etc/init.d/apache2 restart
ADD /docker-asset/serverStart.sh /home/serverStart.sh
CMD ["/bin/bash", "-c", "/home/serverStart.sh && tail -f /dev/null"]