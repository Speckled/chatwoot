class AiBrain::BotSender
  def self.for(account)
    account.with_lock do
      account.agent_bots.find_or_create_by!(name: 'AI Brain', outgoing_url: nil)
    end
  end
end
