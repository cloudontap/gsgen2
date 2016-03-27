#!/bin/bash

trap 'exit $RESULT' EXIT SIGHUP SIGINT SIGTERM

FILTER_DEFAULT=".*"
MINIMUM_DEFAULT=50
MAXIMUM_DEFAULT=100
function usage() {
  echo -e "\nUpdate the deployment configuration of ECS services to permit CF stack updates" 
  echo -e "\nUsage: $(basename $0) -f FILTER -n MINIMUM -x MAXIMUM\n"
  echo -e "\nwhere\n"
  echo -e "(o) -f FILTER string that services must match to be updated"
  echo -e "    -h shows this text"
  echo -e "(o) -n MINIMUM is the minimum healthy percent permitted during deploys"
  echo -e "(o) -x MAXIMUM is the maximum running percent (of the desired count) permitted during deploys"
  echo -e "\nDEFAULTS:\n"
  echo -e "FILTER  =\"${FILTER_DEFAULT}\""
  echo -e "MINIMUM =\"${MINIMUM_DEFAULT}%\""
  echo -e "MAXIMUM =\"${MAXIMUM_DEFAULT}%\""
  echo -e "\nNOTES:\n"
  echo -e "1) You must be in the directory corresponding to the environment to be updated"
  echo -e ""
  exit 1
}

FILTER=${FILTER_DEFAULT}
MINIMUM=${MINIMUM_DEFAULT}
MAXIMUM=${MAXIMUM_DEFAULT}
# Parse options
while getopts "f:hn:x:" opt; do
  case $opt in
    f)
      FILTER=$OPTARG
      ;;
    h)
      usage
      ;;
    n)
      MINIMUM=$OPTARG
      ;;
    x)
      MAXIMUM=$OPTARG
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

OAID="$(basename $(cd $BIN/../..;pwd))"

ROOT_DIR="$(cd $BIN/../..;pwd)"
AWS_DIR="${ROOT_DIR}/infrastructure/aws"

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

if [[ "${REGION}" == "" ]]; then
    echo -e "\nThe region must be defined in the container/solution/account configuration files (in this preference order). Nothing to do."
    usage
fi

# Set the profile if on PC to pick up the IAM credentials to use to access the credentials bucket. 
# For other platforms, assume the server has a service role providing access.
uname | grep -iE "MINGW64|Darwin|FreeBSD" > /dev/null 2>&1
if [[ "$?" -eq 0 ]]; then
    PROFILE="--profile ${OAID}"
fi

# Get the list of ECS clusters  
for CLUSTER in $(aws ${PROFILE} --region ${REGION} ecs list-clusters | grep ${PID}-${CONTAINER} | cut -f2 -d'/' | cut -f1 -d'"'); do
	# Get the list of services
    for SERVICE in $(aws ${PROFILE} --region ${REGION} ecs list-services --cluster ${CLUSTER} | grep ${PID}-${CONTAINER} | cut -f2 -d'/' | cut -f1 -d'"'); do
    	echo -en "\nCLUSTER=${CLUSTER}, SERVICE=${SERVICE}"
    	if [[ "${SERVICE}" =~ ${FILTER} ]]; then
			echo -e "\nCurrently:"
			aws ${PROFILE} --region ${REGION} ecs describe-services --cluster ${CLUSTER} --service ${SERVICE} | grep "Percent"
			
			aws ${PROFILE} --region ${REGION} ecs update-service --cluster ${CLUSTER} --service ${SERVICE} --deployment-configuration maximumPercent=${MAXIMUM},minimumHealthyPercent=${MINIMUM} > /dev/null 2>&1
	
			echo -e "Now:"
			aws ${PROFILE} --region ${REGION} ecs describe-services --cluster ${CLUSTER} --service ${SERVICE} | grep "Percent"
		else
			echo -e " - ignored"
		fi
		done
done

