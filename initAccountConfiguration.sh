#!/bin/bash

# Defaults
ALMSIZE_DEFAULT="small"
ALMTYPE_DEFAULT="external"
OAINDEX_DEFAULT="01"
OANAME_DEFAULT="Development"
REGION_DEFAULT="ap-southeast-2"
REGION_DEFAULT_NAME="Sydney"
SESREGION_DEFAULT="us-west-2"
SESREGION_DEFAULT_NAME="Oregon"

function usage() {
  echo -e "\nInitialise the organisation/account/ALM level configuration information"
  echo -e "\nUsage: $(basename $0) -t TITLE -n NAME -o OID -i OAINDEX -d DESCRIPTION -m OANAME -r REGION -e SESREGION -y ALMTYPE -s ALMSIZE"
  echo -e "\nwhere\n"
  echo -e "(o) -d DESCRIPTION is general information about the organisation"
  echo -e "(o) -e SESREGION is the AWS region identifier for the region via which emails will be sent"
  echo -e "    -h shows this text"
  echo -e "(o) -i OAINDEX is the 2 digit organisation account e.g. \"01\", \"02\""
  echo -e "(o) -m OANAME is short form (one word and no spaces) of the account title. The account title is the concatenation of TITLE, OANAME and \"Account\""
  echo -e "(m) -n NAME is the short form (one word, lowercase and no spaces) of the organisation title e.g. \"environment\""
  echo -e "(m) -o OID is the organisation id e.g. \"env\""
  echo -e "(o) -r REGION is the AWS region identifier for the region in which the account will be created"
  echo -e "(o) -s ALMSIZE is the sizing required for the ALM"
  echo -e "       - micro"
  echo -e "       - small"
  echo -e "       - medium"
  echo -e "(m) -t TITLE is the organisation title e.g. \"Department of Environment\""
  echo -e "(o) -y ALMTYPE is the arrangement required for the ALM"
  echo -e "       - nat      - if you want a NAT based ALM container"
  echo -e "       - external - if you want an externally exposed ALM server"
  echo -e "\nDEFAULTS:\n"
  echo -e "OAINDEX   = \"${OAINDEX_DEFAULT}\""
  echo -e "OANAME    = \"${OANAME_DEFAULT}\""
  echo -e "REGION    = \"${REGION_DEFAULT}\" (${REGION_DEFAULT_NAME})"
  echo -e "SESREGION = \"${SESREGION_DEFAULT}\" (${SESREGION_DEFAULT_NAME})"
  echo -e "ALMSIZE   = \"${ALMSIZE_DEFAULT}\""
  echo -e "ALMTYPE   = \"${ALMTYPE_DEFAULT}\""
  echo -e "\nNOTES:\n"
  echo -e "1) The organisation account id (OAID) is formed by concatenating the OID and the OAINDEX"
  echo -e "2) The OAID needs to match the root of the directory structure"
  echo -e ""
  exit 1
}

ALMSIZE="${ALMSIZE_DEFAULT}"
ALMTYPE="${ALMTYPE_DEFAULT}"
OAINDEX="${OAINDEX_DEFAULT}"
OANAME="${OANAME_DEFAULT}"
REGION="${REGION_DEFAULT}"
SESREGION="${SESREGION_DEFAULT}"

# Parse options
while getopts ":d:e:hi:m:n:o:r:s:t:y:" opt; do
  case $opt in
    d)
      DESCRIPTION=$OPTARG
      ;;
    e)
      SESREGION=$OPTARG
      ;;
    h)
      usage
      ;;
    i)
      OAINDEX=$OPTARG
      ;;
    m)
      OANAME=$OPTARG
       ;;
    n)
      NAME=$OPTARG
       ;;
    o)
      OID=$OPTARG
      ;;
    r)
      REGION=$OPTARG
      ;;
    s)
      ALMSIZE=$OPTARG
      ;;
    t)
      TITLE=$OPTARG
       ;;
    y)
      ALMTYPE=$OPTARG
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
if [[ "${TITLE}"  == "" || 
      "${NAME}"  == "" ||
      "${OID}"  == "" ||
      "${OAINDEX}" == "" ]]; then
  echo -e "\nInsufficient arguments"
  usage
fi

OAID="${OID}${OAINDEX}"

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ROOT="$(basename $(cd $BIN/../..;pwd))"
ROOT_DIR="$(cd $BIN/../..;pwd)"
SOLUTIONS_DIR="${ROOT_DIR}/config/solutions"
PROJECT_DIR="${SOLUTIONS_DIR}/${OAID}"
ALM_DIR="${PROJECT_DIR}/alm"

if [[ "${OAID}" != "${ROOT}" ]]; then
    echo -e "\nThe provided OAID (${OAID}) doesn't match the root directory (${ROOT}). Nothing to do."
    usage
fi

# Generate the organisation profile
TEMPLATE="organisation.ftl"
TEMPLATEDIR="${BIN}/templates"
OUTPUT="${SOLUTIONS_DIR}/organisation.json"

ARGS="-v \"organisation=${TITLE}\""
ARGS="${ARGS} -v id=${OID}"
ARGS="${ARGS} -v name=${NAME}"
if [[ "${DESCRIPTION}" != "" ]]; then
  ARGS="$ARGS -v \"description=${DESCRIPTION}\""
fi
CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
eval $CMD

# Generate the account profile
TEMPLATE="account.ftl"
TEMPLATEDIR="${BIN}/templates"
OUTPUT="${SOLUTIONS_DIR}/account.json"

ARGS="-v \"account=${TITLE} ${OANAME} Account\""
ARGS="${ARGS} -v id=${OAID}"
ARGS="${ARGS} -v name=${OANAME}"
ARGS="${ARGS} -v region=${REGION}"
ARGS="${ARGS} -v sesRegion=${SESREGION}"

CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
eval $CMD

# Create the "account" project
if [[ ! -e ${PROJECT_DIR} ]]; then
	mkdir ${PROJECT_DIR}
fi

# Add any standard files
cp -rp ${BIN}/patterns/configuration/account/* ${PROJECT_DIR}

# Generate the ALM project profile
TEMPLATE="project.ftl"
TEMPLATEDIR="${BIN}/templates"
OUTPUT="${PROJECT_DIR}/project.json"

ARGS="-v \"project=${TITLE} Application LifeCycle Management (ALM) System\""
ARGS="${ARGS} -v id=${OAID}"
ARGS="${ARGS} -v name=${OAID}"

CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
eval $CMD

if [[ "${ALMTYPE}" == "nat" ]]; then
	mv ${PROJECT_DIR}/solution-nat.json ${PROJECT_DIR}/solution.json
else
	mv ${PROJECT_DIR}/solution-external.json ${PROJECT_DIR}/solution.json
fi
rm ${PROJECT_DIR}/solution-*.json

if [[ -e "${ALM_DIR}/container-${ALMSIZE}.json" ]]; then
	mv ${ALM_DIR}/container-${ALMSIZE}.json ${ALM_DIR}/container.json
else
	mv ${ALM_DIR}/container-micro.json ${ALM_DIR}/container.json
fi
rm ${ALM_DIR}/container-*.json

cd ${SOLUTIONS_DIR}

# Remove the placeholder file
if [[ -e .placeholder ]]; then
	git rm .placeholder
fi

# Commit the results
git add *
git commit -m "Configure organisation/account information. Configure ALM solution"

