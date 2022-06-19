#!/bin/bash

set -e

PASSWORD_ACCESS=${PASSWORD_ACCESS:-no}
START_SYSLOGD=${START_SYSLOGD:-yes}
KERBEROS_REALM=${KERBEROS_REALM}
CHMOD_DIR=${CHMOD_DIR}

TZ=${TZ:-UTC}

echo "Setting timezone to ${TZ}..."
ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime
echo ${TZ} > /etc/timezone

# create folders
mkdir -p /config/ssh_host_keys

# symlink out ssh config directory
if [ ! -L /etc/ssh ];then
    if [ ! -f /config/ssh_host_keys/sshd_config ]; then
        sed -i '/#PidFile/c\PidFile \/config\/sshd.pid' /etc/ssh/sshd_config
        cp -a /etc/ssh/sshd_config /config/ssh_host_keys/
        cp -a /etc/ssh/ssh_config /config/ssh_host_keys/
    fi
    rm -Rf /etc/ssh
    ln -s /config/ssh_host_keys /etc/ssh
    ssh-keygen -A
fi

if [ "${KERBEROS_REALM}" ]; then
    cat >/etc/krb5.conf <<EOL
[libdefaults]
    default_realm = ${KERBEROS_REALM}
    dns_lookup_realm = true
    dns_lookup_kdc = true
EOL
    echo "Wrote realm to /etc/krb5.conf"
else
    :>/etc/krb5.conf
    echo "Wrote empty file to /etc/krb5.conf. Manual kinit should specify REALM as user@REALM"
fi

if [ "$PASSWORD_ACCESS" == "no" ]; then
    sed -i '/^#PasswordAuthentication/c\PasswordAuthentication no' /etc/ssh/sshd_config
    sed -i '/^PasswordAuthentication/c\PasswordAuthentication no' /etc/ssh/sshd_config
    echo "User/password ssh access is enabled."
else
    sed -i '/^PasswordAuthentication/c\PasswordAuthentication yes' /etc/ssh/sshd_config
    echo "User/password ssh access is disabled."
fi

if [ "$START_SYSLOGD" != "no" ]; then
    chgrp syslog /var/log && \
    chmod g+w /var/log && \
    /usr/sbin/rsyslogd && echo "syslogd started."
    { sleep 1 ; tail -F /var/log/auth.log ; } &
else
    echo "syslogd not started."
fi

if [ "${CHMOD_DIR}" ]; then
    # In case /tmp subdir is mounted for krb5cc
    find "${CHMOD_DIR}" -type d -exec chmod 777 {} +
fi

# Start sshd
exec "$@"
