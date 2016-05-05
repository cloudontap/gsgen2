#!/bin/bash

trap 'find . -name STATUS.txt -exec rm {} \; ; exit $RESULT' EXIT SIGHUP SIGINT SIGTERM

DELAY_DEFAULT=30
TIER_DEFAULT="database"
function usage() {
  echo -e "\nSnapshot an RDS Database" 
  echo -e "\nUsage: $(basename $0) -t TIER -i COMPONENT -s SUFFIX -c -m -d DELAY -r RETAIN -a AGE\n"
  echo -e "\nwhere\n"
  echo -e "(o) -a AGE is the maximum age in days of snapshots to retain"
  echo -e "(o) -c (CREATE ONLY) initiates but does not monitor the snapshot creation process"
  echo -e "(o) -d DELAY is the interval between checking the progress of snapshot creation. Default is ${DELAY_DEFAULT} seconds"
  echo -e "    -h shows this text"
  echo -e "(m) -i COMPONENT is the name of the database component in the solution"
  echo -e "(o) -m (MONITOR ONLY) monitors but does not initiate the snapshot creation process"
  echo -e "(o) -r RETAIN is the count of snapshots to retain"
  echo -e "(o) -s SUFFIX is appended to the snapshot identifier"
  echo -e "(o) -t TIER is the name of the database tier in the solution. Default is \"${TIER_DEFAULT}\""
  echo -e "\nNOTES:\n"
  echo -e "1. Snapshot identifer takes the form {project}-{environment}-database-{component}-datetime-{suffix}"
  echo -e "2. RETAIN and AGE may be used together. If both are present, RETAIN is applied first"
  echo -e ""
  exit 1
}

DELAY=${DELAY_DEFAULT}
TIER=${TIER_DEFAULT}
CREATE=true
WAIT=true
# Parse options
while getopts ":a:cd:hi:mr:s:t:" opt; do
  case $opt in
    a)
      AGE=$OPTARG
      ;;
    c)
      WAIT=false
      ;;
    d)
      DELAY=$OPTARG
      ;;
    h)
      usage
      ;;
    i)
      COMPONENT=$OPTARG
      ;;
    m)
      CREATE=false
      ;;
    r)
      RETAIN=$OPTARG
      ;;
    s)
      SUFFIX=$OPTARG
      ;;
    t)
      TIER=$OPTARG
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
if [[ "${COMPONENT}"  == "" ]]; then
  echo -e "\nInsufficient arguments"
  usage
fi

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

OAID="$(basename $(cd $BIN/../..;pwd))"

ROOT_DIR="$(cd $BIN/../..;pwd)"

# Determine the Organisation Account Identifier, Project Identifier, and region
# in which the stack should be created.
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

DB_INSTANCE_IDENTIFIER="${PID}-${CONTAINER}-${TIER}-${COMPONENT}"
DB_SNAPSHOT_IDENTIFIER="${DB_INSTANCE_IDENTIFIER}-$(date -u +%Y-%m-%d-%H-%M-%S)"
if [[ "${SUFFIX}" != "" ]]; then
    DB_SNAPSHOT_IDENTIFIER="${DB_SNAPSHOT_IDENTIFIER}-${SUFFIX}"
fi


if [[ "${CREATE}" == "true" ]]; then
	aws ${PROFILE} --region ${REGION} rds create-db-snapshot --db-snapshot-identifier ${DB_SNAPSHOT_IDENTIFIER} --db-instance-identifier ${DB_INSTANCE_IDENTIFIER}
	RESULT=$?
	if [ "$RESULT" -ne 0 ]; then exit; fi
fi

if [[ ("${RETAIN}" != "") || ("${AGE}" != "") ]]; then
    if [[ "${RETAIN}" != "" ]]; then
        LIST=$(aws ${PROFILE} --region ${REGION} rds describe-db-snapshots --snapshot-type manual | grep DBSnapshotIdentifier | grep ${DB_INSTANCE_IDENTIFIER} | cut -d'"' -f 4 | sort | head -n -${RETAIN})
    else
        LIST=$(aws ${PROFILE} --region ${REGION} rds describe-db-snapshots --snapshot-type manual | grep DBSnapshotIdentifier | grep ${DB_INSTANCE_IDENTIFIER} | cut -d'"' -f 4 | sort)
    fi
#    echo LIST=$LIST
    if [[ "${AGE}" != "" ]]; then
        BASELIST=${LIST}
        LIST=""
        LASTDATE=$(date --utc +%Y%m%d%H%M%S -d "$AGE days ago")
        for SNAPSHOT in $(echo $BASELIST); do
            DATEPLUSSUFFIX=${SNAPSHOT#"$DB_INSTANCE_IDENTIFIER-"}
            SUFFIX=${DATEPLUSSUFFIX#????-??-??-??-??-??}
            SNAPSHOTDATE=$(echo ${DATEPLUSSUFFIX%"$SUFFIX"} | tr -d "-")
#            echo LASTDATE=$LASTDATE, SNAPSHOT=$SNAPSHOTDATE
            if [[ $LASTDATE > $SNAPSHOTDATE ]]; then
                LIST="${LIST} ${SNAPSHOT}"
            fi
        done        
    fi
#    echo LIST=$LIST
    if [[ "${LIST}" != "" ]]; then
        for SNAPSHOT in $(echo $LIST); do
            aws ${PROFILE} --region ${REGION} rds delete-db-snapshot --db-snapshot-identifier $SNAPSHOT
        done
    fi
fi

RESULT=1
if [[ "${WAIT}" == "true" ]]; then
  while true; do
	aws ${PROFILE} --region ${REGION} rds describe-db-snapshots --db-snapshot-identifier ${DB_SNAPSHOT_IDENTIFIER} 2>/dev/null | grep "Status" > STATUS.txt
    cat STATUS.txt
    grep "available" STATUS.txt >/dev/null 2>&1
    RESULT=$?
    if [ "$RESULT" -eq 0 ]; then break; fi
    grep "creating" STATUS.txt  >/dev/null 2>&1
    RESULT=$?
    if [ "$RESULT" -ne 0 ]; then break; fi
    sleep $DELAY
  done
fi

