#!/bin/bash
#==============================================================================
#title         : install_graylog.sh
#description   : This script will install Graylog components (server and web).
#author        : Mikaël ANDRE
#job title     : Network engineer
#mail          : mikael.andre.1989@gmail.com
#created       : 20150219
#last revision : 20150311
#version       : 1.4
#platform      : Linux
#processor     : 64 Bits
#os            : CentOS
#os version    : 6.5 or 6.6
#usage         : sh install_graylog.sh -i|-a <VARIABLES FILE>
#notes         : Copy and paste in Vi to use this script
#==============================================================================

#==============================================================================
# Global variables
#==============================================================================
# SYSTEM VARIABLES
SERVER_PROCESSOR_TYPE=
SERVER_IP_ADDRESS=
SERVER_HOST_NAME=
SERVER_SHORT_NAME=
SERVER_TIME_ZONE=
PRIVATE_KEY_FILE=
PUBLIC_KEY_FILE=
INSTALLATION_LOG_TIMESTAMP=`date +%d%m%Y%H%M%S`
INSTALLATION_LOG_FOLDER=`pwd`
INSTALLATION_LOG_FILE="$INSTALLATION_LOG_FOLDER/install_graylog_$INSTALLATION_LOG_TIMESTAMP.log"
INSTALLATION_CFG_FILE=""
# NETWORK VARIABLES
NETWORK_INTERFACE_NAME=
# NTP VARIABLES
BOOLEAN_NTP_ONSTARTUP=
BOOLEAN_NTP_CONFIGURE=
NEW_NTP_ADDRESS=
# SSH VARIABLES
BOOLEAN_USE_OPENSSHKEY=
OPENSSH_PERSONAL_KEY=
# MONGO VARIABLES
BOOLEAN_MONGO_ONSTARTUP=
MONGO_ADMIN_USER="admin"
MONGO_ADMIN_PASSWORD=
MONGO_GRAYLOG_DATABASE=
MONGO_GRAYLOG_USER=
MONGO_GRAYLOG_PASSWORD=
# SSL VARIABLES
SSL_KEY_SIZE=
SSL_KEY_DURATION=
SSL_SUBJECT_COUNTRY=
SSL_SUBJECT_STATE=
SSL_SUBJECT_LOCALITY=
SSL_SUBJECT_ORGANIZATION=
SSL_SUBJECT_ORGANIZATIONUNIT=
SSL_SUBJECT_EMAIL=
# JAVA VARIABLES
ELASTICSEARCH_RAM_RESERVATION="256m"
GRAYLOGSERVER_RAM_RESERVATION="256m"
GRAYLOGWEBGUI_RAM_RESERVATION="256m"
# ELASTICSEARCH VARIABLES
BOOLEAN_ELASTICSEARCH_ONSTARTUP=
BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN=
# GRAYLOG VARIABLES
BOOLEAN_GRAYLOGSERVER_ONSTARTUP=
BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP=
GRAYLOG_SECRET_PASSWORD=
GRAYLOG_ADMIN_USERNAME=
GRAYLOG_ADMIN_PASSWORD=
GRAYLOG_USE_SMTP=
# SMTP VARIABLES
SMTP_HOST_NAME=
SMTP_DOMAIN_NAME=
SMTP_PORT_NUMBER=
SMTP_USE_AUTH=
SMTP_USE_TLS=
SMTP_USE_SSL=
SMTP_AUTH_USERNAME=
SMTP_AUTH_PASSWORD=
# NGINX VARIABLES
BOOLEAN_NGINX_ONSTARTUP=
# TERMINAL VARIABLES
RES_COL="60"
RES_COL1="67"
# COLOR VARIABLES
MOVE_TO_COL="\\033[${RES_COL}G"
MOVE_TO_COL1="\\033[${RES_COL1}G"
SETCOLOR_INFO="\\033[0;36m"
SETCOLOR_SUCCESS="\\033[0;32m"
SETCOLOR_FAILURE="\\033[0;31m"
SETCOLOR_WARNING="\\033[0;33m"
SETCOLOR_NORMAL="\\033[0;39m"
#==============================================================================

#==============================================================================
# Functions
#==============================================================================
# Log function to write all events during installation process
function log() {
  local program_name="$0"
  local message_type="$1"
  shift
  local message_content="$@"
  echo -e "$(date) [$program_name]: $message_type: $message_content" >> $INSTALLATION_LOG_FILE
}
# Display message on standart output without carriage return
function echo_message() {
  echo -en "${1}${MOVE_TO_COL}"
}
# Display "[ INFO ]" message on standart output with carriage return
function echo_info() {
  echo -e "[ ${SETCOLOR_INFO}${1}${SETCOLOR_NORMAL} ]" 
}
# Display "[  OK  ]" message on standart output with carriage return
function echo_success() {
  echo -e "[  ${SETCOLOR_SUCCESS}${1}${SETCOLOR_NORMAL}  ]" 
}
# Display "[FAILED]" message on standart output with carriage return
function echo_failure() {
  echo -e "[${SETCOLOR_FAILURE}${1}${SETCOLOR_NORMAL}]"
}
# Display "[ WARN ]" message on standart output with carriage return
function echo_warning() {
  echo -e "[ ${SETCOLOR_WARNING}${1}${SETCOLOR_NORMAL} ]"
}
# Display "[ PASS ]" message on standart output with carriage return
function echo_passed() {
  echo -e "[ ${SETCOLOR_WARNING}${1}${SETCOLOR_NORMAL} ]"
}
# Return 0 if user answers "yes" or 1 to "no" answer
function yes_no_function() {
  local input_message=$1
  local yes_regex="^[Yy][Ee][Ss]$|^[Yy]$"
  local no_regex="^[Nn][Oo]$|^[Nn]$"
  local default_answer=$2
  local answer="not_define"
  while [[ !("$answer" =~ $yes_regex) && !("$answer" =~ $no_regex) && !( -z $answer) ]]
  do
    echo -e "\n$input_message\n[y/n], default to [${SETCOLOR_INFO}$default_answer${SETCOLOR_NORMAL}]:"
    echo -en "> "
    read answer
    if [ -z $answer ]
    then
      answer="$default_answer"
    fi
  done
  if [[ "$answer" =~ $yes_regex ]]
  then 
    return 0
  else 
    return 1
  fi
}
# Abort function and inform user to read log file for more informations on bad ending
function abort_installation() {
  log "ERROR" "GRAYLOG installation: Abort"
  echo_message "Check log file $INSTALLATION_LOG_FILE"
  echo_info "INFO"
  if [ $INSTALLATION_CFG_FILE != "" ]
  then
    if [[ "$INSTALLATION_CFG_FILE" =~ .*\.cfg$ ]]
    then
      log "INFO" "GRAYLOG installation: Retry with $0 -f $INSTALLATION_CFG_FILE"
    fi
  fi
  exit 1
}
# Return 0 if file exists or 1 if not
function test_file() {
  local input_file="$1"
  local is_exist=
  if [ -f $input_file ]
  then
    is_exist=0
  else
    is_exist=1
  fi
  echo $is_exist
}
# Return 0 if directory exists or 1 if not
function test_directory() {
  local input_folder="$1"
  local is_exist=
  if [ -d $input_folder ]
  then
    is_exist=0
  else
    is_exist=1
  fi
  echo $is_exist
}
# Test DNS configuration and send 4 icmp packets
function test_internet() {
  local icmp_packets_sent=4
  local icmp_packets_received=
  local internet_host_name="www.google.fr"
  local icmp_time_out=5
  echo_message "Check Internet connection"
  log "INFO" "Internet connection: Check connection to $internet_host_name"
  icmp_packets_received=$(ping -c ${icmp_packets_sent} -W ${icmp_time_out} ${internet_host_name} 2>&1)
  if [[ ! "$icmp_packets_received" =~ .*unknown.* ]]
  then
    log "INFO" "Internet connection: DNS successfully configured"
    log "INFO" "Internet connection: ICMP packets sent=$icmp_packets_sent"
    icmp_packets_received=$(ping -c $icmp_packets_sent -W $icmp_time_out $internet_host_name | grep "received" | awk -F: '{print $1}' | awk '{print $4}')
    if [ "$icmp_packets_received" == "$icmp_packets_sent" ]
    then
      log "INFO" "Internet connection: ICMP packets received=$icmp_packets_received"
      echo_success "OK"
    else
      log "ERROR" "Internet connection: ICMP packets received=$icmp_packets_received"
      echo_failure "FAILED"
      abort_installation
    fi
  else
    log "ERROR" "Internet connection: Unable to resolve $internet_host_name"
    echo_failure "FAILED"
    abort_installation
  fi
}
# Set all global variables using inputs user
function set_globalvariables() {
  local installation_cfg_tmpfile="$INSTALLATION_LOG_FOLDER/install_graylog_$INSTALLATION_LOG_TIMESTAMP.cfg"
  touch $installation_cfg_tmpfile
  log "INFO" "Global variables: $installation_cfg_tmpfile successfully created"
  if [ -z "$NETWORK_INTERFACE_NAME" ]
  then
    yes_no_function "Do you want to modify name of network interface, default value : ${SETCOLOR_INFO}eth0${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify name of network interface, actual value : ${SETCOLOR_WARNING}${NETWORK_INTERFACE_NAME}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$NETWORK_INTERFACE_NAME" ]
    then
      while [ -z "$NETWORK_INTERFACE_NAME" ]
      do
        echo -e "Type network interface name, followed by [ENTER]:"
        echo -en "> "
        read NETWORK_INTERFACE_NAME
      done
    else
      yes_no_function "Can you confirm you want to modify current interface name ?" "yes"
      if [ $? -eq 0 ]
      then
        NETWORK_INTERFACE_NAME=
        while [ -z "$NETWORK_INTERFACE_NAME" ]
        do
          echo -e "Type network interface name, followed by [ENTER]:"
          echo -en "> "
          read NETWORK_INTERFACE_NAME
        done
      else
        NETWORK_INTERFACE_NAME=$NETWORK_INTERFACE_NAME
      fi
    fi
  else
    if [ -z "$NETWORK_INTERFACE_NAME" ]
    then
      NETWORK_INTERFACE_NAME='eth0'
    else
      NETWORK_INTERFACE_NAME=$NETWORK_INTERFACE_NAME
    fi
  fi
  echo "NETWORK_INTERFACE_NAME='$NETWORK_INTERFACE_NAME'" > $installation_cfg_tmpfile
  if [ -z "$BOOLEAN_USE_OPENSSHKEY" ]
  then
    yes_no_function "Do you want to use your OpenSSH key to authenticate you on GRAYLOG server, default value : ${SETCOLOR_INFO}yes${SETCOLOR_NORMAL} ?" "yes"
  else
    if [ "$BOOLEAN_USE_OPENSSHKEY" == 1 ]
    then
      yes_no_function "Do you want to use your OpenSSH key to authenticate you on GRAYLOG server, actual value : ${SETCOLOR_WARNING}yes${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to use your OpenSSH key to authenticate you on GRAYLOG server, actual value : ${SETCOLOR_WARNING}no${SETCOLOR_NORMAL} ?" "no"
    fi
  fi
  if [ $? -eq 0 ]
  then
    BOOLEAN_USE_OPENSSHKEY=1
    if [ -z "$OPENSSH_PERSONAL_KEY" ]
    then
      while [ -z "$OPENSSH_PERSONAL_KEY" ] || [[ ! "$OPENSSH_PERSONAL_KEY" =~ ^ssh-rsa.* ]]
      do
        echo -e "Paste your OpenSSH key, followed by [ENTER]:"
        echo -en "> "
        read OPENSSH_PERSONAL_KEY
      done
    else
      yes_no_function "Can you confirm you want to modify current SSH key ?" "yes"
      if [ $? -eq 0 ]
      then
        OPENSSH_PERSONAL_KEY=
        while [ -z "$OPENSSH_PERSONAL_KEY" ] || [[ ! "$OPENSSH_PERSONAL_KEY" =~ ^ssh-rsa.* ]]
        do
          echo -e "Paste your OpenSSH key, followed by [ENTER]:"
          echo -en "> "
          read OPENSSH_PERSONAL_KEY
        done
      else
        OPENSSH_PERSONAL_KEY=$OPENSSH_PERSONAL_KEY
      fi
    fi
  else
    BOOLEAN_USE_OPENSSHKEY=0
    OPENSSH_PERSONAL_KEY=
  fi
  echo "BOOLEAN_USE_OPENSSHKEY=$BOOLEAN_USE_OPENSSHKEY" >> $installation_cfg_tmpfile
  echo "OPENSSH_PERSONAL_KEY='$OPENSSH_PERSONAL_KEY'" >> $installation_cfg_tmpfile
  if [ -z "$SERVER_TIME_ZONE" ]
  then
    yes_no_function "Do you want to modify timezone of server, default value : ${SETCOLOR_INFO}Europe/Paris${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify timezone of server, actual value : ${SETCOLOR_WARNING}${SERVER_TIME_ZONE}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$SERVER_TIME_ZONE" ]
    then
      while [ -z "$SERVER_TIME_ZONE" ]
      do
        echo -e "Type timezone, followed by [ENTER]:"
        echo -en "> "
        read SERVER_TIME_ZONE
      done
    else
      yes_no_function "Can you confirm you want to modify current timezone ?" "yes"
      if [ $? -eq 0 ]
      then
        SERVER_TIME_ZONE=
        while [ -z "$SERVER_TIME_ZONE" ]
        do
          echo -e "Type timezone, followed by [ENTER]:"
          echo -en "> "
          read SERVER_TIME_ZONE
        done
      else
        SERVER_TIME_ZONE=$SERVER_TIME_ZONE
      fi
    fi
  else
    if [ -z "$SERVER_TIME_ZONE" ]
    then
      SERVER_TIME_ZONE='Europe/Paris'
    else
      SERVER_TIME_ZONE=$SERVER_TIME_ZONE
    fi
  fi
  echo "SERVER_TIME_ZONE='$SERVER_TIME_ZONE'" >> $installation_cfg_tmpfile
  if [ -z "$BOOLEAN_NTP_CONFIGURE" ]
  then
    yes_no_function "Do you want to configure NTP service, default value : ${SETCOLOR_INFO}yes${SETCOLOR_NORMAL} ?" "yes"
  else
    if [ "$BOOLEAN_NTP_CONFIGURE" == 1 ]
    then
      yes_no_function "Do you want to configure NTP service, actual value : ${SETCOLOR_WARNING}yes${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to configure NTP service, actual value : ${SETCOLOR_WARNING}no${SETCOLOR_NORMAL} ?" "no"
    fi
  fi
  if [ $? -eq 0 ]
  then
    BOOLEAN_NTP_CONFIGURE=1
    if [ -z "$NEW_NTP_ADDRESS" ]
    then
      while [ -z "$NEW_NTP_ADDRESS" ]
      do
        echo -e "Type IP address or hostname of NTP server, followed by [ENTER]:"
        echo -en "> "
        read NEW_NTP_ADDRESS
      done
    else
      yes_no_function "Can you confirm you want to modify current NTP server ?" "yes"
      if [ $? -eq 0 ]
      then
        NEW_NTP_ADDRESS=
        while [ -z "$NEW_NTP_ADDRESS" ]
        do
          echo -e "Type IP address or hostname of NTP server, followed by [ENTER]:"
          echo -en "> "
          read NEW_NTP_ADDRESS
        done
      else
        NEW_NTP_ADDRESS=$NEW_NTP_ADDRESS
      fi
    fi
  else
    BOOLEAN_NTP_CONFIGURE=0
    NEW_NTP_ADDRESS=
  fi
  echo "BOOLEAN_NTP_CONFIGURE=$BOOLEAN_NTP_CONFIGURE" >> $installation_cfg_tmpfile
  echo "NEW_NTP_ADDRESS='$NEW_NTP_ADDRESS'" >> $installation_cfg_tmpfile
  if [ -z "$BOOLEAN_NTP_ONSTARTUP" ]
  then
    yes_no_function "Do you want to add NTP service on startup, default value : ${SETCOLOR_INFO}on${SETCOLOR_NORMAL} ?" "yes"
  else
    if [ "$BOOLEAN_NTP_ONSTARTUP" == 1 ]
    then
      yes_no_function "Do you want to add NTP service on startup, actual value : ${SETCOLOR_WARNING}on${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to add NTP service on startup, actual value : ${SETCOLOR_WARNING}off${SETCOLOR_NORMAL} ?" "no"
    fi
  fi
  if [ "$?" == 0 ]
  then
    if [ -z "$BOOLEAN_NTP_ONSTARTUP" ]
    then
      BOOLEAN_NTP_ONSTARTUP=1
    else
      if [ "$BOOLEAN_NTP_ONSTARTUP" == 1 ]
      then
        yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}disable${SETCOLOR_NORMAL} NTP service on startup ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_NTP_ONSTARTUP=0
        else
          BOOLEAN_NTP_ONSTARTUP=$BOOLEAN_NTP_ONSTARTUP
        fi
      else
        yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}enable${SETCOLOR_NORMAL} NTP service on startup ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_NTP_ONSTARTUP=1
        else
          BOOLEAN_NTP_ONSTARTUP=$BOOLEAN_NTP_ONSTARTUP
        fi
      fi
    fi
  else
    BOOLEAN_NTP_ONSTARTUP=0
  fi
  echo "BOOLEAN_NTP_ONSTARTUP=$BOOLEAN_NTP_ONSTARTUP" >> $installation_cfg_tmpfile
  if [ -z "$MONGO_ADMIN_PASSWORD" ]
  then
    yes_no_function "Do you want to modify password of Mongo administrator, default value : ${SETCOLOR_INFO}admin4mongo${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify password of Mongo administrator, actual value : ${SETCOLOR_WARNING}${MONGO_ADMIN_PASSWORD}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$MONGO_ADMIN_PASSWORD" ]
    then
      while [ -z "$MONGO_ADMIN_PASSWORD" ]
      do
        echo -e "Type password of Mongo administrator, followed by [ENTER]:"
        echo -en "> "
        read MONGO_ADMIN_PASSWORD
      done
    else
      yes_no_function "Can you confirm you want to modify current password of Mongo administrator ?" "yes"
      if [ $? -eq 0 ]
      then
        MONGO_ADMIN_PASSWORD=
        while [ -z "$MONGO_ADMIN_PASSWORD" ]
        do
          echo -e "Type password of Mongo administrator, followed by [ENTER]:"
          echo -en "> "
          read MONGO_ADMIN_PASSWORD
        done
      else
        MONGO_ADMIN_PASSWORD=$MONGO_ADMIN_PASSWORD
      fi
    fi
  else
    if [ -z "$MONGO_ADMIN_PASSWORD" ]
    then
      MONGO_ADMIN_PASSWORD='admin4mongo'
    else
      MONGO_ADMIN_PASSWORD=$MONGO_ADMIN_PASSWORD
    fi
  fi
  echo "MONGO_ADMIN_PASSWORD='$MONGO_ADMIN_PASSWORD'" >> $installation_cfg_tmpfile
  if [ -z "$MONGO_GRAYLOG_DATABASE" ]
  then
    yes_no_function "Do you want to modify name of Graylog Mongo database, default value : ${SETCOLOR_INFO}graylog${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify name of Graylog Mongo database, actual value : ${SETCOLOR_WARNING}${MONGO_GRAYLOG_DATABASE}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$MONGO_GRAYLOG_DATABASE" ]
    then
      while [ -z "$MONGO_GRAYLOG_DATABASE" ]
      do
        echo -e "Type name of Graylog Mongo database, followed by [ENTER]:"
        echo -en "> "
        read MONGO_GRAYLOG_DATABASE
      done
    else
      yes_no_function "Can you confirm you want to modify current name of Graylog Mongo database ?" "yes"
      if [ $? -eq 0 ]
      then
        MONGO_GRAYLOG_DATABASE=
        while [ -z "$MONGO_GRAYLOG_DATABASE" ]
        do
          echo -e "Type name of Graylog Mongo database, followed by [ENTER]:"
          echo -en "> "
          read MONGO_GRAYLOG_DATABASE
        done
      else
        MONGO_GRAYLOG_DATABASE=$MONGO_GRAYLOG_DATABASE
      fi
    fi
  else
    if [ -z "$MONGO_GRAYLOG_DATABASE" ]
    then
      MONGO_GRAYLOG_DATABASE='admin4mongo'
    else
      MONGO_GRAYLOG_DATABASE=$MONGO_GRAYLOG_DATABASE
    fi
  fi
  echo "MONGO_GRAYLOG_DATABASE='$MONGO_GRAYLOG_DATABASE'" >> $installation_cfg_tmpfile
  if [ -z "$MONGO_GRAYLOG_USER" ]
  then
    yes_no_function "Do you want to modify login of Mongo Graylog user, default value : ${SETCOLOR_INFO}grayloguser${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify login of Mongo Graylog user, actual value : ${SETCOLOR_WARNING}${MONGO_GRAYLOG_USER}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$MONGO_GRAYLOG_USER" ]
    then
      while [ -z "$MONGO_GRAYLOG_USER" ]
      do
        echo -e "Type login of Graylog Mongo database, followed by [ENTER]:"
        echo -en "> "
        read MONGO_GRAYLOG_USER
      done
    else
      yes_no_function "Can you confirm you want to modify current login of Mongo Graylog user ?" "yes"
      if [ $? -eq 0 ]
      then
        MONGO_GRAYLOG_USER=
        while [ -z "$MONGO_GRAYLOG_USER" ]
        do
          echo -e "Type login of Graylog Mongo database, followed by [ENTER]:"
          echo -en "> "
          read MONGO_GRAYLOG_USER
        done
      else
        MONGO_GRAYLOG_USER=$MONGO_GRAYLOG_USER
      fi
    fi
  else
    if [ -z "$MONGO_GRAYLOG_USER" ]
    then
      MONGO_GRAYLOG_USER='grayloguser'
    else
      MONGO_GRAYLOG_USER=$MONGO_GRAYLOG_USER
    fi
  fi
  echo "MONGO_GRAYLOG_USER='$MONGO_GRAYLOG_USER'" >> $installation_cfg_tmpfile
  if [ -z "$MONGO_GRAYLOG_PASSWORD" ]
  then
    yes_no_function "Do you want to modify password of Graylog Mongo user, default value : ${SETCOLOR_INFO}graylog4mongo${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify password of Graylog Mongo user, actual value : ${SETCOLOR_WARNING}${MONGO_GRAYLOG_PASSWORD}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$MONGO_GRAYLOG_PASSWORD" ]
    then
      while [ -z "$MONGO_GRAYLOG_PASSWORD" ]
      do
        echo -e "Type the login of Graylog Mongo password, followed by [ENTER]:"
        echo -en "> "
        read MONGO_GRAYLOG_PASSWORD
      done
    else
      yes_no_function "Can you confirm you want to modify current password of Graylog Mongo user ?" "yes"
      if [ $? -eq 0 ]
      then
        MONGO_GRAYLOG_PASSWORD=
        while [ -z "$MONGO_GRAYLOG_PASSWORD" ]
        do
          echo -e "Type the login of Graylog Mongo password, followed by [ENTER]:"
          echo -en "> "
          read MONGO_GRAYLOG_PASSWORD
        done
      else
        MONGO_GRAYLOG_PASSWORD=$MONGO_GRAYLOG_PASSWORD
      fi
    fi
  else
    if [ -z "$MONGO_GRAYLOG_PASSWORD" ]
    then
      MONGO_GRAYLOG_PASSWORD='graylog4mongo'
    else
      MONGO_GRAYLOG_PASSWORD=$MONGO_GRAYLOG_PASSWORD
    fi
  fi
  echo "MONGO_GRAYLOG_PASSWORD='$MONGO_GRAYLOG_PASSWORD'" >> $installation_cfg_tmpfile
  if [ -z "$BOOLEAN_MONGO_ONSTARTUP" ]
  then
    yes_no_function "Do you want to add Mongo database server on startup, default value : ${SETCOLOR_INFO}on${SETCOLOR_NORMAL} ?" "yes"
  else
    if [ "$BOOLEAN_MONGO_ONSTARTUP" == 1 ]
    then
      yes_no_function "Do you want to add Mongo database server on startup, actual value : ${SETCOLOR_WARNING}on${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to add Mongo database server on startup, actual value : ${SETCOLOR_WARNING}off${SETCOLOR_NORMAL} ?" "no"
    fi
  fi
  if [ "$?" == 0 ]
  then
    if [ -z "$BOOLEAN_MONGO_ONSTARTUP" ]
    then
      BOOLEAN_MONGO_ONSTARTUP=1
    else
      if [ "$BOOLEAN_MONGO_ONSTARTUP" == 1 ]
      then
        yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}disable${SETCOLOR_NORMAL} Mongo database server on startup ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_MONGO_ONSTARTUP=0
        else
          BOOLEAN_MONGO_ONSTARTUP=$BOOLEAN_MONGO_ONSTARTUP
        fi
      else
        yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}enable${SETCOLOR_NORMAL} Mongo database server on startup ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_MONGO_ONSTARTUP=1
        else
          BOOLEAN_MONGO_ONSTARTUP=$BOOLEAN_MONGO_ONSTARTUP
        fi
      fi
    fi
  else
    BOOLEAN_MONGO_ONSTARTUP=0
  fi
  echo "BOOLEAN_MONGO_ONSTARTUP=$BOOLEAN_MONGO_ONSTARTUP" >> $installation_cfg_tmpfile
  if [ -z "$SSL_KEY_SIZE" ]
  then
    yes_no_function "Do you want to modify size of SSL private key, default value : ${SETCOLOR_INFO}2048${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify size of SSL private key, actual value : ${SETCOLOR_WARNING}${SSL_KEY_SIZE}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$SSL_KEY_SIZE" ]
    then
      while [ -z "$SSL_KEY_SIZE" ] || [[ ! "$SSL_KEY_SIZE" =~ 512|1024|2048|4096 ]]
      do
        echo -e "Type size of SSL private key (possible values : ${SETCOLOR_FAILURE}512${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}1024${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}2048${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}4096${SETCOLOR_NORMAL}), followed by [ENTER]:"
        echo -en "> "
        read SSL_KEY_SIZE
      done
    else
      yes_no_function "Can you confirm you want to modify current size of SSL private key ?" "yes"
      if [ $? -eq 0 ]
      then
        SSL_KEY_SIZE=
        while [ -z "$SSL_KEY_SIZE" ] || [[ ! "$SSL_KEY_SIZE" =~ 512|1024|2048|4096 ]]
        do
          echo -e "Type size of SSL private key (possible values : ${SETCOLOR_FAILURE}512${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}1024${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}2048${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}4096${SETCOLOR_NORMAL}), followed by [ENTER]:"
          echo -en "> "
          read SSL_KEY_SIZE
        done
      else
        SSL_KEY_SIZE=$SSL_KEY_SIZE
      fi
    fi
  else
    if [ -z "$SSL_KEY_SIZE" ]
    then
      SSL_KEY_SIZE=2048
    else
      SSL_KEY_SIZE=$SSL_KEY_SIZE
    fi
  fi
  echo "SSL_KEY_SIZE='$SSL_KEY_SIZE'" >> $installation_cfg_tmpfile
  if [ -z "$SSL_KEY_DURATION" ]
  then
    yes_no_function "Do you want to modify period of validity of SSL Certificate, default value : ${SETCOLOR_INFO}365${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify period of validity of SSL Certificate, actual value : ${SETCOLOR_WARNING}${SSL_KEY_DURATION}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$SSL_KEY_DURATION" ]
    then
      while [ -z "$SSL_KEY_DURATION" ] || [[ ! "$SSL_KEY_DURATION" =~ [0-9]{1,5} ]]
      do
        echo -e "Type period of validity (in day) of SSL certificate, followed by [ENTER]:"
        echo -en "> "
        read SSL_KEY_DURATION
      done
    else
      yes_no_function "Can you confirm you want to modify current period of validity of SSL Certificate ?" "yes"
      if [ $? -eq 0 ]
      then
        SSL_KEY_DURATION=
        while [ -z "$SSL_KEY_DURATION" ] || [[ ! "$SSL_KEY_DURATION" =~ [0-9]{1,5} ]]
        do
          echo -e "Type period of validity (in day) of SSL certificate, followed by [ENTER]:"
          echo -en "> "
          read SSL_KEY_DURATION
        done
      else
        SSL_KEY_DURATION=$SSL_KEY_DURATION
      fi
    fi
  else
    if [ -z "$SSL_KEY_DURATION" ]
    then
      SSL_KEY_DURATION=365
    else
      SSL_KEY_DURATION=$SSL_KEY_DURATION
    fi
  fi
  echo "SSL_KEY_DURATION=$SSL_KEY_DURATION" >> $installation_cfg_tmpfile
  if [ -z "$SSL_SUBJECT_COUNTRY" ]
  then
    yes_no_function "Do you want to modify country code of SSL Certificate, default value : ${SETCOLOR_INFO}FR${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify country code of SSL Certificate, actual value : ${SETCOLOR_WARNING}${SSL_SUBJECT_COUNTRY}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$SSL_SUBJECT_COUNTRY" ]
    then
      while [ -z "$SSL_SUBJECT_COUNTRY" ] || [[ ! "$SSL_SUBJECT_COUNTRY" =~ [A-Z]{2} ]]
      do
        echo -e "Type country code of SSL certificate, followed by [ENTER]:"
        echo -en "> "
        read SSL_SUBJECT_COUNTRY
      done
    else
      yes_no_function "Can you confirm you want to modify current country code of SSL Certificate ?" "yes"
      if [ $? -eq 0 ]
      then
        SSL_SUBJECT_COUNTRY=
        while [ -z "$SSL_SUBJECT_COUNTRY" ] || [[ ! "$SSL_SUBJECT_COUNTRY" =~ [A-Z]{2} ]]
        do
          echo -e "Type country code of SSL certificate, followed by [ENTER]:"
          echo -en "> "
          read SSL_SUBJECT_COUNTRY
        done
      else
        SSL_SUBJECT_COUNTRY=$SSL_SUBJECT_COUNTRY
      fi
    fi
  else
    if [ -z "$SSL_SUBJECT_COUNTRY" ]
    then
      SSL_SUBJECT_COUNTRY='FR'
    else
      SSL_SUBJECT_COUNTRY=$SSL_SUBJECT_COUNTRY
    fi
  fi
  echo "SSL_SUBJECT_COUNTRY='$SSL_SUBJECT_COUNTRY'" >> $installation_cfg_tmpfile
  if [ -z "$SSL_SUBJECT_STATE" ]
  then
    yes_no_function "Do you want to modify state of SSL Certificate, default value : ${SETCOLOR_INFO}STATE${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify state of SSL Certificate, actual value : ${SETCOLOR_WARNING}${SSL_SUBJECT_STATE}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$SSL_SUBJECT_STATE" ]
    then
      while [ -z "$SSL_SUBJECT_STATE" ]
      do
        echo -e "Type state of SSL certificate, followed by [ENTER]:"
        echo -en "> "
        read SSL_SUBJECT_STATE
      done
    else
      yes_no_function "Can you confirm you want to modify current state of SSL Certificate ?" "yes"
      if [ $? -eq 0 ]
      then
        SSL_SUBJECT_STATE=
        while [ -z "$SSL_SUBJECT_STATE" ]
        do
          echo -e "Type state of SSL certificate, followed by [ENTER]:"
          echo -en "> "
          read SSL_SUBJECT_STATE
        done
      else
        SSL_SUBJECT_STATE=$SSL_SUBJECT_STATE
      fi
    fi
  else
    if [ -z "$SSL_SUBJECT_STATE" ]
    then
      SSL_SUBJECT_STATE='STATE'
    else
      SSL_SUBJECT_STATE=$SSL_SUBJECT_STATE
    fi
  fi
  echo "SSL_SUBJECT_STATE='$SSL_SUBJECT_STATE'" >> $installation_cfg_tmpfile
  if [ -z "$SSL_SUBJECT_LOCALITY" ]
  then
    yes_no_function "Do you want to modify locality of SSL Certificate, default value : ${SETCOLOR_INFO}LOCALITY${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify locality of SSL Certificate, actual value : ${SETCOLOR_WARNING}${SSL_SUBJECT_LOCALITY}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$SSL_SUBJECT_LOCALITY" ]
    then
      while [ -z "$SSL_SUBJECT_LOCALITY" ]
      do
        echo -e "Type locality of SSL certificate, followed by [ENTER]:"
        echo -en "> "
        read SSL_SUBJECT_LOCALITY
      done
    else
      yes_no_function "Can you confirm you want to modify current locality of SSL Certificate ?" "yes"
      if [ $? -eq 0 ]
      then
        SSL_SUBJECT_LOCALITY=
        while [ -z "$SSL_SUBJECT_LOCALITY" ]
        do
          echo -e "Type locality of SSL certificate, followed by [ENTER]:"
          echo -en "> "
          read SSL_SUBJECT_LOCALITY
        done
      else
        SSL_SUBJECT_LOCALITY=$SSL_SUBJECT_LOCALITY
      fi
    fi
  else
    if [ -z "$SSL_SUBJECT_LOCALITY" ]
    then
      SSL_SUBJECT_LOCALITY='LOCALITY'
    else
      SSL_SUBJECT_LOCALITY=$SSL_SUBJECT_LOCALITY
    fi
  fi
  echo "SSL_SUBJECT_LOCALITY='$SSL_SUBJECT_LOCALITY'" >> $installation_cfg_tmpfile
  if [ -z "$SSL_SUBJECT_ORGANIZATION" ]
  then
    yes_no_function "Do you want to modify organization name of SSL Certificate, default value : ${SETCOLOR_INFO}Organisation${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify organization name of SSL Certificate, actual value : ${SETCOLOR_WARNING}${SSL_SUBJECT_ORGANIZATION}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$SSL_SUBJECT_ORGANIZATION" ]
    then
      while [ -z "$SSL_SUBJECT_ORGANIZATION" ]
      do
        echo -e "Type organization name of SSL certificate, followed by [ENTER]:"
        echo -en "> "
        read SSL_SUBJECT_ORGANIZATION
      done
    else
      yes_no_function "Can you confirm you want to modify current organization name of SSL Certificate ?" "yes"
      if [ $? -eq 0 ]
      then
        SSL_SUBJECT_ORGANIZATION=
        while [ -z "$SSL_SUBJECT_ORGANIZATION" ]
        do
          echo -e "Type organization name of SSL certificate, followed by [ENTER]:"
          echo -en "> "
          read SSL_SUBJECT_ORGANIZATION
        done
      else
        SSL_SUBJECT_ORGANIZATION=$SSL_SUBJECT_ORGANIZATION
      fi
    fi
  else
    if [ -z "$SSL_SUBJECT_ORGANIZATION" ]
    then
      SSL_SUBJECT_ORGANIZATION='Organisation'
    else
      SSL_SUBJECT_ORGANIZATION=$SSL_SUBJECT_ORGANIZATION
    fi
  fi
  echo "SSL_SUBJECT_ORGANIZATION='$SSL_SUBJECT_ORGANIZATION'" >> $installation_cfg_tmpfile
  if [ -z "$SSL_SUBJECT_ORGANIZATIONUNIT" ]
  then
    yes_no_function "Do you want to modify organization unit name of SSL Certificate, default value : ${SETCOLOR_INFO}Organisation Unit${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify organization unit name of SSL Certificate, actual value : ${SETCOLOR_WARNING}${SSL_SUBJECT_ORGANIZATIONUNIT}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$SSL_SUBJECT_ORGANIZATIONUNIT" ]
    then
      while [ -z "$SSL_SUBJECT_ORGANIZATIONUNIT" ]
      do
        echo -e "Type organization unit name of SSL certificate, followed by [ENTER]:"
        echo -en "> "
        read SSL_SUBJECT_ORGANIZATIONUNIT
      done
    else
      yes_no_function "Can you confirm you want to modify current organization unit name of SSL Certificate ?" "yes"
      if [ $? -eq 0 ]
      then
        SSL_SUBJECT_ORGANIZATIONUNIT=
        while [ -z "$SSL_SUBJECT_ORGANIZATIONUNIT" ]
        do
          echo -e "Type organization unit name of SSL certificate, followed by [ENTER]:"
          echo -en "> "
          read SSL_SUBJECT_ORGANIZATIONUNIT
        done
      else
        SSL_SUBJECT_ORGANIZATIONUNIT=$SSL_SUBJECT_ORGANIZATIONUNIT
      fi
    fi
  else
    if [ -z "$SSL_SUBJECT_ORGANIZATIONUNIT" ]
    then
      SSL_SUBJECT_ORGANIZATIONUNIT='Organisation Unit'
    else
      SSL_SUBJECT_ORGANIZATIONUNIT=$SSL_SUBJECT_ORGANIZATIONUNIT
    fi
  fi
  echo "SSL_SUBJECT_ORGANIZATIONUNIT='$SSL_SUBJECT_ORGANIZATIONUNIT'" >> $installation_cfg_tmpfile
  if [ -z "$SSL_SUBJECT_EMAIL" ]
  then
    yes_no_function "Do you want to modify e-mail address of SSL Certificate, default value : ${SETCOLOR_INFO}mail.address@test.fr${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify e-mail address of SSL Certificate, actual value : ${SETCOLOR_WARNING}${SSL_SUBJECT_EMAIL}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$SSL_SUBJECT_EMAIL" ]
    then
      while [ -z "$SSL_SUBJECT_EMAIL" ]
      do
        echo -e "Type e-mail address of SSL certificate, followed by [ENTER]:"
        echo -en "> "
        read SSL_SUBJECT_EMAIL
      done
    else
      yes_no_function "Can you confirm you want to modify current e-mail address of SSL Certificate ?" "yes"
      if [ $? -eq 0 ]
      then
        SSL_SUBJECT_EMAIL=
        while [ -z "$SSL_SUBJECT_EMAIL" ]
        do
          echo -e "Type e-mail address of SSL certificate, followed by [ENTER]:"
          echo -en "> "
          read SSL_SUBJECT_EMAIL
        done
      else
        SSL_SUBJECT_EMAIL=$SSL_SUBJECT_EMAIL
      fi
    fi
  else
    if [ -z "$SSL_SUBJECT_EMAIL" ]
    then
      SSL_SUBJECT_EMAIL='mail.address@test.fr'
    else
      SSL_SUBJECT_EMAIL=$SSL_SUBJECT_EMAIL
    fi
  fi
  echo "SSL_SUBJECT_EMAIL='$SSL_SUBJECT_EMAIL'" >> $installation_cfg_tmpfile
  if [ -z "$BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN" ]
  then
    yes_no_function "Do you want to install HQ plugin to manage ElasticSearch, default value : ${SETCOLOR_INFO}yes${SETCOLOR_NORMAL} ?" "yes"
  else
    if [ "$BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN" == 1 ]
    then
      yes_no_function "Do you want to install HQ plugin to manage ElasticSearch, actual value : ${SETCOLOR_WARNING}yes${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to install HQ plugin to manage ElasticSearch, actual value : ${SETCOLOR_WARNING}no${SETCOLOR_NORMAL} ?" "no"
    fi
  fi
  if [ "$?" == 0 ]
  then
    if [ -z "$BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN" ]
    then
      BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN=1
    else
      if [ "$BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN" == 1 ]
      then
        yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}not install${SETCOLOR_NORMAL} HQ plugin ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN=0
        else
          BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN=$BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN
        fi
      else
        yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}install${SETCOLOR_NORMAL} HQ plugin ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN=1
        else
          BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN=$BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN
        fi
      fi
    fi
  else
    BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN=0
  fi
  echo "BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN=$BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN" >> $installation_cfg_tmpfile
  if [ -z "$BOOLEAN_ELASTICSEARCH_ONSTARTUP" ]
  then
    yes_no_function "Do you want to add ElasticSearch server on startup, default value : ${SETCOLOR_INFO}on${SETCOLOR_NORMAL} ?" "yes"
  else
    if [ "$BOOLEAN_ELASTICSEARCH_ONSTARTUP" == 1 ]
    then
      yes_no_function "Do you want to add ElasticSearch server on startup, actual value : ${SETCOLOR_WARNING}on${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to add ElasticSearch server on startup, actual value : ${SETCOLOR_WARNING}off${SETCOLOR_NORMAL} ?" "no"
    fi
  fi
  if [ "$?" == 0 ]
  then
    if [ -z "$BOOLEAN_ELASTICSEARCH_ONSTARTUP" ]
    then
      BOOLEAN_ELASTICSEARCH_ONSTARTUP=1
    else
      if [ "$BOOLEAN_ELASTICSEARCH_ONSTARTUP" == 1 ]
      then
        yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}disable${SETCOLOR_NORMAL} ElasticSearch server on startup ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_ELASTICSEARCH_ONSTARTUP=0
        else
          BOOLEAN_ELASTICSEARCH_ONSTARTUP=$BOOLEAN_ELASTICSEARCH_ONSTARTUP
        fi
      else
        yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}enable${SETCOLOR_NORMAL} ElasticSearch server on startup ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_ELASTICSEARCH_ONSTARTUP=1
        else
          BOOLEAN_ELASTICSEARCH_ONSTARTUP=$BOOLEAN_ELASTICSEARCH_ONSTARTUP
        fi
      fi
    fi
  else
    BOOLEAN_ELASTICSEARCH_ONSTARTUP=0
  fi
  echo "BOOLEAN_ELASTICSEARCH_ONSTARTUP=$BOOLEAN_ELASTICSEARCH_ONSTARTUP" >> $installation_cfg_tmpfile
  if [ -z "$GRAYLOG_SECRET_PASSWORD" ]
  then
    yes_no_function "Do you want to modify secret password of Graylog application, default value : ${SETCOLOR_INFO}secretpassword${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify secret password of Graylog application, actual value : ${SETCOLOR_WARNING}${GRAYLOG_SECRET_PASSWORD}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$GRAYLOG_SECRET_PASSWORD" ]
    then
      while [ -z "$GRAYLOG_SECRET_PASSWORD" ]
      do
        echo -e "Type secret password of Graylog application, followed by [ENTER]:"
        echo -en "> "
        read GRAYLOG_SECRET_PASSWORD
      done
    else
      yes_no_function "Can you confirm you want to modify current secret password of Graylog application ?" "yes"
      if [ $? -eq 0 ]
      then
        GRAYLOG_SECRET_PASSWORD=
        while [ -z "$GRAYLOG_SECRET_PASSWORD" ]
        do
          echo -e "Type secret password of Graylog application, followed by [ENTER]:"
          echo -en "> "
          read GRAYLOG_SECRET_PASSWORD
        done
      else
        GRAYLOG_SECRET_PASSWORD=$GRAYLOG_SECRET_PASSWORD
      fi
    fi
  else
    if [ -z "$GRAYLOG_SECRET_PASSWORD" ]
    then
      GRAYLOG_SECRET_PASSWORD='secretpassword'
    else
      GRAYLOG_SECRET_PASSWORD=$GRAYLOG_SECRET_PASSWORD
    fi
  fi
  echo "GRAYLOG_SECRET_PASSWORD='$GRAYLOG_SECRET_PASSWORD'" >> $installation_cfg_tmpfile
  if [ -z "$GRAYLOG_ADMIN_USERNAME" ]
  then
    yes_no_function "Do you want to modify login of Graylog administrator user, default value : ${SETCOLOR_INFO}admin${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify login of Graylog administrator, actual value : ${SETCOLOR_WARNING}${GRAYLOG_ADMIN_USERNAME}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$GRAYLOG_ADMIN_USERNAME" ]
    then
      while [ -z "$GRAYLOG_ADMIN_USERNAME" ]
      do
        echo -e "Type login of Graylog administrator, followed by [ENTER]:"
        echo -en "> "
        read GRAYLOG_ADMIN_USERNAME
      done
    else
      yes_no_function "Can you confirm you want to modify current login of Graylog administrator ?" "yes"
      if [ $? -eq 0 ]
      then
        GRAYLOG_ADMIN_USERNAME=
        while [ -z "$GRAYLOG_ADMIN_USERNAME" ]
        do
          echo -e "Type login of Graylog administrator, followed by [ENTER]:"
          echo -en "> "
          read GRAYLOG_ADMIN_USERNAME
        done
      else
        GRAYLOG_ADMIN_USERNAME=$GRAYLOG_ADMIN_USERNAME
      fi
    fi
  else
    if [ -z "$GRAYLOG_ADMIN_USERNAME" ]
    then
      GRAYLOG_ADMIN_USERNAME='admin'
    else
      GRAYLOG_ADMIN_USERNAME=$GRAYLOG_ADMIN_USERNAME
    fi
  fi
  echo "GRAYLOG_ADMIN_USERNAME='$GRAYLOG_ADMIN_USERNAME'" >> $installation_cfg_tmpfile
  if [ -z "$GRAYLOG_ADMIN_PASSWORD" ]
  then
    yes_no_function "Do you want to modify password of Graylog administrator, default value : ${SETCOLOR_INFO}adminpassword${SETCOLOR_NORMAL} ?" "yes"
  else
    yes_no_function "Do you want to modify password of Graylog administrator, actual value : ${SETCOLOR_WARNING}${GRAYLOG_ADMIN_PASSWORD}${SETCOLOR_NORMAL} ?" "no"
  fi
  if [ $? -eq 0 ]
  then
    if [ -z "$GRAYLOG_ADMIN_PASSWORD" ]
    then
      while [ -z "$GRAYLOG_ADMIN_PASSWORD" ]
      do
        echo -e "Type password of Graylog administrator, followed by [ENTER]:"
        echo -en "> "
        read GRAYLOG_ADMIN_PASSWORD
      done
    else
      yes_no_function "Can you confirm you want to modify current password of Graylog administrator ?" "yes"
      if [ $? -eq 0 ]
      then
        GRAYLOG_ADMIN_PASSWORD=
        while [ -z "$GRAYLOG_ADMIN_PASSWORD" ]
        do
          echo -e "Type password of Graylog administrator, followed by [ENTER]:"
          echo -en "> "
          read GRAYLOG_ADMIN_PASSWORD
        done
      else
        GRAYLOG_ADMIN_PASSWORD=$GRAYLOG_ADMIN_PASSWORD
      fi
    fi
  else
    if [ -z "$GRAYLOG_ADMIN_PASSWORD" ]
    then
      GRAYLOG_ADMIN_PASSWORD='adminpassword'
    else
      GRAYLOG_ADMIN_PASSWORD=$GRAYLOG_ADMIN_PASSWORD
    fi
  fi
  echo "GRAYLOG_ADMIN_PASSWORD='$GRAYLOG_ADMIN_PASSWORD'" >> $installation_cfg_tmpfile

  if [ -z "$GRAYLOG_USE_SMTP" ]
  then
    yes_no_function "Do you want to use Simple Mail Transport Protocol (SMTP) for Graylog, default value : ${SETCOLOR_INFO}yes${SETCOLOR_NORMAL} ?" "yes"
  else
    if [ "$GRAYLOG_USE_SMTP" == 1 ]
    then
      yes_no_function "Do you want to use Simple Mail Transport Protocol (SMTP) for Graylog, actual value : ${SETCOLOR_WARNING}yes${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to use Simple Mail Transport Protocol (SMTP) for Graylog, actual value : ${SETCOLOR_WARNING}no${SETCOLOR_NORMAL} ?" "no"
    fi
  fi
  if [ "$?" == 0 ]
  then
    if [ -z "$GRAYLOG_USE_SMTP" ]
    then
      GRAYLOG_USE_SMTP=1
    else
      if [ "$GRAYLOG_USE_SMTP" == 1 ]
      then
        yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}not use${SETCOLOR_NORMAL} SMTP for Graylog ?" "yes"
        if [ "$?" == 0 ]
        then
          GRAYLOG_USE_SMTP=0
        else
          GRAYLOG_USE_SMTP=$GRAYLOG_USE_SMTP
        fi
      else
        yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}use${SETCOLOR_NORMAL} SMTP for Graylog ?" "yes"
        if [ "$?" == 0 ]
        then
          GRAYLOG_USE_SMTP=1
        else
          GRAYLOG_USE_SMTP=$GRAYLOG_USE_SMTP
        fi
      fi
    fi
  else
    GRAYLOG_USE_SMTP=0
  fi
  if [ "GRAYLOG_USE_SMTP" == 1 ]
  then
    if [ -z "$SMTP_HOST_NAME" ]
    then
      yes_no_function "Do you want to modify fully qualified domain name (FQDN) of SMTP server, default value : ${SETCOLOR_INFO}mail.example.com${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to modify fully qualified domain name (FQDN) of SMTP server, actual value : ${SETCOLOR_WARNING}${SMTP_HOST_NAME}${SETCOLOR_NORMAL} ?" "no"
    fi
    if [ $? -eq 0 ]
    then
      if [ -z "$SMTP_HOST_NAME" ]
      then
        while [ -z "$SMTP_HOST_NAME" ]
        do
          echo -e "Type FQDN of SMTP server, followed by [ENTER]:"
          echo -en "> "
          read SMTP_HOST_NAME
        done
      else
        yes_no_function "Can you confirm you want to modify current FQDN of SMTP server ?" "yes"
        if [ $? -eq 0 ]
        then
          SMTP_HOST_NAME=
          while [ -z "$SMTP_HOST_NAME" ]
          do
            echo -e "Type FQDN of SMTP server, followed by [ENTER]:"
            echo -en "> "
            read SMTP_HOST_NAME
          done
        else
          SMTP_HOST_NAME=$SMTP_HOST_NAME
        fi
      fi
    else
      if [ -z "$SMTP_HOST_NAME" ]
      then
        SMTP_HOST_NAME='mail.example.com'
      else
        SMTP_HOST_NAME=$SMTP_HOST_NAME
      fi
    fi
    if [ -z "$SMTP_DOMAIN_NAME" ]
    then
      yes_no_function "Do you want to modify SMTP domain name, default value : ${SETCOLOR_INFO}example.com${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to modify SMTP domain name, actual value : ${SETCOLOR_WARNING}${SMTP_DOMAIN_NAME}${SETCOLOR_NORMAL} ?" "no"
    fi
    if [ $? -eq 0 ]
    then
      if [ -z "$SMTP_DOMAIN_NAME" ]
      then
        while [ -z "$SMTP_DOMAIN_NAME" ]
        do
          echo -e "Type SMTP domain name, followed by [ENTER]:"
          echo -en "> "
          read SMTP_DOMAIN_NAME
        done
      else
        yes_no_function "Can you confirm you want to modify current SMTP domain name ?" "yes"
        if [ $? -eq 0 ]
        then
          SMTP_DOMAIN_NAME=
          while [ -z "$SMTP_DOMAIN_NAME" ]
          do
            echo -e "Type SMTP domain name, followed by [ENTER]:"
            echo -en "> "
            read SMTP_DOMAIN_NAME
          done
        else
          SMTP_DOMAIN_NAME=$SMTP_DOMAIN_NAME
        fi
      fi
    else
      if [ -z "$SMTP_DOMAIN_NAME" ]
      then
        SMTP_DOMAIN_NAME='example.com'
      else
        SMTP_DOMAIN_NAME=$SMTP_DOMAIN_NAME
      fi
    fi
    
    if [ -z "$SMTP_PORT_NUMBER" ]
    then
      yes_no_function "Do you want to modify SMTP port number, default value : ${SETCOLOR_INFO}587${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to modify SMTP port number, actual value : ${SETCOLOR_WARNING}${SMTP_PORT_NUMBER}${SETCOLOR_NORMAL} ?" "no"
    fi
    if [ $? -eq 0 ]
    then
      if [ -z "$SMTP_PORT_NUMBER" ]
      then
        while [ -z "$SMTP_PORT_NUMBER" ] || [[ ! "$SMTP_PORT_NUMBER" =~ 25|465|587 ]]
        do
          echo -e "Type SMTP port number (possible values : ${SETCOLOR_FAILURE}25${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}465${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}587${SETCOLOR_NORMAL}), followed by [ENTER]:"
          echo -en "> "
          read SMTP_PORT_NUMBER
        done
      else
        yes_no_function "Can you confirm you want to modify current SMTP port number ?" "yes"
        if [ $? -eq 0 ]
        then
          SMTP_PORT_NUMBER=
          while [ -z "$SMTP_PORT_NUMBER" ] || [[ ! "$SMTP_PORT_NUMBER" =~ 25|465|587 ]]
          do
            echo -e "Type SMTP port number (possible values : ${SETCOLOR_FAILURE}25${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}465${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}587${SETCOLOR_NORMAL}), followed by [ENTER]:"
            echo -en "> "
            read SMTP_PORT_NUMBER
          done
        else
          SMTP_PORT_NUMBER=$SMTP_PORT_NUMBER
        fi
      fi
    else
      if [ -z "$SMTP_PORT_NUMBER" ]
      then
        SMTP_PORT_NUMBER='587'
      else
        SMTP_PORT_NUMBER=$SMTP_PORT_NUMBER
      fi
    fi
    if [ -z "$SMTP_USE_AUTH" ]
    then
      yes_no_function "Do you want to use SMTP authentication, default value : ${SETCOLOR_INFO}yes${SETCOLOR_NORMAL} ?" "yes"
    else
      if [ "$SMTP_USE_AUTH" == 1 ]
      then
        yes_no_function "Do you want to use SMTP authentication, actual value : ${SETCOLOR_WARNING}yes${SETCOLOR_NORMAL} ?" "yes"
      else
        yes_no_function "Do you want to use SMTP authentication, actual value : ${SETCOLOR_WARNING}no${SETCOLOR_NORMAL} ?" "no"
      fi
    fi
    if [ "$?" == 0 ]
    then
      if [ -z "$SMTP_USE_AUTH" ]
      then
        SMTP_USE_AUTH=1
      else
        if [ "$SMTP_USE_AUTH" == 1 ]
        then
          yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}not use${SETCOLOR_NORMAL} SMTP authentication ?" "yes"
          if [ "$?" == 0 ]
          then
            SMTP_USE_AUTH=0
          else
            SMTP_USE_AUTH=$SMTP_USE_AUTH
          fi
        else
          yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}use${SETCOLOR_NORMAL} SMTP authentication ?" "yes"
          if [ "$?" == 0 ]
          then
            SMTP_USE_AUTH=1
          else
            SMTP_USE_AUTH=$SMTP_USE_AUTH
          fi
        fi
      fi
    else
      SMTP_USE_AUTH=0
    fi
    if [ "$SMTP_USE_AUTH" == 1 ]
    then
      if [ -z "$SMTP_USE_TLS" ]
      then
        yes_no_function "Do you want to use TLS for SMTP, default value : ${SETCOLOR_INFO}yes${SETCOLOR_NORMAL} ?" "yes"
      else
        if [ "$SMTP_USE_TLS" == 1 ]
        then
          yes_no_function "Do you want to use TLS for SMTP, actual value : ${SETCOLOR_WARNING}yes${SETCOLOR_NORMAL} ?" "yes"
        else
          yes_no_function "Do you want to use TLS for SMTP, actual value : ${SETCOLOR_WARNING}no${SETCOLOR_NORMAL} ?" "no"
        fi
      fi
      if [ "$?" == 0 ]
      then
        if [ -z "$SMTP_USE_TLS" ]
        then
          SMTP_USE_TLS=1
        else
          if [ "$SMTP_USE_TLS" == 1 ]
          then
            yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}not use${SETCOLOR_NORMAL} SMTP over TLS ?" "yes"
            if [ "$?" == 0 ]
            then
              SMTP_USE_TLS=0
            else
              SMTP_USE_TLS=$SMTP_USE_TLS
            fi
          else
            yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}use${SETCOLOR_NORMAL} SMTP over TLS ?" "yes"
            if [ "$?" == 0 ]
            then
              SMTP_USE_TLS=1
            else
              SMTP_USE_TLS=$SMTP_USE_TLS
            fi
          fi
        fi
      else
        SMTP_USE_TLS=0
      fi
      if [ -z "$SMTP_USE_SSL" ]
      then
        yes_no_function "Do you want to use SSL for SMTP, default value : ${SETCOLOR_INFO}yes${SETCOLOR_NORMAL} ?" "yes"
      else
        if [ "$SMTP_USE_SSL" == 1 ]
        then
          yes_no_function "Do you want to use SSL for SMTP, actual value : ${SETCOLOR_WARNING}yes${SETCOLOR_NORMAL} ?" "yes"
        else
          yes_no_function "Do you want to use SSL for SMTP, actual value : ${SETCOLOR_WARNING}no${SETCOLOR_NORMAL} ?" "no"
        fi
      fi
      if [ "$?" == 0 ]
      then
        if [ -z "$SMTP_USE_SSL" ]
        then
          SMTP_USE_SSL=1
        else
          if [ "$SMTP_USE_SSL" == 1 ]
          then
            yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}not use${SETCOLOR_NORMAL} SMTP over SSL ?" "yes"
            if [ "$?" == 0 ]
            then
              SMTP_USE_SSL=0
            else
              SMTP_USE_SSL=$SMTP_USE_SSL
            fi
          else
            yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}use${SETCOLOR_NORMAL} SMTP over SSL ?" "yes"
            if [ "$?" == 0 ]
            then
              SMTP_USE_SSL=1
            else
              SMTP_USE_SSL=$SMTP_USE_SSL
            fi
          fi
        fi
      else
        SMTP_USE_SSL=0
      fi
      if [ -z "$SMTP_AUTH_USERNAME" ]
      then
        yes_no_function "Do you want to modify username of SMTP authentication, default value : ${SETCOLOR_INFO}you@example.com${SETCOLOR_NORMAL} ?" "yes"
      else
        yes_no_function "Do you want to modify username of SMTP authentication, actual value : ${SETCOLOR_WARNING}${SMTP_AUTH_USERNAME}${SETCOLOR_NORMAL} ?" "no"
      fi
      if [ $? -eq 0 ]
      then
        if [ -z "$SMTP_AUTH_USERNAME" ]
        then
          while [ -z "$SMTP_AUTH_USERNAME" ]
          do
            echo -e "Type username of SMTP authentication, followed by [ENTER]:"
            echo -en "> "
            read SMTP_AUTH_USERNAME
          done
        else
          yes_no_function "Can you confirm you want to modify current username of SMTP authentication ?" "yes"
          if [ $? -eq 0 ]
          then
            SMTP_AUTH_USERNAME=
            while [ -z "$SMTP_AUTH_USERNAME" ]
            do
              echo -e "Type username of SMTP authentication, followed by [ENTER]:"
              echo -en "> "
              read SMTP_AUTH_USERNAME
            done
          else
            SMTP_AUTH_USERNAME=$SMTP_AUTH_USERNAME
          fi
        fi
      else
        if [ -z "$SMTP_AUTH_USERNAME" ]
        then
          SMTP_AUTH_USERNAME='you@example.com'
        else
          SMTP_AUTH_USERNAME=$SMTP_AUTH_USERNAME
        fi
      fi
      if [ -z "$SMTP_AUTH_PASSWORD" ]
      then
        yes_no_function "Do you want to modify password of SMTP authentication, default value : ${SETCOLOR_INFO}secret${SETCOLOR_NORMAL} ?" "yes"
      else
        yes_no_function "Do you want to modify password of SMTP authentication, actual value : ${SETCOLOR_WARNING}${SMTP_AUTH_PASSWORD}${SETCOLOR_NORMAL} ?" "no"
      fi
      if [ $? -eq 0 ]
      then
        if [ -z "$SMTP_AUTH_PASSWORD" ]
        then
          while [ -z "$SMTP_AUTH_PASSWORD" ]
          do
            echo -e "Type password of SMTP authentication, followed by [ENTER]:"
            echo -en "> "
            read SMTP_AUTH_PASSWORD
          done
        else
          yes_no_function "Can you confirm you want to modify current password of SMTP authentication ?" "yes"
          if [ $? -eq 0 ]
          then
            SMTP_AUTH_PASSWORD=
            while [ -z "$SMTP_AUTH_PASSWORD" ]
            do
              echo -e "Type password of SMTP authentication, followed by [ENTER]:"
              echo -en "> "
              read SMTP_AUTH_PASSWORD
            done
          else
            SMTP_AUTH_PASSWORD=$SMTP_AUTH_PASSWORD
          fi
        fi
      else
        if [ -z "$SMTP_AUTH_PASSWORD" ]
        then
          SMTP_AUTH_PASSWORD='secret'
        else
          SMTP_AUTH_PASSWORD=$SMTP_AUTH_PASSWORD
        fi
      fi
    else
      SMTP_USE_AUTH='false'
      SMTP_USE_TLS='false'
      SMTP_USE_SSL='false'
      SMTP_AUTH_USERNAME='you@example.com'
      SMTP_AUTH_PASSWORD='secret'
    fi
  else
    GRAYLOG_USE_SMTP='false'
    SMTP_HOST_NAME='mail.example.com'
    SMTP_DOMAIN_NAME='example.com'
    SMTP_PORT_NUMBER=587
    SMTP_USE_AUTH='false'
    SMTP_USE_TLS='false'
    SMTP_USE_SSL='false'
    SMTP_AUTH_USERNAME='you@example.com'
    SMTP_AUTH_PASSWORD='secret'
  fi
  echo "GRAYLOG_USE_SMTP=$GRAYLOG_USE_SMTP" >> $installation_cfg_tmpfile
  echo "SMTP_HOST_NAME='$SMTP_HOST_NAME'" >> $installation_cfg_tmpfile
  echo "SMTP_DOMAIN_NAME='$SMTP_DOMAIN_NAME'" >> $installation_cfg_tmpfile
  echo "SMTP_PORT_NUMBER='$SMTP_PORT_NUMBER'" >> $installation_cfg_tmpfile
  echo "SMTP_USE_AUTH=$SMTP_USE_AUTH" >> $installation_cfg_tmpfile
  echo "SMTP_USE_TLS=$SMTP_USE_TLS" >> $installation_cfg_tmpfile
  echo "SMTP_USE_SSL=$SMTP_USE_SSL" >> $installation_cfg_tmpfile
  echo "SMTP_AUTH_USERNAME='$SMTP_AUTH_USERNAME'" >> $installation_cfg_tmpfile
  echo "SMTP_AUTH_PASSWORD='$SMTP_AUTH_PASSWORD'" >> $installation_cfg_tmpfile
  if [ -z "$BOOLEAN_GRAYLOGSERVER_ONSTARTUP" ]
  then
    yes_no_function "Do you want to add Graylog server on startup, default value : ${SETCOLOR_INFO}on${SETCOLOR_NORMAL} ?" "yes"
  else
    if [ "$BOOLEAN_GRAYLOGSERVER_ONSTARTUP" == 1 ]
    then
      yes_no_function "Do you want to add Graylog server on startup, actual value : ${SETCOLOR_WARNING}on${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to add Graylog server on startup, actual value : ${SETCOLOR_WARNING}off${SETCOLOR_NORMAL} ?" "no"
    fi
  fi
  if [ "$?" == 0 ]
  then
    if [ -z "$BOOLEAN_GRAYLOGSERVER_ONSTARTUP" ]
    then
      BOOLEAN_GRAYLOGSERVER_ONSTARTUP=1
    else
      if [ "$BOOLEAN_GRAYLOGSERVER_ONSTARTUP" == 1 ]
      then
        yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}disable${SETCOLOR_NORMAL} Graylog server on startup ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_GRAYLOGSERVER_ONSTARTUP=0
        else
          BOOLEAN_GRAYLOGSERVER_ONSTARTUP=$BOOLEAN_GRAYLOGSERVER_ONSTARTUP
        fi
      else
        yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}enable${SETCOLOR_NORMAL} Graylog server on startup ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_GRAYLOGSERVER_ONSTARTUP=1
        else
          BOOLEAN_GRAYLOGSERVER_ONSTARTUP=$BOOLEAN_GRAYLOGSERVER_ONSTARTUP
        fi
      fi
    fi
  else
    BOOLEAN_GRAYLOGSERVER_ONSTARTUP=0
  fi
  echo "BOOLEAN_GRAYLOGSERVER_ONSTARTUP=$BOOLEAN_GRAYLOGSERVER_ONSTARTUP" >> $installation_cfg_tmpfile
  if [ -z "$BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP" ]
  then
    yes_no_function "Do you want to add Graylog web interface on startup, default value : ${SETCOLOR_INFO}on${SETCOLOR_NORMAL} ?" "yes"
  else
    if [ "$BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP" == 1 ]
    then
      yes_no_function "Do you want to add Graylog web interface on startup, actual value : ${SETCOLOR_WARNING}on${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to add Graylog web interface on startup, actual value : ${SETCOLOR_WARNING}off${SETCOLOR_NORMAL} ?" "no"
    fi
  fi
  if [ "$?" == 0 ]
  then
    if [ -z "$BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP" ]
    then
      BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP=1
    else
      if [ "$BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP" == 1 ]
      then
        yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}disable${SETCOLOR_NORMAL} Graylog web interface on startup ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP=0
        else
          BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP=$BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP
        fi
      else
        yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}enable${SETCOLOR_NORMAL} Graylog web interface on startup ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP=1
        else
          BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP=$BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP
        fi
      fi
    fi
  else
    BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP=0
  fi
  echo "BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP=$BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP" >> $installation_cfg_tmpfile
  if [ -z "$BOOLEAN_NGINX_ONSTARTUP" ]
  then
    yes_no_function "Do you want to add Nginx web server on startup, default value : ${SETCOLOR_INFO}on${SETCOLOR_NORMAL} ?" "yes"
  else
    if [ "$BOOLEAN_NGINX_ONSTARTUP" == 1 ]
    then
      yes_no_function "Do you want to add Nginx web server on startup, actual value : ${SETCOLOR_WARNING}on${SETCOLOR_NORMAL} ?" "yes"
    else
      yes_no_function "Do you want to add Nginx web server on startup, actual value : ${SETCOLOR_WARNING}off${SETCOLOR_NORMAL} ?" "no"
    fi
  fi
  if [ "$?" == 0 ]
  then
    if [ -z "$BOOLEAN_NGINX_ONSTARTUP" ]
    then
      BOOLEAN_NGINX_ONSTARTUP=1
    else
      if [ "$BOOLEAN_NGINX_ONSTARTUP" == 1 ]
      then
        yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}disable${SETCOLOR_NORMAL} Nginx web server on startup ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_NGINX_ONSTARTUP=0
        else
          BOOLEAN_NGINX_ONSTARTUP=$BOOLEAN_NGINX_ONSTARTUP
        fi
      else
        yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}enable${SETCOLOR_NORMAL} Nginx web server on startup ?" "yes"
        if [ "$?" == 0 ]
        then
          BOOLEAN_NGINX_ONSTARTUP=1
        else
          BOOLEAN_NGINX_ONSTARTUP=$BOOLEAN_NGINX_ONSTARTUP
        fi
      fi
    fi
  else
    BOOLEAN_NGINX_ONSTARTUP=0
  fi
  echo "BOOLEAN_NGINX_ONSTARTUP=$BOOLEAN_NGINX_ONSTARTUP" >> $installation_cfg_tmpfile
  INSTALLATION_CFG_FILE=$installation_cfg_tmpfile
  verify_globalvariables
}
# Verify all global variables
function verify_globalvariables() {
  echo -e "\n###################################################################"
  echo -e "#${MOVE_TO_COL1}#\n# ${SETCOLOR_WARNING}Verify our variables before continue installation process${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "#${MOVE_TO_COL1}#"
  echo -e "# NETWORK_INTERFACE_NAME.............'${SETCOLOR_INFO}$NETWORK_INTERFACE_NAME${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# BOOLEAN_USE_OPENSSHKEY..............${SETCOLOR_INFO}$BOOLEAN_USE_OPENSSHKEY${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# OPENSSH_PERSONAL_KEY...............'${SETCOLOR_INFO}$OPENSSH_PERSONAL_KEY${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SERVER_TIME_ZONE...................'${SETCOLOR_INFO}$SERVER_TIME_ZONE${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# BOOLEAN_NTP_CONFIGURE...............${SETCOLOR_INFO}$BOOLEAN_NTP_CONFIGURE${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# NEW_NTP_ADDRESS....................'${SETCOLOR_INFO}$NEW_NTP_ADDRESS${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# BOOLEAN_NTP_ONSTARTUP...............${SETCOLOR_INFO}$BOOLEAN_NTP_ONSTARTUP${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# MONGO_ADMIN_PASSWORD...............'${SETCOLOR_INFO}$MONGO_ADMIN_PASSWORD${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# MONGO_GRAYLOG_DATABASE.............'${SETCOLOR_INFO}$MONGO_GRAYLOG_DATABASE${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# MONGO_GRAYLOG_USER.................'${SETCOLOR_INFO}$MONGO_GRAYLOG_USER${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# MONGO_GRAYLOG_PASSWORD.............'${SETCOLOR_INFO}$MONGO_GRAYLOG_PASSWORD${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# BOOLEAN_MONGO_ONSTARTUP.............${SETCOLOR_INFO}$BOOLEAN_MONGO_ONSTARTUP${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# SSL_KEY_SIZE........................${SETCOLOR_INFO}$SSL_KEY_SIZE${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# SSL_KEY_DURATION....................${SETCOLOR_INFO}$SSL_KEY_DURATION${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# SSL_SUBJECT_COUNTRY................'${SETCOLOR_INFO}$SSL_SUBJECT_COUNTRY${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SSL_SUBJECT_STATE..................'${SETCOLOR_INFO}$SSL_SUBJECT_STATE${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SSL_SUBJECT_LOCALITY...............'${SETCOLOR_INFO}$SSL_SUBJECT_LOCALITY${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SSL_SUBJECT_ORGANIZATION...........'${SETCOLOR_INFO}$SSL_SUBJECT_ORGANIZATION${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SSL_SUBJECT_ORGANIZATIONUNIT.......'${SETCOLOR_INFO}$SSL_SUBJECT_ORGANIZATIONUNIT${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SSL_SUBJECT_EMAIL..................'${SETCOLOR_INFO}$SSL_SUBJECT_EMAIL${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN.${SETCOLOR_INFO}$BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# BOOLEAN_ELASTICSEARCH_ONSTARTUP.....${SETCOLOR_INFO}$BOOLEAN_ELASTICSEARCH_ONSTARTUP${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# GRAYLOG_SECRET_PASSWORD............'${SETCOLOR_INFO}$GRAYLOG_SECRET_PASSWORD${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# GRAYLOG_ADMIN_USERNAME.............'${SETCOLOR_INFO}$GRAYLOG_ADMIN_USERNAME${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# GRAYLOG_ADMIN_PASSWORD.............'${SETCOLOR_INFO}$GRAYLOG_ADMIN_PASSWORD${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# BOOLEAN_GRAYLOGSERVER_ONSTARTUP.....${SETCOLOR_INFO}$BOOLEAN_GRAYLOGSERVER_ONSTARTUP${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP.....${SETCOLOR_INFO}$BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# GRAYLOG_USE_SMTP...................'${SETCOLOR_INFO}$GRAYLOG_USE_SMTP${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SMTP_HOST_NAME.....................'${SETCOLOR_INFO}$SMTP_HOST_NAME${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SMTP_DOMAIN_NAME...................'${SETCOLOR_INFO}$SMTP_DOMAIN_NAME${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SMTP_PORT_NUMBER....................${SETCOLOR_INFO}$SMTP_PORT_NUMBER${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# SMTP_USE_AUTH......................'${SETCOLOR_INFO}$SMTP_USE_AUTH${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SMTP_USE_TLS.......................'${SETCOLOR_INFO}$SMTP_USE_TLS${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SMTP_USE_SSL.......................'${SETCOLOR_INFO}$SMTP_USE_SSL${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SMTP_AUTH_USERNAME.................'${SETCOLOR_INFO}$SMTP_AUTH_USERNAME${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# SMTP_AUTH_PASSWORD.................'${SETCOLOR_INFO}$SMTP_AUTH_PASSWORD${SETCOLOR_NORMAL}'${MOVE_TO_COL1}#"
  echo -e "# BOOLEAN_NGINX_ONSTARTUP.............${SETCOLOR_INFO}$BOOLEAN_NGINX_ONSTARTUP${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "#${MOVE_TO_COL1}#"
  echo -e "###################################################################"
  yes_no_function "Do you want to continue installation process ?" "yes"
  if [ "$?" == 0 ]
  then
    log "INFO" "Global variables: Confirmed by user"
  else
    log "WARN" "Global variables: Not accepted by user"
    yes_no_function "Do you want to define them again ?" "yes"
    if [ "$?" == 0 ]
    then
      set_globalvariables
    else
      log "WARN" "GRAYLOG installation: Ended by user"
      exit 0
    fi
  fi
}
# Get system informations like OS name, OS version, etc...
function get_sysinfo() {
  local error_counter=0
  local std_error_output=
  local centos_release_file="/etc/centos-release"
  local os_major_version=
  local os_minor_version=
  echo_message "Check all system informations"
  SERVER_IP_ADDRESS=$(ifconfig $NETWORK_INTERFACE_NAME 2>> $INSTALLATION_LOG_FILE | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
  if [ "$SERVER_IP_ADDRESS" != "" ]
  then
    log "INFO" "System informations: IP address=$SERVER_IP_ADDRESS"
  else
    log "ERROR" "System informations: IP address=$SERVER_IP_ADDRESS"
    ((error_counter++))
  fi
  SERVER_HOST_NAME=$(hostname)
  if [ "$SERVER_HOST_NAME" != "" ]
  then
    log "INFO" "System informations: FQDN=$SERVER_HOST_NAME"
  else
    log "ERROR" "System informations: FQDN=$SERVER_HOST_NAME"
    ((error_counter++))
  fi
  SERVER_SHORT_NAME=$(hostname -s)
  if [ "$SERVER_SHORT_NAME" != "" ]
  then
    log "INFO" "System informations: Short name=$SERVER_SHORT_NAME"
  else
    log "ERROR" "System informations: Short name=$SERVER_SHORT_NAME"
    ((error_counter++))
  fi
  SERVER_PROCESSOR_TYPE=$(uname -p)
  if [ "$SERVER_PROCESSOR_TYPE" == "x86_64" ]
  then
    log "INFO" "System informations: Processor type=$SERVER_PROCESSOR_TYPE"
  else
    log "ERROR" "System informations: Processor type=$SERVER_PROCESSOR_TYPE"
    ((error_counter++))
  fi
  std_error_output=$(test_file ${centos_release_file})
  if [ "$std_error_output" == "0" ]
  then
    log "INFO" "System informations: OS name=CentOS"
    os_major_version=`sed -rn 's/.*\s.*\s.*([0-9])\.[0-9].*/\1/p' $centos_release_file`
    os_minor_version=`sed -rn 's/.*\s.*\s.*[0-9]\.([0-9]).*/\1/p' $centos_release_file`
    if [ "$os_major_version" == "6" ] && [[ "$os_minor_version" =~ [5-6] ]]
    then
      log "INFO" "System informations: OS major version=$os_major_version"
      log "INFO" "System informations: OS minor version=$os_minor_version"
    elif [ "$os_major_version" != "6" ] && [[ "$os_minor_version" =~ [5-6] ]]
    then
      log "ERROR" "System informations: OS major version=$os_major_version"
      ((error_counter++))
    elif [ "$os_major_version" == "6" ] && [[ ! "$os_minor_version" =~ [5-6] ]]
    then
      log "ERROR" "System informations: OS minor version=$os_minor_version"
      ((error_counter++))
    else
      log "ERROR" "System informations: OS major version=$os_major_version"
      log "ERROR" "System informations: OS minor version=$os_minor_version"
      ((error_counter++))
    fi
  else
    log "ERROR" "System informations: $centos_release_file not found"
    ((error_counter++))
  fi
  if [ "$error_counter" -eq "0" ]
  then
    echo_success "OK"
  else
    echo_failure "FAILED"
    abort_installation
  fi
}
# Generate private and public keys to secure communications
function generate_sslkeys() {
  local std_error_output1=
  local std_error_output2=
  local private_key_folder="/etc/pki/tls/private"
  local public_key_folder="/etc/pki/tls/certs"
  local private_key_name="$SERVER_SHORT_NAME.key"
  local public_key_name="$SERVER_SHORT_NAME.crt"
  local private_key_md5fingerprint=
  local public_key_md5fingerprint=
  PRIVATE_KEY_FILE="$private_key_folder/$private_key_name"
  PUBLIC_KEY_FILE="$public_key_folder/$public_key_name"
  local subject_commonname=$SERVER_HOST_NAME
  echo_message "Generate SSL keys"
  std_error_output1=$(test_directory ${private_key_folder})
  std_error_output2=$(test_directory ${public_key_folder})
  if [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "0" ]
  then
    log "INFO" "SSL keys: $private_key_folder successfully found"
    log "INFO" "SSL keys: $public_key_folder successfully found"
    std_error_output1=$(test_file ${PRIVATE_KEY_FILE})
    std_error_output2=$(test_file ${PUBLIC_KEY_FILE})
    if [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "0" ]
    then
      log "WARN" "SSL keys: $PRIVATE_KEY_FILE already generated"
      log "WARN" "SSL keys: $PUBLIC_KEY_FILE already generated"
      echo_passed "PASS"
    elif [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "1" ]
    then
      log "WARN" "SSL keys: $PRIVATE_KEY_FILE already generated"
      log "ERROR" "SSL keys: $PUBLIC_KEY_FILE not found"
      echo_failure "FAILED"
      abort_installation
    elif [ "$std_error_output1" == "1" ] && [ "$std_error_output2" == "0" ]
    then
      log "ERROR" "SSL keys: $PRIVATE_KEY_FILE not found"
      log "WARN" "SSL keys: $PUBLIC_KEY_FILE already generated"
      echo_failure "FAILED"
      abort_installation
    else
      openssl req -x509 -newkey rsa:$SSL_KEY_SIZE -keyform PEM -keyout $PRIVATE_KEY_FILE -nodes -outform PEM -out $PUBLIC_KEY_FILE -days $SSL_KEY_DURATION \
      -subj "/C=$SSL_SUBJECT_COUNTRY/ST=$SSL_SUBJECT_STATE/L=$SSL_SUBJECT_LOCALITY/O=$SSL_SUBJECT_ORGANIZATION/OU=$SSL_SUBJECT_ORGANIZATIONUNIT/CN=$subject_commonname/emailAddress=$SSL_SUBJECT_EMAIL" \
      &>/dev/null
      private_key_md5fingerprint=$(openssl rsa -noout -modulus -in ${PRIVATE_KEY_FILE} | openssl md5 | sed -rn 's/.*=\s(.*)/\1/p')
      public_key_md5fingerprint=$(openssl x509 -noout -modulus -in ${PUBLIC_KEY_FILE} | openssl md5 | sed -rn 's/.*=\s(.*)/\1/p')
      if [ "$private_key_md5fingerprint" == "$public_key_md5fingerprint" ]
      then
        log "INFO" "SSL keys: Private key location=$PRIVATE_KEY_FILE"
        log "INFO" "SSL keys: Private key MD5 fingerprint=$private_key_md5fingerprint"
        log "INFO" "SSL keys: Public key location=$PUBLIC_KEY_FILE"
        log "INFO" "SSL keys: Public key MD5 fingerprint=$public_key_md5fingerprint"
        log "INFO" "SSL keys: Successfully completed"
        echo_success "OK"
      else
        log "ERROR" "SSL keys: Private key MD5 fingerprint=$private_key_md5fingerprint"
        log "ERROR" "SSL keys: Public key MD5 fingerprint=$public_key_md5fingerprint"
        log "ERROR" "SSL keys: No match between both MD5 fingerprints"
        log "ERROR" "SSL keys: Not completed"
        echo_failure "FAILED"
        abort_installation
      fi
    fi
  elif [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "1" ]
  then
    log "INFO" "SSL keys: $private_key_folder successfully found"
    log "ERROR" "SSL keys: $public_key_folder not found"
    echo_failure "FAILED"
    abort_installation
  elif [ "$std_error_output1" == "1" ] && [ "$std_error_output2" == "0" ]
  then
    log "ERROR" "SSL keys: $private_key_folder not found"
    log "INFO" "SSL keys: $public_key_folder successfully found"
    echo_failure "FAILED"
    abort_installation
  else
    log "ERROR" "SSL keys: $private_key_folder not found"
    log "ERROR" "SSL keys: $public_key_folder not found"
    echo_failure "FAILED"
    abort_installation
  fi
}
# Configure Yum repositories (EPEL, ElasticSearch, Nginx, Graylog)
function configure_yum() {
  local error_counter=0
  local warning_counter=0
  local std_error_output=
  local epel_rpm_url="http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm"
  local epel_key_url="http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-6"
  local epel_repo_file="/etc/yum.repos.d/epel.repo"
  local nginx_rpm_url="http://nginx.org/packages/centos/6/noarch/RPMS/nginx-release-centos-6-0.el6.ngx.noarch.rpm"
  local nginx_key_url="http://nginx.org/packages/keys/nginx_signing.key"
  local nginx_repo_file="/etc/yum.repos.d/nginx.repo"
  local mongodb_repo_file="/etc/yum.repos.d/mongodb.repo"
  local elasticsearch_key_url="https://packages.elasticsearch.org/GPG-KEY-elasticsearch"
  local elasticsearch_repo_file="/etc/yum.repos.d/elasticsearch.repo"
  local graylog_rpm_url="https://packages.graylog2.org/repo/packages/graylog-1.0-repository-el6_latest.rpm"
  local graylog_repo_file="/etc/yum.repos.d/graylog.repo"
  echo_message "Configure YUM repositories"
  std_error_output=$(test_file ${epel_repo_file})
  if [ "$std_error_output" == "0" ]
  then
    log "WARN" "YUM repositories: EPEL repository already installed"
    ((warning_counter++))
  else
    rpm --import $epel_key_url
    std_error_output=$(rpm -U ${epel_rpm_url} 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ]
    then
      log "INFO" "YUM repositories: EPEL repository successfully installed"
    else
      log "ERROR" "YUM repositories: EPEL repository not installed"
      log "DEBUG" $std_error_output
      ((error_counter++))
    fi
  fi
  std_error_output=$(test_file ${nginx_repo_file})
  if [ "$std_error_output" == "0" ]
  then
    log "WARN" "YUM repositories: NGINX repository already installed"
    ((warning_counter++))
  else
    rpm --import $nginx_key_url
    std_error_output=$(rpm -U ${nginx_rpm_url} 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ]
    then
      log "INFO" "YUM repositories: NGINX repository successfully installed"
      std_error_output=$(sed -i \
      -e "s/\(baseurl=http:\/\/nginx\.org\/packages\)\(\/centos\/6\/\$basearch\/\)/\1\/mainline\2/" \
      ${nginx_repo_file} 2>&1 >/dev/null)
      if [ "$std_error_output" == "" ]
      then
        log "INFO" "YUM repositories: NGINX repository successfully configured"
      else
        log "ERROR" "YUM repositories: NGINX repository not configured"
        log "DEBUG" $std_error_output
        ((error_counter++))
      fi
    else
      log "ERROR" "YUM repositories: NGINX repository not installed"
      log "DEBUG" $std_error_output
      ((error_counter++))
    fi
  fi
  std_error_output=$(test_file ${mongodb_repo_file})
  if [ "$std_error_output" == "0" ]
  then
    log "WARN" "YUM repositories: MONGO repository already installed"
    ((warning_counter++))
  else
    std_error_output=$(cat << EOF > ${mongodb_repo_file}
[mongodb]
name=MongoDB Repository
baseurl=http://downloads-distro.mongodb.org/repo/redhat/os/x86_64/
gpgcheck=0
enabled=1
EOF
2>&1 >/dev/null)
    if [ "$std_error_output" == "" ]
    then
      log "INFO" "YUM repositories: MONGO repository successfully installed"
    else
      log "ERROR" "YUM repositories: MONGO repository not installed"
      log "DEBUG" $std_error_output
      ((error_counter++))
    fi
  fi
  std_error_output=$(test_file ${elasticsearch_repo_file})
  if [ "$std_error_output" == "0" ]
  then
    log "WARN" "YUM repositories: ELASTICSEARCH repository already installed"
    ((warning_counter++))
  else
    rpm --import $elasticsearch_key_url
    std_error_output=$(cat << EOF > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch-1.4]
name=Elasticsearch repository for 1.4.x packages
baseurl=http://packages.elasticsearch.org/elasticsearch/1.4/centos
gpgcheck=1
gpgkey=http://packages.elasticsearch.org/GPG-KEY-elasticsearch
enabled=1
EOF
2>&1 >/dev/null)
    if [ "$std_error_output" == "" ]
    then
      log "INFO" "YUM repositories: ELASTICSEARCH repository successfully installed"
    else
      log "ERROR" "YUM repositories: ELASTICSEARCH repository not installed"
      log "DEBUG" $std_error_output
      ((error_counter++))
    fi
  fi
  std_error_output=$(test_file ${graylog_repo_file})
  if [ "$std_error_output" == "0" ]
  then
    log "WARN" "YUM repositories: GRAYLOG repository already installed"
    ((warning_counter++))
  else
    std_error_output=$(rpm -U ${graylog_rpm_url} 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ]
    then
      log "INFO" "YUM repositories: GRAYLOG repository successfully installed"
    else
      log "ERROR" "YUM repositories: GRAYLOG repository not installed"
      log "DEBUG" $std_error_output
      ((error_counter++))
    fi
  fi
  if [ "$error_counter" -eq "0" ] && [ "$warning_counter" -eq "0" ]
  then
    echo_success "OK"
  elif [ "$error_counter" -eq "0" ] && [ "$warning_counter" -ne "0" ]
  then
    echo_warning "WARN"
  else
    echo_failure "FAILED"
    abort_installation
  fi
}
# Clean yum cache and recreate it
function initialize_yum() {
  local error_counter=0
  echo_message "Initialize YUM"
  std_error_output=$(yum clean all 2>&1 >/dev/null)
  if [ "$std_error_output" == "" ] || [ "$std_error_output" =~ [Ww]arning.* ]
  then
    log "INFO" "YUM repositories: Successfully cleaned"
  else
    log "ERROR" "YUM repositories: Not cleaned"
    log "DEBUG" $std_error_output
    ((error_counter++))
  fi
  std_error_output=$(yum makecache 2>&1 >/dev/null)
  if [ "$std_error_output" == "" ] || [ "$std_error_output" =~ [Ww]arning.* ]
  then
    log "INFO" "YUM cache: Successfully created"
  else
    log "ERROR" "YUM cache: Not created"
    log "DEBUG" $std_error_output
    ((error_counter++))
  fi
  if [ "$error_counter" -eq "0" ]
  then
    echo_success "OK"
  else
    echo_failure "FAILED"
    abort_installation
  fi
}
# Upgrade OS to the last version
function upgrade_os() {
  local std_error_output=
  echo_message "Install YUM plugin"
  std_error_output=$(yum list installed | grep -w yum-presto)
  if [ "$std_error_output" == "" ]
  then
    std_error_output=$(yum -y install yum-presto 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ] || [[ "$std_error_output" =~ [Ww]arning.* ]]
    then
      log "INFO" "YUM plugin: yum-presto successfully installed"
      echo_success "OK"
    else
      log "ERROR" "YUM plugin: yum-presto not installed"
      log "DEBUG" $std_error_output
      echo_failure "FAILED"
      abort_installation
    fi
  else
    log "WARN" "YUM plugin: yum-presto already installed"
    echo_passed "PASS"
  fi
  echo_message "Upgrade operating system"
  std_error_output=$(yum -y update 2>&1 >/dev/null)
  if [ "$std_error_output" == "" ] || [[ "$std_error_output" =~ [Ww]arning.* ]]
  then
    log "INFO" "Upgrade operation: Successfully completed"
    echo_success "OK"
  else
    log "ERROR" "Upgrade operation: Not completed"
    log "DEBUG" $std_error_output
    echo_failure "FAILED"
    abort_installation
  fi
}
# Install NTP service to maintain system at the time
function install_ntp() {
  local installed_counter=0
  local std_error_output=
  local ntp_config_file="/etc/ntp.conf"
  local ntp_backup_file="$ntp_config_file.dist"
  echo_message "Install NTP service"
  std_error_output=$(yum list installed | grep -w ntp)
  if [[ "$std_error_output" =~ ^ntp\..* ]]
  then
    ((installed_counter++))
  fi
  if [ "$installed_counter" -eq "1" ]
  then
    log "WARN" "NTP service: Already installed"
    echo_passed "PASS"
  else
    std_error_output=$(yum -y install ntp 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ] || [[ "$std_error_output" =~ [Ww]arning.* ]]
    then
      log "INFO" "NTP service: Successfully installed"
      echo_success "OK"
      echo_message "Configure NTP service"
      std_error_output=$(test_file ${ntp_backup_file})
      if [ "$std_error_output" == "0" ]
      then
        log "WARN" "NTP service: Already configured"
        echo_passed "PASS"
      else
        if [ $BOOLEAN_NTP_CONFIGURE == 1 ]
        then
          std_error_output=$(sed -i.dist \
          -e "s/\(# Please consider.*\)/\1\nserver $NEW_NTP_ADDRESS/" \
          -e "s/\(server\s[0-9]\..*\)/#\1/" \
          $ntp_config_file 2>&1 >/dev/null)
          if [ "$std_error_output" == "" ]
          then
            log "INFO" "NTP service: Successfully configured"
            echo_success "OK"
          else
            log "ERROR" "NTP service: Not configured"
            log "DEBUG" $std_error_output
            echo_failure "FAILED"
            abort_installation
          fi
        else
          log "WARN" "NTP service: Configuration cancelled by user"
          echo_passed "PASS"
        fi
      fi
      echo_message "Start NTP service"
      std_error_output=$(service ntpd start on 2>&1 >/dev/null)
      if [ "$std_error_output" == "" ]
      then
        log "INFO" "NTP service: Successfully started"
        echo_success "OK"
      else
        log "ERROR" "NTP service: Not started"
        log "DEBUG" $std_error_output
        echo_failure "FAILED"
        abort_installation
      fi
      echo_message "Add NTP service on startup"
      if [ $BOOLEAN_NTP_ONSTARTUP == 1 ]
      then
        std_error_output=$(chkconfig ntpd on 2>&1 >/dev/null)
        if [ "$std_error_output" == "" ]
        then
          log "INFO" "NTP service: Successfully added on startup"
          echo_success "OK"
        else
          log "ERROR" "NTP service: Not added on startup"
          log "DEBUG" $std_error_output
          echo_failure "FAILED"
        fi
      else
        std_error_output1=$(chkconfig ntpd off 2>&1 >/dev/null)
        if [ "$std_error_output1" == "" ]
        then
          log "WARN" "NTP service: Not added on startup by user"
          echo_passed "PASS"
        else
          log "ERROR" "NTP service: Not disabled on startup"
          log "DEBUG" $std_error_output1
          echo_failure "FAILED"
        fi
      fi
    else
      log "INFO" "NTP service: Not installed"
      log "DEBUG" $std_error_output
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Install core rpm packages
function install_lsbpackages() {
  local installed_counter=0
  local std_error_output=
  echo_message "Install LSB packages"
  std_error_output=$(yum list installed | grep -w redhat-lsb-core)
  if [[ "$std_error_output" =~ ^redhat-lsb-core\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w mlocate)
  if [[ "$std_error_output" =~ ^mlocate\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w bash-completion)
  if [[ "$std_error_output" =~ ^bash-completion\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w vim-enhanced)
  if [[ "$std_error_output" =~ ^vim-enhanced\..* ]]
  then
    ((installed_counter++))
  fi
  if [ "$installed_counter" -eq "4" ]
  then
    log "WARN" "LSB packages: Already installed"
    echo_passed "PASS"
  else
    std_error_output=$(yum -y install vim redhat-lsb-core mlocate bash-completion 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ] || [[ "$std_error_output" =~ [Ww]arning.* ]]
    then
      log "INFO" "LSB packages: Successfully installed"
      echo_success "OK"
    else
      log "ERROR" "LSB packages: Not installed"
      log "DEBUG" $std_error_output
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Install tcpdump, scp, telnet, traceroute, etc..
function install_networkpackages() {
  local installed_counter=0
  local std_error_output=
  echo_message "Install network packages"
  std_error_output=$(yum list installed | grep -w wget)
  if [[ "$std_error_output" =~ ^wget\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w tcpdump)
  if [[ "$std_error_output" =~ ^tcpdump\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w traceroute)
  if [[ "$std_error_output" =~ ^traceroute\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w bind-utils)
  if [[ "$std_error_output" =~ ^bind-utils\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w telnet)
  if [[ "$std_error_output" =~ ^telnet\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w openssh-clients)
  if [[ "$std_error_output" =~ ^openssh-clients\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w system-config-firewall-tui)
  if [[ "$std_error_output" =~ ^system-config-firewall-tui\..* ]]
  then
    ((installed_counter++))
  fi
  
  if [ "$installed_counter" -eq "7" ]
  then
    log "INFO" "Network packages: Already installed"
    echo_passed "PASS"
  else
    std_error_output=$(yum -y install wget tcpdump traceroute bind-utils telnet openssh-clients system-config-firewall 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ] || [[ "$std_error_output" =~ [Ww]arning.* ]]
    then
      log "INFO" "Network packages: Successfully installed"
      echo_success "OK"
    else
      log "ERROR" "Network packages: Not installed"
      log "DEBUG" $std_error_output
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Configure Bash
function configure_bashrc() {
  local std_error_output=
  local bashrc_config_file="/root/.bashrc"
  local bashrc_backup_file="$bashrc_config_file.dist"
  echo_message "Configure Bourne-Again shell"
  std_error_output=$(test_file ${bashrc_backup_file})
  if [ "$std_error_output" == "0" ]
  then
    log "WARN" "Bourne-Again shell: Already configured"
    echo_passed "PASS"
  else
    std_error_output=$(cp -p ${bashrc_config_file} ${bashrc_backup_file} 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ]
    then
      log "INFO" "Bourne-Again shell: Successfully backed-up"
      std_error_output=$(cat << EOF > $bashrc_config_file
# .bashrc

# User specific aliases and functions

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias vi='vim'

# Set colors and different options for LS command
eval "`dircolors -b`"
alias ls='ls --time-style=+"%d-%m-%Y %H:%M:%S" --color=always --group-directories-first -AhFlX'

# Set colors for grep command
alias grep='grep --color'

# Set alias for df command
alias df='df -hTa --total'

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi
EOF
2>&1 >/dev/null)
      if [ "$std_error_output" == "" ]
      then
        log "INFO" "Bourne-Again shell: Successfully configured"
        echo_success "OK"
      else
        log "ERROR" "Bourne-Again shell: NOT configured"
        log "DEBUG" $std_error_output
        echo_failure "FAILED"
      fi
    else
      log "ERROR" "Bourne-Again shell: Not backed-up"
      log "DEBUG" $std_error_output
      echo_failure "FAILED"
    fi
  fi
}
# Configure OpenSSH to listen on loopback and specific interface specified by user
function configure_openssh() {
  local std_error_output=
  local opensshd_config_folder="/etc/ssh"
  local opensshd_config_file="$opensshd_config_folder/sshd_config"
  local opensshd_backup_file="$opensshd_config_file.dist"
  local openssh_hostrsakey_file="$opensshd_config_folder/ssh_host_rsa_key"
  echo_message "Configure SSH service"
  std_error_output=$(test_file ${opensshd_backup_file})
  if [ "$std_error_output" == "0" ]
  then
    log "WARN" "SSH service: Already configured"
    echo_passed "PASS"
  else
    std_error_output=$(sed -i.dist \
    -e "s/#\(ListenAddress\)\s0.0.0.0/\1 $SERVER_IP_ADDRESS/g" \
    -e "s/#\(ListenAddress\)\s::/\1 127.0.0.1/g" \
    $opensshd_config_file 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ]
    then
#      ssh-keygen -b 2048 -t rsa -f $openssh_hostrsakey_file
      log "INFO" "SSH service: Successfully configured"
      echo_success "OK"
      echo_message "Restart SSH service"
      std_error_output=$(service sshd restart 2>&1 >/dev/null)
      if [ "$std_error_output" == "" ]
      then
        log "INFO" "SSH service: Successfully restarted"
        echo_success "OK"
      else
        log "ERROR" "SSH service: Not restarted"
        log "DEBUG" $std_error_output
        echo_failure "FAILED"
      fi
    else
      log "ERROR" "SSH service: Not configured"
      log "DEBUG" $std_error_output
      echo_failure "FAILED"
    fi
  fi
}
# Authenticate "root" user on system using RSA keys
function add_opensshkey() {
  local std_error_output=
  local openssh_authorizedkeys_folder="/root/.ssh"
  local openssh_authorizedkeys_file="$openssh_authorizedkeys_folder/authorized_keys"
  echo_message "Add OpenSSH Key"
  std_error_output=$(test_directory ${openssh_authorizedkeys_folder})
  if [ "$std_error_output" == "0" ]
  then
    log "INFO" "SSH personal key: $openssh_authorizedkeys_folder successfully found"
    std_error_output=$(test_file ${openssh_authorizedkeys_file})
    if [ "$std_error_output" == "0" ]
    then
      log "INFO" "SSH personal key: $openssh_authorizedkeys_file successfully found"
      if [ -s $openssh_authorizedkeys_file ]
      then
        log "INFO" "SSH personal key: $openssh_authorizedkeys_file not empty"
        std_error_output=$(echo ${OPENSSH_PERSONAL_KEY} >> ${openssh_authorizedkeys_file})
        if [ "$std_error_output" == "" ]
        then
          log "INFO" "SSH personal key: Successfully inserted"
          echo_success "OK"
        else
          log "ERROR" "SSH personal key: Not inserted"
          log "DEBUG" $std_error_output
          echo_failure "FAILED"
        fi
      else
        log "INFO" "SSH personal key: $openssh_authorizedkeys_file empty"
        std_error_output=$(echo ${OPENSSH_PERSONAL_KEY} > ${openssh_authorizedkeys_file})
        if [ "$std_error_output" == "" ]
        then
          log "INFO" "SSH personal key: Successfully inserted"
          echo_success "OK"
        else
          log "ERROR" "SSH personal key: Not inserted"
          log "DEBUG" $std_error_output
          echo_failure "FAILED"
        fi
      fi
    else
      touch $openssh_authorizedkeys_file
      log "INFO" "SSH personal key: $openssh_authorizedkeys_file created"
      echo $OPENSSH_PERSONAL_KEY > $openssh_authorizedkeys_file
      log "INFO" "SSH personal key: Successfully inserted"
      echo_success "OK"
    fi
  else
    std_error_output=$(mkdir ${openssh_authorizedkeys_folder})
    if [ "$std_error_output" == "" ]
    then
      log "INFO" "SSH personal key: $openssh_authorizedkeys_folder successfully created"
      std_error_output=$(chmod 700 ${openssh_authorizedkeys_folder})
      if [ "$std_error_output" == "" ]
      then
        log "INFO" "SSH personal key: $openssh_authorizedkeys_folder successfully changed rights"
        std_error_output=$(touch ${openssh_authorizedkeys_file})
        if [ "$std_error_output" == "" ]
        then
          log "INFO" "SSH personal key: $openssh_authorizedkeys_file created"
          std_error_output=$(echo ${OPENSSH_PERSONAL_KEY} > ${openssh_authorizedkeys_file})
          if [ "$std_error_output" == "" ]
          then
            log "INFO" "SSH personal key: Successfully inserted"
            echo_success "OK"
          else
            log "ERROR" "SSH personal key: Not inserted"
            log "DEBUG" $std_error_output
            echo_failure "FAILED"
          fi
        else
          log "ERROR" "SSH personal key: $openssh_authorizedkeys_file not created"
          log "DEBUG" $std_error_output
          echo_failure "FAILED"
        fi
      else
        log "ERROR" "SSH personal key: $openssh_authorizedkeys_folder not changed rights"
        log "DEBUG" $std_error_output
        echo_failure "FAILED"
      fi
    else
      log "ERROR" "SSH personal key: $openssh_authorizedkeys_folder not created"
      log "DEBUG" $std_error_output
      echo_failure "FAILED"
    fi
  fi
}
# Configure Postfix to use Internet Protocol version 4
function configure_postfix() {
  local std_error_output=
  local postfix_config_folder="/etc/postfix"
  local postfix_config_file="$postfix_config_folder/main.cf"
  local postfix_backup_file="$postfix_config_file.dist"
  echo_message "Configure POSTFIX service"
  std_error_output=$(test_file ${postfix_backup_file})
  if [ "$std_error_output" == "0" ]
  then
    log "WARN" "POSTFIX service: Already configured"
    echo_passed "PASS"
  else
    std_error_output=$(sed -i.dist \
    -e "s/\(inet_protocols\s=\).*/\1 ipv4/g" \
    $postfix_config_file 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ]
    then
      log "INFO" "POSTFIX service: Successfully configured"
      echo_success "OK"
      echo_message "Restart POSTFIX service"
      std_error_output=$(service postfix restart 2>&1 >/dev/null)
      if [ "$std_error_output" == "" ]
      then
        log "INFO" "POSTFIX service: Successfully restarted"
        echo_success "OK"
      else
        log "ERROR" "POSTFIX service: Not restarted"
        log "DEBUG" $std_error_output
        echo_failure "FAILED"
      fi
    else
      log "ERROR" "POSTFIX service: Not configured"
      log "DEBUG" $std_error_output
      echo_failure "FAILED"
    fi
  fi
}
# Add an entry to "/etc/hosts" file
function configure_hostsfile() {
  local std_error_output=
  local hosts_definiton_file="/etc/hosts"
  local hosts_backup_file="$hosts_definiton_file.dist"
  echo_message "Configure hosts file"
  std_error_output=$(test_file ${hosts_backup_file})
  if [ "$std_error_output" == "0" ]
  then
    log "WARN" "HOSTS file: Already configured"
    echo_passed "PASS"
  else
    std_error_output=$(sed -i.dist \
    -e "s/^\(127.0.0.1\)\s*\(.*\)/\1\t\2/g" \
    -e "s/^\(::1\)\s*\(.*\)/\1\t\t\2\n$SERVER_IP_ADDRESS\t$SERVER_HOST_NAME/g" \
    $hosts_definiton_file 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ]
    then
      log "INFO" "HOSTS file: Successfully configured"
      echo_success "OK"
    else
      log "ERROR" "HOSTS file: Not configured"
      log "DEBUG" $std_error_output
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Disable Selinux module
function configure_selinux() {
  local std_error_output=
  local selinux_config_folder="/etc/selinux"
  local selinux_config_file="$selinux_config_folder/config"
  local selinux_backup_file="$selinux_config_file.dist"
  echo_message "Configure SELINUX module"
  std_error_output=$(test_file ${selinux_backup_file})
  if [ "$std_error_output" == "0" ]
  then
    log "WARN" "SELINUX module: Already configured"
    echo_passed "PASS"
  else
    std_error_output=$(sed -i.dist \
    -e "s/\(SELINUX\)=enforcing/\1=disabled/g" \
    $selinux_config_file 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ]
    then
      log "INFO" "SELINUX module: Successfully configured"
      echo_success "OK"
    else
      log "ERROR" "SELINUX module: Not configured"
      log "DEBUG" $std_error_output
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Install and configure Mongo database server
function install_mongodb() {
  local installed_counter=0
  local std_error_output=
  local success_word_definition="Successfully"
  local success_word_occurrence=
  local mongodb_init_file="/etc/init.d/mongod"
  local mongodb_config_file="/etc/mongod.conf"
  local mongodb_backup_file="$mongodb_config_file.dist"
  local mongodb_admin_database="admin"
  echo_message "Install MONGO database server"
  std_error_output=$(yum list installed | grep mongodb-org.x)
  if [[ "$std_error_output" =~ ^mongodb-org\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w mongodb-org-mongos)
  if [[ "$std_error_output" =~ ^mongodb-org-mongos\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w mongodb-org-server)
  if [[ "$std_error_output" =~ ^mongodb-org-server\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w mongodb-org-shell)
  if [[ "$std_error_output" =~ ^mongodb-org-shell\..* ]]
  then
    ((installed_counter++))
  fi
  std_error_output=$(yum list installed | grep -w mongodb-org-tools)
  if [[ "$std_error_output" =~ ^mongodb-org-tools\..* ]]
  then
    ((installed_counter++))
  fi
  if [ "$installed_counter" -eq "5" ]
  then
    log "INFO" "MONGO database server: Already installed"
    echo_passed "PASS"
  else
    std_error_output=$(yum -y install mongodb-org 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ] || [[ "$std_error_output" =~ [Ww]arning.* ]]
    then
      log "INFO" "MONGO database server: Successfully installed"
      std_error_output=$(test_file ${mongodb_init_file})
      if [ "$std_error_output" == "0" ]
      then
        log "INFO" "MONGO database server: $mongodb_init_file successfully found"
        std_error_output=$(sed -i \
        -e "s/\(.*daemon\)\(.*--user \"\$MONGO_USER\" \"\$NUMACTL \$mongod \$OPTIONS >\/dev\/null 2>&1\"\)/\1 --check \$mongod\2/" \
        $mongodb_init_file 2>&1 >/dev/null)
        if [ "$std_error_output" == "" ]
        then
          log "INFO" "MONGO database server: $mongodb_init_file successfully modified"
        else
          log "ERROR" "MONGO database server: $mongodb_init_file not modified"
          log "DEBUG" $std_error_output
        fi
        std_error_output=$(service mongod start 2>&1 >/dev/null)
        if [ "$std_error_output" == "" ]
        then
          log "INFO" "MONGO database server: Successfully started"
          std_error_output=$(test_file ${mongodb_backup_file})
          if [ "$std_error_output" == "0" ]
          then
            log "WARN" "MONGO database server: $mongodb_config_file already backed-up"
          else
            std_error_output=$(mongo <<EOF
use $mongodb_admin_database
db.createUser(
 {
  user: "$MONGO_ADMIN_USER",
  pwd: "$MONGO_ADMIN_PASSWORD",
  roles: [ { role: "root", db: "$mongodb_admin_database" } ]
 }
)
use $MONGO_GRAYLOG_DATABASE
db.createUser(
 {
  user: "$MONGO_GRAYLOG_USER",
  pwd: "$MONGO_GRAYLOG_PASSWORD",
  roles: [ { role: "readWrite", db: "$MONGO_GRAYLOG_DATABASE" } ]
 }
)
quit()
EOF
2>&1 >/dev/null)
            success_word_occurrence=$(( (`cat <<<${std_error_output} | wc -c` - `sed "s/$success_word_definition//g" <<<$std_error_output | wc -c`) / ${#success_word_definition} ))
            if [ $success_word_occurrence == 2 ]
            then
              log "INFO" "MONGO database server: Successfully set password ($MONGO_ADMIN_PASSWORD) for user $MONGO_ADMIN_USER"
              log "INFO" "MONGO database server: Successfully set role 'root' to user $mongodb_admin_user on database $mongodb_admin_database"
              log "INFO" "MONGO database server: Successfully create database $MONGO_GRAYLOG_DATABASE"
              log "INFO" "MONGO database server: Successfully create user $MONGO_GRAYLOG_USER"
              log "INFO" "MONGO database server: Successfully set password ($MONGO_GRAYLOG_PASSWORD) for user $MONGO_GRAYLOG_USER"
              log "INFO" "MONGO database server: Successfully set role 'readWrite' to user $MONGO_GRAYLOG_USER on database $MONGO_GRAYLOG_DATABASE"
              log "INFO" "MONGO database server: CLI configuration successfully completed"
              std_error_output=$(sed -i.dist \
              -e "s/#\(port=27017\)/\1/" \
              -e "s/#\(auth=true\)/\1/" \
              -e "s/#\(quota=true\)/\1/" \
              -e "s/#\(httpinterface=\)true/\1false/" \
              $mongodb_config_file 2>&1 >/dev/null)
              if [ "$std_error_output" == "" ]
              then
                log "INFO" "MONGO database server: Successfully configured"
                echo_success "OK"
                echo_message "Restart MONGO database server"
                std_error_output=$(service mongod restart 2>&1 >/dev/null)
                if [ "$std_error_output" == "" ]
                then
                  log "INFO" "MONGO database server: Successfully restarted"
                  echo_success "OK"
                else
                  log "ERROR" "MONGO database server: Not restarted"
                  log "DEBUG" $std_error_output
                  echo_failure "FAILED"
                  abort_installation
                fi
              else
                log "ERROR" "MONGO database server: Not configured"
                log "DEBUG" $std_error_output
                echo_failure "FAILED"
                abort_installation
              fi
            else
              log "ERROR" "MONGO database server: CLI configuration not completed"
              log "DEBUG" $std_error_output
              echo_failure "FAILED"
              abort_installation
            fi
          fi
        else
          log "ERROR" "MONGO database server: Not started"
          log "DEBUG" $std_error_output
          echo_failure "FAILED"
          abort_installation
        fi
        echo_message "Add MONGO database server on startup"
        if [ $BOOLEAN_MONGO_ONSTARTUP == 1 ]
        then
          std_error_output=$(chkconfig mongod on 2>&1 >/dev/null)
          if [ "$std_error_output" == "" ]
          then
            log "INFO" "MONGO database server: Successfully added on startup"
            echo_success "OK"
          else
            log "ERROR" "MONGO database server: Not added on startup"
            log "DEBUG" $std_error_output
            echo_failure "FAILED"
          fi
        else
          std_error_output1=$(chkconfig mongod off 2>&1 >/dev/null)
          if [ "$std_error_output1" == "" ]
          then
            log "WARN" "MONGO database server: Not added on startup by user"
            echo_passed "PASS"
          else
            log "ERROR" "MONGO database server: Not disabled on startup"
            log "DEBUG" $std_error_output1
            echo_failure "FAILED"
          fi
        fi
      else
        log "ERROR" "MONGO database server: $mongodb_init_file not found"
        log "DEBUG" $std_error_output
        echo_failure "FAILED"
        abort_installation
      fi
    else
      log "ERROR" "MONGO database server: Not installed"
      log "DEBUG" $std_error_output
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Install JRE (Java Runtime Environment)
function install_java() {
  local installed_counter=0
  local std_error_output=
  echo_message "Install Java Runtime Environment"
  std_error_output=$(yum list installed | grep java-)
  if [[ "$std_error_output" =~ ^java.* ]]
  then
    ((installed_counter++))
  fi
  if [ "$installed_counter" -eq "1" ]
  then
    log "WARN" "Java Runtime Environment: Already installed"
    echo_passed "PASS"
  else
    std_error_output=$(yum -y install jre 2>&1 >/dev/null)
    if [ "$std_error_output" == "" ] || [[ "$std_error_output" =~ [Ww]arning.* ]]
    then
      log "INFO" "Java Runtime Environment: Successfully installed"
      echo_success "OK"
    else
      log "ERROR" "Java Runtime Environment: Not installed"
      log "DEBUG" $std_error_output
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Install and configure ElasticSearch server
function install_elasticsearch() {
  local installed_counter=0
  local std_error_output1=
  local std_error_output2=
  local elasticsearch_config_folder="/etc/elasticsearch"
  local elasticsearch_config_file="$elasticsearch_config_folder/elasticsearch.yml"
  local elasticsearch_backup_file="$elasticsearch_config_file.dist"
  local elasticsearch_sysconfig_file="/etc/sysconfig/elasticsearch"
  local elasticsearch_sysbackup_file="$elasticsearch_sysconfig_file.dist"
  echo_message "Install ELASTICSEARCH server"
  std_error_output=$(yum list installed | grep -w elasticsearch)
  if [[ "$std_error_output" =~ ^elasticsearch\..* ]]
  then
    ((installed_counter++))
  fi
  if [ "$installed_counter" -eq "1" ]
  then
    log "WARN" "ELASTICSEARCH server: Already installed"
    echo_passed "PASS"
  else
    std_error_output1=$(yum -y install elasticsearch 2>&1 >/dev/null)
    if [ "$std_error_output1" == "" ] || [[ "$std_error_output1" =~ [Ww]arning.* ]]
    then
      log "INFO" "ELASTICSEARCH server: Successfully installed"
      std_error_output1=$(test_file ${elasticsearch_backup_file})
      std_error_output2=$(test_file ${elasticsearch_sysbackup_file})
      if [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "0" ]
      then
        log "WARN" "ELASTICSEARCH server: $elasticsearch_config_file already backed-up"
        log "WARN" "ELASTICSEARCH server: $elasticsearch_sysconfig_file already backed-up"
        echo_passed "PASS"
      elif [ "$std_error_output1" == "1" ] && [ "$std_error_output2" == "0" ]
      then
        log "ERROR" "ELASTICSEARCH server: $elasticsearch_config_file not backed-up"
        log "WARN" "ELASTICSEARCH server: $elasticsearch_sysconfig_file already backed-up"
        echo_failure "FAILED"
        abort_installation
      elif [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "1" ]
      then
        log "WARN" "ELASTICSEARCH server: $elasticsearch_config_file already backed-up"
        log "ERROR" "ELASTICSEARCH server: $elasticsearch_sysconfig_file not backed-up"
        echo_failure "FAILED"
        abort_installation
      else
        std_error_output1=$(test_file ${elasticsearch_config_file})
        std_error_output2=$(test_file ${elasticsearch_sysconfig_file})
        if [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "0" ]
        then
          log "INFO" "ELASTICSEARCH server: $elasticsearch_config_file successfully found"
          log "INFO" "ELASTICSEARCH server: $elasticsearch_sysconfig_file successfully found"
          std_error_output1=$(sed -i.dist \
          -e "s/#\(cluster.name: \).*/\1log-cluster/" \
          -e "s/#\(node.name: \).*/\1$SERVER_SHORT_NAME-elasticsearch/" \
          -e "0,/#\(node.master: true\)/s//\1/" \
          -e "0,/#\(node.data: true\)/s//\1/" \
          -e "s/#\(network.host: \).*/\1$SERVER_IP_ADDRESS/" \
          -e "s/#\(transport.tcp.port: 9300\)/\1/" \
          -e "s/#\(http.port: 9200\)/\1/" \
          -e "s/#\(http.enabled: \)false/\1true/" \
          -e "s/#\(discovery.zen.ping.multicast.enabled: false\)/\1/" \
          -e "s/#\(discovery.zen.ping.unicast.hosts: \).*/\1\[\"$SERVER_HOST_NAME\"\]/" \
          -e "s/\(\#http.jsonp.enable: true\)/\1\nscript.disable_dynamic: true/" \
          $elasticsearch_config_file 2>&1 >/dev/null)
          std_error_output2=$(sed -i.dist \
          -e "s/#\(ES_HEAP_SIZE\=\).*/\1$ELASTICSEARCH_RAM_RESERVATION/" \
          -e "s/#\(ES_DIRECT_SIZE\=\).*/\1$ELASTICSEARCH_RAM_RESERVATION/" \
          -e "s/#\(ES_JAVA_OPTS\=\).*/\1\"\-Djava.net.preferIPv4Stack\=true\"/" \
          $elasticsearch_sysconfig_file 2>&1 >/dev/null)
          if [ "$std_error_output1" == "" ] && [ "$std_error_output2" == "" ]
          then
            log "INFO" "ELASTICSEARCH server: $elasticsearch_config_file successfully modified"
            log "INFO" "ELASTICSEARCH server: $elasticsearch_sysconfig_file successfully modified"
            echo_success "OK"
            echo_message "Start ELASTICSEARCH service"
            std_error_output1=$(service elasticsearch start 2>&1 >/dev/null)
            if [ "$std_error_output1" == "" ]
            then
              log "INFO" "ELASTICSEARCH server: Successfully started"
              echo_success "OK"
              echo_message "Install ELASTICSEARCH HQ Management plugin"
              if [ $BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN -eq 1 ]
              then
                std_error_output1=$(/usr/share/elasticsearch/bin/plugin -install royrusso/elasticsearch-HQ 2>&1 >/dev/null)
                if [ "$std_error_output1" == "" ]
                then
                  log "INFO" "ELASTICSEARCH server: HQ Management plugin successfully installed"
                  echo_success "OK"
                else
                  log "ERROR" "ELASTICSEARCH server: HQ Management plugin not installed"
                  log "DEBUG" $std_error_output1
                  echo_failure "FAILED"
                fi
              else
                log "WARN" "ELASTICSEARCH server: HQ Management plugin installation cancelled by user"
                echo_passed "PASS"
              fi
            else
              log "ERROR" "ELASTICSEARCH server: Not started"
              log "DEBUG" $std_error_output1
              echo_failure "FAILED"
              abort_installation
            fi
          elif [ "$std_error_output1" != "" ] && [ "$std_error_output2" == "" ]
          then
            log "ERROR" "ELASTICSEARCH server: $elasticsearch_config_file not modified"
            log "DEBUG" $std_error_output1
            log "INFO" "ELASTICSEARCH server: $elasticsearch_sysconfig_file successfully modified"
            echo_failure "FAILED"
            abort_installation
          elif [ "$std_error_output1" == "" ] && [ "$std_error_output2" != "" ]
          then
            log "INFO" "ELASTICSEARCH server: $elasticsearch_config_file successfully modified"
            log "ERROR" "ELASTICSEARCH server: $elasticsearch_sysconfig_file not modified"
            log "DEBUG" $std_error_output2
            echo_failure "FAILED"
            abort_installation
          else
            log "ERROR" "ELASTICSEARCH server: $elasticsearch_config_file not modified"
            log "DEBUG" $std_error_output1
            log "ERROR" "ELASTICSEARCH server: $elasticsearch_sysconfig_file not modified"
            log "DEBUG" $std_error_output2
            echo_failure "FAILED"
            abort_installation
          fi
        elif [ "$std_error_output1" == "1" ] && [ "$std_error_output2" == "0" ]
        then
          log "ERROR" "ELASTICSEARCH server: $elasticsearch_config_file not found"
          log "INFO" "ELASTICSEARCH server: $elasticsearch_sysconfig_file successfully found"
          echo_failure "FAILED"
          abort_installation
        elif [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "1" ]
        then
          log "INFO" "ELASTICSEARCH server: $elasticsearch_config_file successfully found"
          log "ERROR" "ELASTICSEARCH server: $elasticsearch_sysconfig_file not found"
          echo_failure "FAILED"
          abort_installation
        else
          log "ERROR" "ELASTICSEARCH server: $elasticsearch_config_file not found"
          log "ERROR" "ELASTICSEARCH server: $elasticsearch_sysconfig_file not found"
          echo_failure "FAILED"
          abort_installation
        fi
      fi
      echo_message "Add ELASTICSEARCH service on startup"
      if [ $BOOLEAN_ELASTICSEARCH_ONSTARTUP == 1 ]
      then
        std_error_output1=$(chkconfig elasticsearch on 2>&1 >/dev/null)
        if [ "$std_error_output1" == "" ]
        then
          log "INFO" "ELASTICSEARCH server: Successfully added on startup"
          echo_success "OK"
        else
          log "ERROR" "ELASTICSEARCH server: Not added on startup"
          log "DEBUG" $std_error_output1
          echo_failure "FAILED"
        fi
      else
        std_error_output1=$(chkconfig elasticsearch off 2>&1 >/dev/null)
        if [ "$std_error_output1" == "" ]
        then
          log "WARN" "ELASTICSEARCH server: Not added on startup by user"
          echo_passed "PASS"
        else
          log "ERROR" "ELASTICSEARCH server: Not disabled on startup"
          log "DEBUG" $std_error_output1
          echo_failure "FAILED"
        fi
      fi
    else
      log "ERROR" "ELASTICSEARCH server: Not installed"
      log "DEBUG" $std_error_output1
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Install and configure server component of Graylog application
function install_graylogserver() {
  local installed_counter=0
  local std_error_output1=
  local std_error_output2=
  local graylogserver_config_folder="/etc/graylog/server"
  local graylogserver_config_file="$graylogserver_config_folder/server.conf"
  local graylogserver_backup_file="$graylogserver_config_file.dist"
  local graylogserver_sysconfig_file="/etc/sysconfig/graylog-server"
  local graylogserver_sysbackup_file="$graylogserver_sysconfig_file.dist"
  local graylog_secret_password=`echo -n "$GRAYLOG_SECRET_PASSWORD" | sha256sum | sed -rn 's/(.*)\s{2}.*/\1/p'`
  local graylog_admin_password=`echo -n "$GRAYLOG_ADMIN_PASSWORD" | sha256sum | sed -rn 's/(.*)\s{2}.*/\1/p'`
  echo_message "Install GRAYLOG server"
  std_error_output=$(yum list installed | grep -w graylog-server)
  if [[ "$std_error_output" =~ ^graylog-server\..* ]]
  then
    ((installed_counter++))
  fi
  if [ "$installed_counter" -eq "1" ]
  then
    log "WARN" "GRAYLOG server: Already installed"
    echo_passed "PASS"
  else
    std_error_output1=$(yum -y install graylog-server 2>&1 >/dev/null)
    if [ "$std_error_output1" == "" ] || [[ "$std_error_output1" =~ [Ww]arning.* ]]
    then
      log "INFO" "GRAYLOG server: Successfully installed"
      std_error_output1=$(test_file ${graylogserver_backup_file})
      std_error_output2=$(test_file ${graylogserver_sysbackup_file})
      if [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "0" ]
      then
        log "WARN" "GRAYLOG server: $graylogserver_config_file already backed-up"
        log "WARN" "GRAYLOG server: $graylogserver_sysconfig_file already backed-up"
        echo_passed "PASS"
      elif [ "$std_error_output1" == "1" ] && [ "$std_error_output2" == "0" ]
      then
        log "ERROR" "GRAYLOG server: $graylogserver_config_file not backed-up"
        log "WARN" "GRAYLOG server: $graylogserver_sysconfig_file already backed-up"
        echo_failure "FAILED"
        abort_installation
      elif [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "1" ]
      then
        log "WARN" "GRAYLOG server: $graylogserver_config_file already backed-up"
        log "ERROR" "GRAYLOG server: $graylogserver_sysconfig_file not backed-up"
        echo_failure "FAILED"
        abort_installation
      else
        std_error_output1=$(test_file ${graylogserver_config_file})
        std_error_output2=$(test_file ${graylogserver_sysconfig_file})
        if [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "0" ]
        then
          log "INFO" "GRAYLOG server: $graylogserver_config_file successfully found"
          log "INFO" "GRAYLOG server: $graylogserver_sysconfig_file successfully found"
          std_error_output1=$(sed -i.dist \
          -e "s/\(password_secret =\)/\1 $graylog_secret_password/" \
          -e "s/#\(root_username =\).*/\1 $GRAYLOG_ADMIN_USERNAME/" \
          -e "s/\(root_password_sha2 =\)/\1 $graylog_admin_password/" \
          -e "s/#\(root_email = \"\)\(\"\)/\1$SERVER_SHORT_NAME\@$SMTP_DOMAIN_NAME\2/" \
          -e "s|#\(root_timezone = \).*|\1$SERVER_TIME_ZONE|" \
          -e "s|\(rest_listen_uri = \).*|\1https://$SERVER_HOST_NAME:12900/|" \
          -e "s|#\(rest_transport_uri = \).*|\1https://$SERVER_HOST_NAME:12900/|" \
          -e "s/#\(rest_enable_tls = true\)/\1/" \
          -e "s|#\(rest_tls_cert_file = \).*|\1$PUBLIC_KEY_FILE|" \
          -e "s|#\(rest_tls_key_file = \).*|\1$PRIVATE_KEY_FILE|" \
          -e "s/#\(elasticsearch_cluster_name = \).*/\1log-cluster/" \
          -e "s/#\(elasticsearch_node_name = \).*/\1$SERVER_SHORT_NAME-graylog/" \
          -e "s/#\(elasticsearch_http_enabled = false\)/\1/" \
          -e "s/#\(elasticsearch_discovery_zen_ping_multicast_enabled = false\)/\1/" \
          -e "s/#\(elasticsearch_discovery_zen_ping_unicast_hosts = \).*/\1$SERVER_HOST_NAME:9300/" \
          -e "s/#\(elasticsearch_node_master = false\)/\1/" \
          -e "s/#\(elasticsearch_node_data = false\)/\1/" \
          -e "s/#\(elasticsearch_transport_tcp_port = 9350\)/\1/" \
          -e "s/#\(elasticsearch_http_enabled = false\)/\1/" \
          -e "s/#\(elasticsearch_network_host = \).*/\1$SERVER_IP_ADDRESS/" \
          -e "s/\(mongodb_useauth = \).*/\1true/" \
          -e "s/#\(mongodb_user = \).*/\1$MONGO_GRAYLOG_USER/" \
          -e "s/#\(mongodb_password = \).*/\1$MONGO_GRAYLOG_PASSWORD/" \
          -e "s/\(mongodb_host = \).*/\1localhost/" \
          -e "s/\(mongodb_database = \).*/\1$MONGO_GRAYLOG_DATABASE/" \
          -e "s/#\(transport_email_enabled = \).*/\1$GRAYLOG_USE_SMTP/" \
          -e "s/#\(transport_email_hostname = \).*/\1$SMTP_HOST_NAME/" \
          -e "s/#\(transport_email_port = \).*/\1$SMTP_PORT_NUMBER/" \
          -e "s/#\(transport_email_use_auth = \).*/\1$SMTP_USE_AUTH/" \
          -e "s/#\(transport_email_use_tls = \).*/\1$SMTP_USE_TLS/" \
          -e "s/#\(transport_email_use_ssl = \).*/\1$SMTP_USE_SSL/" \
          -e "s/#\(transport_email_auth_username = \).*/\1$SMTP_AUTH_USERNAME/" \
          -e "s/#\(transport_email_auth_password = \).*/\1$SMTP_AUTH_PASSWORD/" \
          -e "s/#\(transport_email_subject_prefix = .*\)/\1/" \
          -e "s/#\(transport_email_from_email = \).*/\1$SERVER_SHORT_NAME\@$SMTP_DOMAIN_NAME/" \
          -e "s|#\(transport_email_web_interface_url = \).*|\1https://$SERVER_HOST_NAME|" \
          $graylogserver_config_file 2>&1 >/dev/null)
          std_error_output2=$(sed -i.dist \
          -e "s/\(GRAYLOG_SERVER_JAVA_OPTS=\"\).*\(\"\)/\1-Djava.net.preferIPv4Stack=true -Xms$GRAYLOGSERVER_RAM_RESERVATION -Xmx$GRAYLOGSERVER_RAM_RESERVATION -XX:NewRatio=1 -XX:PermSize=128m -XX:MaxPermSize=256m -server -XX:+ResizeTLAB -XX:+UseConcMarkSweepGC -XX:+CMSConcurrentMTEnabled -XX:+CMSClassUnloadingEnabled -XX:+UseParNewGC -XX:-OmitStackTraceInFastThrow\2/" \
          $graylogserver_sysconfig_file 2>&1 >/dev/null)
          if [ "$std_error_output1" == "" ] && [ "$std_error_output2" == "" ]
          then
            log "INFO" "GRAYLOG server: $graylogserver_config_file successfully modified"
            log "INFO" "GRAYLOG server: $graylogserver_sysconfig_file successfully modified"
            echo_success "OK"
          elif [ "$std_error_output1" != "" ] && [ "$std_error_output2" == "" ]
          then
            log "ERROR" "GRAYLOG server: $graylogserver_config_file not modified"
            log "DEBUG" $std_error_output1
            log "INFO" "GRAYLOG server: $graylogserver_sysconfig_file successfully modified"
            echo_failure "FAILED"
            abort_installation
          elif [ "$std_error_output1" == "" ] && [ "$std_error_output2" != "" ]
          then
            log "INFO" "GRAYLOG server: $graylogserver_config_file successfully modified"
            log "ERROR" "GRAYLOG server: $graylogserver_sysconfig_file not modified"
            log "DEBUG" $std_error_output2
            echo_failure "FAILED"
            abort_installation
          else
            log "ERROR" "GRAYLOG server: $graylogserver_config_file not modified"
            log "DEBUG" $std_error_output1
            log "ERROR" "GRAYLOG server: $graylogserver_sysconfig_file not modified"
            log "DEBUG" $std_error_output2
            echo_failure "FAILED"
            abort_installation
          fi
        elif [ "$std_error_output1" == "1" ] && [ "$std_error_output2" == "0" ]
        then
          log "ERROR" "GRAYLOG server: $graylogserver_config_file not found"
          log "INFO" "GRAYLOG server: $graylogserver_sysconfig_file successfully found"
          echo_failure "FAILED"
          abort_installation
        elif [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "1" ]
        then
          log "INFO" "GRAYLOG server: $graylogserver_config_file successfully found"
          log "ERROR" "GRAYLOG server: $graylogserver_sysconfig_file not found"
          echo_failure "FAILED"
          abort_installation
        else
          log "ERROR" "GRAYLOG server: $graylogserver_config_file not found"
          log "ERROR" "GRAYLOG server: $graylogserver_sysconfig_file not found"
          echo_failure "FAILED"
          abort_installation
        fi
      fi
      echo_message "Add GRAYLOG server on startup"
      if [ $BOOLEAN_GRAYLOGSERVER_ONSTARTUP == 1 ]
      then
        std_error_output1=$(chkconfig graylog-server on 2>&1 >/dev/null)
        if [ "$std_error_output1" == "" ]
        then
          log "INFO" "GRAYLOG server: Successfully added on startup"
          echo_success "OK"
        else
          log "ERROR" "GRAYLOG server: Not added on startup"
          log "DEBUG" $std_error_output1
          echo_failure "FAILED"
        fi
      else
        std_error_output1=$(chkconfig graylog-server off 2>&1 >/dev/null)
        if [ "$std_error_output1" == "" ]
        then
          log "WARN" "GRAYLOG server: Not added on startup by user"
          echo_passed "PASS"
        else
          log "ERROR" "GRAYLOG server: Not disabled on startup"
          log "DEBUG" $std_error_output1
          echo_failure "FAILED"
        fi
      fi
    else
      log "ERROR" "GRAYLOG server: Not installed"
      log "DEBUG" $std_error_output1
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Install and configure web interface component of Graylog application
function install_graylogwebgui() {
  local installed_counter=0
  local std_error_output1=
  local std_error_output2=
  local graylogwebgui_config_folder="/etc/graylog/web"
  local graylogwebgui_config_file="$graylogwebgui_config_folder/web.conf"
  local graylogwebgui_backup_file="$graylogwebgui_config_file.dist"
  local graylogwebgui_sysconfig_file="/etc/sysconfig/graylog-web"
  local graylogwebgui_sysbackup_file="$graylogwebgui_sysconfig_file.dist"
  local graylog_secret_password=`echo -n "$GRAYLOG_SECRET_PASSWORD" | sha256sum | sed -rn 's/(.*)\s{2}.*/\1/p'`
  echo_message "Install GRAYLOG web interface"
  std_error_output=$(yum list installed | grep -w graylog-web)
  if [[ "$std_error_output" =~ ^graylog-web\..* ]]
  then
    ((installed_counter++))
  fi
  if [ "$installed_counter" -eq "1" ]
  then
    log "WARN" "GRAYLOG web interface: Already installed"
    echo_passed "PASS"
  else
    std_error_output1=$(yum -y install graylog-web 2>&1 >/dev/null)
    if [ "$std_error_output1" == "" ] || [[ "$std_error_output1" =~ [Ww]arning.* ]]
    then
      log "INFO" "GRAYLOG web interface: Successfully installed"
      std_error_output1=$(test_file ${graylogwebgui_backup_file})
      std_error_output2=$(test_file ${graylogwebgui_sysbackup_file})
      if [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "0" ]
      then
        log "WARN" "GRAYLOG web interface: $graylogwebgui_config_file already backed-up"
        log "WARN" "GRAYLOG web interface: $graylogwebgui_sysconfig_file already backed-up"
        echo_passed "PASS"
      elif [ "$std_error_output1" == "1" ] && [ "$std_error_output2" == "0" ]
      then
        log "ERROR" "GRAYLOG web interface: $graylogwebgui_config_file not backed-up"
        log "WARN" "GRAYLOG web interface: $graylogwebgui_sysconfig_file already backed-up"
        echo_failure "FAILED"
        abort_installation
      elif [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "1" ]
      then
        log "WARN" "GRAYLOG web interface: $graylogwebgui_config_file already backed-up"
        log "ERROR" "GRAYLOG web interface: $graylogwebgui_sysconfig_file not backed-up"
        echo_failure "FAILED"
        abort_installation
      else
        std_error_output1=$(test_file ${graylogwebgui_config_file})
        std_error_output2=$(test_file ${graylogwebgui_sysconfig_file})
        if [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "0" ]
        then
          log "INFO" "GRAYLOG web interface: $graylogwebgui_config_file successfully found"
          log "INFO" "GRAYLOG web interface: $graylogwebgui_sysconfig_file successfully found"
          std_error_output1=$(sed -i.dist \
          -e "s|\(graylog2-server.uris=\"\)\(\"\)|\1https://$SERVER_HOST_NAME:12900/\2|" \
          -e "s/\(application.secret=\"\)\(\"\)/\1$graylog_secret_password\2/" \
          -e "s|#.*\(timezone=\"\).*\(\"\)|\1$SERVER_TIME_ZONE\2|" \
          $graylogwebgui_config_file 2>&1 >/dev/null)
          std_error_output2=$(sed -i.dist \
          -e "s/\(GRAYLOG_WEB_HTTP_ADDRESS=\"\)0.0.0.0\(\"\)/\1localhost\2/" \
          -e "s/\(GRAYLOG_WEB_JAVA_OPTS=\"\)\(\"\)/\1-Djava.net.preferIPv4Stack=true\2/" \
          $graylogwebgui_sysconfig_file 2>&1 >/dev/null)
          if [ "$std_error_output1" == "" ] && [ "$std_error_output2" == "" ]
          then
            log "INFO" "GRAYLOG web interface: $graylogwebgui_config_file successfully modified"
            log "INFO" "GRAYLOG web interface: $graylogwebgui_sysconfig_file successfully modified"
            echo_success "OK"
          elif [ "$std_error_output1" != "" ] && [ "$std_error_output2" == "" ]
          then
            log "ERROR" "GRAYLOG web interface: $graylogwebgui_config_file not found"
            log "DEBUG" $std_error_output1
            log "INFO" "GRAYLOG web interface: $graylogwebgui_sysconfig_file successfully found"
            echo_failure "FAILED"
            abort_installation
          elif [ "$std_error_output1" == "" ] && [ "$std_error_output2" != "" ]
          then
            log "INFO" "GRAYLOG web interface: $graylogwebgui_config_file successfully found"
            log "ERROR" "GRAYLOG web interface: $graylogwebgui_sysconfig_file not found"
            log "DEBUG" $std_error_output2
            echo_failure "FAILED"
            abort_installation
          else
            log "ERROR" "GRAYLOG web interface: $graylogwebgui_config_file not found"
            log "DEBUG" $std_error_output1
            log "ERROR" "GRAYLOG web interface: $graylogwebgui_sysconfig_file not found"
            log "DEBUG" $std_error_output2
            echo_failure "FAILED"
            abort_installation
          fi
        elif [ "$std_error_output1" == "1" ] && [ "$std_error_output2" == "0" ]
        then
          log "ERROR" "GRAYLOG web interface: $graylogwebgui_config_file not found"
          log "INFO" "GRAYLOG web interface: $graylogwebgui_sysconfig_file successfully found"
          echo_failure "FAILED"
          abort_installation
        elif [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "1" ]
        then
          log "INFO" "GRAYLOG web interface: $graylogwebgui_config_file successfully found"
          log "ERROR" "GRAYLOG web interface: $graylogwebgui_sysconfig_file not found"
          echo_failure "FAILED"
          abort_installation
        else
          log "ERROR" "GRAYLOG web interface: $graylogwebgui_config_file not found"
          log "ERROR" "GRAYLOG web interface: $graylogwebgui_sysconfig_file not found"
          echo_failure "FAILED"
          abort_installation
        fi
      fi
      echo_message "Add GRAYLOG web interface on startup"
      if [ $BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP == 1 ]
      then
        std_error_output1=$(chkconfig graylog-web on 2>&1 >/dev/null)
        if [ "$std_error_output1" == "" ]
        then
          log "INFO" "GRAYLOG web interface: Successfully added on startup"
          echo_success "OK"
        else
          log "ERROR" "GRAYLOG web interface: Not added on startup"
          log "DEBUG" $std_error_output1
          echo_failure "FAILED"
        fi
      else
        std_error_output1=$(chkconfig graylog-web off 2>&1 >/dev/null)
        if [ "$std_error_output1" == "" ]
        then
          log "WARN" "GRAYLOG web interface: Not added on startup by user"
          echo_passed "PASS"
        else
          log "ERROR" "GRAYLOG web interface: Not disabled on startup"
          log "DEBUG" $std_error_output1
          echo_failure "FAILED"
        fi
      fi
    else
      log "ERROR" "GRAYLOG web interface: Not installed"
      log "DEBUG" $std_error_output1
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Install Nginx web server as a proxy to communicate with Graylog web interface
function install_nginx() {
  local installed_counter=0
  local std_error_output1=
  local std_error_output2=
  local nginx_binary_file=`which nginx 2>/dev/null`
  local nginx_config_folder="/etc/nginx/conf.d"
  local nginx_defaultconfig_file="$nginx_config_folder/default.conf"
  local nginx_defaultbackup_file="$nginx_defaultconfig_file.dist"
  local nginx_defaultssl_file="$nginx_config_folder/example_ssl.conf"
  local nginx_sslconfig_file="$nginx_config_folder/ssl.conf"
  local nginx_sslbackup_file="$nginx_sslconfig_file.dist"
  echo_message "Install NGINX web server"
  std_error_output=$(yum list installed | grep nginx.x)
  if [[ "$std_error_output" =~ ^nginx\..* ]]
  then
    ((installed_counter++))
  fi
  if [ "$installed_counter" -eq "1" ]
  then
    log "WARN" "NGINX web server: Already installed"
    echo_passed "PASS"
  else
    std_error_output1=$(yum -y install nginx 2>&1 >/dev/null)
    if [ "$std_error_output1" == "" ] || [[ "$std_error_output1" =~ [Ww]arning.* ]]
    then
      log "INFO" "NGINX web server: Successfully installed"
      std_error_output1=$(test_file ${nginx_defaultbackup_file})
      std_error_output2=$(test_file ${nginx_sslbackup_file})
      if [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "0" ]
      then
        log "WARN" "NGINX web server: $nginx_defaultconfig_file already backed-up"
        log "WARN" "NGINX web server: $nginx_sslconfig_file already backed-up"
        echo_passed "PASS"
      elif [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "1" ]
      then
        log "WARN" "NGINX web server: $nginx_defaultconfig_file already backed-up"
        log "ERROR" "NGINX web server: $nginx_sslbackup_file not found"
        echo_failure "FAILED"
        abort_installation
      elif [ "$std_error_output1" == "1" ] && [ "$std_error_output2" == "0" ]
      then
        log "ERROR" "NGINX web server: $nginx_defaultconfig_file not found"
        log "WARN" "NGINX web server: $nginx_sslbackup_file already backed-up"
        echo_failure "FAILED"
        abort_installation
      else
        std_error_output1=$(test_file ${nginx_defaultconfig_file})
        std_error_output2=$(test_file ${nginx_defaultssl_file})
        if [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "0" ]
        then
          log "INFO" "NGINX web server: $nginx_defaultconfig_file successfully found"
          log "INFO" "NGINX web server: $nginx_defaultssl_file successfully found"
          std_error_output1=$(mv ${nginx_defaultconfig_file} ${nginx_defaultbackup_file} 2>&1 >/dev/null)
          std_error_output2=$(mv ${nginx_defaultssl_file} ${nginx_sslconfig_file} 2>&1 >/dev/null)
          if [ "$std_error_output1" == "" ] && [ "$std_error_output2" == "" ]
          then
            log "INFO" "NGINX web server: $nginx_defaultconfig_file successfully backed-up"
            log "INFO" "NGINX web server: $nginx_defaultssl_file successfully backed-up"
            std_error_output1=$(sed -i.dist \
            -e "s/\#\(server .*\)/\1/" \
            -e "s/\#.*\(listen\).*\(443.*;\)/\t\1\t\t\t$SERVER_HOST_NAME:\2/" \
            -e "s/\#.*\(server_name\).*\(;\)/\t\1\t\t$SERVER_HOST_NAME\2/" \
            -e "s|\#.*\(ssl_certificate \).*\(;\)|\t\1\t$PUBLIC_KEY_FILE\2|" \
            -e "s|\#.*\(ssl_certificate_key\).*\(;\)|\t\1\t$PRIVATE_KEY_FILE\2|" \
            -e "s/\#.*\(ssl_session_cache\).*\(shared:SSL:1m;\)/\t\1\t\2/" \
            -e "s/\#.*\(ssl_session_timeout\).*\(5m;\)/\t\1\t\2/" \
            -e "s/\#.*\(ssl_ciphers\).*\(HIGH:\!aNULL:\!MD5;\)/\t\1\t\t\2/" \
            -e "s/\#.*\(ssl_prefer_server_ciphers\).*\(on;\)/\t\1\t\2/" \
            -e "s/\#.*\(location \/ {\)/\t\1/" \
            -e "s/\# .*\(\}\)/\t\1/" \
            -e "s/\#.*root.*/\t\tproxy_pass http:\/\/localhost:9000\/;\n\t\tproxy_set_header Host \$host;\n\t\tproxy_set_header X-Real-IP \$remote_addr;\n\t\tproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n\t\tproxy_connect_timeout 150;\n\t\tproxy_send_timeout 100;\n\t\tproxy_read_timeout 100;\n\t\tproxy_buffers 4 32k;\n\t\tclient_max_body_size 8m;\n\t\tclient_body_buffer_size 128k;/" \
            -e "s/\#\(\}\)/\1/" \
            -e '/\#.*index.*/d' \
            $nginx_sslconfig_file 2>&1 >/dev/null)
            if [ "$std_error_output1" == "" ]
            then
              log "INFO" "NGINX web server: $nginx_defaultssl_file successfully modified"
              echo_success "OK"
            else
              log "ERROR" "NGINX web server: $nginx_defaultssl_file not modified"
              log "DEBUG" $std_error_output1
              echo_failure "FAILED"
              abort_installation
            fi
          elif [ "$std_error_output1" != "" ] && [ "$std_error_output2" == "" ]
          then
            log "ERROR" "NGINX web server: $nginx_defaultconfig_file not backed-up"
            log "DEBUG" $std_error_output1
            log "INFO" "NGINX web server: $nginx_defaultssl_file successfully backed-up"
            echo_failure "FAILED"
            abort_installation
          elif [ "$std_error_output1" == "" ] && [ "$std_error_output2" != "" ]
          then
            log "INFO" "NGINX web server: $nginx_defaultconfig_file successfully backed-up"
            log "ERROR" "NGINX web server: $nginx_defaultssl_file not backed-up"
            log "DEBUG" $std_error_output2
            echo_failure "FAILED"
            abort_installation
          else
            log "ERROR" "NGINX web server: $nginx_defaultconfig_file not backed-up"
            log "DEBUG" $std_error_output1
            log "ERROR" "NGINX web server: $nginx_defaultssl_file not backed-up"
            log "DEBUG" $std_error_output2
            echo_failure "FAILED"
            abort_installation
          fi
        elif [ "$std_error_output1" == "1" ] && [ "$std_error_output2" == "0" ]
        then
          log "ERROR" "NGINX web server: $nginx_defaultconfig_file not found"
          log "INFO" "NGINX web server: $nginx_defaultssl_file successfully found"
          echo_failure "FAILED"
          abort_installation
        elif [ "$std_error_output1" == "0" ] && [ "$std_error_output2" == "1" ]
        then
          log "INFO" "NGINX web server: $nginx_defaultconfig_file successfully found"
          log "ERROR" "NGINX web server: $nginx_defaultssl_file not found"
          echo_failure "FAILED"
          abort_installation
        else
          log "ERROR" "NGINX web server: $nginx_defaultconfig_file not found"
          log "ERROR" "NGINX web server: $nginx_defaultssl_file not found"
          echo_failure "FAILED"
          abort_installation
        fi
      fi
      echo_message "Add NGINX service on startup"
      if [ $BOOLEAN_NGINX_ONSTARTUP == 1 ]
      then
        std_error_output1=$(chkconfig nginx on 2>&1 >/dev/null)
        if [ "$std_error_output1" == "" ]
        then
          log "INFO" "NGINX web server: Successfully added on startup"
          echo_success "OK"
        else
          log "ERROR" "NGINX web server: Not added on startup"
          log "DEBUG" $std_error_output1
          echo_failure "FAILED"
        fi
      else
        std_error_output1=$(chkconfig nginx off 2>&1 >/dev/null)
        if [ "$std_error_output1" == "" ]
        then
          log "WARN" "NGINX web server: Not added on startup by user"
          echo_passed "PASS"
        else
          log "ERROR" "NGINX web server: Not disabled on startup"
          log "DEBUG" $std_error_output1
          echo_failure "FAILED"
        fi
      fi
    else
      log "ERROR" "NGINX web server: Not installed"
      log "DEBUG" $std_error_output1
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Display Graylog informations (URL, login and password of admin account)
function display_informations() {
  echo -e "\n###################################################################"
  echo -e "#${MOVE_TO_COL1}#\n# To administrate Graylog server${MOVE_TO_COL1}#"
  echo -e "# - URL\t: ${SETCOLOR_INFO}https://$SERVER_HOST_NAME${SETCOLOR_NORMAL}${MOVE_TO_COL1}#\n#${MOVE_TO_COL1}#"
  echo -e "# Admin account${MOVE_TO_COL1}#"
  echo -e "# - Login\t: ${SETCOLOR_INFO}$GRAYLOG_ADMIN_USERNAME${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# - Password\t: ${SETCOLOR_INFO}$GRAYLOG_ADMIN_PASSWORD${SETCOLOR_NORMAL}${MOVE_TO_COL1}#\n#${MOVE_TO_COL1}#"
  echo -e "###################################################################"
  if [ $BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN -eq 1 ]
  then
    echo -e "\n###################################################################"
    echo -e "#${MOVE_TO_COL1}#\n# To administrate ElasticSearch server${MOVE_TO_COL1}#"
    echo -e "# - URL\t: ${SETCOLOR_INFO}http://$SERVER_HOST_NAME:9200/_plugin/HQ/${SETCOLOR_NORMAL}${MOVE_TO_COL1}#\n#${MOVE_TO_COL1}#"
    echo -e "###################################################################"
  fi
  echo -e "\n\n    ${SETCOLOR_WARNING}!!! You MUST restart the server after this installation !!!${SETCOLOR_NORMAL}    \n\n"
}
# Display help to use this installation program
function display_help() {
  local program=$0
  echo -e "Usage: $program -i|a <file>"
  echo -e "  -i\tInstall Graylog Components in interactive mode"
  echo -e "  -a\tInstall Graylog components in auto mode"
  echo -e "  -h\tDisplay this help"
  echo -e "\nExample:\n   $program -a /root/graylog_variables.cfg"
  exit 1
}
# Main loop
function main {
  log "INFO" "GRAYLOG installation: Begin"
  test_internet
  if [ "$INSTALLATION_CFG_FILE" == "" ]
  then
    set_globalvariables
  else
    if [[ "$INSTALLATION_CFG_FILE" =~ .*\.cfg$ ]]
    then
      std_error_output=$(test_file ${INSTALLATION_CFG_FILE})
      if [ "$std_error_output" == "0" ]
      then
        log "INFO" "Global variables: $INSTALLATION_CFG_FILE successfully found"
        if [ -z "$INSTALLATION_CFG_FILE" ]
        then
          log "ERROR" "Global variables: Not loaded"
          abort_installation
        else
          source $INSTALLATION_CFG_FILE
          log "INFO" "Global variables: Successfully loaded"
          verify_globalvariables
        fi
      else
        log "ERROR" "Global variables: $INSTALLATION_CFG_FILE not found"
        abort_installation
      fi
    else
      log "ERROR" "Global variables: $INSTALLATION_CFG_FILE bad extension"
      abort_installation
    fi
  fi
#  get_sysinfo
#  generate_sslkeys
#  configure_yum
#  initialize_yum
#  upgrade_os
#  install_ntp
#  install_lsbpackages
#  install_networkpackages
#  configure_bashrc
#  configure_openssh
#  if [ $BOOLEAN_USE_OPENSSHKEY -eq 1 ]
#  then
#    add_opensshkey
#  else
#    echo_message "Add OpenSSH Key"
#    log "WARN" "SSH personal key: operation cancelled by user"
#    echo_passed "PASS"
#  fi
#  configure_postfix
#  configure_hostsfile
#  configure_selinux
#  install_mongodb
#  install_java
#  install_elasticsearch
#  install_graylogserver
#  install_graylogwebgui
#  install_nginx
#  display_informations
  log "INFO" "GRAYLOG installation: Successfully completed"
}
#==============================================================================

#==============================================================================
# Program
#==============================================================================
OPTIND=1
while getopts ":hia:" options
do
  case ${options} in
    i )
      main
      ;;
    a )
      INSTALLATION_CFG_FILE=$OPTARG
      main
      ;;
    : )
      display_help
      exit 1
      ;;
    \?|h)
      display_help
      exit 0
      ;;
    * )
      display_help
      exit 1
      ;;
  esac
done
shift "$((OPTIND-1))"
exit 0
#==============================================================================
