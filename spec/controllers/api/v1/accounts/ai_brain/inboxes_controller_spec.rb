# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain inboxes', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:first_inbox) do
    create(:inbox, account: account, channel: Channel::Whatsapp.create!(account: account, phone_number: '+5511999990001', provider: 'test',
                                                                        provider_config: { 'source' => 'ai_brain_test' }))
  end
  let(:second_inbox) do
    create(:inbox, account: account, channel: Channel::Whatsapp.create!(account: account, phone_number: '+5511999990002', provider: 'test',
                                                                        provider_config: { 'source' => 'ai_brain_test' }))
  end
  let(:base) { "/api/v1/accounts/#{account.id}/ai_brain/inboxes" }
  let(:chosen_ids) do
    lambda do
      get base, headers: admin.create_new_auth_token, as: :json
      response.parsed_body.select { |inbox| inbox.dig('aiBrainInbox', 'ownerAssistant') }.pluck('id')
    end
  end

  before do
    AiBrainInbox.create!(account: account, inbox: first_inbox, active: true)
    AiBrainInbox.create!(account: account, inbox: second_inbox, active: true)
  end

  it 'lets an administrator choose one inbox for the admin assistant, and change it' do
    put "#{base}/#{first_inbox.id}/owner_assistant", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:ok)
    expect(chosen_ids.call).to eq([first_inbox.id])

    put "#{base}/#{second_inbox.id}/owner_assistant", headers: admin.create_new_auth_token, as: :json
    expect(chosen_ids.call).to eq([second_inbox.id])
  end

  it 'shows no choice once the AI Brain is turned off on the chosen inbox' do
    put "#{base}/#{first_inbox.id}/owner_assistant", headers: admin.create_new_auth_token, as: :json

    put "#{base}/#{first_inbox.id}", headers: admin.create_new_auth_token, params: { active: false }, as: :json

    expect(chosen_ids.call).to be_empty
  end

  it 'refuses an inbox the AI Brain does not serve, an inbox of another channel, and an agent' do
    AiBrainInbox.find_by(inbox: second_inbox).update!(active: false)
    put "#{base}/#{second_inbox.id}/owner_assistant", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    web_inbox = create(:inbox, account: account)
    AiBrainInbox.create!(account: account, inbox: web_inbox, active: true)
    put "#{base}/#{web_inbox.id}/owner_assistant", headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    put "#{base}/#{first_inbox.id}/owner_assistant", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(chosen_ids.call).to be_empty
  end
end
