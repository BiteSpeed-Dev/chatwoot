require 'rails_helper'

describe Messages::Facebook::MessageBuilder do
  subject(:message_builder) { described_class.new(incoming_fb_text_message, facebook_channel.inbox).perform }

  before do
    stub_request(:post, /graph.facebook.com/)
  end

  let!(:facebook_channel) { create(:channel_facebook_page) }
  let!(:message_object) { build(:incoming_fb_text_message).to_json }
  let!(:incoming_fb_text_message) { Integrations::Facebook::MessageParser.new(message_object) }
  let(:fb_object) { double }

  describe '#perform' do
    it 'creates contact and message for the facebook inbox' do
      allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
      allow(fb_object).to receive(:get_object).and_return(
        {
          first_name: 'Jane',
          last_name: 'Dae',
          account_id: facebook_channel.inbox.account_id,
          profile_pic: 'https://chatwoot-assets.local/sample.png'
        }.with_indifferent_access
      )
      message_builder

      contact = facebook_channel.inbox.contacts.first
      message = facebook_channel.inbox.messages.first

      expect(contact.name).to eq('Jane Dae')
      expect(message.content).to eq('facebook message')
    end

    it 'increments channel authorization_error_count when error is thrown' do
      allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
      allow(fb_object).to receive(:get_object).and_raise(Koala::Facebook::AuthenticationError.new(500, 'Error validating access token'))
      message_builder

      expect(facebook_channel.authorization_error_count).to eq(2)
    end

    it 'raises exception for non profile account' do
      allow(Koala::Facebook::API).to receive(:new).and_return(fb_object)
      allow(fb_object).to receive(:get_object).and_raise(Koala::Facebook::ClientError.new(400, '',
                                                                                          {
                                                                                            'type' => 'OAuthException',
                                                                                            'message' => '(#100) No profile available for this user.',
                                                                                            'error_subcode' => 2_018_218,
                                                                                            'code' => 100
                                                                                          }))
      message_builder

      contact = facebook_channel.inbox.contacts.first
      # Refer: https://github.com/chatwoot/chatwoot/pull/3016 for this check
      default_name = 'John Doe'

      expect(facebook_channel.inbox.reload.contacts.count).to eq(1)
      expect(contact.name).to eq(default_name)
    end
  end

  context 'when ticketting_interval is set' do
    subject(:mocked_message_builder) do
      described_class.new(mocked_incoming_fb_text_message, facebook_channel.inbox).perform
    end

    let!(:mocked_message_object) { build(:mocked_message_text, sender_id: contact_inbox.source_id).to_json }
    let!(:mocked_incoming_fb_text_message) { Integrations::Facebook::MessageParser.new(mocked_message_object) }
    let(:contact) { create(:contact, name: 'Jane Dae') }
    let(:contact_inbox) { create(:contact_inbox, contact_id: contact.id, inbox_id: facebook_channel.inbox.id) }

    before do
      facebook_channel.inbox.update!(ticketing_interval: 600)
      stub_request(:get, /graph.facebook.com/)
    end

    it 'creates a new conversation if existing conversation is not present' do
      inital_count = Conversation.count

      mocked_message_builder

      facebook_channel.inbox.reload

      expect(facebook_channel.inbox.conversations.count).to eq(1)
      expect(Conversation.count).to eq(inital_count + 1)
    end

    it 'will not create a new conversation if last conversation is not resolved' do
      existing_conversation = create(:conversation, account_id: facebook_channel.inbox.account.id, inbox_id: facebook_channel.inbox.id,
                                                    contact_id: contact.id, contact_inbox_id: contact_inbox.id,
                                                    status: :open)

      mocked_message_builder

      facebook_channel.inbox.reload

      expect(facebook_channel.inbox.conversations.last.id).to eq(existing_conversation.id)
    end

    it 'creates a new conversation if last conversation is resolved later than ticketting interval' do
      existing_conversation = create(:conversation, account_id: facebook_channel.inbox.account.id,
                                                    inbox_id: facebook_channel.inbox.id, contact_id: contact.id, contact_inbox_id: contact_inbox.id,
                                                    status: :resolved, last_resolution_time: 11.minutes.ago)

      inital_count = Conversation.count

      mocked_message_builder

      facebook_channel.inbox.reload

      expect(facebook_channel.inbox.conversations.last.id).not_to eq(existing_conversation.id)
      expect(Conversation.count).to eq(inital_count + 1)
    end

    it 'reopens the resolved conversation if last conversation is resolved within ticketting interval' do
      existing_conversation = create(:conversation, account_id: facebook_channel.inbox.account.id,
                                                    inbox_id: facebook_channel.inbox.id, contact_id: contact.id, contact_inbox_id: contact_inbox.id,
                                                    status: :resolved, last_resolution_time: 9.minutes.ago)

      mocked_message_builder

      facebook_channel.inbox.reload

      expect(facebook_channel.inbox.conversations.last.id).to eq(existing_conversation.id)
      expect(facebook_channel.inbox.conversations.last.status).to eq('open')
    end
  end
end
