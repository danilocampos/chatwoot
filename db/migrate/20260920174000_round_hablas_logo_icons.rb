class RoundHablasLogoIcons < ActiveRecord::Migration[7.1]
  LOGO_THUMBNAIL = '/brand-assets/hablas_logo_thumbnail.png?v=hablas-20260920-rounded'.freeze

  def up
    InstallationConfig.find_by!(name: 'LOGO_THUMBNAIL').update!(value: LOGO_THUMBNAIL)
    InstallationConfig.find_by!(name: 'LOGO_EMAIL').update!(value: LOGO_THUMBNAIL)
    GlobalConfig.clear_cache
  end

  def down
    InstallationConfig.find_by!(name: 'LOGO_THUMBNAIL').update!(value: '/brand-assets/hablas_logo_thumbnail.png?v=hablas-20260920')
    InstallationConfig.find_by!(name: 'LOGO_EMAIL').update!(value: '/brand-assets/hablas_logo_thumbnail.png?v=hablas-20260920')
    GlobalConfig.clear_cache
  end
end
