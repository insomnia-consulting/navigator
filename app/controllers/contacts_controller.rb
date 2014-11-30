class ContactsController < AdminController
  before_filter :authenticate_user!, :except => [:new, :create, :opt_out]
  #before_filter :authorize, :only => [:index]

  def index
    authorize unless params[:group_id] 
    if params[:group_id]
      @group = current_user.groups.find(params[:group_id])
      @contacts = @group.contacts
    else
      @contacts = Contact.all
    end
  rescue
    Rails.logger.debug "##### You don't have access to group #{@group}"
    flash[:alert] = "You don't have access to this group."
    redirect_to root_path and return
  end
  
  def show
    @contact = Contact.find(params[:id])
    @group = Group.find(params[:group_id]) if params[:group_id]
  end

  def new
    @contact = Contact.new

    if params[:user] && current_user
      Rails.logger.debug "##### Setting a user ID on this group"
      @contact.user_id = current_user.id
    end
    logger.info "##### Group id will be #{ params[:group_id]}"

    if !params[:group_id].nil? && Group.exists?(params[:group_id]) 
      @group = Group.find(params[:group_id]) 

      if @group.exceed_contacts?
        flash[:alert] = "This contact cannot be added because you have already added #{@group.membership_level.allowed_contacts}.  You must upgrade to a 'Premium' or 'Sponsored' level to be able to add additional contacts."
        redirect_to @group
      end
    end
  end

  def create
    @contact = Contact.determine_type(params)
    unless params[:contact][:group].nil?  && params[:contact][:group][:id].nil?
      group_id = params[:contact][:group][:id]
      @group = Group.find(group_id)
      logger.info "##### Group is " + @group.name
      @group.contacts << @contact
    end

    if @contact.errors.size == 0
      redirect_to group_contact_path(@group, @contact), :notice => "Successfully created contact"  if current_user
      redirect_to root_path, :notice => "We will let you know when something is posted for \"#{@group.name}\"." unless current_user
    else
      Rails.logger.warn "##### New contact had errors #{@contact.errors.full_messages}"
      # Need to have a generic contact object on a new contact form.. 
      # otherwise the create method breaks when it tries to examine the params[:contact]
      @contact = @contact.becomes(Contact)
      render "new"
    end

  end

  def edit
    @contact = Contact.find(params[:id]).becomes(Contact)
    @group = Group.find(params[:group_id]) if params[:group_id]
  end

  def update
    # move all this garbage to the model.
    @group = Group.find(params[:group_id])
    @contact = Contact.determine_type(params)
    if @contact.errors.size == 0
      redirect_to group_contact_path(@group, @contact) , :notice => "Successfully updated contact." and return if current_user
      redirect_to root_path, :notice => "We will let you know when something is posted for \"#{@group.name}\"." and return unless current_user
    else
      @contact = @contact.becomes(Contact)
      render :action => 'edit'          
    end
  end

  def destroy
    @group = Group.find(params[:group_id]) if params[:group_id]
    @contact = Contact.find(params[:id])
    @contact.destroy
    redirect_to group_contacts_url(@group), :notice => "Successfully destroyed contact."
  end
  def opt_out
    contact = Contact.find(params[:contact_id])
    contact.destroy
  end
end
