cd Ansible/projets/elasticsearch-cluster

ansible-playbook baselines.yml -i inventory/dev/hosts.ini --vault-password-file /tmp/ansible-vault-pwd.txt
ansible-playbook elasticsearch.yml -i inventory/dev/hosts.ini --vault-password-file /tmp/ansible-vault-pwd.txt