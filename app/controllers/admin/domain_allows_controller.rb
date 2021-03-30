# frozen_string_literal: true

class Admin::DomainAllowsController < Admin::BaseController
  before_action :set_domain_allow, only: [:destroy]

  def new
    authorize :domain_allow, :create?

    @domain_allow = DomainAllow.new(domain: params[:_domain])
  end

  def create
    authorize :domain_allow, :create?

    @domain_allow = DomainAllow.new(resource_params)
    was_siloed = completely_siloed?
    if @domain_allow.save
      log_action :create, @domain_allow
      if was_siloed
        Setting.dms_enabled = true
      end
      redirect_to admin_instances_path, notice: I18n.t('admin.domain_allows.created_msg')
    else
      render :new
    end
  end

  def destroy
    authorize @domain_allow, :destroy?
    UnallowDomainService.new.call(@domain_allow)
    redirect_to admin_instances_path, notice: I18n.t('admin.domain_allows.destroyed_msg')
  end

  private

  def set_domain_allow
    @domain_allow = DomainAllow.find(params[:id])
  end

  def resource_params
    params.require(:domain_allow).permit(:domain)
  end
end
