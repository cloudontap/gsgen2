#!/bin/bash

trap 'find . -name STATUS.txt -exec rm {} \; ; exit $RESULT' EXIT SIGHUP SIGINT SIGTERM

DELAY_DEFAULT=30
TIER_DEFAULT="web"
COMPONENT_DEFAULT="www"
function usage() {
  echo -e "\nRun an ECS task" 
  echo -e "\nUsage: $(basename $0) -t TIER -i COMPONENT -w TASK -e ENV -v VALUE -d DELAY\n"
  echo -e "\nwhere\n"
  echo -e "(o) -d DELAY is the interval between checking the progress of the task. Default is ${DELAY_DEFAULT} seconds"
  echo -e "(o) -e ENV is the name of an environment variable to define for the task"
  echo -e "    -h shows this text"
  echo -e "(o) -i COMPONENT is the name of the solution component where the task is defined. Default is \"${COMPONENT_DEFAULT}\""
  echo -e "(o) -t TIER is the name of the tier in the solution where the task is defined. Default is \"${TIER_DEFAULT}\""
  echo -e "(o) -v VALUE is the value for the last environment value defined (via -e) for the task"
  echo -e "(m) -w TASK is the name of the task to be run"
  echo -e "\nNOTES:\n"
  echo -e "1) The ECS cluster is found using the provided tier and component combined with the project and container"
  echo -e "2) ENV and VALUE should always appear in pairs" 
  echo -e ""
  exit 1
}

DELAY="${DELAY_DEFAULT}"
TIER="${TIER_DEFAULT}"
COMPONENT="${COMPONENT_DEFAULT}"
ENV_STRUCTURE="\"environment\":["
ENV_NAME=

# Parse options
while getopts ":d:e:hi:t:v:w:" opt; do
  case $opt in
    d)
      DELAY=$OPTARG
      ;;
    e)
      # Separate environment variable definitions
      if [[ -n "${ENV_NAME}" ]]; then 
          ENV_STRUCTURE="${ENV_STRUCTURE},"
      fi
      ENV_NAME=$OPTARG
      ;;
    h)
      usage
      ;;
    i)
      COMPONENT=$OPTARG
      ;;
    t)
      TIER=$OPTARG
      ;;
    v)
      ENV_STRUCTURE="${ENV_STRUCTURE}{\"name\":\"${ENV_NAME}\", \"value\":\"${OPTARG}\"}"
      ;;
    w)
      TASK=$OPTARG
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

ENV_STRUCTURE="${ENV_STRUCTURE}]"

# Ensure mandatory arguments have been provided
if [[ "${TASK}"  == "" ]]; then
  echo -e "\nInsufficient arguments"
  usage
fi

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

OAID="$(basename $(cd $BIN/../..;pwd))"

ROOT_DIR="$(cd $BIN/../..;pwd)"

# Determine the Organisation Account Identifier, Project Identifier, and region
# in which the task should be run.
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

# Find the cluster
CLUSTER_ARN=$(aws ${PROFILE} --region ${REGION} ecs list-clusters | jq -r ".clusterArns[] | capture(\"(?<arn>.*${PID}-${CONTAINER}.*ecsX${TIER}X${COMPONENT}.*)\").arn")
if [[ "${CLUSTER_ARN}" == "" ]]; then
    echo -e "\nUnable to locate ECS cluster"
    usage
fi

# Find the task definition
TASK_DEFINITION_ARN=$(aws ${PROFILE} --region ${REGION} ecs list-task-definitions | jq -r ".taskDefinitionArns[] | capture(\"(?<arn>.*${PID}-${CONTAINER}.*ecsTaskX${TIER}X${COMPONENT}X${TASK}.*)\").arn")
if [[ "${TASK_DEFINITION_ARN}" == "" ]]; then
    echo -e "\nUnable to locate task definition"
    usage
fi

aws ${PROFILE} --region ${REGION} ecs run-task --cluster "${CLUSTER_ARN}" --task-definition "${TASK_DEFINITION_ARN}" --count 1 --overrides "{\"containerOverrides\":[{\"name\":\"${TIER}-${COMPONENT}-${TASK}\",${ENV_STRUCTURE}}]}" > STATUS.txt
RESULT=$?
if [ "$RESULT" -ne 0 ]; then exit; fi
cat STATUS.txt
TASK_ARN=$(cat STATUS.txt | jq -r ".tasks[0].taskArn")

while true; do
    aws ${PROFILE} --region ${REGION} ecs describe-tasks --cluster ${CLUSTER_ARN} --tasks ${TASK_ARN} 2>/dev/null | jq ".tasks[] | select(.taskArn == \"${TASK_ARN}\") | {lastStatus: .lastStatus}" > STATUS.txt
    cat STATUS.txt
    grep "STOPPED" STATUS.txt >/dev/null 2>&1
    RESULT=$?
    if [ "$RESULT" -eq 0 ]; then break; fi
    grep "PENDING\|RUNNING" STATUS.txt  >/dev/null 2>&1
    RESULT=$?
    if [ "$RESULT" -ne 0 ]; then break; fi
    sleep $DELAY
done

