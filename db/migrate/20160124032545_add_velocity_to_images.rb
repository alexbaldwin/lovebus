class AddVelocityToImages < ActiveRecord::Migration
  def change
    add_column :images, :velocity, :float
  end
end
