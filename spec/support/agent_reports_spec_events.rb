RSpec.shared_context 'agent reports spec events' do
  before(:each) do
    travel_to(Time.zone.today) do
      inbox = create(:inbox, account: account, working_hours_enabled: true)
      create(:inbox_member, user: user, inbox: inbox)
      # create(:inbox_member, user: user2, inbox: inbox)

      gravatar_url = 'https://www.gravatar.com'
      stub_request(:get, /#{gravatar_url}.*/).to_return(status: 404)

      perform_enqueued_jobs do
        10.times do
          conversation = create(:conversation, account: account,
                                               inbox: inbox, assignee: user,
                                               created_at: Time.zone.today - 9.days)
          create_list(:message, 5, message_type: 'outgoing',
                                   account: account, inbox: inbox, sender: user,
                                   conversation: conversation, created_at: Time.zone.today - 8.days)
          create_list(:message, 2, message_type: 'incoming',
                                   account: account, inbox: inbox,
                                   conversation: conversation,
                                   created_at: Time.zone.today - 9.days)
          conversation.update_labels('label_1')
          conversation.label_list
          conversation.save!
        end

        5.times do
          conversation = create(:conversation, account: account,
                                               inbox: inbox, assignee: user,
                                               created_at: (Time.zone.today - 5.days))
          create_list(:message, 3, message_type: 'outgoing',
                                   account: account, inbox: inbox, sender: user,
                                   conversation: conversation,
                                   created_at: (Time.zone.today - 2.days))
          create_list(:message, 1, message_type: 'incoming',
                                   account: account, inbox: inbox,
                                   conversation: conversation,
                                   created_at: (Time.zone.today - 5.days))
          conversation.update_labels('label_2')
          conversation.label_list
          conversation.save!
        end
      end
    end
  end
end
