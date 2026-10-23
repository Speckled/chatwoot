class CreateAiBrainInboxes < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_brain_inboxes do |t|
      t.references :account, null: false, index: true
      t.references :inbox, null: false, index: { unique: true }
      t.uuid :agent_definition_id, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :ai_brain_inboxes, [:account_id, :agent_definition_id]

    create_table :ai_brain_conversations do |t|
      t.references :account, null: false
      t.references :conversation, null: false, index: { unique: true }
      t.string :state, null: false, default: 'bot'
      t.uuid :review_id
      t.bigint :source_message_id
      t.timestamps
    end
  end
end
