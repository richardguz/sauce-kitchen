require 'test_helper'

class UserSignInTest < ActionDispatch::IntegrationTest
  def setup
  	@user = users(:markus)
  end

  test "valid user sign in" do
  	post login_path, params: {session: {username: @user.username, password: "password"}}
  	assert_redirected_to @user
  	assert_equal "Login Successful!", flash[:success]
		assert_equal @user.id, session[:user_id]	
  end  	

  test "invalid password/username combo" do
  	post login_path, params: {session: {username: @user.username, password: "password1"}}
  	assert_template 'sessions/new'
  	assert_equal "Invalid username/password combination", flash[:danger] 
  end
end
