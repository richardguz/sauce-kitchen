module SessionsHelper

	def current_user
		if (usr = $redis.get("u" + session[:user_id].to_s))
			return UserDBHelper2.new(JSON.parse(usr))
		elsif session[:user_id]
			usr = User.find_by(id: session[:user_id])
			$redis.set("u" + session[:user_id].to_s, UserCacheHelper2.new(usr).to_json)
			return usr
		else
			nil
		end
	end

	def is_current_user(user)
		if session[:user_id]
			current_user = User.find_by(id: session[:user_id])
			if (current_user == user)
				true
			else
				false
			end
		else
			false
		end
	end

	def is_logged_in
		if session[:user_id]
			return true
		else
			return false
		end
	end

	def login(user)
		session[:user_id] = user.id
	end
end


class UserDBHelper2
  def initialize(user)
    @id = user["id"]
    @username = user["username"]
    @email = user["email"]
    @password_digest = user["password_digest"]
    @created_at = user["created_at"]
    @updated_at = user["updated_at"]
    @avatar_file_name = user["avatar_file_name"]
    @avatar_content_type = user["avatar_content_type"]
    @avatar_file_size = user["avatar_file_size"]
    @avatar_updated_at = user["avatar_updated_at"]
  end

  attr_reader :id
  attr_reader :username
  attr_reader :email
  attr_reader :password_digest
  attr_reader :created_at
  attr_reader :updated_at
  attr_reader :avatar_file_name
  attr_reader :avatar_content_type
  attr_reader :avatar_file_size
  attr_reader :avatar_updated_at
end

class UserCacheHelper2
  def initialize(user)
    @id = user.id
    @username = user.username
    @email = user.email
    @password_digest = user.password_digest
    @created_at = user.created_at
    @updated_at = user.updated_at
    @avatar_file_name = user.avatar_file_name
    @avatar_content_type = user.avatar_content_type
    @avatar_file_size = user.avatar_file_size
    @avatar_updated_at = user.avatar_updated_at
  end

  attr_reader :id
  attr_reader :username
  attr_reader :email
  attr_reader :password_digest
  attr_reader :created_at
  attr_reader :updated_at
  attr_reader :avatar_file_name
  attr_reader :avatar_content_type
  attr_reader :avatar_file_size
  attr_reader :avatar_updated_at
end