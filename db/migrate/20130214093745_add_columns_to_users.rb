class AddColumnsToUsers < ActiveRecord::Migration
  def change
    add_column :users, :name, :string
    add_column :users, :max_number_of_wins, :integer, :default => 0
    add_column :users, :total_wins, :integer, :default => 0
    add_column :users, :total_loses, :integer, :default => 0
  end
end
