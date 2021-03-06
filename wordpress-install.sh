#!/bin/bash
#
# [Automatic installation on Linux for WordPress]
#
# GitHub : https://github.com/MaximeMichaud/wordpress-install
# URL : https://wordpress.org
#
# This script is intended for a quick and easy installation :
# curl -O https://raw.githubusercontent.com/MaximeMichaud/wordpress-install/master/wordpress-install.sh
# chmod +x wordpress-install.sh
# ./wordpress-install.sh
#
# wordpress-install Copyright (c) 2020-2021 Maxime Michaud
# Licensed under MIT License
#
#   Permission is hereby granted, free of charge, to any person obtaining a copy
#   of this software and associated documentation files (the "Software"), to deal
#   in the Software without restriction, including without limitation the rights
#   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#   copies of the Software, and to permit persons to whom the Software is
#   furnished to do so, subject to the following conditions:
#
#   The above copyright notice and this permission notice shall be included in all
#   copies or substantial portions of the Software.
#
#################################################################################
#Colors
black=$(tput setaf 0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
cyan=$(tput setaf 6)
white=$(tput setaf 7)
bold=$(tput bold)
standout=$(tput smso)
normal=$(tput sgr0)
alert=${white}${on_red}
sub_title=${bold}${yellow}
repo_title=${black}${on_green}
message_title=${white}${on_magenta}
#################################################################################
function isRoot() {
  if [ "$EUID" -ne 0 ]; then
    return 1
  fi
}

function initialCheck() {
  if ! isRoot; then
    echo "Sorry, you need to run this as root"
    exit 1
  fi
  checkOS
}

function checkOS() {
  if [[ -e /etc/debian_version ]]; then
    OS="debian"
    source /etc/os-release

    if [[ "$ID" == "debian" || "$ID" == "raspbian" ]]; then
      if [[ ! $VERSION_ID =~ (9|10|11) ]]; then
        echo "⚠️ ${alert}Your version of Debian is not supported.${normal}"
        echo ""
        echo "However, if you're using Debian >= 9 or unstable/testing then you can continue."
        echo "Keep in mind they are not supported, though.${normal}"
        echo ""
        until [[ $CONTINUE =~ (y|n) ]]; do
          read -rp "Continue? [y/n] : " -e CONTINUE
        done
        if [[ "$CONTINUE" == "n" ]]; then
          exit 1
        fi
      fi
    elif [[ "$ID" == "ubuntu" ]]; then
      OS="ubuntu"
      if [[ ! $VERSION_ID =~ (16.04|18.04|20.04) ]]; then
        echo "⚠️ ${alert}Your version of Ubuntu is not supported.${normal}"
        echo ""
        echo "However, if you're using Ubuntu > 17 or beta, then you can continue."
        echo "Keep in mind they are not supported, though.${normal}"
        echo ""
        until [[ $CONTINUE =~ (y|n) ]]; do
          read -rp "Continue? [y/n]: " -e CONTINUE
        done
        if [[ "$CONTINUE" == "n" ]]; then
          exit 1
        fi
      fi
    fi
  elif [[ -e /etc/fedora-release ]]; then
    OS=fedora
  elif [[ -e /etc/centos-release ]]; then
    if ! grep -qs "^CentOS Linux release 7" /etc/centos-release; then
      echo "${alert}Your version of CentOS is not supported.${normal}"
      echo "${red}Keep in mind they are not supported, though.${normal}"
      echo ""
      unset CONTINUE
      until [[ $CONTINUE =~ (y|n) ]]; do
        read -rp "Continue? [y/n] : " -e CONTINUE
      done
      if [[ "$CONTINUE" == "n" ]]; then
        exit 1
      fi
    fi
  else
    echo "Looks like you aren't running this script on a Debian, Ubuntu, Fedora or CentOS system ${normal}"
    exit 1
  fi
}

function script() {
  installQuestions
  aptupdate
  aptinstall
  aptinstall_apache2
  aptinstall_$database
  aptinstall_php
  aptinstall_phpmyadmin
  install_composer
  install_wp-cli
  install_wordpress
  setupdone

}
function installQuestions() {
  echo "${cyan}Welcome to wordpress-install !"
  echo "https://github.com/MaximeMichaud/wordpress-install"
  echo "I need to ask some questions before starting the configuration."
  echo "You can leave the default options and just press Enter if that's right for you."
  echo ""
  echo "${cyan}Which Version of PHP ?"
  echo "${red}Red = End of life ${yellow}| Yellow = Security fixes only ${green}| Green = Active support"
  echo "${yellow}   1) PHP 7.3 "
  echo "   2) PHP 7.4 (recommended) ${normal}"
  echo "${red}   3) PHP 8 (not recommended yet) ${normal}${cyan}"
  until [[ "$PHP_VERSION" =~ ^[1-3]$ ]]; do
    read -rp "Version [1-3]: " -e -i 2 PHP_VERSION
  done
  case $PHP_VERSION in
  1)
    PHP="7.3"
    ;;
  2)
    PHP="7.4"
    ;;
  3)
    PHP="8.0"
    ;;
  esac
  echo "Which type of database ?"
  echo "   1) MySQL"
  echo "   2) MariaDB"
  echo "   3) SQLite"
  until [[ "$DATABASE" =~ ^[1-3]$ ]]; do
    read -rp "Version [1-3]: " -e -i 1 DATABASE
  done
  case $DATABASE in
  1)
    database="mysql"
    ;;
  2)
    database="mariadb"
    ;;
  3)
    database="sqlite"
    ;;
  esac
  if [[ "$database" =~ (mysql) ]]; then
  echo "Which version of MySQL ?"
  echo "   1) MySQL 5.7"
  echo "   2) MySQL 8.0"
  until [[ "$DATABASE_VER" =~ ^[1-2]$ ]]; do
    read -rp "Version [1-2]: " -e -i 2 DATABASE_VER
  done
  case $DATABASE_VER in
  1)
    database_ver="5.7"
    ;;
  2)
    database_ver="8.0"
    ;;
  esac
  fi
  if [[ "$database" =~ (mariadb) ]]; then
  echo "Which version of MySQL ?"
  echo "${yellow}   1) MariaDB 10.3 (Old Stable)${normal}"
  echo "${yellow}   2) MariaDB 10.4 (Old Stable)${normal}"
  echo "${green}   3) MariaDB 10.5 (Stable)${normal}"
  until [[ "$DATABASE_VER" =~ ^[1-3]$ ]]; do
    read -rp "Version [1-3]: " -e -i 3 DATABASE_VER
  done
  case $DATABASE_VER in
  1)
    database_ver="10.3"
    ;;
  2)
    database_ver="10.4"
    ;;
  3)
    database_ver="10.5"
    ;;
  esac
  fi
  echo ""
  echo "We are ready to start the installation !"
  APPROVE_INSTALL=${APPROVE_INSTALL:-n}
  if [[ $APPROVE_INSTALL =~ n ]]; then
    read -n1 -r -p "Press any key to continue..."
  fi
}

function aptupdate() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
  apt-get update
  fi
}
function aptinstall() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
  apt-get -y install ca-certificates apt-transport-https dirmngr zip unzip lsb-release gnupg openssl curl
  fi
}

function aptinstall_apache2() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
  apt-get install -y apache2
  a2enmod rewrite
  wget -O /etc/apache2/sites-available/000-default.conf https://raw.githubusercontent.com/MaximeMichaud/wordpress-install/master/conf/000-default.conf
  service apache2 restart
  fi
}

function aptinstall_mariadb() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    echo "MariaDB Installation"
    apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
    if [[ "$VERSION_ID" =~ (9|10|16.04|18.04|20.04) ]]; then
      echo "deb [arch=amd64] https://ftp.igh.cnrs.fr/pub/mariadb/repo/$database_ver/$ID $(lsb_release -sc) main" >/etc/apt/sources.list.d/mariadb.list
      apt-get update && apt-get install mariadb-server -y
      systemctl enable mariadb && systemctl start mariadb
    fi
	if [[ "$VERSION_ID" == "11" ]]; then
      echo "deb [arch=amd64] https://ftp.igh.cnrs.fr/pub/mariadb/repo/$database_ver/debian buster main" >/etc/apt/sources.list.d/mariadb.list
      apt-get update && apt-get install mariadb-server -y
      systemctl enable mariadb && systemctl start mariadb
    fi
  fi
}

function aptinstall_mysql() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    echo "MYSQL Installation"
    if [[ "$database_ver" == "8.0" ]]; then
	  wget https://raw.githubusercontent.com/MaximeMichaud/wordpress-install/master/conf/default-auth-override.cnf -P /etc/mysql/mysql.conf.d
    fi
    if [[ "$VERSION_ID" =~ (9|10|16.04|18.04|20.04) ]]; then
      echo "deb http://repo.mysql.com/apt/$ID/ $(lsb_release -sc) mysql-$database_ver" >/etc/apt/sources.list.d/mysql.list
      echo "deb-src http://repo.mysql.com/apt/$ID/ $(lsb_release -sc) mysql-$database_ver" >>/etc/apt/sources.list.d/mysql.list
      apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5
      apt-get update && apt-get install mysql-server mysql-client -y
      systemctl enable mysql && systemctl start mysql
    fi
	if [[ "$VERSION_ID" == "11" ]]; then
      echo "deb http://repo.mysql.com/apt/debian/ buster mysql-$database_ver" >/etc/apt/sources.list.d/mysql.list
      echo "deb-src http://repo.mysql.com/apt/debian/ buster mysql-$database_ver" >>/etc/apt/sources.list.d/mysql.list
      apt-key adv --keyserver keys.gnupg.net --recv-keys 8C718D3B5072E1F5
      apt-get update && apt-get install mysql-server mysql-client -y
      systemctl enable mysql && systemctl start mysql
    fi
  fi
}

function aptinstall_php() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    echo "PHP Installation"
    curl -sSL -o /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
    if [[ "$VERSION_ID" =~ (9|10) ]]; then
      echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list
      apt-get update && apt-get install php$PHP{,-bcmath,-mbstring,-common,-xml,-curl,-gd,-zip,-mysql,-imagick} -y
      sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/apache2/php.ini
      sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/apache2/php.ini
	  sed -i 's|memory_limit = 128M|memory_limit = 256M|' /etc/php/$PHP/fpm/php.ini
      systemctl restart apache2
    fi
	if [[ "$VERSION_ID" == "11" ]]; then
      echo "deb https://packages.sury.org/php/ buster main" | tee /etc/apt/sources.list.d/php.list
      apt-get update && apt-get install php$PHP{,-bcmath,-mbstring,-common,-xml,-curl,-gd,-zip,-mysql,-imagick} -y
      sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/apache2/php.ini
      sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/apache2/php.ini
	  sed -i 's|memory_limit = 128M|memory_limit = 256M|' /etc/php/$PHP/fpm/php.ini
      systemctl restart apache2
    fi
    if [[ "$VERSION_ID" =~ (16.04|18.04|20.04) ]]; then
      add-apt-repository -y ppa:ondrej/php
      apt-get update && apt-get install php$PHP{,-bcmath,-mbstring,-common,-xml,-curl,-gd,-zip,-mysql,-imagick} -y
      sed -i 's|upload_max_filesize = 2M|upload_max_filesize = 50M|' /etc/php/$PHP/apache2/php.ini
      sed -i 's|post_max_size = 8M|post_max_size = 50M|' /etc/php/$PHP/apache2/php.ini
	  sed -i 's|memory_limit = 128M|memory_limit = 256M|' /etc/php/$PHP/fpm/php.ini
      systemctl restart apache2
    fi
  fi
}

function aptinstall_phpmyadmin() {
  echo "phpMyAdmin Installation"
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
    PHPMYADMIN_VER=$(curl -s "https://api.github.com/repos/phpmyadmin/phpmyadmin/releases/latest" | grep -m1 '^[[:blank:]]*"name":' | cut -d \" -f 4)
    mkdir /usr/share/phpmyadmin/ || exit
	wget https://files.phpmyadmin.net/phpMyAdmin/$PHPMYADMIN_VER/phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz -O /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz
    tar xzf /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz --strip-components=1 --directory /usr/share/phpmyadmin
    rm -f /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMIN_VER-all-languages
    # Create phpMyAdmin TempDir
    mkdir /usr/share/phpmyadmin/tmp || exit
    chown www-data:www-data /usr/share/phpmyadmin/tmp
    chmod 700 /usr/share/phpmyadmin/tmp
    randomBlowfishSecret=$(openssl rand -base64 32)
    sed -e "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$randomBlowfishSecret'|" /usr/share/phpmyadmin/config.sample.inc.php >/usr/share/phpmyadmin/config.inc.php
    wget https://raw.githubusercontent.com/MaximeMichaud/wordpress-install/master/conf/phpmyadmin.conf
    ln -s /usr/share/phpmyadmin /var/www/phpmyadmin
    mv phpmyadmin.conf /etc/apache2/sites-available/
    a2ensite phpmyadmin
    systemctl restart apache2
  elif [[ "$OS" =~ (centos|amzn) ]]; then
    echo "No Support"
  elif [[ "$OS" == "fedora" ]]; then
    echo "No Support"
  fi
}

function install_wordpress() {
  rm -rf /var/www/html/
  mkdir /var/www/html
  cd /var/www/html || exit
  wget -O latest.zip https://wordpress.org/latest.zip
  unzip latest.zip
  rm -rf latest.zip
  mv /var/www/html/wordpress/* /var/www/html
  chmod -R 755 /var/www/html
  chown -R www-data:www-data /var/www/html
}

function install_composer() {
  curl -sS https://getcomposer.org/installer | php
  mv composer.phar /usr/local/bin/composer
  chmod +x /usr/local/bin/composer
}

function install_wp-cli() {
  cd /opt || exit
  curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x wp-cli.phar
  mv wp-cli.phar /usr/local/bin/wp
}

function mod_cloudflare() {
  #disabled for the moment
  a2enmod remoteip
  cd /etc/apache2 || exit
  wget https://raw.githubusercontent.com/MaximeMichaud/wordpress-install/master/conf/cloudflare/apache2.conf
  wget https://raw.githubusercontent.com/MaximeMichaud/wordpress-install/master/conf/cloudflare/000-default.conf
  cd /etc/apache2/conf-available || exit
  wget https://raw.githubusercontent.com/MaximeMichaud/wordpress-install/master/conf/cloudflare/remoteip.conf
  systemctl restart apache2
}

function autoUpdate() {
  if [[ "$OS" =~ (debian|ubuntu) ]]; then
  echo "Enable Automatic Updates..."
  apt-get install -y unattended-upgrades
  fi
}

function setupdone() {
  IP=$(curl 'https://api.ipify.org')
  echo "It done!"
  echo "Configuration Database/User: http://$IP"
  echo "phpMyAdmin: http://$IP/phpmyadmin"
  echo "For the moment, If you choose to use MariaDB, you will need to execute ${cyan}mysql_secure_installation${normal} for setting the password"
}
function manageMenu() {
  clear
  echo "Welcome to wordpress-install !"
  echo "https://github.com/MaximeMichaud/wordpress-install"
  echo ""
  echo "It seems that the Script has already been used in the past."
  echo ""
  echo "What do you want to do ?"
  echo "   1) Restart the installation"
  echo "   2) Update phpMyAdmin"
  echo "   3) Add certs (https)"
  echo "   4) Update the Script"
  echo "   5) Quit"
  until [[ "$MENU_OPTION" =~ ^[1-5]$ ]]; do
    read -rp "Select an option [1-5] : " MENU_OPTION
  done
  case $MENU_OPTION in
  1)
    install_wordpress
    ;;
  2)
    updatephpMyAdmin
    ;;
  3)
    install_letsencrypt
    ;;
  4)
    update
    ;;
  5)
    exit 0
    ;;
  esac
}

function update() {
  wget https://raw.githubusercontent.com/MaximeMichaud/wordpress-install/master/wordpress-install.sh -O wordpress-install.sh
  chmod +x wordpress-install.sh
  echo ""
  echo "Update Done."
  sleep 2
  ./wordpress-install.sh
  exit
}

function updatephpMyAdmin() {
  rm -rf /usr/share/phpmyadmin/*
  cd /usr/share/phpmyadmin/ || exit
  wget https://files.phpmyadmin.net/phpMyAdmin/$PHPMYADMIN_VER/phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz -O /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz
  tar xzf /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMIN_VER-all-languages.tar.gz --strip-components=1 --directory /usr/share/phpmyadmin
  rm -f /usr/share/phpmyadmin/phpMyAdmin-$PHPMYADMIN_VER-all-languages
  PHPMYADMIN_VER=$(curl -s "https://api.github.com/repos/phpmyadmin/phpmyadmin/releases/latest" | grep -m1 '^[[:blank:]]*"name":' | cut -d \" -f 4)
  mv phpMyAdmin-$PHPMYADMIN_VER-all-languages/* /usr/share/phpmyadmin
  rm /usr/share/phpmyadmin/phpMyAdmin-latest-all-languages.tar
  # Create TempDir
  mkdir /usr/share/phpmyadmin/tmp || exit
  chown www-data:www-data /usr/share/phpmyadmin/tmp
  chmod 700 /var/www/phpmyadmin/tmp
  randomBlowfishSecret=$(openssl rand -base64 32)
  sed -e "s|cfg\['blowfish_secret'\] = ''|cfg['blowfish_secret'] = '$randomBlowfishSecret'|" /usr/share/phpmyadmin/config.sample.inc.php >/usr/share/phpmyadmin/config.inc.php
}

initialCheck

if [[ -e /var/www/html/app/ ]]; then
  manageMenu
else
  script
fi