FROM alpine:3.8

RUN apk add --no-cache \
          bash \
          ca-certificates \
          curl \
          jq

COPY entrypoint.sh /usr/bin/container_entrypoint

CMD /usr/bin/container_entrypoint
