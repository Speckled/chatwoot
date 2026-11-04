require 'rails_helper'

describe AiBrain::ResponseJob do
  let(:account) { create(:account) }
  let(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
  end
  let(:inbox) { whatsapp_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5551999998888') }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox, status: :pending)
  end
  let(:goodbye) { create(:message, conversation: conversation, account: account, inbox: inbox, message_type: :incoming, content: 'Obrigada, tchau!') }
  let(:farewell) { 'Foi um prazer te atender, Luiza! Até a próxima e boa consulta com o Dr. Rafael.' }
  let(:client) { instance_double(AiBrain::Client) }

  before do
    AiBrainInbox.create!(account: account, inbox: inbox, active: true)
    inbox.update!(csat_survey_enabled: true, csat_config: { 'message' => 'Muito obrigado pelo contato!', 'button_text' => 'Avaliar atendimento' })
    allow(AiBrain::Client).to receive(:new).and_return(client)
    allow(client).to receive(:send_session_message).and_return(
      [200, { 'outcome' => 4, 'sessionId' => 'session-1', 'outgoingMessageId' => 'outgoing-1', 'textToSend' => farewell }]
    )
    allow(client).to receive(:confirm_delivery)
  end

  context 'when the AI Brain closes the session' do
    it 'sends the farewell as the CSAT survey, so resolving adds no survey of its own' do
      described_class.perform_now(goodbye.id)
      CsatSurveyService.new(conversation: conversation.reload).perform

      expect(conversation).to be_resolved
      expect(conversation.messages.where(content_type: :input_csat).pluck(:content)).to eq([farewell])
    end

    it 'sends the farewell as text when CSAT is off' do
      inbox.update!(csat_survey_enabled: false)

      described_class.perform_now(goodbye.id)

      expect(conversation.messages.outgoing.last).to have_attributes(content: farewell, content_type: 'text')
    end
  end
end
