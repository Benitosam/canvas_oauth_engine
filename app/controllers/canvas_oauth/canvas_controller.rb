module CanvasOauth
  class CanvasController < CanvasOauth::ApplicationController
    skip_before_action :request_canvas_authentication

    def oauth
      redirect_path = params["redirect_to"]
      if redirect_path == "/referrals"
        feature_name = "Referral system"
      elsif redirect_path == "/leaderboards"
        feature_name = "Leaderboard"
      end
      if verify_oauth2_state(params[:state]) && params[:code]
        if (token_details = canvas.get_access_token(params[:code]))
          access_token = token_details[0][0]
          refresh_token = token_details[0][1]
          expires_in = Time.now + token_details[0][2].to_i - 5.minutes
          if CanvasOauth::Authorization.cache_token(access_token, user_id, tool_consumer_instance_guid, refresh_token, expires_in)
            course_id = session[:course_id]
            check_for_authorized_user = CanvasOauth::AuthorizedUser.where(course_id: course_id).first
            unless check_for_authorized_user.present?
              if session[:ext_roles].present?
                if session[:ext_roles].include? "urn:lti:instrole:ims/lis/Administrator"
                  user_roll = 'Admin'
                elsif session[:ext_roles].include? "urn:lti:instrole:ims/lis/Instructor"
                  user_roll = 'Teacher'
                end
                CanvasOauth::AuthorizedUser.where(user_id: user_id, user_roll: user_roll, course_id: course_id, feature_name: feature_name).create!
                redirect_to redirect_path
              end
            end
          else
            render plain: "Error: unable to save token"
          end
        else
          render plain: "Error: invalid code - #{params[:code]}"
        end
      else
        render plain: "#{feature_name} needs access to your account in order to function properly. Please try again and click log in to approve the integration."
      end
    end

    def verify_oauth2_state(callback_state)
      callback_state.present? && callback_state == session.delete(:oauth2_state)
    end
  end
end
