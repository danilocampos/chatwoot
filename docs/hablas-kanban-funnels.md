# Funis do Kanban Hablas

Implementação própria sobre a versão Hablas existente. Não utiliza a imagem,
código privado ou ativação comercial do sendingtk; não representa paridade com
todos os recursos daquele produto.

## Uso

- No Kanban, selecione **Novo funil** como administrador e informe nome e etapas.
- Cada funil aceita de 1 a 20 etapas, que podem ser renomeadas ou reordenadas.
- O botão de transferência de cada cartão permite escolher outro funil e etapa.
- Arraste cartões para mover entre etapas do funil atual.
- Filtros e exportação CSV respeitam o funil selecionado e as permissões das caixas.
- Agentes podem usar os funis; somente administradores podem configurá-los.
- Para remover uma etapa ocupada, transfira as conversas antes de editar o funil.

O funil padrão continua com suas cinco etapas originais. As conversas existentes
permanecem nele sem necessidade de redistribuição. O vínculo com um funil é da
conversa, não do contato; cada conversa pertence a um único funil por vez.

## Publicação

A mudança requer a migration `20260918040000_create_kanban_funnels` e novos assets
do frontend na mesma release. Siga o fluxo de release do repositório, execute
`bundle exec rails db:chatwoot_prepare` com a nova imagem e atualize web e worker.
Enviar esta branch ao GitHub não altera o ambiente de produção.

Antes de reverter para uma versão sem funis, devolva as conversas ao funil padrão:
versões antigas não compreendem a separação dos funis personalizados. Não execute
o rollback destrutivo da tabela se houver funis configurados.

Esta etapa ainda não inclui automações por etapa, valor de negócio ou relatórios
de conversão. Exclusão de funis também não está disponível nesta versão.
