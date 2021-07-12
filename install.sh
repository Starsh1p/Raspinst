#!/bin/sh
# installer.sh will install all necessary packages for paperless-ng bare metal
#Define User
DB_USER="paperless"
DB_PASSWORD="paperless"
DB_NAME="paperless"

# Define Working Directory for Paperless-NG
WORKING_DIR="/media/drive/paperless"

# Define Working Directory for Postgresql
WORKING_DIRPG="/media/drive/paperless/postgresql/11"

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

usermod -aG paperless pi

cd $WORKING_DIR

#Postgres Install & Configure
apt install postgresql -y
systemctl stop postgresql
sed -i "/data_directory/c\data_directory = '$WORKING_DIRPG'" /etc/postgresql/11/main
rsync -av /var/lib/postgresql/11/main $WORKING_DIRPG
systemctl start postgresql

#set up DB
sudo mkdir -p $WORKING_DIRPG/main
sudo -u postgres psql -c "create database $DB_NAME;"
sudo -u postgres psql -c "create user $DB_USER with encrypted password '$DB_PASSWORD';"
sudo -u postgres psql -c "grant all privileges on database $DB_NAME to $DB_USER;"

#Get Paperless, unzip
sudo -u paperless wget https://github.com/jonaswinkler/paperless-ng/releases/download/ng-1.4.5/paperless-ng-1.4.5.tar.xz
sudo -u paperless tar -xvf paperless-ng-1.4.5.tar.xz
sudo -u paperless mv ./paperless-ng/* ./
rm paperless-ng-1.4.5.tar.xz

#Setup paperless.conf
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

#create folders
sudo -u paperless mkdir ./consume 
sudo -u paperless mkdir ./media
sudo -u paperless mkdir ./data

#install git
sudo apt install git -y

#install jbig2enc
git clone https://github.com/agl/jbig2enc
cd jbig2enc
./autogen.sh
./configure && make
make install
cd ..
#install qpdf
git clone https://github.com/qpdf/qpdf
cd qpdf
./configure && make
make install

#export PATH=$PATH:$WORKING_DIR/.local/bin/

sudo ldconfig

#Requirements.txt
sudo pip3 install --upgrade pip
sudo -Hu paperless pip3 install pybind11
sudo -Hu paperless pip3 install ocrmypdf
sudo -Hu paperless pip3 install -r $WORKING_DIR/requirements.txt

cd src

sudo -Hu paperless python3 manage.py migrate
sudo -Hu paperless python3 manage.py createsuperuser
#sudo -Hu paperless python3 manage.py runserver

sudo sed -i "/WorkingDirectory/c\WorkingDirectory=$WORKING_DIR/src" $WORKING_DIR/scripts/paperless-webserver.service
sudo sed -i "/ExecStart/c\ExecStart=$WORKING_DIR/.local/bin/gunicorn -c $WORKING_DIR/gunicorn.conf.py paperless.asgi:application" $WORKING_DIR/scripts/paperless-webserver.service
sudo sed -i "/WorkingDirectory/c\WorkingDirectory=$WORKING_DIR/src" $WORKING_DIR/scripts/paperless-consumer.service
sudo sed -i "/WorkingDirectory/c\WorkingDirectory=$WORKING_DIR/src" $WORKING_DIR/src/scripts/paperless-scheduler.service

sudo cp $WORKING_DIR/scripts/paperless-consumer.service /usr/lib/systemd/system/
sudo cp $WORKING_DIR/scripts/paperless-scheduler.service /usr/lib/systemd/system/
sudo cp $WORKING_DIR/scripts/paperless-webserver.service /usr/lib/systemd/system/

sudo systemctl start paperless-webserver.service
sudo systemctl start paperless-scheduler.service
sudo systemctl start paperless-consumer.service

sudo systemctl enable paperless-webserver.service
sudo systemctl enable paperless-scheduler.service
sudo systemctl enable paperless-consumer.service
sudo systemctl daemon-reload



echo "Install complete"

