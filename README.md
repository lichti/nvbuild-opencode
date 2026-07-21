# nvbuild-opencode

Setup do [OpenCode](https://opencode.ai) apontando para o catálogo
[NVIDIA Build](https://build.nvidia.com) (NIM), com mitigação do limite de
**40 requisições por minuto** (erro `429 Too Many Requests`) via rotação de
modelos e retry com backoff exponencial.

## Problema

A API da NVIDIA Build limita o uso a 40 RPM **por modelo** (não por conta).
Sem tratamento, o OpenCode derruba a sessão ao estourar esse limite:

```json
{"status":429,"title":"Too Many Requests"}
```

## Estratégia de mitigação

- **Rotação de modelos**: como o limite é por modelo, alternar entre vários
  modelos multiplica a capacidade efetiva disponível (6 modelos ≈ 240 RPM
  agregados, contra 40 RPM de um único modelo).
- **Retry com backoff exponencial + jitter**: evita que várias tentativas
  caiam no mesmo segundo e piorem o throttle.
- **Circuit breaker**: interrompe temporariamente o uso de um modelo que
  está falhando repetidamente, dando tempo para o rate limit resetar.
- **Timeout generoso no provider**: evita retries agressivos por timeout
  curto.

## Estrutura

- [opencode.json](opencode.json) — config principal do OpenCode, com o
  provider NVIDIA e 6 modelos cadastrados (GLM-5.2, Qwen3 Coder 480B,
  DeepSeek V4 Pro, DeepSeek V4 Flash, Kimi K2.6, MiniMax M3).
- [auth.json.example](auth.json.example) — modelo do arquivo de
  credenciais, separado do config para não vazar a chave em versionamento.
- [rate-limit-fallback.json](rate-limit-fallback.json) — config do plugin
  de fallback entre modelos quando um deles bate no limite de RPM.
- [Makefile](Makefile) — automação de setup, instalação de plugins e uso.
- [AGENTS.md](AGENTS.md) — instruções agnósticas de vendor para agentes
  de IA que trabalharem neste repo (fonte da verdade).
  [CLAUDE.md](CLAUDE.md) e [GEMINI.md](GEMINI.md) apontam para ele.

## Instalação rápida

```bash
export NVIDIA_API_KEY="nvapi-..."   # gere em https://build.nvidia.com (perfil > API Keys)
make setup                          # copia configs para ~/.config/opencode, ~/.opencode etc.
make install                        # instala os plugins de resiliência
```

Veja `make help` para todos os comandos disponíveis.

Se preferir não usar a variável de ambiente, edite o `auth.json` copiado
em `~/.local/share/opencode/auth.json` (gerado a partir de
[auth.json.example](auth.json.example)) e cole sua chave real ali. **Nunca
commite um `auth.json` com chave real** — apenas o `.example`.

## Uso

```bash
make run
```

Dentro da sessão do OpenCode:

```text
/models                              # lista os modelos disponíveis
/model nvidia/z-ai/glm-5.2            # troca de modelo manualmente
/rate-limit-status                    # relatório de saúde/fallback dos modelos
```

## Próximos passos

- Se o uso ficar consistente, solicite aumento de RPM no NVIDIA Developer
  Forums (geralmente pede e-mail corporativo).
- Para produção, considere o NIM self-hosted em GPU própria ou o serverless
  NIM via Hugging Face (billing por uso, sem o teto de RPM do catálogo
  trial).
