module JournalPatch
  def self.included(base)
    base.class_eval do
      unloadable
      belongs_to :contact, foreign_key: :journalized_id

      after_create_commit :send_notification, unless: -> { contact? }

      def contact?
        contact
      end
    end
  end
end
