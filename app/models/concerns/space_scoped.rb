# frozen_string_literal: true

# Automatically scopes queries to Current.space when set (i.e. inside
# Spaces:: controllers). Outside that context the scope is a no-op, so
# Platform admin, BookingController, console, and background jobs are
# unaffected.
module SpaceScoped
  extend ActiveSupport::Concern

  included do
    default_scope -> { Current.space ? where(space_id: Current.space.id) : nil }
  end
end
