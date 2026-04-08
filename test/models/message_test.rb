# frozen_string_literal: true

require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "content is encrypted at rest" do
    message = Message.create!(
      sender: users(:manager),
      recipient: users(:secretary),
      messageable: appointments(:one),
      content: "Sensitive appointment details"
    )

    assert_equal "Sensitive appointment details", message.reload.content
    assert_not_equal "Sensitive appointment details", message.reload.ciphertext_for(:content)
  end
end
