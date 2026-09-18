class Whatsapp::ProviderEvents::Base
  def initialize(payload)
    @body = payload.with_indifferent_access
  end

  private

  # Explicit keyword fields describe the shared event envelope, not provider switches.
  def message_event(id:, phone:, text:, type: 'text', media: nil, name: nil, echo: false, timestamp: nil, reply: nil) # rubocop:disable Metrics/ParameterLists
    phone = phone.to_s.split('@').first.delete('+')
    return if id.blank? || !phone.match?(/\A\d{6,15}\z/)
    return if type == 'text' && text.blank?

    message = { id: id.to_s, from: phone, to: phone, type: type, timestamp: epoch(timestamp),
                text: { body: text }, context: { id: reply } }
    message[type.to_sym] = media if media
    { echo: echo, payload: { contacts: [{ wa_id: phone, profile: { name: name } }], messages: [message] } }
  end

  def epoch(value)
    return if value.blank?
    return Time.iso8601(value).to_i if value.is_a?(String) && !value.match?(/\A\d+\z/)

    number = value.to_i
    number > 1_000_000_000_000 ? number / 1000 : number
  rescue ArgumentError, NoMethodError
    nil
  end
end
