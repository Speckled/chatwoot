# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain AI models API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:client) { instance_double(AiBrain::Client) }
  let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/ai_models/providers" }

  before { allow(AiBrain::Client).to receive(:new).and_return(client) }

  it 'lists the providers the agents can run on' do
    providers = [{ 'id' => 'OpenRouter', 'name' => 'OpenRouter' }]
    allow(client).to receive(:get).with('ai/providers').and_return([200, providers])

    get url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(providers)
  end

  it "lists a provider's models and asks for a fresh list only when told to" do
    list = { 'provider' => 'OpenRouter', 'current' => '~deepseek/deepseek-flash-latest', 'models' => [] }
    allow(client).to receive(:get).and_return([200, list])

    get "#{url}/OpenRouter/models", headers: admin.create_new_auth_token
    get "#{url}/OpenRouter/models", headers: admin.create_new_auth_token, params: { refresh: 'true' }

    expect(response.parsed_body).to eq(list)
    expect(client).to have_received(:get).with('ai/providers/OpenRouter/models', {}).once
    expect(client).to have_received(:get).with('ai/providers/OpenRouter/models', { 'refresh' => 'true' }).once
  end

  it "passes the backend's not found through for an unknown provider" do
    allow(client).to receive(:get).and_return([404, nil])

    get "#{url}/anthropic/models", headers: admin.create_new_auth_token

    expect(response).to have_http_status(:not_found)
  end

  it 'rejects agents' do
    get url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
