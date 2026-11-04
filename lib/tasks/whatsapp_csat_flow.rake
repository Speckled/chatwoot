# Sends a WhatsApp inbox's CSAT survey as a WhatsApp Flow built in WhatsApp Manager (see docs/whatsapp_csat_flow.md).
module WhatsappCsatFlowTasks
  def self.attach(args)
    inbox = Inbox.find(args[:inbox_id])
    check_arguments(inbox, args)
    # Test inboxes never talk to Meta.
    check_meta_setup(inbox, args) if inbox.channel.provider == 'whatsapp_cloud'

    flow_config = { 'flow_id' => args[:flow_id], 'template_name' => args[:template_name], 'template_language' => args[:template_language] }
    inbox.update!(csat_config: inbox.csat_config.merge('whatsapp_flow' => flow_config.compact_blank))
    puts "✓ Inbox #{inbox.id} sends its CSAT survey as Flow #{args[:flow_id]}"
  end

  def self.check_arguments(inbox, args)
    abort 'Error: the inbox is not a WhatsApp Cloud inbox' unless inbox.whatsapp? && %w[whatsapp_cloud test].include?(inbox.channel.provider)
    abort 'Error: FLOW_ID is required' if args[:flow_id].blank?
    abort 'Error: TEMPLATE_LANGUAGE is required with TEMPLATE_NAME' if args[:template_name].present? && args[:template_language].blank?
    # The Flow message's button shows the CSAT button text.
    abort "Error: save the inbox's Customer Satisfaction settings first" if inbox.csat_config['button_text'].blank?
  end

  def self.check_meta_setup(inbox, args)
    flow = HTTParty.get("#{ENV.fetch('WHATSAPP_CLOUD_BASE_URL', 'https://graph.facebook.com')}/v24.0/#{args[:flow_id]}",
                        query: { fields: 'name,status' }, headers: inbox.channel.api_headers)
    abort "Error: could not read Flow #{args[:flow_id]}: #{flow.body}" unless flow.success?
    abort "Error: Flow '#{flow['name']}' is #{flow['status']}; publish it first" unless flow['status'] == 'PUBLISHED'
    return if args[:template_name].blank?

    template = inbox.channel.provider_service.get_template_status(args[:template_name])
    puts "Template '#{args[:template_name]}' is #{template.dig(:template, :status) || template[:error]}; it is used once APPROVED"
  end

  def self.detach(args)
    inbox = Inbox.find(args[:inbox_id])
    inbox.update!(csat_config: inbox.csat_config.except('whatsapp_flow'))
    puts "✓ Inbox #{inbox.id} sends its CSAT survey as a link"
  end
end

namespace :whatsapp do
  namespace :csat_flow do
    desc 'Send the CSAT survey of a WhatsApp Cloud inbox as a Flow, and outside the 24h window as a Flow template'
    task :attach, [:inbox_id, :flow_id, :template_name, :template_language] => :environment do |_task, args|
      WhatsappCsatFlowTasks.attach(args)
    end

    desc 'Send the CSAT survey of a WhatsApp inbox as a link again'
    task :detach, [:inbox_id] => :environment do |_task, args|
      WhatsappCsatFlowTasks.detach(args)
    end
  end
end
