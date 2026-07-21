# AGENTS.md

Instruções para agentes de IA (OpenCode, Codex, Claude Code, Gemini CLI e
outros) que trabalharem neste repositório. Este é o arquivo **agnóstico de
vendor** — a fonte única de verdade. `CLAUDE.md` e `GEMINI.md` são apenas
ponteiros para este arquivo; não duplique conteúdo neles.

## O que é este projeto

`nvbuild-opencode` configura o OpenCode para usar o catálogo NVIDIA Build
(NIM) como provider, mitigando o limite de 40 requisições por minuto (RPM)
imposto por modelo pela NVIDIA. A mitigação combina rotação entre múltiplos
modelos, retry com backoff exponencial e circuit breaker — ver
[README.md](README.md) para o raciocínio completo.

Não é uma aplicação com lógica de negócio: é um conjunto de arquivos de
configuração (`opencode.json`, `rate-limit-fallback.json`,
`auth.json.example`) mais um `Makefile` que automatiza a instalação desses
arquivos nos diretórios que o OpenCode espera (`~/.config/opencode`,
`~/.local/share/opencode`, `~/.opencode`).

## Regras importantes

- **Nunca commitar segredos.** `auth.json` (com chave real) nunca deve ir
  para o git — apenas `auth.json.example`. Se encontrar um `auth.json` com
  chave preenchida, alerte antes de fazer qualquer commit.
- **O limite de RPM é por modelo, não por conta.** Ao propor mudanças na
  config, preserve a lista de múltiplos modelos em `fallbackModels`
  (`opencode.json` e `rate-limit-fallback.json`) — não simplifique para um
  único modelo, isso reintroduz o problema de 429 que o projeto resolve.
- **Os três arquivos de config são acoplados.** Os `modelID`/`providerID`
  em `rate-limit-fallback.json` devem sempre corresponder a um modelo
  cadastrado em `opencode.json`. Ao adicionar ou remover um modelo, edite
  os dois arquivos juntos.
- **Makefile é a interface de setup.** Não instrua o usuário a copiar
  arquivos manualmente com `cp` — use e, se necessário, estenda os alvos do
  `Makefile` (`make setup`, `make install`, `make doctor`, etc.).
- **Nunca mencionar agente de IA como contribuidor ou committer.** Commits
  neste repositório não devem incluir trailers como `Co-Authored-By`
  citando Claude, Codex, Gemini ou qualquer outro agente de IA, nem usar
  um agente como autor/committer do commit. Autor e committer são sempre
  a pessoa que solicitou a mudança.

## Convenções

- Documentação e comentários deste projeto são em português (pt-BR).
- JSON de config deve continuar sendo JSON válido (sem comentários `//`
  dentro dos arquivos `.json`) — explicações vão no README ou neste
  arquivo, não dentro do JSON.

## Comandos úteis

```bash
make help      # lista todos os alvos disponíveis
make setup     # copia as configs para os diretórios do OpenCode
make install   # instala os plugins de resiliência (rate-limit-retry, rate-limit)
make doctor    # verifica se tudo está instalado e configurado corretamente
make run       # inicia o OpenCode
```
