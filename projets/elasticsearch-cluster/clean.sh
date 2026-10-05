#!/bin/bash

echo "=== CLEANING ALL ! ==="
ansible elasticsearch -i inventory/prod/hosts.ini \
  -m ansible.builtin.shell \
  -a 'systemctl stop elasticsearch || true; systemctl disable elasticsearch || true; rm -f /etc/systemd/system/elasticsearch.service; rm -f /etc/systemd/system/multi-user.target.wants/elasticsearch.service; systemctl daemon-reload; rm -rf /applis/elasticsearch /log/elasticsearch; sed -i "\|/applis|d; \|/log|d" /etc/fstab' \
  --become \
  --vault-password-file /mnt/ansible-vault-pwd

  echo "=== CHECK THE CLEANING ==="
  ansible elasticsearch -i inventory/prod/hosts.ini \
  -m ansible.builtin.shell \
  -a 'echo "=== SERVICE ==="; systemctl is-enabled elasticsearch 2>&1 || true; systemctl is-active elasticsearch 2>&1 || true; echo "=== FICHIERS ==="; test ! -e /etc/systemd/system/elasticsearch.service && echo "OK service supprimé" || echo "KO service présent"; test ! -d /applis/elasticsearch && echo "OK /applis/elasticsearch supprimé" || echo "KO /applis/elasticsearch présent"; test ! -d /log/elasticsearch && echo "OK /log/elasticsearch supprimé" || echo "KO /log/elasticsearch présent"; echo "=== FSTAB ==="; grep -E "/applis|/log" /etc/fstab || echo "OK aucune entrée /applis /log"; echo "=== LVM ==="; lvs' \
  --become \
  --vault-password-file /mnt/ansible-vault-pwd