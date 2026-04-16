SHELL := /bin/sh

VAULT_DIR := environments/local/vault
APP_DIR := environments/local/app
BOOTSTRAP_DIR := environments/bootstrap

.PHONY: up down plan init bootstrap-init bootstrap-plan bootstrap-apply bootstrap-destroy

init:
	terraform -chdir=$(VAULT_DIR) init
	terraform -chdir=$(APP_DIR) init

plan:
	terraform -chdir=$(VAULT_DIR) plan
	terraform -chdir=$(APP_DIR) plan

up:
	terraform -chdir=$(VAULT_DIR) apply
	terraform -chdir=$(APP_DIR) apply

down:
	terraform -chdir=$(APP_DIR) destroy
	terraform -chdir=$(VAULT_DIR) destroy

bootstrap-init:
	terraform -chdir=$(BOOTSTRAP_DIR) init

bootstrap-plan:
	terraform -chdir=$(BOOTSTRAP_DIR) plan

bootstrap-apply:
	terraform -chdir=$(BOOTSTRAP_DIR) apply

bootstrap-destroy:
	terraform -chdir=$(BOOTSTRAP_DIR) destroy
