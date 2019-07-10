module DataLoch
  class Zipper

    BATCH_SIZE = 120000
    STAGING_DIRECTORY = Pathname.new Settings.data_loch.staging_directory

    def self.zip_query(base_path, format='CSV')
      path = staging_path "#{base_path}.gz"
      Zlib::GzipWriter.open(path) do |gz|
        rows = yield
        zip_query_results(rows, gz, format)
      end
      path
    end

    def self.zip_query_sliced_matches(base_path, match_vals, format='CSV', slice_size=1000)
      # Handle WHERE...IN queries which need to be split for acceptable DB response times.
      path = staging_path "#{base_path}.gz"
      match_slices = match_vals.each_slice(slice_size).to_a
      Zlib::GzipWriter.open(path) do |gz|
        match_slices.each do |slice|
          result = yield(slice)
          zip_query_results(result, gz, format)
        end
      end
      path
    end

    def self.zip_query_with_batched_results(base_path, format='CSV')
      # Handle queries whose results would overload memory if transferred in one batch.
      path = staging_path "#{base_path}.gz"
      batch = 0
      Zlib::GzipWriter.open(path) do |gz|
        loop do
          result = yield(batch, BATCH_SIZE)
          zip_query_results(result, gz, format)
          # If we receive fewer rows than the batch size, we've read all available rows and are done.
          if result.rows.count < BATCH_SIZE
            Rails.logger.warn "On batch #{batch}, received only #{result.rows.count} rows"
            break
          end
          batch += 1
        end
      end
      path
    end

    def self.zip_query_results(results, gz, format)
      raise StandardError, 'DB query failed' unless results.respond_to?(:rows)
      columns = results.columns.map &:downcase
      intified_idxs = intified_cols.map {|name| columns.index name}.compact
      results.rows.each do |r|
        intified_idxs.each do |idx|
          raw = r[idx]
          next if raw.nil? || raw.is_a?(String)
          r[idx] = raw.to_i
        end
        gz.write r.to_csv if format == 'CSV'
      end
      gz.write results.to_json if format == 'JSON'
    end

    # Cast BigDecimals and suchlike to integers.
    def self.intified_cols
      %w(sid section_id ldap_uid parent_income test_score_nbr applied_school_yr saa_seq_nbr instructor_advisor_nbr display_only acadplan_ownedby_pct)
    end

    def self.staging_path(basename)
      FileUtils.mkdir_p STAGING_DIRECTORY unless File.exists? STAGING_DIRECTORY
      STAGING_DIRECTORY.join(basename).to_s
    end

  end
end
