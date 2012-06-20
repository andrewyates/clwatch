class CreateTables <  ActiveRecord::Migration
  def up
    create_table :posts do |t|
      t.string :title
      t.string :url  
      t.string :page
      t.string :postdate
      t.timestamps
    end
  end

  def down
    drop_table :posts
  end
end
