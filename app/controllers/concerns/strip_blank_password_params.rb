# frozen_string_literal: true

module StripBlankPasswordParams
  def user_params_without_blank_passwords
    p = user_params.to_h
    p.delete(:password) if p[:password].blank?
    p.delete(:password_confirmation) if p[:password_confirmation].blank?
    p
  end
end
