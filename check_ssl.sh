#!/bin/bash

#-------
# HELP |
#-------
HELP () {
	NORM=$(tput sgr0)
	BOLD=$(tput bold)
	REV=$(tput smso)
	cat <<- EOH
	Help documentation for ${BOLD}$0${NORM}
	${REV}-H${NORM}  --Sets the value for the ${BOLD}h${NORM}ostname. e.g ${BOLD}example.com${NORM}.
	${REV}-I${NORM}  --Sets an optional value for an ${BOLD}i${NORM}p to connect. e.g ${BOLD}127.0.0.1${NORM}.
	${REV}-p${NORM}  --Sets the value for the ${BOLD}p${NORM}ort. e.g ${BOLD}443${NORM}.
	${REV}-P${NORM}  --Sets an optional value for an TLS ${BOLD}P${NORM}rotocol. e.g ${BOLD}xmpp${NORM}.
	${REV}-w${NORM}  --Sets the value for the days before ${BOLD}w${NORM}arning. Default are ${BOLD}30${NORM}.
	${REV}-c${NORM}  --Sets the value for the days before ${BOLD}C${NORM}ritical. Default are ${BOLD}5${NORM}.
	${REV}-l${NORM}  --Sets an optional ${BOLD}l${NORM}abel for the host in messages. Default uses /etc/services.
	${REV}-q${NORM}  --${BOLD}Q${NORM}uiet mode. Only show warnings and errors.
	${REV}-h${NORM}  --Displays this ${BOLD}h${NORM}elp message.
	Example: ${BOLD}$0 -H example.com -p 443 -w 40${NORM}
	Or: ${BOLD}$0 -H xmpp.example.com -p 5222 -P xmpp -w 30 -c 5${NORM}
	EOH
	exit
}

#-----------------
# DEFAULT VALUES |
#-----------------
CRITICAL_DAYS=5
QUIET=0
WARNING_DAYS=30

#---------------
# GET HOSTINFO |
#---------------
while getopts :H:I:l:p:P:w:c:qh FLAG; do
	case $FLAG in
		H) #set host
			HOST=$OPTARG
			;;
		I) #set ip to connect
			IP=$OPTARG
			;;

		l) #set label
			LABEL=$OPTARG
			;;

		p) #set port
			PORT=$OPTARG
			;;

		P) #set tls intended protocol
			PROTOCOL=$OPTARG
			;;

		w) #set day before warning
			WARNING_DAYS=$OPTARG
			;;

		c) #set day before Critical
			CRITICAL_DAYS=$OPTARG
			;;

		h) #show help
			HELP
			;;

		q) #quiet mode
			QUIET=1
			;;

		*)
			HELP
			;;
	esac
done

if [[ -z "${1}" ]]; then
	read -rp "Hostname: " HOST
	read -rp "Port (443): " PORT
	if [[ -z "${PORT}" ]]; then
		PORT=443
	else
		read -rp "Protocol (leave empty, when It's a SSL Protocol): " PROTOCOL
	fi
fi

if [[ -z "${PORT}" ]]; then
	PORT=443
fi

if [[ -z "${PROTOCOL}" ]]; then
	case "$PORT" in
		110) PROTOCOL=pop3;;
		143) PROTOCOL=imap;;
		5222) PROTOCOL=xmpp;;
		5269) PROTOCOL=xmpps;;
	esac
fi
if [[ "${PROTOCOL}" = "no_tls" ]]; then
	PROTOCOL=""
fi

if [[ -z "${HOST}" ]]; then
	HELP
fi

if [[ -z "${IP}" ]]; then
	IP=${HOST}
fi

if [[ -z "${LABEL}" && -f /etc/services ]]; then
	LABEL=$(grep "${PORT}/tcp" /etc/services |cut -f1)
fi
if [[ -n "${LABEL}" ]]; then
	LABEL=" (${LABEL})"
fi

#-----------
# GET DATE |
#-----------
DATE_ACTUALLY_SECONDS=$(date +"%s")

#------------------
# GET CERTIFICATE |
#------------------
if [[ -n "${PROTOCOL}" ]]; then
	HOST_CHECK_COMMAND="openssl s_client -servername ${HOST} -connect ${IP}:${PORT} -starttls ${PROTOCOL}"
else
	HOST_CHECK_COMMAND="openssl s_client -servername ${HOST} -connect ${IP}:${PORT}"
fi
HOST_CHECK=$(${HOST_CHECK_COMMAND} 2>&- | openssl x509 -enddate -subject -noout)
while [ "${?}" = "1" ]; do
	echo "Check Hostname"
	exit 2
done
DATE_EXPIRE_SECONDS=$(echo "${HOST_CHECK}" | grep "notAfter=" |sed 's/^notAfter=//g' | xargs -I{} date -d {} +%s)
# The regular expression "CN ?= ?" is required because OpenSSL 1.0 and
# OpenSSL 1.1 have different output formats for subject:
# OpenSSL 1.0: "subject= /CN=example.com"
# OpenSSL 1.1: "subject=CN = example.com"
COMMON_NAME=$(echo "${HOST_CHECK}" | grep "subject=" | sed -E 's/^.*CN ?= ?//' | sed 's/\s.*$//')

#-------------------
# DATE CALCULATION |
#-------------------
DATE_EXPIRE_FORMAT=$(date -I --date="@${DATE_EXPIRE_SECONDS}")
DATE_DIFFERENCE_SECONDS=$((DATE_EXPIRE_SECONDS - DATE_ACTUALLY_SECONDS))
DATE_DIFFERENCE_DAYS=$((DATE_DIFFERENCE_SECONDS/60/60/24))

#---------
# OUTPUT |
#---------
if [[ "${DATE_DIFFERENCE_DAYS}" -le "${CRITICAL_DAYS}" && "${DATE_DIFFERENCE_DAYS}" -ge "0" ]]; then
	echo -e "CRITICAL: Cert $COMMON_NAME$LABEL will expire on: ${DATE_EXPIRE_FORMAT}"
	exit 2
elif [[ "${DATE_DIFFERENCE_DAYS}" -le "${WARNING_DAYS}" && "${DATE_DIFFERENCE_DAYS}" -ge "0" ]]; then
	echo -e "WARNING: Cert $COMMON_NAME$LABEL will expire on: ${DATE_EXPIRE_FORMAT}"
	exit 1
elif [[ "${DATE_DIFFERENCE_DAYS}" -lt "0" ]]; then
	echo -e "CRITICAL: Cert $COMMON_NAME$LABEL expired on: ${DATE_EXPIRE_FORMAT}"
	exit 2
else
	if [[ "${QUIET}" -lt 1 ]]; then
		echo -e "OK: Cert $COMMON_NAME$LABEL will expire on: ${DATE_EXPIRE_FORMAT}"
	fi
	exit 0
fi
