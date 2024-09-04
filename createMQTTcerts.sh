#!/bin/sh
###########################################################
#
# Author: Balazs Bezeczky
# Email: b <dot> bezeczky <at> beckhoff <dot> at
# Date: 2024 August 7
#
# All rights reserved
#
# Licence: MIT
#
##########################################################

#make script BSD and linux compatible:

# Determine the correct bash path
if [ -x /usr/local/bin/bash ]; then
    BASH_PATH="/usr/local/bin/bash"
#    printf "${BASH_PATH}\n"
elif [ -x /usr/bin/bash ]; then
    BASH_PATH="/usr/bin/bash"
#    printf "${BASH_PATH}\n"
else
    echo "Bash not found in expected locations. Please install bash."
    exit 1
fi

# Re-exec the script with the correct bash interpreter
if [ "$(ps -p $$ -o comm=)" != "$(basename $BASH_PATH)" ]; then
    exec "$BASH_PATH" "$0" "$@"
fi

OS=`uname -s`
 
case "$OS" in
     "Linux" )
#       echo "Linux system found...\n"
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        CYAN='\033[0;36m'
        NC='\033[0m' # No Color
        HOSTNAME=`cat /etc/hostname`
        CERT_DAYS="3650"
        CA_DN="/CN=${HOSTNAME}"
        XAE_CN='/CN=TwinCAT_XAE'
        XAR_CN='/CN=TwinCAT_XAR'
        MOSQPATH="/etc/mosquitto/"
        printf "${RED}Linux system found...${NC}\n"
        ;;
    "FreeBSD" )
#       echo "FreeBSD system found...\n"
        RED="\033[0;31m"
        GREEN='\033[0;32m'
        CYAN='\033[0;36m'
        NC='\033[0m' # No Color
        HOSTNAME=$(hostname)
        CERT_DAYS="3650"
        CA_DN="/CN=${HOSTNAME}"
        XAE_CN='/CN=TwinCAT_XAE'
        XAR_CN='/CN=TwinCAT_XAR'
        MOSQPATH="/usr/local/etc/mosquitto/"
        printf "${RED}FreeBSD system found...${NC}\n"
        ;;
    * )
        echo "Unknown OS [$MYOS], exiting\n"
        ;;
esac

 
printf "${CYAN}Enter a project name (e.g. test_certs). This will be used to name the directory where the certificates will be stored in the file system. E.g. ${PROJECTPATH}test_certs${NC}\n"
read PROJECT
printf "${GREEN}The project name is '${PROJECT}'\n"
PROJECTPATH="${MOSQPATH}${PROJECT}"

printf "${GREEN}The project path is now '${PROJECTPATH}'\n"
 
printf "${RED}Certificate Authority (CA) will be created. You will be prompted for a password to secure the CA certificate. For the
same password will be asked when signing the client certificates${NC}\n"

############### Read inputs for CSRs ############
printf "${CYAN}Country Name (2 letter Code):${NC} "
#read -p "${CYAN}Country Name (2 letter Code):${NC} " COUNTRY
read COUNTRY
#echo $COUNTRY
printf "${CYAN}State or Province Name (The state/province where your company is located):${NC} "
read STATE
#echo $STATE
printf "${CYAN}Locality Name (the city where your company is located):${NC} "
read CITY
#echo $CITY
printf "${CYAN}Organization Name (Your company's legally registered name):${NC} "
read COMPANY
#echo $COMPANY
printf "${CYAN}Organizational Unit name (The name of your department within the organization):${NC} "
read UNIT
#echo $UNIT
printf "${CYAN}Common Name: ${GREEN}${HOSTNAME}${CYAN} was found. It should be the FQDN. Enter something else if not satisfied:${NC} "
read CN
#echo $CN
if [ "$CN" == "$HOSTNAME" ];
then
#   echo "sind gleich"
    $CN = $HOSTNAME
else
#   echo "NICHT gleich"
    if [ "$CN" == "" ];
    then
        CN=$HOSTNAME
    fi
fi
 
#echo $CN
#exit;

 
CA="openssl req -new -x509 -days ${CERT_DAYS} -extensions v3_ca -keyout ./CA.key -out ./CA.crt -subj \"/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O='${COMPANY}'/OU=${UNIT}/CN=${CN}\""
BROKER2="openssl req -out ./broker.csr -key ./broker.key -new -subj \"/CN=${CN}\""
#BROKER2="openssl req -out ./broker.csr -key ./broker.key -new"
BROKER3="openssl x509 -req -in ./broker.csr -CA ./CA.crt -CAkey ./CA.key -CAcreateserial -out ./broker.crt -days ${CERT_DAYS}"
XAE2="openssl req -out ./TwinCAT_XAE.csr -key ./TwinCAT_XAE.key -new -subj ${XAE_CN}"
XAE3="openssl x509 -req -in ./TwinCAT_XAE.csr -CA ./CA.crt -CAkey ./CA.key -CAcreateserial -out ./TwinCAT_XAE.crt -days ${CERT_DAYS}"
XAR2="openssl req -out ./TwinCAT_XAR.csr -key ./TwinCAT_XAR.key -new -subj ${XAR_CN}"
XAR3="openssl x509 -req -in ./TwinCAT_XAR.csr -CA ./CA.crt -CAkey ./CA.key -CAcreateserial -out ./TwinCAT_XAR.crt -days ${CERT_DAYS}"
 
#echo $CA
#exit;
printf "${GREEN}Generating CA...${NC}\n"
 
openssl req -new -x509 -days ${CERT_DAYS} -extensions v3_ca -keyout ./CA.key -out ./CA.crt -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${COMPANY}/OU=${UNIT}/CN=${CN}"
 

printf "${GREEN}Generating broker certificate...${NC}\n"
openssl genrsa -out ./broker.key 2048
#$BROKER2
openssl req -out ./broker.csr -key ./broker.key -new -subj "/CN=${CN}"
 
$BROKER3
 
printf "${GREEN}Generating XAE certificate...${NC}\n"
openssl genrsa -out ./TwinCAT_XAE.key 2048
$XAE2
$XAE3
 
printf "${GREEN}Generating XAR certificate...${NC}\n"
openssl genrsa -out ./TwinCAT_XAR.key 2048
$XAR2
$XAR3
 
printf "${GREEN}Verifying CA cert: ${NC}\n"
openssl x509 -text -in ./CA.crt -noout
printf "${GREEN}Verifying Broker cert: ${NC}\n"
openssl x509 -text -in ./broker.crt -noout
 
printf "${CYAN}On which port should the broker be accessible over MQTT? e.g. 8883?${NC}\n"
read PORT
printf "${GREEN}Generating mosquitto config:${NC}\n"
echo "
listener 1883
allow_anonymous false
password_file ${MOSQPATH}mqttuser.txt
user mosquitto 

# Logging
# If set to true, the log will include entries when clients connect and disconnect. If set to false, these entries will not appear.
connection_messages true
log_dest topic 
log_dest file /var/log/mosquitto/mosquitto.log
log_timestamp true
log_timestamp_format %Y-%m-%dT%H:%M:%S
log_type all

listener ${PORT}
allow_anonymous false
require_certificate true
use_identity_as_username true
cafile ${PROJECTPATH}/CA.crt
keyfile ${PROJECTPATH}/broker.key
certfile ${PROJECTPATH}/broker.crt
tls_version tlsv1.2" > ./mosquitto.conf
 
echo "
listener 1883
allow_anonymous false
password_file ${MOSQPATH}mqttuser.txt
user mosquitto

# Logging
# If set to true, the log will include entries when clients connect and disconnect. If set to false, these entries will not appear.
connection_messages true
log_dest topic 
log_dest file /var/log/mosquitto/mosquitto.log
log_timestamp true
log_timestamp_format %Y-%m-%dT%H:%M:%S
log_type all

listener ${PORT}
allow_anonymous false
require_certificate true
use_identity_as_username true
cafile ${PROJECTPATH}/CA.crt
keyfile ${PROJECTPATH}/broker.key
certfile ${PROJECTPATH}/broker.crt
tls_version tlsv1.2"
 
printf "${GREEN}Removing certificate sign request files (*.csr) for less confusion...${NC}\n"
rm *.csr
 
RTOSPATH="/TwinCAT/3.1/Target/"
RTOSPATH_CERT="${RTOSPATH}Certificates"
RTOSPATH_ROUTES="${RTOSPATH}Routes"
BSDPATH="/usr/local/etc/TwinCAT/3.1/Target/"
BSDPATH_CERT="${BSDPATH}Certificates"
BSDPATH_ROUTES="${BSDPATH}Routes"
WINDOWSPATH="C:\TwinCAT\\\3.1\Target\\"
WINDOWSPATH_CERT="${WINDOWSPATH}Certificates\\"
WINDOWSPATH_ROUTES="${WINDOWSPATH}Routes\\"



 
printf "${CYAN}Which OS is running on the target device (XAR)? Enter the number either for 1) TC/RTOS, 2) Windows or 3) TC/BSD: ${NC}\n"
TARGETOSLIST="TCRTOS Windows TCBSD"
select opt in $TARGETOSLIST; do
     if [ "$opt" = "TCRTOS" ]; then
        printf "${GREEN}freeRTOS ${NC}\n"
        TARGETPATH=$RTOSPATH
	TARGETPATH_CERT=$RTOSPATH_CERT
	TARGETPATH_ROUTES=$RTOSPATH_ROUTES
        break
    elif [ "$opt" = "Windows" ]; then
        printf "${GREEN}Windows ${NC}\n"
        TARGETPATH=$WINDOWSPATH
	TARGETPATH_CERT=$WINDOWSPATH_CERT
	TARGETPATH_ROUTES=$WINDOWSPATH_ROUTES
        break
    elif [ "$opt" = "TCBSD" ]; then
        printf "${GREEN} TCBSD ${NC}\n"
        TARGETPATH=$BSDPATH
	TARGETPATH_CERT=$BSDPATH_CERT
	TARGETPATH_ROUTES=$BSDPATH_ROUTES
        break
    else
       printf "${RED}Bad input. Choose one of the options above.${NC}\n"
    fi
done
 
TARGETOS=$opt
 
#printf "${GREEN} TargetOS: ${TARGETOS}, TargetPath: ${TARGETPATH} ${NC}\n"

cat <<EOF > ./Routes_XAR.xml
<?xml version="1.0" encoding="UTF-8"?>
<TcConfig xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.beckhoff.com/schemas/2015/12/TcConfig">
    <RemoteConnections>
        <Mqtt>
            <Address Port="${PORT}">${HOSTNAME}</Address>
           <Topic>VirtualAmsNetwork1</Topic>
            <User>TwinCAT_XAE</User>
            <Tls>
                <Ca>${TARGETPATH_CERT}CA.crt</Ca>
                <Cert>${TARGETPATH_CERT}TwinCAT_XAE.crt</Cert>
               <Key>${TARGETPATH_CERT}TwinCAT_XAE.key</Key>
           </Tls>
       </Mqtt>
    </RemoteConnections>
</TcConfig>
EOF
 
printf "${CYAN}Config files for XAR (runtime system) were created. Copy the files to the following locations:${NC}\n"
printf "${CYAN}Routes_XAR.xml -> ${GREEN}on your target OS (${TARGETOS}) into the directory ${CYAN}${TARGETPATH_ROUTES} ${GREEN}. Create directory first, if missing.${NC}\n"
printf "${CYAN}CA.crt, TwinCAT_XAR.crt and TwinCAT_XAE.key -> ${GREEN}on your target OS (${TARGETOS}) into the directory ${CYAN}${TARGETPATH_CERT} ${GREEN}. Create directory first, if missing.${NC}\n"


cat <<EOF > ./Routes_XAE.xml
<?xml version="1.0" encoding="UTF-8"?>
<TcConfig xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.beckhoff.com/schemas/2015/12/TcConfig">
    <RemoteConnections>
        <Mqtt>
           <Address Port="${PORT}">${HOSTNAME}</Address>
           <Topic>VirtualAmsNetwork1</Topic>
           <User>TwinCAT_XAE</User>
           <Tls>
               <Ca>${WINDOWSPATH_CERT}CA.crt</Ca>
               <Cert>${WINDOWSPATH_CERT}TwinCAT_XAE.crt</Cert>
               <Key>${WINDOWSPATH_CERT}TwinCAT_XAE.key</Key>
           </Tls>
       </Mqtt>
  </RemoteConnections>
</TcConfig>
EOF

printf "${CYAN}Config files for XAE (engineering system) were created. Copy the files to the following locations:${NC}\n"
printf "${CYAN}Routes_XAE.xml -> ${GREEN} on your Windows XAE pc into the directory ${CYAN}${WINDOWSPATH_ROUTES} ${GREEN}. Create directory first, if missing.${NC}\n"
printf "${CYAN}CA.crt, TwinCAT_XAE.crt and TwinCAT_XAE.key -> ${GREEN} on your Windows XAE pc into the directory ${CYAN}${WINDOWSPATH_CERT} ${GREEN}. Create directory first, if missing.${NC}\n"

printf "${CYAN}Should the files copied to their destinations? certificates -> ${PROJECTPATH}, mosquitto.conf -> ${MOSQPATH}: 1) yes 2) no${NC}\n"
OPTIONSLIST="yes no"
select opt in $OPTIONSLIST; do
     if [ "$opt" = "yes" ]; then
        printf "${GREEN}Creating directory ${PROJECTPATH}...${NC}\n"
        mkdir ${PROJECTPATH}
	printf "${GREEN}Copying certificates to ${PROJECTPATH}...${NC}\n"
	cp ./CA.crt ./broker.crt ./broker.key ${PROJECTPATH}
	printf "${GREEN}Changing owner of certificates to user mosquitto...${NC}\n"
	chown -R mosquitto:mosquitto ${PROJECTPATH}
	printf "${GREEN}Creating backup of mosquitto.conf in ${MOSQPATH}...${NC}\n"
	cp ${MOSQPATH}mosquitto.conf ${MOSQPATH}mosquitto.conf.bkp
	printf "${GREEN}Copying mosquitto.conf to ${MOSQPATH}...${NC}\n"
	cp ./mosquitto.conf ${MOSQPATH}
        break
    elif [ "$opt" = "no" ]; then
        printf "${GREEN}Not copying anything...${NC}\n"
        TARGETPATH=$WINDOWSPATH
        break
    else
       printf "${RED}Bad input. Choose one of the options above.${NC}\n"
    fi
done

