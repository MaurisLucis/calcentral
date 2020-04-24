module CanvasCsv
  require 'csv'

  class Base < CsvExport
    include ClassLogger

    def initialize
      super(Settings.canvas_proxy.export_directory)
      @reporter_uid = Settings.canvas_proxy.reporter_uid
    end

    def accumulate_user_data(user_ids)
      users = []
      user_ids.each_slice(1000) do |uid_slice|
        campus_attributes = User::BasicAttributes.attributes_for_uids uid_slice
        users.concat campus_attributes.map { |attrs| canvas_user_from_campus_attributes attrs }
      end
      users
    end

    def canvas_user_from_campus_attributes(campus_user)
      {
        'user_id' => derive_sis_user_id(campus_user),
        'login_id' => campus_user[:ldap_uid].to_s,
        'password' => nil,
        'first_name' => campus_user[:first_name],
        'last_name' => campus_user[:last_name],
        'email' => campus_user[:email_address],
        'status' => 'active'
      }
    end

    def derive_sis_user_id(campus_user)
      return nil unless campus_user
      if Settings.canvas_proxy.mixed_sis_user_id
        if campus_user[:student_id].present? &&
          (campus_user[:roles][:student] || campus_user[:roles][:concurrentEnrollmentStudent]) &&
          !campus_user[:roles][:expiredAccount]
          campus_user[:student_id].to_s
        else
          "UID:#{campus_user[:ldap_uid]}"
        end
      else
        campus_user[:ldap_uid].to_s
      end
    end

    def make_csv(filename, headers, rows)
      csv = CSV.open(
        filename, 'wb:UTF-8',
        {
          headers: headers,
          write_headers: true
        }
      )
      safe_encode = ->(v) { v.to_s.encode(Encoding::UTF_8, {invalid: :replace, undef: :replace, replace: ''}) }
      if rows
        rows.each do |row|
          if row.respond_to? :transform_values
            csv << row.transform_values(&safe_encode)
          elsif row.is_a? Array
            csv << row.map(&safe_encode)
          else
            csv << row
          end
        end
        csv.close
        filename
      else
        csv
      end
    end

    def file_safe(string)
      # Prevent collisions with the filesystem.
      string.gsub(/[^a-z0-9\-.]+/i, '_')
    end

    def make_accounts_csv(filename, rows = nil)
      make_csv(filename, 'account_id,parent_account_id,name,status', rows)
    end

    def make_courses_csv(filename, rows = nil)
      make_csv(filename, 'course_id,short_name,long_name,account_id,term_id,status,start_date,end_date', rows)
    end

    def make_enrollments_csv(filename, rows = nil)
      make_csv(filename, 'course_id,user_id,role,section_id,status,associated_user_id', rows)
    end

    def make_sections_csv(filename, rows = nil)
      make_csv(filename, 'section_id,course_id,name,status,start_date,end_date', rows)
    end

    def make_sis_ids_csv(filename, rows = nil)
      make_csv(filename, 'old_id,new_id,old_integration_id,new_integration_id,type', rows)
    end

    def make_users_csv(filename, rows = nil)
      make_csv(filename, 'user_id,login_id,first_name,last_name,email,status', rows)
    end

    def csv_count(csv_filename)
      CSV.read(csv_filename, {headers: true}).length
    end

    def sheets_manager
      @sheets_manager ||=  @reporter_uid.present? ? GoogleApps::SheetsManager.new(GoogleApps::Proxy::APP_ID, @reporter_uid) : nil
    end

    def reports_folder
      @reports_folder ||= sheets_manager.present? ?
        sheets_manager.find_folders_by_title('bCourses Reports').first || sheets_manager.find_folders_by_title('bCourses Reports', shared: true).first :
        nil
    end

    def timestamp_from_filepath(filepath)
      filepath.gsub(@export_dir, '').gsub(/\D/, '')
    end

  end
end
