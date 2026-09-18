class KanbanFunnel < ApplicationRecord
  belongs_to :account

  validates :name, presence: true, length: { maximum: 80 }
  validate :validate_stages
  validate :preserve_occupied_stages, on: :update

  def stage_ids
    stages.pluck('id')
  end

  private

  def validate_stages
    valid = stages.is_a?(Array) && stages.length.between?(1, 20) && stages.all? do |stage|
      stage.is_a?(Hash) && stage['id'].is_a?(String) && stage['id'].match?(/\A[a-zA-Z0-9_-]{1,64}\z/) &&
        stage['name'].is_a?(String) && stage['name'].strip.length.between?(1, 80)
    end
    valid &&= stage_ids.uniq.length == stages.length
    errors.add(:stages, :invalid) unless valid
  end

  def preserve_occupied_stages
    return unless stages_changed? && errors[:stages].empty?

    removed = stages_in_database.pluck('id') - stage_ids
    return if removed.empty?
    return unless account.conversations.where("custom_attributes->>'kanban_funnel_id' = ?", id.to_s)
                         .where("custom_attributes->>'kanban_status' IN (?)", removed).exists?

    errors.add(:stages, :invalid)
  end
end
