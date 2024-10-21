<!-- eslint-disable vue/no-mutating-props -->
<template>
  <woot-modal :show.sync="show" :on-close="onCancel" modal-type="right-aligned">
    <div class="h-auto overflow-auto flex flex-col">
      <woot-modal-header
        :header-title="`${$t('EDIT_CONTACT.TITLE')} - ${
          contact.name || contact.email
        }`"
        :header-content="$t('EDIT_CONTACT.DESC')"
      />
      <contact-form
        :contact="contact"
        :in-progress="uiFlags.isUpdating"
        :on-submit="onSubmit"
        @success="onSuccess"
        @cancel="onCancel"
      />
    </div>
  </woot-modal>
</template>

<script>
import { mapGetters } from 'vuex';
import ContactForm from './ContactForm.vue';

export default {
  components: {
    ContactForm,
  },
  props: {
    show: {
      type: Boolean,
      default: false,
    },
    contact: {
      type: Object,
      default: () => ({}),
    },
  },

  computed: {
    ...mapGetters({
      uiFlags: 'contacts/getUIFlags',
      accountId: 'getCurrentAccountId',
      currentUser: 'getCurrentUser',
      getAccount: 'accounts/getAccount',
    }),
    currentAccount() {
      return this.getAccount(this.accountId) || {};
    },
    shouldShowContactDetails() {
      const contactMasking =
        this.currentAccount?.custom_attributes?.contact_masking;
      if (this.currentUser.role === 'administrator' && contactMasking?.admin)
        return false;
      if (this.currentUser.role === 'agent' && contactMasking?.agent)
        return false;
      return true;
    },
  },

  methods: {
    onCancel() {
      this.$emit('cancel');
    },
    onSuccess() {
      this.$emit('cancel');
    },
    async onSubmit(contactItem) {
      await this.$store.dispatch('contacts/update', contactItem);
      await this.$store.dispatch(
        'contacts/fetchContactableInbox',
        this.contact.id
      );
    },
  },
};
</script>
