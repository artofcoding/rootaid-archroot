#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

node_uris=("amqp://rabbitmq1:5672" "amqp://rabbitmq2:5673" "amqp://rabbitmq3:5674")
my_name="$(hostname -s)"

for n in ${#node_uris[@]}
do
    other_node="${node_uris[$n]}"
    if [[ ${my_name} != ${other_node} ]]
    then
        echo "${my_name}: Adding federation upstream ${other_node}"
        rabbitmqctl set_parameter federation-upstream "rabbitmq-shard${n}" '{"uri":"${other_node}"}'
    fi
done
rabbitmqctl set_policy --apply-to exchanges federate-me "^amq\." '{"federation-upstream-set":"all"}'

exit 0
