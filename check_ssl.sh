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
	${REV}-h${NORM}  --Displays this ${BOLD}h${NORM}elp message.
	Example: ${BOLD}$0 -H example.com -p 443 -w 40${NORM}
	Or: ${BOLD}$0 -H xmpp.example.com -p 5222 -P xmpp -w 30 -c 5${NORM}
	EOH
	exit
}

#---------------
# GET HOSTINFO |
#---------------
while getopts :H:I:p:P:w:c:h FLAG; do
	case $FLAG in
		H) #set host
			HOST=$OPTARG
			;;
		I) #set ip to connect
			IP=$OPTARG
			;;

		p) #set port
			PORT=$OPTARG
			;;

		P) #set tls intended protocol
			if [ "${OPTARG}" == "no_tls" ] || [ -z "${OPTARG}" ]; then
				PROTOCOL=""
			else
				PROTOCOL=$OPTARG
			fi
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

if [[ -z "${HOST}" ]]; then
	HELP
fi

if [[ -z "${IP}" ]]; then
  IP=${HOST}
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
	echo -e "CRITICAL: Cert $COMMON_NAME will expire on: ${DATE_EXPIRE_FORMAT}"
	exit 2
elif [[ "${DATE_DIFFERENCE_DAYS}" -le "${WARNING_DAYS}" && "${DATE_DIFFERENCE_DAYS}" -ge "0" ]]; then
	echo -e "WARNING: Cert $COMMON_NAME will expire on: ${DATE_EXPIRE_FORMAT}"
	exit 1
elif [[ "${DATE_DIFFERENCE_DAYS}" -lt "0" ]]; then
	echo -e "CRITICAL: Cert $COMMON_NAME expired on: ${DATE_EXPIRE_FORMAT}"
	exit 2
else
	echo -e "OK: Cert $COMMON_NAME will expire on: ${DATE_EXPIRE_FORMAT}"
	exit 0
fi
