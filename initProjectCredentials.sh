#!/bin/bash

function usage() {
  echo -e "\nCreate project credentials and install them in an AWS region" 
  echo -e "\nUsage: $(basename $0) -a OAID -p PID -r REGION"
  echo -e "\nwhere\n"
  echo -e "(m) -a OAID is the organisation account id e.g. \"env01\""
  echo -e "    -h shows this text"
  echo -e "(m) -p PID is the project id e.g. \"eticket\""
  echo -e "(o) -r REGION is the AWS region identifier for the region to be updated"
  echo -e "\nNOTES:\n"
  echo -e "1) The project directory tree will be created if not present"
  echo -e "2) The OAID is only used to ensure we are in the correct directory tree"
  echo -e "3) If ssh keys already exist, they are not recreated"
  echo -e "4) If a region is not provided, the organisation account/solution region will be used"
  echo -e ""
  exit 1
}

# Parse options
while getopts ":a:hp:r:" opt; do
  case $opt in
    a)
      OAID=$OPTARG
      ;;
    h)
      usage
      ;;
    p)
      PID=$OPTARG
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

ROOT="$(basename $(cd $BIN/../..;pwd))"
ROOT_DIR="$(cd $BIN/../..;pwd)"

CREDS_DIR="${ROOT_DIR}/infrastructure/credentials"
PROJECT_DIR="${CREDS_DIR}/${PID}"
ALPHA_DIR="${PROJECT_DIR}/alpha"

SOLUTIONS_DIR="${ROOT_DIR}/config/solutions"
PROJECT_SOLUTIONS_DIR="${SOLUTIONS_DIR}/${PID}"

# Region defaults to that configured in the account/solution files
if [[ "${REGION}" == "" && -e ${PROJECT_SOLUTIONS_DIR}/solution.json ]]; then
  REGION=$(grep '"Region"' ${PROJECT_SOLUTIONS_DIR}/solution.json | cut -d '"' -f 4)
fi

if [[ "${REGION}" == "" && -e ${SOLUTIONS_DIR}/account.json ]]; then
  REGION=$(grep '"Region"' ${SOLUTIONS_DIR}/account.json | cut -d '"' -f 4)
fi

# Ensure mandatory arguments have been provided
if [[ "${OAID}" == "" || 
      "${REGION}" == "" || 
      "${PID}"  == "" ]]; then
  echo -e "\nInsufficient arguments"
  usage
fi

if [[ "${OAID}" != "${ROOT}" ]]; then
    echo -e "\nThe provided OAID (${OAID}) doesn't match the root directory (${ROOT}). Nothing to do."
    usage
fi

if [[ ! -d ${PROJECT_SOLUTIONS_DIR} ]]; then
    echo -e "\nProject needs to be configured before credentials are created. Nothing to do."
    usage
fi

# Set the profile if on PC to pick up the IAM credentials to use to access the credentials bucket. 
# For other platforms, assume the server has a service role providing access.
uname | grep -iE "MINGW64|Darwin|FreeBSD" > /dev/null 2>&1
if [[ "$?" -eq 0 ]]; then
    PROFILE="--profile ${OAID}"
fi

# Handle some MINGW peculiarities
uname | grep -i "MINGW64" > /dev/null 2>&1
if [[ "$?" -eq 0 ]]; then
	MINGW64="true"
fi

if [[ ! -d "${PROJECT_DIR}" ]]; then
  mkdir ${PROJECT_DIR}
  for CONTAINER in $(ls ${PROJECT_SOLUTIONS_DIR}); do
  	CONTAINER_NAME="$(basename ${CONTAINER})"
  	CONTAINER_DIR="${PROJECT_DIR}/${CONTAINER_NAME}"
    if [[ (-d ${PROJECT_SOLUTIONS_DIR}/${CONTAINER_NAME}) && (! -d ${CONTAINER_DIR}) ]]; then
      mkdir ${CONTAINER_DIR}

      # Generate the credentials for the container 
      PASSWORD="$(curl -s 'https://www.random.org/passwords/?num=1&len=20&format=plain&rnd=new')"
      TEMPLATE="containerCredentials.ftl"
      TEMPLATEDIR="${BIN}/templates"
      OUTPUT="${CONTAINER_DIR}/credentials.json"

      ARGS="-v password=${PASSWORD}"

      CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
      eval $CMD
    fi  
  done
fi

pushd ${PROJECT_DIR} > /dev/null 2>&1
 
if [[ (! -e aws-ssh-crt.pem) && (! -e aws-ssh-prv.pem) ]]; then
  openssl genrsa -out aws-ssh-prv.pem 2048
  openssl rsa -in aws-ssh-prv.pem -pubout > aws-ssh-crt.pem
fi

# Upload the project specific keypair
if [[ -e aws-ssh-crt.pem ]]; then
  aws ${PROFILE} --region ${REGION} ec2 describe-key-pairs --key-name ${PID} > /dev/null 2>&1
  if [[ "$?" -ne 0 ]]; then 
    CRT=$(cat aws-ssh-crt.pem | dos2unix | awk 'BEGIN {RS="\n"} /^[^-]/ {printf $1}')
    aws ${PROFILE} --region ${REGION} ec2 import-key-pair --key-name ${PID} --public-key-material $CRT
  fi
fi

# Upload any SSL certificate if present for ELB/CloudFront
for CERTIFICATE in $(ls *crt.pem 2> /dev/null | grep -v "^aws-ssh"); do
  PREFIX=$(echo $CERTIFICATE | awk -F "crt.pem" '{print $1}')
  aws ${PROFILE} --region ${REGION} iam get-server-certificate --server-certificate-name ${PID}-ssl > /dev/null 2>&1
  if [[ "$?" -ne 0 ]]; then
	if [[ "${MINGW64}" == "true" ]]; then
	  MSYS_NO_PATHCONV=1 aws ${PROFILE} --region ${REGION} iam upload-server-certificate --server-certificate-name ${PID}-ssl --path "/ssl/${PID}/" --certificate-body file://${PREFIX}crt.pem --private-key file://${PREFIX}prv.pem --certificate-chain file://${PREFIX}chain.pem
	else
	  aws ${PROFILE} --region ${REGION} iam upload-server-certificate --server-certificate-name ${PID}-ssl --path "/ssl/${PID}/" --certificate-body file://${PREFIX}crt.pem --private-key file://${PREFIX}prv.pem --certificate-chain file://${PREFIX}chain.pem
	fi
  fi

  aws ${PROFILE} --region ${REGION} iam get-server-certificate --server-certificate-name ${PID}-cloudfront > /dev/null 2>&1
  if [[ "$?" -ne 0 ]]; then
	if [[ "${MINGW64}" == "true" ]]; then
	  MSYS_NO_PATHCONV=1  aws ${PROFILE} --region ${REGION} iam upload-server-certificate --server-certificate-name ${PID}-cloudfront --path "/cloudfront/${PID}/" --certificate-body file://${PREFIX}crt.pem --private-key file://${PREFIX}prv.pem --certificate-chain file://${PREFIX}chain.pem
	else
	  aws ${PROFILE} --region ${REGION} iam upload-server-certificate --server-certificate-name ${PID}-cloudfront --path "/cloudfront/${PID}/" --certificate-body file://${PREFIX}crt.pem --private-key file://${PREFIX}prv.pem --certificate-chain file://${PREFIX}chain.pem
	fi
  fi
done

# Separate keypair for alpha environment
if [[ -d "${ALPHA_DIR}" ]]; then
  pushd ${ALPHA_DIR} > /dev/null 2>&1
  if [[ (! -e aws-ssh-crt.pem) && (! -e aws-ssh-prv.pem) ]]; then
    openssl genrsa -out aws-ssh-prv.pem 2048
    openssl rsa -in aws-ssh-prv.pem -pubout > aws-ssh-crt.pem
  fi

  # Upload the alpha environment specific keypair
  if [[ -e aws-ssh-crt.pem ]]; then
	aws ${PROFILE} --region ${REGION} ec2 describe-key-pairs --key-name "${PID}-alpha" > /dev/null 2>&1
    if [[ "$?" -ne 0 ]]; then 
      CRT=$(cat aws-ssh-crt.pem | awk 'BEGIN {RS="\r\n?|\n"} /^[^-]/ {printf $1}')
      aws ${PROFILE} --region ${REGION} ec2 import-key-pair --key-name "${PID}-alpha" --public-key-material $CRT
    fi
  fi
  popd > /dev/null 2>&1
fi

# Commit the results
git add ${PROJECT_DIR}
git commit -m "Configure project ${PID} credentials"

