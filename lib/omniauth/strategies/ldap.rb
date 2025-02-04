require 'omniauth'

module OmniAuth
  module Strategies
    class LDAP
      class MissingCredentialsError < StandardError; end      
      include OmniAuth::Strategy
      @@config = {
        'name' => 'cn',
        'first_name' => 'givenName',
        'last_name' => 'sn',
        'email' => ['mail', "email", 'userPrincipalName'],
        'phone' => ['telephoneNumber', 'homePhone', 'facsimileTelephoneNumber'],
        'mobile' => ['mobile', 'mobileTelephoneNumber'],
        'nickname' => ['uid', 'userid', 'sAMAccountName'],
        'title' => 'title',
        'location' => {"%0, %1, %2, %3 %4" => [['address', 'postalAddress', 'homePostalAddress', 'street', 'streetAddress'], ['l'], ['st'],['co'],['postOfficeBox']]},
        'uid' => 'dn',
        'url' => ['wwwhomepage'],
        'image' => 'jpegPhoto',
        'description' => 'description'
      }
      option :title, "LDAP Authentication" #default title for authentication form 
      option :port, 389
      option :method, :plain
      option :uid, 'sAMAccountName'
      option :name_proc, lambda {|n| n}
      def initialize(app, *args, &block)        
        super
      end
      
      def request_phase
        f = OmniAuth::Form.new(:title => (options[:title] || "LDAP Authentication"), :url => callback_path)
        f.text_field 'Login', 'username'
        f.password_field 'Password', 'password'
        f.button "Sign In"
        f.to_response
      end

      def callback_phase
        raise MissingCredentialsError.new("Missing login credentials") if request['username'].nil? || request['password'].nil?
        begin
        @adaptor = OmniAuth::LDAP::Adaptor.new @options
        creds = {'username' => request['username'], 'password' => request['password']}
        @ldap_user_info = @adaptor.bind_as(:filter => Net::LDAP::Filter.eq(@adaptor.uid, @options.name_proc.call(creds['username'])),:size => 1)
        return fail!(:invalid_credentials) if !@ldap_user_info
           
        @user_info = self.class.map_user(@@config, @ldap_user_info)
        super
        rescue Exception => e
          return fail!(:ldap_error, e)
        end
      end
      
      uid {
        @user_info["uid"]
      }      
      info {
        @user_info
      }
      extra {
        @ldap_user_info
      }
            
      def self.map_user(mapper, object)
        user = {}
        mapper.each do |key, value|
          case value
            when String
              user[key] = object[value.downcase.to_sym].to_s if object[value.downcase.to_sym]
            when Array
              value.each {|v| (user[key] = object[v.downcase.to_sym].to_s; break;) if object[v.downcase.to_sym]}
            when Hash
              value.map do |key1, value1|
                pattern = key1.dup
                value1.each_with_index do |v,i|
                  part = ''; v.collect(&:downcase).collect(&:to_sym).each {|v1| (part = object[v1].to_s; break;) if object[v1]}
                  pattern.gsub!("%#{i}",part||'')
                end
                user[key] = pattern
              end
            end
        end
        user
      end
    end
  end
end

OmniAuth.config.add_camelization 'ldap', 'LDAP'
