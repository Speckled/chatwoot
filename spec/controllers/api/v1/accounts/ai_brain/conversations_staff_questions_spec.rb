# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain staff question answers', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:conversation) { create(:conversation, account: account) }
  let(:client) { instance_double(AiBrain::Client) }
  let(:question_id) { SecureRandom.uuid }
  let(:session_id) { SecureRandom.uuid }
  let(:outgoing_id) { SecureRandom.uuid }
  let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/conversations/#{conversation.display_id}/staff_questions/#{question_id}/answer" }

  before do
    allow(AiBrain::Client).to receive(:new).and_return(client)
    allow(client).to receive(:post).and_return([200, { 'questionId' => question_id, 'sessionId' => session_id, 'outgoingMessageId' => outgoing_id,
                                                       'textToSend' => 'Resposta da clínica: sim.' }])
    allow(client).to receive(:confirm_delivery).and_return([200, {}])
  end

  it 'posts the answer as the bot once and confirms its delivery' do
    2.times { post url, headers: admin.create_new_auth_token, params: { text: 'Sim.' }, as: :json }

    expect(response).to have_http_status(:no_content)
    sent = conversation.messages.where(message_type: :outgoing, private: false)
    expect(sent.pluck(:content)).to eq(['Resposta da clínica: sim.'])
    expect(sent.first.sender).to eq(AiBrain::BotSender.for(account))
    expect(client).to have_received(:post).with("staff-questions/#{question_id}/answer", operatorId: admin.id, text: 'Sim.', saveAsFaq: false).twice
    expect(client).to have_received(:confirm_delivery)
      .with(session_id: session_id, outgoing_message_id: outgoing_id, chatwoot_message_id: sent.first.id).twice
  end

  it 'posts the answer carrying the template the AI Brain gives outside the 24-hour window' do
    allow(client).to receive(:post).and_return([200, { 'questionId' => question_id, 'sessionId' => session_id, 'outgoingMessageId' => outgoing_id,
                                                       'textToSend' => 'Resposta da clínica: sim.',
                                                       'template' => { 'name' => 'resposta', 'language' => 'pt_BR', 'bodyParameters' => ['sim'] } }])

    post url, headers: admin.create_new_auth_token, params: { text: 'Sim.' }, as: :json

    sent = conversation.messages.find_by(message_type: :outgoing, private: false)
    expect(sent.content).to eq('Resposta da clínica: sim.')
    expect(sent.additional_attributes['template_params'])
      .to eq('name' => 'resposta', 'language' => 'pt_BR', 'processed_params' => { 'body' => { '1' => 'sim' } })
  end

  it 'posts nothing and says why when the answer may not be sent' do
    allow(client).to receive(:post).and_return([200, { 'questionId' => question_id, 'sessionId' => session_id, 'textToSend' => 'Resposta.',
                                                       'skippedReason' => 'Outside the 24-hour window and no approved template.' }])

    post url, headers: admin.create_new_auth_token, params: { text: 'Sim.' }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq('sent' => false, 'reason' => 'Outside the 24-hour window and no approved template.')
    expect(conversation.messages.where(message_type: :outgoing)).to be_empty
    expect(client).not_to have_received(:confirm_delivery)
  end

  it 'lists the open questions with the conversation state' do
    allow(client).to receive(:get).and_return([200, [{ 'id' => question_id, 'status' => 'open', 'question' => 'Atende cardiologia?' },
                                                     { 'id' => SecureRandom.uuid, 'status' => 'answered', 'question' => 'Outra' }]])

    get "/api/v1/accounts/#{account.id}/ai_brain/conversations/#{conversation.display_id}", headers: admin.create_new_auth_token

    expect(response.parsed_body['staffQuestions'].pluck('id')).to eq([question_id])
  end
end
