class User < ActiveRecord::Base
  attr_accessible :login_id, :password, :character, :number_of_wins, :number_of_combo, :name, :max_number_of_wins, :total_wins, :total_loses

  validates :login_id, :presence => true, :uniqueness => true
  validates :password, :presence => true
  validates :character, :presence => true
end
