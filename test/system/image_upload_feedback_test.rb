require "application_system_test_case"

class ImageUploadFeedbackTest < ApplicationSystemTestCase
  include Warden::Test::Helpers

  setup do
    @active_user = users(:manager_two)
    @manager = users(:manager)
    Warden.test_mode!
  end

  teardown do
    Warden.test_reset!
  end

  test "profile picture selection shows an immediate preview and status message" do
    login_as(@active_user, scope: :user)
    visit edit_profile_path

    upload = image_upload(filename: "preview-avatar.png")
    selected_filename = File.basename(upload.path)
    attach_file I18n.t("profiles.edit.profile_picture_label"), upload.path

    assert_selector "[data-role='profile-picture-selection-feedback']",
                    text: I18n.t("profiles.edit.profile_picture_selected", filename: selected_filename)

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const image = document.querySelector("[data-role='profile-picture-preview-image']")
        const placeholder = document.querySelector("[data-role='profile-picture-placeholder']")

        return {
          src: image ? image.src : null,
          imageHidden: image ? image.classList.contains("hidden") : null,
          placeholderHidden: placeholder ? placeholder.classList.contains("hidden") : null
        }
      })()
    JS

    assert_match(/\Ablob:/, metrics["src"])
    assert_equal false, metrics["imageHidden"]
    assert_equal true, metrics["placeholderHidden"]
  end

  test "space banner selection shows an immediate preview and status message" do
    login_as(@manager, scope: :user)
    visit edit_settings_space_path

    upload = image_upload(filename: "preview-banner.png")
    selected_filename = File.basename(upload.path)
    attach_file I18n.t("space.settings.edit.banner_label"), upload.path

    assert_selector "[data-role='space-banner-selection-feedback']",
                    text: I18n.t("space.settings.edit.banner_selected", filename: selected_filename)

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const image = document.querySelector("[data-role='space-banner-preview-image']")
        const placeholder = document.querySelector("[data-role='space-banner-placeholder']")

        return {
          src: image ? image.src : null,
          imageHidden: image ? image.classList.contains("hidden") : null,
          placeholderHidden: placeholder ? placeholder.classList.contains("hidden") : null
        }
      })()
    JS

    assert_match(/\Ablob:/, metrics["src"])
    assert_equal false, metrics["imageHidden"]
    assert_equal true, metrics["placeholderHidden"]
  end
end
