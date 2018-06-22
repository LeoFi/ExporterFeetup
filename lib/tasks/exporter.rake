namespace :exporter do
  desc 'run all exports due at the current hour'
  task run: :environment do
    puts 'Running export now:'
    available_exports = Export.available_exports
    exit unless available_exports.present?

    Exporter.new(available_exports).run
  end
end
