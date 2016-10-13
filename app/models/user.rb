class User < ApplicationRecord
	validates :username, presence: true, uniqueness: true, length: {maximum: 30}
	validates :email, presence: true, uniqueness: true, length: {maximum: 255}
end
