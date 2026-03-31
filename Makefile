SHELL := /bin/sh

VAULT_DIR := environments/local/vault
APP_DIR := environments/local/app

.PHONY: up down plan init

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
