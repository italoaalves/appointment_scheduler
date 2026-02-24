# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "alpine-turbo-drive-adapter", to: "https://cdn.jsdelivr.net/npm/alpine-turbo-drive-adapter@2.2.0/dist/alpine-turbo-drive-adapter.esm.js"
pin "alpinejs" # @3.15.8
pin "flatpickr", to: "https://esm.sh/flatpickr@4.6.13"
