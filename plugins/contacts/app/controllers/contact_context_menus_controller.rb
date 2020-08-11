class ContactContextMenusController < ContextMenusController
  before_action :find_contacts, only: :contacts

  def contacts
    @contact = @contacts.first if @contacts.size == 1
    @contact_ids = @contacts.map(&:id).sort

    @can = { edit: @contacts.all?(&:attributes_editable?),
             delete: @contacts.all?(&:deletable?) }
    @columns = params[:c]
    @options_by_custom_field = {}
    @safe_attributes = @contacts.map(&:safe_attribute_names).reduce(:&)
    render layout: false
  end

  private

  def find_contacts
    @contacts = Contact.where(id: (params[:id] || params[:ids]))
                    .preload(:project, custom_values: :custom_field)
                    .to_a

    raise ActiveRecord::RecordNotFound if @contacts.empty?
    @projects = @contacts.collect(&:project).compact.uniq
    @project = @projects.first if @projects.size == 1
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
