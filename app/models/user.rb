class User < ApplicationRecord
	has_many :active_relationships, class_name: "Relationship",
																	foreign_key: "follower_id",
																	dependent: :destroy
	has_many :passive_relationships, class_name: "Relationship",
																	foreign_key: "followed_id",
																	dependent: :destroy

	has_many :following, through: :active_relationships, source: :followed
	has_many :followers, through: :passive_relationships, source: :follower
	has_attached_file :avatar, styles: { medium: "200x200>", thumb: "100x100>" }, default_url: "missing.png"
	validates_attachment_content_type :avatar, content_type: /\Aimage\/.*\z/

	before_save {self.email = self.email.downcase}
	EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
	validates :username, presence: true, uniqueness: true, length: {maximum: 30}
	validates :email, presence: true, uniqueness: {case_sensitive: false}, length: {maximum: 255},
										format: {with: EMAIL_REGEX}
	validates :password, presence: true, length: {minimum: 6}, :if => :password_digest_changed?
	#for BCRYPT gem:
	has_secure_password
	has_many :playlists
	has_many :votes, dependent: :destroy
  	has_many :upvoted_psongs, through: :votes, source: :psong
	has_many :likes, :foreign_key => "user_id"
	has_many :playlists_liked, :through => :likes, :source => :playlist

	def password_auth?(password)
		BCrypt::Password.new(self.password_digest).is_password?(password)
	end

	def follow(other_user)
		active_relationships.create(followed_id: other_user.id)
	end

	def unfollow(other_user)
		active_relationships.find_by(followed_id: other_user.id).destroy
	end

	def following?(other_user)
		following.include?(other_user)
	end

	class << self
    	# Returns the hash digest of the given string.
    	def digest(string)
      		cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
                                                    BCrypt::Engine.cost
      		BCrypt::Password.create(string, cost: cost)
    	end
  	end
end
