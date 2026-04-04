# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_space

    def connect
      self.current_space = find_space
    end

    private

    def find_space
      # Use Devise's helper to find current_user from session
      # ActionCable has access to rack_session through request
      if user = User.find_by(id: request.cookies["_user_session"])
        user.space
      end
    end
  end
end
