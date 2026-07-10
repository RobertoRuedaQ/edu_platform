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

      # Decrypts every `sensitive_fields` key in `raw`, returning a NEW hash
      # (the encrypted `raw` itself is never mutated) with those values
      # replaced by plaintext. Shared by Validator/Committer (need the real
      # values to validate/upsert against) and the preview view (via each
      # strategy's #preview_columns) — one implementation of "which fields
      # need decrypting" per kind (the strategy), one implementation of HOW
      # to decrypt (here).
      def decrypt_row(raw, sensitive_fields)
        sensitive_fields.reduce(raw.dup) { |row, field| row.merge(field => decrypt(row[field])) }
      end

      # Reveals AT MOST half of a plaintext sensitive value — never the
      # whole thing, even for an unrealistically short value (guardrail,
      # v1.7.0: a naive "show last 4" revealed 4-character ids in full).
      def mask(plain)
        return "—" if plain.blank?

        visible = [ plain.length / 2, 4 ].min
        ("•" * (plain.length - visible)) + plain.last(visible)
      end
    end
  end
end
