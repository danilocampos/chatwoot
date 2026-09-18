# Validação local — provedores WhatsApp

Data: 18/09/2026. Base oficial Chatwoot v4.18.0. Produção, Coolify, DNS, R2 e provedores externos não foram alterados.

## Ambiente

Worktree isolado em `/private/tmp/chatwoot-whatsapp-providers`, branch `codex/whatsapp-providers`.
Ruby 3.4.4, Rails 7.2.3.1, PostgreSQL 17 com pgvector, Redis local, pnpm 10.2.0.
PostgreSQL `127.0.0.1:55439`, bancos separados de desenvolvimento/teste; Redis `127.0.0.1:56389`, DBs 11/12.
Nenhum teste foi executado no Supabase nem no banco de produção. Dados e credenciais da revisão visual são fictícios.
`.env`, `.env.test`, screenshots e estado do navegador são ignorados pelo Git.

Node disponível: 26.7.0. O projeto exige Node 24.x; build/testes passaram, mas a matriz Node 24 deve ser repetida no CI antes de release.
Não houve mudança em dependências ou lockfiles do projeto.

## Backend

Suíte de regressão ampliada: **658 exemplos, zero falhas**. Abrange todos os services WhatsApp upstream, os novos adapters,
Meta/360dialog, signup/webhook, janela de atendimento, models Whatsapp/Twilio, API de inboxes, controle global/account e eventos novos.

```sh
bundle exec rspec \
  spec/services/whatsapp \
  spec/models/whatsapp \
  spec/models/channel/whatsapp_provider_access_spec.rb \
  spec/models/channel/whatsapp_spec.rb \
  spec/models/channel/twilio_sms_spec.rb \
  spec/controllers/super_admin/whatsapp_providers_controller_spec.rb \
  spec/controllers/webhooks/whatsapp_providers_controller_spec.rb \
  spec/controllers/api/v1/accounts/whatsapp/providers_controller_spec.rb \
  spec/jobs/webhooks/whatsapp_provider_events_job_spec.rb \
  spec/controllers/webhooks/whatsapp_controller_spec.rb \
  spec/services/conversations/message_window_service_spec.rb \
  spec/controllers/api/v1/accounts/inboxes_controller_spec.rb
```

Validados: criação permitida/negada pela API real; isolamento de contas; segredo cifrado inclusive em `save!(validate: false)`;
edição vazia; serializers sem tokens; webhook de cada adapter autenticado; conteúdo da fila cifrado; QR cifrado;
deduplicação durável; texto recebido; download simulado com anexo persistido; timestamp; status sem regressão;
envio HTTP simulado; timeout/erro sem token nem causa original; SSRF e redirects bloqueados.
Os testes não constituem tráfego real com WhatsApp.

Schema e migration aplicados somente nos bancos locais. A suíte completa do Chatwoot/Enterprise não foi executada.
Warnings upstream de enums Rails e `unprocessable_entity` permanecem; não causaram falhas.

## Frontend, lint e build

```sh
pnpm test app/javascript/dashboard/api/specs/whatsappProviders.spec.js \
  app/javascript/dashboard/helper/specs/whatsappProviders.spec.js \
  app/javascript/dashboard/routes/dashboard/settings/inbox/channels/specs/SessionWhatsapp.spec.js
pnpm exec vite build
pnpm run build:sdk
```

- Vitest: **3 arquivos, 6 testes aprovados**.
- RuboCop nos Ruby/rake alterados/criados: sem infrações após correções (schema gerado excluído).
- ESLint nos JS/Vue alterados: zero erros; dois avisos de chaves i18n dinâmicas nos campos declarados pelo registry.
- Build Vite: aprovado. Build SDK: aprovado.
- Avisos de build: Browserslist desatualizado e chunks grandes upstream; sem alteração de limites para ocultar avisos.
- Não há script de type checking dedicado no package.json; não foi declarado como executado.
- `git diff --check`: aprovado.

## Revisão no navegador

Playwright CLI, Rails local porta 3309 e Vite 3310. Verificados visualmente:

- Listagem Super Admin em desktop 1280×800, tablet 768×1024 e mobile 390×844.
- Formulário global com confirmação de salvamento e chave mascarada, nunca valor real no HTML.
- Formulário de permissões da conta.
- Wizard: apenas provedores permitidos; Baileys/Uazapi indisponíveis não aparecem.
- Criação de inbox Z-API com credenciais fictícias, retorno ao painel de conexão e edição vazia preservando secrets.

Evidências locais em `output/playwright/`: `providers-desktop.png`, `providers-tablet.png`, `providers-mobile.png`,
`provider-secret-masked.png`, `provider-account-mobile.png`, `provider-wizard-desktop.png` e `provider-inbox-created.png`.

A revisão identificou e corrigiu a barra lateral que esmagava o conteúdo mobile, chamada de SDK de suporte sem configuração,
e uso do Axios não autenticado no módulo. O cliente final usa o `ApiClient` compartilhado do dashboard.

Após a correção, as rotas do módulo carregaram e a inbox foi salva. O ambiente local ainda exibe um 404 da rota upstream
`/enterprise/api/v1/accounts/1/limits`, avisos upstream de traduções Meta/Modal e modo de desenvolvimento.
Houve erro transitório de HMR (`BackButton before initialization`) durante edição; desapareceu no carregamento completo.
Portanto, não se declara console global inteiramente limpo nem ambiente local equivalente à configuração de produção.
Busca nos logs locais por marcadores de secrets fictícios não encontrou seus valores em texto claro.

## Pendências de aceite operacional

Não foram executados: conexão real, leitura de QR em aparelho, envio/recebimento bidirecional por provedor, mídia no R2,
validação externa de assinatura/protocolo ou cutover. Não foram anunciadas capabilities de native, grupos/histórico,
presença, reações/edição/revogação, contatos/localização e LID-only.
É necessária uma instância de staging com credenciais válidas e número autorizado para homologar esses adapters antes de produção.
O roteiro está na seção 13 de `whatsapp-providers.md`; a lista de limitações é parte da entrega, não um aceite desses pontos.
