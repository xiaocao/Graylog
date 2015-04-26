#!/bin/bash
#==============================================================================
#title         : install_graylog.sh
#description   : This script will install Graylog components (server and web).
#author        : Mikaël ANDRE
#job title     : Network engineer
#mail          : mikael.andre.1989@gmail.com
#created       : 20150219
#last revision : 20150426
#version       : 1.4
#platform      : Linux
#processor     : 64 Bits
#os            : CentOS
#os version    : 6.5 or 6.6
#usage         : sh install_graylog.sh -i | -a <file.cfg> | -v (options)
#                options are --cfg <file.cfg> | --cnx | --sys
#notes         : Copy and paste in Vi to use this script
#==============================================================================

#==============================================================================
# Global variables
#==============================================================================
# SCRIPT VARIABLES
SCRIPT_MODE=
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
INSTALLATION_LOG_FILE="${INSTALLATION_LOG_FOLDER}/install_graylog_${INSTALLATION_LOG_TIMESTAMP}.log"
INSTALLATION_CFG_FILE=
# NETWORK VARIABLES
NETWORK_INTERFACE_NAME=
# NTP VARIABLES
BOOLEAN_NTP_ONSTARTUP=
BOOLEAN_NTP_CONFIGURE=
NEW_NTP_ADDRESS=
# SSH VARIABLES
BOOLEAN_RSA_AUTH=
RSA_PUBLIC_KEY=
# MONGO VARIABLES
BOOLEAN_MONGO_ONSTARTUP=
MONGODB_ADMIN_DATABASE='admin'
MONGO_ADMIN_USER='admin'
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
ELASTICSEARCH_RAM_RESERVATION=
GRAYLOGSERVER_RAM_RESERVATION=
#GRAYLOGWEBGUI_RAM_RESERVATION="256m"
# ELASTICSEARCH VARIABLES
BOOLEAN_ELASTICSEARCH_ONSTARTUP=
BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN=
# GRAYLOG VARIABLES
BOOLEAN_GRAYLOGSERVER_ONSTARTUP=
BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP=
GRAYLOG_SECRET_PASSWORD=
GRAYLOG_ADMIN_USERNAME=
GRAYLOG_ADMIN_PASSWORD=
BOOLEAN_GRAYLOG_SMTP=
# SMTP VARIABLES
SMTP_HOST_NAME=
SMTP_DOMAIN_NAME=
SMTP_PORT_NUMBER=
BOOLEAN_SMTP_AUTH=
BOOLEAN_SMTP_TLS=
BOOLEAN_SMTP_SSL=
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
SETCOLOR_DISABLE="\\033[0;90m"
SETCOLOR_NORMAL="\\033[0;39m"
#==============================================================================

#==============================================================================
# Functions
#==============================================================================
# Log function to write all events during installation process
function log() {
  local program_name=${0}
  local message_type=${1}
  shift
  local message_content=${@}
  echo -e "$(date) [${program_name}]: ${message_type}: ${message_content}" >> ${INSTALLATION_LOG_FILE}
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
  local input_message=${1}
  local default_answer=${2}
  local user_answer="UNDEF"
  while [[ !( "${user_answer}" =~ ^[Yy][Ee][Ss]$|^[Yy]$ ) && !( "${user_answer}" =~ ^[Nn][Oo]$|^[Nn]$ ) && !( -z "${user_answer}" ) ]]
  do
    echo -e "\n${input_message}\n[y/n], default to [${SETCOLOR_INFO}${default_answer}${SETCOLOR_NORMAL}]:"
    echo -en "> "
    read user_answer
    if [ -z "${user_answer}" ]
    then
      user_answer=${default_answer}
    fi
  done
  if [[ "${user_answer}" =~ ^[Yy][Ee][Ss]$|^[Yy]$ ]]
  then 
    return 0
  else 
    return 1
  fi
}
# Abort function and inform user to read log file for more informations on bad ending
function abort_installation() {
  log "ERROR" "GRAYLOG installation: Abort"
  echo_message "Check log file : ${INSTALLATION_LOG_FILE}"
  echo_info "INFO"
  if [ ! -z "${INSTALLATION_CFG_FILE}" ]
  then
    if [[ "${INSTALLATION_CFG_FILE}" =~ .*\.cfg$ ]]
    then
      log "INFO" "GRAYLOG installation: After debugging, launch again installation process with ${0} -a ${INSTALLATION_CFG_FILE}"
    fi
  fi
  exit 1
}
# Return 0 if file exists or 1 if not
function test_file() {
  local input_file=${1}
  local is_exist=
  if [ -f "${input_file}" ]
  then
    is_exist=0
  else
    is_exist=1
  fi
  echo ${is_exist}
}
# Return 0 if directory exists or 1 if not
function test_directory() {
  local input_folder=${1}
  local is_exist=
  if [ -d "${input_folder}" ]
  then
    is_exist=0
  else
    is_exist=1
  fi
  echo ${is_exist}
}
# Return 0 if search pattern is present in specified file or 1 if not
function find_pattern() {
  local input_file=${1}
  local input_pattern=${1}
  local find_command=
  local is_present=
  find_command=$(find ${input_file} -type f -print | xargs grep "${input_pattern}")
  if [ -z "${find_command}" ]
  then
    is_present=1
  else
    is_present=0
  fi
  echo ${is_present}
}
# Test DNS configuration and send 4 icmp packets
function test_internet() {
  local icmp_packets_sent=4
  local icmp_packets_received=
  local internet_host_name="www.google.fr"
  local icmp_time_out=5
  echo_message "Check Internet connection"
  log "INFO" "Internet connection: Check connection to ${internet_host_name}"
  icmp_packets_received=$(ping -c ${icmp_packets_sent} -W ${icmp_time_out} ${internet_host_name} 2>&1)
  if [[ ! "${icmp_packets_received}" =~ .*unknown.* ]]
  then
    log "INFO" "Internet connection: DNS successfully configured"
    log "INFO" "Internet connection: ICMP packets sent=${icmp_packets_sent}"
    icmp_packets_received=$(ping -c ${icmp_packets_sent} -W ${icmp_time_out} ${internet_host_name} | grep "received" | awk -F: '{print $1}' | awk '{print $4}')
    if [ "${icmp_packets_received}" == ${icmp_packets_sent} ]
    then
      log "INFO" "Internet connection: ICMP packets received=${icmp_packets_received}"
      echo_success "OK"
      if [[ ${SCRIPT_MODE} =~ v_cnx ]]
      then
        echo_message "Check log file : ${INSTALLATION_LOG_FILE}"
        echo_info "INFO"
      fi
    else
      log "ERROR" "Internet connection: ICMP packets received=${icmp_packets_received}"
      echo_failure "FAILED"
      abort_installation
    fi
  else
    log "ERROR" "Internet connection: Unable to resolve ${internet_host_name}"
    echo_failure "FAILED"
    abort_installation
  fi
}
# Set all global variables using inputs user
function set_globalvariables() {
  local command_output_message=
  local old_input_value=
  local installation_cfg_tmpfile="${INSTALLATION_LOG_FOLDER}/install_graylog_${INSTALLATION_LOG_TIMESTAMP}.cfg"
  local mailaddress_regular_expression="^[a-z0-9,!#\$%&'\*\+/=\?\^_\`\{\|}~-]+(\.[a-z0-9,!#\$%&'\*\+/=\?\^_\`\{\|}~-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*\.([a-z]{2,})$"
  if [ "${SCRIPT_MODE}" == "i" ]
  then
    command_output_message=$(test_file ${installation_cfg_tmpfile})
    if [ "${command_output_message}" == "0" ]
    then
      log "WARN" "Global variables: ${installation_cfg_tmpfile} already created"
    else
      touch ${installation_cfg_tmpfile}
      log "INFO" "Global variables: ${installation_cfg_tmpfile} successfully created"
    fi
  else
    installation_cfg_tmpfile=${INSTALLATION_CFG_FILE}
    log "INFO" "Global variables: ${installation_cfg_tmpfile} successfully selected"
  fi
  if [ -z "${NETWORK_INTERFACE_NAME}" ]
  then
    while [ -z "${NETWORK_INTERFACE_NAME}" ]
    do
      echo -e "\nType network interface name, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}eth0${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read NETWORK_INTERFACE_NAME
      if [ -z "${NETWORK_INTERFACE_NAME}" ]
      then
        NETWORK_INTERFACE_NAME='eth0'
      fi
    done
  else
    yes_no_function "Can you confirm you want to modify current interface name ?" "yes"
    if [ "${?}" == "0" ]
    then
      old_input_value=${NETWORK_INTERFACE_NAME}
      NETWORK_INTERFACE_NAME=
      while [ -z "${NETWORK_INTERFACE_NAME}" ]
      do
        echo -e "\nType network interface name, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read NETWORK_INTERFACE_NAME
        if [ -z "${NETWORK_INTERFACE_NAME}" ]
        then
          NETWORK_INTERFACE_NAME=${old_input_value}
        fi
      done
    else
      NETWORK_INTERFACE_NAME=${old_input_value}
    fi
  fi
  echo "NETWORK_INTERFACE_NAME='${NETWORK_INTERFACE_NAME}'" > ${installation_cfg_tmpfile}
  if [ -z "${BOOLEAN_RSA_AUTH}" ]
  then
    yes_no_function "Do you want to use RSA authentication on GRAYLOG back-end server ?" "yes"
    if [ "${?}" == "0" ]
    then
      BOOLEAN_RSA_AUTH="true"
    else
      BOOLEAN_RSA_AUTH="false"
    fi
  else
    if [[ "${BOOLEAN_RSA_AUTH}" =~ true ]]
    then
      yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}not use${SETCOLOR_NORMAL} RSA authentication ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_RSA_AUTH="false"
      else
        BOOLEAN_RSA_AUTH=${BOOLEAN_RSA_AUTH}
      fi
    else
      yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}use${SETCOLOR_NORMAL} RSA authentication ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_RSA_AUTH="true"
      else
        BOOLEAN_RSA_AUTH=${BOOLEAN_RSA_AUTH}
      fi
    fi
  fi
  if [[ "${BOOLEAN_RSA_AUTH}" =~ true ]]
  then
    if [ -z "${RSA_PUBLIC_KEY}" ]
    then
      while [ -z "${RSA_PUBLIC_KEY}" ] || [[ ! "${RSA_PUBLIC_KEY}" =~ ^ssh-rsa.* ]]
      do
        echo -e "Paste your RSA public key, followed by [ENTER]:"
        echo -en "> "
        read RSA_PUBLIC_KEY
      done
    else
      old_input_value=${RSA_PUBLIC_KEY}
      yes_no_function "Can you confirm you want to modify current RSA public key" "yes"
      if [ "${?}" == "0" ]
      then
        RSA_PUBLIC_KEY=
        while [ -z "${RSA_PUBLIC_KEY}" ] || [[ ! "${RSA_PUBLIC_KEY}" =~ ^ssh-rsa.* ]]
        do
          echo -e "Paste your RSA public key, followed by [ENTER]"
          echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
          echo -en "> "
          read RSA_PUBLIC_KEY
          if [ -z "${RSA_PUBLIC_KEY}" ]
          then
            RSA_PUBLIC_KEY=${old_input_value}
          fi
        done
      else
        RSA_PUBLIC_KEY=${old_input_value}
      fi
    fi
  else
    RSA_PUBLIC_KEY=
  fi
  echo "BOOLEAN_RSA_AUTH='${BOOLEAN_RSA_AUTH}'" >> ${installation_cfg_tmpfile}
  echo "RSA_PUBLIC_KEY='${RSA_PUBLIC_KEY}'" >> ${installation_cfg_tmpfile}
  if [ -z "${SERVER_TIME_ZONE}" ]
  then
    while [ -z "${SERVER_TIME_ZONE}" ]
    do
      echo -e "\nType timezone, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}Europe/Paris${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read SERVER_TIME_ZONE
      if [ -z "${SERVER_TIME_ZONE}" ]
      then
        SERVER_TIME_ZONE='Europe/Paris'
      fi
    done
  else
    old_input_value=${SERVER_TIME_ZONE}
    yes_no_function "Can you confirm you want to modify current time zone ?" "yes"
    if [ "${?}" == "0" ]
    then
      SERVER_TIME_ZONE=
      while [ -z "${SERVER_TIME_ZONE}" ]
      do
        echo -e "\nType timezone, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read SERVER_TIME_ZONE
        if [ -z "${SERVER_TIME_ZONE}" ]
        then
          SERVER_TIME_ZONE=${old_input_value}
        fi
      done
    else
      SERVER_TIME_ZONE=${old_input_value}
    fi
  fi
  echo "SERVER_TIME_ZONE='${SERVER_TIME_ZONE}'" >> ${installation_cfg_tmpfile}
  if [ -z "${BOOLEAN_NTP_CONFIGURE}" ]
  then
    yes_no_function "Do you want to configure NTP service ?" "yes"
    if [ "${?}" == "0" ]
    then
      BOOLEAN_NTP_CONFIGURE="true"
    else
      BOOLEAN_NTP_CONFIGURE="false"
    fi
  else
    if [[ "${BOOLEAN_NTP_CONFIGURE}" =~ true ]]
    then
      yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}not configure${SETCOLOR_NORMAL} NTP service ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_NTP_CONFIGURE="false"
      else
        BOOLEAN_NTP_CONFIGURE=${BOOLEAN_NTP_CONFIGURE}
      fi
    else
      yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}configure${SETCOLOR_NORMAL} NTP service ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_NTP_CONFIGURE="true"
      else
        BOOLEAN_NTP_CONFIGURE=${BOOLEAN_NTP_CONFIGURE}
      fi
    fi
  fi
  if [[ "${BOOLEAN_NTP_CONFIGURE}" =~ true ]]
  then
    if [ -z "${NEW_NTP_ADDRESS}" ]
    then
      while [[ ! "${NEW_NTP_ADDRESS}" =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]] && [[ ! "${NEW_NTP_ADDRESS}" =~ ^(([a-zA-Z0-9](-?[a-zA-Z0-9])*)\.)*[a-zA-Z0-9](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}$ ]]
      do
        echo -e "\nType IP address or hostname of NTP server, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_INFO}ntp.test.fr${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read NEW_NTP_ADDRESS
        if [ -z "${NEW_NTP_ADDRESS}" ]
        then
          NEW_NTP_ADDRESS='ntp.test.fr'
        fi
      done
    else
      old_input_value=${NEW_NTP_ADDRESS}
      yes_no_function "Can you confirm you want to modify current NTP server ?" "yes"
      if [ "${?}" == "0" ]
      then
        NEW_NTP_ADDRESS=
        while [[ ! "${NEW_NTP_ADDRESS}" =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]] && [[ ! "${NEW_NTP_ADDRESS}" =~ ^(([a-zA-Z0-9](-?[a-zA-Z0-9])*)\.)*[a-zA-Z0-9](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}$ ]]
        do
          echo -e "\nType IP address or hostname of NTP server, followed by [ENTER]"
          echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
          echo -en "> "
          read NEW_NTP_ADDRESS
          if [ -z "${NEW_NTP_ADDRESS}" ]
          then
            NEW_NTP_ADDRESS=${old_input_value}
          fi
        done
      else
        NEW_NTP_ADDRESS=${old_input_value}
      fi
    fi
  else
    NEW_NTP_ADDRESS=
  fi
  echo "BOOLEAN_NTP_CONFIGURE='${BOOLEAN_NTP_CONFIGURE}'" >> ${installation_cfg_tmpfile}
  echo "NEW_NTP_ADDRESS='${NEW_NTP_ADDRESS}'" >> ${installation_cfg_tmpfile}
  if [ -z "${BOOLEAN_NTP_ONSTARTUP}" ]
  then
    yes_no_function "Do you want to add NTP service on startup ?" "yes"
    if [ "${?}" == "0" ]
    then
      BOOLEAN_NTP_ONSTARTUP="true"
    else
      BOOLEAN_NTP_ONSTARTUP="false"
    fi
  else
    if [[ "${BOOLEAN_NTP_ONSTARTUP}" =~ true ]]
    then
      yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}disable${SETCOLOR_NORMAL} NTP service on startup ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_NTP_ONSTARTUP="false"
      else
        BOOLEAN_NTP_ONSTARTUP=${BOOLEAN_NTP_ONSTARTUP}
      fi
    else
      yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}enable${SETCOLOR_NORMAL} NTP service on startup ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_NTP_ONSTARTUP="true"
      else
        BOOLEAN_NTP_ONSTARTUP=${BOOLEAN_NTP_ONSTARTUP}
      fi
    fi
  fi
  echo "BOOLEAN_NTP_ONSTARTUP='${BOOLEAN_NTP_ONSTARTUP}'" >> ${installation_cfg_tmpfile}
  if [ -z "${MONGO_ADMIN_PASSWORD}" ]
  then
    while [ -z "${MONGO_ADMIN_PASSWORD}" ]
    do
      echo -e "\nType password of Mongo administrator, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}admin4mongo${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read MONGO_ADMIN_PASSWORD
      if [ -z "${MONGO_ADMIN_PASSWORD}" ]
      then
        MONGO_ADMIN_PASSWORD='admin4mongo'
      fi
    done
  else
    old_input_value=${MONGO_ADMIN_PASSWORD}
    yes_no_function "Can you confirm you want to modify current password of Mongo administrator ?" "yes"
    if [ "${?}" == "0" ]
    then
      MONGO_ADMIN_PASSWORD=
      while [ -z "${MONGO_ADMIN_PASSWORD}" ]
      do
        echo -e "\nType password of Mongo administrator, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read MONGO_ADMIN_PASSWORD
        if [ -z "${MONGO_ADMIN_PASSWORD}" ]
        then
          MONGO_ADMIN_PASSWORD=${old_input_value}
        fi
      done
    else
      MONGO_ADMIN_PASSWORD=${old_input_value}
    fi
  fi
  echo "MONGO_ADMIN_PASSWORD='${MONGO_ADMIN_PASSWORD}'" >> ${installation_cfg_tmpfile}
  if [ -z "${MONGO_GRAYLOG_DATABASE}" ]
  then
    while [ -z "${MONGO_GRAYLOG_DATABASE}" ]
    do
      echo -e "\nType name of Graylog Mongo database, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}graylog${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read MONGO_GRAYLOG_DATABASE
      if [ -z "${MONGO_GRAYLOG_DATABASE}" ]
      then
        MONGO_GRAYLOG_DATABASE='graylog'
      fi
    done
  else
    old_input_value=${MONGO_GRAYLOG_DATABASE}
    yes_no_function "Can you confirm you want to modify current name of Graylog Mongo database ?" "yes"
    if [ "${?}" == "0" ]
    then
      MONGO_GRAYLOG_DATABASE=
      while [ -z "${MONGO_GRAYLOG_DATABASE}" ]
      do
        echo -e "\nType name of Graylog Mongo database, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read MONGO_GRAYLOG_DATABASE
        if [ -z "${MONGO_GRAYLOG_DATABASE}" ]
        then
          MONGO_GRAYLOG_DATABASE=${old_input_value}
        fi
      done
    else
      MONGO_GRAYLOG_DATABASE=${old_input_value}
    fi
  fi
  echo "MONGO_GRAYLOG_DATABASE='${MONGO_GRAYLOG_DATABASE}'" >> ${installation_cfg_tmpfile}
  if [ -z "${MONGO_GRAYLOG_USER}" ]
  then
    while [ -z "${MONGO_GRAYLOG_USER}" ]
    do
      echo -e "\nType login of Mongo Graylog user, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}grayloguser${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read MONGO_GRAYLOG_USER
      if [ -z "${MONGO_GRAYLOG_USER}" ]
      then
        MONGO_GRAYLOG_USER='grayloguser'
      fi
    done
  else
    old_input_value=${MONGO_GRAYLOG_USER}
    yes_no_function "Can you confirm you want to modify current login of Mongo Graylog user ?" "yes"
    if [ "${?}" == "0" ]
    then
      MONGO_GRAYLOG_USER=
      while [ -z "${MONGO_GRAYLOG_USER}" ]
      do
        echo -e "\nType login of Mongo Graylog user, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read MONGO_GRAYLOG_USER
        if [ -z "${MONGO_GRAYLOG_USER}" ]
        then
          MONGO_GRAYLOG_USER=${old_input_value}
        fi
      done
    else
      MONGO_GRAYLOG_USER=${old_input_value}
    fi
  fi
  echo "MONGO_GRAYLOG_USER='${MONGO_GRAYLOG_USER}'" >> ${installation_cfg_tmpfile}
  if [ -z "${MONGO_GRAYLOG_PASSWORD}" ]
  then
    while [ -z "${MONGO_GRAYLOG_PASSWORD}" ]
    do
      echo -e "\nType password of Mongo Graylog user, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}graylog4mongo${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read MONGO_GRAYLOG_PASSWORD
      if [ -z "${MONGO_GRAYLOG_PASSWORD}" ]
      then
        MONGO_GRAYLOG_PASSWORD='graylog4mongo'
      fi
    done
  else
    old_input_value=${MONGO_GRAYLOG_PASSWORD}
    yes_no_function "Can you confirm you want to modify current password of Mongo Graylog user ?" "yes"
    if [ "${?}" == "0" ]
    then
      MONGO_GRAYLOG_PASSWORD=
      while [ -z "${MONGO_GRAYLOG_PASSWORD}" ]
      do
        echo -e "\nType password of Mongo Graylog user, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read MONGO_GRAYLOG_PASSWORD
        if [ -z "${MONGO_GRAYLOG_PASSWORD}" ]
        then
          MONGO_GRAYLOG_PASSWORD=${old_input_value}
        fi
      done
    else
      MONGO_GRAYLOG_PASSWORD=${old_input_value}
    fi
  fi
  echo "MONGO_GRAYLOG_PASSWORD='${MONGO_GRAYLOG_PASSWORD}'" >> ${installation_cfg_tmpfile}
  if [ -z "${BOOLEAN_MONGO_ONSTARTUP}" ]
  then
    yes_no_function "Do you want to add Mongo database server on startup ?" "yes"
    if [ "${?}" == "0" ]
    then
      BOOLEAN_MONGO_ONSTARTUP="true"
    else
      BOOLEAN_MONGO_ONSTARTUP="false"
    fi
  else
    if [[ "${BOOLEAN_MONGO_ONSTARTUP}" =~ true ]]
    then
      yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}disable${SETCOLOR_NORMAL} Mongo database server on startup ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_MONGO_ONSTARTUP="false"
      else
        BOOLEAN_MONGO_ONSTARTUP=${BOOLEAN_MONGO_ONSTARTUP}
      fi
    else
      yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}enable${SETCOLOR_NORMAL} Mongo database server on startup ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_MONGO_ONSTARTUP="true"
      else
        BOOLEAN_MONGO_ONSTARTUP=${BOOLEAN_MONGO_ONSTARTUP}
      fi
    fi
  fi
  echo "BOOLEAN_MONGO_ONSTARTUP='${BOOLEAN_MONGO_ONSTARTUP}'" >> ${installation_cfg_tmpfile}
  if [ -z "${SSL_KEY_SIZE}" ]
  then
    while [[ ! "${SSL_KEY_SIZE}" =~ 512|1024|2048|4096 ]]
    do
      echo -e "\nType size of SSL private key (possible values : ${SETCOLOR_FAILURE}512${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}1024${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}2048${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}4096${SETCOLOR_NORMAL}), followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}2048${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read SSL_KEY_SIZE
      if [ -z "${SSL_KEY_SIZE}" ]
      then
        SSL_KEY_SIZE='2048'
      fi
    done
  else
    old_input_value=${SSL_KEY_SIZE}
    yes_no_function "Can you confirm you want to modify current size of SSL private key ?" "yes"
    if [ "${?}" == "0" ]
    then
      SSL_KEY_SIZE=
      while [[ ! "${SSL_KEY_SIZE}" =~ 512|1024|2048|4096 ]]
      do
        echo -e "\nType size of SSL private key (possible values : ${SETCOLOR_FAILURE}512${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}1024${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}2048${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}4096${SETCOLOR_NORMAL}), followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read SSL_KEY_SIZE
        if [ -z "${SSL_KEY_SIZE}" ]
        then
          SSL_KEY_SIZE=${old_input_value}
        fi
      done
    else
      SSL_KEY_SIZE=${old_input_value}
    fi
  fi
  echo "SSL_KEY_SIZE='${SSL_KEY_SIZE}'" >> ${installation_cfg_tmpfile}
  if [ -z "${SSL_KEY_DURATION}" ]
  then
    while [[ ! "${SSL_KEY_DURATION}" =~ [0-9]{1,5} ]]
    do
      echo -e "\nType period of validity (in day) of SSL certificate, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}365${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read SSL_KEY_DURATION
      if [ -z "${SSL_KEY_DURATION}" ]
      then
        SSL_KEY_DURATION='365'
      fi
    done
  else
    old_input_value=${SSL_KEY_DURATION}
    yes_no_function "Can you confirm you want to modify current period of validity of SSL Certificate ?" "yes"
    if [ "${?}" == "0" ]
    then
      SSL_KEY_DURATION=
      while [[ ! "${SSL_KEY_DURATION}" =~ [0-9]{1,5} ]]
      do
        echo -e "\nType period of validity (in day) of SSL certificate, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read SSL_KEY_DURATION
        if [ -z "${SSL_KEY_DURATION}" ]
        then
          SSL_KEY_DURATION=${old_input_value}
        fi
      done
    else
      SSL_KEY_DURATION=${old_input_value}
    fi
  fi
  echo "SSL_KEY_DURATION='${SSL_KEY_DURATION}'" >> ${installation_cfg_tmpfile}
  if [ -z "${SSL_SUBJECT_COUNTRY}" ]
  then
    while [[ ! "${SSL_SUBJECT_COUNTRY}" =~ [A-Z]{2,3} ]]
    do
      echo -e "\nType country code of SSL certificate, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}FR${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read SSL_SUBJECT_COUNTRY
      if [ -z "${SSL_SUBJECT_COUNTRY}" ]
      then
        SSL_SUBJECT_COUNTRY='FR'
      fi
    done
  else
    old_input_value=${SSL_SUBJECT_COUNTRY}
    yes_no_function "Can you confirm you want to modify current country code of SSL Certificate ?" "yes"
    if [ "${?}" == "0" ]
    then
      SSL_SUBJECT_COUNTRY=
      while [[ ! "${SSL_SUBJECT_COUNTRY}" =~ [A-Z]{2,3} ]]
      do
        echo -e "\nType country code of SSL certificate, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read SSL_SUBJECT_COUNTRY
        if [ -z "${SSL_SUBJECT_COUNTRY}" ]
        then
          SSL_SUBJECT_COUNTRY=${old_input_value}
        fi
      done
    else
      SSL_SUBJECT_COUNTRY=${old_input_value}
    fi
  fi
  echo "SSL_SUBJECT_COUNTRY='${SSL_SUBJECT_COUNTRY}'" >> ${installation_cfg_tmpfile}
  if [ -z "${SSL_SUBJECT_STATE}" ]
  then
    while [ -z "${SSL_SUBJECT_STATE}" ]
    do
      echo -e "\nType state of SSL certificate, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}STATE${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read SSL_SUBJECT_STATE
      if [ -z "${SSL_SUBJECT_STATE}" ]
      then
        SSL_SUBJECT_STATE='STATE'
      fi
    done
  else
    old_input_value=${SSL_SUBJECT_STATE}
    yes_no_function "Can you confirm you want to modify current state of SSL Certificate ?" "yes"
    if [ "${?}" == "0" ]
    then
      SSL_SUBJECT_STATE=
      while [ -z "${SSL_SUBJECT_STATE}" ]
      do
        echo -e "\nType state of SSL certificate, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read SSL_SUBJECT_STATE
        if [ -z "${SSL_SUBJECT_STATE}" ]
        then
          SSL_SUBJECT_STATE=${old_input_value}
        fi
      done
    else
      SSL_SUBJECT_STATE=${old_input_value}
    fi
  fi
  echo "SSL_SUBJECT_STATE='${SSL_SUBJECT_STATE}'" >> ${installation_cfg_tmpfile}
  if [ -z "${SSL_SUBJECT_LOCALITY}" ]
  then
    while [ -z "${SSL_SUBJECT_LOCALITY}" ]
    do
      echo -e "\nType state of SSL certificate, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}LOCALITY${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read SSL_SUBJECT_LOCALITY
      if [ -z "${SSL_SUBJECT_LOCALITY}" ]
      then
        SSL_SUBJECT_LOCALITY='LOCALITY'
      fi
    done
  else
    old_input_value=${SSL_SUBJECT_LOCALITY}
    yes_no_function "Can you confirm you want to modify current locality of SSL Certificate ?" "yes"
    if [ "${?}" == "0" ]
    then
      SSL_SUBJECT_LOCALITY=
      while [ -z "${SSL_SUBJECT_LOCALITY}" ]
      do
        echo -e "\nType state of SSL certificate, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read SSL_SUBJECT_LOCALITY
        if [ -z "${SSL_SUBJECT_LOCALITY}" ]
        then
          SSL_SUBJECT_LOCALITY=${old_input_value}
        fi
      done
    else
      SSL_SUBJECT_LOCALITY=${old_input_value}
    fi
  fi
  echo "SSL_SUBJECT_LOCALITY='${SSL_SUBJECT_LOCALITY}'" >> ${installation_cfg_tmpfile}
  if [ -z "${SSL_SUBJECT_ORGANIZATION}" ]
  then
    while [ -z "${SSL_SUBJECT_ORGANIZATION}" ]
    do
      echo -e "\nType organization name of SSL certificate, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}ORGANIZATION${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read SSL_SUBJECT_ORGANIZATION
      if [ -z "${SSL_SUBJECT_ORGANIZATION}" ]
      then
        SSL_SUBJECT_ORGANIZATION='ORGANIZATION'
      fi
    done
  else
    old_input_value=${SSL_SUBJECT_ORGANIZATION}
    yes_no_function "Can you confirm you want to modify current organization name of SSL Certificate ?" "yes"
    if [ "${?}" == "0" ]
    then
      SSL_SUBJECT_ORGANIZATION=
      while [ -z "${SSL_SUBJECT_ORGANIZATION}" ]
      do
        echo -e "\nType organization name of SSL certificate, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read SSL_SUBJECT_ORGANIZATION
        if [ -z "${SSL_SUBJECT_ORGANIZATION}" ]
        then
          SSL_SUBJECT_ORGANIZATION=${old_input_value}
        fi
      done
    else
      SSL_SUBJECT_ORGANIZATION=${old_input_value}
    fi
  fi
  echo "SSL_SUBJECT_ORGANIZATION='${SSL_SUBJECT_ORGANIZATION}'" >> ${installation_cfg_tmpfile}
  if [ -z "${SSL_SUBJECT_ORGANIZATIONUNIT}" ]
  then
    while [ -z "${SSL_SUBJECT_ORGANIZATIONUNIT}" ]
    do
      echo -e "\nType organization unit name of SSL certificate, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}ORGANIZATION UNIT${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read SSL_SUBJECT_ORGANIZATIONUNIT
      if [ -z "${SSL_SUBJECT_ORGANIZATIONUNIT}" ]
      then
        SSL_SUBJECT_ORGANIZATIONUNIT='ORGANIZATION UNIT'
      fi
    done
  else
    old_input_value=${SSL_SUBJECT_ORGANIZATIONUNIT}
    yes_no_function "Can you confirm you want to modify current organization unit name of SSL Certificate ?" "yes"
    if [ "${?}" == "0" ]
    then
      SSL_SUBJECT_ORGANIZATIONUNIT=
      while [ -z "${SSL_SUBJECT_ORGANIZATIONUNIT}" ]
      do
        echo -e "\nType organization unit name of SSL certificate, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read SSL_SUBJECT_ORGANIZATIONUNIT
        if [ -z "${SSL_SUBJECT_ORGANIZATIONUNIT}" ]
        then
          SSL_SUBJECT_ORGANIZATIONUNIT=${old_input_value}
        fi
      done
    else
      SSL_SUBJECT_ORGANIZATIONUNIT=${old_input_value}
    fi
  fi
  echo "SSL_SUBJECT_ORGANIZATIONUNIT='${SSL_SUBJECT_ORGANIZATIONUNIT}'" >> ${installation_cfg_tmpfile}
  if [ -z "${SSL_SUBJECT_EMAIL}" ]
  then
    while [[ ! "${SSL_SUBJECT_EMAIL}" =~ ${mailaddress_regular_expression} ]]
    do
      echo -e "\nType organization unit name of SSL certificate, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}mail.address@test.fr${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read SSL_SUBJECT_EMAIL
      if [ -z "${SSL_SUBJECT_EMAIL}" ]
      then
        SSL_SUBJECT_EMAIL='mail.address@test.fr'
      fi
    done
  else
    old_input_value=${SSL_SUBJECT_EMAIL}
    yes_no_function "Can you confirm you want to modify current e-mail address of SSL Certificate ?" "yes"
    if [ "${?}" == "0" ]
    then
      SSL_SUBJECT_EMAIL=
      while [[ ! "${SSL_SUBJECT_EMAIL}" =~ ${mailaddress_regular_expression} ]]
      do
        echo -e "\nType organization unit name of SSL certificate, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read SSL_SUBJECT_EMAIL
        if [ -z "${SSL_SUBJECT_EMAIL}" ]
        then
          SSL_SUBJECT_EMAIL=${old_input_value}
        fi
      done
    else
      SSL_SUBJECT_EMAIL=${old_input_value}
    fi
  fi
  echo "SSL_SUBJECT_EMAIL='${SSL_SUBJECT_EMAIL}'" >> ${installation_cfg_tmpfile}
  if [ -z "${BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN}" ]
  then
    yes_no_function "Do you want to install HQ plugin to manage ElasticSearch ?" "yes"
    if [ "${?}" == "0" ]
    then
      BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN="true"
    else
      BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN="false"
    fi
  else
    if [[ "${BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN}" =~ true ]]
    then
      yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}not install${SETCOLOR_NORMAL} ElasticSearch HQ plugin ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN="false"
      else
        BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN=${BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN}
      fi
    else
      yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}install${SETCOLOR_NORMAL} ElasticSearch HQ plugin ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN="true"
      else
        BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN=${BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN}
      fi
    fi
  fi
  echo "BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN='${BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN}'" >> ${installation_cfg_tmpfile}
  if [ -z "${BOOLEAN_ELASTICSEARCH_ONSTARTUP}" ]
  then
    yes_no_function "Do you want to add ELASTICSEARCH index server on startup ?" "yes"
    if [ "${?}" == "0" ]
    then
      BOOLEAN_ELASTICSEARCH_ONSTARTUP="true"
    else
      BOOLEAN_ELASTICSEARCH_ONSTARTUP="false"
    fi
  else
    if [[ "${BOOLEAN_ELASTICSEARCH_ONSTARTUP}" =~ true ]]
    then
      yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}disable${SETCOLOR_NORMAL} ELASTICSEARCH index server on startup ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_ELASTICSEARCH_ONSTARTUP="false"
      else
        BOOLEAN_ELASTICSEARCH_ONSTARTUP=${BOOLEAN_ELASTICSEARCH_ONSTARTUP}
      fi
    else
      yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}enable${SETCOLOR_NORMAL} ELASTICSEARCH index server on startup ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_ELASTICSEARCH_ONSTARTUP="true"
      else
        BOOLEAN_ELASTICSEARCH_ONSTARTUP=${BOOLEAN_ELASTICSEARCH_ONSTARTUP}
      fi
    fi
  fi
  echo "BOOLEAN_ELASTICSEARCH_ONSTARTUP='${BOOLEAN_ELASTICSEARCH_ONSTARTUP}'" >> ${installation_cfg_tmpfile}
  if [ -z "${GRAYLOG_SECRET_PASSWORD}" ]
  then
    while [ -z "${GRAYLOG_SECRET_PASSWORD}" ]
    do
      echo -e "\nType secret password of Graylog application, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}secretpassword${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read GRAYLOG_SECRET_PASSWORD
      if [ -z "${GRAYLOG_SECRET_PASSWORD}" ]
      then
        GRAYLOG_SECRET_PASSWORD='secretpassword'
      fi
    done
  else
    old_input_value=${GRAYLOG_SECRET_PASSWORD}
    yes_no_function "Can you confirm you want to modify current secret password of Graylog application ?" "yes"
    if [ "${?}" == "0" ]
    then
      GRAYLOG_SECRET_PASSWORD=
      while [ -z "${GRAYLOG_SECRET_PASSWORD}" ]
      do
        echo -e "\nType secret password of Graylog application, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read GRAYLOG_SECRET_PASSWORD
        if [ -z "${GRAYLOG_SECRET_PASSWORD}" ]
        then
          GRAYLOG_SECRET_PASSWORD=${old_input_value}
        fi
      done
    else
      GRAYLOG_SECRET_PASSWORD=${old_input_value}
    fi
  fi
  echo "GRAYLOG_SECRET_PASSWORD='${GRAYLOG_SECRET_PASSWORD}'" >> ${installation_cfg_tmpfile}
  if [ -z "${GRAYLOG_ADMIN_USERNAME}" ]
  then
    while [ -z "${GRAYLOG_ADMIN_USERNAME}" ]
    do
      echo -e "\nType login of Graylog administrator, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}admin${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read GRAYLOG_ADMIN_USERNAME
      if [ -z "${GRAYLOG_ADMIN_USERNAME}" ]
      then
        GRAYLOG_ADMIN_USERNAME='admin'
      fi
    done
  else
    old_input_value=${GRAYLOG_ADMIN_USERNAME}
    yes_no_function "Can you confirm you want to modify current login of Graylog administrator ?" "yes"
    if [ "${?}" == "0" ]
    then
      GRAYLOG_ADMIN_USERNAME=
      while [ -z "${GRAYLOG_ADMIN_USERNAME}" ]
      do
        echo -e "\nType login of Graylog administrator, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read GRAYLOG_ADMIN_USERNAME
        if [ -z "${GRAYLOG_ADMIN_USERNAME}" ]
        then
          GRAYLOG_ADMIN_USERNAME=${old_input_value}
        fi
      done
    else
      GRAYLOG_ADMIN_USERNAME=${old_input_value}
    fi
  fi
  echo "GRAYLOG_ADMIN_USERNAME='${GRAYLOG_ADMIN_USERNAME}'" >> ${installation_cfg_tmpfile}
  if [ -z "${GRAYLOG_ADMIN_PASSWORD}" ]
  then
    while [ -z "${GRAYLOG_ADMIN_PASSWORD}" ]
    do
      echo -e "\nType password of Graylog administrator, followed by [ENTER]"
      echo -e "Default to [${SETCOLOR_INFO}adminpassword${SETCOLOR_NORMAL}]:"
      echo -en "> "
      read GRAYLOG_ADMIN_PASSWORD
      if [ -z "${GRAYLOG_ADMIN_PASSWORD}" ]
      then
        GRAYLOG_ADMIN_PASSWORD='adminpassword'
      fi
    done
  else
    old_input_value=${GRAYLOG_ADMIN_PASSWORD}
    yes_no_function "Can you confirm you want to modify current password of Graylog administrator ?" "yes"
    if [ "${?}" == "0" ]
    then
      GRAYLOG_ADMIN_PASSWORD=
      while [ -z "${GRAYLOG_ADMIN_PASSWORD}" ]
      do
        echo -e "\nType password of Graylog administrator, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read GRAYLOG_ADMIN_PASSWORD
        if [ -z "${GRAYLOG_ADMIN_PASSWORD}" ]
        then
          GRAYLOG_ADMIN_PASSWORD=${old_input_value}
        fi
      done
    else
      GRAYLOG_ADMIN_PASSWORD=${old_input_value}
    fi
  fi
  echo "GRAYLOG_ADMIN_PASSWORD='${GRAYLOG_ADMIN_PASSWORD}'" >> ${installation_cfg_tmpfile}
  if [ -z "${BOOLEAN_GRAYLOG_SMTP}" ]
  then
    yes_no_function "Do you want to use Simple Mail Transport Protocol (SMTP) for Graylog application ?" "yes"
    if [ "${?}" == "0" ]
    then
      BOOLEAN_GRAYLOG_SMTP="true"
    else
      BOOLEAN_GRAYLOG_SMTP="false"
    fi
  else
    if [ "${BOOLEAN_GRAYLOG_SMTP}" == "true" ]
    then
      yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}not use${SETCOLOR_NORMAL} SMTP for Graylog application ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_GRAYLOG_SMTP="false"
      else
        BOOLEAN_GRAYLOG_SMTP=${BOOLEAN_GRAYLOG_SMTP}
      fi
    else
      yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}use${SETCOLOR_NORMAL} SMTP for Graylog application ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_GRAYLOG_SMTP="true"
      else
        BOOLEAN_GRAYLOG_SMTP=${BOOLEAN_GRAYLOG_SMTP}
      fi
    fi
  fi
  if [ "${BOOLEAN_GRAYLOG_SMTP}" == "true" ]
  then
    if [ -z "${SMTP_HOST_NAME}" ]
    then
      while [[ ! "${SMTP_HOST_NAME}" =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]] && [[ ! "${SMTP_HOST_NAME}" =~ ^(([a-zA-Z0-9](-?[a-zA-Z0-9])*)\.)*[a-zA-Z0-9](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}$ ]]
      do
        echo -e "\nType FQDN of SMTP server, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_INFO}mail.example.com${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read SMTP_HOST_NAME
        if [ -z "${SMTP_HOST_NAME}" ]
        then
          SMTP_HOST_NAME='mail.example.com'
        fi
      done
    else
      old_input_value=${SMTP_HOST_NAME}
      yes_no_function "Can you confirm you want to modify current FQDN of SMTP server ?" "yes"
      if [ "${?}" == "0" ]
      then
        SMTP_HOST_NAME=
        while [[ ! "${SMTP_HOST_NAME}" =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]] && [[ ! "${SMTP_HOST_NAME}" =~ ^(([a-zA-Z0-9](-?[a-zA-Z0-9])*)\.)*[a-zA-Z0-9](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}$ ]]
        do
          echo -e "\nType FQDN of SMTP server, followed by [ENTER]"
          echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
          echo -en "> "
          read SMTP_HOST_NAME
          if [ -z "${SMTP_HOST_NAME}" ]
          then
            SMTP_HOST_NAME=${old_input_value}
          fi
        done
      else
        SMTP_HOST_NAME=${old_input_value}
      fi
    fi
    if [ -z "${SMTP_DOMAIN_NAME}" ]
    then
      while [[ ! "${SMTP_DOMAIN_NAME}" =~ ^(([a-zA-Z0-9](-?[a-zA-Z0-9])*)\.)*[a-zA-Z0-9](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}$ ]]
      do
        echo -e "\nType SMTP domain name, followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_INFO}example.com${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read SMTP_DOMAIN_NAME
        if [ -z ${SMTP_DOMAIN_NAME} ]
        then
          SMTP_DOMAIN_NAME='example.com'
        fi
      done
    else
      old_input_value=${SMTP_DOMAIN_NAME}
      yes_no_function "Can you confirm you want to modify current SMTP domain name ?" "yes"
      if [ "${?}" == "0" ]
      then
        SMTP_DOMAIN_NAME=
        while [[ ! "${SMTP_DOMAIN_NAME}" =~ ^(([a-zA-Z0-9](-?[a-zA-Z0-9])*)\.)*[a-zA-Z0-9](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}$ ]]
        do
          echo -e "\nType SMTP domain name, followed by [ENTER]"
          echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
          echo -en "> "
          read SMTP_DOMAIN_NAME
          if [ -z "${SMTP_DOMAIN_NAME}" ]
          then
            SMTP_DOMAIN_NAME=${old_input_value}
          fi
        done
      else
        SMTP_DOMAIN_NAME=${old_input_value}
      fi
    fi
    if [ -z "${SMTP_PORT_NUMBER}" ]
    then
      while [[ ! "${SMTP_PORT_NUMBER}" =~ 25|465|587 ]]
      do
        echo -e "\nType SMTP port number (possible values : ${SETCOLOR_FAILURE}25${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}465${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}587${SETCOLOR_NORMAL}), followed by [ENTER]"
        echo -e "Default to [${SETCOLOR_INFO}587${SETCOLOR_NORMAL}]:"
        echo -en "> "
        read SMTP_PORT_NUMBER
        if [ -z "${SMTP_PORT_NUMBER}" ]
        then
          SMTP_PORT_NUMBER='587'
        fi
      done
    else
      old_input_value=${SMTP_PORT_NUMBER}
      yes_no_function "Can you confirm you want to modify current SMTP port number ?" "yes"
      if [ "${?}" == "0" ]
      then
        SMTP_PORT_NUMBER=
        while [[ ! "${SMTP_PORT_NUMBER}" =~ 25|465|587 ]]
        do
          echo -e "\nType SMTP port number (possible values : ${SETCOLOR_FAILURE}25${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}465${SETCOLOR_NORMAL}|${SETCOLOR_FAILURE}587${SETCOLOR_NORMAL}), followed by [ENTER]"
          echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
          echo -en "> "
          read SMTP_PORT_NUMBER
          if [ -z "${SMTP_PORT_NUMBER}" ]
          then
            SMTP_PORT_NUMBER=${old_input_value}
          fi
        done
      else
        SMTP_PORT_NUMBER=${old_input_value}
      fi
    fi
    if [ -z "${BOOLEAN_SMTP_AUTH}" ]
    then
      yes_no_function "Do you want to use authentication for SMTP ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_SMTP_AUTH="true"
      else
        BOOLEAN_SMTP_AUTH="false"
      fi
    else
      if [ "${BOOLEAN_SMTP_AUTH}" == "true" ]
      then
        yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}not use${SETCOLOR_NORMAL} SMTP authentication ?" "yes"
        if [ "${?}" == "0" ]
        then
          BOOLEAN_SMTP_AUTH="false"
        else
          BOOLEAN_SMTP_AUTH=${BOOLEAN_SMTP_AUTH}
        fi
      else
        yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}use${SETCOLOR_NORMAL} SMTP authentication ?" "yes"
        if [ "${?}" == "0" ]
        then
          BOOLEAN_SMTP_AUTH="true"
        else
          BOOLEAN_SMTP_AUTH=${BOOLEAN_SMTP_AUTH}
        fi
      fi
    fi
    if [ "${BOOLEAN_SMTP_AUTH}" == "true" ]
    then
      if [ -z "${BOOLEAN_SMTP_TLS}" ]
      then
        yes_no_function "Do you want to use SMTP over Transport Layer Security (TLS) ?" "yes"
        if [ "${?}" == "0" ]
        then
          BOOLEAN_SMTP_TLS="true"
        else
          BOOLEAN_SMTP_TLS="false"
        fi
      else
        if [ "${BOOLEAN_SMTP_TLS}" == "true" ]
        then
          yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}not use${SETCOLOR_NORMAL} SMTP over TLS ?" "yes"
          if [ "${?}" == "0" ]
          then
            BOOLEAN_SMTP_TLS="false"
          else
            BOOLEAN_SMTP_TLS=${BOOLEAN_SMTP_TLS}
          fi
        else
          yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}use${SETCOLOR_NORMAL} SMTP over TLS ?" "yes"
          if [ "${?}" == "0" ]
          then
            BOOLEAN_SMTP_TLS="true"
          else
            BOOLEAN_SMTP_TLS=${BOOLEAN_SMTP_TLS}
          fi
        fi
      fi
      if [ -z "${BOOLEAN_SMTP_SSL}" ]
      then
        yes_no_function "Do you want to use SMTP over Secure Socket Layer (SSL) ?" "yes"
        if [ "${?}" == "0" ]
        then
          BOOLEAN_SMTP_SSL="true"
        else
          BOOLEAN_SMTP_SSL="false"
        fi
      else
        if [ "${BOOLEAN_SMTP_SSL}" == "true" ]
        then
          yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}not use${SETCOLOR_NORMAL} SMTP over SSL ?" "yes"
          if [ "${?}" == "0" ]
          then
            BOOLEAN_SMTP_SSL="false"
          else
            BOOLEAN_SMTP_SSL=${BOOLEAN_SMTP_SSL}
          fi
        else
          yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}use${SETCOLOR_NORMAL} SMTP over SSL ?" "yes"
          if [ "${?}" == "0" ]
          then
            BOOLEAN_SMTP_SSL="true"
          else
            BOOLEAN_SMTP_SSL=${BOOLEAN_SMTP_SSL}
          fi
        fi
      fi
      if [ -z "${SMTP_AUTH_USERNAME}" ]
      then
        while [ -z "${SMTP_AUTH_USERNAME}" ]
        do
          echo -e "\nType username of SMTP authentication, followed by [ENTER]"
          echo -e "Default to [${SETCOLOR_INFO}you@example.com${SETCOLOR_NORMAL}]:"
          echo -en "> "
          read SMTP_AUTH_USERNAME
          if [ -z "${SMTP_AUTH_USERNAME}" ]
          then
            SMTP_AUTH_USERNAME='you@example.com'
          fi
        done
      else
        old_input_value=${SMTP_AUTH_USERNAME}
        yes_no_function "Can you confirm you want to modify current username of SMTP authentication ?" "yes"
        if [ "${?}" == "0" ]
        then
          SMTP_AUTH_USERNAME=
          while [ -z "${SMTP_AUTH_USERNAME}" ]
          do
            echo -e "\nType username of SMTP authentication, followed by [ENTER]"
            echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
            echo -en "> "
            read SMTP_AUTH_USERNAME
            if [ -z "${SMTP_AUTH_USERNAME}" ]
            then
              SMTP_AUTH_USERNAME=${old_input_value}
            fi
          done
        else
          SMTP_AUTH_USERNAME=${old_input_value}
        fi
      fi
      if [ -z "${SMTP_AUTH_PASSWORD}" ]
      then
        while [ -z ${SMTP_AUTH_PASSWORD} ]
        do
          echo -e "\nType password of SMTP authentication, followed by [ENTER]"
          echo -e "Default to [${SETCOLOR_INFO}secret${SETCOLOR_NORMAL}]:"
          echo -en "> "
          read SMTP_AUTH_PASSWORD
          if [ -z "${SMTP_AUTH_PASSWORD}" ]
          then
            SMTP_AUTH_PASSWORD='secret'
          fi
        done
      else
        old_input_value=${SMTP_AUTH_PASSWORD}
        yes_no_function "Can you confirm you want to modify current password of SMTP authentication ?" "yes"
        if [ "${?}" == "0" ]
        then
          SMTP_AUTH_PASSWORD=
          while [ -z "${SMTP_AUTH_PASSWORD}" ]
          do
            echo -e "\nType password of SMTP authentication, followed by [ENTER]"
            echo -e "Default to [${SETCOLOR_WARNING}${old_input_value}${SETCOLOR_NORMAL}]:"
            echo -en "> "
            read SMTP_AUTH_PASSWORD
            if [ -z ${SMTP_AUTH_PASSWORD} ]
            then
              SMTP_AUTH_PASSWORD=${old_input_value}
            fi
          done
        else
          SMTP_AUTH_PASSWORD=${old_input_value}
        fi
      fi
    else
      BOOLEAN_SMTP_AUTH='false'
      BOOLEAN_SMTP_TLS='false'
      BOOLEAN_SMTP_SSL='false'
      SMTP_AUTH_USERNAME='you@example.com'
      SMTP_AUTH_PASSWORD='secret'
    fi
  else
    BOOLEAN_GRAYLOG_SMTP='false'
    SMTP_HOST_NAME='mail.example.com'
    SMTP_DOMAIN_NAME='example.com'
    SMTP_PORT_NUMBER='587'
    BOOLEAN_SMTP_AUTH='false'
    BOOLEAN_SMTP_TLS='false'
    BOOLEAN_SMTP_SSL='false'
    SMTP_AUTH_USERNAME='you@example.com'
    SMTP_AUTH_PASSWORD='secret'
  fi
  echo "BOOLEAN_GRAYLOG_SMTP='${BOOLEAN_GRAYLOG_SMTP}'" >> ${installation_cfg_tmpfile}
  echo "SMTP_HOST_NAME='${SMTP_HOST_NAME}'" >> ${installation_cfg_tmpfile}
  echo "SMTP_DOMAIN_NAME='${SMTP_DOMAIN_NAME}'" >> ${installation_cfg_tmpfile}
  echo "SMTP_PORT_NUMBER='${SMTP_PORT_NUMBER}'" >> ${installation_cfg_tmpfile}
  echo "BOOLEAN_SMTP_AUTH='${BOOLEAN_SMTP_AUTH}'" >> ${installation_cfg_tmpfile}
  echo "BOOLEAN_SMTP_TLS='${BOOLEAN_SMTP_TLS}'" >> ${installation_cfg_tmpfile}
  echo "BOOLEAN_SMTP_SSL='${BOOLEAN_SMTP_SSL}'" >> ${installation_cfg_tmpfile}
  echo "SMTP_AUTH_USERNAME='${SMTP_AUTH_USERNAME}'" >> ${installation_cfg_tmpfile}
  echo "SMTP_AUTH_PASSWORD='${SMTP_AUTH_PASSWORD}'" >> ${installation_cfg_tmpfile}
  if [ -z "${BOOLEAN_GRAYLOGSERVER_ONSTARTUP}" ]
  then
    yes_no_function "Do you want to add GRAYLOG back-end server on startup ?" "yes"
    if [ "${?}" == "0" ]
    then
      BOOLEAN_GRAYLOGSERVER_ONSTARTUP="true"
    else
      BOOLEAN_GRAYLOGSERVER_ONSTARTUP="false"
    fi
  else
    if [[ "${BOOLEAN_GRAYLOGSERVER_ONSTARTUP}" =~ true ]]
    then
      yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}disable${SETCOLOR_NORMAL} GRAYLOG back-end server on startup ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_GRAYLOGSERVER_ONSTARTUP="false"
      else
        BOOLEAN_GRAYLOGSERVER_ONSTARTUP=${BOOLEAN_GRAYLOGSERVER_ONSTARTUP}
      fi
    else
      yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}enable${SETCOLOR_NORMAL} GRAYLOG back-end server on startup ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_GRAYLOGSERVER_ONSTARTUP="true"
      else
        BOOLEAN_GRAYLOGSERVER_ONSTARTUP=${BOOLEAN_GRAYLOGSERVER_ONSTARTUP}
      fi
    fi
  fi
  echo "BOOLEAN_GRAYLOGSERVER_ONSTARTUP='${BOOLEAN_GRAYLOGSERVER_ONSTARTUP}'" >> ${installation_cfg_tmpfile}
  if [ -z "${BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP}" ]
  then
    yes_no_function "Do you want to add GRAYLOG front-end server on startup ?" "yes"
    if [ "${?}" == "0" ]
    then
      BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP="true"
    else
      BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP="false"
    fi
  else
    if [[ "${BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP}" =~ true ]]
    then
      yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}disable${SETCOLOR_NORMAL} GRAYLOG front-end server on startup ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP="false"
      else
        BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP=${BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP}
      fi
    else
      yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}enable${SETCOLOR_NORMAL} GRAYLOG front-end server on startup ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP="true"
      else
        BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP=${BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP}
      fi
    fi
  fi
  echo "BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP='${BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP}'" >> ${installation_cfg_tmpfile}
  if [ -z "${BOOLEAN_NGINX_ONSTARTUP}" ]
  then
    yes_no_function "Do you want to add Nginx web server on startup ?" "yes"
    if [ "${?}" == "0" ]
    then
      BOOLEAN_NGINX_ONSTARTUP="true"
    else
      BOOLEAN_NGINX_ONSTARTUP="false"
    fi
  else
    if [[ "${BOOLEAN_NGINX_ONSTARTUP}" =~ true ]]
    then
      yes_no_function "Can you confirm you want to ${SETCOLOR_FAILURE}disable${SETCOLOR_NORMAL} Nginx web server on startup ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_NGINX_ONSTARTUP="false"
      else
        BOOLEAN_NGINX_ONSTARTUP=${BOOLEAN_NGINX_ONSTARTUP}
      fi
    else
      yes_no_function "Can you confirm you want to ${SETCOLOR_SUCCESS}enable${SETCOLOR_NORMAL} Nginx web server on startup ?" "yes"
      if [ "${?}" == "0" ]
      then
        BOOLEAN_NGINX_ONSTARTUP="true"
      else
        BOOLEAN_NGINX_ONSTARTUP=${BOOLEAN_NGINX_ONSTARTUP}
      fi
    fi
  fi
  echo "BOOLEAN_NGINX_ONSTARTUP='${BOOLEAN_NGINX_ONSTARTUP}'" >> ${installation_cfg_tmpfile}
  INSTALLATION_CFG_FILE=${installation_cfg_tmpfile}
  verify_globalvariables
}
# Verify all global variables
function verify_globalvariables() {
  local error_counter=0
  local mailaddress_regular_expression="^[a-z0-9,!#\$%&'\*\+/=\?\^_\`\{\|}~-]+(\.[a-z0-9,!#\$%&'\*\+/=\?\^_\`\{\|}~-]+)*@[a-z0-9-]+(\.[a-z0-9-]+)*\.([a-z]{2,})$"
  echo -e "\n###################################################################"
  echo -e "#${MOVE_TO_COL1}#\n# ${SETCOLOR_WARNING}Check your settings before continue${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "#${MOVE_TO_COL1}#"
  if [ ! -z "${NETWORK_INTERFACE_NAME}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}NETWORK_INTERFACE_NAME${SETCOLOR_NORMAL}..............'${NETWORK_INTERFACE_NAME}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: NETWORK_INTERFACE_NAME not successfully definied by user (value=${NETWORK_INTERFACE_NAME})"
    echo -e "# ${SETCOLOR_FAILURE}NETWORK_INTERFACE_NAME${SETCOLOR_NORMAL}..............'${NETWORK_INTERFACE_NAME}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_RSA_AUTH}" =~ true|false ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_RSA_AUTH${SETCOLOR_NORMAL}....................'${BOOLEAN_RSA_AUTH}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: BOOLEAN_RSA_AUTH not successfully definied by user (value=${BOOLEAN_RSA_AUTH})"
    echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_RSA_AUTH${SETCOLOR_NORMAL}....................'${BOOLEAN_RSA_AUTH}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_RSA_AUTH}" =~ true ]]
  then
    if [[ "${RSA_PUBLIC_KEY}" =~ ^ssh-rsa.* ]]
    then
      echo -e "# ${SETCOLOR_SUCCESS}RSA_PUBLIC_KEY${SETCOLOR_NORMAL}......................'${RSA_PUBLIC_KEY}'${MOVE_TO_COL1}#"
    else
      ((error_counter++))
      log "ERROR" "Global variables: RSA_PUBLIC_KEY not successfully definied by user (value=${RSA_PUBLIC_KEY})"
      echo -e "# ${SETCOLOR_FAILURE}RSA_PUBLIC_KEY${SETCOLOR_NORMAL}......................'${RSA_PUBLIC_KEY}'${MOVE_TO_COL1}#"
    fi
  else
    echo -e "# ${SETCOLOR_DISABLE}RSA_PUBLIC_KEY${SETCOLOR_NORMAL}......................'${RSA_PUBLIC_KEY}'${MOVE_TO_COL1}#"
  fi
  if [ ! -z "${SERVER_TIME_ZONE}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}SERVER_TIME_ZONE${SETCOLOR_NORMAL}....................'${SERVER_TIME_ZONE}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: SERVER_TIME_ZONE not successfully definied by user (value=${SERVER_TIME_ZONE})"
    echo -e "# ${SETCOLOR_FAILURE}SERVER_TIME_ZONE${SETCOLOR_NORMAL}....................'${SERVER_TIME_ZONE}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_NTP_CONFIGURE}" =~ true|false ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_NTP_CONFIGURE${SETCOLOR_NORMAL}...............'${BOOLEAN_NTP_CONFIGURE}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: BOOLEAN_NTP_CONFIGURE not successfully definied by user (value=${BOOLEAN_NTP_CONFIGURE})"
    echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_NTP_CONFIGURE${SETCOLOR_NORMAL}...............'${BOOLEAN_NTP_CONFIGURE}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_NTP_CONFIGURE}" =~ true ]]
  then
    if [[ "${NEW_NTP_ADDRESS}" =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]] || [[ "${NEW_NTP_ADDRESS}" =~ ^(([a-zA-Z0-9](-?[a-zA-Z0-9])*)\.)*[a-zA-Z0-9](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}$ ]]
    then
      echo -e "# ${SETCOLOR_SUCCESS}NEW_NTP_ADDRESS${SETCOLOR_NORMAL}.....................'${NEW_NTP_ADDRESS}'${MOVE_TO_COL1}#"
    else
      ((error_counter++))
      log "ERROR" "Global variables: NEW_NTP_ADDRESS not successfully definied by user (value=${NEW_NTP_ADDRESS})"
      echo -e "# ${SETCOLOR_FAILURE}NEW_NTP_ADDRESS${SETCOLOR_NORMAL}.....................'${NEW_NTP_ADDRESS}'${MOVE_TO_COL1}#"
    fi
  else
    echo -e "# ${SETCOLOR_DISABLE}NEW_NTP_ADDRESS${SETCOLOR_NORMAL}.....................'${NEW_NTP_ADDRESS}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_NTP_ONSTARTUP}" =~ true|false ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_NTP_ONSTARTUP${SETCOLOR_NORMAL}...............'${BOOLEAN_NTP_ONSTARTUP}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: BOOLEAN_NTP_ONSTARTUP not successfully definied by user (value=${BOOLEAN_NTP_ONSTARTUP})"
    echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_NTP_ONSTARTUP${SETCOLOR_NORMAL}...............'${BOOLEAN_NTP_ONSTARTUP}'${MOVE_TO_COL1}#"
  fi
  if [ ! -z "${MONGO_ADMIN_PASSWORD}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}MONGO_ADMIN_PASSWORD${SETCOLOR_NORMAL}................'${MONGO_ADMIN_PASSWORD}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: MONGO_ADMIN_PASSWORD not successfully definied by user (value=${MONGO_ADMIN_PASSWORD})"
    echo -e "# ${SETCOLOR_FAILURE}MONGO_ADMIN_PASSWORD${SETCOLOR_NORMAL}................'${MONGO_ADMIN_PASSWORD}'${MOVE_TO_COL1}#"
  fi
  if [ ! -z "${MONGO_GRAYLOG_DATABASE}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}MONGO_GRAYLOG_DATABASE${SETCOLOR_NORMAL}..............'${MONGO_GRAYLOG_DATABASE}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: MONGO_GRAYLOG_DATABASE not successfully definied by user (value=${MONGO_GRAYLOG_DATABASE})"
    echo -e "# ${SETCOLOR_FAILURE}MONGO_GRAYLOG_DATABASE${SETCOLOR_NORMAL}..............'${MONGO_GRAYLOG_DATABASE}'${MOVE_TO_COL1}#"
  fi
  if [ ! -z "${MONGO_GRAYLOG_USER}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}MONGO_GRAYLOG_USER${SETCOLOR_NORMAL}..................'${MONGO_GRAYLOG_USER}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: MONGO_GRAYLOG_USER not successfully definied by user (value=${MONGO_GRAYLOG_USER})"
    echo -e "# ${SETCOLOR_FAILURE}MONGO_GRAYLOG_USER${SETCOLOR_NORMAL}..................'${MONGO_GRAYLOG_USER}'${MOVE_TO_COL1}#"
  fi
  if [ ! -z "${MONGO_GRAYLOG_PASSWORD}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}MONGO_GRAYLOG_PASSWORD${SETCOLOR_NORMAL}..............'${MONGO_GRAYLOG_PASSWORD}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: MONGO_GRAYLOG_PASSWORD not successfully definied by user (value=${MONGO_GRAYLOG_PASSWORD})"
    echo -e "# ${SETCOLOR_FAILURE}MONGO_GRAYLOG_PASSWORD${SETCOLOR_NORMAL}..............'${MONGO_GRAYLOG_PASSWORD}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_MONGO_ONSTARTUP}" =~ true|false ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_MONGO_ONSTARTUP${SETCOLOR_NORMAL}.............'${BOOLEAN_MONGO_ONSTARTUP}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: BOOLEAN_MONGO_ONSTARTUP not successfully definied by user (value=${BOOLEAN_MONGO_ONSTARTUP})"
    echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_MONGO_ONSTARTUP${SETCOLOR_NORMAL}.............'${BOOLEAN_MONGO_ONSTARTUP}'${MOVE_TO_COL1}#"
  fi
  if [[ "${SSL_KEY_SIZE}" =~ 512|1024|2048|4096 ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}SSL_KEY_SIZE${SETCOLOR_NORMAL}........................'${SSL_KEY_SIZE}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: SSL_KEY_SIZE not successfully definied by user (value=${SSL_KEY_SIZE})"
    echo -e "# ${SETCOLOR_FAILURE}SSL_KEY_SIZE${SETCOLOR_NORMAL}........................'${SSL_KEY_SIZE}'${MOVE_TO_COL1}#"
  fi
  if [[ "${SSL_KEY_DURATION}" =~ [0-9]{1,5} ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}SSL_KEY_DURATION${SETCOLOR_NORMAL}....................'${SSL_KEY_DURATION}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: SSL_KEY_DURATION not successfully definied by user (value=${SSL_KEY_DURATION})"
    echo -e "# ${SETCOLOR_FAILURE}SSL_KEY_DURATION${SETCOLOR_NORMAL}....................'${SSL_KEY_DURATION}'${MOVE_TO_COL1}#"
  fi
  if [[ "${SSL_SUBJECT_COUNTRY}" =~ [A-Z]{2,3} ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}SSL_SUBJECT_COUNTRY${SETCOLOR_NORMAL}.................'${SSL_SUBJECT_COUNTRY}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: SSL_SUBJECT_COUNTRY not successfully definied by user (value=${SSL_SUBJECT_COUNTRY})"
    echo -e "# ${SETCOLOR_FAILURE}SSL_SUBJECT_COUNTRY${SETCOLOR_NORMAL}.................'${SSL_SUBJECT_COUNTRY}'${MOVE_TO_COL1}#"
  fi
  if [ ! -z "${SSL_SUBJECT_STATE}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}SSL_SUBJECT_STATE${SETCOLOR_NORMAL}...................'${SSL_SUBJECT_STATE}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: SSL_SUBJECT_STATE not successfully definied by user (value=${SSL_SUBJECT_STATE})"
    echo -e "# ${SETCOLOR_FAILURE}SSL_SUBJECT_STATE${SETCOLOR_NORMAL}...................'${SSL_SUBJECT_STATE}'${MOVE_TO_COL1}#"
  fi
  if [ ! -z "${SSL_SUBJECT_LOCALITY}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}SSL_SUBJECT_LOCALITY${SETCOLOR_NORMAL}................'${SSL_SUBJECT_LOCALITY}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: SSL_SUBJECT_LOCALITY not successfully definied by user (value=${SSL_SUBJECT_LOCALITY})"
    echo -e "# ${SETCOLOR_FAILURE}SSL_SUBJECT_LOCALITY${SETCOLOR_NORMAL}................'${SSL_SUBJECT_LOCALITY}'${MOVE_TO_COL1}#"
  fi
  if [ ! -z "${SSL_SUBJECT_ORGANIZATION}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}SSL_SUBJECT_ORGANIZATION${SETCOLOR_NORMAL}............'${SSL_SUBJECT_ORGANIZATION}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: SSL_SUBJECT_ORGANIZATION not successfully definied by user (value=${SSL_SUBJECT_ORGANIZATION})"
    echo -e "# ${SETCOLOR_FAILURE}SSL_SUBJECT_ORGANIZATION${SETCOLOR_NORMAL}............'${SSL_SUBJECT_ORGANIZATION}'${MOVE_TO_COL1}#"
  fi
  if [ ! -z "${SSL_SUBJECT_ORGANIZATIONUNIT}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}SSL_SUBJECT_ORGANIZATIONUNIT${SETCOLOR_NORMAL}........'${SSL_SUBJECT_ORGANIZATIONUNIT}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: SSL_SUBJECT_ORGANIZATIONUNIT not successfully definied by user (value=${SSL_SUBJECT_ORGANIZATIONUNIT})"
    echo -e "# ${SETCOLOR_FAILURE}SSL_SUBJECT_ORGANIZATIONUNIT${SETCOLOR_NORMAL}........'${SSL_SUBJECT_ORGANIZATIONUNIT}'${MOVE_TO_COL1}#"
  fi
  if [[ "${SSL_SUBJECT_EMAIL}" =~ ${mailaddress_regular_expression} ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}SSL_SUBJECT_EMAIL${SETCOLOR_NORMAL}...................'${SSL_SUBJECT_EMAIL}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: SSL_SUBJECT_EMAIL not successfully definied by user (value=${SSL_SUBJECT_EMAIL})"
    echo -e "# ${SETCOLOR_FAILURE}SSL_SUBJECT_EMAIL${SETCOLOR_NORMAL}...................'${SSL_SUBJECT_EMAIL}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN}" =~ true|false ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN${SETCOLOR_NORMAL}.'${BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN not successfully definied by user (value=${BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN})"
    echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN${SETCOLOR_NORMAL}.'${BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_ELASTICSEARCH_ONSTARTUP}" =~ true|false ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_ELASTICSEARCH_ONSTARTUP${SETCOLOR_NORMAL}.....'${BOOLEAN_ELASTICSEARCH_ONSTARTUP}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: BOOLEAN_ELASTICSEARCH_ONSTARTUP not successfully definied by user (value=${BOOLEAN_ELASTICSEARCH_ONSTARTUP})"
    echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_ELASTICSEARCH_ONSTARTUP${SETCOLOR_NORMAL}.....'${BOOLEAN_ELASTICSEARCH_ONSTARTUP}'${MOVE_TO_COL1}#"
  fi
  if [ ! -z "${GRAYLOG_SECRET_PASSWORD}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}GRAYLOG_SECRET_PASSWORD${SETCOLOR_NORMAL}.............'${GRAYLOG_SECRET_PASSWORD}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: GRAYLOG_SECRET_PASSWORD not successfully definied by user (value=${GRAYLOG_SECRET_PASSWORD})"
    echo -e "# ${SETCOLOR_FAILURE}GRAYLOG_SECRET_PASSWORD${SETCOLOR_NORMAL}.............'${GRAYLOG_SECRET_PASSWORD}'${MOVE_TO_COL1}#"
  fi
  if [ ! -z "${GRAYLOG_ADMIN_USERNAME}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}GRAYLOG_ADMIN_USERNAME${SETCOLOR_NORMAL}..............'${GRAYLOG_ADMIN_USERNAME}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: GRAYLOG_ADMIN_USERNAME not successfully definied by user (value=${GRAYLOG_ADMIN_USERNAME})"
    echo -e "# ${SETCOLOR_FAILURE}GRAYLOG_ADMIN_USERNAME${SETCOLOR_NORMAL}..............'${GRAYLOG_ADMIN_USERNAME}'${MOVE_TO_COL1}#"
  fi
  if [ ! -z "${GRAYLOG_ADMIN_PASSWORD}" ]
  then
    echo -e "# ${SETCOLOR_SUCCESS}GRAYLOG_ADMIN_PASSWORD${SETCOLOR_NORMAL}..............'${GRAYLOG_ADMIN_PASSWORD}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: GRAYLOG_ADMIN_PASSWORD not successfully definied by user (value=${GRAYLOG_ADMIN_PASSWORD})"
    echo -e "# ${SETCOLOR_FAILURE}GRAYLOG_ADMIN_PASSWORD${SETCOLOR_NORMAL}..............'${GRAYLOG_ADMIN_PASSWORD}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_GRAYLOGSERVER_ONSTARTUP}" =~ true|false ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_GRAYLOGSERVER_ONSTARTUP${SETCOLOR_NORMAL}.....'${BOOLEAN_GRAYLOGSERVER_ONSTARTUP}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: BOOLEAN_GRAYLOGSERVER_ONSTARTUP not successfully definied by user (value=${BOOLEAN_GRAYLOGSERVER_ONSTARTUP})"
    echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_GRAYLOGSERVER_ONSTARTUP${SETCOLOR_NORMAL}.....'${BOOLEAN_GRAYLOGSERVER_ONSTARTUP}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP}" =~ true|false ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP${SETCOLOR_NORMAL}.....'${BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP not successfully definied by user (value=${BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP})"
    echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP${SETCOLOR_NORMAL}.....'${BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_GRAYLOG_SMTP}" =~ true|false ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_GRAYLOG_SMTP${SETCOLOR_NORMAL}................'${BOOLEAN_GRAYLOG_SMTP}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: BOOLEAN_GRAYLOG_SMTP not successfully definied by user (value=${BOOLEAN_GRAYLOG_SMTP})"
    echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_GRAYLOG_SMTP${SETCOLOR_NORMAL}................'${BOOLEAN_GRAYLOG_SMTP}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_GRAYLOG_SMTP}" =~ true ]]
  then
    if [[ "${SMTP_HOST_NAME}" =~ ^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]] || [[ "${SMTP_HOST_NAME}" =~ ^(([a-zA-Z0-9](-?[a-zA-Z0-9])*)\.)*[a-zA-Z0-9](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}$ ]]
    then
      echo -e "# ${SETCOLOR_SUCCESS}SMTP_HOST_NAME${SETCOLOR_NORMAL}......................'${SMTP_HOST_NAME}'${MOVE_TO_COL1}#"
    else
      ((error_counter++))
      log "ERROR" "Global variables: SMTP_HOST_NAME not successfully definied by user (value=${SMTP_HOST_NAME})"
      echo -e "# ${SETCOLOR_FAILURE}SMTP_HOST_NAME${SETCOLOR_NORMAL}......................'${SMTP_HOST_NAME}'${MOVE_TO_COL1}#"
    fi
  else
    echo -e "# ${SETCOLOR_DISABLE}SMTP_HOST_NAME${SETCOLOR_NORMAL}......................'${SMTP_HOST_NAME}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_GRAYLOG_SMTP}" =~ true ]]
  then
    if [[ "${SMTP_DOMAIN_NAME}" =~ ^(([a-zA-Z0-9](-?[a-zA-Z0-9])*)\.)*[a-zA-Z0-9](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}$ ]]
    then
      echo -e "# ${SETCOLOR_SUCCESS}SMTP_DOMAIN_NAME${SETCOLOR_NORMAL}....................'${SMTP_DOMAIN_NAME}'${MOVE_TO_COL1}#"
    else
      ((error_counter++))
      log "ERROR" "Global variables: SMTP_DOMAIN_NAME not successfully definied by user (value=${SMTP_DOMAIN_NAME})"
      echo -e "# ${SETCOLOR_FAILURE}SMTP_DOMAIN_NAME${SETCOLOR_NORMAL}....................'${SMTP_DOMAIN_NAME}'${MOVE_TO_COL1}#"
    fi
  else
    echo -e "# ${SETCOLOR_DISABLE}SMTP_DOMAIN_NAME${SETCOLOR_NORMAL}....................'${SMTP_DOMAIN_NAME}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_GRAYLOG_SMTP}" =~ true ]]
  then
    if [[ "${SMTP_PORT_NUMBER}" =~ 25|465|587 ]]
    then
      echo -e "# ${SETCOLOR_SUCCESS}SMTP_PORT_NUMBER${SETCOLOR_NORMAL}....................'${SMTP_PORT_NUMBER}'${MOVE_TO_COL1}#"
    else
      ((error_counter++))
      log "ERROR" "Global variables: SMTP_PORT_NUMBER not successfully definied by user (value=${SMTP_PORT_NUMBER})"
      echo -e "# ${SETCOLOR_FAILURE}SMTP_PORT_NUMBER${SETCOLOR_NORMAL}....................'${SMTP_PORT_NUMBER}'${MOVE_TO_COL1}#"
    fi
  else
    echo -e "# ${SETCOLOR_DISABLE}SMTP_PORT_NUMBER${SETCOLOR_NORMAL}....................'${SMTP_PORT_NUMBER}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_GRAYLOG_SMTP}" =~ true ]]
  then
    if [[ "${BOOLEAN_SMTP_AUTH}" =~ true|false ]]
    then
      echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_SMTP_AUTH${SETCOLOR_NORMAL}...................'${BOOLEAN_SMTP_AUTH}'${MOVE_TO_COL1}#"
    else
      ((error_counter++))
      log "ERROR" "Global variables: BOOLEAN_SMTP_AUTH not successfully definied by user (value=${BOOLEAN_SMTP_AUTH})"
      echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_SMTP_AUTH${SETCOLOR_NORMAL}...................'${BOOLEAN_SMTP_AUTH}'${MOVE_TO_COL1}#"
    fi
  else
    echo -e "# ${SETCOLOR_DISABLE}BOOLEAN_SMTP_AUTH${SETCOLOR_NORMAL}...................'${BOOLEAN_SMTP_AUTH}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_GRAYLOG_SMTP}" =~ true ]]
  then
    if [[ "${BOOLEAN_SMTP_TLS}" =~ true|false ]]
    then
      echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_SMTP_TLS${SETCOLOR_NORMAL}....................'${BOOLEAN_SMTP_TLS}'${MOVE_TO_COL1}#"
    else
      ((error_counter++))
      log "ERROR" "Global variables: BOOLEAN_SMTP_TLS not successfully definied by user (value=${BOOLEAN_SMTP_TLS})"
      echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_SMTP_TLS${SETCOLOR_NORMAL}....................'${BOOLEAN_SMTP_TLS}'${MOVE_TO_COL1}#"
    fi
  else
    echo -e "# ${SETCOLOR_DISABLE}BOOLEAN_SMTP_TLS${SETCOLOR_NORMAL}....................'${BOOLEAN_SMTP_TLS}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_GRAYLOG_SMTP}" =~ true ]]
  then
    if [[ "${BOOLEAN_SMTP_SSL}" =~ true|false ]]
    then
      echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_SMTP_SSL${SETCOLOR_NORMAL}....................'${BOOLEAN_SMTP_SSL}'${MOVE_TO_COL1}#"
    else
      ((error_counter++))
      log "ERROR" "Global variables: BOOLEAN_SMTP_SSL not successfully definied by user (value=${BOOLEAN_SMTP_SSL})"
      echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_SMTP_SSL${SETCOLOR_NORMAL}....................'${BOOLEAN_SMTP_SSL}'${MOVE_TO_COL1}#"
    fi
  else
    echo -e "# ${SETCOLOR_DISABLE}BOOLEAN_SMTP_SSL${SETCOLOR_NORMAL}....................'${BOOLEAN_SMTP_SSL}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_SMTP_AUTH}" =~ true ]]
  then
    if [ ! -z "${SMTP_AUTH_USERNAME}" ]
    then
      echo -e "# ${SETCOLOR_SUCCESS}SMTP_AUTH_USERNAME${SETCOLOR_NORMAL}..................'${SMTP_AUTH_USERNAME}'${MOVE_TO_COL1}#"
    else
      ((error_counter++))
      log "ERROR" "Global variables: SMTP_AUTH_USERNAME not successfully definied by user (value=${SMTP_AUTH_USERNAME})"
      echo -e "# ${SETCOLOR_FAILURE}SMTP_AUTH_USERNAME${SETCOLOR_NORMAL}..................'${SMTP_AUTH_USERNAME}'${MOVE_TO_COL1}#"
    fi
  else
    echo -e "# ${SETCOLOR_DISABLE}SMTP_AUTH_USERNAME${SETCOLOR_NORMAL}..................'${SMTP_AUTH_USERNAME}'${MOVE_TO_COL1}#"
  fi
  if [[ "${BOOLEAN_SMTP_AUTH}" =~ true ]]
  then
    if [ ! -z "${SMTP_AUTH_PASSWORD}" ]
    then
      echo -e "# ${SETCOLOR_SUCCESS}SMTP_AUTH_PASSWORD${SETCOLOR_NORMAL}..................'${SMTP_AUTH_PASSWORD}'${MOVE_TO_COL1}#"
    else
      ((error_counter++))
      log "ERROR" "Global variables: SMTP_AUTH_USERNAME not successfully definied by user (value=${SMTP_AUTH_USERNAME})"
      echo -e "# ${SETCOLOR_FAILURE}SMTP_AUTH_PASSWORD${SETCOLOR_NORMAL}..................'${SMTP_AUTH_PASSWORD}'${MOVE_TO_COL1}#"
    fi
  else
    echo -e "# ${SETCOLOR_DISABLE}SMTP_AUTH_PASSWORD${SETCOLOR_NORMAL}..................'${SMTP_AUTH_PASSWORD}'${MOVE_TO_COL1}#"
  fi
  
  if [[ "${BOOLEAN_NGINX_ONSTARTUP}" =~ true|false ]]
  then
    echo -e "# ${SETCOLOR_SUCCESS}BOOLEAN_NGINX_ONSTARTUP${SETCOLOR_NORMAL}.............'${BOOLEAN_NGINX_ONSTARTUP}'${MOVE_TO_COL1}#"
  else
    ((error_counter++))
    log "ERROR" "Global variables: BOOLEAN_NGINX_ONSTARTUP not successfully definied by user (value=${BOOLEAN_NGINX_ONSTARTUP})"
    echo -e "# ${SETCOLOR_FAILURE}BOOLEAN_NGINX_ONSTARTUP${SETCOLOR_NORMAL}.............'${BOOLEAN_NGINX_ONSTARTUP}'${MOVE_TO_COL1}#"
  fi
  echo -e "#${MOVE_TO_COL1}#"
  echo -e "###################################################################"
  if [[ ${SCRIPT_MODE} =~ i|a ]]
  then
    if [ "${error_counter}" == "0" ]
    then
      log "INFO" "Global variables: Successfully definied by user"
      yes_no_function "All variables seem to be good.\nDo you want to continue installation process ?" "yes"
      if [ "${?}" == "0" ]
      then
        log "INFO" "Global variables: Confirmed by user"
        log "INFO" "Global variables: NETWORK_INTERFACE_NAME successfully definied by user (value=${NETWORK_INTERFACE_NAME})"
        log "INFO" "Global variables: SERVER_TIME_ZONE successfully definied by user (value=${SERVER_TIME_ZONE})"
        log "INFO" "Global variables: BOOLEAN_NTP_ONSTARTUP successfully definied by user (value=${BOOLEAN_NTP_ONSTARTUP})"
        log "INFO" "Global variables: BOOLEAN_NTP_CONFIGURE successfully definied by user (value=${BOOLEAN_NTP_CONFIGURE})"
        log "INFO" "Global variables: NEW_NTP_ADDRESS successfully definied by user (value=${NEW_NTP_ADDRESS})"
        log "INFO" "Global variables: BOOLEAN_RSA_AUTH successfully definied by user (value=${BOOLEAN_RSA_AUTH})"
        log "INFO" "Global variables: RSA_PUBLIC_KEY successfully definied by user (value=${RSA_PUBLIC_KEY})"
        log "INFO" "Global variables: MONGO_ADMIN_PASSWORD successfully definied by user (value=${MONGO_ADMIN_PASSWORD})"
        log "INFO" "Global variables: MONGO_GRAYLOG_DATABASE successfully definied by user (value=${MONGO_GRAYLOG_DATABASE})"
        log "INFO" "Global variables: MONGO_GRAYLOG_USER successfully definied by user (value=${MONGO_GRAYLOG_USER})"
        log "INFO" "Global variables: MONGO_GRAYLOG_PASSWORD successfully definied by user (value=${MONGO_GRAYLOG_PASSWORD})"
        log "INFO" "Global variables: BOOLEAN_MONGO_ONSTARTUP successfully definied by user (value=${BOOLEAN_MONGO_ONSTARTUP})"
        log "INFO" "Global variables: SSL_KEY_SIZE successfully definied by user (value=${SSL_KEY_SIZE})"
        log "INFO" "Global variables: SSL_KEY_DURATION successfully definied by user (value=${SSL_KEY_DURATION})"
        log "INFO" "Global variables: SSL_SUBJECT_COUNTRY successfully definied by user (value=${SSL_SUBJECT_COUNTRY})"
        log "INFO" "Global variables: SSL_SUBJECT_STATE successfully definied by user (value=${SSL_SUBJECT_STATE})"
        log "INFO" "Global variables: SSL_SUBJECT_LOCALITY successfully definied by user (value=${SSL_SUBJECT_LOCALITY})"
        log "INFO" "Global variables: SSL_SUBJECT_ORGANIZATION successfully definied by user (value=${SSL_SUBJECT_ORGANIZATION})"
        log "INFO" "Global variables: SSL_SUBJECT_ORGANIZATIONUNIT successfully definied by user (value=${SSL_SUBJECT_ORGANIZATIONUNIT})"
        log "INFO" "Global variables: SSL_SUBJECT_EMAIL successfully definied by user (value=${SSL_SUBJECT_EMAIL})"
        log "INFO" "Global variables: BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN successfully definied by user (value=${BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN})"
        log "INFO" "Global variables: BOOLEAN_ELASTICSEARCH_ONSTARTUP successfully definied by user (value=${BOOLEAN_ELASTICSEARCH_ONSTARTUP})"
        log "INFO" "Global variables: GRAYLOG_SECRET_PASSWORD successfully definied by user (value=${GRAYLOG_SECRET_PASSWORD})"
        log "INFO" "Global variables: GRAYLOG_ADMIN_USERNAME successfully definied by user (value=${GRAYLOG_ADMIN_USERNAME})"
        log "INFO" "Global variables: GRAYLOG_ADMIN_PASSWORD successfully definied by user (value=${GRAYLOG_ADMIN_PASSWORD})"
        log "INFO" "Global variables: BOOLEAN_GRAYLOG_SMTP successfully definied by user (value=${BOOLEAN_GRAYLOG_SMTP})"
        log "INFO" "Global variables: SMTP_HOST_NAME successfully definied by user (value=${SMTP_HOST_NAME})"
        log "INFO" "Global variables: SMTP_DOMAIN_NAME successfully definied by user (value=${SMTP_DOMAIN_NAME})"
        log "INFO" "Global variables: SMTP_PORT_NUMBER successfully definied by user (value=${SMTP_PORT_NUMBER})"
        log "INFO" "Global variables: BOOLEAN_SMTP_AUTH successfully definied by user (value=${BOOLEAN_SMTP_AUTH})"
        log "INFO" "Global variables: BOOLEAN_SMTP_TLS successfully definied by user (value=${BOOLEAN_SMTP_TLS})"
        log "INFO" "Global variables: BOOLEAN_SMTP_SSL successfully definied by user (value=${BOOLEAN_SMTP_SSL})"
        log "INFO" "Global variables: SMTP_AUTH_USERNAME successfully definied by user (value=${SMTP_AUTH_USERNAME})"
        log "INFO" "Global variables: SMTP_AUTH_PASSWORD successfully definied by user (value=${SMTP_AUTH_PASSWORD})"
        log "INFO" "Global variables: BOOLEAN_GRAYLOGSERVER_ONSTARTUP successfully definied by user (value=${BOOLEAN_GRAYLOGSERVER_ONSTARTUP})"
        log "INFO" "Global variables: BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP successfully definied by user (value=${BOOLEAN_GRAYLOGWEBGUI_ONSTARTUP})"
        log "INFO" "Global variables: BOOLEAN_NGINX_ONSTARTUP successfully definied by user (value=${BOOLEAN_NGINX_ONSTARTUP})"
      else
        log "WARN" "Global variables: Not confirmed by user"
        yes_no_function "Do you want to define them again ?" "yes"
        if [ "${?}" == "0" ]
        then
          set_globalvariables
        else
          log "WARN" "GRAYLOG installation: Ended by user"
          exit 0
        fi
      fi
    else
      yes_no_function "One or more variables do not seem to be good.\nDo you want to correct them ?" "yes"
      if [ "${?}" == "0" ]
      then
        set_globalvariables
      else
        log "WARN" "GRAYLOG installation: Ended by user"
        exit 0
      fi
    fi
  else
    echo_message "Check log file : ${INSTALLATION_LOG_FILE}"
    echo_info "INFO"
  fi
}
# Get system informations like OS name, OS version, etc...
function get_sysinfo() {
  local error_counter=0
  local command_output_message=
  local centos_release_file="/etc/centos-release"
  local os_major_version=
  local os_minor_version=
  echo_message "Check all system informations"
  SERVER_IP_ADDRESS=$(ifconfig ${NETWORK_INTERFACE_NAME} 2>> ${INSTALLATION_LOG_FILE} | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}')
  if [ ! -z "${SERVER_IP_ADDRESS}" ]
  then
    log "INFO" "System informations: IP address=${SERVER_IP_ADDRESS}"
  else
    ((error_counter++))
    log "ERROR" "System informations: IP address=${SERVER_IP_ADDRESS}"
  fi
  SERVER_HOST_NAME=$(hostname)
  if [ ! -z "${SERVER_HOST_NAME}" ]
  then
    log "INFO" "System informations: FQDN=${SERVER_HOST_NAME}"
  else
    ((error_counter++))
    log "ERROR" "System informations: FQDN=${SERVER_HOST_NAME}"
  fi
  SERVER_SHORT_NAME=$(hostname -s)
  if [ ! -z "${SERVER_SHORT_NAME}" ]
  then
    log "INFO" "System informations: Short name=${SERVER_SHORT_NAME}"
  else
    ((error_counter++))
    log "ERROR" "System informations: Short name=${SERVER_SHORT_NAME}"
  fi
  SERVER_PROCESSOR_TYPE=$(uname -p)
  if [ "${SERVER_PROCESSOR_TYPE}" == "x86_64" ]
  then
    log "INFO" "System informations: Processor type=${SERVER_PROCESSOR_TYPE}"
  else
    ((error_counter++))
    log "ERROR" "System informations: Processor type=${SERVER_PROCESSOR_TYPE}"
  fi
  command_output_message=$(test_file ${centos_release_file})
  if [ "${command_output_message}" == "0" ]
  then
    log "INFO" "System informations: OS name=CentOS"
    os_major_version=`sed -rn 's/.*\s.*\s.*([0-9])\.[0-9].*/\1/p' ${centos_release_file}`
    os_minor_version=`sed -rn 's/.*\s.*\s.*[0-9]\.([0-9]).*/\1/p' ${centos_release_file}`
    if [ "${os_major_version}" == "6" ] && [[ "${os_minor_version}" =~ [5-6] ]]
    then
      log "INFO" "System informations: OS major version=${os_major_version}"
      log "INFO" "System informations: OS minor version=${os_minor_version}"
    elif [ "${os_major_version}" != "6" ] && [[ "${os_minor_version}" =~ [5-6] ]]
    then
      ((error_counter++))
      log "ERROR" "System informations: OS major version=${os_major_version}"
    elif [ "${os_major_version}" == "6" ] && [[ ! "${os_minor_version}" =~ [5-6] ]]
    then
      ((error_counter++))
      log "ERROR" "System informations: OS minor version=${os_minor_version}"
    else
      ((error_counter++))
      log "ERROR" "System informations: OS major version=${os_major_version}"
      log "ERROR" "System informations: OS minor version=${os_minor_version}"
    fi
  else
    ((error_counter++))
    log "ERROR" "System informations: ${centos_release_file} not found"
  fi
  if [ "${error_counter}" == "0" ]
  then
    echo_success "OK"
    if [[ ${SCRIPT_MODE} =~ v_sys ]]
    then
      echo_message "Check log file : ${INSTALLATION_LOG_FILE}"
      echo_info "INFO"
    fi
  else
    echo_failure "FAILED"
    abort_installation
  fi
}
# Generate private and public keys to secure communications
function generate_sslkeys() {
  local command_output_message=
  local error_counter=0
  local private_key_folder="/etc/pki/tls/private"
  local public_key_folder="/etc/pki/tls/certs"
  local private_key_name="${SERVER_SHORT_NAME}.key"
  local public_key_name="${SERVER_SHORT_NAME}.crt"
  local private_key_md5fingerprint=
  local public_key_md5fingerprint=
  local subject_commonname=${SERVER_HOST_NAME}
  PRIVATE_KEY_FILE="${private_key_folder}/$private_key_name"
  PUBLIC_KEY_FILE="${public_key_folder}/$public_key_name"
  echo_message "Generate SSL keys"
  command_output_message=$(test_directory ${private_key_folder})
  if [ "${command_output_message}" == "0" ]
  then
    log "INFO" "SSL keys: ${private_key_folder} successfully found"
  else
    ((error_counter++))
    log "ERROR" "SSL keys: ${private_key_folder} not found"
    log "DEBUG" "SSL keys: ${command_output_message}"
  fi
  command_output_message=$(test_directory ${public_key_folder})
  if [ "${command_output_message}" == "0" ]
  then
    log "INFO" "SSL keys: ${public_key_folder} successfully found"
  else
    ((error_counter++))
    log "ERROR" "SSL keys: ${public_key_folder} not found"
    log "DEBUG" "SSL keys: ${command_output_message}"
  fi
  if [ "${error_counter}" == "0" ]
  then
    command_output_message=$(test_file ${PRIVATE_KEY_FILE})
    if [ "${command_output_message}" == "0" ]
    then
      log "WARN" "SSL keys: ${PRIVATE_KEY_FILE} already generated"
    else
      ((error_counter++))
      log "ERROR" "SSL keys: ${PRIVATE_KEY_FILE} not found"
    fi
    command_output_message=$(test_file ${PUBLIC_KEY_FILE})
    if [ "${command_output_message}" == "0" ]
    then
      log "WARN" "SSL keys: ${PUBLIC_KEY_FILE} already generated"
    else
      ((error_counter++))
      log "ERROR" "SSL keys: ${PRIVATE_KEY_FILE} not found"
    fi
    if [ "${error_counter}" == "0" ]
    then
      echo_passed "PASS"
    elif [ "${error_counter}" == "2" ]
    then
      openssl req -x509 -newkey rsa:${SSL_KEY_SIZE} -keyform PEM -keyout ${PRIVATE_KEY_FILE} -nodes -outform PEM -out ${PUBLIC_KEY_FILE} -days ${SSL_KEY_DURATION} \
      -subj "/C=${SSL_SUBJECT_COUNTRY}/ST=${SSL_SUBJECT_STATE}/L=${SSL_SUBJECT_LOCALITY}/O=${SSL_SUBJECT_ORGANIZATION}/OU=${SSL_SUBJECT_ORGANIZATIONUNIT}/CN=${subject_commonname}/emailAddress=${SSL_SUBJECT_EMAIL}" \
      &>/dev/null
      private_key_md5fingerprint=$(openssl rsa -noout -modulus -in ${PRIVATE_KEY_FILE} | openssl md5 | sed -rn 's/.*=\s(.*)/\1/p')
      public_key_md5fingerprint=$(openssl x509 -noout -modulus -in ${PUBLIC_KEY_FILE} | openssl md5 | sed -rn 's/.*=\s(.*)/\1/p')
      if [ "${private_key_md5fingerprint}" == ${public_key_md5fingerprint} ]
      then
        log "INFO" "SSL keys: Private key location=${PRIVATE_KEY_FILE}"
        log "INFO" "SSL keys: Private key MD5 fingerprint=${private_key_md5fingerprint}"
        log "INFO" "SSL keys: Public key location=${PUBLIC_KEY_FILE}"
        log "INFO" "SSL keys: Public key MD5 fingerprint=${public_key_md5fingerprint}"
        log "INFO" "SSL keys: Successfully completed"
        echo_success "OK"
      else
        log "ERROR" "SSL keys: Private key MD5 fingerprint=${private_key_md5fingerprint}"
        log "ERROR" "SSL keys: Public key MD5 fingerprint=${public_key_md5fingerprint}"
        log "ERROR" "SSL keys: No match between both MD5 fingerprints"
        log "ERROR" "SSL keys: Not completed"
        echo_failure "FAILED"
        abort_installation
      fi
    else
      echo_failure "FAILED"
      abort_installation
    fi
  else
    echo_failure "FAILED"
    abort_installation
  fi
}
# Configure Yum repositories (EPEL, ElasticSearch, Nginx, Graylog)
function configure_yum() {
  local error_counter=0
  local warning_counter=0
  local command_output_message=
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
  command_output_message=$(test_file ${epel_repo_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((warning_counter++))
    log "WARN" "YUM repositories: EPEL repository already installed"
  else
    rpm --import ${epel_key_url}
    command_output_message=$(rpm -U ${epel_rpm_url} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "YUM repositories: EPEL repository successfully installed"
    else
      ((error_counter++))
      log "ERROR" "YUM repositories: EPEL repository not installed"
      log "DEBUG" "YUM repositories: ${command_output_message}"
    fi
  fi
  command_output_message=$(test_file ${nginx_repo_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((warning_counter++))
    log "WARN" "YUM repositories: NGINX repository already installed"
  else
    rpm --import ${nginx_key_url}
    command_output_message=$(rpm -U ${nginx_rpm_url} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "YUM repositories: NGINX repository successfully installed"
      command_output_message=$(sed -i \
      -e "s/\(baseurl=http:\/\/nginx\.org\/packages\)\(\/centos\/6\/\$basearch\/\)/\1\/mainline\2/" \
      ${nginx_repo_file} 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "YUM repositories: NGINX repository successfully configured"
      else
        ((error_counter++))
        log "ERROR" "YUM repositories: NGINX repository not configured"
        log "DEBUG" "YUM repositories: ${command_output_message}"
      fi
    else
      ((error_counter++))
      log "ERROR" "YUM repositories: NGINX repository not installed"
      log "DEBUG" "YUM repositories: ${command_output_message}"
    fi
  fi
  command_output_message=$(test_file ${mongodb_repo_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((warning_counter++))
    log "WARN" "YUM repositories: MONGO repository already installed"
  else
    command_output_message=$(cat << EOF > ${mongodb_repo_file}
[mongodb-org-3.0]
name=MongoDB Repository
baseurl=http://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/3.0/x86_64/
gpgcheck=0
enabled=1
EOF
2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "YUM repositories: MONGO repository successfully installed"
    else
      ((error_counter++))
      log "ERROR" "YUM repositories: MONGO repository not installed"
      log "DEBUG" "YUM repositories: ${command_output_message}"
    fi
  fi
  command_output_message=$(test_file ${elasticsearch_repo_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((warning_counter++))
    log "WARN" "YUM repositories: ELASTICSEARCH repository already installed"
  else
    rpm --import ${elasticsearch_key_url}
    command_output_message=$(cat << EOF > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch-1.5]
name=Elasticsearch repository for 1.5.x packages
baseurl=http://packages.elasticsearch.org/elasticsearch/1.5/centos
gpgcheck=1
gpgkey=http://packages.elasticsearch.org/GPG-KEY-elasticsearch
enabled=1
EOF
2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "YUM repositories: ELASTICSEARCH repository successfully installed"
    else
      ((error_counter++))
      log "ERROR" "YUM repositories: ELASTICSEARCH repository not installed"
      log "DEBUG" "YUM repositories: ${command_output_message}"
    fi
  fi
  command_output_message=$(test_file ${graylog_repo_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((warning_counter++))
    log "WARN" "YUM repositories: GRAYLOG repository already installed"
  else
    command_output_message=$(rpm -U ${graylog_rpm_url} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "YUM repositories: GRAYLOG repository successfully installed"
    else
      ((error_counter++))
      log "ERROR" "YUM repositories: GRAYLOG repository not installed"
      log "DEBUG" "YUM repositories: ${command_output_message}"
    fi
  fi
  if [ "${error_counter}" == "0" ] && [ "${warning_counter}" == "0" ]
  then
    echo_success "OK"
  elif [ "${error_counter}" == "0" ] && [ "${warning_counter}" != "0" ]
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
  local command_output_message=
  echo_message "Initialize YUM"
  command_output_message=$(yum clean all 2>&1 >/dev/null)
  if [ -z "${command_output_message}" ] || [ "${command_output_message}" =~ [Ww]arning.* ]
  then
    log "INFO" "YUM repositories: Successfully cleaned"
  else
    ((error_counter++))
    log "ERROR" "YUM repositories: Not cleaned"
    log "DEBUG" "YUM repositories: ${command_output_message}"
  fi
  command_output_message=$(yum makecache 2>&1 >/dev/null)
  if [ -z "${command_output_message}" ] || [ "${command_output_message}" =~ [Ww]arning.* ]
  then
    log "INFO" "YUM cache: Successfully created"
  else
    ((error_counter++))
    log "ERROR" "YUM cache: Not created"
    log "DEBUG" "YUM repositories: ${command_output_message}"
  fi
  if [ "${error_counter}" == "0" ]
  then
    echo_success "OK"
  else
    echo_failure "FAILED"
    abort_installation
  fi
}
# Upgrade OS to the last version
function upgrade_os() {
  local command_output_message=
  echo_message "Install YUM plugin"
  command_output_message=$(yum list installed | grep -w yum-presto)
  if [ -z "${command_output_message}" ]
  then
    command_output_message=$(yum -y install yum-presto 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ] || [[ "${command_output_message}" =~ [Ww]arning.* ]]
    then
      log "INFO" "YUM plugin: yum-presto successfully installed"
      echo_success "OK"
    else
      log "ERROR" "YUM plugin: yum-presto not installed"
      log "DEBUG" "YUM plugin: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  else
    log "WARN" "YUM plugin: yum-presto already installed"
    echo_passed "PASS"
  fi
  echo_message "Upgrade operating system"
  command_output_message=$(yum -y update 2>&1 >/dev/null)
  if [ -z "${command_output_message}" ] || [[ "${command_output_message}" =~ [Ww]arning.* ]]
  then
    log "INFO" "Upgrade operation: Successfully completed"
    echo_success "OK"
  else
    log "ERROR" "Upgrade operation: Not completed"
    log "DEBUG" "YUM plugin: ${command_output_message}"
    echo_failure "FAILED"
    abort_installation
  fi
}
# Install NTP service to maintain system at the time
function install_ntp() {
  local configured_counter=0
  local onstartup_counter=0
  local command_output_message=
  local chkconfig_array=
  local ntp_config_file="/etc/ntp.conf"
  local ntp_backup_file="${ntp_config_file}.dist"
  echo_message "Install NTP service"
  command_output_message=$(yum list installed | grep -w ntp)
  if [[ "${command_output_message}" =~ ^ntp\..* ]]
  then
    log "WARN" "NTP service: Already installed"
    echo_passed "PASS"
  else
    command_output_message=$(yum -y install ntp 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ] || [[ "${command_output_message}" =~ [Ww]arning.* ]]
    then
      log "INFO" "NTP service: Successfully installed"
      echo_success "OK"
    else
      log "INFO" "NTP service: Not installed"
      log "DEBUG" "NTP service: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  fi
  echo_message "Configure NTP service"
  if [[ "${BOOLEAN_NTP_CONFIGURE}" =~ true ]]
  then
    command_output_message=$(test_file ${ntp_backup_file})
    if [ "${command_output_message}" == "0" ]
    then
      ((configured_counter++))
      log "INFO" "NTP service: ${ntp_backup_file} successfully found"
    fi
    if [ "${configured_counter}" == "1" ]
    then
      log "WARN" "NTP service: Already configured"
      echo_passed "PASS"
    else
      command_output_message=$(sed -i.dist \
      -e "s/\(# Please consider.*\)/\1\nserver ${NEW_NTP_ADDRESS}/" \
      -e "s/\(server\s[0-9]\..*\)/#\1/" \
      ${ntp_config_file} 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "NTP service: Successfully configured"
        echo_success "OK"
      else
        log "ERROR" "NTP service: Not configured"
        log "DEBUG" "NTP service: ${command_output_message}"
        echo_failure "FAILED"
        abort_installation
      fi
    fi
  else
    log "WARN" "NTP service: Configuration cancelled by user"
    echo_passed "PASS"
  fi
  chkconfig_array=( `chkconfig --list | grep 'ntpd '` )
  for i in "${chkconfig_array[@]}"
  do
    value=`echo ${i} | awk -F: '{print $2}'`
    if [ "${value}" == "off" ]
    then
      ((onstartup_counter++))
    fi
  done
  if [[ "${BOOLEAN_NTP_ONSTARTUP}" =~ true ]]
  then
    echo_message "Enable NTP service on startup"
    if [ "${onstartup_counter}" == "7" ]
    then
      command_output_message=$(chkconfig ntpd on 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "NTP service: Successfully enabled on startup"
        echo_success "OK"
      else
        log "ERROR" "NTP service: Not enabled on startup"
        log "DEBUG" "NTP service: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "WARN" "NTP service: Already enabled on startup"
      echo_passed "PASS"
    fi
  else
    echo_message "Disable NTP service on startup"
    if [ "${onstartup_counter}" != "7" ]
    then
      command_output_message=$(chkconfig ntpd off 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "NTP service: Disabled on startup"
        echo_passed "OK"
      else
        log "ERROR" "NTP service: Not disabled on startup"
        log "DEBUG" "NTP service: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "WARN" "NTP service: Already disabled on startup"
      echo_passed "PASS"
    fi
  fi
}
# Install core rpm packages
function install_lsbpackages() {
  local installed_counter=0
  local command_output_message=
  echo_message "Install LSB packages"
  command_output_message=$(yum list installed | grep -w redhat-lsb-core)
  if [[ "${command_output_message}" =~ ^redhat-lsb-core\..* ]]
  then
    ((installed_counter++))
    log "WARN" "LSB packages: redhat-lsb-core already installed"
  fi
  command_output_message=$(yum list installed | grep -w mlocate)
  if [[ "${command_output_message}" =~ ^mlocate\..* ]]
  then
    ((installed_counter++))
    log "WARN" "LSB packages: mlocate already installed"
  fi
  command_output_message=$(yum list installed | grep -w bash-completion)
  if [[ "${command_output_message}" =~ ^bash-completion\..* ]]
  then
    ((installed_counter++))
    log "WARN" "LSB packages: bash-completion already installed"
  fi
  command_output_message=$(yum list installed | grep -w vim-enhanced)
  if [[ "${command_output_message}" =~ ^vim-enhanced\..* ]]
  then
    ((installed_counter++))
    log "WARN" "LSB packages: vim-enhanced already installed"
  fi
  command_output_message=$(yum list installed | grep -w dmidecode)
  if [[ "${command_output_message}" =~ ^dmidecode\..* ]]
  then
    ((installed_counter++))
    log "WARN" "LSB packages: dmidecode already installed"
  fi
  if [ "${installed_counter}" == "5" ]
  then
    log "WARN" "LSB packages: Already installed"
    echo_passed "PASS"
  else
    command_output_message=$(yum -y install vim redhat-lsb-core mlocate bash-completion dmidecode 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ] || [[ ${command_output_message} =~ [Ww]arning.* ]]
    then
      log "INFO" "LSB packages: Successfully installed"
      echo_success "OK"
    else
      log "ERROR" "LSB packages: Not installed"
      log "DEBUG" "LSB packages: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Install tcpdump, scp, telnet, traceroute, etc..
function install_networkpackages() {
  local installed_counter=0
  local command_output_message=
  echo_message "Install network packages"
  command_output_message=$(yum list installed | grep -w wget)
  if [[ "${command_output_message}" =~ ^wget\..* ]]
  then
    ((installed_counter++))
    log "WARN" "Network packages: wget already installed"
  fi
  command_output_message=$(yum list installed | grep -w tcpdump)
  if [[ "${command_output_message}" =~ ^tcpdump\..* ]]
  then
    ((installed_counter++))
    log "WARN" "Network packages: tcpdump already installed"
  fi
  command_output_message=$(yum list installed | grep -w traceroute)
  if [[ "${command_output_message}" =~ ^traceroute\..* ]]
  then
    ((installed_counter++))
    log "WARN" "Network packages: traceroute already installed"
  fi
  command_output_message=$(yum list installed | grep -w bind-utils)
  if [[ "${command_output_message}" =~ ^bind-utils\..* ]]
  then
    ((installed_counter++))
    log "WARN" "Network packages: bind-utils already installed"
  fi
  command_output_message=$(yum list installed | grep -w telnet)
  if [[ "${command_output_message}" =~ ^telnet\..* ]]
  then
    ((installed_counter++))
    log "WARN" "Network packages: telnet already installed"
  fi
  command_output_message=$(yum list installed | grep -w openssh-clients)
  if [[ "${command_output_message}" =~ ^openssh-clients\..* ]]
  then
    ((installed_counter++))
    log "WARN" "Network packages: openssh-clients already installed"
  fi
  command_output_message=$(yum list installed | grep -w system-config-firewall-tui)
  if [[ "${command_output_message}" =~ ^system-config-firewall-tui\..* ]]
  then
    ((installed_counter++))
    log "WARN" "Network packages: system-config-firewall-tui already installed"
  fi
  if [ "${installed_counter}" == "7" ]
  then
    log "WARN" "Network packages: Already installed"
    echo_passed "PASS"
  else
    command_output_message=$(yum -y install wget tcpdump traceroute bind-utils telnet openssh-clients system-config-firewall 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ] || [[ ${command_output_message} =~ [Ww]arning.* ]]
    then
      log "INFO" "Network packages: Successfully installed"
      echo_success "OK"
    else
      log "ERROR" "Network packages: Not installed"
      log "DEBUG" "Network packages: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Configure Bash
function configure_bashrc() {
  local command_output_message=
  local bashrc_config_file="/root/.bashrc"
  local bashrc_backup_file="${bashrc_config_file}.dist"
  echo_message "Configure Bourne-Again shell"
  command_output_message=$(test_file ${bashrc_backup_file})
  if [ "${command_output_message}" == "0" ]
  then
    log "INFO" "Bourne-Again shell: ${bashrc_backup_file} successfully found"
    log "WARN" "Bourne-Again shell: Already configured"
    echo_passed "PASS"
  else
    command_output_message=$(cp -p ${bashrc_config_file} ${bashrc_backup_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "Bourne-Again shell: Successfully backed-up"
      command_output_message=$(cat << EOF > ${bashrc_config_file}
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
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "Bourne-Again shell: Successfully configured"
        echo_success "OK"
      else
        log "ERROR" "Bourne-Again shell: NOT configured"
        log "DEBUG" "Bourne-Again shell: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "ERROR" "Bourne-Again shell: Not backed-up"
      log "DEBUG" "Bourne-Again shell: ${command_output_message}"
      echo_failure "FAILED"
    fi
  fi
}
# Configure OpenSSH to listen on loopback and specific interface specified by user
function configure_openssh() {
  local command_output_message=
  local opensshd_config_folder="/etc/ssh"
  local opensshd_config_file="${opensshd_config_folder}/sshd_config"
  local opensshd_backup_file="${opensshd_config_file}.dist"
  local openssh_hostrsakey_file="${opensshd_config_folder}/ssh_host_rsa_key"
  echo_message "Configure SSH service"
  command_output_message=$(test_file ${opensshd_backup_file})
  if [ "${command_output_message}" == "0" ]
  then
    log "INFO" "SSH service: ${opensshd_backup_file} successfully found"
    log "WARN" "SSH service: Already configured"
    echo_passed "PASS"
  else
    command_output_message=$(sed -i.dist \
    -e "s/#\(ListenAddress\)\s0.0.0.0/\1 ${SERVER_IP_ADDRESS}/g" \
    -e "s/#\(ListenAddress\)\s::/\1 127.0.0.1/g" \
    ${opensshd_config_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
#      ssh-keygen -b 2048 -t rsa -f ${openssh_hostrsakey_file}
      log "INFO" "SSH service: Successfully configured"
      echo_success "OK"
    else
      log "ERROR" "SSH service: Not configured"
      log "DEBUG" "SSH service: ${command_output_message}"
      echo_failure "FAILED"
    fi
  fi
}
# Configure RSA authentication for root user
function configure_rsaauth() {
  local command_output_message=
  local openssh_authorizedkeys_folder="/root/.ssh"
  local openssh_authorizedkeys_file="${openssh_authorizedkeys_folder}/authorized_keys"
  echo_message "Configure RSA authentication"
  command_output_message=$(test_directory ${openssh_authorizedkeys_folder})
  if [ "${command_output_message}" == "0" ]
  then
    log "INFO" "RSA authentication: ${openssh_authorizedkeys_folder} successfully found"
    command_output_message=$(test_file ${openssh_authorizedkeys_file})
    if [ "${command_output_message}" == "0" ]
    then
      log "INFO" "RSA authentication: ${openssh_authorizedkeys_file} successfully found"
      if [ -s "${openssh_authorizedkeys_file}" ]
      then
        log "WARN" "RSA authentication: ${openssh_authorizedkeys_file} not empty"
        command_output_message=$(find_pattern ${openssh_authorizedkeys_file} ${RSA_PUBLIC_KEY})
        if [ "${command_output_message}" == "0" ]
        then
          command_output_message=$(echo ${RSA_PUBLIC_KEY} >> ${openssh_authorizedkeys_file})
          if [ -z "${command_output_message}" ]
          then
            log "INFO" "RSA authentication: Public key successfully inserted"
            echo_success "OK"
          else
            log "ERROR" "RSA authentication: Public key not inserted"
            log "DEBUG" "RSA authentication: ${command_output_message}"
            echo_failure "FAILED"
          fi
        else
          log "WARN" "RSA authentication: Public key already inserted"
          echo_warning "WARN"
        fi
      else
        log "INFO" "RSA authentication: ${openssh_authorizedkeys_file} empty"
        command_output_message=$(echo ${RSA_PUBLIC_KEY} > ${openssh_authorizedkeys_file})
        if [ -z "${command_output_message}" ]
        then
          log "INFO" "RSA authentication: Public key successfully inserted"
          echo_success "OK"
        else
          log "ERROR" "RSA authentication: Public key not inserted"
          log "DEBUG" "RSA authentication: ${command_output_message}"
          echo_failure "FAILED"
        fi
      fi
    else
      touch ${openssh_authorizedkeys_file}
      log "INFO" "RSA authentication: ${openssh_authorizedkeys_file} created"
      echo ${RSA_PUBLIC_KEY} > ${openssh_authorizedkeys_file}
      log "INFO" "RSA authentication: Public key successfully inserted"
      echo_success "OK"
    fi
  else
    command_output_message=$(mkdir ${openssh_authorizedkeys_folder})
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "RSA authentication: ${openssh_authorizedkeys_folder} successfully created"
      command_output_message=$(chmod 700 ${openssh_authorizedkeys_folder})
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "RSA authentication: ${openssh_authorizedkeys_folder} successfully changed rights"
        command_output_message=$(touch ${openssh_authorizedkeys_file})
        if [ -z "${command_output_message}" ]
        then
          log "INFO" "RSA authentication: ${openssh_authorizedkeys_file} created"
          command_output_message=$(echo ${RSA_PUBLIC_KEY} > ${openssh_authorizedkeys_file})
          if [ -z "${command_output_message}" ]
          then
            log "INFO" "RSA authentication: Public key successfully inserted"
            echo_success "OK"
          else
            log "ERROR" "RSA authentication: Public key not inserted"
            log "DEBUG" "RSA authentication: ${command_output_message}"
            echo_failure "FAILED"
          fi
        else
          log "ERROR" "RSA authentication: ${openssh_authorizedkeys_file} not created"
          log "DEBUG" "RSA authentication: ${command_output_message}"
          echo_failure "FAILED"
        fi
      else
        log "ERROR" "RSA authentication: ${openssh_authorizedkeys_folder} not changed rights"
        log "DEBUG" "RSA authentication: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "ERROR" "RSA authentication: ${openssh_authorizedkeys_folder} not created"
      log "DEBUG" "RSA authentication: ${command_output_message}"
      echo_failure "FAILED"
    fi
  fi
}
# Configure Postfix to use Internet Protocol version 4
function configure_postfix() {
  local command_output_message=
  local postfix_config_folder="/etc/postfix"
  local postfix_config_file="${postfix_config_folder}/main.cf"
  local postfix_backup_file="${postfix_config_file}.dist"
  echo_message "Configure POSTFIX service"
  command_output_message=$(test_file ${postfix_backup_file})
  if [ "${command_output_message}" == "0" ]
  then
    log "INFO" "POSTFIX service: ${postfix_backup_file} successfully found"
    log "WARN" "POSTFIX service: Already configured"
    echo_passed "PASS"
  else
    command_output_message=$(sed -i.dist \
    -e "s/\(inet_protocols\s=\).*/\1 ipv4/g" \
    ${postfix_config_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "POSTFIX service: Successfully configured"
      echo_success "OK"
    else
      log "ERROR" "POSTFIX service: Not configured"
      log "DEBUG" "POSTFIX service: ${command_output_message}"
      echo_failure "FAILED"
    fi
  fi
}
# Add an entry to "/etc/hosts" file
function configure_hostsfile() {
  local command_output_message=
  local hosts_definiton_file="/etc/hosts"
  local hosts_backup_file="${hosts_definiton_file}.dist"
  echo_message "Configure hosts file"
  command_output_message=$(test_file ${hosts_backup_file})
  if [ "${command_output_message}" == "0" ]
  then
    log "INFO" "HOSTS file: ${hosts_backup_file} successfully found"
    log "WARN" "HOSTS file: Already configured"
    echo_passed "PASS"
  else
    command_output_message=$(sed -i.dist \
    -e "s/^\(127.0.0.1\)\s*\(.*\)/\1\t\2/g" \
    -e "s/^\(::1\)\s*\(.*\)/\1\t\t\2\n${SERVER_IP_ADDRESS}\t${SERVER_HOST_NAME}/g" \
    ${hosts_definiton_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "HOSTS file: Successfully configured"
      echo_success "OK"
    else
      log "ERROR" "HOSTS file: Not configured"
      log "DEBUG" "HOSTS file: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Disable Selinux module
function configure_selinux() {
  local command_output_message=
  local selinux_config_folder="/etc/selinux"
  local selinux_config_file="${selinux_config_folder}/config"
  local selinux_backup_file="${selinux_config_file}.dist"
  echo_message "Configure SELINUX module"
  command_output_message=$(test_file ${selinux_backup_file})
  if [ "${command_output_message}" == "0" ]
  then
    log "INFO" "SELINUX module: ${selinux_backup_file} successfully found"
    log "WARN" "SELINUX module: Already configured"
    echo_passed "PASS"
  else
    command_output_message=$(sed -i.dist \
    -e "s/\(SELINUX\)=enforcing/\1=disabled/g" \
    ${selinux_config_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "SELINUX module: Successfully configured"
      echo_success "OK"
    else
      log "ERROR" "SELINUX module: Not configured"
      log "DEBUG" "SELINUX module: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Install and configure Mongo database server
function install_mongodb() {
  local installed_counter=0
  local configured_counter=0
  local onstartup_counter=0
  local success_word_occurrence=
  local command_output_message=
  local chkconfig_array=
  local success_word_definition="Successfully"
  local mongodb_init_file="/etc/init.d/mongod"
  local mongodb_initbackup_file="${mongodb_init_file}.dist"
  local mongodb_config_file="/etc/mongod.conf"
  local mongodb_backup_file="${mongodb_config_file}.dist"
  echo_message "Install MONGO database server"
  command_output_message=$(yum list installed | grep mongodb-org.x)
  if [[ "${command_output_message}" =~ ^mongodb-org\..* ]]
  then
    ((installed_counter++))
    log "WARN" "MONGO database server: mongodb-org already installed"
  fi
  command_output_message=$(yum list installed | grep -w mongodb-org-mongos)
  if [[ "${command_output_message}" =~ ^mongodb-org-mongos\..* ]]
  then
    ((installed_counter++))
    log "WARN" "MONGO database server: mongodb-org-mongos already installed"
  fi
  command_output_message=$(yum list installed | grep -w mongodb-org-server)
  if [[ "${command_output_message}" =~ ^mongodb-org-server\..* ]]
  then
    ((installed_counter++))
    log "WARN" "MONGO database server: mongodb-org-server already installed"
  fi
  command_output_message=$(yum list installed | grep -w mongodb-org-shell)
  if [[ "${command_output_message}" =~ ^mongodb-org-shell\..* ]]
  then
    ((installed_counter++))
    log "WARN" "MONGO database server: mongodb-org-shell already installed"
  fi
  command_output_message=$(yum list installed | grep -w mongodb-org-tools)
  if [[ "${command_output_message}" =~ ^mongodb-org-tools\..* ]]
  then
    ((installed_counter++))
    log "WARN" "MONGO database server: mongodb-org-tools already installed"
  fi
  if [ "${installed_counter}" == "5" ]
  then
    log "WARN" "MONGO database server: Already installed"
    echo_passed "PASS"
  else
    command_output_message=$(yum -y install mongodb-org 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ] || [[ "${command_output_message}" =~ [Ww]arning.* ]]
    then
      log "INFO" "MONGO database server: Successfully installed"
      echo_success "OK"
    else
      log "ERROR" "MONGO database server: Not installed"
      log "DEBUG" "MONGO database server: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  fi
  echo_message "Configure MONGO database server"
  command_output_message=$(test_file ${mongodb_initbackup_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((configured_counter++))
    log "INFO" "MONGO database server: ${mongodb_initbackup_file} successfully found"
  fi
  command_output_message=$(test_file ${mongodb_backup_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((configured_counter++))
    log "INFO" "MONGO database server: ${mongodb_backup_file} successfully found"
  fi
  if [ "${configured_counter}" == "2" ]
  then
    log "WARN" "MONGO database server: Already configured"
    echo_passed "PASS"
  else
    command_output_message=$(sed -i.dist \
    -e "s/\(.*daemon\)\(.*--user \"\$MONGO_USER\" \"\$NUMACTL \$mongod \$OPTIONS >\/dev\/null 2>&1\"\)/\1 --check \$mongod\2/" \
    ${mongodb_init_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "MONGO database server: ${mongodb_init_file} successfully modified"
    else
      log "ERROR" "MONGO database server: ${mongodb_init_file} not modified"
      log "DEBUG" "MONGO database server: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
    command_output_message=$(service mongod start 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "MONGO database server: Successfully started"
      sleep 30
    else
      log "ERROR" "MONGO database server: Not started"
      log "DEBUG" "MONGO database server: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
    command_output_message=$(mongo --eval "db.getSiblingDB('${MONGODB_ADMIN_DATABASE}').createUser({user: '${MONGO_ADMIN_USER}', pwd: '${MONGO_ADMIN_PASSWORD}', roles: [ { role: 'root', db: '${MONGODB_ADMIN_DATABASE}' } ]})")
    success_word_occurrence=$(( (`cat <<<${command_output_message} | wc -c` - `sed "s/${success_word_definition}//g" <<<${command_output_message} | wc -c`) / ${#success_word_definition} ))
    if [ "${success_word_occurrence}" == "1" ]
    then
      log "INFO" "MONGO database server: Successfully set password (${MONGO_ADMIN_PASSWORD}) for user ${MONGO_ADMIN_USER}"
      log "INFO" "MONGO database server: Successfully set role 'root' to user ${MONGO_ADMIN_USER} on database ${MONGODB_ADMIN_DATABASE}"
    else
      log "ERROR" "MONGO database server: CLI configuration not completed"
      log "DEBUG" "MONGO database server: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
    command_output_message=$(mongo --eval "db.getSiblingDB('${MONGO_GRAYLOG_DATABASE}').createUser({user: '${MONGO_GRAYLOG_USER}',  pwd: '${MONGO_GRAYLOG_PASSWORD}',  roles: [ { role: 'readWrite', db: '${MONGO_GRAYLOG_DATABASE}' } ]})")
    success_word_occurrence=$(( (`cat <<<${command_output_message} | wc -c` - `sed "s/${success_word_definition}//g" <<<${command_output_message} | wc -c`) / ${#success_word_definition} ))
    if [ "${success_word_occurrence}" == "1" ]
    then
      log "INFO" "MONGO database server: Successfully create database ${MONGO_GRAYLOG_DATABASE}"
      log "INFO" "MONGO database server: Successfully create user ${MONGO_GRAYLOG_USER}"
      log "INFO" "MONGO database server: Successfully set password (${MONGO_GRAYLOG_PASSWORD}) for user ${MONGO_GRAYLOG_USER}"
      log "INFO" "MONGO database server: Successfully set role 'readWrite' to user ${MONGO_GRAYLOG_USER} on database ${MONGO_GRAYLOG_DATABASE}"
    else
      log "ERROR" "MONGO database server: CLI configuration not completed"
      log "DEBUG" "MONGO database server: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
    command_output_message=$(sed -i.dist \
    -e "s/#\(port=27017\)/\1/" \
    -e "s/#\(auth=true\)/\1/" \
    -e "s/#\(quota=true\)/\1/" \
    -e "s/#\(httpinterface=\)true/\1false/" \
    ${mongodb_config_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "MONGO database server: Successfully configured"
      echo_success "OK"
    else
      log "ERROR" "MONGO database server: Not configured"
      log "DEBUG" "MONGO database server: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  fi
  chkconfig_array=( `chkconfig --list | grep 'mongod'` )
  for i in "${chkconfig_array[@]}"
  do
    value=`echo ${i} | awk -F: '{print $2}'`
    if [ "${value}" == "off" ]
    then
      ((onstartup_counter++))
    fi
  done
  if [[ "${BOOLEAN_MONGO_ONSTARTUP}" =~ true ]]
  then
    echo_message "Enable MONGO database server on startup"
    if [ "${onstartup_counter}" == "7" ]
    then
      command_output_message=$(chkconfig mongod on 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "MONGO database server: Successfully enabled on startup"
        echo_success "OK"
      else
        log "ERROR" "MONGO database server: Not enabled on startup"
        log "DEBUG" "MONGO database server: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "WARN" "MONGO database server: Already enabled on startup"
      echo_passed "PASS"
    fi
  else
    echo_message "Disable MONGO database server on startup"
    if [ "${onstartup_counter}" != "7" ]
    then
      command_output_message=$(chkconfig mongod off 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "MONGO database server: Disabled on startup"
        echo_passed "OK"
      else
        log "ERROR" "MONGO database server: Not disabled on startup"
        log "DEBUG" "MONGO database server: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "WARN" "MONGO database server: Already disabled on startup"
      echo_passed "PASS"
    fi
  fi
}
# Install JRE (Java Runtime Environment)
function install_java() {
  local installed_counter=0
  local command_output_message=
  echo_message "Install Java Runtime Environment"
  command_output_message=$(yum list installed | grep java-)
  if [[ "${command_output_message}" =~ ^java.* ]]
  then
    ((installed_counter++))
    log "WARN" "Java Runtime Environment: RPM package already installed"
  fi
  if [ "${installed_counter}" == "1" ]
  then
    log "WARN" "Java Runtime Environment: Already installed"
    echo_passed "PASS"
  else
    command_output_message=$(yum -y install jre 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ] || [[ "${command_output_message}" =~ [Ww]arning.* ]]
    then
      log "INFO" "Java Runtime Environment: Successfully installed"
      echo_success "OK"
    else
      log "ERROR" "Java Runtime Environment: Not installed"
      log "DEBUG" "Java Runtime Environment: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  fi
}
# Configure RAM reservations for ELASTICSEARCH and GRAYLOG
function configure_ramreservations() {
  local ram_size=0
  local ram_array=( `dmidecode -t memory | grep 'Enabled Size:' | awk -F: '{print $2}' |  awk '{print $1}'` )
  echo_message "Configure RAM reservations"
  for i in "${ram_array[@]}"
  do
    if [ "${i}" != "Not" ]
    then
      ram_size=$(( ${ram_size}+${i} ))
    fi
  done
  log "INFO" "RAM reservations: Total RAM size = ${ram_size}MB"
  ELASTICSEARCH_RAM_RESERVATION="$(( ${ram_size}/2 ))m"
  log "INFO" "RAM reservations: ${ELASTICSEARCH_RAM_RESERVATION} for ELASTICSEARCH index server"
  GRAYLOGSERVER_RAM_RESERVATION="$(( ${ram_size}/4 ))m"
  log "INFO" "RAM reservations: ${GRAYLOGSERVER_RAM_RESERVATION} for GRAYLOG back-end server component"
  echo_success "OK"
}
# Install and configure ELASTICSEARCH index server
function install_elasticsearch() {
  local configured_counter=0
  local error_counter=0
  local onstartup_counter=0
  local command_output_message=
  local chkconfig_array=
  local elasticsearch_config_folder="/etc/elasticsearch"
  local elasticsearch_config_file="${elasticsearch_config_folder}/elasticsearch.yml"
  local elasticsearch_backup_file="${elasticsearch_config_file}.dist"
  local elasticsearch_sysconfig_file="/etc/sysconfig/elasticsearch"
  local elasticsearch_sysbackup_file="${elasticsearch_sysconfig_file}.dist"
  local elasticsearch_service_file="/usr/lib/systemd/system/elasticsearch.service"
  local elasticsearch_serbackup_file="${elasticsearch_service_file}.dist"
  echo_message "Install ELASTICSEARCH index server"
  command_output_message=$(yum list installed | grep -w elasticsearch)
  if [[ "${command_output_message}" =~ ^elasticsearch\..* ]]
  then
    log "WARN" "ELASTICSEARCH index server: Already installed"
    echo_passed "PASS"
  else
    command_output_message=$(yum -y install elasticsearch 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ] || [[ "${command_output_message}" =~ [Ww]arning.* ]]
    then
      log "INFO" "ELASTICSEARCH index server: Successfully installed"
      echo_success "OK"
    else
      log "ERROR" "ELASTICSEARCH index server: Not installed"
      log "DEBUG" "ELASTICSEARCH index server: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  fi
  echo_message "Configure ELASTICSEARCH index server"
  command_output_message=$(test_file ${elasticsearch_backup_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((configured_counter++))
    log "INFO" "ELASTICSEARCH index server: ${elasticsearch_backup_file} successfully found"
  fi
  command_output_message=$(test_file ${elasticsearch_sysbackup_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((configured_counter++))
    log "INFO" "ELASTICSEARCH index server: ${elasticsearch_sysbackup_file} successfully found"
  fi
  command_output_message=$(test_file ${elasticsearch_serbackup_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((configured_counter++))
    log "INFO" "ELASTICSEARCH index server: ${elasticsearch_serbackup_file} successfully found"
  fi
  if [ "${configured_counter}" == "3" ]
  then
    log "WARN" "ELASTICSEARCH index server: Already configured"
    echo_passed "PASS"
  else
    command_output_message=$(sed -i.dist \
    -e "s/#\(cluster.name: \).*/\1log-cluster/" \
    -e "s/#\(node.name: \).*/\1${SERVER_SHORT_NAME}-elasticsearch/" \
    -e "0,/#\(node.master: true\)/s//\1/" \
    -e "0,/#\(node.data: true\)/s//\1/" \
    -e "s/#\(network.host: \).*/\1${SERVER_IP_ADDRESS}/" \
    -e "s/#\(transport.tcp.port: 9300\)/\1/" \
    -e "s/#\(http.port: 9200\)/\1/" \
    -e "s/#\(http.enabled: \)false/\1true/" \
    -e "s/#\(discovery.zen.ping.multicast.enabled: false\)/\1/" \
    -e "s/#\(discovery.zen.ping.unicast.hosts: \).*/\1\[\"${SERVER_HOST_NAME}\"\]/" \
    -e "s/\(\#http.jsonp.enable: true\)/\1\nscript.disable_dynamic: true\nbootstrap.mlockall: true/" \
    ${elasticsearch_config_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "ELASTICSEARCH index server: ${elasticsearch_config_file} successfully modified"
    else
      ((error_counter++))
      log "ERROR" "ELASTICSEARCH index server: ${elasticsearch_config_file} not modified"
      log "DEBUG" "ELASTICSEARCH index server: ${command_output_message}"
    fi
    command_output_message=$(sed -i.dist \
    -e "s/#\(ES_HEAP_SIZE\=\).*/\1${ELASTICSEARCH_RAM_RESERVATION}/" \
    -e "s/#\(ES_DIRECT_SIZE\=\).*/\1${ELASTICSEARCH_RAM_RESERVATION}/" \
    -e "s/#\(ES_JAVA_OPTS\=\).*/\1\"\-Djava.net.preferIPv4Stack\=true\"/" \
    -e "s/#\(MAX_LOCKED_MEMORY\=\).*/\1unlimited/" \
    ${elasticsearch_sysconfig_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "ELASTICSEARCH index server: ${elasticsearch_sysconfig_file} successfully modified"
    else
      ((error_counter++))
      log "ERROR" "ELASTICSEARCH index server: ${elasticsearch_sysconfig_file} not modified"
      log "DEBUG" "ELASTICSEARCH index server: ${command_output_message}"
    fi
    command_output_message=$(sed -i.dist \
    -e "s/#\(LimitMEMLOCK\=infinity\)/\1/" \
    ${elasticsearch_service_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "ELASTICSEARCH index server: ${elasticsearch_service_file} successfully modified"
    else
      ((error_counter++))
      log "ERROR" "ELASTICSEARCH index server: ${elasticsearch_service_file} not modified"
      log "DEBUG" "ELASTICSEARCH index server: ${command_output_message}"
    fi
    command_output_message=$(chkconfig --add elasticsearch 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "ELASTICSEARCH index server: Successfully added to chkconfig"
    else
      ((error_counter++))
      log "ERROR" "ELASTICSEARCH index server: Not added to chkconfig"
      log "DEBUG" "ELASTICSEARCH index server: ${command_output_message}"
    fi
    if [ "${error_counter}" == "0" ]
    then
      log "INFO" "ELASTICSEARCH index server: Successfully configured"
      echo_success "OK"
    else
      echo_failure "FAILED"
      abort_installation
    fi
    echo_message "Start ELASTICSEARCH index server"
    command_output_message=$(service elasticsearch start 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "ELASTICSEARCH index server: Successfully started"
      echo_success "OK"
    else
      log "ERROR" "ELASTICSEARCH index server: Not started"
      log "DEBUG" "ELASTICSEARCH index server: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
    echo_message "Install ELASTICSEARCH HQ Management plugin"
    if [[ "${BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN}" =~ true ]]
    then
      command_output_message=$(/usr/share/elasticsearch/bin/plugin -install royrusso/elasticsearch-HQ 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "ELASTICSEARCH index server: HQ Management plugin successfully installed"
        echo_success "OK"
      else
        log "ERROR" "ELASTICSEARCH index server: HQ Management plugin not installed"
        log "DEBUG" "ELASTICSEARCH index server: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
        log "WARN" "ELASTICSEARCH index server: HQ Management plugin installation cancelled by user"
        echo_passed "PASS"
    fi
  fi
  chkconfig_array=( `chkconfig --list | grep 'elasticsearch'` )
  for i in "${chkconfig_array[@]}"
  do
    value=`echo ${i} | awk -F: '{print $2}'`
    if [ "${value}" == "off" ]
    then
      ((onstartup_counter++))
    fi
  done
  if [[ "${BOOLEAN_ELASTICSEARCH_ONSTARTUP}" =~ true ]]
  then
    echo_message "Enable ELASTICSEARCH index server on startup"
    if [ "${onstartup_counter}" == "7" ]
    then
      command_output_message=$(chkconfig elasticsearch on 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "ELASTICSEARCH index server: Successfully enabled on startup"
        echo_success "OK"
      else
        log "ERROR" "ELASTICSEARCH index server: Not enabled on startup"
        log "DEBUG" "ELASTICSEARCH index server: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "WARN" "ELASTICSEARCH index server: Already enabled on startup"
      echo_passed "PASS"
    fi
  else
    echo_message "Disable ELASTICSEARCH index server on startup"
    if [ "${onstartup_counter}" != "7" ]
    then
      command_output_message=$(chkconfig elasticsearch off 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "ELASTICSEARCH index server: Disabled on startup"
        echo_passed "OK"
      else
        log "ERROR" "ELASTICSEARCH index server: Not disabled on startup"
        log "DEBUG" "ELASTICSEARCH index server: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "WARN" "ELASTICSEARCH index server: Already disabled on startup"
      echo_passed "PASS"
    fi
  fi
}
# Install and configure server component of Graylog application
function install_graylogserver() {
  local configured_counter=0
  local error_counter=0
  local onstartup_counter=0
  local command_output_message=
  local chkconfig_array=
  local graylogserver_config_folder="/etc/graylog/server"
  local graylogserver_config_file="${graylogserver_config_folder}/server.conf"
  local graylogserver_backup_file="${graylogserver_config_file}.dist"
  local graylogserver_sysconfig_file="/etc/sysconfig/graylog-server"
  local graylogserver_sysbackup_file="${graylogserver_sysconfig_file}.dist"
  local graylog_secret_password=`echo -n ${GRAYLOG_SECRET_PASSWORD} | sha256sum | sed -rn 's/(.*)\s{2}.*/\1/p'`
  local graylog_admin_password=`echo -n ${GRAYLOG_ADMIN_PASSWORD} | sha256sum | sed -rn 's/(.*)\s{2}.*/\1/p'`
  echo_message "Install GRAYLOG back-end server"
  command_output_message=$(yum list installed | grep -w graylog-server)
  if [[ "${command_output_message}" =~ ^graylog-server\..* ]]
  then
    log "WARN" "GRAYLOG back-end server: Already installed"
    echo_passed "PASS"
  else
    command_output_message=$(yum -y install graylog-server 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ] || [[ "${command_output_message}" =~ [Ww]arning.* ]]
    then
      log "INFO" "GRAYLOG back-end server: Successfully installed"
      echo_success "OK"
    else
      log "ERROR" "GRAYLOG back-end server: Not installed"
      log "DEBUG" "GRAYLOG back-end server: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  fi
  echo_message "Configure GRAYLOG back-end server"
  command_output_message=$(test_file ${graylogserver_backup_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((configured_counter++))
    log "INFO" "GRAYLOG back-end server: ${graylogserver_backup_file} successfully found"
  fi
  command_output_message=$(test_file ${graylogserver_sysbackup_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((configured_counter++))
    log "INFO" "GRAYLOG back-end server: ${graylogserver_sysbackup_file} successfully found"
  fi
  if [ "${configured_counter}" == "2" ]
  then
    log "WARN" "GRAYLOG back-end server: Already configured"
    echo_passed "PASS"
  else
    command_output_message=$(sed -i.dist \
    -e "s/\(password_secret =\)/\1 ${graylog_secret_password}/" \
    -e "s/#\(root_username =\).*/\1 ${GRAYLOG_ADMIN_USERNAME}/" \
    -e "s/\(root_password_sha2 =\)/\1 ${graylog_admin_password}/" \
    -e "s/#\(root_email = \"\)\(\"\)/\1${SERVER_SHORT_NAME}\@${SMTP_DOMAIN_NAME}\2/" \
    -e "s|#\(root_timezone = \).*|\1${SERVER_TIME_ZONE}|" \
    -e "s|\(rest_listen_uri = \).*|\1https://${SERVER_HOST_NAME}:12900/|" \
    -e "s|#\(rest_transport_uri = \).*|\1https://${SERVER_HOST_NAME}:12900/|" \
    -e "s/#\(rest_enable_tls = true\)/\1/" \
    -e "s|#\(rest_tls_cert_file = \).*|\1${PUBLIC_KEY_FILE}|" \
    -e "s|#\(rest_tls_key_file = \).*|\1${PRIVATE_KEY_FILE}|" \
    -e "s/#\(elasticsearch_cluster_name = \).*/\1log-cluster/" \
    -e "s/#\(elasticsearch_node_name = \).*/\1${SERVER_SHORT_NAME}-graylog/" \
    -e "s/#\(elasticsearch_http_enabled = false\)/\1/" \
    -e "s/#\(elasticsearch_discovery_zen_ping_multicast_enabled = false\)/\1/" \
    -e "s/#\(elasticsearch_discovery_zen_ping_unicast_hosts = \).*/\1${SERVER_HOST_NAME}:9300/" \
    -e "s/#\(elasticsearch_node_master = false\)/\1/" \
    -e "s/#\(elasticsearch_node_data = false\)/\1/" \
    -e "s/#\(elasticsearch_transport_tcp_port = 9350\)/\1/" \
    -e "s/#\(elasticsearch_http_enabled = false\)/\1/" \
    -e "s/#\(elasticsearch_network_host = \).*/\1${SERVER_IP_ADDRESS}/" \
    -e "s/\(mongodb_useauth = \).*/\1true/" \
    -e "s/#\(mongodb_user = \).*/\1${MONGO_GRAYLOG_USER}/" \
    -e "s/#\(mongodb_password = \).*/\1${MONGO_GRAYLOG_PASSWORD}/" \
    -e "s/\(mongodb_host = \).*/\1localhost/" \
    -e "s/\(mongodb_database = \).*/\1${MONGO_GRAYLOG_DATABASE}/" \
    -e "s/#\(transport_email_enabled = \).*/\1${BOOLEAN_GRAYLOG_SMTP}/" \
    -e "s/#\(transport_email_hostname = \).*/\1${SMTP_HOST_NAME}/" \
    -e "s/#\(transport_email_port = \).*/\1${SMTP_PORT_NUMBER}/" \
    -e "s/#\(transport_email_use_auth = \).*/\1${BOOLEAN_SMTP_AUTH}/" \
    -e "s/#\(transport_email_use_tls = \).*/\1${BOOLEAN_SMTP_TLS}/" \
    -e "s/#\(transport_email_use_ssl = \).*/\1${BOOLEAN_SMTP_SSL}/" \
    -e "s/#\(transport_email_auth_username = \).*/\1${SMTP_AUTH_USERNAME}/" \
    -e "s/#\(transport_email_auth_password = \).*/\1${SMTP_AUTH_PASSWORD}/" \
    -e "s/#\(transport_email_subject_prefix = .*\)/\1/" \
    -e "s/#\(transport_email_from_email = \).*/\1${SERVER_SHORT_NAME}\@${SMTP_DOMAIN_NAME}/" \
    -e "s|#\(transport_email_web_interface_url = \).*|\1https://${SERVER_HOST_NAME}|" \
    ${graylogserver_config_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "GRAYLOG back-end server: ${graylogserver_config_file} successfully modified"
    else
      ((error_counter++))
      log "ERROR" "GRAYLOG back-end server: ${graylogserver_config_file} not modified"
      log "DEBUG" "GRAYLOG back-end server: ${command_output_message}"
    fi
    command_output_message=$(sed -i.dist \
    -e "s/\(GRAYLOG_SERVER_JAVA_OPTS=\"\).*\(\"\)/\1-Djava.net.preferIPv4Stack=true -Xms${GRAYLOGSERVER_RAM_RESERVATION} -Xmx${GRAYLOGSERVER_RAM_RESERVATION} -XX:NewRatio=1 -XX:PermSize=128m -XX:MaxPermSize=256m -server -XX:+ResizeTLAB -XX:+UseConcMarkSweepGC -XX:+CMSConcurrentMTEnabled -XX:+CMSClassUnloadingEnabled -XX:+UseParNewGC -XX:-OmitStackTraceInFastThrow\2/" \
    ${graylogserver_sysconfig_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "GRAYLOG back-end server: ${graylogserver_sysconfig_file} successfully modified"
    else
      ((error_counter++))
      log "ERROR" "GRAYLOG back-end server: ${graylogserver_sysconfig_file} not modified"
      log "DEBUG" "GRAYLOG back-end server: ${command_output_message}"
    fi
    if [ "${error_counter}" == "0" ]
    then
      log "INFO" "GRAYLOG back-end server: Successfully configured"
      echo_success "OK"
    else
      echo_failure "FAILED"
      abort_installation
    fi
  fi
  chkconfig_array=( `chkconfig --list | grep 'graylog-server'` )
  for i in "${chkconfig_array[@]}"
  do
    value=`echo ${i} | awk -F: '{print $2}'`
    if [ "${value}" == "off" ]
    then
      ((onstartup_counter++))
    fi
  done
  if [[ "${BOOLEAN_GRAYLOGSERVER_ONSTARTUP}" =~ true ]]
  then
    echo_message "Enable GRAYLOG back-end server on startup"
    if [ "${onstartup_counter}" == "7" ]
    then
      command_output_message=$(chkconfig graylog-server on 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "GRAYLOG back-end server: Successfully enabled on startup"
        echo_success "OK"
      else
        log "ERROR" "GRAYLOG back-end server: Not enabled on startup"
        log "DEBUG" "GRAYLOG back-end server: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "WARN" "GRAYLOG back-end server: Already enabled on startup"
      echo_passed "PASS"
    fi
  else
    echo_message "Disable GRAYLOG back-end server on startup"
    if [ "${onstartup_counter}" != "7" ]
    then
      command_output_message=$(chkconfig graylog-server off 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "GRAYLOG back-end server: Disabled on startup"
        echo_passed "OK"
      else
        log "ERROR" "GRAYLOG back-end server: Not disabled on startup"
        log "DEBUG" "GRAYLOG back-end server: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "WARN" "GRAYLOG back-end server: Already disabled on startup"
      echo_passed "PASS"
    fi
  fi
}
# Install and configure web interface component of Graylog application
function install_graylogwebgui() {
  local configured_counter=0
  local error_counter=0
  local onstartup_counter=0
  local command_output_message=
  local chkconfig_array=
  local graylogwebgui_config_folder="/etc/graylog/web"
  local graylogwebgui_config_file="${graylogwebgui_config_folder}/web.conf"
  local graylogwebgui_backup_file="${graylogwebgui_config_file}.dist"
  local graylogwebgui_sysconfig_file="/etc/sysconfig/graylog-web"
  local graylogwebgui_sysbackup_file="${graylogwebgui_sysconfig_file}.dist"
  local graylog_secret_password=`echo -n ${GRAYLOG_SECRET_PASSWORD} | sha256sum | sed -rn 's/(.*)\s{2}.*/\1/p'`
  echo_message "Install GRAYLOG front-end server"
  command_output_message=$(yum list installed | grep -w graylog-web)
  if [[ "${command_output_message}" =~ ^graylog-web\..* ]]
  then
    log "WARN" "GRAYLOG front-end server: Already installed"
    echo_passed "PASS"
  else
    command_output_message=$(yum -y install graylog-web 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ] || [[ "${command_output_message}" =~ [Ww]arning.* ]]
    then
      log "INFO" "GRAYLOG front-end server: Successfully installed"
      echo_success "OK"
    else
      log "ERROR" "GRAYLOG front-end server: Not installed"
      log "DEBUG" "GRAYLOG front-end server: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  fi
  echo_message "Configure GRAYLOG front-end server"
  command_output_message=$(test_file ${graylogwebgui_backup_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((configured_counter++))
    log "INFO" "GRAYLOG front-end server: ${graylogwebgui_backup_file} successfully found"
  fi
  command_output_message=$(test_file ${graylogwebgui_sysbackup_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((configured_counter++))
    log "INFO" "GRAYLOG front-end server: ${graylogwebgui_sysbackup_file} successfully found"
  fi
  if [ "${configured_counter}" == "2" ]
  then
    log "WARN" "GRAYLOG front-end server: Already configured"
    echo_passed "PASS"
  else
    command_output_message=$(sed -i.dist \
    -e "s|\(graylog2-server.uris=\"\)\(\"\)|\1https://${SERVER_HOST_NAME}:12900/\2|" \
    -e "s/\(application.secret=\"\)\(\"\)/\1${graylog_secret_password}\2/" \
    -e "s|#.*\(timezone=\"\).*\(\"\)|\1${SERVER_TIME_ZONE}\2|" \
    ${graylogwebgui_config_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "GRAYLOG front-end server: ${graylogwebgui_config_file} successfully modified"
    else
      ((error_counter++))
      log "ERROR" "GRAYLOG front-end server: ${graylogwebgui_config_file} not found"
      log "DEBUG" "GRAYLOG front-end server: ${command_output_message}"
    fi
    command_output_message=$(sed -i.dist \
    -e "s/\(GRAYLOG_WEB_HTTP_ADDRESS=\"\)0.0.0.0\(\"\)/\1localhost\2/" \
    -e "s/\(GRAYLOG_WEB_JAVA_OPTS=\"\)\(\"\)/\1-Djava.net.preferIPv4Stack=true\2/" \
    ${graylogwebgui_sysconfig_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "GRAYLOG front-end server: ${graylogwebgui_sysconfig_file} successfully modified"
    else
      ((error_counter++))
      log "ERROR" "GRAYLOG front-end server: ${graylogwebgui_sysconfig_file} not found"
      log "DEBUG" "GRAYLOG front-end server: ${command_output_message}"
    fi
    if [ "${error_counter}" == "0" ]
    then
      log "INFO" "GRAYLOG front-end server: Successfully configured"
      echo_success "OK"
    else
      echo_failure "FAILED"
      abort_installation
    fi
  fi
  chkconfig_array=( `chkconfig --list | grep 'graylog-web'` )
  for i in "${chkconfig_array[@]}"
  do
    value=`echo ${i} | awk -F: '{print $2}'`
    if [ "${value}" == "off" ]
    then
      ((onstartup_counter++))
    fi
  done
  if [[ "${BOOLEAN_GRAYLOGSERVER_ONSTARTUP}" =~ true ]]
  then
    echo_message "Enable GRAYLOG front-end server on startup"
    if [ "${onstartup_counter}" == "7" ]
    then
      command_output_message=$(chkconfig graylog-web on 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "GRAYLOG front-end server: Successfully enabled on startup"
        echo_success "OK"
      else
        log "ERROR" "GRAYLOG front-end server: Not enabled on startup"
        log "DEBUG" "GRAYLOG front-end server: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "WARN" "GRAYLOG front-end server: Already enabled on startup"
      echo_passed "PASS"
    fi
  else
    echo_message "Disable GRAYLOG front-end server on startup"
    if [ "${onstartup_counter}" != "7" ]
    then
      command_output_message=$(chkconfig graylog-web off 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "GRAYLOG front-end server: Disabled on startup"
        echo_passed "OK"
      else
        log "ERROR" "GRAYLOG front-end server: Not disabled on startup"
        log "DEBUG" "GRAYLOG front-end server: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "WARN" "GRAYLOG front-end server: Already disabled on startup"
      echo_passed "PASS"
    fi
  fi
}
# Install Nginx web server as a proxy to communicate with GRAYLOG front-end server
function install_nginx() {
  local installed_counter=0
  local error_counter=0
  local onstartup_counter=0
  local command_output_message=
  local chkconfig_array=
  local nginx_config_folder="/etc/nginx/conf.d"
  local nginx_defaultconfig_file="${nginx_config_folder}/default.conf"
  local nginx_defaultbackup_file="${nginx_defaultconfig_file}.dist"
  local nginx_defaultssl_file="${nginx_config_folder}/example_ssl.conf"
  local nginx_sslconfig_file="${nginx_config_folder}/ssl.conf"
  local nginx_sslbackup_file="${nginx_sslconfig_file}.dist"
  echo_message "Install NGINX web server"
  command_output_message=$(yum list installed | grep nginx.x)
  if [[ "${command_output_message}" =~ ^nginx\..* ]]
  then
    log "WARN" "NGINX web server: Already installed"
    echo_passed "PASS"
  else
    command_output_message=$(yum -y install nginx 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ] || [[ "${command_output_message}" =~ [Ww]arning.* ]]
    then
      log "INFO" "NGINX web server: Successfully installed"
      echo_success "OK"
    else
      log "ERROR" "NGINX web server: Not installed"
      log "DEBUG" "NGINX web server: ${command_output_message}"
      echo_failure "FAILED"
      abort_installation
    fi
  fi
  echo_message "Configure NGINX web server"
  command_output_message=$(test_file ${nginx_defaultbackup_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((configured_counter++))
  fi
  command_output_message=$(test_file ${nginx_sslconfig_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((configured_counter++))
  fi
  command_output_message=$(test_file ${nginx_sslbackup_file})
  if [ "${command_output_message}" == "0" ]
  then
    ((configured_counter++))
  fi
  if [ "${configured_counter}" == "3" ]
  then
    log "WARN" "NGINX web server: Already configured"
    echo_passed "PASS"
  else
    command_output_message=$(mv ${nginx_defaultconfig_file} ${nginx_defaultbackup_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "NGINX web server: ${nginx_defaultconfig_file} successfully backed-up"
    else
      ((error_counter++))
      log "ERROR" "NGINX web server: ${nginx_defaultconfig_file} not backed-up"
      log "DEBUG" "NGINX web server: ${command_output_message}"
    fi
    command_output_message=$(mv ${nginx_defaultssl_file} ${nginx_sslconfig_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "NGINX web server: ${nginx_defaultssl_file} successfully backed-up"
    else
      ((error_counter++))
      log "ERROR" "NGINX web server: ${nginx_defaultssl_file} successfully backed-up"
      log "DEBUG" "NGINX web server: ${command_output_message}"
    fi
    command_output_message=$(sed -i.dist \
    -e "s/\#\(server .*\)/\1/" \
    -e "s/\#.*\(listen\).*\(443.*;\)/\t\1\t\t\t\t${SERVER_HOST_NAME}:\2/" \
    -e "s/\#.*\(server_name\).*\(;\)/\t\1\t\t\t${SERVER_HOST_NAME}\2/" \
    -e "s|\#.*\(ssl_certificate \).*\(;\)|\t\1\t\t${PUBLIC_KEY_FILE}\2|" \
    -e "s|\#.*\(ssl_certificate_key\).*\(;\)|\t\1\t\t${PRIVATE_KEY_FILE}\2|" \
    -e "s/\#.*\(ssl_session_cache\).*\(shared:SSL:1m;\)/\t\1\t\t\2/" \
    -e "s/\#.*\(ssl_session_timeout\).*\(5m;\)/\t\1\t\t\2/" \
    -e "s/\#.*\(ssl_ciphers\).*\(HIGH:\!aNULL:\!MD5;\)/\t\1\t\t\t\2/" \
    -e "s/\#.*\(ssl_prefer_server_ciphers\).*\(on;\)/\t\1\t\2/" \
    -e "s/\#.*\(location \/ {\)/\t\1/" \
    -e "s/\# .*\(\}\)/\t\1/" \
    -e "s/\#.*root.*/\t\tproxy_pass http:\/\/localhost:9000\/;\n\t\tproxy_set_header Host \$host;\n\t\tproxy_set_header X-Real-IP \$remote_addr;\n\t\tproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n\t\tproxy_connect_timeout 150;\n\t\tproxy_send_timeout 100;\n\t\tproxy_read_timeout 100;\n\t\tproxy_buffers 4 32k;\n\t\tclient_max_body_size 8m;\n\t\tclient_body_buffer_size 128k;/" \
    -e "s/\#\(\}\)/\1/" \
    -e '/\#.*index.*/d' \
    ${nginx_sslconfig_file} 2>&1 >/dev/null)
    if [ -z "${command_output_message}" ]
    then
      log "INFO" "NGINX web server: ${nginx_defaultssl_file} successfully modified"
    else
      ((error_counter++))
      log "ERROR" "NGINX web server: ${nginx_defaultssl_file} not modified"
      log "DEBUG" "NGINX web server: ${command_output_message}"
    fi
    if [ "${error_counter}" == "0" ]
    then
      log "INFO" "NGINX web server: Successfully configured"
      echo_success "OK"
    else
      echo_failure "FAILED"
      abort_installation
    fi
  fi
  chkconfig_array=( `chkconfig --list | grep 'nginx'` )
  for i in "${chkconfig_array[@]}"
  do
    value=`echo ${i} | awk -F: '{print $2}'`
    if [ "${value}" == "off" ]
    then
      ((onstartup_counter++))
    fi
  done
  if [[ "${BOOLEAN_GRAYLOGSERVER_ONSTARTUP}" =~ true ]]
  then
    echo_message "Enable NGINX web server on startup"
    if [ "${onstartup_counter}" == "7" ]
    then
      command_output_message=$(chkconfig nginx on 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "NGINX web server: Successfully enabled on startup"
        echo_success "OK"
      else
        log "ERROR" "NGINX web server: Not enabled on startup"
        log "DEBUG" "NGINX web server: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "WARN" "NGINX web server: Already enabled on startup"
      echo_passed "PASS"
    fi
  else
    echo_message "Disable NGINX web server on startup"
    if [ "${onstartup_counter}" != "7" ]
    then
      command_output_message=$(chkconfig nginx off 2>&1 >/dev/null)
      if [ -z "${command_output_message}" ]
      then
        log "INFO" "NGINX web server: Disabled on startup"
        echo_passed "OK"
      else
        log "ERROR" "NGINX web server: Not disabled on startup"
        log "DEBUG" "NGINX web server: ${command_output_message}"
        echo_failure "FAILED"
      fi
    else
      log "WARN" "NGINX web server: Already disabled on startup"
      echo_passed "PASS"
    fi
  fi
}
# Display Graylog informations (URL, login and password of admin account)
function display_informations() {
  echo -e "\n###################################################################"
  echo -e "#${MOVE_TO_COL1}#\n# To administrate GRAYLOG back-end server${MOVE_TO_COL1}#"
  echo -e "# - URL\t: ${SETCOLOR_INFO}https://${SERVER_HOST_NAME}${SETCOLOR_NORMAL}${MOVE_TO_COL1}#\n#${MOVE_TO_COL1}#"
  echo -e "# Admin account${MOVE_TO_COL1}#"
  echo -e "# - Login\t: ${SETCOLOR_INFO}${GRAYLOG_ADMIN_USERNAME}${SETCOLOR_NORMAL}${MOVE_TO_COL1}#"
  echo -e "# - Password\t: ${SETCOLOR_INFO}${GRAYLOG_ADMIN_PASSWORD}${SETCOLOR_NORMAL}${MOVE_TO_COL1}#\n#${MOVE_TO_COL1}#"
  echo -e "###################################################################"
  if [[ "${BOOLEAN_INSTALL_ELASTICSEARCHPLUGIN}" =~ true ]]
  then
    echo -e "\n###################################################################"
    echo -e "#${MOVE_TO_COL1}#\n# To administrate ELASTICSEARCH index server${MOVE_TO_COL1}#"
    echo -e "# - URL\t: ${SETCOLOR_INFO}http://${SERVER_HOST_NAME}:9200/_plugin/HQ/${SETCOLOR_NORMAL}${MOVE_TO_COL1}#\n#${MOVE_TO_COL1}#"
    echo -e "###################################################################"
  fi
  echo -e "\n\n    ${SETCOLOR_WARNING}!!! You MUST restart the server after this installation !!!${SETCOLOR_NORMAL}    \n\n"
}
# Display help to use this installation program
function display_help() {
  local program=${0}
  echo -e "Usage: ${program} -i | a <file.cfg> | -v [--cfg <file.cfg> | --cnx | --sys]"
  echo -e "  -i                  Install Graylog Components with interactive questions"
  echo -e "  -a <file.cfg>       Install Graylog components with variables specified in <file.cfg>"
  echo -e "  -v --cfg <file.cfg> Verify variables specified in <file.cfg>"
  echo -e "  -v --cnx            Verify Internet connectivity"
  echo -e "  -v --sys            Verify OS informations"
  echo -e "  -h                  Display this help"
  echo -e "\nExample:\n   ${program} -a /root/graylog_variables.cfg"
}
# Main loop
function main {
  local command_output_message=
  if [[ "${SCRIPT_MODE}" =~ i|a|v_cnx ]]
  then
    test_internet
  fi
  if [[ "${SCRIPT_MODE}" =~ i ]]
  then
    set_globalvariables
  fi
  if [[ "${SCRIPT_MODE}" =~ a|v_cfg ]]
  then
    if [[ "${INSTALLATION_CFG_FILE}" =~ .*\.cfg$ ]]
    then
      command_output_message=$(test_file ${INSTALLATION_CFG_FILE})
      if [ "${command_output_message}" == "0" ]
      then
        log "INFO" "Global variables: ${INSTALLATION_CFG_FILE} successfully found"
        if [ -z "${INSTALLATION_CFG_FILE}" ]
        then
          log "ERROR" "Global variables: Not loaded"
          abort_installation
        else
          source ${INSTALLATION_CFG_FILE}
          log "INFO" "Global variables: Successfully loaded"
          verify_globalvariables
        fi
      else
        log "ERROR" "Global variables: ${INSTALLATION_CFG_FILE} not found"
        abort_installation
      fi
    else
      log "ERROR" "Global variables: ${INSTALLATION_CFG_FILE} bad extension"
      abort_installation
    fi
  fi
  if [[ "${SCRIPT_MODE}" =~ i|a|v_sys ]]
  then
    get_sysinfo
  fi
  if [[ "${SCRIPT_MODE}" =~ i|a ]]
  then
    generate_sslkeys
    configure_yum
    initialize_yum
    upgrade_os
    install_ntp
    install_lsbpackages
    install_networkpackages
    configure_bashrc
    configure_openssh
    if [[ "${BOOLEAN_RSA_AUTH}" =~ true ]]
    then
      configure_rsaauth
    else
      echo_message "Configure RSA authentication"
      log "WARN" "RSA authentication: operation cancelled by user"
      echo_passed "PASS"
    fi
    configure_postfix
    configure_hostsfile
    configure_selinux
    install_mongodb
    install_java
    configure_ramreservations
    install_elasticsearch
    install_graylogserver
    install_graylogwebgui
    install_nginx
    display_informations
  fi
}
#==============================================================================

#==============================================================================
# Program
#==============================================================================
OPTIND=1
if [ "${#}" == "0" ]
then
  display_help
  exit 1
else
  while getopts ":ia:v:" options
  do
    case "${options}" in
      i )
        SCRIPT_MODE="i"
        main
        ;;
      a )
        SCRIPT_MODE="a"
        INSTALLATION_CFG_FILE=${OPTARG}
        main
        ;;
      v )
        case ${OPTARG} in
          --cfg )
            SCRIPT_MODE="v_cfg"
            INSTALLATION_CFG_FILE=${3}
            main
            ;;
          --cnx )
            SCRIPT_MODE="v_cnx"
            main
            ;;
          --sys )
            SCRIPT_MODE="v_sys"
            main
            ;;
          * )
            display_help
            exit 1
            ;;
          \?|h )
            display_help
            exit 0
            ;;
        esac
        ;;
      : )
        display_help
        exit 1
        ;;
      \?|h )
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
fi
exit 0
#==============================================================================