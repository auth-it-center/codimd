#!/usr/bin/env bash

cron
set -euo pipefail

if [[ "$#" -gt 0 ]]; then
    exec "$@"
    exit $?
fi
# We pass the values to file so that cron script can use them
env | sed "s/=\(.*\)/='\1'/" > /home/hackmd/cron.env
# check database and redis is ready
pcheck -env CMD_DB_URL

# run DB migrate
NEED_MIGRATE=${CMD_AUTO_MIGRATE:=true}

if [[ "$NEED_MIGRATE" = "true" ]] && [[ -f .sequelizerc ]] ; then
    npx sequelize db:migrate
fi

# start application
node app.js
