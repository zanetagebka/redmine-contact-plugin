class Contact < ActiveRecord::Base
  unloadable
  include Redmine::SafeAttributes

  EMAIL_REGEX = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
  URL_REGEX = /(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?/ix

  belongs_to :project
  belongs_to :author, class_name: 'User', foreign_key: 'author_id'

  has_many :journals, as: :journalized, dependent: :destroy, inverse_of: :journalized
  has_many :addresses, dependent: :destroy, as: :addressable, class_name: 'Address'

  accepts_nested_attributes_for :addresses, reject_if: :all_blank, allow_destroy: true
  attr_writer :deleted_attachment_ids

  acts_as_attachable view_permission: :view_contacts, delete_permission: :manage_contacts
  acts_as_customizable
  acts_as_searchable columns: %w(first_name last_name company email phone),
                     project_key: "#{Project.table_name}.id",
                     date_column: 'created_on'

  acts_as_event datetime: :created_on,
                url: Proc.new { |o| { controller: :contacts, action: :show, id: o.id, project_id: o.project_id }},
                title: lambda { |contact| contact.to_s },
                description: lambda { |contact| [contact.to_s, contact.company, contact.email, contact.addresses.first].join(' ') },
                author: :author_id

  acts_as_activity_provider timestamp: "#{table_name}.updated_on",
                            type: 'contacts',
                            permission: :view_contacts,
                            author_key: :author_id,
                            scope: joins(:project).preload(:author, :project )

  after_save :delete_selected_attachments, :create_journal

  validates_presence_of :first_name, :last_name, :email
  validates_format_of :email, with: EMAIL_REGEX
  validates_format_of :website, with: URL_REGEX, allow_blank: true
  validates :phone, numericality: true, length: { minimum: 9, maximum: 15 }, allow_blank: true

  scope :companies, lambda { where(is_company: true) }
  scope :visible, lambda { |*args| joins(:project).where(Project.allowed_to_condition(args.shift || User.current, :view_contacts, *args)) }

  def to_s
    "#{first_name} #{last_name}"
  end

  def editable?(user = User.current)
    user.allowed_to?(:manage_contacts, project)
  end

  def attributes_editable?(user = User.current)
    user.allowed_to?(:manage_contacts, project)
  end

  def deletable?(user = User.current)
    user.allowed_to?(:manage_contacts, project)
  end

  def self.visible_condition(user, options = {})
    Project.where(Project.allowed_to_condition(user, :view_contacts)).pluck(:id)
  end

  def init_journal(user, notes = '')
    @current_journal ||= Journal.new(journalized: self, user: user, notes: notes)
  end

  def current_journal
    @current_journal
  end

  def clear_journal
    @current_journal = nil
  end

  def journalized_attribute_names
    names = Contact.column_names - %w(id created_on updated_on)
    names
  end

  def last_journal_id
    new_record? ? nil : journals.maximum(:id)
  end

  def journals_after(journal_id)
    scope = journals.reorder("#{Journal.table_name}.id ASC")
    if journal_id.present?
      scope = scope.where("#{Journal.table_name}.id > ?", journal_id.to_i)
    end
    scope
  end

  def visible_journals_with_index(user = User.current)
    result = journals.
        preload(:details).
        preload(user: :email_address).
        reorder(:created_on, :id).to_a

    result.each_with_index { |j, i| j.indice = i + 1 }

    unless user.allowed_to?(:view_private_notes, project)
      result.select! do |journal|
        !journal.private_notes? || journal.user == user
      end
    end
    Journal.preload_journals_details_custom_fields(result)
    result.select! { |journal| journal.notes? || journal.visible_details.any? }
    result
  end

  def self.load_visible_last_updated_by(contacts, user = User.current)
    if contacts.any?
      contact_ids = contacts.map(&:id)
      journal_ids = Journal.joins(contact: :project).
          where(journalized_type: 'Contact', journalized_id: contact_ids).
          where(Journal.visible_notes_condition(user, skip_pre_condition: true)).
          group(:journalized_id).
          maximum(:id).
          values
      journals = Journal.where(id: journal_ids).preload(:user).to_a

      contacts.each do |contact|
        journal = journals.detect { |j| j.journalized_id == contact.id }
        contact.instance_variable_set("@last_updated_by", journal.try(:user) || '')
      end
    end
  end

  def deleted_attachment_ids
    Array(@deleted_attachment_ids).map(&:to_i)
  end

  def available_custom_fields
    ContactCustomField.all
  end

  def visible_custom_field_values(user = nil)
    user_real = user || User.current
    custom_field_values.select do |value|
      value.custom_field.visible_by?(project, user_real)
    end
  end

  safe_attributes 'is_company',
                  'first_name',
                  'last_name',
                  'company',
                  'website',
                  'birthday',
                  'author_id',
                  'phone',
                  'email',
                  'project_ids',
                  'address_attributes',
                  'custom_fields',
                  'custom_field_values',
                  'deleted_attachment_ids'

  def delete_selected_attachments
    if deleted_attachment_ids.present?
      objects = attachments.where(:id => deleted_attachment_ids.map(&:to_i))
      attachments.delete(objects)
    end
  end

  def self.self_and_descendants(contacts)
    Contact.joins("JOIN #{Contact.table_name} ancestors" +
                      " ON ancestors.root_id = #{Contact.table_name}.root_id" +
                      " AND ancestors.lft <= #{Contact.table_name}.lft AND ancestors.rgt >= #{Contact.table_name}.rgt"
    ).
        where(:ancestors => { :id => contacts.map(&:id) })
  end

  private

  def create_journal
    current_journal.save if current_journal
  end
end
