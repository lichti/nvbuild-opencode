SHELL := /bin/bash

CONFIG_DIR := $(HOME)/.config/opencode
DATA_DIR   := $(HOME)/.local/share/opencode
HOME_DIR   := $(HOME)/.opencode
PLUGIN_DIR := $(CONFIG_DIR)/plugin
PLUGIN_FILE := $(PLUGIN_DIR)/index.js
PLUGIN_LOG := $(HOME_DIR)/model-fallback-plugin.log

VENDOR_DIR := $(HOME)/.cache/nvbuild-opencode/vendor
FALLBACK_PLUGIN_REPO := https://github.com/lichti/lichti-opencode-model-fallback.git
FALLBACK_PLUGIN_SRC := $(VENDOR_DIR)/lichti-opencode-model-fallback

.DEFAULT_GOAL := help

.PHONY: help setup setup-plugin check-key doctor run status clean

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

setup-plugin: | $(PLUGIN_DIR) ## Clona/atualiza o lichti-opencode-model-fallback (git) e instala no diretorio de plugins do OpenCode
	@mkdir -p "$(VENDOR_DIR)"
	@if [ -d "$(FALLBACK_PLUGIN_SRC)/.git" ]; then \
		echo "Atualizando $(FALLBACK_PLUGIN_SRC)..."; \
		git -C "$(FALLBACK_PLUGIN_SRC)" pull --ff-only || echo "Aviso: git pull falhou (sem rede?) - usando copia em cache."; \
	else \
		echo "Clonando $(FALLBACK_PLUGIN_REPO)..."; \
		git clone "$(FALLBACK_PLUGIN_REPO)" "$(FALLBACK_PLUGIN_SRC)"; \
	fi
	@[ -f "$(FALLBACK_PLUGIN_SRC)/index.js" ] || { echo "ERRO: $(FALLBACK_PLUGIN_SRC)/index.js nao encontrado apos clone/pull."; exit 1; }
	@$(call confirm_copy,$(FALLBACK_PLUGIN_SRC)/index.js,$(PLUGIN_FILE))

setup: | $(CONFIG_DIR) $(DATA_DIR) $(HOME_DIR) $(PLUGIN_DIR) ## Copia configs (perguntando antes de sobrescrever) e pede a NVIDIA_API_KEY se faltar
	@$(MAKE) --no-print-directory setup-plugin
	@if [ -f "$(CONFIG_DIR)/opencode.json" ]; then \
		read -r -p "$(CONFIG_DIR)/opencode.json ja existe. Sobrescrever? [y/N] " reply; \
		case "$$reply" in \
			[yY]*) sed "s|__MODEL_FALLBACK_PLUGIN_PATH__|$(PLUGIN_FILE)|" opencode.json > "$(CONFIG_DIR)/opencode.json"; echo "Sobrescrito: $(CONFIG_DIR)/opencode.json";; \
			*) echo "Mantido (nao sobrescrito): $(CONFIG_DIR)/opencode.json";; \
		esac; \
	else \
		sed "s|__MODEL_FALLBACK_PLUGIN_PATH__|$(PLUGIN_FILE)|" opencode.json > "$(CONFIG_DIR)/opencode.json"; \
		echo "Criado: $(CONFIG_DIR)/opencode.json"; \
	fi
	@$(call confirm_copy,model-fallback.json,$(HOME_DIR)/model-fallback.json)
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

$(CONFIG_DIR) $(DATA_DIR) $(HOME_DIR) $(PLUGIN_DIR):
	mkdir -p $@

check-key: ## Verifica se ha uma chave NVIDIA valida em auth.json (o que o OpenCode realmente le em runtime)
	@if [ -f $(DATA_DIR)/auth.json ] && ! grep -q "COLE_SUA_CHAVE_AQUI" $(DATA_DIR)/auth.json; then \
		echo "OK: chave configurada em $(DATA_DIR)/auth.json."; \
	else \
		echo "FALTA: nenhuma chave NVIDIA configurada em $(DATA_DIR)/auth.json. Rode 'make setup' (NVIDIA_API_KEY no ambiente preenche automaticamente, mas so na hora do setup - o OpenCode em si sempre le do auth.json)."; \
		exit 1; \
	fi

doctor: ## Roda todas as checagens de setup (opencode, plugin, config, chave)
	@echo "== opencode =="
	@command -v opencode >/dev/null 2>&1 && echo "  ok: instalado" || echo "  falta: npm install -g opencode-ai"
	@echo "== plugin =="
	@[ -d "$(FALLBACK_PLUGIN_SRC)/.git" ] && echo "  ok: vendor clonado em $(FALLBACK_PLUGIN_SRC)" || echo "  falta: make setup-plugin"
	@[ -f "$(PLUGIN_FILE)" ] && echo "  ok: $(PLUGIN_FILE)" || echo "  falta: make setup"
	@[ -f "$(PLUGIN_LOG)" ] && echo "  ok: log em $(PLUGIN_LOG) (veja 'make status')" || echo "  info: plugin ainda nao gerou log (normal antes do primeiro 'opencode')"
	@echo "== config =="
	@[ -f $(CONFIG_DIR)/opencode.json ] && echo "  ok: $(CONFIG_DIR)/opencode.json" || echo "  falta: make setup"
	@[ -f $(HOME_DIR)/model-fallback.json ] && echo "  ok: $(HOME_DIR)/model-fallback.json" || echo "  falta: make setup"
	@echo "== chave =="
	@$(MAKE) --no-print-directory check-key || true

run: ## Inicia o OpenCode
	@command -v opencode >/dev/null 2>&1 || { echo "opencode nao encontrado. Instale com: npm install -g opencode-ai"; exit 1; }
	opencode

status: ## Mostra as ultimas linhas do log do plugin de fallback (trocas de modelo, erros)
	@[ -f "$(PLUGIN_LOG)" ] && tail -n 30 "$(PLUGIN_LOG)" || echo "Nenhum log ainda em $(PLUGIN_LOG) - rode 'opencode' primeiro."

clean: ## Remove os arquivos de config instalados por 'make setup' (auth.json e preservado)
	rm -f $(CONFIG_DIR)/opencode.json
	rm -f $(HOME_DIR)/model-fallback.json
	rm -rf $(PLUGIN_DIR)
	@echo "Config removida. auth.json preservado em $(DATA_DIR) (remova manualmente se quiser)."
