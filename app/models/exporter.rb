require 'net/sftp'
require 'tempfile'

class Exporter
  HOSTNAME = ENV['TARGET_EXPORT_HOST']
  USERNAME = ENV['TARGET_EXPORT_USERNAME']
  PORT = ENV['TARGET_EXPORT_PORT']
  PASSWORD = ENV['TARGET_EXPORT_PASSWORD']

  FTP_PATH = "/Testordner"

  def initialize(exports = [])
    @exports = exports
  end

  def run
    @exports.each { |export| run_export(export.shop) }
  end

  def run_export(shop)
    active_session_for(shop)

    exported_order_ids = shop.exported_orders.map { |order| order.shopify_order_id }
    orders = shop.orders(status: :open, financial_status: :paid)
    # orders.delete_if { |order| exported_order_ids.include?(order.id) } # TODO put this back

    orders_from_eu = orders_by_region(orders, true)
    upload_xml(orders_from_eu, shop.shopify_domain, "/EU")

    orders_from_rest_of_world = orders_by_region(orders, false)
    upload_xml(orders_from_rest_of_world, shop.shopify_domain, "/Non-EU")

    ShopifyAPI::Base.clear_session
  end

  private

  def upload_xml(orders, shop_name, directory)
    unless orders.empty?
      payload = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.orders { build_orders_xml(xml, orders) }
      end

      # upload(shop, payload.to_xml)
      tz = TZInfo::Timezone.get("Europe/Berlin")
      timestamp = tz.utc_to_local(Time.now.utc).strftime("%Y-%m-%d-%H%M%S")

      file_name = "#{ directory.upcase }-#{ timestamp }-#{ shop_name }.xml"
      file_path = FTP_PATH + directory + "/" + file_name
      Rails.logger.error file_path

      upload(payload.to_xml, file_path)

      # TODO put this back
      # orders.each do |order|
      #   ExportedOrder.create(shop_id: shop.id, shopify_order_id: order.id)
      # end
    end
  end

  def orders_by_region(orders, in_eu)
    orders.select do |order|
      country = ISO3166::Country.new(order.shipping_address.country_code)
      country.in_eu? == in_eu
    end
  end

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

  def upload(payload, file_path)
    file = Tempfile.new('temp-export')
    file.write(payload)
    file.close

    begin
      Net::SFTP.start(HOSTNAME, USERNAME, password: PASSWORD, port: PORT) do |sftp|
        # tz = TZInfo::Timezone.get("Europe/Berlin")
        # filename = tz.utc_to_local(Time.now.utc).strftime("%Y-%m-%d-%H%M%S")
        # sftp.upload!(file.path, "/Testordner/#{shop.shopify_domain}_#{filename}.xml")
        sftp.upload!(file.path, file_path)
      end
    rescue IOError => e
      Rails.logger.error e.message
    end

    file.unlink
  end

  def customer_name(customer)
    "#{customer.first_name} #{customer.last_name}"
  end
end
