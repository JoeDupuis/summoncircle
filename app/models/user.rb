class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  encrypts :github_token, deterministic: false
  encrypts :ssh_key, deterministic: false

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  enum :role, { standard: 0, admin: 1 }, allow_nil: true

  def ssh_key_file_path
    return nil unless ssh_key.present?

    @ssh_key_file ||= begin
      file = Tempfile.new([ "user_ssh_key_#{id}", "" ])
      file.write(ssh_key)
      file.close
      File.chmod(0600, file.path)
      file.path
    end
  end

  def cleanup_ssh_key_file
    return unless @ssh_key_file

    File.unlink(@ssh_key_file) if File.exist?(@ssh_key_file)
    @ssh_key_file = nil
  end

  def ssh_key_bind_string(mount_path = nil)
    return nil unless ssh_key_file_path
    return nil unless mount_path.present?

    "#{ssh_key_file_path}:#{mount_path}:ro"
  end
end
