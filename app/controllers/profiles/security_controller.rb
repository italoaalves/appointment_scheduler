# frozen_string_literal: true

module Profiles
  class SecurityController < Security::BaseController
    before_action :load_security_overview

    def show
    end
  end
end
