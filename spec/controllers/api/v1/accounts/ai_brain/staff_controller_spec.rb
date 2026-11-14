# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain staff', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:client) { instance_double(AiBrain::Client) }
  let(:id) { SecureRandom.uuid }

  before { allow(AiBrain::Client).to receive(:new).and_return(client) }

  it 'names the current user when changing capabilities' do
    allow(client).to receive(:put).and_return([200, { 'id' => id }])

    put "/api/v1/accounts/#{account.id}/ai_brain/staff/#{id}/capabilities",
        headers: admin.create_new_auth_token, params: { isResponder: true }, as: :json

    expect(response).to have_http_status(:ok)
    expect(client).to have_received(:put).with("users/#{id}/capabilities", { 'isResponder' => true, :actingChatwootUserId => admin.id })
  end

  it 'passes a staff description through without naming the current user' do
    allow(client).to receive(:put).and_return([200, { 'id' => id, 'profession' => 'médica' }])

    put "/api/v1/accounts/#{account.id}/ai_brain/staff/#{id}/description",
        headers: admin.create_new_auth_token,
        params: { profession: 'médica', specialties: %w[ginecologia obstetrícia], note: '', isOwner: true }, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['profession']).to eq('médica')
    expect(client).to have_received(:put)
      .with("users/#{id}/description", { 'profession' => 'médica', 'specialties' => %w[ginecologia obstetrícia], 'note' => '' })
  end

  it 'adds a provider with their description' do
    allow(client).to receive(:post).and_return([201, { 'id' => id }])

    post "/api/v1/accounts/#{account.id}/ai_brain/staff",
         headers: admin.create_new_auth_token,
         params: { name: 'Carla', whatsAppNumber: '+5511977776666', profession: 'fisioterapeuta', specialties: ['pilates'] }, as: :json

    expect(client).to have_received(:post)
      .with('users/providers', { 'name' => 'Carla', 'whatsAppNumber' => '+5511977776666', 'profession' => 'fisioterapeuta',
                                 'specialties' => ['pilates'], :accountId => account.id })
  end

  it 'adds a provider to the current account' do
    allow(client).to receive(:post).and_return([201, { 'id' => id }])

    post "/api/v1/accounts/#{account.id}/ai_brain/staff",
         headers: admin.create_new_auth_token, params: { name: 'Carla', whatsAppNumber: '+5511977776666' }, as: :json

    expect(response).to have_http_status(:created)
    expect(client).to have_received(:post)
      .with('users/providers', { 'name' => 'Carla', 'whatsAppNumber' => '+5511977776666', :accountId => account.id })
  end
end
