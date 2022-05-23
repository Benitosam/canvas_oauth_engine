module CanvasOauth
  class CanvasController < CanvasOauth::ApplicationController
    skip_before_action :request_canvas_authentication

    def oauth
      if verify_oauth2_state(params[:state]) && params[:code]
        if token = canvas.get_access_token(params[:code])
          if CanvasOauth::Authorization.cache_token(token, user_id, tool_consumer_instance_guid)
            redirect_path = params["redirect_to"]
            course_id = session[:course_id]
            check_for_authorized_user = CreateAuthorizedUser.where(course_id: course_id).first
            unless check_for_authorized_user.present?
              if session[:ext_roles].present?
                if (session[:ext_roles].include? "urn:lti:instrole:ims/lis/Administrator")
                  user_roll = 'Admin'
                elsif (session[:ext_roles].include? "urn:lti:instrole:ims/lis/Instructor")
                  user_roll = 'Teacher'
                end
                if redirect_path == "/referrals"
                  feature_name = "Referral system"
                elsif redirect_path == "/leaderboards"
                  feature_name = "Leaderboard"
                end
                CreateAuthorizedUser.where(user_id: user_id, enrollment_type: user_roll, course_id: course_id, feature: feature_name).create!
                redirect_to redirect_path
              end
            end
            redirect_to params["redirect_to"]
          else
            render plain: "Error: unable to save token"
          end
        else
          render plain: "Error: invalid code - #{params[:code]}"
        end
      else
        render plain: "#{CanvasOauth::Config.tool_name} needs access to your account in order to function properly. Please try again and click log in to approve the integration."
      end
    end

    def verify_oauth2_state(callback_state)
      callback_state.present? && callback_state == session.delete(:oauth2_state)
    end
  end
end
