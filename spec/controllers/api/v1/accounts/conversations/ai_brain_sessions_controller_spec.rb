# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain session of a conversation', type: :request do
  let(:account) { create(:account) }
  let(:channel) do
    Channel::Whatsapp.create!(account: account, phone_number: '+5511999990000', provider: 'test', provider_config: { 'source' => 'ai_brain_test' })
  end
  let(:inbox) do
    inbox = create(:inbox, account: account, channel: channel)
    AiBrainInbox.create!(account: account, inbox: inbox, active: true)
    inbox
  end
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:outsider) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :open, assignee: agent) }
  let!(:state) { AiBrainConversation.create!(account: account, conversation: conversation, state: 'human') }
  let(:client) { instance_double(AiBrain::Client) }
  let(:base) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/ai_brain_session" }

  before do
    create(:inbox_member, user: agent, inbox: inbox)
    allow(AiBrain::Client).to receive(:new).and_return(client)
    allow(client).to receive(:post).and_return([204, nil])
  end

  it 'shows the prompt to an agent who can see the conversation, and to nobody else' do
    state.show_inactivity_prompt!('notice')

    get base, headers: agent.create_new_auth_token
    expect(response.parsed_body).to include('aiSession' => true, 'inactivityPrompt' => 'notice')

    get base, headers: outsider.create_new_auth_token
    expect(response).to have_http_status(:unauthorized)
  end

  it 'records an answer to the question with the backend, and shows what comes next' do
    state.show_inactivity_prompt!('notice')

    post "#{base}/answer", headers: agent.create_new_auth_token, params: { solved: false }, as: :json

    expect(response).to have_http_status(:no_content)
    expect(client).to have_received(:post).with("conversations/#{conversation.id}/session/inactivity-answer")
    expect(state.reload.inactivity_prompt).to eq('unsolved')
  end

  it 'clears a question the backend no longer waits for' do
    state.show_inactivity_prompt!('notice')
    allow(client).to receive(:post).and_return([409, { 'error' => 'not waiting' }])

    post "#{base}/answer", headers: agent.create_new_auth_token, params: { solved: true }, as: :json

    expect(response).to have_http_status(:conflict)
    expect(state.reload.inactivity_prompt).to be_nil
  end

  it 'answers only the question, not the mandatory close' do
    state.show_inactivity_prompt!('close_required')

    post "#{base}/answer", headers: agent.create_new_auth_token, params: { solved: true }, as: :json

    expect(response).to have_http_status(:conflict)
    expect(client).not_to have_received(:post)
  end

  it 'closes with the reason and who closed, then resolves the conversation' do
    post "#{base}/close", headers: agent.create_new_auth_token, params: { reason: 'Other', note: ' Resolvido por telefone ' }, as: :json

    expect(response).to have_http_status(:no_content)
    expect(client).to have_received(:post).with("conversations/#{conversation.id}/session/end",
                                                { reason: 'Other', note: 'Resolvido por telefone', closedByUserId: agent.id })
    expect(conversation.reload).to be_resolved
  end

  it 'leaves the note out for a reason from the list' do
    post "#{base}/close", headers: agent.create_new_auth_token, params: { reason: 'IssueSolved', note: 'x' }, as: :json

    expect(client).to have_received(:post).with("conversations/#{conversation.id}/session/end", { reason: 'IssueSolved', closedByUserId: agent.id })
  end

  it 'refuses a close without a valid reason and keeps the conversation open' do
    post "#{base}/close", headers: agent.create_new_auth_token, params: { reason: 'Other', note: ' ' }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    post "#{base}/close", headers: agent.create_new_auth_token, params: { reason: 'Bored' }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    post "#{base}/close", headers: agent.create_new_auth_token, params: { reason: 'Other', note: 'x' * 501 }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    expect(client).not_to have_received(:post)
    expect(conversation.reload).not_to be_resolved
  end

  it 'keeps the conversation open when the backend cannot record the close' do
    allow(client).to receive(:post).and_return([500, nil])

    post "#{base}/close", headers: agent.create_new_auth_token, params: { reason: 'IssueSolved' }, as: :json

    expect(response).to have_http_status(:bad_gateway)
    expect(conversation.reload).not_to be_resolved
  end
end
