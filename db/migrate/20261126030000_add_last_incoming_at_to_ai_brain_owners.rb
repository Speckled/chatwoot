# When each owner last wrote to each AI Brain WhatsApp inbox, keyed by inbox id: their messages never reach Chatwoot's
# messages, and WhatsApp's 24-hour window for the AI Brain's own messages to them counts from it. Existing rows start empty.
class AddLastIncomingAtToAiBrainOwners < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_brain_owners, :last_incoming_at, :jsonb, default: {}, null: false
  end
end
