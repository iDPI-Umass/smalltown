# frozen_string_literal: true

class InitialStateSerializer < ActiveModel::Serializer
  attributes :meta, :compose, :accounts,
             :media_attachments, :settings, :max_status_chars

  has_one :push_subscription, serializer: REST::WebPushSubscriptionSerializer

  def max_status_chars
    StatusLengthValidator::MAX_CHARS
  end

  def meta
    store = {
      streaming_api_base_url: Rails.configuration.x.streaming_api_base_url,
      access_token: object.token,
      locale: I18n.locale,
      domain: Rails.configuration.x.local_domain,
      title: instance_presenter.site_title,
      admin: object.admin&.id&.to_s,
      search_enabled: Chewy.enabled?,
      repository: Mastodon::Version.repository,
      source_url: Mastodon::Version.source_url,
      version: Mastodon::Version.to_s,
      invites_enabled: Setting.min_invite_role == 'user',
      mascot: instance_presenter.mascot&.file&.url,
      profile_directory: Setting.profile_directory,
      trends: Setting.trends,
      show_staff_badge: Setting.show_staff_badge,
      completely_siloed: Rails.configuration.x.whitelist_mode && DomainAllow.count() == 0,
      whitelist_mode: Rails.configuration.x.whitelist_mode,
      dms_enabled: Setting.dms_enabled,
      featured_topics: ActiveModelSerializers::SerializableResource.new(FeaturedTopic.order(created_at: :desc), each_serializer: REST::FeaturedTopicSerializer),
      support_url: Setting.support_url,
      android_icon: instance_presenter.android_icon&.file&.url,
      bookmarks: Setting.bookmarks,
      lists: Setting.lists,
      relationships: Setting.relationships,
      status_queue: Setting.status_queue,
      home_enabled: Setting.home_enabled,
      reblogs_enabled: Setting.reblogs_enabled,
      share_enabled: Setting.share_enabled,
      archive_min_status_id: Setting.archive_status_id,
      archive_max_status_id: Setting.archive_status_id == '' ? Setting.archive_status_id : calculate_archive_max,
      welcome_message: Setting.welcome_message == '' ? Setting.welcome_message : Nokogiri::HTML.fragment(Setting.welcome_message).to_s,
      tutorial: Setting.tutorial
    }

    if object.current_account
      store[:me]                = object.current_account.id.to_s
      store[:unfollow_modal]    = object.current_account.user.setting_unfollow_modal
      store[:boost_modal]       = object.current_account.user.setting_boost_modal
      store[:delete_modal]      = object.current_account.user.setting_delete_modal
      store[:auto_play_gif]     = object.current_account.user.setting_auto_play_gif
      store[:display_media]     = object.current_account.user.setting_display_media
      store[:expand_spoilers]   = object.current_account.user.setting_expand_spoilers
      store[:reduce_motion]     = object.current_account.user.setting_reduce_motion
      store[:disable_swiping]   = object.current_account.user.setting_disable_swiping
      store[:advanced_layout]   = object.current_account.user.setting_advanced_layout
      store[:use_blurhash]      = object.current_account.user.setting_use_blurhash
      store[:use_pending_items] = object.current_account.user.setting_use_pending_items
      store[:is_staff]          = object.current_account.user.staff?
      store[:trends]            = Setting.trends && object.current_account.user.setting_trends
      store[:crop_images]       = object.current_account.user.setting_crop_images
    else
      store[:auto_play_gif] = Setting.auto_play_gif
      store[:display_media] = Setting.display_media
      store[:reduce_motion] = Setting.reduce_motion
      store[:use_blurhash]  = Setting.use_blurhash
      store[:crop_images]   = Setting.crop_images
    end

    store
  end

  def compose
    store = {}

    if object.current_account
      store[:me]                = object.current_account.id.to_s
      store[:default_privacy]   = object.visibility || object.current_account.user.setting_default_privacy
      store[:default_sensitive] = object.current_account.user.setting_default_sensitive
    end

    store[:text] = object.text if object.text

    store
  end

  def accounts
    store = {}
    store[object.current_account.id.to_s] = ActiveModelSerializers::SerializableResource.new(object.current_account, serializer: REST::AccountSerializer) if object.current_account
    store[object.admin.id.to_s]           = ActiveModelSerializers::SerializableResource.new(object.admin, serializer: REST::AccountSerializer) if object.admin
    store
  end

  def media_attachments
    { accept_content_types: MediaAttachment.supported_file_extensions + MediaAttachment.supported_mime_types }
  end

  private

  def instance_presenter
    @instance_presenter ||= InstancePresenter.new
  end

  def calculate_archive_max
    status_list = Status.where('id > ?', Setting.archive_status_id)
    if status_list.empty?
      'all'
    else
      status_list.last.id.to_s
    end
  end
end
