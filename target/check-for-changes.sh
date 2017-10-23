#! /bin/bash

# create date for log output
log_date=$(date +"%Y-%m-%d %H:%M:%S ")
# Prevent a start too early
sleep 5
echo "${log_date} Start check-for-changes script."

# change directory
cd /tmp/docker-mailserver

# Check postfix-accounts.cf exist else break
if [ ! -f postfix-accounts.cf ]; then
   echo "${log_date} postfix-accounts.cf is missing! This should not run! Exit!"
   exit
fi 

# Update / generate after start
echo "${log_date} Makeing new checksum file."
if [ -f postfix-virtual.cf ]; then
	sha512sum --tag postfix-accounts.cf --tag postfix-virtual.cf > chksum
else
	sha512sum --tag postfix-accounts.cf > chksum
fi
# Run forever
while true; do

# recreate logdate
log_date=$(date +"%Y-%m-%d %H:%M:%S ")

# Get chksum and check it.
chksum=$(sha512sum -c --ignore-missing chksum)
resu_acc=${chksum:21:2}
if [ -f postfix-virtual.cf ]; then
	resu_vir=${chksum:44:2}
else
	resu_vir="OK"
fi

if ! [ $resu_acc = "OK" ] || ! [ $resu_vir = "OK" ]; then
   echo "${log_date} Change detected"
    #regen postfix accounts.
	echo -n > /etc/postfix/vmailbox
	echo -n > /etc/dovecot/userdb
	if [ -f /tmp/docker-mailserver/postfix-accounts.cf -a "$ENABLE_LDAP" != 1 ]; then
		sed -i 's/\r//g' /tmp/docker-mailserver/postfix-accounts.cf
		echo "# WARNING: this file is auto-generated. Modify config/postfix-accounts.cf to edit user list." > /etc/postfix/vmailbox
		# Checking that /tmp/docker-mailserver/postfix-accounts.cf ends with a newline
		sed -i -e '$a\' /tmp/docker-mailserver/postfix-accounts.cf
		chown dovecot:dovecot /etc/dovecot/userdb
		chmod 640 /etc/dovecot/userdb
		sed -i -e '/\!include auth-ldap\.conf\.ext/s/^/#/' /etc/dovecot/conf.d/10-auth.conf
		sed -i -e '/\!include auth-passwdfile\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf
		# Creating users
		# 'pass' is encrypted
		# comments and empty lines are ignored
		grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-accounts.cf | while IFS=$'|' read login pass
		do
			# Setting variables for better readability
			user=$(echo ${login} | cut -d @ -f1)
			domain=$(echo ${login} | cut -d @ -f2)
			# Let's go!
			echo "${login} ${domain}/${user}/" >> /etc/postfix/vmailbox
			# User database for dovecot has the following format:
			# user:password:uid:gid:(gecos):home:(shell):extra_fields
			# Example :
			# ${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::userdb_mail=maildir:/var/mail/${domain}/${user}
			echo "${login}:${pass}:5000:5000::/var/mail/${domain}/${user}::" >> /etc/dovecot/userdb
			mkdir -p /var/mail/${domain}
			if [ ! -d "/var/mail/${domain}/${user}" ]; then
				maildirmake.dovecot "/var/mail/${domain}/${user}"
				maildirmake.dovecot "/var/mail/${domain}/${user}/.Sent"
				maildirmake.dovecot "/var/mail/${domain}/${user}/.Trash"
				maildirmake.dovecot "/var/mail/${domain}/${user}/.Drafts"
				echo -e "INBOX\nSent\nTrash\nDrafts" >> "/var/mail/${domain}/${user}/subscriptions"
				touch "/var/mail/${domain}/${user}/.Sent/maildirfolder"
			fi
			# Copy user provided sieve file, if present
			test -e /tmp/docker-mailserver/${login}.dovecot.sieve && cp /tmp/docker-mailserver/${login}.dovecot.sieve /var/mail/${domain}/${user}/.dovecot.sieve
			echo ${domain} >> /tmp/vhost.tmp
		done
	fi
	if [ -f postfix-virtual.cf ]; then
    # regen postfix aliases
    echo -n > /etc/postfix/virtual
	echo -n > /etc/postfix/regexp
	if [ -f /tmp/docker-mailserver/postfix-virtual.cf ]; then
		# Copying virtual file
		cp -f /tmp/docker-mailserver/postfix-virtual.cf /etc/postfix/virtual
		while read from to
		do
			# Setting variables for better readability
			uname=$(echo ${from} | cut -d @ -f1)
			domain=$(echo ${from} | cut -d @ -f2)
			# if they are equal it means the line looks like: "user1     other@domain.tld"
			test "$uname" != "$domain" && echo ${domain} >> /tmp/vhost.tmp
		done < /tmp/docker-mailserver/postfix-virtual.cf
	fi
	if [ -f /tmp/docker-mailserver/postfix-regexp.cf ]; then
		# Copying regexp alias file
		cp -f /tmp/docker-mailserver/postfix-regexp.cf /etc/postfix/regexp
		sed -i -e '/^virtual_alias_maps/{
		s/ regexp:.*//
		s/$/ regexp:\/etc\/postfix\/regexp/
		}' /etc/postfix/main.cf
	fi
	fi
    # Set vhost 
	if [ -f /tmp/vhost.tmp ]; then
		cat /tmp/vhost.tmp | sort | uniq > /etc/postfix/vhost && rm /tmp/vhost.tmp
	fi
    
    # Set right new if needed
	if [ `find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | grep -c .` != 0 ]; then
		chown -R 5000:5000 /var/mail
	fi
    
    # Restart of the postfix
    supervisorctl restart postfix
    
    # Prevent restart of dovecot when smtp_only=1
    if [ ! -f $SMTP_ONLY = 1 ]; then
        supervisorctl restart dovecot
    fi 

    echo "${log_date} Update checksum"
	if [ -f postfix-virtual.cf ]; then
    sha512sum --tag postfix-accounts.cf --tag postfix-virtual.cf > chksum
	else
	sha512sum --tag postfix-accounts.cf > chksum
	fi
fi

sleep 1
done
