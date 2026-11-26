# AiBrain::BotSender asks the AI Brain backend for the assistant's name the first time it posts in an account. Specs never
# reach the backend: the name is unknown, so the bot stays 'AI Brain' and unmarked, as before. bot_sender_spec calls the
# original.
RSpec.configure do |config|
  config.before do
    allow(AiBrain::BotSender).to receive(:assistant_name).and_return(nil)
  end
end
