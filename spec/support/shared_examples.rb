###############################################################################################
# Shared Examples
# ---------------
#
# Used to provide test functionality that is shared across tests.
# See https://www.relishapp.com/rspec/rspec-core/docs/example-groups/shared-examples
#
###############################################################################################

# This example is intended to be used with let(:make_request) which defines the controller method call
# for the method that is being tested.
shared_examples 'a user authenticated api endpoint' do
  context 'when no user session present' do
    before { session['user_id'] = nil }
    it 'returns empty json hash' do
      make_request
      assert_response :success
      json_response = JSON.parse(response.body)
      json_response.should == {}
    end
  end
end

shared_examples 'an authenticated endpoint' do
  context 'when no user session present' do
    before { session['user_id'] = nil }
    it 'returns empty response' do
      make_request
      expect(response.status).to eq(401)
      expect(response.body).to eq ''
    end
  end
end

shared_examples 'an unauthorized endpoint for LTI' do
  before do
    session['user_id'] = random_id
    session[SessionKey.lti_authenticated_only] = true
  end
  it 'denies all access' do
    make_request
    expect(response.status).to eq 403
    expect(response.body).to eq ''
  end
end

shared_examples 'an api endpoint' do
  context 'when standarderror exception raised' do
    it 'returns json formatted 500 error' do
      make_request
      expect(response.status).to eq(500)
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to be_an_instance_of String
      expect(json_response['error']).to eq 'Something went wrong'
    end
  end
end

shared_examples 'an endpoint' do
  context 'when standarderror exception raised' do
    it 'returns 500 error' do
      make_request
      expect(response.status).to eq(500)
      expect(response.body).to eq error_text
    end
  end
end

shared_examples 'a cross-domain endpoint' do
  it 'sets cross origin access control headers' do
    make_request
    expect(response.headers['Access-Control-Allow-Origin']).to eq Settings.canvas_proxy.url_root
    expect(response.header['Access-Control-Allow-Methods']).to eq 'GET, OPTIONS, HEAD'
    expect(response.header["Access-Control-Max-Age"]).to eq '86400'
  end
end

shared_context 'LTI authenticated' do
  before do
    session['user_id'] = uid
    session[SessionKey.lti_authenticated_only] = true
  end
end
