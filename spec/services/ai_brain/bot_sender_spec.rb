# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiBrain::BotSender do
  let(:account) { create(:account) }
  let(:client) { instance_double(AiBrain::Client) }

  before do
    allow(described_class).to receive(:assistant_name).and_call_original
    allow(AiBrain::Client).to receive(:new).and_return(client)
    allow(client).to receive(:get).with('business-rules').and_return([200, { 'assistantName' => 'Clara' }])
  end

  it "keeps an account's 'AI Brain' bot and its messages, now named as the clinic's rules say" do
    bot = AgentBot.create!(account: account, name: 'AI Brain')

    sender = described_class.for(account)

    expect(sender.id).to eq(bot.id)
    expect(sender.reload).to have_attributes(name: 'Clara', bot_config: include('ai_brain' => true))
  end

  it 'gives a new account one bot with the name, and asks the backend only until it is marked' do
    first = described_class.for(account)
    second = described_class.for(account)

    expect(second).to eq(first)
    expect(account.agent_bots.pluck(:name)).to eq(['Clara'])
    expect(client).to have_received(:get).once
  end

  it 'returns the same bot after a rename, without making a second one' do
    bot = described_class.for(account)

    described_class.rename(account, 'Bia')

    expect(described_class.for(account)).to eq(bot)
    expect(account.agent_bots.pluck(:name)).to eq(['Bia'])
  end

  it 'still gives a bot when the backend cannot be reached, and names it on a later call' do
    allow(client).to receive(:get).and_raise(AiBrain::Client::UnavailableError, 'connection refused')
    unnamed = described_class.for(account)
    allow(client).to receive(:get).and_return([200, { 'assistantName' => 'Clara' }])

    named = described_class.for(account)

    expect(unnamed.name).to eq('AI Brain')
    expect(named.id).to eq(unnamed.id)
    expect(named.reload.name).to eq('Clara')
  end

  it 'renames only the bot of the account it is given' do
    other = create(:account)
    other_bot = described_class.for(other)

    described_class.rename(account, 'Bia')

    expect(other_bot.reload.name).to eq('Clara')
  end
end
