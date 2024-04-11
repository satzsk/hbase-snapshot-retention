#!/bin/bash
#this script sets retention of snapshot at cluster

RETENTION=${1:-7}
DELETE=$2
log_date="date +%d-%m-%Y:%H:%M:%S"


if [[ -z $1 ]] ; then
   echo "usage
         ./snapshot_retention.sh <retention_days default is 7 days> 
         use -d to perform delete , if not its considered as dryrun
         "
   exit 1
fi

CURRENT_DATE=$(date +'%Y%m%d')
RETENTION_DATE=$(date -d "now -$RETENTION days" +%Y%m%d)

function get_snapshots {
    snapshots=$(echo "list_snapshots" | hbase shell -n 2>/dev/null | sed -e '/row/q' -e '/SNAPSHOT/d' | grep -v row)
    echo $snapshots
}

function delete_snapshot {
    if [[ $DELETE != "-d" ]]; then 
      echo "$($log_date) : No delete option provided , this is a DRYRUN
      To delete use -d option"
    fi
    snaps=$1
    echo "$($log_date) : Current date $CURRENT_DATE"
    echo "$($log_date) : Retention date $RETENTION_DATE"

    declare -A arr
    snap_names=$(echo $snaps | sed -e 's/) /\n/g' | tr -d '(|)' | awk '{print $1}')
    for i in $snap_names; do
       arr+=( ["$i"]=$(echo $snaps| sed -e 's/) /\n/g' | tr -d '(|)' | grep $i | awk '{print $(NF-5),$(NF-4),$(NF-3),$(NF-2),$NF}' |  xargs -I {} date -d {} +'%Y%m%d') )
    done

    for key in ${!arr[@]}; do
     snap_date=${arr[${key}]}
     if [[ $snap_date -lt $RETENTION_DATE ]]; then
       if [[ $DELETE != "-d" ]]; then  
          echo "$($log_date) : To be deleted ${key} , create_date: $(date -d ${arr[${key}]} +%Y-%m-%d)"
       else
          echo "$($log_date) : Deleting ${key} created_date: $(date -d ${arr[${key}]} +%Y-%m-%d)"
          #command to delete snapshot
          echo "delete_snapshot \"$key\"" | hbase shell -n 2>/dev/null
          if (( $? == 0 )); then
            echo "$($log_date) : Successfully deleted ${key}"
          else
            echo "$($log_date) : ERROR !!! Cleanup Failed"
          fi
       fi
     else
        echo "  $($log_date) : Skip delete ${key} created_date $(date -d ${arr[${key}]} +%Y-%m-%d)"
    fi
     done

}

echo "$($log_date) : Get the snapshot list"
snaps=$(get_snapshots)
delete_snapshot "${snaps[@]}"
echo "$($log_date) : Run completed."