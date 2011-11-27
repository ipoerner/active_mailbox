require 'test/unit'
require 'yaml'

require 'active_mailbox'

class ActiveImap < ActiveMailbox::Base
  folder_class "ImapFolder"
  message_class :default
end

class LoginDataProvider
  
  include ActiveMailbox::ImapAuthenticator
  
  class << self
    
    #
    # provide pseudo-ID for records
    #
    
    def record_id_by_name(name)
      records = TestHelper::Config.accounts
      
      for id in 0...records.length
        return id if (records[id][:login_data][:name] == name)
      end
      
      raise(ActiveMailbox::Errors::RecordNotFound, nil)
    end
    
    #
    # get imap config by ID (this would get a record from the database in a real-world example)
    #
    
    def login_data(id)
      records = TestHelper::Config.accounts
      raise(ActiveMailbox::Errors::RecordNotFound, id) unless records.length > id
      records[id][:login_data]
    end
    
  end
  
end

module TestHelper
  
  class Output
    
    class << self
      
      def puts_connection_log(name, ack_str, server_type = nil, supports_sort = false)
        tabs = "\t" * (2-(name.length/8))
        print "\n\nConnected to #{name}...#{tabs}#{ack_str}"
        unless server_type.nil?
          print " (#{server_type} adapter"
          print " | supports SORT" if supports_sort
          print ")"
        end
      end
      
      def puts_test_log(test)
        print "\nTest: #{test} .."
      end
      
    end
    
  end
  
  class Config
    
    CONFIG_DIR = "test/config/"
    
    class << self
      
      def load(type)
        case type
          when :unit
            yaml_read("unit.yml")
          when :functional
            yaml_read("functional.yml")
          when :accounts
            yaml_read("accounts.yml")
        else
          Hash.new
        end
      end
      
      def unit(field = nil)
        cfg_data = load(:unit)
        @@unit ||= if cfg_data
          cfg_data
        else
          Hash.new
        end
        if @@unit.has_key?("unit")
          (field.nil?) ? @@unit["unit"] : @@unit["unit"][field]
        else
          nil
        end
      end
      
      def functional(field = nil)
        cfg_data = load(:functional)
        @@functional ||= if cfg_data
          cfg_data
        else
          Hash.new
        end
        if @@functional.has_key?("functional")
          (field.nil?) ? @@functional["functional"] : @@functional["functional"][field]
        else
          nil
        end
      end
      
      def accounts
        cfg_data = load(:accounts)
        @@accounts ||= if cfg_data
          cfg_data.collect { |key, value|
            if value["type"].to_sym == :imap
              login_data = { :name           => key,
                            :host           => value["host"],
                            :user           => value["user"],
                            :authentication => value["authentication"],
                            :encrypted_pwd  => value["password"],
                            :use_ssl        => value["use_ssl"] != false,
                            :address        => value["address"] || value["user"],
                            :adapter        => value["adapter"]
                          }
              { :login_data => login_data, :folders => value["folders"] }
            end
          }.compact
        else
          Hash.new
        end
      end
      
      private
      
      def yaml_read(filename)
        begin
          YAML.load(File.open(CONFIG_DIR + filename))
        rescue Errno::ENOENT
          Hash.new
        end
      end
      
    end
    
  end
  
  class Fixtures
    
    FIXTURES_DIR  = "test/fixtures/"
    
    class << self
      
      def rmail_mbox
        rmail_cfg = TestHelper::Config.unit("rmail")
        raise(ArgumentError, "No Mbox file specified!") if rmail_cfg.nil? || rmail_cfg["mbox"].nil?
        
        FIXTURES_DIR + rmail_cfg["mbox"]
      end
      
      def rmail_length
        rmail_cfg = TestHelper::Config.unit("rmail")
        raise(ArgumentError, "No Mbox length specified!") if rmail_cfg.nil? || rmail_cfg["length"].nil?
        
        rmail_cfg["length"]
      end
      
      def messages
        filename = TestHelper::Config.functional("stub")
        raise(ArgumentError, "No Mbox file specified!") if filename.nil?
        
        File.open(FIXTURES_DIR + filename) { |mailbox|
          return RMail::Mailbox.parse_mbox(mailbox).collect { |msg_string|
            RMail::Parser.read(msg_string)
          }
        }
      end
      
      def new_message(conn_id)
        msg  = ActiveImap::ImapMessage.new(conn_id, nil, messages.first, nil, nil, nil, :Trash, :rmail)
        
        # Some servers like SafeMail do not allow messages without a "From" field corresponding
        # with the account. The solutions is to use the address from the configuration.
        address = ActiveImap.with_connection(conn_id) do |conn|
          conn.config.address
        end
        
        if address
          msg.instance.header.from = address
          msg.instance.header.sender = address
        end
        
        msg
      end
      
      def folder(conn_id, type)
        name = name(conn_id)
        type = type.to_s
        record = TestHelper::Config.accounts.find { |account| account[:login_data][:name] == name }
        
        if !record.nil? && record.has_key?(:folders)
          folders = record[:folders]
          if folders.has_key?(type) && !folders[type].nil? && !folders[type].empty?
            return "#{folders[type]}#{delimiter(conn_id)}"
          end
        end
        
        return ""
      end
      
      def name(conn_id)
        ActiveImap.with_connection(conn_id) do |conn|
          conn.config.name
        end
      end
      
      def delimiter(conn_id)
        ActiveImap::ImapFolder.delimiter(conn_id)
      end
      
      def folder_depth_limit(conn_id)
        ActiveImap.with_connection(conn_id) do |conn|
          conn.max_folder_depth
        end
      end
    
    end
    
  end
  
end
