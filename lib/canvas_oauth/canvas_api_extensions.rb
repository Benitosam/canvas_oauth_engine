module CanvasOauth
  class CanvasApiExtensions
    def self.build(canvas_url, user_id, tool_consumer_instance_guid, organization_id = "", app_key = "")
      key_secret_details = LtiProvider::Tool.where(organization_id: organization_id, uuid: app_key).first
      key = key_secret_details.developer_key
      secret = key_secret_details.secret
      app_id = key_secret_details.id
      token = CanvasOauth::Authorization.fetch_token(user_id, tool_consumer_instance_guid, app_id)
      CanvasApi.new(canvas_url, token, key, secret)
    end
  end
end
