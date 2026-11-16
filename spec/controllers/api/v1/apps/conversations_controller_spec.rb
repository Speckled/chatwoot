# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AI Brain inactivity prompt API', type: :request do
  let(:account) { create(:account) }
  let(:channel) do
    Channel::Whatsapp.create!(account: account, phone_number: '+5511999990000', provider: 'test', provider_config: { 'source' => 'ai_brain_test' })
  end
  let!(:inbox) do
    inbox = create(:inbox, account: account, channel: channel)
    AiBrainInbox.create!(account: account, inbox: inbox, active: true)
    inbox
  end
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, status: :open) }
  let(:url) { "/api/v1/apps/chatwoot-main/conversations/#{conversation.id}/inactivity_prompt" }
  let(:headers) { { 'X-Api-Key' => 'test-key' } }

  around { |example| with_modified_env(AI_BRAIN_API_KEY: 'test-key') { example.run } }

  it 'asks the assignee whether the issue is solved, and asks only once' do
    create(:inbox_member, user: agent, inbox: inbox)
    conversation.update!(assignee: agent)

    2.times { post url, headers: headers, params: { stage: 'notice', minutes: 31 }, as: :json }

    expect(response).to have_http_status(:no_content)
    expect(conversation.reload.ai_brain_conversation.inactivity_prompt).to eq('notice')
    notification = Notification.find_by!(user: agent, notification_type: :ai_brain_session_inactive)
    expect(notification.meta).to eq('stage' => 'notice', 'minutes' => 31)
    expect(notification.push_message_title).to include("##{conversation.display_id}", '31 minutes', 'solved')
    expect(Notification.where(notification_type: :ai_brain_session_inactive).count).to eq(1)
  end

  it 'asks the administrators when nobody is assigned' do
    post url, headers: headers, params: { stage: 'close_required', minutes: 61 }, as: :json

    expect(Notification.where(notification_type: :ai_brain_session_inactive).pluck(:user_id)).to eq([admin.id])
    expect(conversation.reload.ai_brain_conversation.inactivity_prompt).to eq('close_required')
  end

  it 'notifies only people who can see the conversation' do
    conversation.update!(assignee: agent)

    post url, headers: headers, params: { stage: 'notice', minutes: 31 }, as: :json

    expect(response).to have_http_status(:no_content)
    expect(Notification.where(notification_type: :ai_brain_session_inactive)).to be_empty
  end

  it 'refuses an unknown stage and a staff conversation' do
    staff = create(:conversation, account: account, inbox: inbox, additional_attributes: { 'ai_brain_audience' => 'staff' })

    post url, headers: headers, params: { stage: 'later', minutes: 31 }, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    staff_url = "/api/v1/apps/chatwoot-main/conversations/#{staff.id}/inactivity_prompt"
    post staff_url, headers: headers, params: { stage: 'notice', minutes: 31 }, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'needs the API key' do
    post url, params: { stage: 'notice', minutes: 31 }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
