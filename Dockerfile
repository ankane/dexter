FROM ruby:3.1.2-alpine3.15

MAINTAINER Andrew Kane <andrew@ankane.org>

RUN apk add --update build-base libpq-dev && \
    gem install pgdexter && \
    apk del build-base && \
    rm -rf /var/cache/apk/*

ENTRYPOINT ["dexter"]
