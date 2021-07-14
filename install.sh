#!/bin/sh
# installer.sh will install all necessary packages for paperless-ng bare metal
#Define User-Variables for paperless login
LOGIN="paperless"
MAIL="blank@mail.com"
WORKING_DIR="/opt/paperless"
#Optional
DB_NAME="paperless"
DB_USER="paperless"
DB_PASS="paperless"




# Define Working Directory for Postgresql
#WORKING_DIRPG="/media/drive/paperless/postgresql/11/main"

#andere Variablen paperless.conf
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
PACKAGES="rsync imagemagick fonts-liberation optipng libpq-dev libmagic-dev python3-pip unpaper icc-profiles-free qpdf liblept5 pngquant tesseract-ocr tesseract-ocr-deu leptonica-progs libleptonica-dev automake libtool libjpeg-dev libxml2-dev libxslt1-dev libffi-dev libatlas-base-dev redis"
echo "update"
sudo apt update
echo "upgrade"
sudo apt upgrade -y
echo "install Packages $PACKAGES"
sudo apt install $PACKAGES -y

#Start Redis Server
echo "start redis-server/enable redis-server"
sudo systemctl start redis-server
sudo systemctl enable redis-server

#Add User for Paperless-NG
echo "add system user paperless:paperless"
sudo adduser "paperless" --system --home $WORKING_DIR --group
sudo mkdir $WORKING_DIR
sudo chown -R paperless:paperless $WORKING_DIR

sudo usermod -aG paperless pi

cd $WORKING_DIR

echo "install & configure postgres"
#Postgres Install & Configure
sudo apt install postgresql -y
#sudo systemctl stop postgresql
#sudo sed -i "/data_directory/c\data_directory = '$WORKING_DIRPG'" /etc/postgresql/11/main/postgresql.conf
#sudo rsync -a /var/lib/postgresql/11/main/ $WORKING_DIRPG
#sudo systemctl start postgresql

#set up DB
sudo -u postgres psql -c "create database $DB_NAME;"
sudo -u postgres psql -c "create user $DB_USER with encrypted password '$DB_PASSWORD';"
sudo -u postgres psql -c "grant all privileges on database $DB_NAME to $DB_USER;"

#Get Paperless, unzip
echo "get paperless"
sudo -u paperless wget https://github.com/jonaswinkler/paperless-ng/releases/download/ng-1.4.5/paperless-ng-1.4.5.tar.xz
sudo -u paperless tar -xvf paperless-ng-1.4.5.tar.xz
sudo -u paperless mv ./paperless-ng/* ./
sudo rm paperless-ng-1.4.5.tar.xz

#Setup paperless.conf
sudo sed -i "/#PAPERLESS_OCR_LANGUAGE/c\$PNG_OCR_LANG" $WORKING_DIR/paperless.conf
sudo sed -i "/#PAPERLESS_MEDIA_ROOT/c\$PNG_MEDIA" $WORKING_DIR/paperless.conf
sudo sed -i "/#PAPERLESS_DATA_DIR/c\$PNG_DATA" $WORKING_DIR/paperless.conf
sudo sed -i "/#PAPERLESS_CONSUMPTION_DIR/c\$PNG_CONSUME" $WORKING_DIR/paperless.conf
sudo sed -i "/#PAPERLESS_DBSSLMODE/c\$PNG_DBSSL" $WORKING_DIR/paperless.conf
sudo sed -i "/#PAPERLESS_DBPASS/c\$PNG_DBPASS" $WORKING_DIR/paperless.conf
sudo sed -i "/#PAPERLESS_DBUSER/c\$PNG_DBUSER" $WORKING_DIR/paperless.conf
sudo sed -i "/#PAPERLESS_DBNAME/c\$PNG_DBNAME" $WORKING_DIR/paperless.conf
sudo sed -i "/#PAPERLESS_DBPORT/c\$PNG_DBPORT" $WORKING_DIR/paperless.conf
sudo sed -i "/#PAPERLESS_DBHOST/c\$PNG_DBHOST" $WORKING_DIR/paperless.conf
sudo sed -i "/#PAPERLESS_REDIS/c\$PNG_REDIS" $WORKING_DIR/paperless.conf

#create folders
sudo -u paperless mkdir ./consume 
sudo -u paperless mkdir ./media
sudo -u paperless mkdir ./data

#install git
echo "install git"
sudo apt install git -y -p

#install jbig2enc
echo "compile jbig2enc"
sudo git clone https://github.com/agl/jbig2enc
cd jbig2enc
sudo sh ./autogen.sh
sudo sh ./configure && make
sudo make install
cd ..
#install qpdf
sudo git clone https://github.com/qpdf/qpdf
cd qpdf
sudo sh ./configure && make
sudo make install

sudo sed -i '$aexport PATH="$WORKING_DIR/.local/bin:$PATH"' ~/.profile
#export PATH=$WORKING_DIR/.local/bin/:$PATH

sudo ldconfig

#Requirements.txt
sudo pip3 install --upgrade pip
sudo -Hu paperless pip3 install pybind11
sudo -Hu paperless pip3 install ocrmypdf
sudo -Hu paperless pip3 install -r $WORKING_DIR/requirements.txt

cd $WORKING_DIR/src

#Django User Creation (Login for paperless)
sudo -Hu paperless python3 manage.py migrate
sudo -Hu paperless python3 manage.py createsuperuser --noinput --username "$LOGIN" --email "$MAIL"
#sudo -Hu paperless nohup python3 manage.py runserver

sudo sed -i "/WorkingDirectory/c\WorkingDirectory=$WORKING_DIR/src" $WORKING_DIR/scripts/paperless-webserver.service
sudo sed -i "/ExecStart/c\ExecStart=$WORKING_DIR/.local/bin/gunicorn -c $WORKING_DIR/gunicorn.conf.py paperless.asgi:application" $WORKING_DIR/scripts/paperless-webserver.service
sudo sed -i "/WorkingDirectory/c\WorkingDirectory=$WORKING_DIR/src" $WORKING_DIR/scripts/paperless-consumer.service
sudo sed -i "/WorkingDirectory/c\WorkingDirectory=$WORKING_DIR/src" $WORKING_DIR/scripts/paperless-scheduler.service

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

echo "Set password for user $LOGIN"
sudo -Hu paperless python3 manage.py changepassword
echo "Install complete"

