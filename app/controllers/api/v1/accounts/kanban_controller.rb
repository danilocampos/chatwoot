class Api::V1::Accounts::KanbanController < Api::V1::Accounts::BaseController
  STATUSES = %w[novo_lead aquecimento qualificado convertido perdido].freeze
  BOARD_LIMIT = 500

  before_action :authorize_index!, only: [:index, :export]
  before_action :conversation, only: [:move]
  before_action :set_funnel

  def index
    conversations = filtered_conversations.limit(BOARD_LIMIT + 1).to_a
    truncated = conversations.length > BOARD_LIMIT
    conversations = conversations.first(BOARD_LIMIT)

    render json: {
      kanban_data: grouped_conversations(conversations),
      stats: stats(conversations),
      meta: { limit: BOARD_LIMIT, truncated: truncated }
    }
  end

  def move
    # Serialize stage edits and moves through the same funnel lock.
    @funnel ? @funnel.with_lock { move_to_stage } : move_to_stage
  end

  def export
    conversations = filtered_conversations.limit(BOARD_LIMIT)

    render json: { data: conversations.map { |conversation| serialize_export_row(conversation) } }
  end

  private

  def set_funnel
    @funnel = Current.account.kanban_funnels.find(params[:funnel_id]) if params[:funnel_id].present?
  end

  def statuses
    @funnel ? @funnel.stage_ids : STATUSES
  end

  def move_to_stage
    status = params.require(:status)
    return render json: { error: 'invalid_status' }, status: :unprocessable_content unless statuses.include?(status)

    @conversation.with_lock do
      attributes = @conversation.custom_attributes.to_h.merge('kanban_status' => status)
      @funnel ? attributes['kanban_funnel_id'] = @funnel.id.to_s : attributes.delete('kanban_funnel_id')
      @conversation.update!(custom_attributes: attributes)
    end
    render json: { conversation: serialize_conversation(@conversation.reload) }
  end

  def authorize_index!
    authorize Conversation, :index?
  end

  def conversation
    scope = Conversations::PermissionFilterService.new(Current.account.conversations, Current.user, Current.account).perform
    @conversation = scope.find_by!(display_id: params[:id])
    authorize @conversation, :show?
  end

  def filtered_conversations
    scope = Conversations::PermissionFilterService.new(Current.account.conversations, Current.user, Current.account).perform
    scope = scope
            .select(<<~SQL.squish)
              conversations.*,
              (SELECT COUNT(*) FROM messages WHERE messages.conversation_id = conversations.id) AS messages_count
            SQL
            .includes(:assignee, :contact, :inbox)
            .order(last_activity_at: :desc, id: :desc)
    scope = if @funnel
              scope.where("conversations.custom_attributes->>'kanban_funnel_id' = ?", @funnel.id.to_s)
            else
              scope.where("NULLIF(conversations.custom_attributes->>'kanban_funnel_id', '') IS NULL")
            end
    scope = filter_by_status(scope)
    scope = filter_by_temperature(scope)
    scope = filter_by_score(scope)
    scope = filter_by_search(scope)
    filter_by_inbox(scope)
  end

  def filter_by_status(scope)
    return scope if params[:status].blank?
    return scope.none unless statuses.include?(params[:status])

    if params[:status] == statuses.first
      return scope if statuses.one?

      scope.where("COALESCE(conversations.custom_attributes->>'kanban_status', '') NOT IN (?)", statuses.drop(1))
    else
      scope.where("conversations.custom_attributes->>'kanban_status' = ?", params[:status])
    end
  end

  def filter_by_temperature(scope)
    return scope if params[:temperatura].blank?

    scope.left_joins(:contact).where("contacts.custom_attributes->>'temperatura' = ?", params[:temperatura])
  end

  def filter_by_score(scope)
    ranges = { 'alto' => 70..100, 'medio' => 40..69, 'baixo' => 0..39 }
    range = ranges[params[:score]]
    return scope unless range

    score_sql = <<~SQL.squish
      CASE
        WHEN contacts.custom_attributes->>'lead_score' ~ '^\\d+$'
        THEN (contacts.custom_attributes->>'lead_score')::integer
        ELSE 0
      END
    SQL
    scope.left_joins(:contact).where("#{score_sql} BETWEEN ? AND ?", range.begin, range.end)
  end

  def filter_by_search(scope)
    return scope if params[:search].blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search].strip)}%"
    scope.left_joins(:contact).where('contacts.name ILIKE :query OR contacts.phone_number ILIKE :query', query: query)
  end

  def filter_by_inbox(scope)
    return scope if params[:inbox_id].blank?

    scope.where(inbox_id: params[:inbox_id])
  end

  def grouped_conversations(conversations)
    grouped = statuses.index_with { [] }
    conversations.each { |conversation| grouped[kanban_status(conversation)] << serialize_conversation(conversation) }
    grouped
  end

  def stats(conversations)
    temperatures = { 'quente' => 0, 'morno' => 0, 'frio' => 0 }
    conversations.each do |conversation|
      temperature = conversation.contact&.custom_attributes.to_h['temperatura']
      temperature = 'frio' unless temperatures.key?(temperature)
      temperatures[temperature] += 1
    end

    { total: conversations.length, by_temperatura: temperatures }
  end

  def kanban_status(conversation)
    status = conversation.custom_attributes.to_h['kanban_status']
    statuses.include?(status) ? status : statuses.first
  end

  def serialize_conversation(conversation)
    contact = conversation.contact

    {
      id: conversation.display_id,
      kanban_status: kanban_status(conversation),
      kanban_funnel_id: @funnel&.id,
      contact: {
        id: contact&.id,
        name: contact&.name,
        phone_number: contact&.phone_number,
        custom_attributes: contact&.custom_attributes.to_h
      },
      inbox: { id: conversation.inbox_id, name: conversation.inbox&.name },
      assignee: conversation.assignee && { id: conversation.assignee_id, name: conversation.assignee.name },
      messages_count: messages_count(conversation),
      last_activity_at: conversation.last_activity_at
    }
  end

  def serialize_export_row(conversation)
    contact = conversation.contact
    attributes = contact&.custom_attributes.to_h

    {
      conversation_id: conversation.display_id,
      nome: contact&.name,
      telefone: contact&.phone_number,
      email: contact&.email,
      status: kanban_status(conversation),
      lead_score: attributes.to_h['lead_score'],
      temperatura: attributes.to_h['temperatura'],
      servico_interesse: attributes.to_h['servico_interesse'],
      ultimo_contato: conversation.last_activity_at,
      total_mensagens: messages_count(conversation),
      inbox: conversation.inbox&.name,
      atribuido_a: conversation.assignee&.name
    }
  end

  def messages_count(conversation)
    return conversation[:messages_count] if conversation.has_attribute?(:messages_count)

    conversation.messages.count
  end
end
