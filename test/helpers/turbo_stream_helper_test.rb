# frozen_string_literal: true

require "test_helper"

class TurboStreamHelperTest < ActionView::TestCase
  include Turbo::StreamsHelper

  def formats
    @formats || [ :html ]
  end

  def formats=(val)
    @formats = val
  end
  test "turbo_stream_flash returns prepend action targeting flash_messages" do
    result = turbo_stream_flash(type: :notice, message: "Great success!")

    assert_includes result, 'action="prepend"'
    assert_includes result, 'target="flash_messages"'
    assert_includes result, "Great success!"
  end

  test "turbo_stream_flash notice uses emerald styling" do
    result = turbo_stream_flash(type: :notice, message: "Done")

    assert_includes result, "bg-emerald-50"
  end

  test "turbo_stream_flash alert uses red styling" do
    result = turbo_stream_flash(type: :alert, message: "Error")

    assert_includes result, "bg-red-50"
  end

  test "turbo_stream_flash includes auto-dismiss x-init" do
    result = turbo_stream_flash(type: :notice, message: "Msg")

    assert_includes result, "setTimeout"
  end
end
