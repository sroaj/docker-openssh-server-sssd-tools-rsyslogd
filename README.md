# docker-openssh-server-sssd-tools-rsyslogd

Based on:
- https://github.com/phihos/docker-sssd-krb5-ldap
- https://github.com/phihos/docker-nginx-auth-pam-sssd
- https://github.com/linuxserver/docker-openssh-server

## Why

I wanted a ssh bastion server that can auth against a samba4 AD DC. 

After setting https://github.com/phihos/docker-sssd-krb5-ldap up, I needed a container that ran openssh-server and sssd-tools to link up with that container.

Since the bastion server will be exposed to the internet, I alo wanted fail2ban to parse the ```/var/log/auth.log``` which also required rsyslogd to be running to emit ```auth.log``` in a sane format in a non hacky way.

## Usage

I have this setup with fail2ban, and putting kerberos tickets in ```/tmp/tickets``` instead of just ```/tmp``` which allows bind mounting the ```/tmp/tickets``` into the bastion server:

```
version: "3.5"

services:
  fail2ban:
    image: crazymax/fail2ban:latest
    container_name: fail2ban
    network_mode: "host"
    cap_add:
      - NET_ADMIN
      - NET_RAW
    volumes:
      - "fail2ban_data:/data"
      - "sshd_log:/var/log:ro"
    environment:
      TZ: 'America/Los_Angeles'
      SSMTP_HOST: ''
    restart: always
  sssd:
    image: phihos/sssd-krb5-ldap
    container_name: sssd
    volumes:
      - "sssd_lib:/var/lib/sss"
      - "sssd_tickets:/tmp/tickets"
    environment:
      TZ: 'America/Los_Angeles'
      KERBEROS_REALM: 'SAMDOM.EXAMPLE.ORG'
      LDAP_BASE_DN: 'CN=Users,DC=samdom,DC=example,DC=org'
      LDAP_BIND_DN: 'CN=bastion,CN=Users,DC=samdom,DC=example,DC=org'
      LDAP_BIND_PASSWORD: 'example-ldap-bind-password'
      LDAP_URI: |-
        ldaps://samba.samdom.example.org
        krb5_ccachedir = /tmp/tickets
    restart: always
  openssh-server:
    build:
      context: https://github.com/sroaj/docker-openssh-server-sssd-tools-rsyslogd.git#main
    container_name: openssh-server
    hostname: bastion
    environment:
      PASSWORD_ACCESS: 'yes'
      TZ: 'America/Los_Angeles'
    volumes:
      - "sssd_lib:/var/lib/sss"
      - "sshd_log:/var/log"
      - "sssd_tickets:/tmp/tickets"
      - "sshd_config:/config"
    ports:
      - "2222:22"
    restart: always
volumes:
  fail2ban_data:
  sshd_log:
  sshd_config:
  sssd_lib:
  sssd_tickets:
```

An important note to see here is that the ```krb5_ccachedir = /tmp/tickets``` is set in the ```sssd``` container via overloading the ```LDAP_URI``` argument with a multiline string. This is fragile and can break if ```phihos/sssd-krb5-ldap``` updates. 

This hack, and the bind mount of ```/tmp/tickets``` between the ```sssd``` container and the ```openssh-server``` container, allows the ```openssh-server``` container to receive the kerberos ticket created in the ```sssd``` container. 

This results in users who ssh-ed into the bastion to have a kerberos ticket ready to connect with other services that supports kerberos auth.

Alternate to this hack is to bind mount ```/tmp``` in both the ```sssd``` container and the ```openssh-server``` container, but this does mean the ```/tmp``` directory is now shared between 2 containers.

## Parameters

* ```TZ```: Default ```UTC```: Sets the timezome in the container
* ```PASSWORD_ACCESS```: Default ```no```: Enables SSH password access using the user's password in the AD
* ```START_SYSLOGD```: Default ```yes```: Starts the rsyslogd in the container. May be useful to turn off if you want to run only ```sshd``` using a custom command.
* ```KERBEROS_REALM```: Default unset: The kerberos realm to set in the ```/etc/krb5.conf```. Used as the default realm when a logged in user runs ```kinit``` manually.
