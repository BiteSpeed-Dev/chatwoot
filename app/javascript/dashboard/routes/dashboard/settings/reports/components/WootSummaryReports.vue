<template>
  <div class="flex-1 overflow-auto p-4">
    <woot-button
      v-if="!showAdvancedFilters"
      color-scheme="success"
      class-names="button--fixed-top"
      icon="arrow-download"
      @click="downloadReports"
    >
      {{ downloadButtonLabel }}
    </woot-button>
    <div
      v-if="agentTableType === 'overview'"
      class="flex items-center button--fixed-top w-[350px]"
    >
      <span class="mr-2 text-sm w-[125px]">Metrics type</span>
      <multiselect
        v-model="selectedMetricType"
        class="no-margin"
        :placeholder="'Select metrics type'"
        :options="metricTypeOptions"
        :option-height="20"
        :show-labels="false"
        @input="onMetricTypeChange"
      />
    </div>
    <report-filter-selector
      :show-agents-filter="false"
      :show-labels-filter="showAdvancedFilters"
      :show-inbox-filter="showAdvancedFilters"
      @filter-change="onFilterChange"
    />
    <ve-table
      max-height="calc(100vh - 21.875rem)"
      :fixed-header="true"
      :columns="columns"
      :table-data="tableData"
      :scroll-width="scrollWidth"
      style="overflow-x: auto"
    />
  </div>
</template>

<script>
import ReportFilterSelector from './FilterSelector.vue';
import { formatTime } from '@chatwoot/utils';

import reportMixin from '../../../../../mixins/reportMixin';
import alertMixin from 'shared/mixins/alertMixin';

import { generateFileName } from '../../../../../helper/downloadHelper';
import { VeTable } from 'vue-easytable';

export default {
  components: {
    VeTable,
    ReportFilterSelector,
  },
  mixins: [reportMixin, alertMixin],
  props: {
    type: {
      type: String,
      default: 'account',
    },
    getterKey: {
      type: String,
      default: '',
    },
    actionKey: {
      type: String,
      default: '',
    },
    summaryKey: {
      type: String,
      default: '',
    },
    downloadButtonLabel: {
      type: String,
      default: 'Download Reports',
    },
    showAdvancedFilters: {
      type: Boolean,
      default: false,
    },
    agentTableType: {
      type: String,
      default: 'default',
    },
  },
  data() {
    return {
      from: 0,
      to: 0,
      selectedFilter: null,
      businessHours: false,
      selectedMetricType: 'Average',
    };
  },
  computed: {
    scrollWidth() {
      // Calculate the total width based on the number of columns
      // Assuming a minimum width of 150px per column
      return `${this.columns.length * 150}px`;
    },
    metricTypeOptions() {
      return ['Average', 'Median'];
    },
    columns() {
      // TODO: make a format to add definitions with ?
      if (this.agentTableType === 'overview') {
        const baseColumns = [
          {
            field: 'agent',
            key: 'agent',
            title: this.type,
            fixed: 'left',
            align: this.isRTLView ? 'right' : 'left',
            width: 25,
            renderBodyCell: ({ row }) => (
              <div class="row-user-block">
                <div class="user-block">
                  <h6 class="title overflow-hidden whitespace-nowrap text-ellipsis text-sm capitalize">
                    {row.name}
                  </h6>
                </div>
              </div>
            ),
          },
          {
            field: 'resolutionsCount',
            key: 'resolutionsCount',
            title: 'Resolved',
            align: this.isRTLView ? 'right' : 'left',
            width: 20,
          },
        ];

        if (this.selectedMetricType === 'Median') {
          baseColumns.push(
            {
              field: 'medianFirstResponseTime',
              key: 'medianFirstResponseTime',
              title: 'Median first response time',
              align: this.isRTLView ? 'right' : 'left',
              width: 20,
            },
            {
              field: 'medianResolutionTime',
              key: 'medianResolutionTime',
              title: 'Median resolution time',
              align: this.isRTLView ? 'right' : 'left',
              width: 20,
            },
            {
              field: 'medianResponseTime',
              key: 'medianResponseTime',
              title: 'Median response time',
              align: this.isRTLView ? 'right' : 'left',
              width: 20,
            },
            {
              field: 'medianCsatScore',
              key: 'medianCsatScore',
              title: 'Median CSAT score',
              align: this.isRTLView ? 'right' : 'left',
              width: 20,
            }
          );
        }

        if (this.selectedMetricType === 'Average') {
          baseColumns.push(
            {
              field: 'avgFirstResponseTime',
              key: 'avgFirstResponseTime',
              title: 'Avg. first response time',
              align: this.isRTLView ? 'right' : 'left',
              width: 20,
            },
            {
              field: 'avgResolutionTime',
              key: 'avgResolutionTime',
              title: 'Avg. resolution time',
              align: this.isRTLView ? 'right' : 'left',
              width: 20,
            },
            {
              field: 'avgResponseTime',
              key: 'avgResponseTime',
              title: 'Avg. response time',
              align: this.isRTLView ? 'right' : 'left',
              width: 20,
            },
            {
              field: 'avgCsatScore',
              key: 'avgCsatScore',
              title: 'Avg. CSAT score',
              align: this.isRTLView ? 'right' : 'left',
              width: 20,
            }
          );
        }
        return baseColumns;
      }

      if (this.agentTableType === 'conversationStates') {
        const baseColumns = [
          {
            field: 'agent',
            key: 'agent',
            title: this.type,
            fixed: 'left',
            align: this.isRTLView ? 'right' : 'left',
            width: 25,
            renderBodyCell: ({ row }) => (
              <div class="row-user-block">
                <div class="user-block">
                  <h6 class="title overflow-hidden whitespace-nowrap text-ellipsis text-sm capitalize">
                    {row.name}
                  </h6>
                </div>
              </div>
            ),
          },
          {
            field: 'handled',
            key: 'handled',
            title: 'Handled',
            align: this.isRTLView ? 'right' : 'left',
            width: 20,
          },
          {
            field: 'newAssigned',
            key: 'newAssigned',
            title: 'New Assigned',
            align: this.isRTLView ? 'right' : 'left',
            width: 20,
          },
          {
            field: 'open',
            key: 'open',
            title: 'Open',
            align: this.isRTLView ? 'right' : 'left',
            width: 20,
          },
          {
            field: 'reopened',
            key: 'reopened',
            title: 'Reopened',
            align: this.isRTLView ? 'right' : 'left',
            width: 20,
          },
          {
            field: 'carryForwarded',
            key: 'carryForwarded',
            title: 'Carry Forwarded',
            align: this.isRTLView ? 'right' : 'left',
            width: 20,
          },
          {
            field: 'resolved',
            key: 'resolved',
            title: 'Resolved',
            align: this.isRTLView ? 'right' : 'left',
            width: 20,
          },
          {
            field: 'waitingAgentResponse',
            key: 'waitingAgentResponse',
            title: 'Waiting agent response',
            align: this.isRTLView ? 'right' : 'left',
            width: 20,
          },
          {
            field: 'waitingCustomerResponse',
            key: 'waitingCustomerResponse',
            title: 'Waiting customer response',
            align: this.isRTLView ? 'right' : 'left',
            width: 20,
          },
          {
            field: 'snoozed',
            key: 'snoozed',
            title: 'Snoozed',
            align: this.isRTLView ? 'right' : 'left',
            width: 20,
          },
        ];

        return baseColumns;
      }
      const baseColumns = [
        {
          field: 'agent',
          key: 'agent',
          title: this.type,
          fixed: 'left',
          align: this.isRTLView ? 'right' : 'left',
          width: 25,
          renderBodyCell: ({ row }) => (
            <div class="row-user-block">
              <div class="user-block">
                <h6 class="title overflow-hidden whitespace-nowrap text-ellipsis text-sm capitalize">
                  {row.name}
                </h6>
              </div>
            </div>
          ),
        },
        {
          field: 'conversationsCount',
          key: 'conversationsCount',
          title: 'Assigned',
          align: this.isRTLView ? 'right' : 'left',
          width: 20,
        },
        {
          field: 'resolutionsCount',
          key: 'resolutionsCount',
          title: 'Resolved',
          align: this.isRTLView ? 'right' : 'left',
          width: 20,
        },
        {
          field: 'avgFirstResponseTime',
          key: 'avgFirstResponseTime',
          title: 'Avg. first response time',
          align: this.isRTLView ? 'right' : 'left',
          width: 20,
        },
        {
          field: 'avgResolutionTime',
          key: 'avgResolutionTime',
          title: 'Avg. resolution time',
          align: this.isRTLView ? 'right' : 'left',
          width: 20,
        },
      ];

      if (this.type === 'agent') {
        baseColumns.push(
          {
            field: 'onlineTime',
            key: 'onlineTime',
            title: 'Online Time',
            align: this.isRTLView ? 'right' : 'left',
            width: 20,
          },
          {
            field: 'busyTime',
            key: 'busyTime',
            title: 'Busy Time',
            align: this.isRTLView ? 'right' : 'left',
            width: 20,
          }
        );
      }

      return baseColumns;
    },
    tableData() {
      if (this.agentTableType === 'overview') {
        return this.filterItemsList.map(team => {
          const typeMetrics = this.getMetrics(team.id);
          return {
            name: team.name,
            resolutionsCount: typeMetrics.resolved || '--',
            avgFirstResponseTime:
              this.renderContent(typeMetrics.avg_first_response_time) || '--',
            avgResolutionTime:
              this.renderContent(typeMetrics.avg_resolution_time) || '--',
            avgResponseTime:
              this.renderContent(typeMetrics.avg_response_time) || '--',
            avgCsatScore:
              this.renderContent(typeMetrics.avg_csat_score) || '--',
            medianFirstResponseTime:
              this.renderContent(typeMetrics.median_first_response_time) ||
              '--',
            medianResolutionTime:
              this.renderContent(typeMetrics.median_resolution_time) || '--',
            medianResponseTime:
              this.renderContent(typeMetrics.median_response_time) || '--',
            medianCsatScore:
              this.renderContent(typeMetrics.median_csat_score) || '--',
          };
        });
      }

      if (this.agentTableType === 'conversationStates') {
        return this.filterItemsList.map(team => {
          const typeMetrics = this.getMetrics(team.id);
          return {
            name: team.name,
            handled: typeMetrics.handled || '--',
            newAssigned: typeMetrics.new_assigned || '--',
            open: typeMetrics.open || '--',
            reopened: typeMetrics.reopened || '--',
            carryForwarded: typeMetrics.carry_forwarded || '--',
            resolved: typeMetrics.resolved || '--',
            waitingCustomerResponse:
              typeMetrics.waiting_customer_response || '--',
            waitingAgentResponse: typeMetrics.waiting_agent_response || '--',
            snoozed: typeMetrics.snoozed || '--',
          };
        });
      }

      return this.filterItemsList.map(team => {
        const typeMetrics = this.getMetrics(team.id);
        return {
          name: team.name,
          conversationsCount: typeMetrics.conversations_count || '--',
          avgFirstResponseTime:
            this.renderContent(typeMetrics.avg_first_response_time) || '--',
          avgResolutionTime:
            this.renderContent(typeMetrics.avg_resolution_time) || '--',
          onlineTime: this.renderContent(typeMetrics.online_time) || '--',
          busyTime: this.renderContent(typeMetrics.busy_time) || '--',
          resolutionsCount: typeMetrics.resolved_conversations_count || '--',
        };
      });
    },
    filterItemsList() {
      return this.$store.getters[this.getterKey] || [];
    },
    typeMetrics() {
      return this.$store.getters[this.summaryKey] || [];
    },
  },
  mounted() {
    this.fetchAllData();
  },
  methods: {
    renderContent(value) {
      return value ? formatTime(value) : '--';
    },
    getMetrics(id) {
      return this.typeMetrics.find(metrics => metrics.id === Number(id)) || {};
    },
    emitFilterChange() {
      this.$emit('filter-change', {
        since: this.from,
        until: this.to,
        businessHours: this.businessHours,
        selectedLabel: this.selectedLabel,
        selectedInbox: this.selectedInbox,
        metricType: this.selectedMetricType,
      });
    },
    fetchAllData() {
      const { from, to, businessHours, selectedLabel, selectedInbox } = this;
      this.emitFilterChange();
      this.$store.dispatch(this.actionKey, {
        since: from,
        until: to,
        businessHours,
        selectedLabel,
        selectedInbox,
      });
    },
    downloadReports() {
      const { from, to, type, businessHours } = this;
      const dispatchMethods = {
        agent: 'downloadAgentReports',
        label: 'downloadLabelReports',
        inbox: 'downloadInboxReports',
        team: 'downloadTeamReports',
      };
      if (dispatchMethods[type]) {
        const fileName = generateFileName({ type, to, businessHours });
        const params = { from, to, fileName, businessHours };
        this.$store.dispatch(dispatchMethods[type], params);
        if (type === 'agent') {
          this.showAlert(
            'The report will soon be available in all administrator email inboxes.'
          );
        }
      }
    },
    onMetricTypeChange(value) {
      this.selectedMetricType = value;
      this.fetchAllData();
    },
    onFilterChange({ from, to, businessHours, selectedLabel, selectedInbox }) {
      this.from = from;
      this.to = to;
      this.businessHours = businessHours;
      this.selectedLabel = selectedLabel;
      this.selectedInbox = selectedInbox;
      this.fetchAllData();
    },
  },
};
</script>
