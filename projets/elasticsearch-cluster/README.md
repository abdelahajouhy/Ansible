# Déploiement du cluster Elasticsearch (Ansible)

Déploiement d'un cluster Elasticsearch 9.x de 3 nœuds à partir du tar.gz officiel, sur Ubuntu 24.04.

**État actuel** : sécurité désactivée (pas d'authentification, pas de TLS). Kibana n'est pas déployé.

---

## 1. Architecture

| Nœud | IP | Rôles | rack_id |
|---|---|---|---|
| srv-abde01 | 192.168.112.135 | master, data, ingest | zone1 |
| srv-abde02 | 192.168.112.136 | master, data, ingest | zone2 |
| srv-abde03 | 192.168.112.137 | master, voting_only | zone3 |

- Les données sont portées par srv-abde01 et srv-abde02.
- srv-abde03 vote pour l'élection du master mais ne peut pas être élu et ne stocke aucune donnée.
- Nom réel d'un nœud : `<inventory_hostname>-<env>` (ex. `srv-abde01-prod`).
- Nom du cluster : `cluster-databde-prod`.

---

## 2. Structure du projet

```
.
├── elasticsearch.yml                  # playbook (appelle uniquement le rôle)
├── inventory/prod/
│   ├── hosts.ini
│   ├── group_vars/
│   │   ├── all/main.yml               # vault_url, vault_token (chiffré), répertoires globaux
│   │   ├── elasticsearch/main.yml     # variables du cluster
│   │   └── kibana/main.yml            # (non utilisé pour l'instant)
│   └── host_vars/srv-abde0[1-3].yml   # node_name, rôles, IP, rack_id
└── roles/elasticsearch/
    ├── tasks/
    │   ├── main.yml                   # ordre + tags
    │   ├── install.yml                # utilisateur, répertoires, archive, sysctl
    │   ├── firewall.yml               # firewalld + ports 9200/9300
    │   ├── config.yml                 # elasticsearch.yml + jvm.options
    │   ├── systemd.yml                # unit systemd
    │   ├── security.yml               # appelle le bootstrap (si activé)
    │   └── security_bootstrap.yml     # mots de passe elastic / kibana_system (Vault)
    ├── handlers/main.yml              # reload, restart, attentes
    ├── templates/                     # elasticsearch.yml.j2, jvm.options.j2, elasticsearch.service.j2
    └── vars/main.yml                  # elasticsearch_base_url
```

---

## 3. Prérequis

**Machine de contrôle**
- Ansible, avec la collection `ansible.posix` :

```bash
ansible-galaxy collection install ansible.posix
```

- Fichier de mot de passe ansible-vault (ex. `/mnt/ansible-vault-pwd`)

**Serveurs**
- Ubuntu 24.04, accès SSH avec l'utilisateur `sysadmin`, sudo.
- Accès sortant vers `https://artifacts.elastic.co` (téléchargement de l'archive).
- `ufw` inactif (le pare-feu est géré par firewalld).
- Ports 9200 (HTTP) et 9300 (transport) ouverts entre les nœuds : fait par le rôle.

**Vérifications avant de lancer**

```bash
# Connexion aux 3 nœuds
ansible -i inventory/prod/hosts.ini elasticsearch -m ping --vault-password-file /mnt/ansible-vault-pwd

# Syntaxe du playbook
ansible-playbook -i inventory/prod/hosts.ini elasticsearch.yml --vault-password-file /mnt/ansible-vault-pwd --syntax-check

# Valeur de la liste seed_hosts
ansible -i inventory/prod/hosts.ini srv-abde01 -m debug -a "var=elasticsearch_discovery_seed_hosts" --vault-password-file /mnt/ansible-vault-pwd

# Accès au téléchargement (à lancer depuis chaque serveur)
curl -4 -sI --max-time 20 https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-9.5.4-linux-x86_64.tar.gz | head -1

# État du pare-feu (sur chaque serveur)
sudo ufw status
sudo firewall-cmd --list-all
```

---

## 4. Variables importantes

Fichier : `inventory/prod/group_vars/elasticsearch/main.yml`

| Variable | Rôle |
|---|---|
| `elasticsearch_version` | Version téléchargée |
| `elasticsearch_heap` | Heap JVM (`-Xms` / `-Xmx`) |
| `elasticsearch_single_node` | `false` pour un cluster |
| `elasticsearch_discovery_seed_hosts` | IP des nœuds (découverte) |
| `elasticsearch_cluster_initial_master_nodes` | Noms des nœuds éligibles, **identiques aux `node.name`** (`srv-abde01-{{ env }}`...) |
| `elasticsearch_cluster_bootstrap` | `true` au premier démarrage uniquement, puis `false` |
| `elasticsearch_security_enabled` | `false` tant que les certificats ne sont pas en place |
| `elasticsearch_security_bootstrap` | `true` pour un run, afin de fixer les mots de passe |

Fichiers `host_vars` : `elasticsearch_node_name`, `elasticsearch_node_roles`, `elasticsearch_network_host`, `elasticsearch_node_attr_rack_id`.

---

## 5. Utilisation

### 5.1 Premier déploiement (bootstrap du cluster)

Les 3 nœuds doivent démarrer **ensemble** : au bootstrap, chaque nœud attend de découvrir tous les nœuds listés dans `initial_master_nodes`.

1. Dans `elasticsearch.yml` (playbook), **commenter `serial: 1`**.
2. Dans `group_vars/elasticsearch/main.yml` : `elasticsearch_cluster_bootstrap: true`.
3. Lancer :

```bash
ansible-playbook -i inventory/prod/hosts.ini elasticsearch.yml --vault-password-file /mnt/ansible-vault-pwd
```

4. Vérifier :

```bash
curl -s 'http://192.168.112.135:9200/_cluster/health?pretty'
curl -s 'http://192.168.112.135:9200/_cat/nodes?v&h=name,ip,node.role,master'
```

Attendu : `number_of_nodes: 3`, `status: green`, 01 et 02 en `dim`, 03 en `mv`, master élu parmi 01 ou 02.

### 5.2 Après le bootstrap

1. **Remettre `serial: 1`** dans le playbook.
2. Passer `elasticsearch_cluster_bootstrap: false` : la ligne `cluster.initial_master_nodes` disparaît de `elasticsearch.yml`.
3. Appliquer (voir 5.3).
4. Contrôler que la ligne a bien disparu, sur un nœud :

```bash
grep -c initial_master /applis/elasticsearch/config/elasticsearch.yml
```

Attendu : `0`. Ne jamais remettre `true` sur un cluster déjà formé.

### 5.3 Mise à jour de la configuration (usage courant)

```bash
ansible-playbook -i inventory/prod/hosts.ini elasticsearch.yml --vault-password-file /mnt/ansible-vault-pwd --tags config
```

Pour chaque nœud, l'un après l'autre (`serial: 1`) :

1. `elasticsearch.yml` et `jvm.options` sont mis à jour.
2. **Si un fichier a changé**, le handler redémarre Elasticsearch.
3. Ansible attend que le port 9200 écoute, puis que le cluster ait ses 3 nœuds `green`.
4. Il passe au nœud suivant.

Si rien n'a changé, rien ne redémarre.

### 5.4 Autres commandes

```bash
# Mise à jour de l'unit systemd uniquement
ansible-playbook -i inventory/prod/hosts.ini elasticsearch.yml --vault-password-file /mnt/ansible-vault-pwd --tags systemd

# Pare-feu uniquement
ansible-playbook -i inventory/prod/hosts.ini elasticsearch.yml --vault-password-file /mnt/ansible-vault-pwd --tags firewall

# Tout sauf l'installation
ansible-playbook -i inventory/prod/hosts.ini elasticsearch.yml --vault-password-file /mnt/ansible-vault-pwd --skip-tags install

# Un seul nœud (nom exact de l'inventaire)
ansible-playbook -i inventory/prod/hosts.ini elasticsearch.yml --vault-password-file /mnt/ansible-vault-pwd --limit srv-abde03

# Voir les tâches qui vont tourner, sans exécuter
ansible-playbook -i inventory/prod/hosts.ini elasticsearch.yml --vault-password-file /mnt/ansible-vault-pwd --tags config --list-tasks

# Voir les différences sans appliquer
ansible-playbook -i inventory/prod/hosts.ini elasticsearch.yml --vault-password-file /mnt/ansible-vault-pwd --tags config --check --diff
```

### 5.5 Tags

| Tag | Effet |
|---|---|
| `install` | utilisateur, répertoires, archive, `vm.max_map_count` |
| `firewall` | firewalld et ouverture des ports |
| `config` | `elasticsearch.yml` et `jvm.options` (+ restart si changement) |
| `systemd` | unit systemd (+ reload et restart si changement) |
| `security` | bootstrap des mots de passe (si activé) |

Sans tag, tout le rôle s'exécute.

---

## 6. Fonctionnement des handlers

Défini dans `roles/elasticsearch/handlers/main.yml`. Notifier `Restart Elasticsearch` déclenche, dans l'ordre :

1. Restart du service.
2. Attente du port 9200.
3. Attente des 3 nœuds `green`.

`config.yml` et `systemd.yml` notifient ce handler uniquement quand un fichier change.

---

## 7. Dépannage

| Symptôme | Cause probable | Action |
|---|---|---|
| `master not discovered yet` | Port 9300 bloqué, IP de `seed_hosts` fausse, ou nœud absent | voir commandes ci-dessous |
| Le bootstrap ne se fait jamais | `initial_master_nodes` ≠ `node.name` (suffixe `-prod` oublié) | Aligner les deux listes |
| `_cat/nodes` très lent | Pas de master élu | Utiliser `?local=true` |
| Timeout sur « Extraire Elasticsearch » | Le serveur n'atteint pas `artifacts.elastic.co` | `curl` depuis le serveur, puis relancer |
| Le nœud ne démarre pas | Bootstrap check (`vm.max_map_count`, droits, chemins) | `journalctl -u elasticsearch` |
| `--limit abde03` ne cible aucun hôte | Le nom exact est `srv-abde03` | `--limit srv-abde03` |

```bash
# Logs du service
sudo journalctl -u elasticsearch -n 100 --no-pager

# Filtrer sur la découverte / le bootstrap
sudo journalctl -u elasticsearch -n 60 --no-pager | grep -iE "master|discover|bootstrap"

# État du nœud local (répond vite même sans master)
curl -s --max-time 10 'http://192.168.112.135:9200/'
curl -s --max-time 10 'http://192.168.112.135:9200/_cluster/health?local=true&pretty'
curl -s --max-time 10 'http://192.168.112.135:9200/_cat/nodes?v&local=true&master_timeout=5s'

# Test du port de transport entre nœuds
nc -zv 192.168.112.136 9300

# Ports ouverts
sudo firewall-cmd --list-ports

# Vérifier le node.name et la liste initial_master_nodes déployés
grep -E "node.name|initial_master" -A4 /applis/elasticsearch/config/elasticsearch.yml
```

Un `data/` vide n'est nécessaire que si un cluster s'est déjà formé avec une mauvaise configuration :

```bash
sudo systemctl stop elasticsearch
sudo rm -rf /applis/elasticsearch/data/*
sudo systemctl start elasticsearch
```

---

## 8. Activer la sécurité (à faire plus tard)

La sécurité est désactivée car, sur un cluster de plusieurs nœuds, Elasticsearch exige le TLS sur le transport dès que l'authentification est activée.

1. Générer la CA et `transport.p12`, puis les déployer sur les 3 nœuds.
2. Passer `elasticsearch_transport_ssl_enable: true` et `elasticsearch_security_enabled: true`.
3. Redémarrer **les 3 nœuds en même temps** (un nœud TLS ne parle pas à un nœud sans TLS).
4. Passer `elasticsearch_security_bootstrap: true` pour un run : les mots de passe `elastic` et `kibana_system` sont lus dans Vault et fixés. Puis remettre `false`.
5. Adapter le handler `Wait for Elasticsearch cluster` : il recevra un `401` et devra s'authentifier avec le mot de passe `elastic` lu dans Vault.
6. Vérifier que `security_bootstrap.yml` s'exécute une seule fois et non nœud par nœud (voir limites).

Secrets Vault utilisés : `secret/elasticsearch/dev/credentials` (clé `elastic`) et `secret/kibana/dev` (clé `kibana_system`).

Chiffrer le mot de passe sudo dans l'inventaire :

```bash
ansible-vault encrypt_string 'MOT_DE_PASSE' --name ansible_become_password
```

---

## 9. Limites connues

- Le restart d'une conf modifiée n'est « rolling » que grâce à `serial: 1`. Sans lui, les 3 nœuds redémarrent en même temps.
- `security_bootstrap.yml` utilise `run_once`, qui s'exécute une fois **par nœud** avec `serial: 1`. À traiter au moment d'activer la sécurité.
- Les mots de passe transitent en clair tant que le TLS HTTP n'est pas activé.
- `ansible_become_password` est en clair dans `group_vars/all/main.yml` : à chiffrer (commande ci-dessus).
- Kibana (rôle, firewall, keystore) est écrit mais non lancé : il nécessite que la sécurité soit active.