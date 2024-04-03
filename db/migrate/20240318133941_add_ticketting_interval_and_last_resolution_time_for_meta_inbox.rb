class AddTickettingIntervalAndLastResolutionTimeForMetaInbox < ActiveRecord::Migration[7.0]
  def change
    add_column :inboxes, :ticketing_interval, :integer, default: 0
    add_column :conversations, :last_resolution_time, :datetime
  end
end
