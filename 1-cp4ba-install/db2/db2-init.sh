#!/bin/bash

set -eo pipefail

DB2_PROJECT="db2"
DB2_COMMANDS_FILENAME=db2-cmd.sh
DB2_COMMANDS_PATH=${BASH_SOURCE%/*}/$DB2_COMMANDS_FILENAME

# Add err trap to help debug any issues
trap 'catcherr $? $LINENO' ERR

# catcherr() prints out the error code and line of any error while running the script
catcherr() {
  echo "ERROR db2-init.sh failed! Info:"
  if [ "$1" != "0" ]; then
    echo "Error $1 on line: $2"
  fi
}

# simple check to test we can find the db2-cmd.sh, if not we fail
# TODO: actually check the contents of the file are what we expect
if [ -f "$DB2_COMMANDS_PATH" ]; then
    echo "Initialising DB2 databases with $DB2_COMMANDS_FILENAME file."
else
  echo "Cannot find db2-cmd.sh file in directory: ${BASH_SOURCE%/*} ! Aborting..." && exit 1
fi

echo "setting project to $DB2_PROJECT" && echo
oc project $DB2_PROJECT

echo "Identifying DB2 pod" && echo
DB2_POD_NAME="$(oc get pod -l role=db -ojsonpath='{.items[0].metadata.name}')"

echo "Listing current databases on pod $DB2_POD_NAME" && echo
oc exec $DB2_POD_NAME -c db2u -- su - db2inst1 -c "db2 list database directory"

echo "Starting database creation on pod $DB2_POD_NAME" && echo

oc cp $DB2_COMMANDS_PATH $DB2_POD_NAME:/tmp/$DB2_COMMANDS_FILENAME -c db2u

# second simple check that the file has made it across to the pod successfully. If we cannot find it, we cannot continue (grep will fail)
# TODO: actually check the contents of the file are what we expect
oc exec $DB2_POD_NAME -it -c db2u -- ls /tmp | grep -q "$DB2_COMMANDS_FILENAME"

oc exec $DB2_POD_NAME -it -c db2u -- chmod +x tmp/$DB2_COMMANDS_FILENAME

# Logging out the processes to observe potential bugs or errors when calling nohup on the pod
oc exec $DB2_POD_NAME -it -c db2u -- su - db2inst1 -c 'nohup sh -c "for ((i=1;i<=1000;i++)); do ps -ef | grep /tmp/db2-cmd.sh >> /tmp/db2-process.log; done" &'

oc exec $DB2_POD_NAME -it -c db2u -- su - db2inst1 -c "nohup date >> /tmp/db2-process-start.log && /tmp/$DB2_COMMANDS_FILENAME &"

echo "Database setup in progress" && echo
echo "To view the log, run:"
echo "oc exec $DB2_POD_NAME -c db2u -- su - db2inst1 -c \"tail -f /tmp/filenet-db2-setup.log\""
echo "To list the databases, run:"
echo "oc exec $DB2_POD_NAME -c db2u -- su - db2inst1 -c \"db2 list database directory\""
