require 'rails_helper'

## This spec is to test the combined agent reports since there is a lot of repetition in the agent reports setup
## which can be just done once and it can be used in all the agent reports specs
describe 'Combined Agent Reports' do # rubocop:disable RSpec/DescribeClass
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:time_range_end) { Time.zone.today.end_of_day }
  let(:time_range_begin) { Time.zone.today - 7.days }
  let(:user) { create(:user, account: account, name: 'Test Agent', email: 'agent@test.com') }
  let(:inbox) { create(:inbox, account: account, working_hours_enabled: true) }
  let(:inbox_member) { create(:inbox_member, user: user, inbox: inbox) }

  # Note that all the reporting events are in a separate helper file since they take up a lot of space and make tests unreadable
  include_context 'agent reports spec events'

  describe V2::Reports::Agents::AverageFirstResponseTimeBuilder do
    subject { builder.perform }

    let(:business_hours) { false } # default
    let(:group_by) { 'day' } # default

    let(:builder) do
      described_class.new(
        account: account,
        params: {
          business_hours: business_hours,
          since: time_range_begin.to_time,
          until: time_range_end.to_time,
          group_by: group_by
        }
      )
    end

    context 'with defaults when business hours is false and group by is set to day' do
      it 'returns the average first response time by agent' do
        # avg value in seconds of 10 records with 1 day first response time and 5 records with 3 days resp time
        expected_avg_first_response = 144_000.0

        expect(subject.size).to eq(1)

        agent_report = subject.pop

        expect(agent_report[:id]).to eq(user.id)

        report_entries = agent_report[:entries]
        expect(report_entries[Time.zone.today]).to eq(expected_avg_first_response)
      end
    end

    context 'when business hours is true and group by is set to day' do
      let(:business_hours) { true }

      it 'returns the average first response time by agent' do
        # avg business hours value in seconds of 10 records with 1 day first resp time and 5 records with 3 days resp time
        expected_avg_first_response = 28_800.0
        expect(subject.size).to eq(1)

        agent_report = subject.pop

        expect(agent_report[:id]).to eq(user.id)

        report_entries = agent_report[:entries]
        expect(report_entries[Time.zone.today]).to eq(expected_avg_first_response)
      end
    end

    context 'when group by is set to week' do
      let(:group_by) { 'week' }

      it 'returns the average first response time by agent' do
        # avg value in seconds of 10 records with 1 day first response time and 5 records with 3 days resp time
        expected_avg_first_response = 144_000.0
        expected_entry_for_weekly_group_by = Time.zone.today.beginning_of_week(:sunday)

        expect(subject.size).to eq(1)

        agent_report = subject.pop

        expect(agent_report[:id]).to eq(user.id)

        report_entries = agent_report[:entries]
        expect(report_entries[expected_entry_for_weekly_group_by]).to eq(expected_avg_first_response)
      end
    end

    context 'when group by is set to month' do
      let(:group_by) { 'month' }

      it 'returns the average first response time by agent' do
        # avg value in seconds of 10 records with 1 day first response time and 5 records with 3 days resp time
        expected_avg_first_response = 144_000.0
        expected_entry_for_monthly_group_by = Time.zone.today.beginning_of_month

        expect(subject.size).to eq(1)

        agent_report = subject.pop

        expect(agent_report[:id]).to eq(user.id)

        report_entries = agent_report[:entries]
        expect(report_entries[expected_entry_for_monthly_group_by]).to eq(expected_avg_first_response)
      end
    end

    context 'when group by is set to year' do
      let(:group_by) { 'year' }

      it 'returns the average first response time by agent' do
        # avg value in seconds of 10 records with 1 day first response time and 5 records with 3 days resp time
        expected_avg_first_response = 144_000.0
        expected_entry_for_yearly_group_by = Time.zone.today.beginning_of_year

        expect(subject.size).to eq(1)

        agent_report = subject.pop

        expect(agent_report[:id]).to eq(user.id)

        report_entries = agent_report[:entries]
        expect(report_entries[expected_entry_for_yearly_group_by]).to eq(expected_avg_first_response)
      end
    end

    context 'when group by is set to invalid value' do
      let(:group_by) { 'invalid' }

      it 'raises an error' do
        expect { subject }.to raise_error(ActiveModel::ValidationError)
      end
    end
  end
end
