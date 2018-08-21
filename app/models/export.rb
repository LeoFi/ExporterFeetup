class Export < ApplicationRecord
  belongs_to :shop

  validates_presence_of :name, :time

  def self.available_exports(time = nil)
    # time ||= Time.zone.now.strftime('%H:00')
    tz = TZInfo::Timezone.get("Europe/Berlin")
    time ||= tz.utc_to_local(Time.now.utc).strftime("%k:00").strip

    puts "[INFO] ExportJob: #{where(time: time).count} scheduled export(s) found at #{time}"
    where(time: time)
  end
end
