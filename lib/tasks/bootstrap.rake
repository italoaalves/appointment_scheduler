namespace :bootstrap do
  desc "Create the platform superuser. Set SUPERUSER_EMAIL and SUPERUSER_PASSWORD via environment variables."
  task superuser: :environment do
    email    = ENV["SUPERUSER_EMAIL"]
    password = ENV["SUPERUSER_PASSWORD"]

    abort "ERROR: SUPERUSER_EMAIL env variable is missing" if email.blank?
    abort "ERROR: SUPERUSER_PASSWORD env variable is missing" if password.blank?

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
