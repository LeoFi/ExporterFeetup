class CreateExportedOrders < ActiveRecord::Migration[5.2]
  def change
    create_table :exported_orders do |t|
      t.integer :shopify_order_id, null: false
      t.references :shop, foreign_key: true

      t.timestamps
    end
  end
end
