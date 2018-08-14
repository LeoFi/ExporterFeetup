class Shop < ActiveRecord::Base
  include ShopifyApp::SessionStorage

  has_many :exports
  has_many :exported_orders

  def orders(params = nil)
    params ||= { status: :any }
    ShopifyAPI::Order.find(:all, params: params)
  end

  def name
    shopify_domain.split('.').first
  end
end
