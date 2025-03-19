#!/usr/bin/env bash
isActive() {
  if ldapsearch -x -H $CMD_LDAP_URL -D "$CMD_LDAP_BINDDN" -w $CMD_LDAP_BINDCREDENTIALS -b $CMD_LDAP_SEARCHBASE $search | grep -q -e "^uid:"; then
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
    /home/hackmd/app/bin/manage_users --del $uid
    /home/hackmd/app/bin/manage_users --delOrphan $uid
  fi
done <<< "$res"
