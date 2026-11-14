# The WhatsApp inbox an account's admin assistant sends its alerts through, chosen on the AI Brain overview, and the
# inbox each owner last wrote through, the fallback while none is chosen. Existing rows get no choice and no last inbox.
class AddOwnerAssistantInboxToAiBrain < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_brain_inboxes, :owner_assistant, :boolean, default: false, null: false
    add_index :ai_brain_inboxes, :account_id, unique: true, where: 'owner_assistant', name: 'index_ai_brain_inboxes_on_owner_assistant'
    add_column :ai_brain_owners, :last_inbox_id, :bigint
  end
end
