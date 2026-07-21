SHELL := /bin/bash

CONFIG_DIR := $(HOME)/.config/opencode
DATA_DIR   := $(HOME)/.local/share/opencode
HOME_DIR   := $(HOME)/.opencode

.DEFAULT_GOAL := help

.PHONY: help setup install check-key doctor run status clean

help: ## Lista os alvos disponiveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

define confirm_copy
	if [ -f "$(2)" ]; then \
		read -r -p "$(2) ja existe. Sobrescrever? [y/N] " reply; \
		case "$$reply" in \
			[yY]*) cp "$(1)" "$(2)"; echo "Sobrescrito: $(2)";; \
			*) echo "Mantido (nao sobrescrito): $(2)";; \
		esac; \
	else \
		cp "$(1)" "$(2)"; \
		echo "Criado: $(2)"; \
	fi
endef

setup: | $(CONFIG_DIR) $(DATA_DIR) $(HOME_DIR) ## Copia configs (perguntando antes de sobrescrever) e pede a NVIDIA_API_KEY se faltar
	@$(call confirm_copy,opencode.json,$(CONFIG_DIR)/opencode.json)
	@$(call confirm_copy,rate-limit-fallback.json,$(HOME_DIR)/rate-limit-fallback.json)
	@overwrite_auth=1; \
	if [ -f "$(DATA_DIR)/auth.json" ]; then \
		read -r -p "$(DATA_DIR)/auth.json ja existe. Sobrescrever? [y/N] " reply; \
		case "$$reply" in [yY]*) overwrite_auth=1;; *) overwrite_auth=0;; esac; \
	fi; \
	if [ "$$overwrite_auth" != "1" ]; then \
		echo "Mantido (nao sobrescrito): $(DATA_DIR)/auth.json"; \
	else \
		key="$$NVIDIA_API_KEY"; \
		if [ -z "$$key" ]; then \
			read -r -s -p "NVIDIA_API_KEY nao encontrada no ambiente. Cole sua chave (nvapi-...), ou deixe em branco para editar depois: " key; \
			echo; \
		else \
			echo "NVIDIA_API_KEY encontrada no ambiente."; \
		fi; \
		if [ -n "$$key" ]; then \
			sed "s/nvapi-COLE_SUA_CHAVE_AQUI/$$key/" auth.json.example > "$(DATA_DIR)/auth.json"; \
			echo "Criado: $(DATA_DIR)/auth.json (chave preenchida)"; \
		else \
			cp auth.json.example "$(DATA_DIR)/auth.json"; \
			echo "Criado: $(DATA_DIR)/auth.json (edite e cole sua chave nvapi-... manualmente)"; \
		fi; \
	fi
	@echo "Setup concluido. Rode 'make doctor' para verificar."

$(CONFIG_DIR) $(DATA_DIR) $(HOME_DIR):
	mkdir -p $@

install: ## Instala os plugins de resiliencia (rate-limit-retry, rate-limit)
	@command -v npm >/dev/null 2>&1 || { echo "npm nao encontrado. Instale o Node.js primeiro."; exit 1; }
	npm install -g opencode-rate-limit-retry opencode-rate-limit

check-key: ## Verifica se a NVIDIA_API_KEY esta configurada (env ou auth.json)
	@if [ -n "$$NVIDIA_API_KEY" ]; then \
		echo "OK: NVIDIA_API_KEY definida via variavel de ambiente."; \
	elif [ -f $(DATA_DIR)/auth.json ] && ! grep -q "COLE_SUA_CHAVE_AQUI" $(DATA_DIR)/auth.json; then \
		echo "OK: chave configurada em $(DATA_DIR)/auth.json."; \
	else \
		echo "FALTA: nenhuma chave NVIDIA configurada. Defina NVIDIA_API_KEY ou edite $(DATA_DIR)/auth.json."; \
		exit 1; \
	fi

doctor: ## Roda todas as checagens de setup (opencode, plugins, config, chave)
	@echo "== opencode =="
	@command -v opencode >/dev/null 2>&1 && echo "  ok: instalado" || echo "  falta: npm install -g opencode"
	@echo "== plugins =="
	@npm ls -g opencode-rate-limit-retry >/dev/null 2>&1 && echo "  ok: opencode-rate-limit-retry" || echo "  falta: opencode-rate-limit-retry (make install)"
	@npm ls -g opencode-rate-limit >/dev/null 2>&1 && echo "  ok: opencode-rate-limit" || echo "  falta: opencode-rate-limit (make install)"
	@echo "== config =="
	@[ -f $(CONFIG_DIR)/opencode.json ] && echo "  ok: $(CONFIG_DIR)/opencode.json" || echo "  falta: make setup"
	@[ -f $(HOME_DIR)/rate-limit-fallback.json ] && echo "  ok: $(HOME_DIR)/rate-limit-fallback.json" || echo "  falta: make setup"
	@echo "== chave =="
	@$(MAKE) --no-print-directory check-key || true

run: ## Inicia o OpenCode
	@command -v opencode >/dev/null 2>&1 || { echo "opencode nao encontrado. Instale com: npm install -g opencode"; exit 1; }
	opencode

status: ## Lembrete de como checar a saude do fallback dentro de uma sessao do OpenCode
	@echo "Dentro do 'opencode', rode: /rate-limit-status"

clean: ## Remove os arquivos de config instalados por 'make setup' (auth.json e preservado)
	rm -f $(CONFIG_DIR)/opencode.json
	rm -f $(HOME_DIR)/rate-limit-fallback.json
	@echo "Config removida. auth.json preservado em $(DATA_DIR) (remova manualmente se quiser)."
