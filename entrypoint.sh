#!/bin/bash

F2B_LOG_LEVEL=${F2B_LOG_LEVEL:-INFO}
F2B_DB_PURGE_AGE=${F2B_DB_PURGE_AGE:-1d}
F2B_MAX_RETRY=${F2B_MAX_RETRY:-5}
F2B_DEST_EMAIL=${F2B_DEST_EMAIL:-root@localhost}
F2B_SENDER=${F2B_SENDER:-root@$(hostname -f)}
F2B_ACTION=${F2B_ACTION:-%(action_)s}
F2B_IPTABLES_CHAIN=${F2B_IPTABLES_CHAIN:-DOCKER-USER}
F2B_LOGDIR=${F2B_LOGDIR:-/data/log}

SSMTP_PORT=${SSMTP_PORT:-25}
SSMTP_HOSTNAME=${SSMTP_HOSTNAME:-$(hostname -f)}
SSMTP_TLS=${SSMTP_TLS:-NO}

# SSMTP
echo "Setting SSMTP configuration..."
if [ -z "$SSMTP_HOST" ] ; then
  echo "WARNING: SSMTP_HOST must be defined if you want fail2ban to send emails"
else
  cat > /etc/ssmtp/ssmtp.conf <<EOL
mailhub=${SSMTP_HOST}:${SSMTP_PORT}
hostname=${SSMTP_HOSTNAME}
FromLineOverride=YES
AuthUser=${SSMTP_USER}
AuthPass=${SSMTP_PASSWORD}
UseTLS=${SSMTP_TLS}
UseSTARTTLS=${SSMTP_TLS}
EOL
fi
unset SSMTP_HOST
unset SSMTP_USER
unset SSMTP_PASSWORD

# Init
echo "Initializing files and folders..."
mkdir -p /data/db /data/action.d /data/filter.d /data/jail.d
ln -sf /data/jail.d /etc/fail2ban/

# Fail2ban conf
echo "Setting Fail2ban configuration..."
# sed -i "s/logtarget =.*/logtarget = STDOUT/g" /etc/fail2ban/fail2ban.conf
sed -i "s/loglevel =.*/loglevel = $F2B_LOG_LEVEL/g" /etc/fail2ban/fail2ban.conf
sed -i "s/dbfile =.*/dbfile = \/data\/db\/fail2ban\.sqlite3/g" /etc/fail2ban/fail2ban.conf
sed -i "s/dbpurgeage =.*/dbpurgeage = $F2B_DB_PURGE_AGE/g" /etc/fail2ban/fail2ban.conf
sed -i "s%logtarget =.*%logtarget = ${F2B_LOGDIR}/fail2ban\.log%g" /etc/fail2ban/fail2ban.conf
sed -i "s/chain =.*/chain = $F2B_IPTABLES_CHAIN/g" /etc/fail2ban/action.d/iptables-common.conf
cat > /etc/fail2ban/jail.local <<EOL
[DEFAULT]
maxretry = ${F2B_MAX_RETRY}
destemail = ${F2B_DEST_EMAIL}
sender = ${F2B_SENDER}
action = ${F2B_ACTION}
EOL

# Check custom actions
echo "Checking for custom actions in /data/action.d..."
actions=$(ls -l /data/action.d | egrep '^-' | awk '{print $9}')
for action in ${actions}; do
  if [ -f "/etc/fail2ban/action.d/${action}" ]; then
    echo "  WARNING: ${action} already exists and will be overriden"
    rm -f "/etc/fail2ban/action.d/${action}"
  fi
  echo "  Add custom action ${action}..."
  ln -sf "/data/action.d/${action}" "/etc/fail2ban/action.d/"
done

# Check custom filters
echo "Checking for custom filters in /data/filter.d..."
filters=$(ls -l /data/filter.d | egrep '^-' | awk '{print $9}')
for filter in ${filters}; do
  if [ -f "/etc/fail2ban/filter.d/${filter}" ]; then
    echo "  WARNING: ${filter} already exists and will be overriden"
    rm -f "/etc/fail2ban/filter.d/${filter}"
  fi
  echo "  Add custom filter ${filter}..."
  ln -sf "/data/filter.d/${filter}" "/etc/fail2ban/filter.d/"
done

[ ! -d "${F2B_LOGDIR}" ] && mkdir -p "${F2B_LOGDIR}"
LOGFILE="${F2B_LOGDIR}/fail2ban.log"
if [ ! -f $LOGFILE ]; then
	touch $LOGFILE
	chmod 666 $LOGFILE
fi

exec tail -f $LOGFILE &
exec "$@"
