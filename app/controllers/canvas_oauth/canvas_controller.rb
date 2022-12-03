module CanvasOauth
  class CanvasController < CanvasOauth::ApplicationController
    skip_before_action :request_canvas_authentication

    def oauth
      redirect_path = params["redirect_to"]
      if redirect_path == "/referrals"
        feature_name = "Referral system"
      elsif redirect_path == "/leaderboards"
        feature_name = "Leaderboard"
      elsif redirect_path == "/enrollment-validity"
        feature_name = "Enrollment validity"
      end
      if verify_oauth2_state(params[:state]) && params[:code]
        if (token_details = canvas.get_access_token(params[:code]))
          access_token = token_details[0][0]
          refresh_token = token_details[0][1]
          expires_in = Time.now + token_details[0][2].to_i - 5.minutes
          key = session[:key]
          app_details = LtiProvider::Tool.where(uuid: key).first
          app_id = app_details.id
          if CanvasOauth::Authorization.cache_token(access_token, user_id, tool_consumer_instance_guid, refresh_token, expires_in, app_id)
            course_id = session[:course_id]
            check_for_authorized_user = CanvasOauth::AuthorizedUser.where(course_id: course_id, app_id: app_id).first
            if check_for_authorized_user.present?
              redirect_to redirect_path
            else
              if session[:ext_roles].present?
                if session[:ext_roles].include? "urn:lti:instrole:ims/lis/Administrator"
                  user_roll = 'Admin'
                  responses = HTTParty.get("#{app_details.domain}/api/v1/accounts", headers: { "Authorization" => "Bearer #{access_token}" })
                  responses.each do |response|
                    if response.present?
                      account_id = response["id"]
                      course_responses = HTTParty.get("#{app_details.domain}/api/v1/accounts/#{account_id}/courses", headers: { "Authorization" => "Bearer #{access_token}" })
                      course_responses.each do |course_response|
                        if course_response.present?
                          course_id = course_response["id"]
                          CanvasOauth::AuthorizedUser.where(user_id: user_id, user_roll: user_roll, course_id: course_id, feature_name: feature_name, app_id: app_id).create!
                        end
                      end
                    end
                  end
                elsif session[:ext_roles].include? "urn:lti:instrole:ims/lis/Instructor"
                  user_roll = 'Teacher'
                  CanvasOauth::AuthorizedUser.where(user_id: user_id, user_roll: user_roll, course_id: course_id, feature_name: feature_name, app_id: app_id).create!
                end
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
