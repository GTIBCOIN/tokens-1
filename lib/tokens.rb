module Tokens
  require "tokens/token"
  require "tokens/version"

  def self.included(base)
    base.class_eval { extend  ClassMethods }
  end

  module ClassMethods
    # Set up model for using tokens.
    #
    #   class User < ActiveRecord::Base
    #     has_tokens
    #   end
    #
    def has_tokens
      has_many :tokens, :as => :tokenizable, :dependent => :destroy
      include InstanceMethods
    end

    # Generate token with specified length.
    #
    #   User.generate_token(10)
    #
    def generate_token(size)
      validity = Proc.new {|token| Token.where(:token => token).first.nil?}

      begin
        seed = "--#{rand}--#{Time.now}--#{rand}--"
        token = Digest::SHA1.hexdigest(seed)[0, size]
      end while validity[token] == false

      token
    end

    # Find a token
    #
    #   User.find_token(:activation, 'abcdefg')
    #   User.find_token(:name => activation, :token => 'abcdefg')
    #   User.find_token(:name => activation, :token => 'abcdefg', :tokenizable_id => 1)
    #
    def find_token(*args)
      if args.first.kind_of?(Hash)
        args.first
      else
        options = {
          :name => args.first,
          :token => args.last
        }
      end

      options.merge!(:name => options[:name].to_s, :tokenizable_type => self.name)
      Token.where(options).include(:tokenizable).first
    end

    # Find object by token.
    #
    #   User.find_by_token(:activation, 'abcdefg')
    #
    def find_by_token(name, hash)
      token = find_token(:name => name.to_s, :token => hash)
      return nil unless token
      token.tokenizable
    end

    # Find object by valid token (same name, same hash, not expired).
    #
    #   User.find_by_valid_token(:activation, 'abcdefg')
    #
    def find_by_valid_token(name, hash)
      token = find_token(:name => name.to_s, :token => hash)
      return nil if !token || t.expired?
      t.tokenizable
    end
  end

  module InstanceMethods
    # Find a token.
    #
    #   @user.find_token(:activation, 'abcdefg')
    #
    def find_token(name, token)
      self.class.find_token(
        :tokenizable_id => self.id,
        :name => name.to_s, :token => token
      )
    end

    # Find token by its name.
    def find_token_by_name(name)
      self.tokens.find_by_name(name.to_s)
    end

    # Remove token.
    #
    #   @user.remove_token(:activate)
    #
    def remove_token(name)
      return if new_record?
      token = find_token_by_name(name)
      token && token.destroy
    end

    # Add a new token.
    #
    #   @user.add_token(:api_key, :expires_at => nil)
    #   @user.add_token(:api_key, :size => 20)
    #   @user.add_token(:api_key, :data => data.to_yaml)
    #
    def add_token(name, options={})
      options.reverse_merge!({
        :expires_at => 2.days.from_now,
        :size => 12,
        :data => nil
      })

      remove_token(name)
      attrs = {
        :name       => name.to_s,
        :token      => self.class.generate_token(options[:size]),
        :expires_at => options[:expires_at],
        :data       => options[:data]
      }
      p attrs
      self.tokens.create!(attrs)
    end
  end
end

ActiveRecord::Base.send :include, Tokens