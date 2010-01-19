require "action_mailer"
require "net/http"
require "net/https"

class MadMimiMailer < ActionMailer::Base
  VERSION = '0.0.8'
  SINGLE_SEND_URL = 'https://madmimi.com/mailer'

  @@api_settings = {}
  cattr_accessor :api_settings
  
  @@defaults = { :use_erb => false }
  cattr_accessor :defaults
  
  @@rails_default_smtp_settings = {
    :address              => "localhost",
    :port                 => 25,
    :domain               => 'localhost.localdomain',
    :user_name            => nil,
    :password             => nil,
    :authentication       => nil,
    :enable_starttls_auto => true,
  }
  cattr_accessor :rails_default_smtp_settings

  # Custom Mailer attributes

  def promotion(promotion = nil)
    if promotion.nil?
      @promotion
    else
      @promotion = promotion
      @use_erb   = false
    end
  end

  def use_erb(use_erb = nil)
    if use_erb.nil?
      @use_erb
    else
      @use_erb = use_erb
    end
  end

  def hidden(hidden = nil)
    if hidden.nil?
      @hidden
    else
      @hidden = hidden
    end
  end

  # Class methods

  class << self
    def method_missing(method_symbol, *parameters)
      if deliver_using_mimi? 
        if method_symbol.id2name.match(/^deliver_([_a-z]\w*)/)
          deliver_mimi_mail($1, *parameters)
        else
          super
        end
      else
        super
      end
    end

    def deliver_mimi_mail(method, *parameters)
      mail = new
      mail.__send__(method, *parameters)
  
      # BOOLEAN TABLE: 
      # instance level     class level     result
      # use_erb            use_erb
      # T                  T               T
      # T                  F               T
      # F                  T               F
      # F                  F               F
      # nil                T               T
      # nil                F               F
      if will_use_erb?(mail)
        mail.create!(method, *parameters)
      end

      return unless perform_deliveries

      if delivery_method == :test
        deliveries << (mail.mail ? mail.mail : mail)
      else
        call_api!(mail, method)
      end
    end

    def call_api!(mail, method)
      params = {
        'username' => api_settings[:username],
        'api_key' =>  api_settings[:api_key],
        'promotion_name' => promotion_name_for(mail, method),
        'recipients' =>     serialize(mail.recipients),
        'subject' =>        mail.subject,
        'bcc' =>            serialize(mail.bcc),
        'from' =>           mail.from,
        'hidden' =>         serialize(mail.hidden)
      }

      if will_use_erb?(mail)
        if mail.parts.any?
          params['raw_plain_text'] = content_for(mail, "text/plain")
          params['raw_html'] = content_for(mail, "text/html") { |html| validate(html.body) }
        else
          validate(mail.body)
          params['raw_html'] = mail.body
        end
      else
        params['body'] = mail.body.to_yaml
      end

      response = post_request do |request|
        request.set_form_data(params)
      end

      case response
      when Net::HTTPSuccess
        response.body
      else
        response.error!
      end
    end
    
    def promotion_name_for(mail, method)
      will_use_erb?(mail) ? nil : mail.promotion || guess_promotion_for(method)
    end

    def guess_promotion_for( method )
      "#{self.name.demodulize.underscore}_#{method}"
    end

    def content_for(mail, content_type)
      part = mail.parts.detect {|p| p.content_type == content_type }
      if part
        yield(part) if block_given?
        part.body
      end
    end
  
    def deliver_using_mimi?
      ActionMailer::Base.delivery_method == :mad_mimi or 
      delivery_method_and_settings_unset?
    end
  
    def delivery_method_and_settings_unset?
      ActionMailer::Base.delivery_method == :smtp &&
      ActionMailer::Base.smtp_settings == rails_default_smtp_settings
    end
    
    def will_use_erb?( mail )
      mail.use_erb == true || (mail.use_erb.nil? && MadMimiMailer.defaults[:use_erb])
    end

    def validate(content)
      unless content.include?("[[peek_image]]") || content.include?("[[tracking_beacon]]")
        raise ValidationError, "You must include a web beacon in your Mimi email: [[peek_image]]"
      end
    end

    def post_request
      url = URI.parse(SINGLE_SEND_URL)
      request = Net::HTTP::Post.new(url.path)
      yield(request)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.start do |http|
        http.request(request)
      end
    end

    def serialize(recipients)
      case recipients
      when String
        recipients
      when Array
        recipients.join(", ")
      when NilClass
        nil
      else
        raise "Please provide a String or an Array for recipients or bcc."
      end
    end
  end

  class ValidationError < StandardError; end
end

# Adding the response body to HTTPResponse errors to provide better error messages.
module Net
  class HTTPResponse
    def error!
      message = @code + ' ' + @message.dump + ' ' + body
      raise error_type().new(message, self)
    end
  end
end
