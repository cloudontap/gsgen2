#!/bin/bash

function usage() {
  echo -e "\nCreate an application specific CloudFormation template" 
  echo -e "\nUsage: $(basename $0) -c CONFIGREFERENCE -s SLICE -d DEPLOYMENT_SLICE"
  echo -e "\nwhere\n"
  echo -e "(m) -c CONFIGREFERENCE is the id of the configuration (commit id, branch id, tag)"
  echo -e "(o) -d DEPLOYMENT_SLICE is the slice of the solution to be used to obtain deployment information"
  echo -e "    -h shows this text"
  echo -e "(o) -s SLICE is the slice of the solution to be included in the template"
  echo -e "\nNOTES:\n"
  echo -e "1) You must be in the container specific directory when running this script"
  echo -e "2) If no DEPLOYMENT_SLICE is provided, SLICE is used to obtain deployment information"
  echo -e ""
  exit 1
}

# Parse options
while getopts ":c:d:hs:" opt; do
  case $opt in
    c)
      CONFIGREFERENCE=$OPTARG
      ;;
    d)
      DEPLOYMENT_SLICE=$OPTARG
      ;;
    h)
      usage
      ;;
    s)
      SLICE=$OPTARG
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



# Ensure mandatory parameters have been provided
if [[ "${CONFIGREFERENCE}" == "" ]]; then
  echo -e "\nInsufficient arguments"
  usage
fi

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

OAID="$(basename $(cd $BIN/../..;pwd))"
PID="$(basename $(cd ..;pwd))"
CONTAINER="$(basename $(pwd))"

ROOT_DIR="$(cd $BIN/../..;pwd)"

AWS_DIR="${ROOT_DIR}/infrastructure/aws"
PROJECT_DIR="${AWS_DIR}/${PID}"
CONTAINER_DIR="${PROJECT_DIR}/${CONTAINER}"
CF_DIR="${CONTAINER_DIR}/cf"

CREDS_DIR="${ROOT_DIR}/infrastructure/credentials"
ACCOUNT_CREDS_DIR="${CREDS_DIR}/${OAID}"
PROJECT_CREDS_DIR="${CREDS_DIR}/${PID}"
CONTAINER_CREDS_DIR="${PROJECT_CREDS_DIR}/${CONTAINER}"

DEPLOYMENTS_DIR="${ROOT_DIR}/config/deployments"
PROJECT_DEPLOY_DIR="${DEPLOYMENTS_DIR}/${PID}"
CONTAINER_DEPLOY_DIR="${PROJECT_DEPLOY_DIR}/${CONTAINER}"
DEPLOY_DIR="${CONTAINER_DEPLOY_DIR}"
if [[ "${DEPLOYMENT_SLICE}" != "" ]]; then 
    DEPLOY_DIR="${DEPLOY_DIR}/${DEPLOYMENT_SLICE}"
else
    if [[ "${SLICE}" != "" ]]; then 
        DEPLOY_DIR="${DEPLOY_DIR}/${SLICE}"; 
    fi
fi
ORGANISATIONFILE="../../organisation.json"
ACCOUNTFILE="../../account.json"
PROJECTFILE="../project.json"
CONTAINERFILE="container.json"
CREDENTIALSFILE="${CONTAINER_CREDS_DIR}/credentials.json"
ACCOUNTCREDENTIALSFILE="${ACCOUNT_CREDS_DIR}/credentials.json"

if [[ -f solution.json ]]; then
	SOLUTIONFILE="solution.json"
else
	SOLUTIONFILE="../solution.json"
fi

if [[ ! -f ${CONTAINERFILE} ]]; then
    echo -e "\nNo \"${CONTAINERFILE}\" file in current directory. Are we in a container directory? Nothing to do."
    usage
fi 

if [[ -d ${DEPLOY_DIR} ]]; then
    BUILDFILE="${DEPLOY_DIR}/build.ref"
    CONFIGURATIONFILE="${DEPLOY_DIR}/config.json"

    if [[ ! -f ${CONFIGURATIONFILE} ]]; then
        echo -e "\nNo \"${CONFIGURATIONFILE}\" file present. Assuming no deployment configuration required.\n"
        CONFIGURATIONFILE=
    fi

    if [[ ! -f ${BUILDFILE} ]]; then
        echo -e "\nNo \"${BUILDFILE}\" file present. Assuming no build reference required.\n"
    else
        BUILDREFERENCE=$(cat ${BUILDFILE})
    fi
else
    echo -e "\nNo \"${DEPLOY_DIR}\" directory present. Assuming no deployment information required.\n"    
fi

if [[ -e ${ACCOUNTFILE} ]]; then
  ACCOUNTREGION=$(grep '"Region"' ${ACCOUNTFILE} | cut -d '"' -f 4)
fi

if [[ "${ACCOUNTREGION}" == "" ]]; then
    echo -e "\nThe account region must be defined in the account configuration file."
    echo -e "Are we in the correct directory? Nothing to do."
    usage
fi

REGION=$(grep '"Region"' ${CONTAINERFILE} | cut -d '"' -f 4)
if [[ "${REGION}" == "" && -e ${SOLUTIONFILE} ]]; then
  REGION=$(grep '"Region"' ${SOLUTIONFILE} | cut -d '"' -f 4)
fi
if [[ "${REGION}" == "" && -e ${ACCOUNTFILE} ]]; then
  REGION=$(grep '"Region"' ${ACCOUNTFILE} | cut -d '"' -f 4)
fi

if [[ "${REGION}" == "" ]]; then
    echo -e "\nThe region must be defined in the container/solution/account configuration files (in this preference order)."
    echo -e "Are we in the correct directory? Nothing to do."
    usage
fi

if [[ ! -d ${CF_DIR} ]]; then mkdir -p ${CF_DIR}; fi

TEMPLATE="createApplication.ftl"

if [[ -f ${TEMPLATE} ]]; then
	TEMPLATEDIR="./"
else
	TEMPLATEDIR="../"
fi

if [[ "${SLICE}" != "" ]]; then
	ARGS="-v slice=${SLICE}"
	OUTPUT="${CF_DIR}/app-${SLICE}-${REGION}-template.json"
else
	ARGS=""
	OUTPUT="${CF_DIR}/application-${REGION}-template.json"
fi

ARGS="${ARGS} -v organisation=${ORGANISATIONFILE}"
ARGS="${ARGS} -v account=${ACCOUNTFILE}"
ARGS="${ARGS} -v project=${PROJECTFILE}"
ARGS="${ARGS} -v solution=${SOLUTIONFILE}"
ARGS="${ARGS} -v container=${CONTAINERFILE}"
ARGS="${ARGS} -v credentials=${CREDENTIALSFILE}"
ARGS="${ARGS} -v accountCredentials=${ACCOUNTCREDENTIALSFILE}"
ARGS="${ARGS} -v masterData=$BIN/data/masterData.json"
if [[ "${BUILDREFERENCE}" != "" ]]; then
    ARGS="${ARGS} -v \"buildReference=${BUILDREFERENCE}\""
fi
ARGS="${ARGS} -v configurationReference=$CONFIGREFERENCE"
if [[ "${CONFIGURATIONFILE}" != "" ]]; then
    ARGS="${ARGS} -v configuration=${CONFIGURATIONFILE}"
fi

pushd ${CF_DIR}  > /dev/null 2>&1
STACKCOUNT=0
for f in $( ls cont*-${REGION}-stack.json sol*-${REGION}-stack.json 2> /dev/null); do
	PREFIX=$(echo $f | awk -F "-${REGION}-stack.json" '{print $1}' | sed 's/-//g')
	ARGS="${ARGS} -v ${PREFIX}Stack=${CF_DIR}/${f}"
	if [[ ${STACKCOUNT} > 0 ]]; then
		STACKS="${STACKS},"
	fi
	STACKS="${STACKS}\\\\\\\"${PREFIX}Stack\\\\\\\""
	STACKCOUNT=${STACKCOUNT}+1
done
popd  > /dev/null 2>&1
ARGS="${ARGS} -v stacks=[${STACKS}]"
CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
eval $CMD
EXITSTATUS=$?

exit ${EXITSTATUS}
