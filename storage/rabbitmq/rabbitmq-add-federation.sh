#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

domain="$(hostname -d)"
domain="${domain##shard?.}"
#"rabbitmq.shard3.${domain}"
node_uris=("rabbitmq.shard1.${domain}" "rabbitmq.shard2.${domain}")
my_name="$(hostname -f)"

last_idx=$((${#node_uris[@]} - 1))
for n in $(seq 0 ${last_idx})
do
    other_node="${node_uris[$n]}"
    if [[ ${my_name} != ${other_node} ]]
    then
        rabbitmqctl set_parameter federation-upstream "rabbitmq-shard$((${n} + 1))" "{\"uri\":\"amqps://${other_node}:5671\"}"
    fi
done
#rabbitmqctl set_policy --priority 10 --apply-to exchanges federate-amq "^amq\." '{"federation-upstream-set":"all"}'
rabbitmqctl set_policy --priority 10 --apply-to exchanges federate-hbd-exchanges "^hbd\.fed\." '{"federation-upstream-set":"all"}'
#rabbitmqctl set_policy --priority 10 --apply-to queues federate-hbd-queue "^hbd\." '{"federation-upstream-set":"all"}'

exit 0
