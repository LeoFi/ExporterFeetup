class Export < ApplicationRecord
  belongs_to :shop

  validates_presence_of :name, :time

  def self.available_exports(time = nil)
    time ||= Time.zone.now.strftime('%H:00')
    puts "Checking for time: #{time}"
    where(time: time)
  end
end
