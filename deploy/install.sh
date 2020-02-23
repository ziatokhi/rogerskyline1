#!/bin/bash

 
echo "All Packages Updating>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
echo "\n"

apt-get update -y
apt-get upgrade -y

echo "\n"

echo "Installing Packages>>>>>>>>>>>>>>>>>>>>>>>>>"
echo "\n"

apt-get install sudo -y
apt-get install apache2 -y
apt-get install sendmail -y
apt-get install portsentry -y
apt-get install fail2ban -y
apt-get install ufw -y
apt-get install vim -y

sleep 5
 

echo "\n"
 
echo "Creating User Account >>>>>>>>>>>>>>>>>."
echo "\n"

echo "adding NEW sudo user... Username ? (default: 'roger')"
read Username
Username=${Username:-"roger"}
sudo adduser $Username
sudo adduser $Username sudo

sleep 5

echo "Completed"

echo "\n"
 
echo " interfaces>>>>>>>>>>>>>>>>>>>>>>>>>"
echo "\n"

mv /etc/network/interfaces /etc/network/interfaces_save
cp /root/rogerskyline1/deploy/files/interfaces /etc/network/

cp /root/rogerskyline1/deploy/files/enp0s3 /etc/network/interfaces.d/

sudo service networking restart

echo "STATIC IP ADDRESS >>>>>>>>>>>>>>>>>>>>>\n"
ip addr

sleep 4

echo "Completed >>>>>>>>>>>>>>>>>>..."

echo "\n"
 
echo " SSHD config>>>>>>>>>>>>>>>>>>>>"
echo "\n"

mv /etc/ssh/sshd_config /etc/ssh/sshd_config_save

cp /root/rogerskyline1/deploy/files/sshd_config /etc/ssh/
mkdir -pv /home/$Username/.ssh
cat /root/rogerskyline1/deploy/files/id_rsa.pub >> /home/$Username/.ssh/authorized_keys
 

sleep 3

sudo service sshd restart

echo "Completed"

echo "\n"
 
echo " setup Firewall>>>>>>>>>>>>>>>>>>>>>>"
echo "\n"

sudo ufw enable
#ssh
sudo ufw allow 51001/tcp
#http
sudo ufw allow 80/tcp
#https
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw reload
sudo ufw status verbose

sleep 3

sudo systemctl start ufw
sudo systemctl enable ufw

#/*///////////////////////////////////////////////////////////////////// sais plus !!!!!
#sudo apt-get iptables
#sudo iptables -t filter -A INPUT -p tcp --dport 51001 -j ACCEPT
#sudo iptables -t filter -A OUTPUT -p tcp --dport 51001 -j ACCEPT
#*///////////////////////////////////////////////////////////////////


sleep 3

echo "Completed>>>>>>>>>>>>>>>>>>>"

echo "\n"
 
echo " DOS protection>>>>>>>>>>>>>>>>>>>>>>"
echo "\n"

sleep 2

#cp /etc/fail2ban/fail2ban.conf /etc/fail2ban/fail2ban.local
#rm /etc/fail2ban/fail2ban.conf
mv /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
cp /root/rogerskyline1/deploy/files/jail.conf /etc/fail2ban/
cp /root/rogerskyline1/deploy/files/apache-dos.conf /etc/fail2ban/filter.d/
sudo systemctl restart fail2ban
#start la jail
sudo fail2ban-client start
echo "STATUS  jail status\n"
sudo fail2ban-client status
#verif status prison sshd avec nombre de tentative echouees et liste ip bannies
echo "STATUS  sshd's jail\n"
sudo fail2ban-client status sshd
#de-bannir une ip d'une jail
#fail2ban-client set [nom de jail] unbanip [IP concernee]
#bannir manuellement une IP sur une jail
#fail2ban-client set [nom de jail] banip [IP a bannir]

sleep 4

echo "COMPLETED"

echo "\n"
 
echo " Installing Port Scans DEFEFENCE>>>>>>>>>>>>>>>>>>>>>>>>>>>>>..."
echo "\n"

#config portsentry
mv /etc/default/portsentry /etc/default/portsentry_save
cp /root/rogerskyline1/deploy/files/portsentry /etc/default/
mv /etc/portsentry/portsentry.conf /etc/portsentry/portsentry.conf_save
cp /root/rogerskyline1/deploy/files/portsentry.conf /etc/portsentry/

sleep 5

sudo service portsentry restart
sudo apt-get install iptables-persistent
sudo iptables-save > /etc/iptables/rules.v6

echo "done"

echo "\n"
echo "---------------------------------------------------------------\n"
echo "          Mail server"
echo "\n"

yes 'Y' | sudo sendmailconfig

sleep 2

echo "\n"
echo "---------------------------------------------------------------\n"
echo "          update Script"
echo "\n"
#met a jour ensemble des packages, qui log l'ensemble ds un fichier 
#/var/log/update_script.log. A chaque reboot et 1 fois par semaine a 4h du mat.

mkdir /root/script
cp /root/rogerskyline1/deploy/files/update_script.sh /root/script
chmod 755 /root/script/update_script.sh
chown root /root/script/update_script.sh

sleep 5

echo "0  4  * * 1	root    /root/script/update_script.sh\n" >> /etc/crontab
echo "@reboot	root    /root/script/update_script.sh\n" >> /etc/crontab

echo "0  4  * * 1	root    /root/script/update_script.sh\n" >> /var/spool/cron/crontabs/root
echo "@reboot	root    /root/script/update_script.sh\n" >> /var/spool/cron/crontabs/root

sleep 5

echo "completed"

echo "\n"
 echo "Schedule task crontab script"
echo "\n"

#script qui permet de surveiller modifications du fichier /etc/crontab et 
#envoie un mail a root si modifie. tache planifie tous les jour a minuit.

cp /root/rogerskyline1/deploy/files/script_modif_crontab.sh /root/script/
cp /root/rogerskyline1/deploy/files/mail_type.txt /root/script/
chmod 755 /root/script/script_modif_crontab.sh
chown root /root/script/script_modif_crontab.sh
chown root /root/script/mail_type.txt

echo "done\n"

echo "0  0  * * *	root    /root/script/script_modif_crontab.sh\n" >> /etc/crontab
echo "0  0  * * *	root    /root/script/script_modif_crontab.sh\n" >> /var/spool/cron/crontabs/root

systemctl enable cron

touch /root/script/tmp
cat /etc/crontab > /root/script/tmp

sleep 3

echo "completed"

echo "\n"
 
echo "Starting WebServer.............."
echo "\n"

sudo systemctl start apache2

echo "completed"

echo "\n"
 
echo "web Vhosting added"
echo "\n"

mkdir -p /var/www/login.fr/html
chown -R $Username:$Username /var/www/login.fr/html
chmod -R 755 /var/www/login.fr/html

cp /root/rogerskyline1/deploy/files/index.html /var/www/login.fr/html
cp /root/rogerskyline1/deploy/files/style.css /var/www/login.fr/html

cp /root/rogerskyline1/deploy/files/default-ssl.conf /etc/apache2/sites-available

rm /etc/apache2/sites-available/000-default.conf
cp /root/rogerskyline1/deploy/files/000-default.conf /etc/apache2/sites-available/
ln -s /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-enabled

sleep 3

echo "completed"

echo "\n"
 
echo "SSL certificat..."
echo "\n"

sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -subj "/C=FR/ST=IDF/O=42/OU=Project-roger/CN=10.11.50.50" -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt

sleep 2

sudo a2enmod ssl
#sudo service apache2 restart
sudo systemctl restart apache2

sleep 2

echo "done"

echo "\n"
 
echo " Removing all unwated contents"
echo "\n"

apt-get remove git -y
apt-get purge git -y
rm -rf /root/rogerskyline1
echo "done"

echo "Subject Installation Completed $Username." | sudo sendmail -v zkamran@student.42.fr
echo "\n"
echo "ALL TASK Completed....."
