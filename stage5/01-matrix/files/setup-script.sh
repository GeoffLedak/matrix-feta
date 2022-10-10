#!/bin/bash

SERVER_DOMAIN=
USER_EMAIL=


begin_installation() {

{


# --- Generate matrix config and enable registration ---

sudo -u pi /home/pi/gen-matrix-config.sh ${SERVER_DOMAIN} 2>> error.txt 1>> /dev/null

echo 24


# --- enable registration and restart synapse server ---

cd /home/pi/matrix 2>> error.txt 1>> /dev/null

sudo -H -u pi sed -i '/^ *#* *enable_registration:/c\enable_registration: true' homeserver.yaml 2>> error.txt 1>> /dev/null
sudo -H -u pi sed -i '/^ *#* *enable_registration_without_verification:/c\enable_registration_without_verification: true' homeserver.yaml 2>> error.txt 1>> /dev/null

echo 32



# --- enable federation ---

mkdir -p /var/www/${SERVER_DOMAIN}/.well-known/matrix 2>> error.txt 1>> /dev/null

cat 2>> error.txt 1> /var/www/${SERVER_DOMAIN}/.well-known/matrix/server <<EOL
{ "m.server": "matrix.${SERVER_DOMAIN}:443" }
EOL

echo 40


# --- install and configure element ---

mkdir /var/www/element.${SERVER_DOMAIN} 2>> error.txt 1>> /dev/null
mv /home/pi/install/element-v1.10.12.tar.gz /var/www/element.${SERVER_DOMAIN} 2>> error.txt 1>> /dev/null
rmdir /home/pi/install 2>> error.txt 1>> /dev/null
cd /var/www/element.${SERVER_DOMAIN} 2>> error.txt 1>> /dev/null
tar -xzvf element-v1.10.12.tar.gz 2>> error.txt 1>> /dev/null
ln -s element-v1.10.12 element 2>> error.txt 1>> /dev/null
chown www-data:www-data -R element 2>> error.txt 1>> /dev/null
cd element 2>> error.txt 1>> /dev/null

MATRIX_URL="https://matrix.${SERVER_DOMAIN}"

jq --arg SERVER_DOMAIN "$SERVER_DOMAIN" --arg MATRIX_URL "$MATRIX_URL" '.default_server_config."m.homeserver".base_url = $MATRIX_URL | .default_server_config."m.homeserver".server_name = $SERVER_DOMAIN' config.sample.json 2>> error.txt 1> config.json

echo 48


# --- configure coturn ---

AUTH_SECRET=$(date +%s | sha256sum | base64 | head -c 32)

cd /etc 2>> error.txt 1>> /dev/null
sudo mv turnserver.conf turnserver-backup.conf 2>> error.txt 1>> /dev/null

cat 2>> error.txt 1> /etc/turnserver.conf <<EOL
syslog

lt-cred-mech
use-auth-secret
static-auth-secret=${AUTH_SECRET}
realm=matrix.${SERVER_DOMAIN}

cert=/etc/letsencrypt/live/matrix.${SERVER_DOMAIN}/fullchain.pem
pkey=/etc/letsencrypt/live/matrix.${SERVER_DOMAIN}/privkey.pem

no-udp
external-ip=matrix.${SERVER_DOMAIN}
min-port=64000
max-port=65535
EOL

systemctl restart coturn 2>> error.txt 1>> /dev/null

echo 56


# --- configure synapse to use coturn ---

cd /home/pi/matrix 2>> error.txt 1>> /dev/null
sed -i 's/^ *# *turn_user_lifetime *: *[^ ]*/turn_user_lifetime: 1h/' homeserver.yaml 2>> error.txt 1>> /dev/null
sed -i 's/^ *# *turn_allow_guests *: *[^ ]*/turn_allow_guests: true/' homeserver.yaml 2>> error.txt 1>> /dev/null
sed -i 's/^ *# *turn_shared_secret *: *[^ ]*/turn_shared_secret: '"\"${AUTH_SECRET}\""'/' homeserver.yaml 2>> error.txt 1>> /dev/null


sed -i 's/^ *# *turn_uris *: *[^ ]*/turn_uris:\n\n - \"turns:matrix.feta.bz?transport=udp\"\n - \"turns:matrix.feta.bz?transport=tcp\"\n - \"turn:matrix.feta.bz?transport=udp\"\n - \"turn:matrix.feta.bz?transport=tcp\"/' homeserver.yaml 2>> error.txt 1>> /dev/null


sed -i 's/^ *# *turn_uris *: *[^ ]*/turn_uris:\n\n - \"turns:matrix.'"${SERVER_DOMAIN}"'?transport=udp\"\n - \"turns:matrix.'"${SERVER_DOMAIN}"'?transport=tcp\"\n - \"turn:matrix.'"${SERVER_DOMAIN}"'?transport=udp\"\n - \"turn:matrix.'"${SERVER_DOMAIN}"'?transport=tcp\"/' homeserver.yaml 2>> error.txt 1>> /dev/null

echo 64


# --- create postgres user and database ---

DATABASE_PASSWORD=$(date +%s | sha256sum | base64 | head -c 32)

sudo -u postgres /home/pi/configure-postgres.sh ${DATABASE_PASSWORD} 2>> error.txt 1>> /dev/null

echo 72


# --- configure synapse to use postgres

sed -i '/^ *database: */{n;/^ *name: */d}' homeserver.yaml 2>> error.txt 1>> /dev/null
sed -i '/^ *database: */{n;/^ *args: */d}' homeserver.yaml 2>> error.txt 1>> /dev/null
sed -i '/^ *database: */{n;/^ *database: */d}' homeserver.yaml 2>> error.txt 1>> /dev/null
sed -i 's/^ *database: */database:\n\n  name: psycopg2\n  txn_limit: 10000\n  args:\n    user: matrix\n    password: '"${DATABASE_PASSWORD}"'\n    database: synapse\n    host: localhost\n    port: 5433\n    cp_min: 5\n    cp_max: 10/' homeserver.yaml 2>> error.txt 1>> /dev/null

echo 83


# --- delete SQLite database? (does it exist yet?)




# --- restart synapse server ---

echo 91

systemctl stop matrix-synapse 2>> error.txt 1>> /dev/null
systemctl start matrix-synapse 2>> error.txt 1>> /dev/null

echo 100

sleep 1





} | whiptail --backtitle "Feta v1.0" --gauge "Setting up Feta" 7 80 0



clear
systemctl status matrix-synapse

echo "

==========================================================================================================

Congrats! Your server is all set up!

visit https://element.${SERVER_DOMAIN} to use your self hosted element client and create a new account

Synapse is running at matrix.${SERVER_DOMAIN}
To connect to your server from a matrix client, you would enter the server as matrix.${SERVER_DOMAIN}

Your server domain is ${SERVER_DOMAIN}

If someone from another server wanted to send a message to a user named foo, they would enter
@foo:${SERVER_DOMAIN}

==========================================================================================================
"
}



pre_install_message() {

if (whiptail --title "Certbot" --yesno "Certbot successfully generated SSL certificates!

Continue to finish setting up Feta.
" 25 90 --yes-button "Continue" --no-button "Shutdown"); then
echo "continue"
begin_installation
else
echo "shutdown"
exit 1
fi

}



certbot_real_failed() {
if (whiptail --title "Certbot" --yesno "Certbot failed for some reason.

This shouldn't happen if the certbot test was successful.
" 25 90 --yes-button "Retry" --no-button "Shutdown"); then
echo "continue"
use_certbot_for_reals
else
echo "shutdown"
exit 1
fi
}



use_certbot_for_reals() {

# REMOVE TEST PARAM FROM THIS!!!
if certbot --nginx -d ${SERVER_DOMAIN} -d element.${SERVER_DOMAIN} -d matrix.${SERVER_DOMAIN} --non-interactive --agree-tos -m ${USER_EMAIL} --test-cert; then
  pre_install_message
else
  certbot_real_failed
fi

}



certbot_test_success() {
if (whiptail --title "Certbot" --yesno "Certbot test was successful!

Next we will generate the actual SSL certifiates with Certbot
" 25 90 --yes-button "Continue" --no-button "Shutdown"); then
echo "continue"
use_certbot_for_reals
else
echo "shutdown"
exit 1
fi
}

certbot_test_failed() {
if (whiptail --title "Certbot" --yesno "Certbot test failed.
" 25 90 --yes-button "Retry" --no-button "Shutdown"); then
echo "continue"
test_certbot
else
echo "shutdown"
exit 1
fi
}



test_certbot() {

if certbot --nginx -d ${SERVER_DOMAIN} -d element.${SERVER_DOMAIN} -d matrix.${SERVER_DOMAIN} --non-interactive --agree-tos -m ${USER_EMAIL} --test-cert; then
  certbot_test_success
else
  certbot_test_failed
fi

}




show_certbot_test_explanation() {


if (whiptail --title "Info" --yesno "Certbot will be used to generate SSL certificates for ${SERVER_DOMAIN}, matrix.${SERVER_DOMAIN}, and element.${SERVER_DOMAIN}

First a test will be performed to make sure that SSL certificates can be properly generated.
" 25 90 --yes-button "Continue" --no-button "Shutdown"); then
echo "continue"
test_certbot
else
echo "shutdown"
exit 1
fi


}



create_nginx_configs() {

  cat 2>> error.txt 1> /etc/nginx/sites-enabled/${SERVER_DOMAIN} <<EOL
server {
  listen 80;
  listen [::]:80;

  server_name ${SERVER_DOMAIN};

  root /var/www/${SERVER_DOMAIN};
  index index.html;

  location / {
    try_files \$uri \$uri/ =404;
  }
}
EOL


cat 2>> error.txt 1> /etc/nginx/sites-enabled/element.${SERVER_DOMAIN} <<EOL
server {
        listen 80;
        listen [::]:80;

        server_name element.${SERVER_DOMAIN};

        root /var/www/element.${SERVER_DOMAIN}/element;
        index index.html;

        location / {
                try_files \$uri \$uri/ =404;
        }
}
EOL


cat 2>> error.txt 1> /etc/nginx/sites-enabled/matrix.${SERVER_DOMAIN} <<EOL
server {
        listen 80;
        listen [::]:80;

        server_name matrix.${SERVER_DOMAIN};

        root /var/www/${SERVER_DOMAIN};
        index index.html;

        location / {
                proxy_pass http://localhost:8008;
        }
}
EOL

show_certbot_test_explanation

}



collect_domain_and_password() {

  while [ -z "$SERVER_DOMAIN" ]; do
    SERVER_DOMAIN=$(whiptail --nocancel --inputbox "Please enter your root domain name:" 20 60 example.com 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      return 0
    elif [ -z "$SERVER_DOMAIN" ]; then
      whiptail --msgbox "Domain name cannot be empty. Please try again." 20 60
    fi
  done


    while [ -z "$USER_EMAIL" ]; do
    USER_EMAIL=$(whiptail --nocancel --inputbox "Please enter your email address (for SSL cert renewal reminders):" 20 60 user@example.com 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
      return 0
    elif [ -z "$USER_EMAIL" ]; then
      whiptail --msgbox "Email address cannot be empty. Please try again." 20 60
    fi
  done

create_nginx_configs

}



domain_record_info_one() {

EXTERNAL_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)

if (whiptail --title "DNS records" --yesno "Your external IP address is:
${EXTERNAL_IP}

DNS A Records should be created for your domain pointing to this IP address for the following hosts:

@
www
matrix
element

Or if you are using the Dynamic DNS feature of your router, CNAME Records should be created for the above hosts and point to the host name that you created through your DDNS provider.
" 25 90 --yes-button "Continue" --no-button "Shutdown"); then
echo "continue"
collect_domain_and_password
else
echo "shutdown"
exit 1
fi

}



port_forwarding() {

INTERNAL_IP=$(hostname -I)

if (whiptail --title "Port forwarding" --yesno "The internal IP address of your PI is:
${INTERNAL_IP}

In your router settings, please forward the following ports before continuing:

TCP:
80, 443, 8448

To make voice and video calls work, you'll also need to forward these ports:

BOTH TCP and UDP:
3478, 3479, 5349

UDP:
64000 to 65535
" 25 90 --yes-button "Continue" --no-button "Shutdown"); then
echo "continue"
domain_record_info_one
else
echo "shutdown"
exit 1
fi

}



nat_info() {
if (whiptail --title "NAT info" --yesno "Attention!

If your ISP has put you behind a NAT, then your router is not directly accessible from the internet and you will be unable to host a server. If you do a web search for 'my ip' and the value is the same as what shows up as your WAN IP in your router settings, then you are not behind a NAT.

If the values are different, you probably are behind a NAT and will have to contact your ISP to get a public IP address.
" 25 90 --yes-button "Continue" --no-button "Shutdown"); then
echo "continue"
port_forwarding
else
echo "shutdown"
exit 1
fi
}



has_internet() {
whiptail --msgbox "ping google.com success!

We have an internet connection." 25 80

nat_info
}

no_internet() {
if (whiptail --title "Check internet connectivity" --yesno "ping google.com failed

We don't seem to have an internet connection.
" 25 90 --yes-button "Retry" --no-button "Shutdown"); then
if ping -q -c 1 -W 1 google.com >/dev/null; then
  has_internet
else
  no_internet
fi
else
echo "shutdown"
exit 1
fi
}




# ---------------- BEGIN ---------------------



if (whiptail --yesno "Welcome to Feta.

Please make sure an ethernet cable from your router is connected to your Pi.
" 25 90 --yes-button "Continue" --no-button "Shutdown"); then
echo "continue"
else
echo "shutdown"
exit 1
fi



if (whiptail --title "IP settings" --yesno "For initial set up, allow your router to assign an IP address to the PI via DHCP.
This should happen automatically if DHCP is enabled.

Or, manually assign it an IP now in your router settings.

If you don't know what this means, select Continue
" 25 90 --yes-button "Continue" --no-button "Shutdown"); then
echo "continue"
else
echo "shutdown"
exit 1
fi



if (whiptail --title "Check internet connectivity" --yesno "Now let's check if your Pi is connected to the internet
" 25 90 --yes-button "Continue" --no-button "Shutdown" 3>&1 1>&2 2>&3); then

if ping -q -c 1 -W 1 google.com >/dev/null; then
  has_internet
else
  no_internet
fi

else
echo "shutdown"
exit 1
fi
