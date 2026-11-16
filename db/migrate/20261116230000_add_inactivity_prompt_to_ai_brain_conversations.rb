# The inactivity prompt a person's AI Brain conversation shows (LRB-85): the question whether the patient's issue is solved,
# the person's answer, or the mandatory close. The backend asks for it; any message or the close clears it.
class AddInactivityPromptToAiBrainConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_brain_conversations, :inactivity_prompt, :string
    add_column :ai_brain_conversations, :inactivity_prompted_at, :datetime
  end
end
