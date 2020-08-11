class CreateAddresses < ActiveRecord::Migration[5.2]
  def change
    create_table :addresses do |t|
      t.string :street
      t.string :city
      t.string :region
      t.string :postcode
      t.string :country_code, limit: 2
      t.string :address_type, limit: 16
      t.references :addressable, polymorphic: true
      t.timestamps null: false
    end
    add_index :addresses, %i[addressable_id addressable_type]
    add_index :addresses, :address_type
  end
end
