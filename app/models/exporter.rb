require 'net/sftp'
require 'tempfile'

class Exporter
  HOSTNAME = ENV['TARGET_EXPORT_HOST']
  USERNAME = ENV['TARGET_EXPORT_USERNAME']
  PORT = ENV['TARGET_EXPORT_PORT']
  PASSWORD = ENV['TARGET_EXPORT_PASSWORD']

  def initialize(exports = [])
    @exports = exports
  end

  def run
    @exports.each { |export| run_export(export.shop) }
  end

  def run_export(shop)
    active_session_for(shop)

    orders = shop.orders(status: :open, financial_status: :paid)
    payload = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.orders { build_orders_xml(xml, orders) }
    end

    upload(payload.to_xml)

    ShopifyAPI::Base.clear_session
  end

  private

  def active_session_for(shop)
    session = ShopifyAPI::Session.new(shop.shopify_domain, shop.shopify_token)
    ShopifyAPI::Base.activate_session(session)
  end

  def build_orders_xml(xml, orders)
    orders.map { |order| build_xml_for_order(xml, order) }.compact
  end

  def build_xml_for_order(xml, order)
    return unless order.try(:customer).present?

    xml.order do
      xml.send(:Bestellnummer, order.name)
      xml.send(:Rechnungsnummer)
      xml.send(:Kundennummer, order.customer.default_address.customer_id)
      xml.send(:Name1, customer_name(order.customer))
      xml.send(:Name2)
      xml.send(:Adresse1, order.customer.default_address.address1)
      xml.send(:Adresse2, order.customer.default_address.address2)
      xml.send(:Adresse3)
      xml.send(:Ort, order.customer.default_address.city)
      xml.send(:PLZ, order.customer.default_address.zip)
      xml.send(:Land, order.customer.default_address.country_code)
      xml.send(:Email, order.email)
      xml.send(:Telefon, order.phone)
      xml.items { build_items_xml(xml, order.line_items) }
    end
  end

  def build_items_xml(xml, items)
    items.map { |item| build_xml_for_item(xml, item) }
  end

  def build_xml_for_item(xml, item)
    xml.item do
      xml.send(:SKU, item.sku)
      xml.send(:Bezeichnung, item.name)
      xml.send(:Menge, item.quantity.to_f)
    end
  end

  def upload(payload)
    file = Tempfile.new('temp-export')
    file.write(payload)

    Net::SFTP.start(HOSTNAME, USERNAME, password: PASSWORD, port: PORT) do |sftp|
      filename = Time.now.to_datetime.to_s
      sftp.upload!(file.path, "Testordner/#{filename}.xml")
    end

    file.close
    file.unlink
  end

  def customer_name(customer)
    "#{customer.first_name} #{customer.last_name}"
  end
end
