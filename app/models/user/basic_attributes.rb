module User
  module BasicAttributes
    extend self

    # Does not include Expired or Alumni populations in search results.
    def attributes_for_uids(uids)
      return [] if uids.blank?
      uid_set = uids.to_set
      attrs = []
      # Oracle dislikes ' IN ()' queries with more than 1000 items.
      uids.each_slice(1000) do |next_batch|
        rows = EdoOracle::Queries.get_basic_people_attributes(next_batch)
        rows.each do |result|
          uid_set.delete result['ldap_uid']
          unless result['person_type'] == 'Z'
            parsed_row = transform_campus_row(result)
            # CLC-7157 was triggered when an active student and an active employee were incorrectly
            # flagged by person_type='A'. Guard against that error.
            if (result['person_type'] != 'A') || parsed_row[:roles].slice(:student, :staff, :faculty, :guest).values.any?
              attrs << parsed_row
            end
          end
        end
      end
      attrs.concat CalnetLdap::UserAttributes.get_bulk_attributes(uid_set) if uid_set.any?
      attrs
    end

    def transform_campus_row(result)
      {
        email_address: result['email_address'],
        first_name: result['first_name'],
        last_name: result['last_name'],
        ldap_uid: result['ldap_uid'],
        roles: Berkeley::UserRoles.roles_from_campus_row(result),
        student_id: result['student_id'],
        official_bmail_address: result['alternateid']
      }
    end
  end
end
