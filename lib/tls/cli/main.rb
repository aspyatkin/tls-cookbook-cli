require 'thor'
require 'json'
require 'tls/cli/helpers'

module ChefCookbook
  module TLS
    module CLI
      class Main < ::Thor
        desc 'list', 'List directory'
        option :pwd
        def list
          pwd = options[:pwd] || ::Dir.pwd
          puts ::ChefCookbook::TLS::CLI::Helpers.list_entries(pwd)
        end

        desc 'jsonify ENTRY_NAME', 'Present ENTRY_NAME in JSON format'
        option :pwd
        def jsonify(entry_name)
          pwd = options[:pwd] || ::Dir.pwd
          puts ::JSON.pretty_generate(
            ::ChefCookbook::TLS::CLI::Helpers.jsonify_entry(
              pwd,
              entry_name
            )
          )
        end
      end
    end
  end
end
