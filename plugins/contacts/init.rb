require 'redmine'

Rails.configuration.to_prepare do
  ContactQueriesHelper.apply
  CustomFieldsHelper::CUSTOM_FIELDS_TABS << { name: 'ContactCustomField', partial: 'custom_fields/index',
                                             label: :label_contact_plural }
end

unless Journal.included_modules.include?(JournalPatch)
  Journal.include(JournalPatch)
end

Redmine::Search.map do |search|
  search.register :contacts
end

Redmine::Activity.map do |activity|
  activity.register :contacts
end

Redmine::Plugin.register :contacts do
  name 'Contacts plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  project_module :contacts do
    permission :view_contacts, contacts: :index
    permission :manage_contacts, contacts: %i[edit update new create destroy]
  end
  menu :project_menu, :contacts, { controller: :contacts, action: :index }, caption: 'Contacts', after: :activity, param: :project_id
end
