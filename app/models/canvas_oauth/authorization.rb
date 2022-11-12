module CanvasOauth
  class Authorization < ActiveRecord::Base
    validates :canvas_user_id, :token, :last_used_at, presence: true

    def self.cache_token(token, user_id, tool_consumer_instance_guid, refresh_token, expires_in, app_id)
      create do |t|
        t.token = token
        t.canvas_user_id = user_id
        t.tool_consumer_instance_guid = tool_consumer_instance_guid
        t.refresh_token = refresh_token
        t.expires_in = expires_in
        t.last_used_at = Time.now
        t.app_id = app_id
      end
    end

    def self.fetch_token(user_id, tool_consumer_instance_guid, app_id)
      user_tokens = where(canvas_user_id: user_id, tool_consumer_instance_guid: tool_consumer_instance_guid, app_id: app_id).order("created_at DESC")
      if canvas_auth = user_tokens.first
        canvas_auth.update_attribute(:last_used_at, Time.now)
        return canvas_auth.token
      end
    end

    def self.clear_tokens(user_id, tool_consumer_instance_guid, app_id)
      where(canvas_user_id: user_id, tool_consumer_instance_guid: tool_consumer_instance_guid, app_id: app_id).destroy_all
    end
  end
end
