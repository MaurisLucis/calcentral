module EdoOracle
  class Bulk < Connection
    include ActiveRecordHelper

    ADVISING_NOTE_CUTOFF = '2018-10-31 12:58:32'

    # See http://www.oracle.com/technetwork/issue-archive/2006/06-sep/o56asktom-086197.html for explanation of
    # query batching with ROWNUM.
    def self.get_batch_enrollments(term_id, batch_number, batch_size)
      mininum_row_exclusive = (batch_number * batch_size)
      maximum_row_inclusive = mininum_row_exclusive + batch_size
      sql = <<-SQL
        SELECT section_id, term_id, ldap_uid, sis_id, enrollment_status, waitlist_position, units,
               grade, grade_points, grading_basis, grade_midterm FROM (
          SELECT /*+ FIRST_ROWS(n) */ enrollments.*, ROWNUM rnum FROM (
            SELECT DISTINCT
              enroll."CLASS_SECTION_ID" as section_id,
              enroll."TERM_ID" as term_id,
              enroll."CAMPUS_UID" AS ldap_uid,
              enroll."STUDENT_ID" AS sis_id,
              enroll."STDNT_ENRL_STATUS_CODE" AS enrollment_status,
              enroll."WAITLISTPOSITION" AS waitlist_position,
              enroll."UNITS_TAKEN" AS units,
              enroll."GRADE_MARK" AS grade,
              enroll."GRADE_POINTS" AS grade_points,
              enroll."GRADING_BASIS_CODE" AS grading_basis,
              enroll."GRADE_MARK_MID" as grade_midterm
            FROM SISEDO.ETS_ENROLLMENTV00_VW enroll
            WHERE
              enroll."TERM_ID" = '#{term_id}'
            ORDER BY section_id, sis_id
          ) enrollments
          WHERE ROWNUM <= #{maximum_row_inclusive}
        )
        WHERE rnum > #{mininum_row_exclusive}
      SQL
      # Result sets are too large for bulk stringification.
      safe_query(sql, do_not_stringify: true)
    end

    def self.get_courses(term_id)
      sql = <<-SQL
        SELECT DISTINCT
          sec."id" AS section_id,
          sec."term-id" AS term_id,
          sec."printInScheduleOfClasses" AS print_in_schedule_of_classes,
          sec."primary" AS primary,
          sec."component-code" AS instruction_format,
          sec."sectionNumber" AS section_num,
          crs."displayName" AS course_display_name,
          sec."enrolledCount" AS enrollment_count,
          instr."campus-uid" AS instructor_uid,
          TRIM(instr."formattedName") AS instructor_name,
          instr."role-code" AS instructor_role_code,
          mtg."location-descr" AS location,
          mtg."meetsDays" AS meeting_days,
          mtg."startTime" AS meeting_start_time,
          mtg."endTime" AS meeting_end_time,
          mtg."startDate" AS meeting_start_date,
          mtg."endDate" AS meeting_end_date,
          TRIM(crs."title") AS course_title,
          cls."allowedUnitsMaximum" AS allowed_units
        FROM
          SISEDO.CLASSSECTIONALLV01_MVW sec
        JOIN SISEDO.EXTENDED_TERM_MVW term1 ON (
          term1.STRM = sec."term-id" AND
          term1.ACAD_CAREER = 'UGRD')
        LEFT OUTER JOIN SISEDO.DISPLAYNAMEXLATV01_MVW xlat ON (xlat."classDisplayName" = sec."displayName")
        LEFT OUTER JOIN SISEDO.API_COURSEV01_MVW crs ON (xlat."courseDisplayName" = crs."displayName")
        LEFT OUTER JOIN SISEDO.CLASSV00_VW cls ON (
          cls."term-id" = sec."term-id" AND
          cls."sectionId" = sec."id")
        LEFT OUTER JOIN SISEDO.MEETINGV00_VW mtg ON (
          mtg."cs-course-id" = sec."cs-course-id" AND
          mtg."term-id" = sec."term-id" AND
          mtg."session-id" = sec."session-id" AND
          mtg."offeringNumber" = sec."offeringNumber" AND
          mtg."sectionNumber" = sec."sectionNumber")
        LEFT OUTER JOIN SISEDO.ASSIGNEDINSTRUCTORV00_VW instr ON (
          instr."cs-course-id" = sec."cs-course-id" AND
          instr."term-id" = sec."term-id" AND
          instr."session-id" = sec."session-id" AND
          instr."offeringNumber" = sec."offeringNumber" AND
          instr."number" = sec."sectionNumber")
        WHERE
          sec."term-id" = '#{term_id}'
          AND sec."status-code" IN ('A','S')
          AND CAST(crs."fromDate" AS DATE) <= term1.TERM_END_DT
          AND CAST(crs."toDate" AS DATE) >= term1.TERM_END_DT
          AND crs."updatedDate" = (
            SELECT MAX(crs2."updatedDate")
            FROM SISEDO.API_COURSEV01_MVW crs2, SISEDO.EXTENDED_TERM_MVW term2
            WHERE crs2."cms-version-independent-id" = crs."cms-version-independent-id"
            AND crs2."displayName" = crs."displayName"
            AND term2.ACAD_CAREER = 'UGRD'
            AND term2.STRM = sec."term-id"
            AND (
              (
                CAST(crs2."fromDate" AS DATE) <= term2.TERM_END_DT AND
                CAST(crs2."toDate" AS DATE) >= term2.TERM_END_DT
              )
              OR CAST(crs2."updatedDate" AS DATE) = TO_DATE('1901-01-01', 'YYYY-MM-DD')
            )
          )
      SQL
      # Result sets are too large for bulk stringification.
      safe_query(sql, do_not_stringify: true)
    end

    def self.get_l_and_s_students
      sql = <<-SQL
        SELECT DISTINCT
          pl.STUDENT_ID as sid, 
          pl.ACADPLAN_CODE, pl.ACADPLAN_DESCR, pl.ACADPLAN_TYPE_CODE, pl.ACADPLAN_OWNEDBY_CODE,
          pi.LDAP_UID, pi.FIRST_NAME, pi.LAST_NAME, pi.EMAIL_ADDRESS, pi.AFFILIATIONS
        FROM SISEDO.student_planv01_vw pl
        JOIN SISEDO.calcentral_person_info_vw pi ON
          pi.STUDENT_ID=pl.STUDENT_ID AND
          pi.PERSON_TYPE != 'Z'
        WHERE pl.acadprog_code='UCLS' AND pl.statusinplan_status_code='AC'
        ORDER BY pl.STUDENT_ID
      SQL
      safe_query(sql, do_not_stringify: true)
    end

    def self.get_active_undergrads
      sql = <<-SQL
        SELECT DISTINCT
          pl.STUDENT_ID as sid, 
          pl.ACADPROG_CODE, pl.ACADPROG_DESCR,
          pl.ACADPLAN_CODE, pl.ACADPLAN_DESCR, pl.ACADPLAN_TYPE_CODE, pl.ACADPLAN_OWNEDBY_CODE
        FROM SISEDO.student_planv01_vw pl
        WHERE pl.ACADCAREER_CODE='UGRD' AND pl.STATUSINPLAN_STATUS_CODE='AC'
        ORDER BY pl.STUDENT_ID, pl.ACADPROG_CODE, pl.ACADPLAN_CODE
      SQL
      safe_query(sql, do_not_stringify: true)
    end

    def self.get_demographics(advisee_sids)
      batched_sids = advisee_sids.each_slice(1000).to_a
      full_sql = ''
      batched_sids.each do |sids|
        if full_sql.present?
          full_sql << ' UNION ALL '
        end
        sids_in = sids.map {|sid| "'#{sid}'"}.join ','
        sql = <<-SQL
          SELECT
            p.person_key AS sid,
            p.gender_genderofrecord_descr AS gender_of_record,
            p.gender_genderidentity_descr AS gender_identity,
            p.usa_visa_type_code,
            ethn.ethnicity_group_descr, ethn.ethnicity_detail_descr,
            inter.foreigncountry_descr
          FROM SISEDO.PERSONV00_VW p
          LEFT JOIN SISEDO.PERSON_ETHNICITYV00_VW ethn ON p.person_key = ethn.person_key
          LEFT JOIN SISEDO.PERSON_FOREIGNCOUNTRYV00_VW inter ON p.person_key = inter.person_key
          WHERE p.person_key IN (#{sids_in})
        SQL
        full_sql << sql
      end

      # Result sets are too large for bulk stringification.
      safe_query(full_sql, do_not_stringify: true)
    end

    def self.get_advising_notes()
      sql = <<-SQL
        SELECT 
          EMPLID,
          SAA_NOTE_ID,
          SAA_SEQ_NBR,
          ADVISOR_ID,
          SCI_NOTE_PRIORITY,
          SAA_NOTE_ITM_LONG,
          SCC_ROW_ADD_OPRID,
          SCC_ROW_ADD_DTTM,
          SCC_ROW_UPD_OPRID,
          SCC_ROW_UPD_DTTM,
          SCI_APPT_ID,
          SAA_NOTE_TYPE,
          UC_ADV_TYP_DESC,
          SAA_NOTE_SUBTYPE,
          UC_ADV_SUBTYP_DESC,
          SCI_TOPIC
        FROM SYSADM.BOA_ADVISEE_NOTE00_VW
        WHERE SCC_ROW_UPD_DTTM > TO_TIMESTAMP('#{ADVISING_NOTE_CUTOFF}', 'YYYY-MM-DD HH24:MI:SS')
        ORDER BY EMPLID, SAA_NOTE_ID
      SQL
      safe_query(sql, do_not_stringify: true)
    end

    def self.get_advising_note_attachments()
      sql = <<-SQL
        SELECT DISTINCT
          A.EMPLID,
          A.SAA_NOTE_ID,
          A.USERFILENAME,
          A.ATTACHSYSFILENAME
        FROM SYSADM.BOA_ADVISEE_NOTE00_VW N
        JOIN SYSADM.BOA_ADVISE_USERATTACHFILENAME00_VW A
          ON N.EMPLID = A.EMPLID
        AND N.SAA_NOTE_ID = A.SAA_NOTE_ID
        WHERE N.SCC_ROW_UPD_DTTM > TO_TIMESTAMP('#{ADVISING_NOTE_CUTOFF}', 'YYYY-MM-DD HH24:MI:SS' )
        ORDER BY A.EMPLID, A.SAA_NOTE_ID
      SQL
      safe_query(sql, do_not_stringify: true)
    end

    def self.get_instructor_advisor_relationships()
      sql = <<-SQL
        SELECT DISTINCT
          I.ADVISOR_ID,
          I.CAMPUS_ID,
          I.INSTRUCTOR_ADISOR_NUMBER AS INSTRUCTOR_ADVISOR_NBR,
          I.ADVISOR_TYPE,
          I.ADVISOR_TYPE_DESCR,
          I.INSTRUCTOR_TYPE,
          I.INSTRUCTOR_TYPE_DESCR,
          I.ACADEMIC_PROGRAM,
          I.ACADEMIC_PROGRAM_DESCR,
          I.ACADEMIC_PLAN,
          I.ACADEMIC_PLAN_DESCR,
          I.ACADEMIC_SUB_PLAN,
          I.ACADEMIC_SUB_PLAN_DESCR
        FROM SYSADM.BOA_INSTRUCTOR_ADVISOR_VW I
        WHERE I.INSTITUTION = 'UCB01'
        AND I.ACADEMIC_CAREER = 'UGRD'
        AND I.EFFECTIVE_STATUS = 'A'
        AND I.EFFECTIVE_DATE = (
            SELECT MAX(I1.EFFECTIVE_DATE)
            FROM SYSADM.BOA_INSTRUCTOR_ADVISOR_VW I1
            WHERE I1.ADVISOR_ID = I.ADVISOR_ID
            AND I1.INSTRUCTOR_ADISOR_NUMBER = I.INSTRUCTOR_ADISOR_NUMBER
        )
      SQL
      safe_query(sql, do_not_stringify: true)
    end

    def self.get_student_advisor_relationships()
      sql = <<-SQL
        SELECT DISTINCT
          S.STUDENT_ID,
          S.CAMPUS_ID,
          S.ADVISOR_ID,
          S.ADVISOR_ROLE,
          S.ADVISOR_ROLE_DESCR,
          S.ACADEMIC_PROGRAM,
          S.ACADEMIC_PROGRAM_DESCR,
          S.ACADEMIC_PLAN,
          S.ACADEMIC_PLAN_DESCR
        FROM SYSADM.BOA_STUDENT_ADVISOR_VW S
        WHERE S.INSTITUTION = 'UCB01'
        AND S.ACADEMIC_CAREER = 'UGRD'
      SQL
      safe_query(sql, do_not_stringify: true)
    end

    def self.get_advisor_note_permissions()
      sql = <<-SQL
        SELECT 
          A.USER_ID,
          A.CS_ID,
          A.PERMISSION_LIST,
          A.DISPLAY_ONLY
        FROM SYSADM.BOA_ADV_NOTES_ACCESS_VW A
      SQL
      safe_query(sql, do_not_stringify: true)
    end

    def self.get_academic_plan_owners()
      sql = <<-SQL
        SELECT DISTINCT 
          ACADPLAN_CODE,
          ACADPLAN_DESCR,
          ACADPLAN_TYPE_CODE,
          ACADPLAN_TYPE_DESCR,
          ACADPLAN_OWNEDBY_CODE, 
          ACADPLAN_OWNEDBY_DESCR,
          ACADPLAN_OWNEDBY_PCT,
          ACADPROG_CODE,
          ACADPROG_DESCR
        FROM SISEDO.STUDENT_PLANV01_VW
        WHERE ACADCAREER_CODE = 'UGRD'
      SQL
      safe_query(sql, do_not_stringify: true)
    end
  end
end
