sudo apt update
sudo apt full-upgrade
sudo apt install apt-transport-https
curl -s https://syncthing.net/release-key.txt | sudo apt-key add -
echo "deb https://apt.syncthing.net/ syncthing stable" | sudo tee /etc/apt/sources.list.d/syncthing.list
sudo apt update
sudo apt install syncthing

syncthing
nano ~/.config/syncthing/config.xml
sudo nano /lib/systemd/system/syncthing.service
sudo nano /lib/systemd/system/syncthing.service
sudo systemctl enable syncthing
sudo systemctl start syncthing
sudo systemctl status syncthing
