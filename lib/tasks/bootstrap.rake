require "io/console"

namespace :bootstrap do
  desc "Create the platform superuser (prompts for email and password interactively)"
  task superuser: :environment do
    $stdout.print "Superuser email: "
    email = $stdin.gets.to_s.strip

    abort "ERROR: email can't be blank" if email.blank?

    password = $stdout.getpass("Password (input hidden): ").to_s.strip
    abort "ERROR: password can't be blank" if password.blank?

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
