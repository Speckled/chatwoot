class UpdateAiBrainForSessions < ActiveRecord::Migration[7.1]
  def change
    change_column_null :ai_brain_inboxes, :agent_definition_id, true

    add_column :ai_brain_conversations, :session_id, :uuid
    add_column :ai_brain_conversations, :active_workflow, :string
    add_column :ai_brain_conversations, :client_id, :uuid
    add_index :ai_brain_conversations, :session_id
  end
end
