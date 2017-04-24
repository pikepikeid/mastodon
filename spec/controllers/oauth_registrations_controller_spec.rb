require 'rails_helper'

RSpec.describe OauthRegistrationsController, type: :controller do
  before do
    request.env['devise.mapping'] = Devise.mappings[:user]

    if auth
      cache_key = "redis_session_store:#{session.id}:devise.omniauth:auth"
      Redis.current.set(cache_key, auth.to_json)

      stub_request(:get, auth['info']['avatar'])
        .with(headers: { 'Referer' => Rails.configuration.x.local_domain })
        .to_return(status: 200, body: File.read('spec/fixtures/files/attachment.jpg'))
    end
  end

  describe 'GET #new' do
    before do
      get :new
    end

    context 'found cache of pixiv oauth' do
      before do
        stub_request(:get, auth['info']['avatar'])
          .with(headers: { 'Referer' => Rails.configuration.x.local_domain})
          .to_return(status: 200, body: File.read('spec/fixtures/files/attachment.jpg'))
      end

      let(:auth) { OmniAuth.config.mock_auth[:pixiv] }
      it { expect(response).to have_http_status(:success) }
    end

    context 'missing cache' do
      let(:auth) { nil }
      it { is_expected.to redirect_to(root_path) }
    end
  end

  describe 'POST #create' do
    subject do
      -> { post :create, params: { form_oauth_registration: attributes } }
    end

    let(:attributes) do
      {
        username: 'username'
      }
    end

    context 'found cache of pixiv oauth' do
      let(:auth) { OmniAuth.config.mock_auth[:pixiv] }

      it 'creates user' do
        is_expected.to change {
          [User.count, Account.count]
        }.from([0, 0]).to([1, 1])
      end
    end
  end
end
