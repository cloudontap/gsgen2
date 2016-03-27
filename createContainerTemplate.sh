#!/bin/bash

function usage() {
  echo -e "\nCreate a container specific CloudFormation template" 
  echo -e "\nUsage: $(basename $0) -s SLICE"
  echo -e "\nwhere\n"
  echo -e "    -h shows this text"
  echo -e "(o) -s SLICE is the slice of the solution to be included in the template (currently \"vpc\" or \"s3\")"
  echo -e "\nNOTES:\n"
  echo -e "1) You must be in the container specific directory when running this script"
  echo -e ""
  exit 1
}

# Parse options
while getopts ":hs:" opt; do
  case $opt in
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

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PID="$(basename $(cd ..;pwd))"
CONTAINER="$(basename $(pwd))"

ROOT_DIR="$(cd $BIN/../..;pwd)"
AWS_DIR="${ROOT_DIR}/infrastructure/aws"
PROJECT_DIR="${AWS_DIR}/${PID}"
CONTAINER_DIR="${PROJECT_DIR}/${CONTAINER}"
CF_DIR="${CONTAINER_DIR}/cf"

ORGANISATIONFILE="../../organisation.json"
ACCOUNTFILE="../../account.json"
PROJECTFILE="../project.json"
CONTAINERFILE="container.json"

if [[ -f solution.json ]]; then
	SOLUTIONFILE="solution.json"
else
	SOLUTIONFILE="../solution.json"
fi

if [[ ! -f ${CONTAINERFILE} ]]; then
    echo -e "\nNo \"${CONTAINERFILE}\" file in current directory. Are we in a container directory? Nothing to do."
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

# Ensure the aws tree for the templates exists
if [[ ! -d ${CF_DIR} ]]; then mkdir -p ${CF_DIR}; fi

TEMPLATE="createContainer.ftl"
TEMPLATEDIR="${BIN}/templates"

if [[ "${SLICE}" != "" ]]; then
	ARGS="-v slice=${SLICE}"
	OUTPUT="${CF_DIR}/cont-${SLICE}-${REGION}-template.json"
else
	ARGS=""
	OUTPUT="${CF_DIR}/container-${REGION}-template.json"
fi

ARGS="${ARGS} -v organisation=${ORGANISATIONFILE}"
ARGS="${ARGS} -v account=${ACCOUNTFILE}"
ARGS="${ARGS} -v project=${PROJECTFILE}"
ARGS="${ARGS} -v solution=${SOLUTIONFILE}"
ARGS="${ARGS} -v container=${CONTAINERFILE}"
ARGS="${ARGS} -v masterData=$BIN/data/masterData.json"

CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
eval $CMD
EXITSTATUS=$?

exit ${EXITSTATUS}
