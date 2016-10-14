require 'test_helper'

class UserSignInTest < ActionDispatch::IntegrationTest
  def setup
  	@user = users(:markus)
  end

  test "valid user sign in" do
  	post login_path, params: {session: {username: @user.username, password: "password"}}
  	assert_redirected_to @user
  	follow_redirect!
  	assert_equal "Login Successful!", flash[:success]
		assert_equal @user.id, session[:user_id]	
		assert_select "a[href=?]", logout_path
		assert_select "a[href=?]", login_path, false
  end  	

  test "invalid password/username combo" do
  	post login_path, params: {session: {username: @user.username, password: "password1"}}
  	assert_template 'sessions/new'
  	assert_equal "Invalid username/password combination", flash[:danger] 
  	assert_select "a[href=?]", logout_path, false
		assert_select "a[href=?]", login_path
  end

  test "redirect to signup" do
    get login_path
    assert_template 'sessions/new'
    assert_select "a[href=?]", signup_path
  end
end
