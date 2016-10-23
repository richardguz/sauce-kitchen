class Vote < ApplicationRecord
	belongs_to :user
  belongs_to :psong
  validates_uniqueness_of :psong_id, scope: :user_id
end
