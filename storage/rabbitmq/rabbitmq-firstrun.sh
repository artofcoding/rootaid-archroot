#!/usr/bin/env bash
# Copyright (C) 2020 art of coding UG, Hamburg

set -o nounset
set -o errexit

echo "Waiting for RabbitMQ to come up"
sleep 10

rabbitmqctl add_user federator federator
rabbitmqctl set_user_tags federator administrator
rabbitmqctl set_permissions -p / federator ".*" ".*" ".*"

rabbitmqctl add_user bugs bunny
rabbitmqctl set_permissions -p / bugs ".*" ".*" ".*"

rabbitmqctl list_users

exit 0
