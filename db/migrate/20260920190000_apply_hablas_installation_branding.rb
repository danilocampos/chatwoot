class ApplyHablasInstallationBranding < ActiveRecord::Migration[7.1]
  BRANDING = {
    'INSTALLATION_NAME' => 'Hablas',
    'LOGO' => '/brand-assets/hablas_logo.svg',
    'LOGO_DARK' => '/brand-assets/hablas_logo_dark.svg',
    'LOGO_THUMBNAIL' => '/brand-assets/hablas_logo_thumbnail.png?v=hablas-20260920-rounded',
    'LOGO_EMAIL' => '/brand-assets/hablas_logo_thumbnail.png?v=hablas-20260920-rounded',
    'BRAND_URL' => 'https://hablas.chat',
    'WIDGET_BRAND_URL' => 'https://hablas.chat',
    'BRAND_NAME' => 'Hablas',
    'BRAND_COLOR' => '#176099'
  }.freeze

  def up
    BRANDING.each { |name, value| InstallationConfig.find_by!(name: name).update!(value: value) }
    GlobalConfig.clear_cache
  end

  def down
    GlobalConfig.clear_cache
  end
end
