module CanvasOauth
  module CanvasApplication
    extend ActiveSupport::Concern

    module ClassMethods
    end

    included do
      helper_method :canvas

      rescue_from CanvasApi::Authenticate, with: :reauthenticate
      rescue_from CanvasApi::Unauthorized, with: :unauthorized_canvas_access

      before_action :check_for_app_activation
      before_action :check_for_reauthentication
      before_action :request_canvas_authentication
    end

    protected

    def initialize_canvas
      tool_detail = LtiProvider::Tool.where(uuid: session[:key]).first
      organization_id = tool_detail.organization_id
      @canvas = ::CanvasOauth::CanvasApiExtensions.build(canvas_url, user_id, tool_consumer_instance_guid, organization_id, session[:key])
    end

    def canvas
      @canvas || initialize_canvas
    end

    def canvas_token
      key = session[:key]
      app_id = LtiProvider::Tool.where(uuid: key).first.id
      ::CanvasOauth::Authorization.fetch_token(user_id, tool_consumer_instance_guid, app_id)
    end

    def request_canvas_authentication
      key = session[:key]
      app = LtiProvider::Tool.where(uuid: key).first
      unless app.feature == 'Sublime Media'
        if !params[:code].present? && !canvas_token.present?
          session[:oauth2_state] = SecureRandom.urlsafe_base64(24)
          redirect_url = canvas_oauth_url + "?redirect_to=#{response.request.fullpath}"
          redirect_to canvas.auth_url(redirect_url, session[:oauth2_state])
        end
      end
    end

    def not_acceptable
      render plain: "Unable to process request", status: 406
    end

    def unauthorized_canvas_access
      render plain: "Your Canvas Developer Key is not authorized to access this data.", status: 401
    end

    def check_for_reauthentication
      user_id = session[:user_id]
      key = session[:key]
      app = LtiProvider::Tool.where(uuid: key).first
      app_id = app.id
      unless app.feature == 'Sublime Media'
        tool_consumer_instance_guid = session[:tool_consumer_instance_guid]
        user_details = CanvasOauth::Authorization.where(canvas_user_id: user_id, tool_consumer_instance_guid: tool_consumer_instance_guid, app_id: app_id).first
        if user_details.present?
          if Time.now.utc > user_details.expires_in
            check_for_access_token_expiration
          end
        end
      end
    end

    def check_for_access_token_expiration
      course_id = session[:course_id]
      tool_consumer_instance_guid = session[:tool_consumer_instance_guid]
      key = session[:key]
      app_id = LtiProvider::Tool.where(uuid: key).first.id
      authorized_user = CanvasOauth::AuthorizedUser.where(course_id: course_id, app_id: app_id).first
      if authorized_user.present?
        authorized_user_id = authorized_user.user_id
      else
        redirect_path = response.request.fullpath
        if session[:ext_roles].present?
          if session[:ext_roles].include? "urn:lti:instrole:ims/lis/Administrator"
            user_roll = 'Admin'
          elsif session[:ext_roles].include? "urn:lti:instrole:ims/lis/Instructor"
            user_roll = 'Teacher'
          end
          if redirect_path == "/referrals"
            feature_name = "Referral system"
          elsif redirect_path == "/leaderboards"
            feature_name = "Leaderboard"
          elsif redirect_path == "/enrollment-validity"
            feature_name = "Enrollment validity"
          end
          authorized_user = CanvasOauth::AuthorizedUser.where(user_id: user_id, user_roll: user_roll, course_id: course_id, feature_name: feature_name, app_id: app_id).create!
          authorized_user_id = authorized_user.user_id
        end
      end
      refresh_token_detail = CanvasOauth::Authorization.where(canvas_user_id: authorized_user_id, tool_consumer_instance_guid: tool_consumer_instance_guid, app_id: app_id).first
      old_refresh_token = refresh_token_detail.refresh_token
      refresh_token_expires_at = refresh_token_detail.expires_in
      if Time.now.utc > refresh_token_expires_at
        new_access_token_details = get_new_access_token(old_refresh_token)
        expires_in = Time.now + new_access_token_details[0][1].to_i - 5.minutes
        CanvasOauth::Authorization.where(canvas_user_id: authorized_user_id, app_id: app_id).update(token: new_access_token_details[0][0], expires_in: expires_in)
      end
    end

    def get_new_access_token(old_refresh_token)
      new_access_token_details = []
      key_secret_details = LtiProvider::Tool.where(uuid: session[:key]).first
      key = key_secret_details.developer_key
      secret = key_secret_details.secret
      domain = key_secret_details.domain
      response = HTTParty.post("#{domain}/login/oauth2/token?grant_type=refresh_token&client_id=#{key}&client_secret=#{secret}&refresh_token=#{old_refresh_token}")
      new_access_token = response['access_token']
      expires_in = response['expires_in']
      new_access_token_details << [new_access_token, expires_in]
    end

    def check_for_app_activation
      key = session[:key]
      app = LtiProvider::Tool.where(uuid: key).first
      unless app.feature == 'Sublime Media'
        is_activated = CanvasOauth::AuthorizedUser.where(course_id: session[:course_id], app_id: app.id).present?
        unless is_activated
          organization_id = session[:organization_id]
          app_created_user_email = Organization.where(id: organization_id).first.email
          if app_created_user_email == session[:canvas_user_email]
            if session[:canvas_user_current_role] == 'Instructor' || (session[:canvas_user_current_role].include? "urn:lti:instrole:ims/lis/Administrator")
              request_canvas_authentication
            else
              render plain: "You are not a Instructor in this course please contact the Instructor."
            end
          elsif CanvasOauth::AuthorizedUser.where(app_id: app.id, user_roll: 'Admin').present?
            request_canvas_authentication
          else
            render plain: "The application is not yet activated, please contact #{app_created_user_email} to active it."
          end
        end
      end
    end

    def reauthenticate
      key = session[:key]
      app_id = LtiProvider::Tool.where(uuid: key).first.id
      ::CanvasOauth::Authorization.clear_tokens(user_id, tool_consumer_instance_guid, app_id)
      request_canvas_authentication
    end

    # these next three methods rely on external session data and either need to
    # be overridden or the session data needs to be set up by the time the
    # oauth filter runs (like with the lti_provider_engine)

    def canvas_url
      session[:canvas_url]
    end

    def user_id
      session[:user_id]
    end

    def tool_consumer_instance_guid
      session[:tool_consumer_instance_guid]
    end
  end
end
