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

#andere Variablen
PNG_REDIS="PAPERLESS_REDIS=redis://localhost:6379"
PNG_DBHOST="PAPERLESS_DBHOST=localhost"
PNG_DBPORT="PAPERLESS_DBPORT=5432"
PNG_DBNAME="PAPERLESS_DBNAME=paperless"
PNG_DBUSER="PAPERLESS_DBUSER=paperless"
PNG_DBPASS="PAPERLESS_DBPASS=paperless"
PNG_DBSSL="PAPERLESS_DBSSLMODE=prefer"
PNG_CONSUME="PAPERLESS_CONSUMPTION_DIR=../consume"
PNG_DATA_DIR="PAPERLESS_DATA_DIR=../data"
PNG_MEDIA="PAPERLESS_MEDIA_ROOT=../media"
PNG_OCR_LANG="PAPERLESS_OCR_LANGUAGE=deu"

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
sed -i "/data_directory/c\data_directory = '$WORKING_DIRPG'" /etc/postgresql/11/main

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

sed -i "/#PAPERLESS_OCR_LANGUAGE/c\$PNG_OCR_LANG" $WORKING_DIR/paperless.conf
sed -i "/#PAPERLESS_MEDIA_ROOT/c\$PNG_MEDIA" $WORKING_DIR/paperless.conf
sed -i "/#PAPERLESS_DATA_DIR/c\$PNG_DATA" $WORKING_DIR/paperless.conf
sed -i "/#PAPERLESS_CONSUMPTION_DIR/c\$PNG_CONSUME" $WORKING_DIR/paperless.conf
sed -i "/#PAPERLESS_DBSSLMODE/c\$PNG_DBSSL" $WORKING_DIR/paperless.conf
sed -i "/#PAPERLESS_DBPASS/c\$PNG_DBPASS" $WORKING_DIR/paperless.conf
sed -i "/#PAPERLESS_DBUSER/c\$PNG_DBUSER" $WORKING_DIR/paperless.conf
sed -i "/#PAPERLESS_DBNAME/c\$PNG_DBNAME" $WORKING_DIR/paperless.conf
sed -i "/#PAPERLESS_DBPORT/c\$PNG_DBPORT" $WORKING_DIR/paperless.conf
sed -i "/#PAPERLESS_DBHOST/c\$PNG_DBHOST" $WORKING_DIR/paperless.conf
sed -i "/#PAPERLESS_REDIS/c\$PNG_REDIS" $WORKING_DIR/paperless.conf

sudo -u paperless mkdir ./consume 
sudo -u paperless mkdir ./media
sudo -u paperless mkdir ./data

sudo apt install git








echo "Install complete, rebooting."
reboot
