module SecretValidation
  extend ActiveSupport::Concern

  # Common code snippets that should not be treated as secrets
  RESERVED_CODE_WORDS = %w[
    els else elsif if end then when case class module def
    do begin rescue ensure nil true false and or not
    return break next redo retry super self yield
    public private protected attr alias undef defined?
  ].freeze

  included do
    validate :value_not_reserved_word, if: :value?
  end

  private

  def value_not_reserved_word
    return unless value.present? && value.length < 10
    
    if RESERVED_CODE_WORDS.include?(value.downcase)
      errors.add(:value, "cannot be a reserved programming keyword to prevent code corruption")
    end
  end
end