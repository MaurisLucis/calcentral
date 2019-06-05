module DataLoch
  class Stocker
    include ClassLogger

    def s3_from_names(targets)
      s3s = []
      if targets.blank?
        logger.warn 'Should specify names of S3 configurations. Defaulting to deprecated single-target configuration.'
        s3s << DataLoch::S3.new
      else
        targets.each do |target|
          s3s << DataLoch::S3.new(target)
        end
      end
      s3s
    end

    def get_daily_path()
      today = (Settings.terms.fake_now || DateTime.now).in_time_zone.strftime('%Y-%m-%d')
      digest = Digest::MD5.hexdigest today
      "daily/#{digest}-#{today}"
    end

    def upload_l_and_s_students(s3_targets)
      logger.warn "Starting L&S students snapshot, targets #{s3_targets}."
      s3s = s3_from_names s3_targets
      l_and_s_path = DataLoch::Zipper.zip_query "l_and_s_students" do
        EdoOracle::Bulk.get_l_and_s_students
      end
      s3s.each {|s3| s3.upload("l_and_s", l_and_s_path) }
      logger.info "L&S snapshot complete at #{l_and_s_path}."
    end

    def upload_term_data(term_ids, s3_targets, is_historical=false)
      if is_historical
        data_type = 'historical'
        parent_path = 'historical'
      else
        data_type = 'daily'
        parent_path = get_daily_path
      end
      Rails.logger.warn "Starting #{data_type} course and enrollment data snapshot for term ids #{term_ids}, targets #{s3_targets}."
      s3s = s3_from_names s3_targets
      term_ids.each do |term_id|
        logger.info "Starting snapshots for term #{term_id}."
        courses_path = DataLoch::Zipper.zip_query "courses-#{term_id}" do
          EdoOracle::Bulk.get_courses(term_id)
        end
        s3s.each {|s3| s3.upload("#{parent_path}/courses", courses_path) }
        enrollments_path = DataLoch::Zipper.zip_query_batched "enrollments-#{term_id}" do |batch, size|
          EdoOracle::Bulk.get_batch_enrollments(term_id, batch, size)
        end
        s3s.each {|s3| s3.upload("#{parent_path}/enrollments", enrollments_path) }
        clean_tmp_files([courses_path, enrollments_path])
        logger.info "Snapshots complete for term #{term_id}."
      end
    end

    def upload_advisee_data(s3_targets, jobs)
      # It seems safest to fetch the list of advisee SIDs from the same S3 environment which will receive their results,
      # but this could mean executing nearly the same large DB query multiple times in a row.
      # TODO Consider using the same SID list across environments.
      logger.warn "Starting #{jobs} data snapshot for targets #{s3_targets}."
      s3s = s3_from_names s3_targets
      previous_sids = nil
      job_paths = Hash[jobs.zip]
      s3s.each do |s3|
        sids = s3.load_advisee_sids()
        if sids != previous_sids
          jobs.each do |job|
            job_paths[job] = DataLoch::Zipper.zip_query job do
              case job
              when 'demographics'
                EdoOracle::Bulk.get_demographics sids
              when 'socio_econ'
                EdwOracle::Queries.get_socio_econ sids
              when 'applicant_scores'
                EdwOracle::Queries.get_applicant_scores sids
              else
                Rails.logger.error "Got unknown job name #{job}!"
              end
            end
          end
          previous_sids = sids
        end
        job_paths.each do |job, path|
          s3.upload("advisees/#{job}", path) if path
        end
      end
      clean_tmp_files(job_paths.values)
      logger.info "#{jobs} snapshots complete."
    end

    def upload_advising_notes_data(s3_targets, jobs)
      logger.warn "Starting SIS advising #{jobs} snapshot, targets #{s3_targets}."
      job_paths = Hash[jobs.zip]
      s3s = s3_from_names s3_targets
      s3s.each do |s3|
        jobs.each do |job|
          job_paths[job] = DataLoch::Zipper.zip_query(job, 'JSON') do
            case job
            when 'notes'
              EdoOracle::Bulk.get_advising_notes
            when 'note-attachments'
              EdoOracle::Bulk.get_advising_note_attachments
            else
              logger.error "Got unknown job name #{job}!"
            end
          end
        end
        job_paths.each do |job, path|
          s3.upload("sis-sysadm/#{get_daily_path}/advising-notes/#{job}", path) if path
        end
      end
      clean_tmp_files(job_paths.values)
      logger.info "#{jobs} snapshots complete."
    end

    # Let tests intercept the file deletion.
    def clean_tmp_files(paths)
      paths.each {|p| FileUtils.rm p}
    end

    def verify_endpoints(s3_targets)
      test_file = Zipper.staging_path 'ping.tmp'
      File.open(test_file, "w") {}
      s3_targets.each do |target|
        logger.info "Testing S3 advisee list access at #{target}"
        s3 = s3_from_names([target]).first
        s3.load_advisee_sids()
        logger.info "Testing upload access to #{target}"
        s3.upload('tmp', test_file)
      end
      logger.info "Access checked for AWS targets #{s3_targets}"
      clean_tmp_files [test_file]
    end

  end
end
