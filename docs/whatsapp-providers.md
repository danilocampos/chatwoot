# Módulo de provedores WhatsApp — implementação e validação

Base: Chatwoot oficial v4.18.0 (`9f920b549`). Referência analisada: `v4.17.0-hablas.2`.
Branch: `codex/whatsapp-providers`. Não publicado; nenhuma alteração em produção.
Esta é uma entrega local do módulo, não uma declaração de homologação operacional de todos os provedores.

## 1. Análise do legado

O legado reúne dois caminhos distintos, não apenas um formulário com mais opções:

| Provedor | Caminho antigo | Credenciais / transporte |
| --- | --- | --- |
| Meta / 360dialog | `Whatsapp::Providers::*Service` | Graph API / HTTP, configuração do canal |
| Twilio WhatsApp | `Channel::TwilioSms` | Conta/token Twilio, canal separado de SMS por `medium` |
| Baileys | `WhatsappBaileysService`, `BaileysHandlers`, `IncomingMessageBaileysService` | API fazer.ai HTTP, chave, sessão por telefone |
| Z-API | `WhatsappZapiService`, `ZapiHandlers`, `IncomingMessageZapiService` | instance ID, token no caminho, Client-Token no header |
| Uazapi | `Whatsapp::Session::Backends::Uazapi` | URL por instância, token no header; webhook com token de instância |
| native (beta) | `Whatsapp::Session::Backends::Connector` | Processo externo de conector e Redis Streams; não é uma API HTTP intercambiável |

Arquivos centrais antigos: `app/models/channel/whatsapp.rb`, `app/models/concerns/account_whatsapp_providers.rb`,
`app/services/whatsapp/session/{registry,provider_descriptor,channel_extension,facade}.rb`,
`app/services/whatsapp/providers/whatsapp_{baileys,zapi}_service.rb`, `app/services/whatsapp/{baileys_handlers,zapi_handlers}/`,
`app/services/whatsapp/session/{inbound,outbound,backends}/`, `app/controllers/webhooks/whatsapp_controller.rb`,
`app/controllers/webhooks/whatsapp/uazapi_controller.rb`, `app/jobs/webhooks/whatsapp{,_session}_events_job.rb`,
`app/jobs/whatsapp/session/`, `app/jobs/channels/whatsapp/` e `config/initializers/{baileys,whatsapp_connector}.rb`.

Envio antigo: dispatcher de canal → service/facade → payload específico. Baileys reserva IDs e envia idempotency metadata;
Uazapi usa `track_id` e retorna `messageid`; Z-API retorna `messageId`. Recebimento autentica o callback, associa canal/inbox,
normaliza contato/conversa e processa em jobs. Baileys usa JIDs/PN/LID; Uazapi traduz eventos canônicos;
Z-API usa telefone e ID externo. Status mapeiam delivery/read/failed e mídia é baixada ou descriptografada pelo provedor.
Baileys possui ainda grupos, presença, histórico, edição e reações com dependências em outros modelos do fork.

Frontend antigo: `BaileysWhatsapp.vue`, `ZapiWhatsapp.vue`, `session/SessionWhatsapp.vue`, `WhatsappLinkDeviceModal.vue`,
`SessionProviderConfiguration.vue`, `WhatsappHistorySync.vue` e helpers de capabilities. Não havia painel completo de configuração
global de provedores. `AccountWhatsappProviders` tinha switches específicos de native/Uazapi em settings, deliberadamente fora do formulário.

Pontos não reutilizados literalmente: logs de respostas externas, serialização de `provider_config` com secrets,
condicionais espalhadas e alterações transversais de grupos/histórico. O conector native exige infraestrutura e contrato próprios.

## 2. Arquitetura atual e implementada

Ruby 3.4.4, Rails 7.2.3.1, Vue 3/Vite, Sidekiq, PostgreSQL. Mantidos os contratos atuais de `Channel::Whatsapp`,
`Whatsapp::Providers::BaseService`, `SendReplyJob`, resolução de contatos/conversas e `Messages::StatusUpdateService`.

A versão 4.18 contém configuração manual Meta V2, mudanças de identidade/BSUID, coexistência, solicitação de dados de contato
e chamadas. Esses arquivos não foram substituídos pelos antigos. A única alteração na janela de atendimento isenta os novos
provedores de sessão da regra de 24 horas; Meta e Twilio continuam usando a regra anterior.

`Whatsapp::ProviderRegistry` é a autoridade de providers suportados, adapter, campos e capabilities. Configuração global fica em
`Whatsapp::ProviderConfiguration`; elegibilidade por cliente em `Account.settings['whatsapp_providers']`.
Nada foi adicionado a `config/features.yml`. A checagem acontece no modelo, cobrindo criação pela API e fluxos oficiais de signup.

## 3. Provedores efetivos e limites

Meta, 360dialog e Twilio conservam seus adapters. Baileys, Z-API e Uazapi têm adapters HTTP novos adaptados dos contratos antigos,
com texto, imagem, áudio, vídeo/documento, reply IDs, estados de entrega e fluxo de QR.
Os testes locais simulam esses contratos; não equivalem a homologação com números reais.

**Não portados:** conector native/Redis Streams, grupos, histórico, presença, edição/revogação, reações, contatos/localização
e resolução completa de JIDs LID-only. Não há capabilities prometendo essas funções. Mensagens/sessões especiais precisam de portabilidade
adicional antes de substituir uma instalação que dependa desses recursos do fork antigo.
Templates permanecem nos provedores oficiais; novos adapters de sessão recusam a operação.

## 4. Configuração e ENV

| Escopo | Configuração |
| --- | --- |
| Global / Super Admin | Ativação, URL base Baileys/Uazapi, chave Baileys criptografada, nome de cliente Baileys, autorização explícita de rede privada |
| Account | Mapa de permissões por nome de provider; somente Super Admin modifica |
| Inbox | Telefone; instance ID/token/client token Z-API; token Uazapi; IDs/tokens oficiais já existentes |
| Gerado no servidor | Webhook token aleatório por inbox; nunca aceito do cliente para novos canais de sessão |
| ENV de boot | PostgreSQL, Redis, SECRET_KEY_BASE, três chaves ACTIVE_RECORD_ENCRYPTION, FRONTEND_URL, R2/Active Storage |

Compatibilidade ENV: `BAILEYS_PROVIDER_DEFAULT_URL`, `BAILEYS_PROVIDER_DEFAULT_API_KEY`, `BAILEYS_PROVIDER_DEFAULT_CLIENT_NAME`
são fallback dinâmico quando não há valor persistido. Para credenciais consumidas pelo adapter: inbox → global → ENV legado.
A URL de infraestrutura usada para novas conexões vem do Super Admin, não de uma URL arbitrária enviada pelo administrador do cliente.
O endpoint Z-API é fixo `https://api.z-api.io`. Endpoints/versões dos serviços oficiais permanecem no mecanismo upstream.

ENV identificadas no legado e deliberadamente não reinterpretadas: `WHATSAPP_GROUPS_ENABLED`, `BAILEYS_WHATSAPP_GROUPS_ENABLED`,
`WHATSAPP_LEGACY_PROVIDERS_CREATABLE`, `BAILEYS_PROVIDER_USE_INTERNAL_HOST_URL`, `INTERNAL_HOST_URL`,
`WHATSAPP_CONNECTOR_ENABLED`, `WHATSAPP_CONNECTOR_CONSUMER`, `WHATSAPP_CONNECTOR_REDIS_PREFIX`,
`WHATSAPP_CONNECTOR_EVENT_SHARDS`, `WHATSAPP_CONNECTOR_REDIS_POOL`, `WHATSAPP_MEDIA_SEND_RATE_BYTES`,
`WHATSAPP_MEDIA_SEND_MAX_TIMEOUT`, `FFMPEG_PATH`. Dependem de recursos não portados ou da infraestrutura de boot.
`WHATSAPP_CLOUD_BASE_URL`, `360DIALOG_BASE_URL`, `WHATSAPP_API_VERSION` e configurações Meta/Twilio existentes não foram removidas.

## 5. Banco e migração

Migration `20260918120000_add_whatsapp_provider_configuration.rb`: tabela global, índice único em `provider`,
coluna TEXT de credenciais criptografadas no canal e JSONB de estado da sessão (preservado caso já exista no legado).
`InstallationConfig` foi analisado e não usado para novos secrets: seu armazenamento/edição/serialização genéricos são plaintext.
Nenhum dado ou canal é apagado. Não execute migração reversa cega: a migration bloqueia rollback destrutivo de credenciais.

Antes de ativar em uma instalação existente, configure e faça backup seguro das três chaves Rails encryption, rode migrations,
depois `bundle exec rails whatsapp:encrypt_provider_credentials`. A tarefa migra em lotes, sem chamadas externas ou mudanças de webhook.
Os canais existentes ainda leem o JSON legado durante a transição; só o backfill elimina o plaintext já armazenado.
Não é uma migração completa do schema fazer.ai para upstream; não aponte este código para o banco antigo sem plano específico.

## 6. Backend

`ProviderRegistry`, `ProviderConfiguration`, `WhatsappProviderCredentials`, adapters `SessionService`, `BaileysService`,
`ZapiService`, `UazapiService`; normalizadores em `Whatsapp::ProviderEvents`; `SessionIncomingService` reutiliza o pipeline 4.18.
`ProviderConnectionJob` executa pareamento; `WhatsappProviderEventsJob` processa eventos em background.
Controller de webhook autentica antes do enqueue; controllers de Super Admin e account têm autorizações separadas.

Timeout de conexão 5s, leitura normal 20s, envio de mídia 60s, teste explícito 5s. Não há retry automático de envio ambíguo.
Webhooks com status antes da mensagem e downloads transitórios possuem retries limitados. Eventos de mensagem são serializados
pelo lock do inbox e deduplicados por `source_id` dentro do inbox; rollback libera o lock e permite reprocessar uma falha.
O lock também cobre download de mídia: prioriza consistência, mas inboxes de grande volume podem precisar de fila de mídia separada.

## 7. Frontend

Wizard `Whatsapp.vue` carrega o catálogo elegível; parâmetro de URL não ignora permissões. `SessionWhatsapp.vue` usa a API de inbox
existente. `ProviderConnection.vue` edita secrets sem exibi-los, testa conexão e conecta/consulta QR (somente administrador).
`ConfigurationPage.vue` integra o painel sem substituir o fluxo oficial. Traduções isoladas en, pt_BR e es; arquivos upstream intactos.

## 8. Uso no Super Admin

Settings → WhatsApp providers: abrir provider, configurar, salvar e habilitar. Teste global disponível para Baileys;
Uazapi/Z-API precisam das credenciais de inbox, onde o teste de conexão é oferecido.
Accounts → abrir cliente → WhatsApp providers: marcar os provedores permitidos e salvar.
Os dois controles precisam estar ativos. Provedores novos começam desligados/sem grants; oficiais mantêm defaults de compatibilidade.

Desativar não corta envio/recebimento existente. Primeira ativação fica bloqueada; uma sessão já ativada pode reconectar.
Trocar instância/token/telefone invalida o estado de conexão e exige elegibilidade atual. Desativação global não é kill switch de tráfego.

## 9. Segurança

Novos secrets usam Active Record Encryption, nunca fallback plaintext. Campos vazios preservam a credencial existente.
As APIs retornam apenas configuração pública; nem `serializable_hash` nem audit logs incluem credenciais.
Twilio deixa de retornar `auth_token` e oferece `auth_token_configured`; valores vazios de edição preservam seu token.
Esse endurecimento é uma mudança intencional para consumidores que antes liam tokens nas respostas: devem guardar suas próprias credenciais.

Baileys exige token de callback; Uazapi exige também token da instância; Z-API usa callback aleatório + instance ID conforme contrato legado.
Não se inventa assinatura HMAC que o provedor não envie. Meta conserva sua verificação atual.
Tokens de callback via query devem ser redigidos também no proxy/Coolify, fora do Rails. HTTPS público é requisito operacional.
Payloads são filtrados antes da fila; parameter wrapping foi desabilitado para impedir cópia aninhada de tokens.
Fingerprint descarta jobs autenticados antes de uma troca de instância/credenciais.

SSRF: endpoints públicos resolvidos pelo SsrfFilter, sem redirects. Rede privada só mediante consentimento do Super Admin para aquele provider.
URLs de mídia externas passam por SafeFetch e limite de 40MB. Credenciais não são encaminhadas para outro host.
Audit usa `Enterprise::AuditLog` quando disponível; CE escreve evento operacional sanitizado, sem criar segunda tabela de auditoria.

## 10. Arquivos

O código está organizado nos diretórios descritos nas seções 5–7. Alterações de integração: models Whatsapp/Twilio,
account settings schema, message window, send service, webhook setup, serializer do inbox, routes, menu/conta do Super Admin e overlay Enterprise de auditoria.
Specs novos cobrem registry, configuração, acesso/criptografia do canal, controllers, jobs, normalização e transporte.
Inventário completo desta entrega: `whatsapp-providers-files.md`.
O inventário do diff legado relevante está em `whatsapp-providers-legacy-files.tsv`.

## 11. Compatibilidade

Não foram substituídos os services oficiais, canais de outras plataformas, autenticação, automações ou dispatcher de envio.
Rotas oficiais Meta permanecem intactas; novos webhooks têm namespace separado. Twilio SMS não passa pelo gate WhatsApp.
As chaves de criptografia passam a ser obrigatórias para gravar credenciais WhatsApp; instalações sem elas precisam configurar antes do upgrade.

## 12. Verificação

Resultados finais são registrados em `whatsapp-providers-validation.md`, incluindo comandos, testes, build e evidência visual.
Não existe script dedicado de type checking no `package.json` upstream; não foi inventada uma execução equivalente.

## 13. Roteiro manual / homologação

1. Usar staging isolado com as migrations, Rails encryption e Sidekiq; configurar FRONTEND_URL HTTPS e R2.
2. Configurar provider no Super Admin; verificar máscara após salvar e após edição com campo secreto vazio.
3. Liberar apenas para a conta A. Confirmar que conta B não vê a opção e recebe erro se tentar criar pela API.
4. Na conta A, criar inbox, preencher credenciais da instância e testar conexão. Conectar, ler QR com número de teste e confirmar estado aberto.
5. Enviar/receber texto, imagem, áudio, vídeo e documento, pelo painel e API; verificar reply IDs e status delivered/read.
6. Reenviar o mesmo webhook: só uma mensagem. Testar token incorreto, canal inexistente, provider desconhecido e troca de credenciais com job pendente.
7. Desativar globalmente: nova criação/primeira ativação negadas, tráfego do inbox existente mantido. Repetir revogação por cliente.
8. Simular API indisponível e timeout; confirmar erro genérico e ausência de retry automático de envio incerto.
9. Conferir logs Rails, Sidekiq e proxy sem tokens; validar leitura de anexos no R2 e número correto pareado.
10. Homologar explicitamente as limitações da seção 3 antes de cutover de qualquer canal produtivo.

## 14. Pontos de atenção

Não houve pareamento ou tráfego real nesta tarefa. Nenhum provider externo, DNS, Coolify, R2 ou banco de produção foi alterado.
O critério de prontidão operacional depende da homologação acima. A configuração Meta embedded já existente em InstallationConfig
não foi migrada para este novo modelo; este módulo não é uma reescrita geral do cofre de secrets da instalação.
QR é credencial temporária restrita a administradores: armazenado junto às credenciais criptografadas, fora do JSONB de estado.
O envelope do job de webhook também é criptografado, e os campos QR são filtrados nos logs HTTP. Rails e Sidekiq precisam das mesmas chaves.
Não copiar capturas contendo QR real para relatórios. A associação do webhook é autenticada por canal, mas a conferência do número
efetivamente pareado ainda é manual; não há quarentena automática de uma instância Uazapi/Z-API pareada com número diferente.
Código interno que altera `provider_config` deve reatribuir o hash (`channel.provider_config = channel.provider_config.merge(...)`),
pois sua leitura compõe o JSON público com as credenciais criptografadas; mutação isolada do hash retornado não persiste.

## 15. Próximos passos

Homologar com instâncias/números dedicados. Completar paridade de eventos especiais (PN/LID, contatos/localização, grupos/histórico/reações)
e conector native com sua suíte de contrato antes de anunciá-los no registry. Só então cortar release/imagem do fork e publicar no Coolify.
Não utilizar a imagem oficial imutável para tentar publicar estas mudanças locais.
