namespace :data_loch do

  def s3_targets
    targets = ENV['TARGETS']
    if targets.blank?
      Rails.logger.warn 'Should specify TARGETS as names of S3 configurations. Separate multiple target names with commas.'
      targets = nil
    else
      targets = targets.split(',')
    end
    return targets
  end

  desc 'Upload student-advisor and instructor-advisor relationship mappings to data loch S3'
  task :advisors => :environment do
    DataLoch::Stocker.new().upload_advisor_relationships(s3_targets)
  end

  desc 'Upload course, enrollment, and advisee data snapshots to data loch S3 (TERM_ID = 2XXX,2XXX...)'
  task :snapshot => :environment do
    term_ids = ENV['TERM_ID']
    advisee_data = []
    advisee_data.concat ['demographics'] if ENV['DEMOGRAPHICS']
    advisee_data.concat ['edw_demographics'] if ENV['EDW_DEMOGRAPHICS']
    advisee_data.concat ['socio_econ', 'applicant_scores'] if ENV['APPLICANT']
    if term_ids.blank? && advisee_data.blank?
      Rails.logger.error 'Neither TERM_ID, DEMOGRAPHICS, nor APPLICANT is specified. Nothing to upload.'
    end
    if term_ids.present?
      term_ids = term_ids.split(',')
    end
    targets = s3_targets
    is_historical = ENV['HISTORICAL']
    stocker = DataLoch::Stocker.new()
    if term_ids.present?
      stocker.upload_term_data(term_ids, targets, is_historical)
    end
    if advisee_data.present?
      stocker.upload_advisee_data(targets, advisee_data)
    end
  end

  desc 'Upload College of Letters & Science student info to data loch S3'
  task :l_and_s => :environment do
    DataLoch::Stocker.new().upload_l_and_s_students(s3_targets)
  end

  desc 'Upload list of undergraduate students to data loch S3'
  task :undergrads => :environment do
    DataLoch::Stocker.new().upload_undergrads(s3_targets)
  end

  desc 'Upload advising notes, topics, and attachment data to data loch S3'
  task :notes => :environment do
    DataLoch::Stocker.new().upload_advising_notes_data(s3_targets, ['notes', 'note-attachments'])
  end

  desc 'Check access to Data Loch S3'
  task :verify => :environment do
    DataLoch::Stocker.new().verify_endpoints(s3_targets)
  end

end
