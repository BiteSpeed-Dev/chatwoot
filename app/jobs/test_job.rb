# class TestJob < ApplicationJob
#   queue_as :default

#   def perform(*args)
#     # Do something later
#     puts "TestJob is running"

#     DailyConversationReportJob.new.generate_custom_report(785, { since: 12.month.ago, until: Time.current })
#   end
# end
