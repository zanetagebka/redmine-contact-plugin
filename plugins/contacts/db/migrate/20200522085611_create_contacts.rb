class CreateContacts < ActiveRecord::Migration[5.2]
  def change
    create_table :contacts do |t|
      t.string :first_name
      t.string :last_name
      t.string :company
      t.string :email
      t.string :phone
      t.string :website
      t.date :birthday
      t.boolean :is_company, default: false
      t.datetime :created_on
      t.datetime :updated_on

      t.references :project
      t.references :author, index: true
    end
  end
end
