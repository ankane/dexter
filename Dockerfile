FROM ruby:2.7.2-alpine3.12

MAINTAINER Andrew Kane <andrew@chartkick.com>

RUN apk add --update ruby-dev build-base \
  libxml2-dev libxslt-dev pcre-dev libffi-dev \
  postgresql-dev

RUN gem install pgdexter

ENTRYPOINT ["dexter"]
