#!/usr/bin/env sh
set -e # exit on error

# Variables
[ -z "$SMTP_LOGIN" -o -z "$SMTP_PASSWORD" ] && {
	echo "SMTP_LOGIN and SMTP_PASSWORD _must_ be defined" >&2
	exit 1
}

if [ -n "$RECIPIENT_RESTRICTIONS" ]; then
	RECIPIENT_RESTRICTIONS="inline:{$(echo $RECIPIENT_RESTRICTIONS | sed 's/\s\+/=OK, /g')=OK}"
else
	RECIPIENT_RESTRICTIONS=static:OK
fi

export SMTP_LOGIN SMTP_PASSWORD RECIPIENT_RESTRICTIONS
export SMTP_HOST=${SMTP_HOST:-"email-smtp.us-east-1.amazonaws.com"}
export SMTP_PORT=${SMTP_PORT:-"25"}
export ACCEPTED_NETWORKS=${ACCEPTED_NETWORKS:-"192.168.0.0/16 172.16.0.0/12 10.0.0.0/8"}
export USE_TLS=${USE_TLS:-"no"}
export TLS_VERIFY=${TLS_VERIFY:-"may"}

# Template
export DOLLAR='$'
envsubst < /root/conf/postfix-main.cf > /etc/postfix/main.cf

# Rewrite sender address
[ -n "$REWRITE_SENDER" ] && {
	cat <<EOF>>/etc/postfix/main.cf
sender_canonical_classes = envelope_sender, header_sender
sender_canonical_maps =  regexp:/etc/postfix/sender_canonical_maps
smtp_header_checks = regexp:/etc/postfix/header_check
EOF
	echo "/.+/    $REWRITE_SENDER" > /etc/postfix/sender_canonical_maps
	echo "/^From\:.*$/ REPLACE From: $REWRITE_SENDER" > /etc/postfix/header_check
	postmap /etc/postfix/sender_canonical_maps
	postmap /etc/postfix/header_check
}

# Generate default alias DB
newaliases

# Launch
rm -f /var/spool/postfix/pid/*.pid
exec supervisord -n -c /etc/supervisord.conf
