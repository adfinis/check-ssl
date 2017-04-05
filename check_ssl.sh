#!/bin/bash
#-------
# HELP |
#-------
function HELP {
NORM=`tput sgr0`
BOLD=`tput bold`
REV=`tput smso`
echo -e \\n"Help documentation for ${BOLD}$0${NORM}"\\n
echo "${REV}-H${NORM}  --Sets the value for the ${BOLD}h${NORM}ostname. e.g ${BOLD}adfinis-sygroup.ch${NORM}."
echo "${REV}-I${NORM}  --Sets an optional value for an ${BOLD}i${NORM}p to connect. e.g ${BOLD}127.0.0.1${NORM}."
echo "${REV}-p${NORM}  --Sets the value for the ${BOLD}p${NORM}ort. e.g ${BOLD}443${NORM}."
echo "${REV}-P${NORM}  --Sets an optional value for an TLS ${BOLD}P${NORM}rotocol. e.g ${BOLD}xmpp${NORM}."
echo "${REV}-w${NORM}  --Sets the value for the days before ${BOLD}w${NORM}arning. Default are ${BOLD}30${NORM}."
echo "${REV}-c${NORM}  --Sets the value for the days before ${BOLD}C${NORM}ritical. Default are ${BOLD}5${NORM}."
echo -e "${REV}-h${NORM}  --Displays this ${BOLD}h${NORM}elp message."\\n
echo -e "Example: ${BOLD}$0 -H adfinis-sygroup.ch -p 443 -w 40${NORM}"
echo -e "Or: ${BOLD}$0 -H jabber.adfinis-sygroup.ch -p 5222 -P xmpp -w 30 -c 5${NORM}"\\n
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
	read -p "Hostname: " HOST
	read -p "Port (443): " PORT
	if [[ -z "${PORT}" ]]; then
		PORT=443
	else
		read -p "Protocol (leave empty, when It's a SSL Protocol): " PROTOCOL
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
if [[ -z "${PROTOCOL}" ]]; then
	HOST_CHECK=$(openssl s_client -servername "${HOST}" -connect "${IP}":"${PORT}" 2>&- | openssl x509 -enddate -noout)
	while [ "${?}" = "1" ]; do
		echo "Check Hostname"
		exit 1
	done
	DATE_EXPIRE_SECONDS=$(echo "${HOST_CHECK}" | sed 's/^notAfter=//g' | xargs -I{} date -d {} +%s)
else
		HOST_CHECK=$(openssl s_client -servername "${HOST}" -connect "${IP}":"${PORT}" -starttls "${PROTOCOL}" 2>&- | openssl x509 -enddate -noout)
	while [ "${?}" = "1" ]; do
		echo "Check Hostname"
		exit 1
	done
	DATE_EXPIRE_SECONDS=$(echo "${HOST_CHECK}" | sed 's/^notAfter=//g' | xargs -I{} date -d {} +%s)
fi

#-------------------
# DATE CALCULATION |
#-------------------
DATE_EXPIRE_FORMAT=$(date -I --date="@${DATE_EXPIRE_SECONDS}")
DATE_DIFFERENCE_SECONDS=$((${DATE_EXPIRE_SECONDS}-${DATE_ACTUALLY_SECONDS}))
DATE_DIFFERENCE_DAYS=$((${DATE_DIFFERENCE_SECONDS}/60/60/24))

#---------
# OUTPUT |
#---------
if [[ "${DATE_DIFFERENCE_DAYS}" -le "${CRITICAL_DAYS}" && "${DATE_DIFFERENCE_DAYS}" -ge "0" ]]; then
	echo -e "CRITICAL: Cert will expire on: "${DATE_EXPIRE_FORMAT}""
	exit 2
elif [[ "${DATE_DIFFERENCE_DAYS}" -le "${WARNING_DAYS}" && "${DATE_DIFFERENCE_DAYS}" -ge "0" ]]; then
	echo -e "WARNING: Cert will expire on: "${DATE_EXPIRE_FORMAT}""
	exit 1
elif [[ "${DATE_DIFFERENCE_DAYS}" -lt "0" ]]; then
	echo -e "CRITICAL: Cert expired on: "${DATE_EXPIRE_FORMAT}""
	exit 2
else
	echo -e "OK: Cert will expire on: "${DATE_EXPIRE_FORMAT}""
	exit 0
fi
