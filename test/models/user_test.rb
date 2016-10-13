require 'test_helper'

class UserTest < ActiveSupport::TestCase
	def setup
		@user = User.new(email: "markusnotti@g.com", username: "notti_i_am", password: "password", password_confirmation: "password")
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
			@user.email = e
			assert @user.valid?, "#{e.inspect} should be valid but is not returning valid"
		end
	end

	test "emails with invalid format" do
		invalid_addresses = %w[user@example,com user_at_foo.org user.name@example.
                           foo@bar_baz.com foo@bar+baz.com]
    invalid_addresses.each do |e|
    	@user.email = e
    	assert_not @user.valid?, "#{e.inspect} should be an invalid email"
    end
	end

	test "emails should be unique" do
		duplicate_user = @user.dup
		duplicate_user.username = "something_different"
		@user.save
		assert_not duplicate_user.valid?
		duplicate_user.email = duplicate_user.email.upcase
		assert_not duplicate_user.valid?
	end

	test "usernames should be unique" do
		duplicate_user = @user.dup
		duplicate_user.email = "something_different@gmail.com"
		@user.save
		assert_not duplicate_user.valid?
	end

	test "before_save email downcasing" do
		mixed_case_email = "aBcDeFg@gmail.com"
		@user.email = mixed_case_email
		@user.save
		@user.reload
		assert_equal mixed_case_email.downcase, @user.email
	end

	test "password should not be blank" do
		@user.password = "    "
		@user.password_confirmation = "    "
		assert_not @user.valid?
		@user.password = ""
		@user.password_confirmation = ""
		assert_not @user.valid?
	end

	test "password should not be too short" do
		@user.password = "a" * 5
		@user.password_confirmation = "a" * 5
		assert_not @user.valid?
	end

end
