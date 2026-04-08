# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw,
  :email,
  :secret,
  :token,
  :_key,
  :crypt,
  :salt,
  :certificate,
  :otp,
  :ssn,
  :cvv,
  :cvc,
  :cpf_cnpj,
  :name,
  :phone,
  :phone_number,
  :address,
  :customer_name,
  :customer_email,
  :customer_phone,
  :customer_address,
  :scheduled_at,
  :body,
  :content,
  :message,
  :contact_name,
  :contact_identifier
]
