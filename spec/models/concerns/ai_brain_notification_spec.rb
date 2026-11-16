# frozen_string_literal: true

require 'rails_helper'

# LRB-85: the notification that a person's AI Brain chat went quiet.
RSpec.describe AiBrainNotification do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  # Joining the account gives the agent Chatwoot's default settings: push and email for assignments only.
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account) }

  def notify(stage, minutes)
    create(:notification, notification_type: 'ai_brain_session_inactive', user: agent, account: account, primary_actor: conversation,
                          meta: { stage: stage, minutes: minutes })
  end

  it 'asks whether the issue is solved, then to close, with the conversation and the minutes' do
    expect(notify('notice', 31).push_message_title)
      .to eq("The chat ##{conversation.display_id} has no messages for the past 31 minutes. Is the client's issue solved?")
    expect(notify('close_required', 61).push_message_title)
      .to eq("The chat ##{conversation.display_id} has no messages for the past 61 minutes. Please close it now.")
  end

  it "shows the patient's last message as the body" do
    create(:message, conversation: conversation, account: account, inbox: conversation.inbox, message_type: :incoming, content: 'Ainda estou aqui')

    expect(notify('notice', 31).push_message_body).to end_with(': Ainda estou aqui')
  end

  it "is pushed whatever the person's settings, and e-mailed only if they chose it" do
    expect(agent.notification_settings.find_by(account: account).push_ai_brain_session_inactive?).to be(false)

    notify('notice', 31)

    expect(Notification::PushNotificationJob).to have_been_enqueued
    expect(Notification::EmailNotificationJob).not_to have_been_enqueued
  end

  it 'leaves the settings in charge of every other type' do
    create(:notification, notification_type: 'conversation_mention', user: agent, account: account, primary_actor: conversation)

    expect(Notification::PushNotificationJob).not_to have_been_enqueued
  end
end
