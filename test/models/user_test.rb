require 'test_helper'

class UserTest < ActiveSupport::TestCase
	def setup
		@user = User.new(email: "markusnotti@g.com", username: "notti_i_am")
	end

	test "validity of basic valid user" do
		assert @user.valid?
	end

	test "blank username/emails should be invalid" do
		@user.email = ""
		assert_not @user.valid?
		@user.email = "    	  "
		assert_not @user.valid?
		@user.email = "m@g.com"

		@user.username = ""
		assert_not @user.valid?
		@user.username = "     "
		assert_not @user.valid?
	end

	test "username/email cannot be too long" do
		@user.email = "a" * 250 + "@g.com"
		assert_not @user.valid?
		@user.email = "m@.com"

		@user.username = "a" * 31
		assert_not @user.valid?
	end

	test "emails with valid format" do
		valid_emails = ["poop@pants.com", "heyheyhey12345@g.ucla.edu", "wass.up@girl.net"]
		valid_emails.each do |e|
			assert e.valid?, 
		end
	end
end
