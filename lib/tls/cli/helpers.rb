require 'thor'
require 'openssl'
require 'date'
require 'digest'
require 'base64'

module ChefCookbook
  module TLS
    module CLI
      module Helpers
        def self.valid_key_file?(key_file)
          key = nil
          if ::File.exist?(key_file)
            begin
              key = ::OpenSSL::PKey.read(::IO.read(key_file))
            rescue ::OpenSSL::PKey::PKeyError
              key = nil
            end
          end

          !key.nil?
        end

        def self.valid_certificate_file?(cert_file)
          cert = nil
          if ::File.exist?(cert_file)
            cert = ::OpenSSL::X509::Certificate.new(::IO.read(cert_file))
          end

          !cert.nil?
        end

        def self.valid_certificate_directory?(path)
          valid_key_file?(::File.join(path, 'server.key')) &&
          valid_certificate_file?(::File.join(path, 'server.crt')) &&
          ::File.exist?(::File.join(path, 'server.chain.crt')) &&
          ::File.exist?(::File.join(path, 'server.fullchain.crt'))
        end

        def self.valid_next_directory?(path)
          valid_key_file?(::File.join(path, 'server.key'))
        end

        def self.valid_directory?(path)
          certificate_dir_regexp = /^\d{4}-\d{2}-\d{2}$/
          has_next_dir = false
          has_certificate_dir = false
          dir = ::Dir.new(path)
          dir.each do |x|
            subdir_path = ::File.join(path, x)
            if ::File.directory?(subdir_path)
              if x == 'next'
                has_next_dir = valid_next_directory?(subdir_path)
              end

              if !has_certificate_dir && !certificate_dir_regexp.match(x).nil?
                has_certificate_dir = valid_certificate_directory?(subdir_path)
              end
            end
          end

          has_next_dir && has_certificate_dir
        end

        def self.list_entries(pwd)
          dir = ::Dir.new(pwd)
          stop_list = %w(
            .
            ..
            .emergency
          )
          dir.select do |x|
            path = ::File.join(pwd, x)
            !stop_list.include?(x) && ::File.directory?(path) && valid_directory?(path)
          end
        end

        def self.get_possible_items(path)
          dir = ::Dir.new(path)
          certificate_dir_regexp = /^\d{4}-\d{2}-\d{2}$/
          dir.select do |x|
            subdir_path = ::File.join(path, x)
            ::File.directory?(subdir_path) && !certificate_dir_regexp.match(x).nil? && valid_certificate_directory?(subdir_path)
          end
        end

        def self.find_valid_item(path)
          get_possible_items(path).max_by do |x|
            ::Date.parse(x)
          end
        end

        def self.get_private_key(pwd, entry_name, item_name)
          path = ::File.join(pwd, entry_name, item_name, 'server.key')
          return ::IO.read(path).strip
        end

        def self.get_certificates(path)
          certificates = []
          ::IO.readlines(path).each do |ln|
            if ln == "-----BEGIN CERTIFICATE-----\n"
              certificates << ln
            else
              certificates[-1] += ln
            end
          end

          certificates.map { |x| x.strip }
        end

        def self.get_fullchain(pwd, entry_name, item_name)
          fullchain_file = ::File.join(pwd, entry_name, item_name, 'server.fullchain.crt')
          get_certificates(fullchain_file)
        end

        def self.get_domain_list(pwd, entry_name, item_name)
          cert_file = ::File.join(pwd, entry_name, item_name, 'server.crt')
          cert = ::OpenSSL::X509::Certificate.new(::IO.read(cert_file))
          domains = []

          cert.extensions.each do |x|
            if x.oid == 'subjectAltName'
              domains += x.value.split(',').map { |x| x.split(':')[1] }
            end
          end

          domains
        end

        def self.get_hpkp_pin(key_file)
          key = ::OpenSSL::PKey.read(::IO.read(key_file))
          public_key = nil
          if key.class == ::OpenSSL::PKey::RSA
            public_key = key.public_key
          elsif key.class == ::OpenSSL::PKey::EC
            public_key = ::OpenSSL::PKey::EC.new(key.group.curve_name)
            public_key.public_key = key.public_key
          end

          ::Digest::SHA256.base64digest(public_key.to_der)
        end

        def self.get_hpkp_pin_list(pwd, entry_name, item_name)
          pin_list = []
          main_key_file = ::File.join(pwd, entry_name, item_name, 'server.key')
          pin_list << get_hpkp_pin(main_key_file)

          emergency_key_file = nil
          key = ::OpenSSL::PKey.read(::IO.read(main_key_file))
          if key.class == ::OpenSSL::PKey::RSA
            emergency_key_file = ::File.join(pwd, '.emergency', 'rsa', 'server.key')
          elsif key.class == ::OpenSSL::PKey::EC
            emergency_key_file = ::File.join(pwd, '.emergency', 'ec', 'server.key')
          end
          if !emergency_key_file.nil? && ::File.file?(emergency_key_file)
            pin_list.unshift(get_hpkp_pin(emergency_key_file))
          end

          next_key_file = ::File.join(pwd, entry_name, 'next', 'server.key')
          pin_list << get_hpkp_pin(next_key_file)

          pin_list
        end

        def self.get_scts(pwd, entry_name, item_name)
          scts_dir = ::File.join(pwd, entry_name, item_name, 'scts')
          h = {}
          if ::File.directory?(scts_dir)
            ::Dir.new(scts_dir).each do |x|
              path = ::File.join(scts_dir, x)
              if ::File.file?(path) && ::File.extname(path) == '.sct'
                log_name = ::File.basename(path, '.sct')
                h[log_name] = ::Base64.strict_encode64(::IO.read(path))
              end
            end
          end

          h
        end

        def self.jsonify_entry(pwd, entry_name)
          item_name = find_valid_item(::File.join(pwd, entry_name))
          {
            name: entry_name,
            domains: get_domain_list(pwd, entry_name, item_name),
            chain: get_fullchain(pwd, entry_name, item_name),
            private_key: get_private_key(pwd, entry_name, item_name),
            hpkp_pins: get_hpkp_pin_list(pwd, entry_name, item_name),
            scts: get_scts(pwd, entry_name, item_name)
          }
        end
      end
    end
  end
end
