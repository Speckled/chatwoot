# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain reminders API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:client) { instance_double(AiBrain::Client) }
  let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/reminders" }
  let(:reminder_id) { SecureRandom.uuid }
  let(:reminder) do
    {
      'name' => 'Lembrete de consulta',
      'isEnabled' => true,
      'target' => { 'type' => 3 },
      'channel' => { 'inboxId' => 12, 'aiReplies' => true,
                     'template' => { 'name' => 'lembrete', 'language' => 'pt_BR', 'bodyParameters' => ['{{client_first_name}}'] } },
      'schedule' => { 'type' => 2, 'daysBefore' => 1, 'timeOfDay' => '18:00', 'calendarIds' => [] },
      'content' => { 'kind' => 0, 'text' => 'Olá {{client_first_name}}, sua consulta é amanhã.' }
    }
  end

  before { allow(AiBrain::Client).to receive(:new).and_return(client) }

  it 'creates a reminder with its target, channel, schedule and content' do
    allow(client).to receive(:post).and_return([201, reminder.merge('id' => reminder_id)])

    post url, headers: admin.create_new_auth_token, params: { reminder: reminder }, as: :json

    expect(response).to have_http_status(:created)
    expect(client).to have_received(:post) do |path, body|
      expect(path).to eq('reminders')
      expect(body).to eq(reminder)
    end
  end

  it 'lists, updates, toggles, runs and deletes reminders through the AI Brain' do
    allow(client).to receive_messages(get: [200, []], put: [200, reminder], post: [202, { 'deliveryIds' => [] }], delete: [204, nil])

    get url, headers: admin.create_new_auth_token, as: :json
    put "#{url}/#{reminder_id}", headers: admin.create_new_auth_token, params: { reminder: reminder }, as: :json
    put "#{url}/#{reminder_id}/enabled", headers: admin.create_new_auth_token, params: { isEnabled: false }, as: :json
    post "#{url}/#{reminder_id}/run_now", headers: admin.create_new_auth_token, as: :json
    get "#{url}/#{reminder_id}/deliveries", headers: admin.create_new_auth_token, params: { limit: 20 }
    get "#{url}/placeholders", headers: admin.create_new_auth_token
    delete "#{url}/#{reminder_id}", headers: admin.create_new_auth_token, as: :json

    expect(client).to have_received(:get).with('reminders')
    expect(client).to have_received(:put).with("reminders/#{reminder_id}", reminder)
    expect(client).to have_received(:put).with("reminders/#{reminder_id}/enabled", { isEnabled: false })
    expect(client).to have_received(:post).with("reminders/#{reminder_id}/run-now")
    expect(client).to have_received(:get).with("reminders/#{reminder_id}/deliveries", { 'limit' => '20' })
    expect(client).to have_received(:get).with('reminders/placeholders')
    expect(client).to have_received(:delete).with("reminders/#{reminder_id}")
  end

  it "passes the backend's validation problems through and rejects agents" do
    problems = { 'errors' => { 'schedule' => ['A reminder before each appointment needs a calendar event target.'] } }
    allow(client).to receive(:post).and_return([400, problems])

    post url, headers: admin.create_new_auth_token, params: { reminder: reminder }, as: :json
    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body).to eq(problems)

    get url, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "lists an inbox's approved WhatsApp templates with their parameter count" do
    templates = [
      { 'name' => 'lembrete', 'language' => 'pt_BR', 'status' => 'APPROVED', 'category' => 'UTILITY',
        'components' => [{ 'type' => 'BODY', 'text' => 'Olá {{1}}, sua consulta é {{2}}. Até {{1}}!' }] },
      { 'name' => 'promocao', 'language' => 'pt_BR', 'status' => 'REJECTED', 'components' => [] }
    ]
    channel = create(:channel_whatsapp, account: account, message_templates: templates, sync_templates: false, validate_provider_config: false)

    get "/api/v1/accounts/#{account.id}/ai_brain/inboxes/#{channel.inbox.id}/templates", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body).to eq([{ 'name' => 'lembrete', 'language' => 'pt_BR', 'category' => 'UTILITY',
                                          'bodyText' => 'Olá {{1}}, sua consulta é {{2}}. Até {{1}}!', 'parameterCount' => 2 }])
  end
end
