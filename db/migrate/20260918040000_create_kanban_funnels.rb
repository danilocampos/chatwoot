class CreateKanbanFunnels < ActiveRecord::Migration[7.1]
  def change
    create_table :kanban_funnels do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :stages, null: false, default: []
      t.timestamps
    end
  end
end
