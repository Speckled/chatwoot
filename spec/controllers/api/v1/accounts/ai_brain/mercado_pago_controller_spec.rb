# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain Mercado Pago API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:client) { instance_double(AiBrain::Client) }
  let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/mercado_pago" }
  let(:user_id) { SecureRandom.uuid }
  let(:return_url) { "https://chat.test/app/accounts/#{account.id}/ai-brain/services" }

  before { allow(AiBrain::Client).to receive(:new).and_return(client) }

  around { |example| with_modified_env(FRONTEND_URL: 'https://chat.test/') { example.run } }

  it "asks the backend for the clinic's authorization URL, returning to the services page" do
    allow(client).to receive(:get).and_return([200, { 'authorizationUrl' => 'https://auth.mercadopago.com/authorization?state=x' }])

    get "#{url}/authorization_url", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['authorizationUrl']).to start_with('https://auth.mercadopago.com/')
    expect(client).to have_received(:get).with('services/mercado-pago/auth/url', redirect: false, returnUrl: return_url)
  end

  it "asks for a professional's own authorization URL and passes a 404 through" do
    allow(client).to receive(:get).and_return([404, nil])

    get "#{url}/professionals/#{user_id}/authorization_url", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:not_found)
    expect(client).to have_received(:get).with("users/#{user_id}/services/mercado-pago/auth/url", redirect: false, returnUrl: return_url)
  end

  it "disconnects the clinic's account and a professional's" do
    allow(client).to receive(:delete).and_return([204, nil])

    delete url, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:no_content)
    delete "#{url}/professionals/#{user_id}", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:no_content)
    expect(client).to have_received(:delete).with('services/mercado-pago')
    expect(client).to have_received(:delete).with("users/#{user_id}/services/mercado-pago")
  end

  it 'refuses a user id that is not a UUID' do
    get "#{url}/professionals/12/authorization_url", headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:bad_request)
  end

  it 'rejects agents' do
    get "#{url}/authorization_url", headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
