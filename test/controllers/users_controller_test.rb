require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get '/signup'
    assert_template 'users/new'
  end

end
