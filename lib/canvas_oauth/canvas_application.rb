module CanvasOauth
  module CanvasApplication
    extend ActiveSupport::Concern

    module ClassMethods
    end

    included do
      helper_method :canvas

      rescue_from CanvasApi::Authenticate, with: :reauthenticate
      rescue_from CanvasApi::Unauthorized, with: :unauthorized_canvas_access

      before_action :check_for_activation
      before_action :check_for_reauthentication
      before_action :request_canvas_authentication
    end

    protected
    def initialize_canvas
      @canvas = ::CanvasOauth::CanvasApiExtensions.build(canvas_url, user_id, tool_consumer_instance_guid)
    end

    def canvas
      @canvas || initialize_canvas
    end

    def canvas_token
      ::CanvasOauth::Authorization.fetch_token(user_id, tool_consumer_instance_guid)
    end

    def request_canvas_authentication
      if !params[:code].present? && !canvas_token.present?
        session[:oauth2_state] = SecureRandom.urlsafe_base64(24)
        redirect_url = canvas_oauth_url+"?redirect_to=#{response.request.fullpath}"
        redirect_to canvas.auth_url(redirect_url, session[:oauth2_state])
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
      tool_consumer_instance_guid = session[:tool_consumer_instance_guid]
      user_details = CanvasOauth::Authorization.where(canvas_user_id: user_id, tool_consumer_instance_guid: tool_consumer_instance_guid).first
      if user_details.present?
        expire_at = user_details.created_at.utc + 1.hour
        if Time.now.utc > expire_at
          reauthenticate
        end
      end
    end

    def check_for_activation
      is_activated = CanvasOauth::AuthorizedUser.where(course_id: session[:course_id]).present?
      unless is_activated
        if session[:ext_roles].present? && (session[:ext_roles].include? "urn:lti:instrole:ims/lis/Student")
          render plain: "The application is not yet activated, please contact your teacher to active it."
        elsif (session[:ext_roles].include? "urn:lti:instrole:ims/lis/Administrator") || (session[:ext_roles].include? "urn:lti:instrole:ims/lis/Instructor")
          request_canvas_authentication
        end
      end
    end

    def reauthenticate
      ::CanvasOauth::Authorization.clear_tokens(user_id, tool_consumer_instance_guid)
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
