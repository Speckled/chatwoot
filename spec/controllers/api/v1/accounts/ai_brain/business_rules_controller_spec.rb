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
end
