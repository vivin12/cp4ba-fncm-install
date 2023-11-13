# Troubleshooting DB2 Bootstrap Scripts (`db2-init.sh`)

This readme contains useful info to help debug [`db2-init.sh`](./db2-init.sh).

- [Troubleshooting DB2 Bootstrap Scripts (`db2-init.sh`)](#troubleshooting-db2-bootstrap-scripts---db2-initsh--)
  * [Common errors](#common-errors)
    + [The script fails to to connect to DB2](#the-script-fails-to-to-connect-to-db2)
    + [`db2-init.sh` runs successfully but you can't see any databases created](#-db2-initsh--runs-successfully-but-you-can-t-see-any-databases-created)
      - [If the script logs return some SQL commands or logging](#if-the-script-logs-return-some-sql-commands-or-logging)
      - [If the script logs return nothing or an error is returned when fetching the logs](#if-the-script-logs-return-nothing-or-an-error-is-returned-when-fetching-the-logs)
      - [If you can see logs returned after cleaning pod processes](#if-you-can-see-logs-returned-after-cleaning-pod-processes)
      - [If you still see an error after cleaning pod processes](#if-you-still-see-an-error-after-cleaning-pod-processes)
      - [Debugging nohup](#debugging-nohup)
  * [Contact](#contact)


## Common errors

### The script fails to to connect to DB2


`db2-init.sh` fails with the following error:

```bash
error: error executing jsonpath "{.items[0].metadata.name}": Error executing template: array index out of bounds: index 0, length 0.
```

or: 

```bash
error: A project named "db2" does not exist on "https://c108-e.eu-gb.containers.cloud.ibm.com:32718".
```

The script is unable to find a pod running DB2, either because the the target project doesn't exist, or because a db2 pod is not running in it. Make sure you have a `DB2uCluster` up and running in namespace set in the following variable in `db2-init.sh`:

```bash
DB2_PROJECT="db2"
```

### `db2-init.sh` runs successfully but you can't see any databases created

Run the following command on your terminal to show script logs:

```
oc exec c-db2-test-db2u-0 -c db2u -- su - db2inst1 -c "tail -f /tmp/filenet-db2-setup.log"
```

And then:

#### If the script logs return some SQL commands or logging

It is likely that [`db2-cmd`](./db2-cmd.sh) is still running. You will know the script is complete when you see the following line in the logs:

```
setup for OS2DB complete
```

#### If the script logs return nothing or an error is returned when fetching the logs

Something likely went wrong when copying the [`db2-cmd.sh`](./db2-cmd.sh) file to the db2 pod.

1. To fix this, open a terminal onto the db2 pod:

```
oc exec -it $(oc get pod -l role=db -ojsonpath='{.items[0].metadata.name}') -- /bin/bash
```

> Make sure you run the command in the project containing db2. If the project containing db2 is named `db2`, run the following:
>```
>oc exec -it $(oc get pod -n db2 -l role=db -ojsonpath='{.items[0].metadata.name}') -- /bin/bash
>```

2. Become the `db2inst1` user on the pod:

```
su db2inst1
```

3. Search for any zombie processes running `db2-cmd.sh`:

```
ps aux | grep db2-cmd.sh
```

If a process is returned by the command, kill the process:

```
kill -9 <pid-of-process>
```

4. Exit out of the pod and back to your terminal.

5. rerun `db2-init.sh`:

```
./db2-init.sh
```


6. Once complete, rerun the log command:

```
oc exec c-db2-test-db2u-0 -c db2u -- su - db2inst1 -c "tail -f /tmp/filenet-db2-setup.log"
```

and then:

#### If you can see logs returned after cleaning pod processes

`db2-cmd.sh` is running successfully. Wait ~15 min for the Database install to complete.

#### If you still see an error after cleaning pod processes

If `db2-init.sh` is still not running the `db2-cmd.sh` scripts, the simplest solution is to copy the file over manually:

1. From this directory, run:

```
oc cp db2-cmd.sh $(oc get pod -l role=db -ojsonpath='{.items[0].metadata.name}'):/tmp/db2-cmd.sh -c db2u
```

> Make sure you run the command in the project containing db2. If the project containing db2 is named `db2`, run the following:
>```
>oc cp db2-cmd.sh $(oc get pod -n db2 -l role=db -ojsonpath='{.items[0].metadata.name}'):/tmp/db2-cmd.sh -c db2u
>```

2. Open a terminal onto the db2 pod:

```
oc exec -it $(oc get pod -l role=db -ojsonpath='{.items[0].metadata.name}') -- /bin/bash
```

> Make sure you run the command in the project containing db2. If the project containing db2 is named `db2`, run the following:
>```
>oc exec -it $(oc get pod -n db2 -l role=db -ojsonpath='{.items[0].metadata.name}') -- /bin/bash
>```

3. Become the `db2inst1` user on the pod:

```
su db2inst1
```

4. Make the script executable:

```
chmod +x /tmp/db2-cmd.sh
```

5. Run the script as a background process:

```
nohup /tmp/db2-cmd.sh &
```

6. Exit out of the pod and back to your terminal and rerun the log command:

```
oc exec c-db2-test-db2u-0 -c db2u -- su - db2inst1 -c "tail -f /tmp/filenet-db2-setup.log"
```

`db2-cmd.sh` should now be running successfully. Wait ~15 min for the Database install to complete.

> If you are still having issues running the script, see the [Debugging nohup](#debugging-nohup) section below

### Debugging nohup

The script now logs out processes running on the pod to see if `nohup` has been called successfully on the pod.

1. The script will log out start time in `/tmp/db2-process-start.log`. Running the following command should return a timestamp:

```
oc exec c-db2-db2u-0 -c db2u -- su - db2inst1 -c "cat /tmp/db2-process-start.log"                            
```
> If you do not see a timestamp returned, it is likely `nohup` was not successfully called on the pod. 

2. The script will log processes running on the pod for ~8 minutes from start time, by running `ps -ef | grep /tmp/db2-init.sh` on the pod. You can view the logs with the following command:

```
oc exec -it c-db2-db2u-0 -c db2u -- su - db2inst1 -c "tail -f /tmp/db2-process.log"
```

If the script is running in the background you should see the following:

```
db2inst1  45058      1  0 11:10 ?        00:00:00 /bin/sh /tmp/db2-cmd.sh
```
> If you do not see a timestamp returned, it is likely `nohup` was not successfully called on the pod. 
