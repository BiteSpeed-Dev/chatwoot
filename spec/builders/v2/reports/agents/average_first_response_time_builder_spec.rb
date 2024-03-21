require 'rails_helper'

RSpec.describe V2::Reports::Agents::AverageFirstResponseTimeBuilder do
  include ActiveJob::TestHelper

  describe '#perform' do
    subject { builder.perform }

    let(:account) { create(:account) }
    let(:user) { create(:user, account: account) }
    let(:builder) { described_class.new(account: account, params: { business_hours: false, since: 1.month.ago, until: Time.zone.now }) }

    before do
      travel_to(Time.zone.today) do
        inbox = create(:inbox, account: account)
        create(:inbox_member, user: user, inbox: inbox)

        gravatar_url = 'https://www.gravatar.com'
        stub_request(:get, /#{gravatar_url}.*/).to_return(status: 404)

        perform_enqueued_jobs do
          10.times do
            conversation = create(:conversation, account: account,
                                                 inbox: inbox, assignee: user,
                                                 created_at: Time.zone.today)
            create_list(:message, 5, message_type: 'outgoing',
                                     account: account, inbox: inbox,
                                     conversation: conversation, created_at: Time.zone.today + 2.hours)
            create_list(:message, 2, message_type: 'incoming',
                                     account: account, inbox: inbox,
                                     conversation: conversation,
                                     created_at: Time.zone.today + 3.hours)
            conversation.update_labels('label_1')
            conversation.label_list
            conversation.save!
          end

          5.times do
            conversation = create(:conversation, account: account,
                                                 inbox: inbox, assignee: user,
                                                 created_at: (Time.zone.today - 2.days))
            create_list(:message, 3, message_type: 'outgoing',
                                     account: account, inbox: inbox,
                                     conversation: conversation,
                                     created_at: (Time.zone.today - 2.days))
            create_list(:message, 1, message_type: 'incoming',
                                     account: account, inbox: inbox,
                                     conversation: conversation,
                                     created_at: (Time.zone.today - 2.days))
            conversation.update_labels('label_2')
            conversation.label_list
            conversation.save!
          end
        end
      end
    end

    it 'returns the average first response time by agent' do
      expect(subject).to eq([])
    end
  end
end
