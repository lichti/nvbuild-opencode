#nvbuild-opencode

- Criar um projeto de setup perfeito para uso do opencode com o NVIDIA Build
- Problema: Limite de 40 RPM (Requests por Minuto) = Erro de Too Many Requests: {"status":429,"title":"Too Many Requests"} 
- Inicializar repo git
- Usar como base: 
  - tmp/escopo.md
  - tmp/README.MD
  - tmp/auth.json.example
  - tmp/opencode.json
  - tmp/rate-limit-fallback.json
- Criar um Makefile para auxiliar, setup, uso e etc...
- Crie um claude.md de forma agnostica que chame um agentic.md que deve ser o arquivo agnostico a vendors que deve ser lido pelo claude.md, gemini.md e outros, ja crie para opencode e outras tecnologia como codex...