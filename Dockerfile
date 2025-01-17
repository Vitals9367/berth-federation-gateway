# ===============================================
FROM helsinkitest/node:14-slim as appbase
# ===============================================

# Offical image has npm log verbosity as info. More info - https://github.com/nodejs/docker-node#verbosity
ENV NPM_CONFIG_LOGLEVEL warn

ARG DEBUG
ENV DEBUG $DEBUG

# Register args for API links
ARG OPEN_CITY_PROFILE_API_URL
ENV OPEN_CITY_PROFILE_API_URL $OPEN_CITY_PROFILE_API_URL
ARG BERTH_RESERVATIONS_API_URL
ENV BERTH_RESERVATIONS_API_URL $BERTH_RESERVATIONS_API_URL

# header size issue
ENV NODE_OPTIONS=--max-http-header-size=16384

# Global npm deps in a non-root user directory
ENV NPM_CONFIG_PREFIX=/app/.npm-global
ENV PATH=$PATH:/app/.npm-global/bin

ENV YARN_VERSION 1.19.1
RUN yarn policies set-version $YARN_VERSION

COPY --chown=appuser:appuser docker-entrypoint.sh /entrypoint/docker-entrypoint.sh
ENTRYPOINT ["/entrypoint/docker-entrypoint.sh"]

# Use non-root user
USER appuser

# =============================
FROM appbase as development_base
# =============================

# Set node environment to development to install all npm dependencies
ENV NODE_ENV=development

# Copy package.json and package-lock.json/yarn.lock files
COPY --chown=appuser:appuser package*.json *yarn* ./

# Install npm depepndencies
ENV PATH /app/node_modules/.bin:$PATH

USER root
RUN apt-install.sh build-essential

USER appuser
RUN yarn && yarn cache clean --force

USER root
RUN apt-cleanup.sh build-essential

COPY --chown=appuser:appuser . /app/.

USER appuser

# =============================
FROM development_base as development
# =============================

# Bake package.json start command into the image
CMD ["npm", "start"]

# =============================
FROM development_base as transpiler
# =============================

# Transpile Typescript into Javascript
RUN npm run transpile

# =============================
FROM appbase as production
# =============================

# Copy the transpiled source files to this image
COPY --from=transpiler --chown=appuser:appuser /app/dist /app/dist

# Set node environment to production to install only main dependencies
ARG NODE_ENV=production
ENV NODE_ENV $NODE_ENV

COPY --chown=appuser:appuser package*.json *yarn* ./

# Install npm depepndencies
ENV PATH /app/node_modules/.bin:$PATH

USER root
RUN apt-install.sh build-essential

USER appuser
RUN yarn && yarn cache clean --force

USER root
RUN apt-cleanup.sh build-essential

USER appuser

EXPOSE 3000/tcp

# Bake package.json serve command into the image
CMD ["npm", "run", "serve"]
