describe Rosters::Common do

  let(:teacher_login_id) { rand(99999).to_s }
  let(:course_id) { rand(99999) }
  let(:section_id_one) { rand(99999).to_s }
  let(:section_id_two) { rand(99999).to_s }
  let(:section_id_three) { rand(99999).to_s }
  subject { Rosters::Common.new(teacher_login_id, course_id: course_id) }

  describe '#index_by_attribute' do
    it 'returns hash of arrays indexed by item attributes' do
      sections = [
        {:ccn => 123, :name => 'Course with CCN 123'},
        {:ccn => 124, :name => 'Course with CCN 124'},
        {:ccn => 125, :name => 'Course with CCN 125'},
      ]
      result = subject.index_by_attribute(sections, :ccn)
      expect(result).to be_an_instance_of Hash
      expect(result.keys).to eq [123, 124, 125]
      expect(result[123]).to eq sections[0]
      expect(result[124]).to eq sections[1]
      expect(result[125]).to eq sections[2]
    end
  end

  describe '#sections_to_name_string' do
    it 'returns section names in string format' do
      sections = [
        {:ccn => 123, :name => 'Course with CCN 123'},
        {:ccn => 124, :name => 'Course with CCN 124'},
      ]
      result = subject.sections_to_name_string([sections[0]])
      expect(result).to eq "Course with CCN 123"
      result = subject.sections_to_name_string([sections[1]])
      expect(result).to eq "Course with CCN 124"
      result = subject.sections_to_name_string(sections)
      expect(result).to eq "Course with CCN 123, Course with CCN 124"
    end
  end

  describe '#get_enrollments' do
    context 'when term is campus solutions' do
      let(:cs_enrollments) {
        [
          {
            'section_id' => section_id_one,
            'ldap_uid' => '333333',
            'student_id' => '22200666',
            'enroll_status' => 'E',
            'waitlist_position' => nil,
            'units' => 4,
            'grading_basis' => 'GRD',
            'major' => 'Cognitive Science BA',
            'academic_career' => 'UGRD',
            'terms_in_attendance_group' => 'R2TA',
            'statusinplan_status_code' => 'AC'
          },
          {
            'section_id' => section_id_one,
            'ldap_uid' => '333333',
            'student_id' => '22200666',
            'enroll_status' => 'E',
            'waitlist_position' => nil,
            'units' => 4,
            'grading_basis' => 'GRD',
            'major' => 'Computer Science BA',
            'academic_career' => 'UGRD',
            'terms_in_attendance_group' => 'R2TA',
            'statusinplan_status_code' => 'AC'
          },
          {
            'section_id' => section_id_one,
            'ldap_uid' => '333333',
            'student_id' => '22200666',
            'enroll_status' => 'E',
            'waitlist_position' => nil,
            'units' => 4,
            'grading_basis' => 'GRD',
            'major' => 'Summer Domestic Visitor UG',
            'academic_career' => 'UGRD',
            'terms_in_attendance_group' => 'R2TA',
            'statusinplan_status_code' => 'DC'
          },
          {
            'section_id' => section_id_one,
            'ldap_uid' => '444444',
            'student_id' => '22200555',
            'enroll_status' => 'E',
            'waitlist_position' => nil,
            'units' => 4,
            'grading_basis' => 'PNP',
            'major' => 'Computer Science BA',
            'academic_career' => 'UGRD',
            'terms_in_attendance_group' => 'R8TA',
            'statusinplan_status_code' => 'AC'
          },
          {
            'section_id' => section_id_one,
            'ldap_uid' => '444444',
            'student_id' => '22200555',
            'enroll_status' => 'E',
            'waitlist_position' => nil,
            'units' => 4,
            'grading_basis' => 'PNP',
            'major' => 'UCBX Fall Pgm for Freshmen',
            'academic_career' => 'UGRD',
            'terms_in_attendance_group' => 'R8TA',
            'statusinplan_status_code' => 'DC'
          },
          {
            'section_id' => section_id_one,
            'ldap_uid' => '555555',
            'student_id' => '22200444',
            'enroll_status' => 'W',
            'waitlist_position' => '25',
            'units' => 4,
            'grading_basis' => 'GRD',
            'major' => 'Law JD',
            'academic_career' => 'LAW',
            'terms_in_attendance_group' => nil,
            'statusinplan_status_code' => 'AC'
          },
          {
            'section_id' => section_id_two,
            'ldap_uid' => '555555',
            'student_id' => '22200444',
            'enroll_status' => 'W',
            'waitlist_position' => '25',
            'units' => 4,
            'grading_basis' => 'GRD',
            'major' => 'Chemistry PhD',
            'academic_career' => 'GRAD',
            'terms_in_attendance_group' => nil,
            'statusinplan_status_code' => 'AC'
          },
          {
            'section_id' => section_id_two,
            'ldap_uid' => '666666',
            'student_id' => '22200333',
            'enroll_status' => 'E',
            'units' => 4,
            'grading_basis' => 'GRD',
            'major' => 'UCBX Concurrent Enrollment',
            'academic_career' => 'UCBX',
            'terms_in_attendance_group' => nil,
            'statusinplan_status_code' => 'AC'
          },
          {
            'section_id' => section_id_two,
            'ldap_uid' => '777777',
            'student_id' => '22200222',
            'enroll_status' => 'E',
            'units' => 4,
            'grading_basis' => 'GRD',
            'major' => 'Pizza Science BA',
            'academic_career' => 'ABCD',
            'terms_in_attendance_group' => nil,
            'statusinplan_status_code' => 'AC'
          }
        ]
      }
      let(:user_attributes_one) {
        [
          {:ldap_uid => '333333', :email_address => 'pambeesly@berkeley.edu'},
          {:ldap_uid => '444444', :email_address => 'kellykapoor@berkeley.edu'},
          {:ldap_uid => '555555', :email_address => 'kevinmalone@berkeley.edu'}
        ]
      }
      let(:user_attributes_two) {
        [
          {:ldap_uid => '555555', :email_address => 'kevinmalone@berkeley.edu'},
          {:ldap_uid => '666666', :email_address => 'tobyflenderson@berkeley.edu'},
          {:ldap_uid => '777777', :email_address => 'shudson@berkeley.edu'},
        ]
      }
      let(:enrollments) { subject.get_enrollments([section_id_one, section_id_two], '2016', 'D') }
      before do
        allow(Berkeley::Terms).to receive(:legacy?).and_return(false)
        allow(EdoOracle::Queries).to receive(:get_rosters).and_return(cs_enrollments)
        expect(User::BasicAttributes).to receive(:attributes_for_uids).with(['333333', '444444', '555555']).and_return(user_attributes_one)
        expect(User::BasicAttributes).to receive(:attributes_for_uids).with(['555555', '666666', '777777']).and_return(user_attributes_two)
      end
      it 'returns student basic attributes and enrollment status grouped by section id, redundancy permitted' do
        expect(enrollments[section_id_one][0][:email]).to eq 'pambeesly@berkeley.edu'
        expect(enrollments[section_id_one][0][:enroll_status]).to eq 'E'
        expect(enrollments[section_id_one][0][:student_id]).to eq '22200666'
        expect(enrollments[section_id_one][0][:units]).to eq '4'
        expect(enrollments[section_id_one][0][:academic_career]).to eq 'UGRD'

        expect(enrollments[section_id_one][1][:email]).to eq 'kellykapoor@berkeley.edu'
        expect(enrollments[section_id_one][1][:enroll_status]).to eq 'E'
        expect(enrollments[section_id_one][1][:student_id]).to eq '22200555'
        expect(enrollments[section_id_one][1][:units]).to eq '4'
        expect(enrollments[section_id_one][1][:academic_career]).to eq 'UGRD'

        expect(enrollments[section_id_one][2][:email]).to eq 'kevinmalone@berkeley.edu'
        expect(enrollments[section_id_one][2][:enroll_status]).to eq 'W'
        expect(enrollments[section_id_one][2][:student_id]).to eq '22200444'
        expect(enrollments[section_id_one][2][:units]).to eq '4'
        expect(enrollments[section_id_one][2][:academic_career]).to eq 'LAW'

        expect(enrollments[section_id_two][0][:email]).to eq 'kevinmalone@berkeley.edu'
        expect(enrollments[section_id_two][0][:enroll_status]).to eq 'W'
        expect(enrollments[section_id_two][0][:student_id]).to eq '22200444'
        expect(enrollments[section_id_two][0][:units]).to eq '4'
        expect(enrollments[section_id_two][0][:academic_career]).to eq 'GRAD'
      end

      it 'converts grade option to string version' do
        expect(enrollments[section_id_one][0][:grade_option]).to eq 'Letter'
        expect(enrollments[section_id_one][1][:grade_option]).to eq 'P/NP'
        expect(enrollments[section_id_one][2][:grade_option]).to eq 'Letter'
      end

      it 'converts waitlist position to integer when present' do
        expect(enrollments[section_id_one][0][:waitlist_position]).to eq nil
        expect(enrollments[section_id_one][1][:waitlist_position]).to eq nil
        expect(enrollments[section_id_one][2][:waitlist_position]).to eq 25
      end

      it 'merges majors into single enrollment for student' do
        expect(enrollments[section_id_one][0][:majors]).to eq ['Cognitive Science BA', 'Computer Science BA']
        expect(enrollments[section_id_one][1][:majors]).to eq ['Computer Science BA']
        expect(enrollments[section_id_one][2][:majors]).to eq ['Law JD']
        expect(enrollments[section_id_two][0][:majors]).to eq ['Chemistry PhD']
        expect(enrollments[section_id_two][1][:majors]).to eq ['UCBX Concurrent Enrollment']
        expect(enrollments[section_id_two][2][:majors]).to eq ['Pizza Science BA']
      end

      it 'converts and includes terms in attendance code' do
        expect(enrollments[section_id_one][0][:terms_in_attendance]).to eq '2'
        expect(enrollments[section_id_one][1][:terms_in_attendance]).to eq '8'
        expect(enrollments[section_id_one][2][:terms_in_attendance]).to eq 'G'
        expect(enrollments[section_id_two][0][:terms_in_attendance]).to eq 'G'
        expect(enrollments[section_id_two][1][:terms_in_attendance]).to eq "\u2014"
        expect(enrollments[section_id_two][2][:terms_in_attendance]).to eq nil
      end

      context 'duplicate results from EDO DB' do
        before { cs_enrollments << cs_enrollments.last }
        it 'should de-duplicate majors' do
          expect(enrollments[section_id_two].last[:majors]).to have(1).item
        end
      end
    end
  end

end
