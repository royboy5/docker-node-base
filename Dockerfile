## (Stage: base)
# Installs prod dependencies
FROM node:12.14.1-alpine3.10 as base

# add tini package
RUN apk add --no-cache tini

WORKDIR /app

COPY package*.json ./

RUN npm config list && \
    npm install --only=production && \
    npm cache clean --force

# Removes TLS check because of self signed certs
ENV NODE_TLS_REJECT_UNAUTHORIZED=0

# Sets PATH to use installed node_modules
ENV PATH=/app/node_modules/.bin:$PATH

## (Stage: development)
# Used for local development via docker-compose
FROM base as dev

EXPOSE 5000

ENV NODE_ENV=development

WORKDIR /app

RUN npm install --only=development

WORKDIR /app/<<<APP NAME>>>

CMD ["nodemon", "--inspect=0.0.0.0:9229"]

## (Stage: source)
# This gets our source code into the builder for use in next two stages
# It gets its own stage so we don't have to copy twice
FROM base as source

WORKDIR /app/<<<APP NAME>>>

COPY . .

## (Stage: testing)
# use this in automatec CI
# it has prod and dev dependencies
FROM source as test

ENV NODE_ENV=development

# this copies all dependencies (prod+dev)
COP --from=dev /app/node_modules /app/node_modules

# run linters as part of build
RUN npm run lint

# run unit test as part of build
CMD ["npm", "run", "test"]

## (stage default i.e. production)
# this will run by default if you don't include a target
# it has prod-only dependencies
FROM source as prod

# add openssl package
RUN apk add --update openssl && \
    rm -rf /var/cache/apk/*

# create director for SSL
RUN mkdir -p /app/tls/private && \
    mkdir -p /app/tls/certs && \
    chown -R node:node /home/app/tls

# create SSL cert
RUN openssl \
    req \
    -newkey \
    rsa: 4096 \
    -x509 \
    -nodes \
    -days 365 \
    -subj "/C=US/ST=NY/L=New York/O=Computers/CN=<<<APP NAME>>>" \
    -keyout /app/tls/private/cert.key \
    -out /app/tls/certs/cert.crt

EXPOSE 8443

ENV NODE_ENV=production

WORKDIR /app/<<<APP NAME>>>

RUN npm run prod:build

ENTRYPOINT ["/sbin/tini", "--"]

CMD ["node", "dist/"]
