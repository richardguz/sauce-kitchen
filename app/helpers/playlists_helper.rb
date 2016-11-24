module PlaylistsHelper
	def did_user_upvote?(user)
		puts user.id
		puts "HEY"
		1
	end
end

# <!-- <tr upvotes="<%=psong["upvotes"]%>" psongid="<%=psong['id']%>" upvoted="<% if (@user && psong["votes"].where(:user_id => @user.id).exists?)%>true<%else%>false<%end%>"> -->
