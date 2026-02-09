ARG RUNTIME=hackmdio/runtime:16.20.2-35fe7e39
ARG BUILDPACK=hackmdio/buildpack:16.20.2-35fe7e39

FROM $BUILDPACK AS build

COPY --chown=hackmd:hackmd . .
ENV QT_QPA_PLATFORM=offscreen

USER hackmd
RUN set -xe && \
    git reset --hard && \
    git clean -fx && \
    npm install && \
    npm run build && \
    cp ./deployments/docker-entrypoint.sh ./ && \
    cp .sequelizerc.example .sequelizerc && \
    rm -rf .git .gitignore .travis.yml .dockerignore .editorconfig .babelrc .mailmap .sequelizerc.example \
        test docs contribute \
        package-lock.json webpack.prod.js webpack.htmlexport.js webpack.dev.js webpack.common.js \
        config.json.example README.md CONTRIBUTING.md AUTHORS node_modules

FROM $RUNTIME
USER root
RUN set -eux; \
    rm -f /etc/apt/sources.list.d/*.list; \
    echo "deb http://archive.debian.org/debian buster main" > /etc/apt/sources.list; \
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        cron \
        ldap-utils; \
    rm -rf /var/lib/apt/lists/*
COPY --from=build /home/hackmd/app/deployments/Cronjob /etc/cron.d/checkusers
RUN chmod +x /etc/cron.d/checkusers
RUN touch /var/log/cron.log
RUN chmod u+s /usr/sbin/cron
#RUN env > /etc/environment
RUN crontab /etc/cron.d/checkusers
#RUN cron
USER hackmd
ENV QT_QPA_PLATFORM=offscreen
WORKDIR /home/hackmd/app
COPY --chown=1500:1500 --from=BUILD /home/hackmd/app .
RUN npm install --production && npm cache clean --force && rm -rf /tmp/{core-js-banners,phantomjs}
EXPOSE 80
ENTRYPOINT ["/home/hackmd/app/docker-entrypoint.sh"]
