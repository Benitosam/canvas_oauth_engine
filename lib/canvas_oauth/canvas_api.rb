module CanvasOauth
  class CanvasApi
    include HTTParty
    PER_PAGE = 50

    attr_accessor :token, :key, :secret
    attr_reader :canvas_url

    def initialize(canvas_url, token, key, secret)
      unless [key, secret].all?(&:present?)
        raise "Invalid Canvas oAuth configuration"
      end

      self.canvas_url = canvas_url
      self.token = token
      self.key = key
      self.secret = secret
    end

    def authenticated_request(method, *params)
      params << {} if params.size == 1

      params.last[:headers] ||= {}
      params.last[:headers]['Authorization'] = "Bearer #{token}"

      start = Time.now

      response = self.class.send(method, *params)

      Rails.logger.info {
        stop = Time.now
        elapsed = ((stop - start) * 1000).round(2)

        params.last[:headers].reject! { |k| k == 'Authorization' }
        "API call (#{elapsed}ms): #{method} #{params.inspect}"
      }

      if response && response.unauthorized?
        if response.headers['WWW-Authenticate'].present?
          raise CanvasApi::Authenticate
        else
          raise CanvasApi::Unauthorized
        end
      else
        return response
      end
    end

    def paginated_get(url, params = {})
      params[:query] ||= {}
      params[:query][:per_page] = PER_PAGE

      all_pages = []

      while url && current_page = authenticated_get(url, params) do
        all_pages.concat(current_page) if valid_page?(current_page)

        links = LinkHeader.parse(current_page.headers['link'])
        url = links.find_link(["rel", "next"]).try(:href)
        params[:query] = nil if params[:query]
      end

      all_pages
    end

    def get_report(account_id, report_type, params)
      report = authenticated_post("/api/v1/accounts/#{account_id}/reports/#{report_type}", { body: params })
      report = authenticated_get "/api/v1/accounts/#{account_id}/reports/#{report_type}/#{report['id']}"
      while (report['status'] == 'created' || report['status'] == 'running')
        sleep(4)
        report = authenticated_get "/api/v1/accounts/#{account_id}/reports/#{report_type}/#{report['id']}"
      end

      if report['status'] == 'complete'
        file_id = report['file_url'].match(/files\/([0-9]+)\/download/)[1]
        file = get_file(file_id)
        return hash_csv(self.class.get(file['url'], limit: 15, parser: DefaultUTF8Parser).parsed_response)
      else
        return report
      end
    end

    def valid_page?(page)
      page && page.size > 0
    end

    def get_file(file_id)
      authenticated_get "/api/v1/files/#{file_id}"
    end

    def get_accounts_provisioning_report(account_id)
      get_report(account_id, :provisioning_csv, 'parameters[accounts]' => true)
    end

    #Needs to be refactored to somewhere more generic
    def hash_csv(csv_string)
      require 'csv'

      csv = csv_string.is_a?(String) ? CSV.parse(csv_string) : csv_string
      headers = csv.shift
      output = []

      csv.each do |row|
        hash = {}
        headers.each do |header|
          hash[header] = row.shift.to_s
        end
        output << hash
      end

      return output
    end

    def authenticated_get(*params)
      authenticated_request(:get, *params)
    end

    def authenticated_post(*params)
      authenticated_request(:post, *params)
    end

    def authenticated_put(*params)
      authenticated_request(:put, *params)
    end

    def get_courses
      paginated_get "/api/v1/courses"
    end

    def get_account(account_id)
      authenticated_get "/api/v1/accounts/#{account_id}"
    end

    def get_account_sub_accounts(account_id)
      paginated_get "/api/v1/accounts/#{account_id}/sub_accounts", { query: { :recursive => true } }
    end

    def get_account_courses(account_id)
      paginated_get "/api/v1/accounts/#{account_id}/courses"
    end

    def get_account_users(account_id)
      paginated_get "/api/v1/accounts/#{account_id}/users"
    end

    def get_course(course_id)
      authenticated_get "/api/v1/courses/#{course_id}"
    end

    def get_section_enrollments(section_id)
      paginated_get "/api/v1/sections/#{section_id}/enrollments"
    end

    def get_user_enrollments(user_id)
      paginated_get "/api/v1/users/#{user_id}/enrollments"
    end

    def get_course_users(course_id)
      paginated_get "/api/v1/courses/#{course_id}/users"
    end

    def get_all_course_users(course_id)
      paginated_get "/api/v1/courses/#{course_id}/users", { query: {enrollment_state: ["active","invited","rejected","completed","inactive"] } }
    end

    def get_course_teachers_and_tas(course_id)
      paginated_get "/api/v1/courses/#{course_id}/users", { query: { enrollment_type: ['teacher', 'ta'] } }
    end

    def get_course_students(course_id)
      paginated_get "/api/v1/courses/#{course_id}/students"
    end

    def get_section(section_id)
      authenticated_get "/api/v1/sections/#{section_id}"
    end

    def get_sections(course_id)
      paginated_get "/api/v1/courses/#{course_id}/sections", { query: { :include => ['students', 'avatar_url', 'enrollments'] } }
    end

    def get_assignments(course_id)
      paginated_get "/api/v1/courses/#{course_id}/assignments"
    end

    def get_assignment(course_id, assignment_id)
      authenticated_get "/api/v1/courses/#{course_id}/assignments/#{assignment_id}"
    end

    def get_user_profile(user_id)
      authenticated_get "/api/v1/users/#{user_id}/profile"
    end

    def create_assignment(course_id, params)
      authenticated_post "/api/v1/courses/#{course_id}/assignments", { body: { assignment: params } }
    end

    def update_assignment(course_id, assignment_id, params)
      authenticated_put "/api/v1/courses/#{course_id}/assignments/#{assignment_id}", { body: { assignment: params } }
    end

    def grade_assignment(course_id, assignment_id, user_id, params)
      authenticated_put "/api/v1/courses/#{course_id}/assignments/#{assignment_id}/submissions/#{user_id}", { body: params }
    end

    def get_submission(course_id, assignment_id, user_id)
      authenticated_get "/api/v1/courses/#{course_id}/assignments/#{assignment_id}/submissions/#{user_id}"
    end

    def course_account_id(course_id)
      course = get_course(course_id)
      course['account_id'] if course
    end

    def root_account_id(account_id)
      if account_id && account = get_account(account_id)
        root_id = account['root_account_id']
      end

      root_id || account_id
    end

    def course_root_account_id(course_id)
      root_account_id(course_account_id(course_id))
    end

    def auth_url(redirect_uri, oauth2_state)
      "#{canvas_url}/login/oauth2/auth?client_id=#{key}&response_type=code&state=#{oauth2_state}&redirect_uri=#{redirect_uri}"
    end

    def get_access_token(code)
      token_details = []
      params = {
        body: {
          client_id: key,
          client_secret: secret,
          code: code
        }
      }

      response = self.class.post '/login/oauth2/token', params
      access_token = response['access_token']
      refresh_token = response['refresh_token']
      token_details << [access_token, refresh_token]
    end

    def hex_sis_id(name, value)
      hex = value.unpack("H*")[0]
      return "hex:#{name}:#{hex}"
    end

    def canvas_url=(value)
      @canvas_url = value
      self.class.base_uri(value)
    end
  end

  class CanvasApi::Unauthorized < StandardError ; end
  class CanvasApi::Authenticate < StandardError ; end
end
