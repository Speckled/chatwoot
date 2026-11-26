# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain session outbound API', type: :request do
  let(:account) { create(:account) }
  let(:channel) do
    Channel::Whatsapp.create!(account: account, phone_number: '+5511999990000', provider: 'test', provider_config: { 'source' => 'ai_brain_test' })
  end
  let!(:inbox) do
    inbox = create(:inbox, account: account, channel: channel, csat_survey_enabled: true)
    AiBrainInbox.create!(account: account, inbox: inbox, active: true)
    inbox
  end
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :open) }
  let(:url) { '/api/v1/apps/chatwoot-main/sessions/session-1/messages/outbound' }
  let(:headers) { { 'X-Api-Key' => 'test-key' } }
  let(:survey) { CsatSurveyService.new(conversation: conversation.reload) }

  around { |example| with_modified_env(AI_BRAIN_API_KEY: 'test-key') { example.run } }

  # The patient's message puts the conversation inside the CSAT window, so only the mark keeps the survey away.
  before { create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming) }

  def close(text)
    post url, headers: headers, params: { chatwootConversationId: conversation.id, outcome: 'SessionClosed', textToSend: text }, as: :json
  end

  it 'resolves a conversation closed for inactivity without a message and without a CSAT survey' do
    close('')

    expect(response).to have_http_status(:ok)
    expect(conversation.reload).to be_resolved
    expect(conversation.messages.outgoing).to be_empty
    expect(conversation.ai_brain_silent_close?).to be(true)
    expect(survey.due?).to be(false)
    expect { survey.perform }.not_to(change { conversation.messages.count })
    expect(conversation.messages.where(content_type: :input_csat)).to be_empty
  end

  it 'sends the survey again once the conversation is reopened and a person resolves it' do
    close('')
    conversation.reload.update!(status: :open)
    expect(conversation.reload.ai_brain_silent_close?).to be(false)

    conversation.update!(status: :resolved)

    expect(survey.due?).to be(true)
  end

  it 'sends the template the AI Brain gives in place of the text, and shows the text in the conversation' do
    post url, headers: headers, params: { chatwootConversationId: conversation.id, outcome: 'Reply', textToSend: 'Resposta da clínica: sim.',
                                          template: { name: 'resposta', language: 'pt_BR', category: 'UTILITY', bodyParameters: ['sim'] } },
              as: :json

    message = conversation.messages.outgoing.last
    expect(message.content).to eq('Resposta da clínica: sim.')
    expect(message.additional_attributes['template_params'])
      .to eq('name' => 'resposta', 'language' => 'pt_BR', 'category' => 'UTILITY', 'processed_params' => { 'body' => { '1' => 'sim' } })
  end

  it 'keeps the survey for a close that says goodbye' do
    close('Até logo!')

    expect(conversation.reload).to be_resolved
    expect(conversation.ai_brain_silent_close?).to be(false)
    expect(conversation.messages.outgoing.pluck(:content, :content_type)).to eq([['Até logo!', 'input_csat']])
  end
end
