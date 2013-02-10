class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string  :login_id, :unique => true, :index => true
      t.string  :password
      t.string  :character
      t.integer :number_of_wins, :default => 0
      t.integer :number_of_combo, :default => 0

      t.timestamps
    end
  end
end
