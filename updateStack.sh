#!/bin/bash

trap 'find ${AWS_DIR} -name STATUS.txt -exec rm {} \; ; exit $RESULT' EXIT SIGHUP SIGINT SIGTERM

DELAY_DEFAULT=30
function usage() {
  echo -e "Update an existing CloudFormation stack" 
  echo -e "\nUsage: $(basename $0) -t TYPE -s SLICE -u -m -d DELAY -r REGION\n"
  echo -e "\nwhere\n"
  echo -e "(o) -d DELAY is the interval between checking the progress of stack update. Default is ${DELAY_DEFAULT} seconds"
  echo -e "    -h shows this text"
  echo -e "(o) -m (MONITOR ONLY) monitors but does not initiate the stack update process"
  echo -e "(o) -r REGION is the AWS region identifier for the region in which the stack should be updated"
  echo -e "(o) -s SLICE is the slice of the solution to be included in the template"
  echo -e "(m) -t TYPE is the stack type - \"account\", \"project\", \"container\", \"solution\" or \"application\""
  echo -e "(o) -u (UPDATE ONLY) initiates but does not monitor the stack update process"
  echo -e "\nNOTES:\n"
  echo -e "1) You must be in the correct directory corresponding to the requested stack type"
  echo -e "2) REGION is only relevant for the \"project\" type, where multiple project stacks are necessary if the project uses resources"
  echo -e "   in multiple regions"  
  echo -e ""
  exit 1
}

DELAY=${DELAY_DEFAULT}
UPDATE=true
WAIT=true

# Parse options
while getopts ":d:hmr:s:t:u" opt; do
  case $opt in
    d)
      DELAY=$OPTARG
      ;;
    h)
      usage
      ;;
    m)
      UPDATE=false
      ;;
    r)
      REGION=$OPTARG
      ;;
    s)
      SLICE=$OPTARG
      ;;
    t)
      TYPE=$OPTARG
      ;;
    u)
      WAIT=false
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
if [[ "${TYPE}"  == "" ]]; then
  echo -e "\nInsufficient arguments"
  usage
fi

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

OAID="$(basename $(cd $BIN/../..;pwd))"

ROOT_DIR="$(cd $BIN/../..;pwd)"
AWS_DIR="${ROOT_DIR}/infrastructure/aws"

# Determine the Organisation Account Identifier, Project Identifier, and region
# in which the stack should be created.
case $TYPE in
account)
  if [[ -e 'account.json' ]]; then
	REGION=$(grep '"Region"' account.json | cut -d '"' -f 4)
  fi
  CF_DIR="${AWS_DIR}/cf"
  STACKNAME="$OAID-$TYPE"
  TEMPLATE="${TYPE}-${REGION}-template.json"
  STACK="${TYPE}-${REGION}-stack.json"
  ;;
project)
  PID="$(basename $(pwd))"
  if [[ "${REGION}" == "" && -e 'solution.json' ]]; then
	REGION=$(grep '"Region"' solution.json | cut -d '"' -f 4)
  fi
  if [[ "${REGION}" == "" && -e '../account.json' ]]; then
	REGION=$(grep '"Region"' ../account.json | cut -d '"' -f 4)
  fi
  CF_DIR="${AWS_DIR}/${PID}/cf"
  STACKNAME="$PID-$TYPE"
  TEMPLATE="${TYPE}-${REGION}-template.json"
  STACK="${TYPE}-${REGION}-stack.json"
  ;;
solution|container|application)
  PID="$(basename $(cd ../;pwd))"
  CONTAINER="$(basename $(pwd))"
  if [[ -e 'container.json' ]]; then
	REGION=$(grep '"Region"' container.json | cut -d '"' -f 4)
  fi
  if [[ "${REGION}" == "" && -e '../solution.json' ]]; then
	REGION=$(grep '"Region"' ../solution.json | cut -d '"' -f 4)
  fi
  if [[ "${REGION}" == "" && -e '../../account.json' ]]; then
	REGION=$(grep '"Region"' ../../account.json | cut -d '"' -f 4)
  fi
  CF_DIR="${AWS_DIR}/${PID}/${CONTAINER}/cf"
  STACKNAME="$PID-$CONTAINER-$TYPE"
  TEMPLATE="${TYPE}-${REGION}-template.json"
  STACK="${TYPE}-${REGION}-stack.json"
  if [[ ("${SLICE}" != "") && ("${TYPE}" == "container") ]]; then
    STACKNAME="$PID-$CONTAINER-cont-${SLICE}"
    TEMPLATE="cont-${SLICE}-${REGION}-template.json"
    STACK="cont-${SLICE}-${REGION}-stack.json"
  fi
  if [[ ("${SLICE}" != "") && ("${TYPE}" == "solution") ]]; then
    STACKNAME="$PID-$CONTAINER-soln-${SLICE}"
    TEMPLATE="soln-${SLICE}-${REGION}-template.json"
    STACK="soln-${SLICE}-${REGION}-stack.json"
  fi
  if [[ ("${SLICE}" != "") && ("${TYPE}" == "application") ]]; then
    STACKNAME="$PID-$CONTAINER-app-${SLICE}"
    TEMPLATE="app-${SLICE}-${REGION}-template.json"
    STACK="app-${SLICE}-${REGION}-stack.json"
  fi
  ;;
*)
  echo -e "\n\"$TYPE\" is not one of the known stack types (account, project, container, solution, application). Nothing to do."
  usage
  ;;
esac

if [[ "${REGION}" == "" ]]; then
    echo -e "\nThe region must be defined in the container/solution/account configuration files (in this preference order). Nothing to do."
    usage
fi

if [[ ! -e "${CF_DIR}/$TEMPLATE" ]]; then
    echo -e "\n\"${TEMPLATE}\" not found. Are we in the correct place in the directory tree? Nothing to do."
    usage
fi

# Set the profile if on PC to pick up the IAM credentials to use to access the credentials bucket. 
# For other platforms, assume the server has a service role providing access.
uname | grep -iE "MINGW64|Darwin|FreeBSD" > /dev/null 2>&1
if [[ "$?" -eq 0 ]]; then
    PROFILE="--profile ${OAID}"
fi

pushd ${CF_DIR} > /dev/null 2>&1

cat $TEMPLATE | jq -c . > stripped-${TEMPLATE}

if [[ "${UPDATE}" = "true" ]]; then
    aws ${PROFILE} --region ${REGION} cloudformation update-stack --stack-name $STACKNAME --template-body file://stripped-${TEMPLATE} --capabilities CAPABILITY_IAM
fi

RESULT=1
if [[ "${WAIT}" = "true" ]]; then
  while true; do
    aws ${PROFILE} --region ${REGION} cloudformation describe-stacks --stack-name $STACKNAME > $STACK
    grep "StackStatus" $STACK > STATUS.txt
    cat STATUS.txt
    grep "UPDATE_COMPLETE" STATUS.txt >/dev/null 2>&1
    RESULT=$?
    if [ "$RESULT" -eq 0 ]; then break;fi
    grep "UPDATE_IN_PROGRESS" STATUS.txt  >/dev/null 2>&1
    RESULT=$?
    if [ "$RESULT" -ne 0 ]; then break;fi
#    read -t $DELAY
	sleep $DELAY
  done
fi

