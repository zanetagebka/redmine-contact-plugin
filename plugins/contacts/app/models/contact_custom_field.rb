class ContactCustomField < CustomField

  def type_name
    :label_contact_plural
  end

  def validate_custom_field
    super
    unless visible? || roles.present?
      errors.add(:base, l(:label_role_plural) + ' ' + l('activerecord.errors.messages.blank'))
    end
  end
end
