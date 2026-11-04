class CreateAiBrainOwners < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_brain_owners do |t|
      t.references :account, null: false
      t.references :user, null: false
      t.string :phone_number, null: false
      t.timestamps
    end
    add_index :ai_brain_owners, :phone_number, unique: true
  end
end
