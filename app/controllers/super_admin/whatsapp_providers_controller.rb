class SuperAdmin::WhatsappProvidersController < SuperAdmin::ApplicationController
  before_action :load_provider, only: [:show, :update, :test_connection]

  def index
    @providers = Whatsapp::ProviderRegistry::DEFINITIONS.values
    @configurations = Whatsapp::ProviderConfiguration.all.index_by(&:provider)
  end

  def show; end

  def update
    @configuration.assign_configuration(configuration_params)
    if @configuration.save
      audit_change(@configuration, 'provider_configured', {
                     'enabled' => @configuration.enabled?,
                     'credentials_changed' => @configuration.saved_change_to_credentials?
                   })
      redirect_to super_admin_whatsapp_provider_path(@definition.id), notice: t('whatsapp_providers.saved')
    else
      flash.now[:error] = t('whatsapp_providers.invalid_configuration')
      render :show, status: :unprocessable_entity
    end
  end

  def test_connection
    unless @definition.id == 'baileys'
      return redirect_to(super_admin_whatsapp_provider_path(@definition.id),
                         alert: t('whatsapp_providers.test_per_inbox'))
    end

    channel = Channel::Whatsapp.new(provider: @definition.id, provider_config: {})
    channel.provider_service.test_connection
    redirect_to super_admin_whatsapp_provider_path(@definition.id), notice: t('whatsapp_providers.connected')
  rescue Whatsapp::Providers::SessionService::Error, KeyError
    redirect_to super_admin_whatsapp_provider_path(@definition.id), alert: t('whatsapp_providers.connection_failed')
  end

  def account
    @account = Account.find(params[:account_id])
    @providers = Whatsapp::ProviderRegistry::DEFINITIONS.values
  end

  def update_account
    @account = Account.find(params[:account_id])
    submitted = params.fetch(:providers, ActionController::Parameters.new).permit(*Whatsapp::ProviderRegistry::DEFINITIONS.keys).to_h
    grants = Whatsapp::ProviderRegistry::DEFINITIONS.keys.index_with { |key| submitted[key] == '1' }
    @account.with_lock { @account.update!(settings: @account.settings.merge('whatsapp_providers' => grants)) }
    audit_change(@account, 'provider_access_updated', grants)
    redirect_to account_super_admin_whatsapp_providers_path(account_id: @account.id), notice: t('whatsapp_providers.saved')
  end

  private

  def load_provider
    @definition = Whatsapp::ProviderRegistry::DEFINITIONS[params[:id]]
    raise ActiveRecord::RecordNotFound unless @definition

    @configuration = Whatsapp::ProviderConfiguration.find_or_initialize_by(provider: @definition.id)
    @configuration.enabled = @definition.default_enabled if @configuration.new_record?
  end

  def configuration_params
    values = params.require(:configuration).permit(:enabled, *Whatsapp::ProviderConfiguration::SETTINGS,
                                                   *Whatsapp::ProviderConfiguration::SECRETS).to_h
    %w[enabled allow_private_network].each { |key| values[key] = values[key] == '1' if values.key?(key) }
    values
  end

  def audit_change(record, action, fields)
    # Reuse Enterprise audit when installed; Community retains a sanitized operational event.
    if defined?(Enterprise::AuditLog)
      Enterprise::AuditLog.create!(auditable: record, user: current_super_admin, action: 'update',
                                   audited_changes: { 'whatsapp_providers' => { 'event' => action, 'fields' => fields } })
    else
      Rails.logger.info("[WHATSAPP PROVIDERS] event=#{action} actor_id=#{current_super_admin.id} record_id=#{record.id}")
    end
  end
end
