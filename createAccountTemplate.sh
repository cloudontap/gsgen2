#!/bin/bash

function usage() {
  echo -e "\nCreate the account specific CloudFormation template" 
  echo -e "\nUsage: $(basename $0) -h"
  echo -e "\nwhere\n"
  echo -e "    -h shows this text"
  echo -e "\nNOTES:\n"
  echo -e "1) You must be in the account directory when running this script"
  echo -e ""
  exit 1
}

# Parse options
while getopts ":h" opt; do
  case $opt in
    h)
      usage
      ;;
    \?)
      echo -e "\nInvalid option: -$OPTARG" 
      usage
      ;;
    :)
      echo -e "\nOption -$OPTARG requires an argument" 
      usage
      ;;
   esac
done

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ROOT_DIR="$(cd $BIN/../..;pwd)"
AWS_DIR="${ROOT_DIR}/infrastructure/aws"
CF_DIR="${AWS_DIR}/cf"

if [[ ! -f account.json ]]; then
    echo -e "\nNo \"account.json\" file in current directory. Are we in a account directory? Nothing to do."
    usage
fi 

REGION=$(grep '"Region"' account.json | cut -d '"' -f 4)

if [[ "${REGION}" == "" ]]; then
    echo -e "\nThe region must be defined in the account configuration file. Are we in the correct directory? Nothing to do."
    usage
fi

if [[ ! -d ${CF_DIR} ]]; then mkdir -p ${CF_DIR}; fi

TEMPLATE="createAccount.ftl"
TEMPLATEDIR="${BIN}/templates"
OUTPUT="${CF_DIR}/account-${REGION}-template.json"

ARGS="-v organisation=organisation.json"
ARGS="${ARGS} -v account=account.json"
ARGS="${ARGS} -v masterData=$BIN/data/masterData.json"

CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
eval $CMD

exit $?
