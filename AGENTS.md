# AGENTS.md

Instruções para agentes de IA (OpenCode, Codex, Claude Code, Gemini CLI e
outros) que trabalharem neste repositório. Este é o arquivo **agnóstico de
vendor** — a fonte única de verdade. `CLAUDE.md` e `GEMINI.md` são apenas
ponteiros para este arquivo; não duplique conteúdo neles.

## O que é este projeto

`nvbuild-opencode` configura o OpenCode para usar o catálogo NVIDIA Build
(NIM) como provider, mitigando o limite de 40 requisições por minuto (RPM)
imposto por modelo pela NVIDIA via rotação entre múltiplos modelos — ver
[README.md](README.md) para o raciocínio completo.

É um conjunto de arquivos de configuração (`opencode.json`,
`model-fallback.json`, `auth.json.example`) e um `Makefile` que automatiza
a instalação de tudo isso nos diretórios que o OpenCode espera
(`~/.config/opencode`, `~/.local/share/opencode`, `~/.opencode`), incluindo
o plugin de fallback — que **não vive mais neste repositório**.

### O plugin de fallback é um repositório separado

[lichti-opencode-model-fallback](https://github.com/lichti/lichti-opencode-model-fallback)
é o plugin de fallback entre modelos (429/410). Foi extraído deste
projeto pra poder ser reusado em outros setups de OpenCode. `make setup`
e `make setup-plugin` clonam/atualizam esse repo via git num cache local
(`~/.cache/nvbuild-opencode/vendor/`) e copiam o `index.js` pro diretório
de plugins do OpenCode.

O writeup completo (por que não usamos o `opencode-rate-limit` do npm,
como funciona a detecção de 429 vs 410, o bug de debounce que já
aconteceu em produção) está no `README.md`/`AGENTS.md` daquele
repositório — não duplique esse conteúdo aqui. Resumo rápido: o pacote de
terceiros só reconhecia "usage limit"/"rate limit"/"high concurrency"/
"reduce concurrency" em texto livre, e o erro real da NVIDIA
("Too Many Requests") nunca dava match, então ele nunca trocava de
modelo. Nosso plugin detecta pelo `statusCode` HTTP estruturado.

### Outros incidentes específicos deste projeto

Esse é um real, não hipotético: em 2026-07-21 o
`qwen/qwen3-coder-480b-a35b-instruct` (que estava na nossa lista de
fallback) passou a responder `410 Gone` — atingiu end-of-life em
2026-06-11 sem substituto confirmado no catálogo hospedado (só existe um
sucessor, `qwen3-coder-next`, como container NGC para self-host, não como
modelo servido em `build.nvidia.com`). Removemos o modelo de
`opencode.json` e `model-fallback.json`. Catálogos de modelo hosted
mudam com o tempo — se um modelo em `fallbackModels` começar a devolver
410/404 de forma consistente, o diagnóstico é "modelo foi descontinuado",
não "bug de config".

**`chunkTimeout` baixo demais quebra modelos de raciocínio (thinking).**
Tínhamos `chunkTimeout: 60000` (60s) em `provider.nvidia.options`. O
GLM-5.2 é um modelo com "thinking" (pausas de raciocínio antes de emitir
o próximo chunk) — quando a pausa passava de 60s, o cliente abortava e
reiniciava a geração do zero, o que aparecia como o modelo repetindo a
mesma frase de abertura várias vezes seguidas sem nunca terminar a
resposta (visto no `opencode.log`: pares `stream`/`llm runtime selected`
se repetindo a cada ~70-95s, sem nenhum erro e sem o `step` do loop
avançar — bem diferente do padrão de retry por 429, que loga
`stream error` explicitamente). Não é algo que o plugin de fallback
resolve — não é um erro HTTP, é um timeout de transporte. Subimos para
`chunkTimeout: 300000` (5min). Se isso voltar a acontecer com outro
modelo "thinking", esse é o primeiro lugar a olhar antes de suspeitar do
plugin ou do rate limit.

## Regras importantes

- **Nunca commitar segredos.** `auth.json` (com chave real) nunca deve ir
  para o git — apenas `auth.json.example`. Se encontrar um `auth.json` com
  chave preenchida, alerte antes de fazer qualquer commit.
- **O limite de RPM é por modelo, não por conta.** Ao propor mudanças na
  config, preserve a lista de múltiplos modelos em `fallbackModels`
  (`opencode.json` e `model-fallback.json`) — não simplifique para um
  único modelo, isso reintroduz o problema de 429 que o projeto resolve.
- **`opencode.json` e `model-fallback.json` são acoplados.** Os
  `modelID`/`providerID` em `model-fallback.json` devem sempre
  corresponder a um modelo cadastrado em `opencode.json`. Ao adicionar ou
  remover um modelo, edite os dois arquivos juntos.
- **Makefile é a interface de setup.** Não instrua o usuário a copiar
  arquivos manualmente com `cp` — use e, se necessário, estenda os alvos do
  `Makefile` (`make setup`, `make setup-plugin`, `make doctor`, `make run`,
  etc.).
- **Nunca adicionar `apiKey` de volta em `provider.nvidia.options` no
  `opencode.json`.** O OpenCode só consulta `auth.json` para um provider
  quando `options.apiKey` está ausente da config; se o campo existir (ex.
  `"{env:NVIDIA_API_KEY}"`) e a env var não estiver setada no processo que
  sobe o `opencode`, ele manda a requisição sem header de autorização e
  ignora silenciosamente o `auth.json` — foi exatamente esse bug que
  quebrou o uso fora do `make run`. A chave sempre vem de `auth.json`
  (escrito pelo `make setup`).
- **Nunca referenciar um pacote npm ou plugin sem confirmar que ele existe
  de verdade no registry.** Já aconteceu de um nome ser inventado/errado
  numa pesquisa anterior (`opencode-rate-limit-retry`, que não existe) e
  quebrar `make install`. Antes de citar um nome de pacote em código,
  Makefile ou docs, verifique com `npm view <pacote>` ou a documentação
  oficial do projeto.
- **Documentação (inclusive READMEs oficiais de pacotes) pode estar
  errada — o código-fonte instalado é a fonte da verdade.** O próprio
  README do `opencode-rate-limit` usava `"plugins"` (plural) no exemplo,
  mas o schema real do OpenCode (`https://opencode.ai/config.json`) usa
  `"plugin"` (singular). Quando a config não se comportar como a
  documentação promete, leia o código real antes de concluir que é erro
  de configuração.
- **O plugin de fallback vive em
  [lichti-opencode-model-fallback](https://github.com/lichti/lichti-opencode-model-fallback),
  não neste repo.** Não reintroduza `opencode-rate-limit` (npm) nem outro
  pacote de terceiros sem antes confirmar (lendo o código, não só o
  README) que ele detecta rate limit pelo `statusCode` HTTP. Mudanças no
  comportamento do plugin em si (detecção de erro, debounce, cooldown)
  são feitas naquele repositório, não aqui — este repo só consome via
  `make setup-plugin` (git clone/pull).
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
make help          # lista todos os alvos disponíveis
make setup         # clona/atualiza o plugin + copia configs para os diretórios do OpenCode
make setup-plugin  # so git pull + recopia o plugin (sem tocar em opencode.json/auth.json)
make doctor        # verifica se tudo está instalado e configurado corretamente
make run           # inicia o OpenCode
make status        # mostra o log do plugin de fallback (trocas de modelo, erros)
```
