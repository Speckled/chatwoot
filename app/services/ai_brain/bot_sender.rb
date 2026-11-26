# The bot that posts and acts for the AI Brain in an account: one per account, marked in bot_config and named after the
# clinic's assistant (the backend's business rules hold the name). Bots made before the marker were found by the name
# 'AI Brain'; the first call marks that same bot, so its messages stay with it.
class AiBrain::BotSender
  MARKER = 'ai_brain'.freeze
  UNNAMED = 'AI Brain'.freeze

  class << self
    # The account's bot. Until one is marked, the name is asked of the backend outside the account lock; when the backend
    # cannot answer, the bot is found or made as 'AI Brain' and left unmarked, so a later call names it. Messages never
    # wait for the name.
    def for(account)
      marked(account) || adopt(account, assistant_name)
    end

    # Renames the account's bot, marking it first when it was not yet.
    def rename(account, name)
      account.with_lock do
        bot = marked(account) || unnamed(account)
        bot.update!(name: name, bot_config: (bot.bot_config || {}).merge(MARKER => true))
        bot
      end
    end

    # The clinic's assistant name from the backend, or nil when it cannot be had now.
    def assistant_name
      status, body = AiBrain::Client.new.get('business-rules')
      body['assistantName'].presence if status == 200 && body.is_a?(Hash)
    rescue AiBrain::Client::UnavailableError => e
      Rails.logger.warn("AI Brain bot name unavailable: #{e.message}")
      nil
    end

    private

    def adopt(account, name)
      account.with_lock do
        marked(account) || begin
          bot = unnamed(account)
          bot.update!(name: name, bot_config: (bot.bot_config || {}).merge(MARKER => true)) if name
          bot
        end
      end
    end

    def marked(account)
      account.agent_bots.where('bot_config @> ?', { MARKER => true }.to_json).order(:id).first
    end

    def unnamed(account)
      account.agent_bots.find_or_create_by!(name: UNNAMED, outgoing_url: nil)
    end
  end
end
