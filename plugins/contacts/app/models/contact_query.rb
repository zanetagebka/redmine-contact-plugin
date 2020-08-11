class ContactQuery < Query

  self.queried_class = Contact
  self.view_permission = :view_contacts

  self.available_columns = [
      QueryColumn.new(:id, sortable: "#{Contact.table_name}.id", default_order: 'desc', caption: '#', frozen: true),
      QueryColumn.new(:first_name, sortable: "#{Contact.table_name}.first_name"),
      QueryColumn.new(:last_name, sortable: "#{Contact.table_name}.last_name"),
      QueryColumn.new(:company, sortable: "#{Contact.table_name}.company", groupable: "#{Contact.table_name}.company", caption: :field_contact_company),
      QueryColumn.new(:phone, sortable: "#{Contact.table_name}.phone", caption: :field_contact_phone),
      QueryColumn.new(:email, sortable: "#{Contact.table_name}.email", caption: :field_contact_email),
      QueryColumn.new(:created_on, sortable: "#{Contact.table_name}.created_on"),
      QueryColumn.new(:updated_on, sortable: "#{Contact.table_name}.updated_on")
  ]

  def initialize(attributes = nil, *args)
    super attributes
    self.filters ||= {}
  end

  def initialize_available_filters
    add_available_filter(
        "project_id",
        :type => :list, :values => lambda { project_values }
    ) if project.nil?
    add_available_filter(
        "author_id",
        :type => :list, :values => lambda { author_values }
    )
    add_available_filter "first_name", :type => :text
    add_available_filter "last_name", :type => :text
    add_available_filter "phone", :type => :text
    add_available_filter "email", :type => :text
    add_available_filter "created_on", :type => :date_past
    add_available_filter "updated_on", :type => :date_past
    add_available_filter(
        "attachment",
        :type => :text, :name => l(:label_attachment)
    )
    add_available_filter(
        "updated_by",
        :type => :list, :values => lambda { author_values }
    )
    add_available_filter(
        "last_updated_by",
        :type => :list, :values => lambda { author_values }
    )
    add_available_filter(
        "project.status",
        :type => :list,
        :name => l(:label_attribute_of_project, :name => l(:field_status)),
        :values => lambda { project_statuses_values }
    ) if project.nil? || !project.leaf?
    add_custom_fields_filters(ContactCustomField.all)
    add_associations_custom_fields_filters :project, :author
  end

  def available_columns
    return @available_columns if @available_columns

    @available_columns = self.class.available_columns.dup
    @available_columns += ContactCustomField.all.visible.collect { |cf| QueryCustomFieldColumn.new(cf) }
    @available_columns
  end

  def default_columns_names
    @default_columns_names ||= %i[id first_name last_name phone email]
  end

  def base_scope
    Contact.joins(:project).where(statement)
  end

  def contact_count
    base_scope.count
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  def default_sort_criteria
    [%w(id desc)]
  end

  def contacts(options = {})
    order_options = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

    unless ["#{Contact.table_name}.id ASC", "#{Contact.table_name}.id DESC"].any? { |i| order_options.include?(i) }
      order_options << "#{Contact.table_name}.id DESC"
    end

    scope = Contact.joins(:project)
                   .joins(:project)
                   .where(statement)
                   .includes((["project"] + (options[:include] || [])).uniq)
                   .where(options[:conditions])
                   .order(order_options)
                   .joins(joins_for_order_statement(order_options.join(',')))
                   .limit(options[:limit]).offset(options[:offset])

    scope = scope.preload([:author, :attachments] & columns.map(&:name))

    if has_custom_field_column?
      scope = scope.preload(:custom_values)
    end

    contacts = scope.to_a

    if has_column?(:last_updated_by)
      Contact.load_visible_last_updated_by(contacts)
    end
    contacts

  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  def contact_ids(options = {})
    order_options = [group_by_sort_order, (options[:order] || sort_clause)].flatten.reject(&:blank?)

    unless ["#{Contact.table_name}.id ASC", "#{Contact.table_name}.id DESC"].any? { |i| order_option.include?(i) }
      order_option << "#{Contact.table_name}.id DESC"
    end

    Contact.joins(:project)
           .where(statement)
           .includes((["project"] + (options[:include] || [])).uniq)
           .where(options[:conditions])
           .order(order_options).joins(joins_for_order_statement(order_options.join(',')))
           .limit(options[:limit])
           .offset(options[:offset])
           .pluck(:id)

  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end

  def sql_for_updated_on_field(field, operator, value)
    case operator
    when "!*"
      "#{Contact.table_name}.updated_on = #{Contact.table_name}.created_on"
    when "*"
      "#{Contact.table_name}.updated_on > #{Contact.table_name}.created_on"
    else
      sql_for_field("updated_on", operator, value, Contact.table_name, "updated_on")
    end
  end

  def sql_for_contact_id_field(field, operator, value)
    if operator == "="
      ids = value.first.to_s.scan(/\d+/).map(&:to_i)
      if ids.present?
        "#{Contact.table_name}.id IN (#{ids.join(",")})"
      else
        "1=0"
      end
    else
      sql_for_field("id", operator, value, Contact.table_name, "id")
    end
  end

  def sql_for_attachment_field(field, operator, value)
    case operator
    when "*", "!*"
      e = (operator == "*" ? "EXISTS" : "NOT EXISTS")
      "#{e} (SELECT 1 FROM #{Attachment.table_name} a WHERE a.container_type = 'Contact' AND a.container_id = #{Contact.table_name}.id)"
    when "~", "!~"
      c = sql_contains("a.filename", value.first)
      e = (operator == "~" ? "EXISTS" : "NOT EXISTS")
      "#{e} (SELECT 1 FROM #{Attachment.table_name} a WHERE a.container_type = 'Contact' AND a.container_id = #{Contact.table_name}.id AND #{c})"
    when "^", "$"
      c = sql_contains("a.filename", value.first, (operator == "^" ? :starts_with : :ends_with) => true)
      "EXISTS (SELECT 1 FROM #{Attachment.table_name} a WHERE a.container_type = 'Contact' AND a.container_id = #{Contact.table_name}.id AND #{c})"
    end
  end

  def sql_for_updated_on_field(field, operator, value)
    case operator
    when "!*"
      "#{Contact.table_name}.updated_on = #{Contact.table_name}.created_on"
    when "*"
      "#{Contact.table_name}.updated_on > #{Contact.table_name}.created_on"
    else
      sql_for_field("updated_on", operator, value, Contact.table_name, "updated_on")
    end
  end

  def results_scope(options={})
    order_option = [group_by_sort_order, options[:order]].flatten.reject(&:blank?)

    objects_scope(options).
        order(order_option).
        joins(joins_for_order_statement(order_option.join(','))).
        limit(options[:limit]).
        offset(options[:offset])
  rescue ::ActiveRecord::StatementInvalid => e
    raise Query::StatementInvalid.new(e.message)
  end

  def journals(options={})
    Journal.visible.
        joins(:contact => %i[project]).
        where(statement).
        order(options[:order]).
        limit(options[:limit]).
        offset(options[:offset]).
        preload(:details, :user, {:contact => %i[project author]}).
        to_a
  rescue ::ActiveRecord::StatementInvalid => e
    raise StatementInvalid.new(e.message)
  end
end
