# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Whatsapp::Providers::WhatsappTestService do
  let(:account) { create(:account) }
  let(:whatsapp_channel) do
    Channel::Whatsapp.create!(
      account: account,
      phone_number: '+5511999990000',
      provider: 'test',
      provider_config: { 'source' => 'ai_brain_test' }
    )
  end
  let(:service) { described_class.new(whatsapp_channel: whatsapp_channel) }

  describe '#provider_service' do
    it 'returns WhatsappTestService when channel provider is test' do
      expect(whatsapp_channel.provider_service).to be_a(described_class)
      expect(whatsapp_channel.test_provider?).to be(true)
    end
  end

  describe '#send_message' do
    it 'returns a mock message id without calling external APIs' do
      message = build(:message)
      id = service.send_message('+5511988887777', message)
      expect(id).to start_with('wamid.test.')
    end
  end

  describe '#send_template' do
    it 'returns a mock template message id without calling external APIs' do
      message = build(:message)
      id = service.send_template('+5511988887777', { name: 'hello' }, message)
      expect(id).to start_with('wamid.test.')
    end
  end

  describe '#validate_provider_config?' do
    it 'always returns true' do
      expect(service.validate_provider_config?).to be(true)
    end
  end
end
