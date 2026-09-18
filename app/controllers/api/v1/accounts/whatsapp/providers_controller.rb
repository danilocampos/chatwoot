class Api::V1::Accounts::Whatsapp::ProvidersController < Api::V1::Accounts::BaseController
  before_action :require_administrator
  before_action :load_session_channel, only: [:show, :connect, :test_connection]

  def index
    render json: Whatsapp::ProviderRegistry.for_account(Current.account).map { |entry| entry.to_h.except(:service, :default_enabled) }
  end

  def show
    state = @channel.provider_connection.slice('connection', 'error')
    state['qr_data_url'] = @channel.provider_credentials['qr_data_url']
    # QR credentials are restricted to an authorized administrator and never broadcast.
    response.headers['Cache-Control'] = 'no-store'
    render json: state.merge(fields: Whatsapp::ProviderRegistry.fetch(@channel.provider).fields,
                             config: @channel.public_provider_config)
  end

  def connect
    unless @channel.provider_connection['activated'] || Whatsapp::ProviderRegistry.available?(@channel.provider, Current.account)
      return head :forbidden
    end

    Whatsapp::ProviderConnectionJob.perform_later(@channel)
    head :accepted
  end

  def test_connection
    @channel.provider_service.test_connection
    render json: { success: true }
  rescue Whatsapp::Providers::SessionService::Error
    render json: { success: false }, status: :unprocessable_entity
  end

  private

  def load_session_channel
    inbox = Current.account.inboxes.find(params[:id])
    authorize inbox, :update?
    @channel = inbox.channel
    head :not_found unless inbox.whatsapp? && @channel.session_provider?
  end

  def require_administrator
    head :forbidden unless Current.account_user&.administrator?
  end
end
