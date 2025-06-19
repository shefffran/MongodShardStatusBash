#!/bin/bash

#Your api key
api_key=""

#Java script to collec shard data
output=$(mongosh --quiet --host localhost --port 27017 --eval '
const printedMembers = new Set();
const shards = db.adminCommand({ listShards: 1 }).shards;

shards.forEach(shard => {
    const host = shard.host.split("/")[1].split(",")[0];
    const rsStatus = new Mongo(host).getDB("admin").runCommand({ replSetGetStatus: 1 });

    rsStatus.members.forEach(member => {
        if (!printedMembers.has(member.name)) {
            print(`${member.name} | State: ${member.stateStr}`);
            printedMembers.add(member.name);
        }
    });
});
')

#Which states are ok
normal_state_array=("PRIMARY" "SECONDARY" "ARBITER")

#Lopp to check all shard states
while IFS= read -r line; do
  found=false
  state=$(echo -e "$line" | awk -F'State: ' '{print $2}')
  member=$(echo -e "$line" | awk -F':' '{print $1}')

  for item in "${normal_state_array[@]}"; do
      if [[ "$state" == "$item" ]];
      then
          found=true
          break
      fi
  done
    if [[ "$found" == true ]]; then
        echo -e "status=ok member=$member state=$state"
        metric_value=1
  else
        echo -e "status=not_ok member=$member state=$state"
        metric_value=0
  fi

#Datadog push
curl -s -X POST "https://api.datadoghq.com/api/v1/series?api_key=$api_key" \
-H "Content-Type: application/json" \
-d '{
  "series": [{
    "metric": "mongo.replica.status",
    "points": [[$(date +%s), '"$metric_value"']],
    "type": "gauge",
    "host": "'"$(hostname)"'",
    "tags": ["member:'$member'", "state:'$value1'"]
  }]
}'
echo " "
done <<< "$output"
