# frozen_string_literal: true

module ContactsHelper
  include ApplicationHelper

  def render_full_width_custom_fields_rows(contact)
    values = contact.visible_custom_field_values.select { |value| value.custom_field }
    return if values.empty?

    s = ''.html_safe
    values.each_with_index do |value, i|
      attr_value_tag = custom_field_value_tag(value)
      next if attr_value_tag.blank?

      content = content_tag('p', content_tag('strong', custom_field_name_tag(value.custom_field) ) +
          ": " + content_tag('span', attr_value_tag, class: 'value'))
      s << content_tag('div', content, class: "attribute")
    end
    s
  end

  def grouped_contacts_list(contacts, query, &block)
    ancestors = []
    grouped_query_results(contacts, query) do |contact, group_name, group_count, group_totals|
      ancestors.pop while ancestors.any?
      yield contact, ancestors.size, group_name, group_count, group_totals
      ancestors << contact
    end
  end

  def contact_history_tabs
    tabs = []
    tabs << { name: 'history', label: :label_history, onclick: 'showContactHistory("history", this.href', partial: 'contacts/tabs/history', locals: { contact: @contact, journals: @journals } }
    tabs
  end

  def contact_history_default_tab
    return params[:tab] if params[:tab].present?

    user_default_tab = User.current.pref.history_default_tab

    case user_default_tab
    when 'last_tab_visited'
      cookies['history_last_tab'].presence || 'history'
    when ''
      'history'
    else
      user_default_tab
    end
  end

  def find_name_by_reflection(field, id)
    return nil if id.blank?

    @detail_value_name_by_reflection ||= Hash.new do |hash, key|
      association = Contact.reflect_on_association(key.first.to_sym)
      name = nil
      if association
        record = association.klass.find_by_id(key.last)
        if record
          name = record.name.force_encoding('UTF-8')
        end
      end
      hash[key] = name
    end
    @detail_value_name_by_reflection[[field, id]]
  end

  def show_detail(detail, no_html=false, options={})
    multiple = false
    show_diff = false
    no_details = false

    case detail.property
    when 'attr'
      field = detail.prop_key.to_s.gsub(/\_id$/, "")
      label = l(("field_" + field).to_sym)
      case detail.prop_key
      when 'project_id'
        value = find_name_by_reflection(field, detail.value)
        old_value = find_name_by_reflection(field, detail.old_value)
      end
    when 'cf'
      custom_field = detail.custom_field
      if custom_field
        label = custom_field.name
        if custom_field.format.class.change_no_details
          no_details = true
        elsif custom_field.format.class.change_as_diff
          show_diff = true
        else
          multiple = custom_field.multiple?
          value = format_value(detail.value, custom_field) if detail.value
          old_value = format_value(detail.old_value, custom_field) if detail.old_value
        end
      end
    when 'attachment'
      label = l(:label_attachment)
    end
    label ||= detail.prop_key
    value ||= detail.value
    old_value ||= detail.old_value
    unless no_html
      label = content_tag('strong', label)
      old_value = content_tag("i", h(old_value)) if detail.old_value
      if detail.old_value && detail.value.blank? && detail.property != 'relation'
        old_value = content_tag("del", old_value)
      end
      if detail.property == 'attachment' && value.present? &&
          atta = detail.journal.journalized.attachments.detect {|a| a.id == detail.prop_key.to_i}
        # Link to the attachment if it has not been removed
        value = link_to_attachment(atta, only_path: options[:only_path])
        if options[:only_path] != false
          value += ' '
          value += link_to_attachment atta, class: 'icon-only icon-download', title: l(:button_download), download: true
        end
      else
        value = content_tag("i", h(value)) if value
      end
    end

    if no_details
      s = l(:text_journal_changed_no_detail, :label => label).html_safe
    elsif show_diff
      s = l(:text_journal_changed_no_detail, :label => label)
      unless no_html
        diff_link =
            link_to(
                'diff',
                diff_journal_url(detail.journal_id, :detail_id => detail.id,
                                 :only_path => options[:only_path]),
                :title => l(:label_view_diff))
        s << " (#{diff_link})"
      end
      s.html_safe
    elsif detail.value.present?
      case detail.property
      when 'attr', 'cf'
        if detail.old_value.present?
          l(:text_journal_changed, :label => label, :old => old_value, :new => value).html_safe
        elsif multiple
          l(:text_journal_added, :label => label, :value => value).html_safe
        else
          l(:text_journal_set_to, :label => label, :value => value).html_safe
        end
      when 'attachment'
        l(:text_journal_added, :label => label, :value => value).html_safe
      end
    else
      l(:text_journal_deleted, :label => label, :old => old_value).html_safe
    end
  end

  def details_to_strings(details, no_html=false, options={})
    options[:only_path] = !(options[:only_path] == false)
    strings = []
    values_by_field = {}
    details.each do |detail|
      if detail.property == 'cf'
        field = detail.custom_field
        if field && field.multiple?
          values_by_field[field] ||= {:added => [], :deleted => []}
          if detail.old_value
            values_by_field[field][:deleted] << detail.old_value
          end
          if detail.value
            values_by_field[field][:added] << detail.value
          end
          next
        end
      end
      strings << show_detail(detail, no_html, options)
    end
    if values_by_field.present?
      values_by_field.each do |field, changes|
        if changes[:added].any?
          detail = MultipleValuesDetail.new('cf', field.id.to_s, field)
          detail.value = changes[:added]
          strings << show_detail(detail, no_html, options)
        end
        if changes[:deleted].any?
          detail = MultipleValuesDetail.new('cf', field.id.to_s, field)
          detail.old_value = changes[:deleted]
          strings << show_detail(detail, no_html, options)
        end
      end
    end
    strings
  end
end
