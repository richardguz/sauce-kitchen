module SessionsHelper

	def current_user
		if session[:user_id]
			User.find_by(id: session[:user_id])
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
