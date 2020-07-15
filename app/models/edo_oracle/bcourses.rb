module EdoOracle
  class Bcourses < Connection
    include ActiveRecordHelper

    def self.get_enrolled_students(section_id, term_id)
      fallible_query <<-SQL
        SELECT DISTINCT
          enroll.CAMPUS_UID AS ldap_uid,
          enroll.STUDENT_ID AS student_id,
          enroll.STDNT_ENRL_STATUS_CODE AS enroll_status,
          enroll.WAITLISTPOSITION AS waitlist_position,
          enroll.UNITS_TAKEN AS units,
          TRIM(enroll.GRADING_BASIS_CODE) AS grading_basis
        FROM SISEDO.ETS_ENROLLMENTV01_VW enroll
        WHERE enroll.CLASS_SECTION_ID = '#{section_id}'
          AND enroll.TERM_ID = '#{term_id}'
          AND #{EdoOracle::Queries.omit_drops_and_withdrawals}
          ORDER BY enroll.CAMPUS_UID
      SQL
    end

    def self.get_section_instructors(term_id, section_id)
      fallible_query <<-SQL
        SELECT DISTINCT
          TRIM(instr."formattedName") AS person_name,
          TRIM(instr."givenName") AS first_name,
          TRIM(instr."familyName") AS last_name,
          instr."campus-uid" AS ldap_uid,
          instr."role-code" AS role_code,
          instr."role-descr" AS role_description,
          instr."gradeRosterAccess" AS grade_roster_access,
          instr."printInScheduleOfClasses" AS print_in_schedule
        FROM
          SISEDO.ASSIGNEDINSTRUCTORV00_VW instr
        JOIN SISEDO.CLASSSECTIONALLV01_MVW sec ON (
          instr."cs-course-id" = sec."cs-course-id" AND
          instr."term-id" = sec."term-id" AND
          instr."session-id" = sec."session-id" AND
          instr."offeringNumber" = sec."offeringNumber" AND
          instr."number" = sec."sectionNumber"
        )
        WHERE
          sec."id" = '#{section_id.to_s}' AND
          sec."term-id" = '#{term_id.to_s}' AND
          TRIM(instr."instructor-id") IS NOT NULL
        ORDER BY
          role_code
      SQL
    end

    def self.get_all_active_people_uids
      rows = safe_query <<-SQL
        select pi.ldap_uid
        from sisedo.calcentral_person_info_vw pi
        where (affiliations like '%-TYPE-%') and person_type not in ('A', 'Z')
      SQL
      rows.collect {|uid| uid['ldap_uid'] }
    end

    def self.find_people_by_name(name_search_string, limit = 0)
      raise ArgumentError, "Search text argument must be a string" if name_search_string.class != String
      raise ArgumentError, "Limit argument must be a Fixnum" if limit.class != Fixnum
      limit_clause = (limit > 0) ? "where rownum <= #{limit}" : ""
      search_text_array = name_search_string.split(',')
      search_text_array.collect! { |e| e.strip }
      clean_search_string = connection.quote_string(search_text_array.join(','))
      safe_query <<-SQL
        select outr.*
        from (
          select  pi.ldap_uid,
                  trim(pi.first_name) as first_name,
                  trim(pi.last_name) as last_name,
                  pi.email_address,
                  pi.student_id,
                  pi.affiliations,
                  pi.person_type,
                  row_number() over(order by 1) row_number,
                  count(*) over() result_count
          from sisedo.calcentral_person_info_vw pi
          where lower( concat(concat(trim(pi.last_name), ','), trim(pi.first_name)) ) like '#{clean_search_string.downcase}%'
            and (affiliations like '%-TYPE-%') and person_type not in ('A', 'Z')
          order by trim(pi.last_name)
        ) outr #{limit_clause}
      SQL
    end

    def self.find_people_by_email(email_search_string, limit = 0)
      raise ArgumentError, "Search text argument must be a string" if email_search_string.class != String
      raise ArgumentError, "Limit argument must be a Fixnum" if limit.class != Fixnum
      limit_clause = (limit > 0) ? "where rownum <= #{limit}" : ""
      clean_search_string = connection.quote_string(email_search_string)
      safe_query <<-SQL
        select outr.*
        from (
          select  pi.ldap_uid,
                  trim(pi.first_name) as first_name,
                  trim(pi.last_name) as last_name,
                  pi.email_address,
                  pi.student_id,
                  pi.affiliations,
                  pi.person_type,
                  row_number() over(order by 1) row_number,
                  count(*) over() result_count
          from sisedo.calcentral_person_info_vw pi
          where lower(pi.email_address) like '%#{clean_search_string.downcase}%'
            and (affiliations like '%-TYPE-%') and person_type not in ('A', 'Z')
          order by trim(pi.last_name)
        ) outr #{limit_clause}
      SQL
    end

    def self.find_active_uid(user_id_string)
      raise ArgumentError, "Argument must be a string" if user_id_string.class != String
      raise ArgumentError, "Argument is not an integer string" unless user_id_string.to_i.to_s == user_id_string
      safe_query <<-SQL
      select pi.ldap_uid, trim(pi.first_name) as first_name, trim(pi.last_name) as last_name, pi.email_address, pi.student_id, pi.affiliations,
        pi.person_type, 1.0 row_number, 1.0 result_count
      from sisedo.calcentral_person_info_vw pi
      where pi.ldap_uid = #{user_id_string}
        and (affiliations like '%-TYPE-%') and person_type not in ('A', 'Z')
      and rownum <= 1
      SQL
    end

    def self.get_recent_instructor_updates(since_timestamp, term_ids)
      term_ids_in = term_ids.map {|term_id| "'#{term_id}'"}.join ','
      timestamp_in = since_timestamp.strftime('%Y-%m-%d %H:%M:%S')
      sql = <<-SQL
        SELECT DISTINCT
        up.instr_id AS sis_id,
        up.term_id,
        up.class_section_id AS section_id,
        up.crse_id AS course_id,
        instr."campus-uid" AS ldap_uid,
        instr."role-code" AS role_code,
        sec."primary",
        up.last_updated
        FROM SISEDO.CLASS_INSTR_UPDATESV00_VW up
        JOIN SISEDO.ASSIGNEDINSTRUCTORV00_VW instr ON (
          instr."cs-course-id" = up.crse_id AND
          instr."term-id" = up.term_id AND
          instr."session-id" = up.session_code AND
          instr."offeringNumber" = up.crse_offer_nbr AND
          instr."number" = up.class_section
        )
        JOIN SISEDO.CLASSSECTIONALLV01_MVW sec ON (
          sec."id" = up.class_section_id AND sec."term-id" = up.term_id
        )
        WHERE up.change_type IN ('C', 'U') AND up.term_id  IN (#{term_ids_in}) AND
        up.last_updated >= to_timestamp('#{timestamp_in}', 'yyyy-mm-dd hh24:mi:ss')
        ORDER BY up.term_id, up.crse_id, up.class_section_id, instr."campus-uid", up.last_updated DESC
      SQL
      fallible_query(sql, do_not_stringify: true)
    end

    def self.get_recent_enrollment_updates(since_timestamp, term_ids)
      term_ids_in = term_ids.map {|term_id| "'#{term_id}'"}.join ','
      timestamp_in = since_timestamp.strftime('%Y-%m-%d %H:%M:%S')
      sql = <<-SQL
        SELECT DISTINCT
          enroll.CLASS_SECTION_ID as section_id,
          enroll.TERM_ID as term_id,
          enroll.CAMPUS_UID AS ldap_uid,
          enroll.STUDENT_ID AS sis_id,
          enroll.STDNT_ENRL_STATUS_CODE AS enroll_status,
          enroll.COURSE_CAREER AS course_career,
          enroll.LAST_UPDATED as last_updated
        FROM SISEDO.ETS_ENROLLMENTV01_VW enroll
        WHERE enroll.TERM_ID IN (#{term_ids_in})
        AND #{EdoOracle::Queries.omit_drops_and_withdrawals}
        AND enroll.last_updated >= to_timestamp('#{timestamp_in}', 'yyyy-mm-dd hh24:mi:ss')
        ORDER BY enroll.TERM_ID,
          -- In case the number of results exceeds our processing cutoff, set priority within terms by the academic
          -- career type for the course.
          CASE
            WHEN enroll.course_career = 'UGRD' THEN 1
            WHEN enroll.course_career = 'GRAD' THEN 2
            WHEN enroll.course_career = 'LAW' THEN 3
            WHEN enroll.course_career = 'UCBX' THEN 4
            ELSE 5
          END,
          enroll.CLASS_SECTION_ID, enroll.CAMPUS_UID, enroll.last_updated DESC
      SQL
      fallible_query(sql, do_not_stringify: true)
    end
  end
end
