#!/bin/sh
# installer.sh will install all necessary packages for paperless-ng bare metal
#Define User
USER="paperless"
PASSWORD="paperless"
DB_NAME="paperless"

# Define Working Directory for Paperless-NG
WORKING_DIR="/media/drive/paperless"

# Define Working Directory for Postgresql
WORKING_DIRPG="/media/drive/paperless/postgresql/11/main"

# Install packages
PACKAGES="imagemagick fonts-liberation optipng libpq-dev libmagic-dev python3-pip unpaper icc-profiles-free qpdf liblept5 pngquant tesseract-ocr tesseract-ocr-deu leptonica-progs libleptonica-dev automake libtool libjpeg-dev libxml2-dev libxslt1-dev libffi-dev libatlas-base-dev redis"
apt update
apt upgrade -y
apt install $PACKAGES -y

#Start Redis Server
systemctl start redis-server
systemctl enable redis-server

#Add User for Paperless-NG
adduser "paperless" --system --home $WORKING_DIR --group

#Postgres Install & Configure
apt install postgresql
systemctl stop postgresql
sed -i "/data_directory/c\data_directory = '$WORKING_DIRPG' /etc/postgresql/11/main

rsync -av /var/lib/postgresql/11/main WORKING_DIRPG
systemctl start postgresql

#set up DB
sudo -u postgres psql
create database $DB_NAME;
create user $USER with encrypted password '$PASSWORD';
grant all privileges on database $DB_NAME to $USER;
/q

usermod -aG paperless pi
cd $WORKING_DIR
sudo -u paperless wget https://github.com/jonaswinkler/paperless-ng/releases/download/ng-1.4.5/paperless-ng-1.4.5.tar.xz
sudo -u paperless tar -xvf paperless-ng-1.4.5.tar.xz
sudo -u paperless mv ./paperless-ng/* ./
rm paperless-ng-1.4.5.tar.xz










echo "Install complete, rebooting."
reboot
