# frozen_string_literal: true

class LegalController < ApplicationController
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :set_locale, raise: false

  def privacy_policy; end
  def terms_of_service; end
end
