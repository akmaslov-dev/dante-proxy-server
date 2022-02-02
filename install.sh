#!/usr/bin/env bash

# Author - akmaslov-dev
# Copyright (c) 2017 akmaslov-dev. MIT License
# Simple script to setup dante socks proxy server
# Should work on Debian, Ubuntu and CentOS


# Check for bash shell
if readlink /proc/$$/exe | grep -qs "dash"; then
	echo "This script needs to be run with bash, not sh"
	exit 1
fi
# Checking for root permission
if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, but you need to run this script as root"
	exit 2
fi
# Checking for distro type (Debian, Ubuntu or CentOS)
if [[ -e /etc/debian_version ]]; then
	OStype=deb
elif [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
	OStype=centos
else
	echo "You should only run this installer on Debian, Ubuntu or CentOS"
	exit 3
fi
# Checking for previous installation with this script
# Also some useful options here
if [[ -e /etc/sockd.conf ]]; then
    while :
	do
	clear
		echo "You are already installed Dante socks proxy"
		echo " "
		echo "What do you want to do now?"
		echo "	1) Add new user for proxy"
		echo "	2) Remove an existing user"
		echo "	3) Completely remove Dante socks proxy server"
		echo "	4) Exit"
		read -p "Select an option [1-4]: " option
		case $option in
			1)
			# Creating new user for proxy
			echo " "
			# Getting new Login
			read -p "Please enter the name for new proxy user: " -e -i proxyuser user
			echo " "
			# Getting new password for new user
			while true; do
				read -s -p "Now we need a VERY, VERY STRONG PASSWORD for new proxy user: " password
				echo " "
				read -s -p "Please retype your password (again): " password2
				echo " "
				[ "$password" = "$password2" ] && break
				echo "Password and password confirmation does not match"
				echo " "
				echo "Please try again"
				echo " "
			done
			# Creating new proxy user
			useradd -M -s /usr/sbin/nologin -p "$(openssl passwd -1 "$password")" "$user"
			echo " "
			echo "New user added!"
			exit
			;;
			2)
			# Deleting an existing user
			read -p "please enter the name for user which should be deleted: " deluser
			echo " "
			if getent passwd "$deluser" > /dev/null 2>&1; then
			    userdel "$deluser"
			    echo "User " "$deluser" "deleted!"
			else
			    echo "We cant find user with this name, sorry!"
			fi
			exit
			;;
			3)
			echo " "
			read -p "Do you really want to remove Dante socks proxy server? [y/n]: " -e -i n REMOVE
			if [[ "$REMOVE" = 'y' ]]; then
				if [[ "$OStype" = 'deb' ]]; then
					# If deb based distro
					/etc/init.d/sockd stop
					update-rc.d -f sockd remove
					rm -f /etc/init.d/sockd
					rm -f /etc/sockd.conf
					rm -f /usr/sbin/sockd
					echo " "
					echo "Dante socks proxy server deleted!"
				else
					# If CentOS
					service sockd stop
					systemctl disable sockd
					rm -f /etc/systemd/system/sockd.service
					rm -f /usr/sbin/sockd
					rm -f /etc/sockd.conf
					systemctl daemon-reload
					systemctl reset-failed
					# Checking for firewalld
					if pgrep firewalld; then
						delport="$(grep 'port =' /etc/sockd.conf | awk '{print $5}')"
						firewall-cmd --zone=public --remove-port="$delport"/tcp
						firewall-cmd --zone=public --remove-port="$delport"/udp
						firewall-cmd --runtime-to-permanent
						firewall-cmd --reload
					fi
					echo " "
					echo "Dante socks proxy server deleted!"
				fi
			else
				echo " "
				echo " Removal process aborted!"
			fi
			exit
			;;
			4)
			# Just exit this script
			exit;;
		esac
	done
else
	clear
	# Obtaining name for system lan interface
	interface="$(ip -o -4 route show to default | awk '{print $5}')"
	# Getting default port for socks proxy service
	read -p "Please enter the port number for our proxy server:  " -e -i 1080 port
	echo " "
	# Getting new Login and Password for proxy user
	read -p "Please enter the name for new proxy user: " -e -i proxyuser user
	echo " "
	# Password section for new proxy user
	while true; do
		read -s -p "Now we need a VERY, VERY STRONG PASSWORD for new proxy user: " password
		echo " "
		read -s -p "Please retype your password (again): " password2
		echo " "
		[ "$password" = "$password2" ] && break
		echo "Password and password confirmation does not match"
		echo " "
		echo "Please try again"
		echo " "
	done
	# Installing minimal requirements
	if [[ "$OStype" = 'deb' ]]; then
		# If deb based distro
		apt-get update
		apt-get -y install openssl make gcc
	else
		# Else, the distro is CentOS
		yum -y install epel-release
		yum -y install openssl make gcc
	fi
fi
# Getting dante 1.4.3
wget https://www.inet.no/dante/files/dante-1.4.3.tar.gz
# Unpacking
tar xvfz dante-1.4.3.tar.gz && cd dante-1.4.3 || exit 4
# Configuring dante packets
./configure \
--prefix=/usr \
--sysconfdir=/etc \
--localstatedir=/var \
--disable-client \
--without-libwrap \
--without-bsdauth \
--without-gssapi \
--without-krb5 \
--without-upnp \
--without-pam
# Compiling dante socks proxy server
make && make install
# Creating new proxy user
useradd -M -s /usr/sbin/nologin -p "$(openssl passwd -1 "$password")" "$user"
# /etc/sockd.conf
# Creating dante socks proxy server config file
cat > /etc/sockd.conf <<-'EOF'
# listen interface or ip and port
# Protocol type placeholder
#internal.protocol: ipv4 ipv6
internal: {interface_name} port = {port_number}
# external interface
# Protocol type placeholder
#external.protocol: ipv4 ipv6
external: {interface_name}
# auth strings
user.privileged: root
user.unprivileged: nobody
# auth metod
socksmethod: username
# log path
logoutput: /var/log/sockd.log
# allow everyone from everywhere so long as they auth, log errors
client pass {
	from: 0.0.0.0/0 to: 0.0.0.0/0
	log: error # connect disconnect iooperation
	socksmethod: username
}
# allow everyone from everywhere so long as they auth, log errors
socks pass {
	from: 0.0.0.0/0 to: 0.0.0.0/0
	command: bind connect udpassociate
	log: error # connect disconnect iooperation
	socksmethod: username
}
# pass statement for incoming connections/packets
socks pass {
	from: 0.0.0.0/0 to: 0.0.0.0/0
	command: bindreply udpreply
	log: error # connect disconnect iooperation
}
EOF
# Updating sockd.conf with proper port and lan intarface name
sed -i "s/internal: {interface_name} port = {port_number}/internal: $interface port = $port/g" /etc/sockd.conf
sed -i "s/external: {interface_name}/external: $interface/g" /etc/sockd.conf
# Creating services
if [[ "$OStype" = 'deb' ]]; then
	# If deb based distro
	# Creating sockd daemon
	cat > /etc/init.d/sockd <<-'EOF'
	#!/usr/bin/env bash
	### BEGIN INIT INFO
	# Provides:          sockd
	# Required-Start:    $remote_fs $syslog
	# Required-Stop:     $remote_fs $syslog
	# Default-Start:     2 3 4 5
	# Default-Stop:      0 1 6
	# Short-Description: Start the dante SOCKS server.
	# Description:       SOCKS (v4 and v5) proxy server daemon (sockd).
	#                    This server allows clients to connect to it and
	#                    request proxying of TCP or UDP network traffic
	#                    with extensive configuration possibilities.
	### END INIT INFO
	#
	# dante SOCKS server init.d file. Based on /etc/init.d/skeleton:
	# Version:  @(#)skeleton  1.8  03-Mar-1998  miquels@cistron.nl
	# Via: https://gitorious.org/dante/pkg-debian

	sleep 5
	PATH=/sbin:/usr/sbin:/bin:/usr/bin
	NAME=sockd
	DAEMON=/usr/sbin/$NAME
	DAEMON_ARGS="-D"
	PIDFILE=/var/run/$NAME.pid
	SCRIPTNAME=/etc/init.d/$NAME
	DESC="Dante SOCKS daemon"
	CONFFILE=/etc/$NAME.conf

	# Exit if the package is not installed
	[ -x "$DAEMON" ] || exit 0

	# Load the VERBOSE setting and other rcS variables
	. /lib/init/vars.sh

	# Define LSB log_* functions.
	# Depend on lsb-base (>= 3.2-14) to ensure that this file is present
	# and status_of_proc is working.
	. /lib/lsb/init-functions

	set -e

	# This function makes sure that the Dante server can write to the pid-file.
	touch_pidfile ()
	{
	  if [ -r $CONFFILE ]; then
	    uid="`sed -n -e 's/[[:space:]]//g' -e 's/#.*//' -e '/^user\.privileged/{s/[^:]*://p;q;}' $CONFFILE`"
	    if [ -n "$uid" ]; then
	      touch $PIDFILE
	      chown $uid $PIDFILE
	    fi
	  fi
	}

	case "$1" in
	  start)
	    if ! egrep -cve '^ *(#|$)' \
	        -e '^(logoutput|user\.((not)?privileged|libwrap)):' \
	        $CONFFILE > /dev/null
	    then
	        echo "Not starting $DESC: not configured."
	        exit 0
	    fi
	    echo -n "Starting $DESC: "
	    touch_pidfile
	    start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON --test > /dev/null \
	        || return 1
	    start-stop-daemon --start --quiet --pidfile $PIDFILE --exec $DAEMON -- \
	        $DAEMON_ARGS \
	        || return 2
	    echo "$NAME."
	    ;;
	  stop)
	    echo -n "Stopping $DESC: "
	    start-stop-daemon --stop --quiet --retry=TERM/30/KILL/5 --pidfile $PIDFILE --name $NAME
	    RETVAL="$?"
	    [ "$RETVAL" = 2 ] && return 2
	    start-stop-daemon --stop --quiet --oknodo --retry=0/30/KILL/5 --exec $DAEMON
	    [ "$?" = 2 ] && return 2
	    echo "$NAME."
	    ;;
	  reload|force-reload)
	    #
	    #   If the daemon can reload its config files on the fly
	    #   for example by sending it SIGHUP, do it here.
	    #
	    #   Make this a do-nothing entry, if the daemon responds to changes in its config file
	    #   directly anyway.
	    #
	     echo "Reloading $DESC configuration files."
	     start-stop-daemon --stop --signal 1 --quiet --pidfile \
	        $PIDFILE --exec $DAEMON -- -D
	  ;;
	  restart)
	    #
	    #   If the "reload" option is implemented, move the "force-reload"
	    #   option to the "reload" entry above. If not, "force-reload" is
	    #   just the same as "restart".
	    #
	    echo -n "Restarting $DESC: "
	    start-stop-daemon --stop --quiet --pidfile $PIDFILE --exec $DAEMON
	    sleep 1
	    touch_pidfile
	    start-stop-daemon --start --quiet --pidfile $PIDFILE \
	      --exec $DAEMON -- -D
	    echo "$NAME."
	    ;;
	  status)
	    status_of_proc "$DAEMON" "$NAME" && exit 0 || exit $?
	    ;;
	  *)
	    N=/etc/init.d/$NAME
	    # echo "Usage: $N {start|stop|restart|reload|force-reload}" >&2
	    echo "Usage: $N {start|stop|restart|status|force-reload}" >&2
	    exit 1
	    ;;
	esac

	exit 0
	EOF
	# Making sockd service executable
	chmod +x /etc/init.d/sockd
	# Updating rc.d
	update-rc.d sockd defaults
	# Enabling autostart for sockd daemon
	update-rc.d sockd enable
	# Starting sockd daemon
	/etc/init.d/sockd start
else
	# Else, the distro is CentOS
	# Creating systemctl service
	cat > /etc/systemd/system/sockd.service <<-'EOF'
	[Unit]
	Description=Dante Socks Proxy v1.4.3
	After=network.target

	[Service]
	Type=forking
	PIDFile=/var/run/sockd.pid
	ExecStart=/usr/sbin/sockd -D -f /etc/sockd.conf
	ExecReload=/bin/kill -HUP ${MAINPID}
	KillMode=process
	Restart=on-failure

	[Install]
	WantedBy=multi-user.target graphical.target
	EOF
	# Restarting systemctl daemon
	systemctl daemon-reload
	# Enabling autostart for sockd service
	systemctl enable sockd
	# Adding exeptions for firewalld
	if pgrep firewalld; then
		firewall-cmd --zone=public --add-port="$port"/tcp
		firewall-cmd --zone=public --add-port="$port"/udp
		firewall-cmd --runtime-to-permanent
		firewall-cmd --reload
	fi
	# Starting service
	service sockd start
fi
