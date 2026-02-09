#!/bin/bash
# The script uses Cronjob to run once a day to check for expired users
# It is vital to have RUN env > /etc/environment in Dockerfile so that
# cronjob can have access to env variables from docker
. /home/hackmd/cron.env
UPLOADS_DIR="/home/hackmd/app/public/uploads"
TRASH_DIR="/home/hackmd/trash"

isActive() {
  if ! ldapres=$(ldapsearch -x -H $CMD_LDAP_URL -D "$CMD_LDAP_BINDDN" -w $CMD_LDAP_BINDCREDENTIALS -b $CMD_LDAP_SEARCHBASE $query 2>/dev/null); then
    echo "Ldap is DOWN. Exiting..."
    exit 1
  fi
  if echo "$ldapres" | grep -q -e "^uid:"; then
    return 0
  else
    return 1
  fi
}

deleteUser(){
  # Deleting users from postgres database
  local profileid="$1"
psql $CMD_DB_URL <<-SQL
DELETE FROM "Users" WHERE profileid = '${profileid}';
SQL
}

deleteNotes(){
  # Deleting all user's notes from postgres database and moving them to
  # trash can
shortids=$(psql $CMD_DB_URL -At<<-SQL
SELECT shortid FROM "Notes" where "ownerId" = '${id}';
SQL
)
while IFS=' ' read shortid; do
title=$(psql $CMD_DB_URL -At<<-SQL
SELECT title FROM "Notes" where shortid = '${shortid}';
SQL
)
safe_title=$(echo "$title" | tr -cd '[:alnum:]._-')
filename="${USER_TRASH_DIR}/${safe_title}.md"

content=$(psql $CMD_DB_URL -At<<-SQL
SELECT content FROM "Notes" WHERE shortid = '${shortid}';
SQL
)

echo "$content" > "$filename"
done<<<"$shortids"

psql $CMD_DB_URL <<-SQL
DELETE FROM "Notes" where "ownerId" = '${id}';
SQL
}

deleteFiles(){
  # Deleting all user's uploads from location /home/hackmd/app/public/uploads
  # The files are saved as upload_{user.id}_{random letters}.{jpg,png,...}
  find $UPLOADS_DIR -type f -name "upload_${id}_*" -exec mv {} "$USER_TRASH_DIR" \; 2>&1
}

actuallyDeleteFiles(){
  # Deleting all user's uploads from location /home/hackmd/app/public/uploads
  # The files are saved as upload_{user.id}_{random letters}.{jpg,png,...}

  echo "Removing old trash files"
  find $TRASH_DIR -mindepth 1 -maxdepth 1 -type d -mtime +90 -exec rm -rf {} \; 2>&1
}

# Write down the date-time
date
# Removing old trash files
actuallyDeleteFiles
allusers=$(psql $CMD_DB_URL -t -c 'SELECT profileid FROM "Users";')
if [ -z "$allusers" ]; then
    echo "Ha Ha nothing to delete"
    exit
fi
while IFS=' ' read -r username; do
  # Extracting the username (removing LDAP- prefix)
  uid=$(echo $username | cut -d '-' -f2)
  # Creating the ldap search query
  query=$(echo $CMD_LDAP_SEARCHFILTER | sed "s#{{username}}#${uid}#")
id=$(psql $CMD_DB_URL -t -A <<-SQL
SELECT id FROM "Users" WHERE profileid = '${username}';
SQL
)
  # Check if the user exists in the ldap as active user
  if isActive; then
    echo "The account $uid  is active"
  else
    echo "The account $uid must be destroyed"
    # This will be the user specific trash can
    USER_TRASH_DIR=${TRASH_DIR}/${uid}
    echo "Moving to Trash ${USER_TRASH_DIR}..."
    mkdir -p $USER_TRASH_DIR
    # These functions move uploads and notes to trash can
    # and delete them permanently after 90 days
    deleteUser $username
    deleteNotes
    deleteFiles

  fi
done <<< "$allusers"
