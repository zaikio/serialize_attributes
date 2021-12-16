class AddMyModels < ActiveRecord::Migration[6.1]
  def change
    create_table :my_models do |t|
      t.text :normal_column
      t.jsonb :data, null: false, default: {}
    end
  end
end
