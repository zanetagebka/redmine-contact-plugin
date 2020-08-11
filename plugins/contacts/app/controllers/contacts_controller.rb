class ContactsController < ApplicationController
  unloadable
  default_search_scope :contacts

  before_action :find_contact, only: %i[show edit update destroy]
  before_action :find_project_by_project_id, only: %i[new create index edit update destroy]
  before_action :authorize, only: %i[new create index edit update destroy]

  include CustomFieldsHelper
  include QueriesHelper
  include SortHelper
  helper :attachments
  helper :custom_fields
  helper :queries
  helper :attachments
  helper :sort

  def index
    use_session = !request.format.csv?
    retrieve_query(ContactQuery, use_session)

    if @query.valid?
      @contacts_count = @query.contact_count
      @contacts_pages = Paginator.new(@contacts_count, per_page_option, params['page'])
      @offset ||= @contacts_pages.offset
      @contacts = @query.contacts(offset: @contacts_pages.offset, limit: @contacts_pages.per_page)

      @filter_tags = @query.filters['tags'] && @query.filters['tags'][:values]
    else
      respond_to do |format|
        format.html { render :layout => !request.xhr? }
      end
    end
  end

  def new
    @contact = Contact.new(author_id: User.current.id, project: @project)
    @contact.safe_attributes = params[:contact]
    @contact.addresses.new
  end

  def create
    @contact = Contact.new(author_id: User.current.id, project: @project)
    @contact.init_journal(User.current)
    @contact.safe_attributes = params[:contact]
    @contact.save_attachments(params[:attachments] || (params[:contact] && params[:contact][:attachments]))
    @contact.addresses.build unless @contact.addresses
    if @contact.save
      render_attachment_warning_if_needed(@contact)
      flash[:notice] = l(:notice_contact_successful_create)
      redirect_to project_contacts_path(@project)
    else
      render :new
    end
  end

  def destroy
    if @contact.destroy
      flash[:notice] = l(:notice_successful_delete)
    else
      flash[:error] = l(:notice_unable_delete_contact)
    end
    redirect_to project_contacts_path(@project)
  end

  def edit; end

  def update
    @contact.init_journal(User.current)
    @contact.safe_attributes = params[:contact]
    @contact.save_attachments(params[:attachments] || (params[:contact] && params[:contact][:attachments]))
    if @contact.save
      render_attachment_warning_if_needed(@contact)
      flash[:notice] = l(:notice_successful_update) unless @contact.current_journal.new_record? || params[:no_flash]
      redirect_to action: :show, project_id: params[:project_id], id: @contact
    else
      render :edit
    end
  end

  def show
    @journals = @contact.visible_journals_with_index
    @journals.reverse! if User.current.wants_comments_in_reverse_order?
  end

  private

  def find_contact
    @contact = Contact.find params[:id]
    @project = @contact.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
