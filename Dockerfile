FROM node:lts as base
ENV NPM_CONFIG_LOGLEVEL=warn
ENV NPM_CONFIG_COLOR=false
WORKDIR /home/node/app
COPY --chown=node:node . /home/node/app/

FROM base as development
WORKDIR /home/node/app
RUN npm install

FROM base as production
WORKDIR /home/node/app
COPY --chown=node:node --from=development /home/node/app/node_modules /home/node/app/node_modules
RUN npm run build

FROM nginx:stable-alpine as deploy
WORKDIR /home/node/app
COPY --chown=node:node --from=production /home/node/app/build /usr/share/nginx/html/