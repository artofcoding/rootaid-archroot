ARG RABBITMQ_RELEASE
FROM rabbitmq:${RABBITMQ_RELEASE} AS base

#RUN rabbitmq-plugins enable --offline rabbitmq_mqtt
#RUN rabbitmq-plugins enable --offline rabbitmq_stomp
RUN rabbitmq-plugins enable --offline rabbitmq_federation
RUN rabbitmq-plugins enable --offline rabbitmq_federation_management

FROM base
ADD rabbitmq.conf /etc/rabbitmq.conf.disabled
ADD rabbitmq-firstrun.sh /usr/local/bin
RUN chmod +x /usr/local/bin

VOLUME ["/var/lib/rabbitmq"]
