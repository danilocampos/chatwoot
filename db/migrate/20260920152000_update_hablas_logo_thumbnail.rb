class UpdateHablasLogoThumbnail < ActiveRecord::Migration[7.1]
  LOGO_THUMBNAIL = '/brand-assets/hablas_logo_thumbnail.png?v=hablas-20260920'.freeze

  def up
    update_value('LOGO_THUMBNAIL')
    update_value('LOGO_EMAIL')
    GlobalConfig.clear_cache
  end

  def down
    update_value('LOGO_THUMBNAIL', '/brand-assets/hablas_logo_thumbnail.png')
    update_value('LOGO_EMAIL', '/brand-assets/hablas_logo_thumbnail.png')
    GlobalConfig.clear_cache
  end

  private

  def update_value(name, value = LOGO_THUMBNAIL)
    InstallationConfig.find_by!(name: name).update!(value: value)
  end
end
