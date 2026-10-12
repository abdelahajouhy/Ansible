# Elasticsearch Ansible Role

## Role Name

`elasticsearch`

An Ansible role for deploying and configuring Elasticsearch nodes in a controlled environment.

## Requirements

The role requires:

* Ansible
* A supported Linux distribution
* Python 3 on managed nodes
* The Python dependencies required by the HashiCorp Vault Ansible integration

The Vault-related Python dependencies are installed by the baseline configuration and are required when the role retrieves secrets from Vault.

## Role Variables

The role provides variables to configure:

* Elasticsearch installation and directories
* Cluster and node configuration
* Network configuration
* JVM settings
* Security settings
* HTTP and transport TLS
* Certificate deployment
* Firewall configuration
* Service management

TLS generation is controlled independently from TLS deployment, allowing existing certificates to be reused without unnecessary regeneration.

Sensitive values are provided through external secret management and are not stored in the role.

## Dependencies

No external Ansible Galaxy roles are required.

The role can use:

* HashiCorp Vault for secret and certificate management
* Ansible Vault for Ansible-managed sensitive variables
* The baseline role for common system prerequisites

## TLS

TLS is used to secure both Elasticsearch transport and HTTP communications.

The implementation provides:

* Transport TLS between Elasticsearch nodes
* HTTPS for the Elasticsearch API
* A dedicated certificate for each Elasticsearch node
* Centralized certificate management through HashiCorp Vault
* Automated certificate deployment through Ansible
* Certificate authority validation

Certificates and private keys are retrieved from the external secret-management system and deployed to the Elasticsearch nodes.

Private keys, certificates, credentials and Vault tokens must not be committed to the Git repository.

Certificate generation and certificate deployment are handled independently. Existing certificates can therefore be reused during normal deployments.

## Security

Elasticsearch security features can be enabled through the role configuration.

Security-related credentials are retrieved from external secret management rather than being hard-coded in the role.

## Example Playbook

```yaml
- name: Deploy Elasticsearch
  hosts: elasticsearch
  become: true

  roles:
    - role: elasticsearch
```

## License

Internal / project-specific.

## Author Information

Abdelah AJOUHY.
