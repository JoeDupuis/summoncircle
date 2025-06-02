if Rails.env.test?
  ActiveRecord::Encryption.configure(
    primary_key:          "1c7e6aa54b2cfbf79cce0e3d82c34d51",
    deterministic_key:    "5db7bb47b6394d1689d6a5c47d28fbcd",
    key_derivation_salt:  "9e6f0e5b9e524fb3afa6077274baf432"
  )
end
