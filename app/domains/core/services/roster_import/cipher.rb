module Core
  module RosterImport
    # Encrypts/decrypts ONE sensitive value (national_id today) for storage
    # inside RosterImportRow#raw's jsonb blob. Same deterministic cipher
    # GroupManagement::Student#national_id uses (`encrypts ..., deterministic:
    # true`) — deterministic so re-parsing the same CSV twice produces the
    # same ciphertext (idempotency, J9), and so Committer/Validator can match
    # it against Student.national_id (which Rails encrypts transparently on
    # both write and query).
    #
    # A dedicated column with `encrypts` isn't an option here: `raw` holds the
    # whole parsed row as one jsonb blob (real schema, not chosen by this
    # slice), and ActiveRecord::Encryption's declarative macro operates on a
    # whole attribute, not one key inside a jsonb hash — so this wraps the
    # same low-level encryptor Rails uses under the hood instead.
    module Cipher
      module_function

      def encrypt(value)
        return nil if value.blank?

        ActiveRecord::Encryption.encryptor.encrypt(
          value.to_s, key_provider: ActiveRecord::Encryption.key_provider,
          cipher_options: { deterministic: true }
        )
      end

      def decrypt(ciphertext)
        return nil if ciphertext.blank?

        ActiveRecord::Encryption.encryptor.decrypt(ciphertext, key_provider: ActiveRecord::Encryption.key_provider)
      end
    end
  end
end
