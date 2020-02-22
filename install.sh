echo "==================================================================\n"
echo "            updating..."
echo "\n"
apt-get -y update
apt-get -y upgrade
echo "done."

echo "\n"
echo "==================================================================\n"
echo "            installing package..."
echo "\n"
apt-get install -y sudo git apache2 sendmail
echo "done."

echo "\n"
echo "==================================================================\n"
echo "            debian disk infos :"
echo "\n"

sudo fdisk -l
sleep 3s

echo "\n"
echo "==================================================================\n"
echo "            user creation..."
echo "\n"

echo "Adding sudo user... Username ? (default: 'roger')"
read Username
Username=${Username:-"roger"}
sudo adduser $Username
sudo adduser $Username sudo

echo "\n"
echo "==================================================================\n"
echo "            INTERFACES"
echo "\n"

cp /etc/network/interfaces /etc/network/interfaces_save
rm -f /etc/network/interfaces
cp /root/roger-skyline-1/files/interfaces /etc/network

cp /root/roger-skyline-1/files/enp0s3 /etc/network/interfaces.d/

sudo service networking restart
echo "done."

echo "\n"
echo "==================================================================\n"
echo "            SSHD_CONFIG"
echo "\n"

cp /etc/ssh/sshd_config /etc/ssh/sshd_config_save
rm -rf /etc/ssh/sshd_config
cp /root/roger-skyline-1/files/sshd_config /etc/ssh/
mkdir -pv /home/$Username/.ssh
yes '/root/roger-skyline-1/files/id_rsa' | ssh-keygen
cat /root/roger-skyline-1/files/id_rsa.pub >> /home/$Username/.ssh/authorized_keys
ssh-copy-id -i /root/roger-skyline-1/files/id_rsa.pub $Username@10.11.42.42 -p 3333

/etc/init.d/ssh restart
echo "done."

echo "\n"
echo "==================================================================\n"
echo "            FIREWALL"
echo "\n"

#Nettoyage des règles existantes
sudo iptables -t filter -F
sudo iptables -t filter -X
# Blocage total
sudo iptables -t filter -P INPUT DROP
sudo iptables -t filter -P FORWARD DROP
sudo iptables -t filter -P OUTPUT DROP
# Garder les connexions etablies
sudo iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# Autoriser loopback
sudo iptables -t filter -A INPUT -i lo -j ACCEPT
# Autoriser SSH
sudo iptables -t filter -A INPUT -p tcp --dport 3333 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 3333 -j ACCEPT
# Autoriser HTTP
sudo iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT
# Autoriser HTTPS
sudo iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -t filter -A INPUT -p tcp --dport 8443 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT
# Autoriser DNS
sudo iptables -t filter -A INPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -t filter -A INPUT -p udp --dport 53 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p tcp --dport 53 -j ACCEPT
sudo iptables -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT
# Autoriser SMTP
sudo iptables -t filter -A OUTPUT -p tcp --dport 25 -j ACCEPT
echo "done."

echo "\n"
echo "==================================================================\n"
echo "            DDOS PROTECTION"
echo "\n"

# Bloque les paquets invalides
sudo iptables -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j DROP
# Bloque les nouveaux paquets qui n'ont pas le flag tcp syn
sudo iptables -t mangle -A PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j DROP
# Bloque les valeurs MSS anormal
sudo iptables -t mangle -A PREROUTING -p tcp -m conntrack --ctstate NEW -m tcpmss ! --mss 536:65535 -j DROP
# Limite les nouvelles connexions
sudo iptables -A INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 60/s --limit-burst 20 -j ACCEPT
sudo iptables -A INPUT -p tcp -m conntrack --ctstate NEW -j DROP
# Limite les nouvelles connexions si un client possede deja 80 connexions
sudo iptables -A INPUT -p tcp -m connlimit --connlimit-above 80 -j REJECT --reject-with tcp-reset
# Limite les connections
sudo iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/minute --limit-burst 100 -j ACCEPT
# Protection Synflood
sudo iptables -A INPUT -p tcp --syn -m limit --limit 2/s --limit-burst 30 -j ACCEPT
# Protection Pingflood
sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT
echo "done."

echo "\n"
echo "==================================================================\n"
echo "            PORTS SCAN PROTECTION"
echo "\n"

# Protection scan de ports
sudo iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
sudo iptables -A INPUT -p tcp --tcp-flags ALL ALL -m limit --limit 1/h -j ACCEPT
echo "done."

echo "\n"
echo "==================================================================\n"
echo "                  FAIL2BAN CONFIGURATION"
echo "\n"

sudo apt-get install fail2ban
cp /root/roger-skyline-1/files/jail.local /etc/fail2ban/
sudo service fail2ban restart
sudo fail2ban-client status
sleep 3s
echo "done."


echo "\n"
echo "==================================================================\n"
echo "            making the configuration persistent..."
echo "\n"

apt-get install -y iptables-persistent
echo "done."

echo "\n"
echo "==================================================================\n"
echo "            MAIL SERVER"
echo "\n"

yes 'Y' | sudo sendmailconfig
echo "done."

echo "\n"
echo "==================================================================\n"
echo "            UPDATE SCRIPT"
echo "\n"

mkdir /root/scripts
cp /root/roger-skyline-1/scripts/script_log.sh /root/scripts/
chmod 755 /root/scripts/script_log.sh
chown root /root/scripts/script_log.sh

echo "0 4 * * wed root /root/scripts/script_log.sh\n" >> /etc/crontab
echo "@reboot root /root/scripts/script_log.sh\n" >> /etc/crontab

echo "0 4 * * wed root /root/scripts/script_log.sh\n" >> /var/spool/cron/crontabs/root
echo "@reboot root /root/scripts/script_log.sh\n" >> /var/spool/cron/crontabs/root

echo "done."

echo "\n"
echo "==================================================================\n"
echo "            CRONTAB SCRIPT"
echo "\n"

cp /root/roger-skyline-1/scripts/script_crontab.sh /root/scripts/
cp /root/roger-skyline-1/files/mail_type.txt /root/scripts/
chmod 755 /root/scripts/script_crontab.sh
chown root /root/scripts/script_crontab.sh
chown root /root/scripts/mail_type.txt
echo "0 0 * * * root /root/scripts/script_crontab.sh\n" >> /etc/crontab
echo "0 0 * * * root /root/scripts/script_crontab.sh\n" >> /var/spool/cron/crontabs/root
cat /etc/crontab > /root/scripts/tmp
echo "done."

echo "\n"
echo "==================================================================\n"
echo "            WEB SERVER"
echo "\n"

systemctl start apache2
echo "done."

echo "\n"
echo "==================================================================\n"
echo "            VIRTUAL HOST"
echo "\n"

mkdir -p /var/www/init.login.fr/html
chown -R $Username:$Username /var/www/init.login.fr/html
chmod -R 775 /var/www/init.login.fr

cp /root/roger-skyline-1/files/index.html /var/www/init.login.fr/html/
cp -r /root/roger-skyline-1/files/home.css /var/www/init.login.fr/html/

cp /root/roger-skyline-1/files/init.login.fr.conf /etc/apache2/sites-available/

rm /etc/apache2/sites-enabled/000-default.conf
ln -s /etc/apache2/sites-available/init.login.fr.conf /etc/apache2/sites-enabled/

echo "done."

echo "\n"
echo "==================================================================\n"
echo "            SSL CERTIFICAT"
echo "\n"

cd /etc/ssl/certs/
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout roger.key -out roger.crt

sudo a2enmod ssl
sudo service apache2 restart
echo "done."

echo "\n"
echo "==================================================================\n"
echo "            CLEANING &  desactivating unecessary services"
echo "\n"

apt-get remove -y git
yes 'Y' | sudo apt-get remove --auto-remove git-man
rm -rf /root/roger-skyline-1/
sudo /etc/init.d/apparmor stop
sudo systemctl stop apparmor.service
sudo update-rc.d -f apparmor remove
echo "Subject: Install done for $Username." | sudo sendmail -v manki@student.42.fr
echo "Work done."
