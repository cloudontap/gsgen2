#!/bin/bash

function usage() {
  echo -e "\nCreate the configuration directory structure for a project" 
  echo -e "\nUsage: $(basename $0) -a OAID -t TITLE -p PID -r REGION -s SOLUTION -l ALPHASOLUTION"
  echo -e "\nwhere\n"
  echo -e "(m) -a OAID is the organisation account id e.g. \"env01\""
  echo -e "    -h shows this text"
  echo -e "(o) -l ALPHASOLUTION is the solution template used for prototyping"
  echo -e "(m) -p PID is the project id for the project e.g. \"eticket\""
  echo -e "(o) -r REGION is the AWS region identifier where project resources will be created"
  echo -e "(o) -s SOLUTION is the target solution template for the project"
  echo -e "(m) -t TITLE is the title for the project e.g. \"Parks E-Ticketing\""
  echo -e "\nNOTES:\n"
  echo -e "1) The project directory tree will be created and populated"
  echo -e "2) If the project directory already exists, no action is performed"
  echo -e "3) The OAID is only used to ensure we are in the correct directory tree"
  echo -e "4) If a region is not provided, the organisation account region will be used"
  echo -e "5) The ALPHASOLUTION template overrides the SOLUTION template in the alpha environment"
  echo -e "6) If ALPHASOLUTION is not provided, a default alpha solution is provided, which"
  echo -e "   provides a basic VPC with a publically accessible subnet" 
  echo -e ""
  exit 1
}

# Parse options
while getopts ":a:hl:p:r:s:t:" opt; do
  case $opt in
    a)
      OAID=$OPTARG
      ;;
    h)
      usage
      ;;
    l)
      ALPHASOLUTION=$OPTARG
      ;;
    p)
      PID=$OPTARG
      ;;
    r)
      REGION=$OPTARG
      ;;
    s)
      SOLUTION=$OPTARG
      ;;
    t)
      PRJ=$OPTARG
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
if [[ "${OAID}" == "" ||
      "${PRJ}"  == "" ||
      "${PID}"  == "" ]]; then
  echo -e "\nInsufficient arguments"
  usage
fi

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ROOT="$(basename $(cd $BIN/../..;pwd))"
ROOT_DIR="$(cd $BIN/../..;pwd)"
SOLUTIONS_DIR="${ROOT_DIR}/config/solutions"
PROJECT_DIR="${SOLUTIONS_DIR}/${PID}"
ALPHA_DIR="${PROJECT_DIR}/alpha"

if [[ "${OAID}" != "${ROOT}" ]]; then
    echo -e "\nThe provided OAID (${OAID}) doesn't match the root directory (${ROOT}). Nothing to do."
    usage
fi

if [[ -d ${PROJECT_DIR} ]]; then
    echo -e "\nLooks like the project directory tree already exists. Nothing to do."
    usage
fi

# Create the project
if [[ ! -e ${PROJECT_DIR} ]]; then
	mkdir ${PROJECT_DIR}
fi

cp -rp ${BIN}/patterns/configuration/project/* ${PROJECT_DIR} 

# Generate the project profile
TEMPLATE="project.ftl"
TEMPLATEDIR="${BIN}/templates"
OUTPUT="${PROJECT_DIR}/project.json"

ARGS="-v \"project=${PRJ}\""
ARGS="${ARGS} -v id=${PID}"
ARGS="${ARGS} -v name=${PID}"

CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
eval $CMD

if [[ "${REGION}" != "" ]]; then
  ARGS="-v region=${REGION}"
fi

# Generate the target solution template
SOLUTIONDIR="${BIN}/patterns/solutions/${SOLUTION}"

if [[ ("${SOLUTION}" != "") && (-d "${SOLUTIONDIR}") ]]; then

  for f in ${SOLUTIONDIR}/*; do
  	NAME=$(basename $f)
	case $NAME in 
	  solution.ftl)
		TEMPLATEDIR="${SOLUTIONDIR}/"
		TEMPLATE="$NAME"
		OUTPUT="${PROJECT_DIR}/solution.json"
	
		CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
		eval $CMD
		;;
	  
	  *)
		cp -p $f .
		;;
    esac
  done
fi

# Generate the alpha solution template
SOLUTIONDIR="${BIN}/patterns/solutions/${ALPHASOLUTION}"

if [[ ("${ALPHASOLUTION}" == "") || (! -d "${SOLUTIONDIR}") ]]; then
  SOLUTIONDIR="${BIN}/patterns/solutions/alpha"
fi

for f in ${SOLUTIONDIR}/*; do
  NAME=$(basename $f)
  case $NAME in 
	solution.ftl)
	  TEMPLATEDIR="${SOLUTIONDIR}/"
	  TEMPLATE="$NAME"
	  OUTPUT="${ALPHA_DIR}/solution.json"
	
	  CMD="${BIN}/gsgen.sh -t $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $ARGS"
	  eval $CMD
	  ;;
	  
	*)
	  cp -p $f ${ALPHA_DIR}
	  ;;
  esac
done

# Commit the results
cd ${PROJECT_DIR}
git add *
git commit -m "Configure project ${PID} solution"

