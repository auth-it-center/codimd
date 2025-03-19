ARG RUNTIME
ARG BUILDPACK

FROM $BUILDPACK AS BUILD

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
        
FROM node:16.20.2 AS cron
USER 0
RUN apt-get update && \
    apt-get install -y cron ldap-utils


FROM $RUNTIME
USER root
RUN apt update && apt install -y vim 
COPY --from=BUILD /home/hackmd/app/deployments/Cronjob /etc/cron.d/checkusers
COPY --from=cron /usr/sbin/cron /usr/sbin/cron
COPY --from=cron /usr/bin/crontab /usr/bin/crontab
COPY --from=cron /usr/bin/ldapsearch /usr/bin/ldapsearch
RUN chmod +x /etc/cron.d/checkusers
RUN touch /var/log/cron.log
RUN crontab /etc/cron.d/checkusers
RUN cron
USER hackmd
ENV QT_QPA_PLATFORM=offscreen
WORKDIR /home/hackmd/app
COPY --chown=1500:1500 --from=BUILD /home/hackmd/app .
RUN npm install --production && npm cache clean --force && rm -rf /tmp/{core-js-banners,phantomjs}
EXPOSE 3000
ENTRYPOINT ["/home/hackmd/app/docker-entrypoint.sh"]
