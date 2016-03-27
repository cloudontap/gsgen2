#!/bin/bash

# Defaults
OAINDEX_DEFAULT="01"

function usage() {
  echo -e "\nInitialise the account/ALM level credentials information" 
  echo -e "\nUsage: $(basename $0) -o OID -i OAINDEX"
  echo -e "\nwhere\n"
  echo -e "    -h shows this text"
  echo -e "(o) -i OAINDEX is the 2 digit organisation account index e.g. \"01\", \"02\""
  echo -e "(m) -o OID is the organisation id e.g. \"env\""
  echo -e "\nDEFAULTS:\n"
  echo -e "OAINDEX =\"${OAINDEX_DEFAULT}\""
  echo -e "\nNOTES:\n"
  echo -e "1) The organisation account id (OAID) is formed by concatenating the OID and the OAINDEX"
  echo -e "2) The OAID needs to match the root of the directory structure"
  echo -e ""
  exit 1
}

OAINDEX="${OAINDEX_DEFAULT}"

# Parse options
while getopts ":hi:o:" opt; do
  case $opt in
    h)
      usage
      ;;
    i)
      OAINDEX=$OPTARG
      ;;
    o)
      OID=$OPTARG
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

# Ensure mandatory arguments have been provided
if [[ "${OID}"  == "" ||
      "${OAINDEX}" == "" ]]; then
  echo -e "\nInsufficient arguments"
  usage
fi

OAID="${OID}${OAINDEX}"

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ROOT="$(basename $(cd $BIN/../..;pwd))"
ROOT_DIR="$(cd $BIN/../..;pwd)"
CREDS_DIR="${ROOT_DIR}/infrastructure/credentials"
PROJECT_DIR="${CREDS_DIR}/${OAID}"
ALM_DIR="${PROJECT_DIR}/alm"
DOCKER_DIR="${ALM_DIR}/docker"

if [[ "${OAID}" != "${ROOT}" ]]; then
    echo -e "\nThe provided OAID (${OAID}) doesn't match the root directory (${ROOT}). Nothing to do."
    usage
fi

if [[ -e ${PROJECT_DIR} ]]; then
    echo -e "\nLooks like this script has already been run. Don't want to overwrite passwords. Nothing to do."
    usage
fi

# Generate initial passwords
ROOTPASSWORD="$(curl -s 'https://www.random.org/passwords/?num=1&len=20&format=plain&rnd=new')"
LDAPPASSWORD="$(curl -s 'https://www.random.org/passwords/?num=1&len=20&format=plain&rnd=new')"
BINDPASSWORD="$(curl -s 'https://www.random.org/passwords/?num=1&len=20&format=plain&rnd=new')"

# Create the "account" level credentials directory
if [[ ! -e ${PROJECT_DIR} ]]; then
	mkdir ${PROJECT_DIR}
fi

# Generate the account level credentials
TEMPLATE="accountCredentials.ftl"
TEMPLATEDIR="${BIN}/templates"
OUTPUT="${PROJECT_DIR}/credentials.json"

ARGS="-v password=${ROOTPASSWORD}"

CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
eval $CMD

if [[ ! -e ${ALM_DIR} ]]; then
	mkdir ${ALM_DIR}
fi

# Generate the alm level credentials
TEMPLATE="almCredentials.ftl"
TEMPLATEDIR="${BIN}/templates"
OUTPUT="${ALM_DIR}/credentials.json"

ARGS="-v organisationId=${OID}"
ARGS="${ARGS} -v accountId=${OAID}"
ARGS="${ARGS} -v ldapPassword=${LDAPPASSWORD}"
ARGS="${ARGS} -v bindPassword=${BINDPASSWORD}"

CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
eval $CMD

if [[ ! -e ${DOCKER_DIR} ]]; then
	mkdir ${DOCKER_DIR}
fi

# Generate the ECS credentials for docker access
TEMPLATE="ecsConfig.ftl"
TEMPLATEDIR="${BIN}/templates"
OUTPUT="${DOCKER_DIR}/ecs.config"

ARGS="-v accountId=${OAID}"
ARGS="${ARGS} -v ldapPassword=${LDAPPASSWORD}"

CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
eval $CMD

cd ${CREDS_DIR}

# Remove the placeholder file
if [[ -e .placeholder ]]; then
	git rm .placeholder
fi

# Commit the results
git add *
git commit -m "Configure account/ALM credentials"

