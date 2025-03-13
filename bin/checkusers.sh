#!/usr/bin/env bash
isActive() {
  value=$(ldapsearch -x -H $CMD_LDAP_URL -D "$CMD_LDAP_BINDDN" -w $CMD_LDAP_BINDCREDENTIALS -b $CMD_LDAP_SEARCHBASE $search)
  if echo $value | grep -q "ISACTIVE"; then
    return 0
  else
    return 1
  fi
}

res=$(psql $CMD_DB_URL -t -c 'SELECT profileid FROM "Users";')
while IFS=' ' read -r word; do
  uid=$(echo $word | cut -d '-' -f2)
  search=$(echo $CMD_LDAP_SEARCHFILTER | sed "s#{{username}}#${uid}#")
  if isActive; then
    echo "The account is active"
  else
    echo "The account must be destroyed"
  fi
done <<< "$res"
