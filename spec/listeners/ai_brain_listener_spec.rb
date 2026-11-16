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

  it 'hands a staff member’s message in their staff conversation to the staff agent, and never one from former staff' do
    staff_contact = create(:contact, account: account, phone_number: '+5551999990002',
                                     additional_attributes: { 'ai_brain_staff_inbox_ids' => [inbox.id] })
    former_contact = create(:contact, account: account, phone_number: '+5551999990003')
    staff = create(:conversation, account: account, inbox: inbox, contact: staff_contact)
    former = create(:conversation, account: account, inbox: inbox, contact: former_contact,
                                   additional_attributes: { 'ai_brain_audience' => 'staff' })
    staff_message = create(:message, account: account, inbox: inbox, conversation: staff, message_type: :incoming, content: 'oi')
    former_message = create(:message, account: account, inbox: inbox, conversation: former, message_type: :incoming, content: 'oi')
    note = create(:message, account: account, inbox: inbox, conversation: staff, message_type: :outgoing, private: true, content: 'nota')
    allow(AiBrain::StaffConversationJob).to receive(:perform_later)
    allow(AiBrain::ResponseJob).to receive(:perform_later)

    [staff_message, former_message, note].each do |message|
      listener.message_created(Events::Base.new(:'message.created', Time.zone.now, message: message))
    end

    expect(staff.reload.ai_brain_staff?).to be(true)
    expect(AiBrain::StaffConversationJob).to have_received(:perform_later).with(staff_message.id).once
    expect(AiBrain::StaffConversationJob).to have_received(:perform_later).once
    expect(AiBrain::ResponseJob).not_to have_received(:perform_later)
  end

  it 'does not hand a staff member’s message to the staff agent while the AI Brain is off in the inbox' do
    staff_contact = create(:contact, account: account, phone_number: '+5551999990002',
                                     additional_attributes: { 'ai_brain_staff_inbox_ids' => [inbox.id] })
    staff = create(:conversation, account: account, inbox: inbox, contact: staff_contact)
    inbox.ai_brain_inbox.update!(active: false)
    staff_message = create(:message, account: account, inbox: inbox, conversation: staff, message_type: :incoming, content: 'oi')
    allow(AiBrain::StaffConversationJob).to receive(:perform_later)

    listener.message_created(Events::Base.new(:'message.created', Time.zone.now, message: staff_message.reload))

    expect(AiBrain::StaffConversationJob).not_to have_received(:perform_later)
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
