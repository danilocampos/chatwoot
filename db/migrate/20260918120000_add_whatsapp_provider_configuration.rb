class AddWhatsappProviderConfiguration < ActiveRecord::Migration[7.2]
  def up
    create_table :whatsapp_provider_configurations do |t|
      t.string :provider, null: false
      t.boolean :enabled, null: false, default: false
      t.jsonb :settings, null: false, default: {}
      t.text :credentials
      t.timestamps
    end
    add_index :whatsapp_provider_configurations, :provider, unique: true
    add_column :channel_whatsapp, :provider_credentials, :text
    add_column :channel_whatsapp, :provider_connection, :jsonb, default: {}, null: false unless column_exists?(:channel_whatsapp,
                                                                                                               :provider_connection)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Encrypted credentials must be exported or reconfigured before removing this module.'
  end
end
