describe ViewAsAuthorization do

  let(:filter) { Class.new { extend ViewAsAuthorization } }
  let(:can_view_as) { false }
  let(:directly_authenticated) { true }
  let(:policy) { double(can_view_as?: can_view_as) }
  let(:current_user) { double user_id: random_id, policy: policy, directly_authenticated?: directly_authenticated }

  describe '#authorize_query_stored_users' do
    subject { filter.authorize_query_stored_users current_user }
    context 'ordinary user' do
      it 'should fail' do
        expect{ subject }.to raise_error(Pundit::NotAuthorizedError)
      end
    end
    context 'super-user' do
      let(:can_view_as) { true }
      it 'should pass' do
        expect{ subject }.to_not raise_error
      end
      context 'when already viewing-as' do
        let(:directly_authenticated) { false }
        it 'should fail' do
          expect{ subject }.to raise_error(Pundit::NotAuthorizedError)
        end
      end
    end
  end

end
