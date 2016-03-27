#!/bin/bash

function usage() {
  echo -e "\nCreate a project specific CloudFormation template" 
  echo -e "\nUsage: $(basename $0) -r REGION"
  echo -e "\nwhere\n"
  echo -e "    -h shows this text"
  echo -e "(o) -r REGION is the AWS region identifier for the region in which the stack should be created"
  echo -e "\nNOTES:\n"
  echo -e "1) If the region is not provided, the region will default to that provided in the"
  echo -e "   solution or account configuration file"
  echo -e "2) You must be in the project directory when running this script"
  echo -e ""
  exit 1
}

# Parse options
while getopts ":hr:" opt; do
  case $opt in
    h)
      usage
      ;;
    r)
      REGION=$OPTARG
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

PID="$(basename $(pwd))"

ROOT_DIR="$(cd $BIN/../..;pwd)"
AWS_DIR="${ROOT_DIR}/infrastructure/aws"
PROJECT_DIR="${AWS_DIR}/${PID}"
CF_DIR="${PROJECT_DIR}/cf"

if [[ "${REGION}" == "" && -e 'solution.json' ]]; then
  REGION=$(grep '"Region"' solution.json | cut -d '"' -f 4)
fi

if [[ "${REGION}" == "" && -e '../account.json' ]]; then
  REGION=$(grep '"Region"' ../account.json | cut -d '"' -f 4)
fi

if [[ ! -f project.json ]]; then
    echo -e "\nNo \"project.json\" file in current directory. Are we in a project directory? Nothing to do."
    usage
fi 

if [[ "${REGION}" == "" ]]; then
    echo -e "\nThe region must be defined in the solution or account configuration"
    echo -e "files, or on the command line. Are we in the correct directory? Nothing to do."
    usage
fi

if [[ ! -d ${CF_DIR} ]]; then mkdir -p ${CF_DIR}; fi

TEMPLATE="createProject.ftl"
TEMPLATEDIR="${BIN}/templates"
OUTPUT="${CF_DIR}/project-${REGION}-template.json"

ARGS="-v organisation=../organisation.json"
ARGS="${ARGS} -v account=../account.json"
ARGS="${ARGS} -v project=project.json"
ARGS="${ARGS} -v solution=solution.json"
ARGS="${ARGS} -v region=${REGION}"
ARGS="${ARGS} -v masterData=$BIN/data/masterData.json"

CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
eval $CMD

exit $?