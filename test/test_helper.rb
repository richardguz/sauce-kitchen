ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require "minitest/reporters"
Minitest::Reporters.use!


class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  def login_as(user)
  	session[:user_id] = user.id
  end
  # Add more helper methods to be used by all tests here...
end

class ActionDispatch::IntegrationTest
	def login_as(user, password: 'password')
  	post login_path, params: {session: {username: user.username, password: password}}
  end
end