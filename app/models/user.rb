class User < ApplicationRecord
	has_attached_file :avatar, styles: { medium: "300x300>", thumb: "100x100>" }, default_url: "missing.png"
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

	def password_auth?(password)
		BCrypt::Password.new(self.password_digest).is_password?(password)
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
