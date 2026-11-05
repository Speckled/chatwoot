# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain service terms API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:client) { instance_double(AiBrain::Client) }
  let(:url) { "/api/v1/accounts/#{account.id}/ai_brain/service_terms" }
  let(:consulta) { SecureRandom.uuid }

  before { allow(AiBrain::Client).to receive(:new).and_return(client) }

  it 'reads the clinic and professional terms from the backend' do
    overview = { 'clinic' => { 'services' => [] }, 'professionals' => [] }
    allow(client).to receive(:get).with('service-terms').and_return([200, overview])

    get url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(overview)
  end

  it 'saves the clinic terms with their services, plans and Pix key' do
    terms = {
      'services' => [{ 'id' => consulta, 'name' => 'Consulta', 'price' => 300, 'priceOnRequest' => false, 'offered' => true }],
      'acceptedPlans' => ['Unimed'],
      'paymentMethods' => [{ 'type' => 0, 'pix' => { 'key' => '+5511999998888', 'recipientName' => 'Clínica' } }],
      'notes' => 'Chegue 10 minutos antes.'
    }
    allow(client).to receive(:put).and_return([200, terms])

    put url, headers: admin.create_new_auth_token, params: { serviceTerms: terms }, as: :json

    expect(response).to have_http_status(:ok)
    expect(client).to have_received(:put) do |path, body|
      expect(path).to eq('service-terms')
      expect(body).to eq(terms)
    end
  end

  it "passes a professional's changes on, with an empty list as none and inherited lists left out" do
    user_id = SecureRandom.uuid
    allow(client).to receive(:put).and_return([200, {}])

    put "#{url}/professionals/#{user_id}",
        headers: admin.create_new_auth_token,
        params: { serviceTerms: { services: [{ id: consulta, offered: false }], acceptedPlans: [], paymentMethods: nil, notes: nil } },
        as: :json

    expect(response).to have_http_status(:ok)
    expect(client).to have_received(:put) do |path, body|
      expect(path).to eq("users/#{user_id}/service-terms")
      expect(body['services']).to eq([{ 'id' => consulta, 'offered' => false }])
      expect(body['acceptedPlans']).to eq([])
      expect(body['paymentMethods']).to be_nil
    end
  end

  it "passes the backend's validation problems through" do
    problems = { 'errors' => { 'services' => ['Every service needs a name.'] } }
    allow(client).to receive(:put).and_return([400, problems])

    put url, headers: admin.create_new_auth_token, params: { serviceTerms: { services: [{ id: consulta, name: '' }] } }, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(response.parsed_body).to eq(problems)
  end

  it 'rejects agents' do
    get url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
