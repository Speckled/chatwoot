# The template_params Whatsapp::TemplateProcessorService reads, from the AI Brain's { name, language, category,
# bodyParameters }: body parameters numbered from 1, in order. Chatwoot sends a message carrying them as that template.
module AiBrain::TemplateParams
  def self.build(template)
    return if template.blank?

    body = Array(template[:bodyParameters]).each_with_index.to_h { |value, index| [(index + 1).to_s, value.to_s] }
    { 'name' => template[:name], 'language' => template[:language], 'category' => template[:category].presence,
      'processed_params' => { 'body' => body } }.compact
  end
end
