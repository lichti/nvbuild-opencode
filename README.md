# nvbuild-opencode

Setup do [OpenCode](https://opencode.ai) apontando para o catálogo
[NVIDIA Build](https://build.nvidia.com) (NIM), com mitigação do limite de
**40 requisições por minuto** (erro `429 Too Many Requests`) via rotação de
modelos com o plugin
[lichti-opencode-model-fallback](https://github.com/lichti/lichti-opencode-model-fallback).

## Problema

A API da NVIDIA Build limita o uso a 40 RPM **por modelo** (não por conta).
Sem tratamento, o OpenCode derruba a sessão ao estourar esse limite:

```json
{"status":429,"title":"Too Many Requests"}
```

## Estratégia de mitigação

- **Rotação de modelos**: como o limite é por modelo, alternar entre vários
  modelos multiplica a capacidade efetiva disponível (5 modelos ≈ 200 RPM
  agregados, contra 40 RPM de um único modelo).
- **[lichti-opencode-model-fallback](https://github.com/lichti/lichti-opencode-model-fallback)**:
  plugin próprio (repositório separado, clonado via git pelo `make setup`)
  que detecta 429 (rate limit, cooldown temporário) e 410 (modelo
  aposentado pela NVIDIA, removido da rotação permanentemente) pelo
  status HTTP estruturado — não por casar texto de mensagem — e reenvia a
  última pergunta com o próximo modelo disponível da lista, com debounce
  por sessão. Loga cada troca em `~/.opencode/model-fallback-plugin.log`
  (veja `make status`).
- **Timeout generoso no provider**: evita retries agressivos por timeout
  curto.

Testamos primeiro o plugin de terceiros `opencode-rate-limit` (npm), mas
ele nunca trocava de modelo com a NVIDIA Build: seu detector de
`session.status` só reconhece as frases "usage limit" / "rate limit" /
"high concurrency" / "reduce concurrency", e o erro real da NVIDIA é
"Too Many Requests" — nunca dava match. Escrevemos o nosso, sem
dependências, que checa o `statusCode` estruturado do erro em vez de uma
lista fixa de frases; depois de validado aqui, viramos um repositório
próprio ([lichti-opencode-model-fallback](https://github.com/lichti/lichti-opencode-model-fallback))
pra poder reusar em outros setups de OpenCode. Detalhes do incidente em
[AGENTS.md](AGENTS.md).

## Estrutura

- [opencode.json](opencode.json) — config principal do OpenCode, com o
  provider NVIDIA e 5 modelos cadastrados (GLM-5.2, DeepSeek V4 Pro,
  DeepSeek V4 Flash, Kimi K2.6, MiniMax M3). O Qwen3 Coder 480B foi
  removido em 2026-07-21: atingiu end-of-life em 2026-06-11 e passou a
  responder `410 Gone` (ver [AGENTS.md](AGENTS.md)).
- [auth.json.example](auth.json.example) — modelo do arquivo de
  credenciais, separado do config para não vazar a chave em versionamento.
- [model-fallback.json](model-fallback.json) — lista de modelos e
  cooldown que o plugin lê (`~/.opencode/model-fallback.json`).
- [Makefile](Makefile) — `make setup-plugin` clona/atualiza
  [lichti-opencode-model-fallback](https://github.com/lichti/lichti-opencode-model-fallback)
  num cache local (`~/.cache/nvbuild-opencode/vendor/`) e copia o
  `index.js` para `$(CONFIG_DIR)/plugin/index.js`, referenciado por
  caminho absoluto em `opencode.json`.
- [AGENTS.md](AGENTS.md) — instruções agnósticas de vendor para agentes
  de IA que trabalharem neste repo (fonte da verdade).
  [CLAUDE.md](CLAUDE.md) e [GEMINI.md](GEMINI.md) apontam para ele.

## Instalação rápida

```bash
export NVIDIA_API_KEY="nvapi-..."   # gere em https://build.nvidia.com (perfil > API Keys)
make setup                          # clona o plugin, copia configs para ~/.config/opencode, ~/.opencode etc.
make run                            # inicia o OpenCode
```

Requer `git` (pra clonar o plugin). Veja `make help` para todos os
comandos disponíveis. `make setup-plugin` atualiza só o plugin (git pull
e recopia o arquivo), sem tocar em `opencode.json`/`auth.json`.

**Importante:** quem o OpenCode realmente lê em runtime é o
`~/.local/share/opencode/auth.json` — não a variável de ambiente. A
`NVIDIA_API_KEY` exportada acima só é usada pelo `make setup` para
preencher o `auth.json` automaticamente; se ela não estiver definida na
hora do `make setup`, ele pede a chave interativamente. Se quiser editar
manualmente, o arquivo (gerado a partir de
[auth.json.example](auth.json.example)) fica em
`~/.local/share/opencode/auth.json`. **Nunca commite um `auth.json` com
chave real** — apenas o `.example`.

## Uso

```bash
make run
```

Dentro da sessão do OpenCode:

```text
/models                              # lista os modelos disponíveis
/model nvidia/z-ai/glm-5.2            # troca de modelo manualmente
```

Fora da sessão, `make status` mostra o log do plugin (trocas de modelo,
erros de fallback).

## Próximos passos

- Se o uso ficar consistente, solicite aumento de RPM no NVIDIA Developer
  Forums (geralmente pede e-mail corporativo).
- Para produção, considere o NIM self-hosted em GPU própria ou o serverless
  NIM via Hugging Face (billing por uso, sem o teto de RPM do catálogo
  trial).
