# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain business rules API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:client) { instance_double(AiBrain::Client) }

  before { allow(AiBrain::Client).to receive(:new).and_return(client) }

  it 'passes the charge timing on with the other rules' do
    allow(client).to receive(:put).and_return([200, { 'chargeTiming' => 1 }])

    put "/api/v1/accounts/#{account.id}/ai_brain/business_rules",
        headers: admin.create_new_auth_token,
        params: { businessRules: { businessName: 'Clínica', chargeTiming: 1, companyRules: [] } },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(client).to have_received(:put) do |path, body|
      expect(path).to eq('business-rules')
      expect(body).to include('businessName' => 'Clínica', 'chargeTiming' => 1)
    end
  end

  it 'passes the four inactivity windows on' do
    allow(client).to receive(:put).and_return([200, {}])
    windows = { inactivityNudgeMinutes: 10, inactivityAutoCloseMinutes: 20, otherSessionInactivityMinutes: 30, personCloseRequiredMinutes: 45 }

    put "/api/v1/accounts/#{account.id}/ai_brain/business_rules",
        headers: admin.create_new_auth_token,
        params: { businessRules: windows.merge(businessName: 'Clínica') },
        as: :json

    expect(client).to have_received(:put) do |_path, body|
      expect(body).to include(windows.stringify_keys)
    end
  end

  it 'passes the payment confirmation template on' do
    allow(client).to receive(:put).and_return([200, {}])
    template = { name: 'pagamento_confirmado', language: 'pt_BR', category: 'UTILITY', bodyParameters: ['{{client_first_name}}', '{{amount}}'] }

    put "/api/v1/accounts/#{account.id}/ai_brain/business_rules",
        headers: admin.create_new_auth_token,
        params: { businessRules: { businessName: 'Clínica', paymentConfirmationTemplate: template } },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(client).to have_received(:put) do |_path, body|
      expect(body['paymentConfirmationTemplate']).to eq(template.deep_stringify_keys)
    end
  end

  it 'passes the working hours on as weekly intervals and dates with their own hours' do
    allow(client).to receive(:put).and_return([200, {}])
    working_hours = {
      defaultSlotDurationMinutes: 30,
      weekly: [{ day: 1, intervals: [{ start: '08:00:00', end: '12:00:00' }, { start: '14:00:00', end: '18:00:00' }] }],
      dateOverrides: [
        { date: '2030-12-25', intervals: [] },
        { date: '2030-12-26', intervals: [{ start: '09:00:00', end: '13:00:00' }] }
      ]
    }

    put "/api/v1/accounts/#{account.id}/ai_brain/business_rules",
        headers: admin.create_new_auth_token,
        params: { businessRules: { businessName: 'Clínica', workingHours: working_hours.merge(activeDays: [1], startTime: '08:00') } },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(client).to have_received(:put) do |_path, body|
      expect(body['workingHours']).to eq(working_hours.deep_stringify_keys)
    end
  end

  it "passes the assistant's name on and renames the account's bot to the name the backend saved" do
    bot = AiBrain::BotSender.for(account)
    other_bot = AiBrain::BotSender.for(create(:account))
    allow(client).to receive(:put).and_return([200, { 'assistantName' => 'Bia' }])

    put "/api/v1/accounts/#{account.id}/ai_brain/business_rules",
        headers: admin.create_new_auth_token,
        params: { businessRules: { businessName: 'Clínica', assistantName: ' Bia ' } },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(client).to have_received(:put) do |_path, body|
      expect(body).to include('assistantName' => ' Bia ')
    end
    expect(bot.reload.name).to eq('Bia')
    expect(other_bot.reload.name).to eq('AI Brain')
  end

  it 'leaves the bot as it is when the backend refuses the rules' do
    bot = AiBrain::BotSender.for(account)
    allow(client).to receive(:put).and_return([400, { 'errors' => { 'assistantName' => ['Too long'] } }])

    put "/api/v1/accounts/#{account.id}/ai_brain/business_rules",
        headers: admin.create_new_auth_token,
        params: { businessRules: { businessName: 'Clínica', assistantName: 'B' * 41 } },
        as: :json

    expect(response).to have_http_status(:bad_request)
    expect(bot.reload.name).to eq('AI Brain')
  end
end
