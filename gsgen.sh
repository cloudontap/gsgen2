#!/bin/bash

function usage() {
  echo -e "\nGenerate a document using the Freemarker template engine" 
  echo -e "\nUsage: $(basename $0) -t TEMPLATE -d TEMPLATEDIR -o OUTPUT (-v VARIABLE=VALUE)*"
  echo -e "\nwhere\n"
  echo -e "(m) -d TEMPLATEDIR is the directory containing the template"
  echo -e "    -h shows this text"
  echo -e "(m) -o OUTPUT is the path of the resulting document"
  echo -e "(m) -t TEMPLATE is the filename of the Freemarker template to use"
  echo -e "(o) -v VARIABLE=VALUE (o) defines a variable and corresponding value to be made available in the template"
  echo -e "\nNOTES:\n"
  echo -e "1) If the value of a variable defines a path to an existing file, the contents of the file are provided to the engine"
  echo -e "2) Values that do not correspond to existing files are provided as is to the engine"
  echo -e "3) Values containing spaces need to be quoted to ensure they are passed in as a single argument"
  echo -e ""
  exit 1
}

VARIABLES=""

# Parse options
while getopts ":d:ho:t:v:" opt; do
  case $opt in
    d)
      TEMPLATEDIR=$OPTARG
      ;;
    h)
      usage
      ;;
    o)
      OUTPUT=$OPTARG
      ;;
    t)
      TEMPLATE=$OPTARG
      ;;
    v)
      VARIABLES="${VARIABLES} \"${OPTARG}\""
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
if [[ "${TEMPLATE}"    == "" || 
      "${TEMPLATEDIR}" == "" ||
      "${OUTPUT}"      == "" ]]; then
  echo -e "\nInsufficient arguments"
  usage
fi

BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ "${VARIABLES}" != "" ]]; then
  VARIABLEARG="-v ${VARIABLES}"
fi

CMD="java -jar "$BIN/gsgen.jar" -i $TEMPLATE -d $TEMPLATEDIR -o $OUTPUT $VARIABLEARG"
eval $CMD

exit $?
