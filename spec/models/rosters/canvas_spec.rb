describe Rosters::Canvas do
  let(:teacher_login_id) { rand(99999).to_s }
  let(:course_id) { rand(99999) }
  let(:catid) {"#{rand(999)}"}

  let(:lecture_section_id) { rand(99999) }
  let(:lecture_section_ccn) { rand(9999).to_s }
  let(:lecture_section_sis_id) { "SEC:2013-C-#{lecture_section_ccn}" }

  let(:discussion_section_id) { rand(99999) }
  let(:discussion_section_ccn) { rand(9999).to_s }
  let(:discussion_section_sis_id) { "SEC:2013-C-#{discussion_section_ccn}" }

  let(:section_identifiers) {[
    {
      'course_id' => course_id,
      'id' => lecture_section_id,
      'name' => 'An Official Lecture Section',
      'sis_section_id' => lecture_section_sis_id,
      :term_yr => '2013',
      :term_cd => 'C',
      :ccn => lecture_section_ccn
    },
    {
      'course_id' => course_id,
      'id' => discussion_section_id,
      'name' => 'An Official Discussion Section',
      'sis_section_id' => discussion_section_sis_id,
      :term_yr => '2013',
      :term_cd => 'C',
      :ccn => discussion_section_ccn
    }
  ]}

  subject { Rosters::Canvas.new(teacher_login_id, course_id: course_id) }

  before do
    allow_any_instance_of(Canvas::Course).to receive(:course).and_return(
      {statusCode: 200,
       body: {
        'account_id'=>rand(9999),
        'course_code'=>"INFO #{catid} - LEC 001",
        'id'=>course_id,
        'name'=>'An Official Course',
        'term'=>{
          'id'=>rand(9999), 'name'=>'Summer 2013', 'sis_term_id'=>'TERM:2013-C'
        },
        'sis_course_id'=>"CRS:INFO-#{catid}-2013-C",
      }
    })
  end

  let(:student_in_discussion_section_login_id) { rand(99999).to_s }
  let(:student_in_discussion_section_student_id) { rand(99999).to_s }

  let(:student_not_in_discussion_section_login_id) { rand(99999).to_s }
  let(:student_not_in_discussion_section_student_id) { rand(99999).to_s }

  before do
    stub_teacher_status(teacher_login_id, course_id)
    allow_any_instance_of(Canvas::CourseSections).to receive(:official_section_identifiers).and_return(section_identifiers)
  end

  shared_examples 'a good and proper roster' do
    it 'should return enrollments for each section' do
      feed = subject.get_feed
      expect(feed[:canvas_course][:id]).to eq course_id
      expect(feed[:canvas_course][:name]).to eq 'An Official Course'
      expect(feed[:sections].length).to eq 2
      expect(feed[:sections][0][:name]).to eq section_identifiers[0]['name']
      expect(feed[:sections][0][:ccn]).to eq section_identifiers[0][:ccn]
      expect(feed[:sections][0][:sis_id]).to eq section_identifiers[0]['sis_section_id']
      expect(feed[:sections][1][:name]).to eq section_identifiers[1]['name']
      expect(feed[:sections][1][:ccn]).to eq section_identifiers[1][:ccn]
      expect(feed[:sections][1][:sis_id]).to eq section_identifiers[1]['sis_section_id']
      expect(feed[:students].length).to eq 2

      student_in_discussion_section = feed[:students].find{|student| student[:student_id] == student_in_discussion_section_student_id}
      expect(student_in_discussion_section).to_not be_nil
      expect(student_in_discussion_section[:id]).to eq student_in_discussion_section_login_id
      expect(student_in_discussion_section[:login_id]).to eq student_in_discussion_section_login_id
      expect(student_in_discussion_section[:first_name]).to_not be_blank
      expect(student_in_discussion_section[:last_name]).to_not be_blank
      expect(student_in_discussion_section[:email]).to_not be_blank
      expect(student_in_discussion_section[:sections].length).to eq 2
      expect(student_in_discussion_section[:sections][0][:ccn]).to eq lecture_section_ccn
      expect(student_in_discussion_section[:sections][0][:name]).to eq 'An Official Lecture Section'
      expect(student_in_discussion_section[:sections][0][:sis_id]).to eq lecture_section_sis_id
      expect(student_in_discussion_section[:sections][1][:ccn]).to eq discussion_section_ccn
      expect(student_in_discussion_section[:sections][1][:name]).to eq 'An Official Discussion Section'
      expect(student_in_discussion_section[:sections][1][:sis_id]).to eq discussion_section_sis_id
      expect(student_in_discussion_section[:section_ccns].length).to eq 2
      expect(student_in_discussion_section[:section_ccns].first).to be_a String

      student_not_in_discussion_section = feed[:students].find{|student| student[:student_id] == student_not_in_discussion_section_student_id}
      expect(student_not_in_discussion_section).to_not be_nil
      expect(student_not_in_discussion_section[:id]).to eq student_not_in_discussion_section_login_id
      expect(student_not_in_discussion_section[:login_id]).to eq student_not_in_discussion_section_login_id
      expect(student_not_in_discussion_section[:first_name]).to_not be_blank
      expect(student_not_in_discussion_section[:last_name]).to_not be_blank
      expect(student_not_in_discussion_section[:email]).to_not be_blank
      expect(student_not_in_discussion_section[:sections].length).to eq 1
      expect(student_not_in_discussion_section[:sections][0][:ccn]).to eq lecture_section_ccn
      expect(student_not_in_discussion_section[:sections][0][:name]).to eq 'An Official Lecture Section'
      expect(student_not_in_discussion_section[:sections][0][:sis_id]).to eq lecture_section_sis_id
      expect(student_not_in_discussion_section[:section_ccns].length).to eq 1
      expect(student_not_in_discussion_section[:section_ccns].first).to be_a String
    end
  end

  context 'Campus Solutions data source' do
    let(:term_id) { Berkeley::TermCodes.to_edo_id('2013', 'C') }
    before do
      allow(Berkeley::Terms).to receive(:legacy?).and_return false
      expect(EdoOracle::Queries).to receive(:get_rosters).with([lecture_section_ccn, discussion_section_ccn], term_id).and_return(
        [
          {
            'section_id' => lecture_section_ccn,
            'ldap_uid' => student_in_discussion_section_login_id,
            'enroll_status' => 'E',
            'student_id' => student_in_discussion_section_student_id,
            'waitlist_position' => nil,
            'units' => BigDecimal.new(4),
            'grading_basis' => 'GRD'
          },
          {
            'section_id' => lecture_section_ccn,
            'ldap_uid' => student_not_in_discussion_section_login_id,
            'enroll_status' => 'E',
            'student_id' => student_not_in_discussion_section_student_id,
            'waitlist_position' => nil,
            'units' => BigDecimal.new(4),
            'grading_basis' => 'GRD'
          },
          {
            'section_id' => discussion_section_ccn,
            'ldap_uid' => student_in_discussion_section_login_id,
            'enroll_status' => 'E',
            'student_id' => student_in_discussion_section_student_id,
            'first_name' => 'Thurston',
            'last_name' => "Howell #{student_in_discussion_section_login_id}",
            'student_email_address' => "#{student_in_discussion_section_login_id}@example.com",
            'waitlist_position' => nil,
            'units' => BigDecimal.new(4),
            'grading_basis' => 'GRD'
          }
        ]
      )
      expect(User::BasicAttributes).to receive(:attributes_for_uids)
        .with([student_in_discussion_section_login_id, student_not_in_discussion_section_login_id]).and_return(
          [
            {
              ldap_uid: student_in_discussion_section_login_id,
              student_id: student_in_discussion_section_student_id,
              first_name: 'Thurston',
              last_name: "Howell #{student_in_discussion_section_login_id}",
              email_address: "#{student_in_discussion_section_login_id}@example.com"
            },
            {
              ldap_uid: student_not_in_discussion_section_login_id,
              student_id: student_not_in_discussion_section_student_id,
              first_name: 'Clarence',
              last_name: "Williams #{student_not_in_discussion_section_login_id}",
              email_address: "#{student_not_in_discussion_section_login_id}@example.com"
            }
          ]
        )
      expect(User::BasicAttributes).to receive(:attributes_for_uids)
        .with([student_in_discussion_section_login_id]).and_return(
          [
            {
              ldap_uid: student_in_discussion_section_login_id,
              student_id: student_in_discussion_section_student_id,
              first_name: 'Thurston',
              last_name: "Howell #{student_in_discussion_section_login_id}",
              email_address: "#{student_in_discussion_section_login_id}@example.com"
            }
          ]
        )
    end
    include_examples 'a good and proper roster'

    describe '#get_csv' do
      it "does not include columns for CalCentral-only data" do
        rosters_csv_string = subject.get_csv
        expect(rosters_csv_string).to be_an_instance_of String
        rosters_csv = CSV.parse(rosters_csv_string, {headers: true})
        expect(rosters_csv.count).to eq 2
        expect(rosters_csv.headers()).to include('Name', 'User ID', 'Student ID', 'Email Address', 'Role', 'Sections')
        expect(rosters_csv.headers()).not_to include('Majors', 'Terms in Attendance', 'Units', 'Grading Basis', 'Waitlist Position')
      end
    end
  end

  def stub_teacher_status(teacher_login_id, canvas_course_id)
    teaching_proxy = double()
    allow(teaching_proxy).to receive(:full_teachers_list).and_return(
      {
        statusCode: 200,
        body: [
          {
            'id' => rand(99999),
            'login_id' => teacher_login_id
          }
        ]
      }
    )
    allow(Canvas::CourseTeachers).to receive(:new).with(course_id: canvas_course_id).and_return(teaching_proxy)
  end

end
