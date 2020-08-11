module ContactQueriesHelper

  def self.apply
    QueriesHelper.prepend(ContactQueriesHelper)
  end

  def contact_column_content(column, item)
    value = column.value_object(item)
    if value.is_a?(Array)
      values = value.collect { |v| contact_column_value(column, item, v) }.compact
      safe_join(values, ', ')
    else
      contact_column_value(column, item, value)
    end
  end

  def contact_column_value(column, item, value)
    case column.name
    when :id
      link_to value, project_contact_path(item.project, item)
    when :email
      mail_to value, item.email
    when :phone
      link_to value, "tel:#{item.phone}"
   when :attachments
      value.to_a.map {|a| format_object(a)}.join(" ").html_safe
    else
      format_object(value)
    end
  end
end
