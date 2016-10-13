require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get users_new_url
    assert_template 'users/new'
    get '/signup'
    assert_template 'users/new'
  end

end
