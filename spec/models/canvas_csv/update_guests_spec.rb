describe CanvasCsv::UpdateGuests do

  let(:canvas_user_rows) do
    [
      {'user_id' => 'UID:11039123', 'login_id' => '11039123', 'password' => nil, 'first_name' => 'John', 'last_name' => 'Smith', 'email' => 'johnsmith@berkeley.edu', 'status' => 'active'},
      {'user_id' => 'UID:11039124', 'login_id' => '11039124', 'password' => nil, 'first_name' => 'Joan', 'last_name' => 'Gupta', 'email' => 'joangupta@berkeley.edu', 'status' => 'active'},
      {'user_id' => 'UID:11039125', 'login_id' => '11039125', 'password' => nil, 'first_name' => 'Mary', 'last_name' => 'Chang', 'email' => 'marychang@berkeley.edu', 'status' => 'active'},
    ]
  end

  describe '#run' do
    let(:last_guest_user_sync_time) { Time.utc(2014, 7, 23, 9, 00, 00).in_time_zone }
    before { allow(CalnetLdap::Client).to receive(:new).and_return double(guests_modified_since: ldap_search_results) }

    context 'when LDAP returns modified guests' do
      let(:ldap_search_results) do
        entries = Net::BER::BerIdentifiedArray.new
        entries << Net::LDAP::Entry._load("dn: uid=11039123,ou=guests,dc=berkeley,dc=edu\nberkeleyeduaffiliations: GUEST-TYPE-COLLABORATOR\ncn: Smith, John\ndisplayname: Smith, John\ngivenname: John\nmail: johnsmith@berkeley.edu\nobjectclass: ucEduPerson\nobjectclass: person\nobjectclass: organizationalPerson\nobjectclass: inetOrgPerson\nobjectclass: berkeleyEduPerson\nobjectclass: top\nobjectclass: eduPerson\nsn: Smith\nuid: 11039123\n")
        entries << Net::LDAP::Entry._load("dn: uid=11039124,ou=guests,dc=berkeley,dc=edu\nberkeleyeduaffiliations: GUEST-TYPE-SPONSORED\ncn: Gupta, Joan\ndisplayname: Gupta, Joan\ngivenname: Joan\nmail: joangupta@berkeley.edu\nobjectclass: ucEduPerson\nobjectclass: person\nobjectclass: organizationalPerson\nobjectclass: inetOrgPerson\nobjectclass: berkeleyEduPerson\nobjectclass: top\nobjectclass: eduPerson\nsn: Gupta\nuid: 11039124\n")
        entries << Net::LDAP::Entry._load("dn: uid=11039125,ou=guests,dc=berkeley,dc=edu\nberkeleyeduaffiliations: GUEST-TYPE-SPONSORED\ncn: Chang, Mary\ndisplayname: Chang, Mary\ngivenname: Mary\nmail: marychang@berkeley.edu\nobjectclass: ucEduPerson\nobjectclass: person\nobjectclass: organizationalPerson\nobjectclass: inetOrgPerson\nobjectclass: berkeleyEduPerson\nobjectclass: top\nobjectclass: eduPerson\nsn: Chang\nuid: 11039125\n")
        entries
      end
      it 'should import them' do
        canvas_sync = double('canvas_synchronization', :last_guest_user_sync => last_guest_user_sync_time)
        expect(CanvasCsv::Synchronization).to receive(:get).twice.and_return(canvas_sync)
        expect(subject).to receive(:import_guests).with(canvas_user_rows)
        expect(canvas_sync).to receive(:update).and_return(true)
        subject.run
      end
    end

    context 'when LDAP returns no modified guests' do
      let(:ldap_search_results) { Net::BER::BerIdentifiedArray.new }
      it 'should not import' do
        canvas_sync = double('canvas_synchronization', :last_guest_user_sync => last_guest_user_sync_time)
        expect(CanvasCsv::Synchronization).to receive(:get).twice.and_return(canvas_sync)
        expect(subject).to_not receive(:import_guests)
        expect(canvas_sync).to receive(:update).and_return(true)
        subject.run
      end
    end

  end

  describe '#prepare_guest_user_csv_rows' do
    it 'should prepare sis csv transformed user array' do
      ldap_guest_array = ['LDAP Guest 1', 'LDAP Guest 2', 'LDAP Guest 3']
      expect(subject).to receive(:sis_csv_user_from_ldap_guest).with(ldap_guest_array[0]).ordered.and_return('CSV User 1')
      expect(subject).to receive(:sis_csv_user_from_ldap_guest).with(ldap_guest_array[1]).ordered.and_return('CSV User 2')
      expect(subject).to receive(:sis_csv_user_from_ldap_guest).with(ldap_guest_array[2]).ordered.and_return('CSV User 3')
      result = subject.prepare_guest_user_csv_rows(ldap_guest_array)
      expect(result).to eq ['CSV User 1', 'CSV User 2', 'CSV User 3']
    end
  end

  describe '#sis_csv_user_from_ldap_guest' do
    let(:ldap_entry) { Net::LDAP::Entry._load("dn: uid=11039123,ou=guests,dc=berkeley,dc=edu\nberkeleyeduaffiliations: GUEST-TYPE-COLLABORATOR\ncn: Smith, John\ndisplayname: Smith, John\ngivenname: John\nmail: johnsmith@berkeley.edu\nobjectclass: ucEduPerson\nobjectclass: person\nobjectclass: organizationalPerson\nobjectclass: inetOrgPerson\nobjectclass: berkeleyEduPerson\nobjectclass: top\nobjectclass: eduPerson\nsn: Smith\nuid: 11039123\n") }
    it 'should convert ldap guest user to sis csv hash' do
      result = subject.sis_csv_user_from_ldap_guest(ldap_entry)
      expect(result).to be_an_instance_of Hash
      expect(result['status']).to eq 'active'
      expect(result['user_id']).to eq 'UID:11039123'
      expect(result['login_id']).to eq '11039123'
      expect(result['password']).to be_nil
      expect(result['first_name']).to eq 'John'
      expect(result['last_name']).to eq 'Smith'
      expect(result['email']).to eq 'johnsmith@berkeley.edu'
    end
  end

  describe '#import_guests' do
    let(:fake_now_datetime) { DateTime.strptime('2014-07-23T09:00:06+07:00', '%Y-%m-%dT%H:%M:%S%z') }
    let(:expected_filename) { 'tmp/canvas/guest_user_provision-2014-07-23-abcd1234gfed4321-users.csv' }

    it 'should perform sis import of prepared guest array' do
      allow(SecureRandom).to receive(:hex).with(8).and_return('abcd1234gfed4321')
      allow(DateTime).to receive(:now).and_return(fake_now_datetime)
      expect(subject).to receive(:make_users_csv).with(expected_filename, canvas_user_rows).and_return(expected_filename)
      expect_any_instance_of(Canvas::SisImport).to receive(:import_users).with(expected_filename).and_return(true)
      subject.import_guests canvas_user_rows
    end
  end

end
