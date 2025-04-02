#!/bin/bash
# The script uses Cronjob to run once a day to check for expired users
# It is vital to have RUN env > /etc/environment in Dockerfile so that
# cronjob can have access to env variables from docker
isActive() {
  if ldapres=$(ldapsearch -x -H $CMD_LDAP_URL -D "$CMD_LDAP_BINDDN" -w $CMD_LDAP_BINDCREDENTIALS -b $CMD_LDAP_SEARCHBASE $query 2>/dev/null); then
    echo "Ldap is UP. Continue..."
  else
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
  # Deleting all user's notes from postgres database
  local id="$1"
psql $CMD_DB_URL <<-SQL
DELETE FROM "Notes" where "ownerId" = '${id}';
SQL
}
deleteFiles(){
  # Deleting all user's uploads from location /home/hackmd/app/public/uploads
  local id="$1"
  # The files are saved as upload_{user.id}_{random letters}.{jpg,png,...}
  find /home/hackmd/app/public/uploads -type f -name "upload_${id}_*" -delete; 2>&1
}
# Write down the date-time
date
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
    echo "Beggining destruction..."
    deleteUser $username
    deleteNotes $id
    deleteFiles $id

  fi
done <<< "$allusers"
