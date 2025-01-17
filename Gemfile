source "https://rubygems.org"

ruby "3.0.3"

# gems that ship with rails...........................................................
gem "spring", "2.1.0"
gem "rails", "~> 7.0.2.2"
gem "redis", "~> 4.2", ">= 4.2.5"
gem "puma", "4.3.11"
gem "pg", "1.2.3"
gem "barnes", "~> 0.0.9"

# app specific gems...................................................................
gem "acts_as_votable", "~> 0.13.2"
gem "ahoy_matey", "~> 3.1"
gem "aws-sdk-s3", require: false
gem "deepl-rb", "~> 2.4", require: 'deepl'
gem "devise", "~> 4.7", ">= 4.7.2"
gem "faraday", "~> 1.1.0"
gem "font-awesome-rails", "~> 4.7"
gem "hashie", "~> 4.1"
gem "hotwire-rails", "~> 0.1.3"
gem "jsbundling-rails", "~> 1.0"
gem "nokogiri", "~> 1.10", ">= 1.10.10"
gem 'omniauth-facebook'
gem 'omniauth-google-oauth2'
gem "omniauth-rails_csrf_protection"
gem "prettier", "~> 1.5"
gem "pg_search", "~> 2.3", ">= 2.3.5"
gem "rails_autolink", "~> 1.1"
gem "rspotify", "~> 2.9", ">= 2.9.2"
gem "sass-rails", "6.0.0"
gem "scenic", "~> 1.5", ">= 1.5.4"
gem "sidekiq", "~> 6.1", ">= 6.1.2"
gem "spring-watcher-listen",  "2.0.1"
gem "streamio-ffmpeg", "~> 3.0", ">= 3.0.2"
gem "yt", "~> 0.32.0"

group :development, :test do
  gem "amazing_print", "~> 1.2", ">= 1.2.2"
  gem "dotenv-rails", "~> 2.7"
  gem "factory_bot_rails", "~> 6.1"
  gem "faker", "~> 2.16"
  gem "rspec-rails", "~> 4.0"
  gem "byebug", "~> 11.1", ">= 11.1.3"
  gem 'webdrivers'
end

group :development do
  gem "listen", "~> 3.2"
  gem "rack-mini-profiler", "~> 2.3"
  gem "rubocop", "~> 1.8"
  gem "rubocop-rails", "~> 2.9"
  gem "rubocop-rspec", "~> 2.1"
  gem "solargraph", "~> 0.40.2"
  gem "web-console", "4.0.2"
end

group :test do
  gem "capybara", ">= 2.15"
  gem 'capybara-screenshot'
  gem "selenium-webdriver", "3.142.7"
  gem "shoulda-matchers", "~> 4.0"
  gem "simplecov", "~> 0.21.2", require: false
  gem 'rspec-sidekiq'
  gem "vcr", "~> 6.0"
  gem "webmock", "~> 3.12"
end
