# Ansible Infrastructure Automation

This repository contains Ansible projects designed to automate infrastructure deployment, configuration, and maintenance.

The projects provide reusable automation for teams that need to deploy and operate clusters, distributed systems, observability platforms, and supporting infrastructure services.

## Supported Infrastructure

The automation can be used to deploy and configure infrastructure components such as:

### Data & Distributed Systems

* **Elasticsearch**
* **Apache Spark**
* **Apache Kafka**

### Observability

* **Kibana**
* **Grafana**
* **Beats agents**

### Other Services

The repository can also be used to automate other services and infrastructure components that can be deployed and configured through Ansible.

The supported scope can evolve as new projects and automation requirements are added.

## Deployment Environments

The automation can be used across different deployment environments, including:

* Physical servers
* Virtual machines
* Containerized environments

Cloud-based deployments are currently outside the scope of this repository.

## Repository Structure

```text
.
├── .github/
│   └── workflows/
├── projets/
│   ├── <ansible-project>/
│   └── ...
├── .ansible-lint
├── .yamllint
├── .gitignore
└── README.md
```

## Projects

Each directory under `projets/` represents an independent Ansible project.

A project can contain:

* Inventory configuration
* Playbooks
* Roles
* Variables
* Templates
* Handlers
* Configuration files
* Project-specific documentation

## Using a Project

Each project provides the automation required to configure its target infrastructure.

A typical workflow is:

```bash
# Move to the selected Ansible project.
cd projets/<ansible-project>

# Display the inventory and verify the target hosts.
ansible-inventory -i inventory/hosts.ini --list

# Test Ansible connectivity with the managed hosts.
ansible all -i inventory/hosts.ini -m ping

# Run the project's main playbook.
ansible-playbook -i inventory/hosts.ini playbook/site.yml
```

The exact commands, variables, inventory structure, and deployment requirements may differ between projects.

Refer to the documentation provided inside each project before deployment.

## Infrastructure Automation

The projects are designed to automate tasks such as:

* Operating system configuration
* Package installation
* Service installation and configuration
* Cluster deployment
* Configuration management
* Directory and filesystem preparation
* Service management
* Monitoring and observability configuration
* Infrastructure hardening

The objective is to make infrastructure deployments **repeatable, consistent, and maintainable**.

## Security

Sensitive credentials and private cryptographic material must not be committed to the repository.

This includes, for example:

* Private keys
* Private CA keys
* Keystores containing private keys
* Credentials
* Access tokens
* Other sensitive information

Secrets should be provided through an appropriate secret-management mechanism or secure deployment process.

## Development Workflow

Infrastructure changes are developed in dedicated feature branches and submitted through Pull Requests.

```text
Feature branch
      │
      ▼
Pull Request
      │
      ▼
Code review
      │
      ▼
main
```

The `main` branch contains the validated infrastructure automation used by the projects.

## Roadmap

The repository will evolve with additional:

* Infrastructure projects
* Services
* Deployment methods
* Automation capabilities

Cloud-based deployment is currently outside the scope of the repository and is not part of the current roadmap.

## Goal

The goal of this repository is to provide practical, reusable Ansible automation that teams can use to deploy and configure infrastructure reliably.

The repository is intended to support data platforms, distributed systems, observability solutions, and other infrastructure services across physical servers, virtual machines, and containerized environments.
