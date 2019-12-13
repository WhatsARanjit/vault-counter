FROM everpeace/curl-jq:latest

ARG VAULT_ADDR
ENV VAULT_ADDR=${VAULT_ADDR:-http://127.0.0.1:8200}
ARG VAULT_TOKEN
ENV VAULT_TOKEN=${VAULT_TOKEN:-root}

COPY ./scripts/counter.sh /tmp

CMD ["/tmp/counter.sh"]
