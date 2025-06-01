class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  encrypts :github_token, deterministic: false

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  enum :role, { standard: 0, admin: 1 }, allow_nil: true

  def instructions_file_path
    return nil unless instructions.present?

    @instructions_file ||= begin
      file = Tempfile.new([ "user_instructions_#{id}", ".txt" ])
      file.write(instructions)
      file.close
      file.path
    end
  end

  def cleanup_instructions_file
    return unless @instructions_file

    File.unlink(@instructions_file) if File.exist?(@instructions_file)
    @instructions_file = nil
  end

  def instructions_bind_string(mount_path)
    return nil unless instructions_file_path && mount_path.present?

    "#{instructions_file_path}:#{mount_path}:ro"
  end
end
