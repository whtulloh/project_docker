#!/bin/bash
echo "Running Cron"
service cron restart

echo "Running Postgress"
service postgresql start

echo "Running Apache Server"
service apache2 start