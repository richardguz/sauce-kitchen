require 'test_helper'

class UserProfileAccessTest < ActionDispatch::IntegrationTest
	def setup
		@user = users(:markus)
	end

	test "accessing a user that never existed" do
		get '/users/9999999'
		assert_redirected_to root_url
		follow_redirect!
		assert_not flash[:warning].empty?
	end

	test "accessing a user that was recently deleted" do
		uid = @user.id
		@user.destroy
		get "/users/#{uid}"
		assert_redirected_to root_url
		follow_redirect!
		assert_not flash[:warning].empty?
	end
end
