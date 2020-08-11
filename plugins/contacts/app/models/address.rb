class Address < ActiveRecord::Base
  include Redmine::SafeAttributes

  safe_attributes 'street', 'region', 'city', 'country_code', 'postcode', 'address_type', 'addressable'

  belongs_to :addressable, polymorphic: true

  def country
    @country ||= l(:label_countries)[country_code.to_sym].to_s unless country_code.blank?
  end

  def blank?
    %w(street city region postcode country_code).all? { |attr| self.send(attr).blank? }
  end

  def to_s
    %w(street city postcode region country_code).map { |attr| send(attr) }.select { |a| !a.blank? }.join(', ')
  end
end
