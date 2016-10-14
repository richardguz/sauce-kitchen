require 'test_helper'

class UserSignupTest < ActionDispatch::IntegrationTest

	test "signing up a valid user" do
		get signup_path
		assert_template 'new'
		assert_difference 'User.count', 1 do
			post signup_path, params: {user: {email: "testuser1@email.com", username: "testuser1",
																		 password: "password", password_confirmation: "password"}}
		end
		follow_redirect!
		assert_template 'show'
	end

	test "invalid signup attempts" do
		#invalid email
		assert_no_difference 'User.count' do
			post signup_path, params: {user: {email: "testuser1@emailcom", username: "testuser1",
																		 password: "password", password_confirmation: "password"}}
		end
		assert_select 'div#error_explanation'

		
		#not matching passwords
		assert_no_difference 'User.count' do
			post signup_path, params: {user: {email: "testuser1@email.com", username: "testuser1",
																		 password: "password", password_confirmation: "poopies"}}
		end
		assert_select 'div#error_explanation'

		#blank username
		assert_no_difference 'User.count' do
			post signup_path, params: {user: {email: "testuser1@email.com", username: "  ",
																		 password: "password", password_confirmation: "password"}}
		end
		assert_select 'div#error_explanation'

	end
end
