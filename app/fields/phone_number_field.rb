require 'administrate/field/base'

# A phone number stored in E.164, entered as a country (flag and dial code) plus the national number.
class PhoneNumberField < Administrate::Field::String
  # Brazil first, as the default; the rest are the clinic's likely neighbours.
  COUNTRIES = [
    ['🇧🇷', 'Brasil', '55'],
    ['🇵🇹', 'Portugal', '351'],
    ['🇦🇷', 'Argentina', '54'],
    ['🇺🇾', 'Uruguai', '598'],
    ['🇵🇾', 'Paraguai', '595'],
    ['🇨🇱', 'Chile', '56'],
    ['🇪🇸', 'Espanha', '34'],
    ['🇺🇸', 'Estados Unidos', '1']
  ].freeze

  # The stored number split into the country's dial code and the national digits; Brazil when there is none.
  def dial_code_and_national_number
    digits = data.to_s.delete('^0-9')
    return [COUNTRIES.first.last, ''] if digits.empty?

    dial_code = COUNTRIES.map(&:last).sort_by { |code| -code.length }.find { |code| digits.start_with?(code) }
    dial_code ? [dial_code, digits.delete_prefix(dial_code)] : [COUNTRIES.first.last, digits]
  end

  # E.g. "🇧🇷 +55 (51) 99568-4103", formatted like the form shows it.
  def display
    dial_code, national_number = dial_code_and_national_number
    return '' if national_number.empty?

    flag = COUNTRIES.find { |_flag, _name, code| code == dial_code }&.first
    "#{flag} +#{dial_code} #{dial_code == '55' ? brazilian(national_number) : national_number}"
  end

  private

  def brazilian(digits)
    rest = digits[2..].to_s
    split = rest.length > 8 ? 5 : 4
    "(#{digits[0, 2]}) #{rest[0, split]}#{"-#{rest[split..]}" if rest.length > split}"
  end
end
