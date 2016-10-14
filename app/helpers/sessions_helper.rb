module SessionsHelper

	def current_user
		if session[:id]
			User.find_by(id: session[:user_id])
		else
			nil
		end
	end
end
