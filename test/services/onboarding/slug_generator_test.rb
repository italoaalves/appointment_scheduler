# frozen_string_literal: true

require "test_helper"

module Onboarding
  class SlugGeneratorTest < ActiveSupport::TestCase
    test "basic generation from simple name" do
      assert_equal "studio-maria", SlugGenerator.call("Studio Maria")
    end

    test "transliteration of accented characters" do
      assert_equal "dr-joao-silva", SlugGenerator.call("Dr. João Silva")
    end

    test "hyphenation of spaces and special characters" do
      result = SlugGenerator.call("Clínica São Paulo & Associados!!!")
      assert_match PersonalizedSchedulingLink::SLUG_FORMAT, result
      assert result.length <= 40, "slug too long: #{result}"
    end

    test "truncation of long names" do
      long = "A" * 50 + " B"
      result = SlugGenerator.call(long)
      assert result.length <= 40, "slug too long: #{result}"
    end

    test "uniqueness retry appends suffix when slug conflicts" do
      PersonalizedSchedulingLink.create!(space: spaces(:one), slug: "studio-maria")
      result = SlugGenerator.call("Studio Maria")
      assert result.start_with?("studio-maria-"), "expected suffix: #{result}"
      assert_match PersonalizedSchedulingLink::SLUG_FORMAT, result
    end

    test "returns valid slug when single conflict occurs" do
      PersonalizedSchedulingLink.create!(space: spaces(:one), slug: "studio-maria")
      result = SlugGenerator.call("Studio Maria")
      refute_equal "studio-maria", result
      assert_match PersonalizedSchedulingLink::SLUG_FORMAT, result
      refute PersonalizedSchedulingLink.exists?(slug: result)
    end

    test "slug matches SLUG_FORMAT" do
      [ "Studio Maria", "Dr. João", "Barbearia do Zé" ].each do |name|
        result = SlugGenerator.call(name)
        assert_match PersonalizedSchedulingLink::SLUG_FORMAT, result,
          "#{name.inspect} produced invalid slug: #{result}"
      end
    end
  end
end
