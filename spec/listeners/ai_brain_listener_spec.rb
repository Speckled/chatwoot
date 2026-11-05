# frozen_string_literal: true

require 'rails_helper'

describe AiBrainListener do
  let(:listener) { described_class.instance }
  let(:account) { create(:account) }
  let(:channel) do
    Channel::Whatsapp.create!(account: account, phone_number: '+5511999990000', provider: 'test', provider_config: { 'source' => 'ai_brain_test' })
  end
  let(:inbox) do
    inbox = create(:inbox, account: account, channel: channel)
    AiBrainInbox.create!(account: account, inbox: inbox, active: true)
    inbox
  end

  it 'hands a client reply to the AI and never a staff reply' do
    client = create(:conversation, account: account, inbox: inbox)
    staff = create(:conversation, account: account, inbox: inbox, additional_attributes: { 'ai_brain_audience' => 'staff' })
    client_reply = create(:message, account: account, inbox: inbox, conversation: client, message_type: :incoming, content: 'Ok!')
    staff_reply = create(:message, account: account, inbox: inbox, conversation: staff, message_type: :incoming, content: 'Ok!')
    allow(AiBrain::ResponseJob).to receive(:perform_later)

    listener.message_created(Events::Base.new(:'message.created', Time.zone.now, message: client_reply))
    listener.message_created(Events::Base.new(:'message.created', Time.zone.now, message: staff_reply))

    expect(AiBrain::ResponseJob).to have_received(:perform_later).with(client_reply.id).once
    expect(AiBrain::ResponseJob).not_to have_received(:perform_later).with(staff_reply.id)
  end

  it 'leaves the AI session alone when an administrator opens or resolves a staff conversation' do
    staff = create(:conversation, account: account, inbox: inbox, additional_attributes: { 'ai_brain_audience' => 'staff' })
    staff.open!
    allow(AiBrain::SessionHandoffJob).to receive(:perform_later)
    allow(AiBrain::SessionEndJob).to receive(:perform_later)

    listener.conversation_opened(Events::Base.new(:'conversation.opened', Time.zone.now, conversation: staff))
    listener.conversation_resolved(Events::Base.new(:'conversation.resolved', Time.zone.now, conversation: staff))

    expect(AiBrain::SessionHandoffJob).not_to have_received(:perform_later)
    expect(AiBrain::SessionEndJob).not_to have_received(:perform_later)
    expect(staff.reload.ai_brain_conversation).to be_nil
  end
end
