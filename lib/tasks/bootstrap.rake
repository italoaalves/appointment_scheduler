namespace :bootstrap do
  desc "Create the platform superuser from Rails credentials (credentials.superuser.email / .password)"
  task superuser: :environment do
    email    = Rails.application.credentials.dig(:superuser, :email)
    password = Rails.application.credentials.dig(:superuser, :password)

    abort "ERROR: credentials.superuser.email is missing" if email.blank?
    abort "ERROR: credentials.superuser.password is missing" if password.blank?

    user = User.find_or_initialize_by(email: email)

    if user.persisted?
      puts "Superuser already exists (#{email}), skipping."
      next
    end

    user.assign_attributes(
      password: password,
      password_confirmation: password,
      system_role: :super_admin
    )

    user.skip_confirmation!

    if user.save
      puts "Superuser created: #{email}"
    else
      abort "ERROR: Could not create superuser — #{user.errors.full_messages.join(', ')}"
    end
  end
end
