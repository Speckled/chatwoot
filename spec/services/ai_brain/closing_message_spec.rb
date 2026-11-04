require 'rails_helper'

describe AiBrain::ClosingMessage do
  let(:account) { create(:account) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:inbox) { whatsapp_channel.inbox }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  before { inbox.update!(csat_survey_enabled: true) }

  describe '.content_type' do
    it 'is the survey when resolving the conversation would send one' do
      expect(described_class.content_type(conversation)).to eq(:input_csat)
    end

    it 'is text when CSAT is off' do
      inbox.update!(csat_survey_enabled: false)

      expect(described_class.content_type(conversation)).to eq(:text)
    end

    it 'is text once the conversation has a survey' do
      create(:message, conversation: conversation, inbox: inbox, account: account, content_type: :input_csat)

      expect(described_class.content_type(conversation)).to eq(:text)
    end

    it 'is text on an inbox that sends the survey as a link in the text' do
      dialog_channel = create(:channel_whatsapp, account: account, provider: 'default', sync_templates: false, validate_provider_config: false)
      dialog_inbox = dialog_channel.inbox
      dialog_inbox.update!(csat_survey_enabled: true)

      expect(described_class.content_type(create(:conversation, account: account, inbox: dialog_inbox))).to eq(:text)
    end
  end
end
