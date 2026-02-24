# frozen_string_literal: true

module BookingContext
  class TokenBookingContext
    def initialize(scheduling_link)
      @scheduling_link = scheduling_link
    end

    def space
      @scheduling_link.space
    end

    def usable?
      @scheduling_link.usable?
    end

    def mark_used!
      @scheduling_link.mark_used!
    end

    def redirect_after_booking
      Rails.application.routes.url_helpers.thank_you_book_path(token: @scheduling_link.token)
    end

    def form_url
      Rails.application.routes.url_helpers.book_path(token: @scheduling_link.token)
    end

    def slots_path
      "/book/#{@scheduling_link.token}/slots"
    end
  end

  class PersonalizedBookingContext
    def initialize(personalized_link)
      @personalized_link = personalized_link
    end

    def space
      @personalized_link.space
    end

    def usable?
      true
    end

    def mark_used!
      # no-op
    end

    def redirect_after_booking
      Rails.application.routes.url_helpers.thank_you_book_by_slug_path(slug: @personalized_link.slug)
    end

    def form_url
      Rails.application.routes.url_helpers.book_by_slug_path(slug: @personalized_link.slug)
    end

    def slots_path
      "/book/s/#{@personalized_link.slug}/slots"
    end
  end
end
