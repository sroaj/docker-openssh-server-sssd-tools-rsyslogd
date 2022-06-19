FROM ubuntu:latest

RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y \
                sssd-tools \
                krb5-user \
                tzdata \
                locales \
                rsyslog \
                openssh-server ; \
    mkdir -p /var/run/sshd ; \
    mkdir -p /var/log ; \
    chmod g+w /var/log ; \
    sed -i '/imklog/s/^/#/' /etc/rsyslog.conf ; \
    pam-auth-update --enable mkhomedir ; \
    pam-auth-update --remove systemd

COPY nsswitch.conf /etc/nsswitch.conf
COPY entrypoint.sh /root/entrypoint.sh

RUN chmod +x /root/entrypoint.sh ; \
    touch /etc/nsswitch.conf ; \
    chmod 644 /etc/nsswitch.conf

EXPOSE 22
VOLUME /config

ENTRYPOINT ["/root/entrypoint.sh"]
CMD ["/usr/sbin/sshd","-D"]
