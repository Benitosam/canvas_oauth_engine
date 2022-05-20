require 'spec_helper'

describe CanvasOauth::CanvasController do
  describe "GET 'oauth'" do
    before do
      @routes = CanvasOauth::Engine.routes
    end

    context "with a code" do
      context "valid" do
        before do
          canvas = double("canvas")
          allow(canvas).to receive(:get_access_token).with('valid') { 'token' }
          allow(controller).to receive(:canvas).and_return(canvas)
          allow(controller).to receive(:verify_oauth2_state).with(nil) { true }
        end

        it "caches the token for the current user" do
          # test that the controller methods are used
          allow(controller).to receive(:user_id) { 1 }
          # but by default they delegate to the session
          session[:tool_consumer_instance_guid] = 'abc123'

          expect(CanvasOauth::Authorization).to receive(:cache_token).with('token', 1, 'abc123')
          get 'oauth', params: { code: 'valid' }
        end

        it "redirects to the root_path" do
          get 'oauth', params: { code: 'valid' }
          expect(response).to redirect_to main_app.root_path
        end
      end

      context "invalid" do
        before do
          canvas = double("canvas")
          allow(canvas).to receive(:get_access_token).with('invalid') { nil }
          allow(controller).to receive(:canvas).and_return(canvas)
          allow(controller).to receive(:verify_oauth2_state).with(nil) { true }
        end

        it "renders an error" do
          get 'oauth', params: { code: 'invalid' }
          expect(response.body).to be =~ /invalid code/
        end
      end
    end

    context "without a code" do
      it "renders an error" do
        allow(controller).to receive(:verify_oauth2_state).with(nil) { true }
        get 'oauth'
        expect(response.body).to be =~ /#{CanvasOauth::Config.tool_name} needs access to your account/
      end
    end

    context "with an oauth state callback" do
      before do
        canvas = double("canvas")
        allow(canvas).to receive(:get_access_token).with('valid') { 'token' }
        allow(controller).to receive(:canvas).and_return(canvas)
      end

      it "works with a valid state" do
        session[:oauth2_state] = 'zzyyxx'
        get 'oauth', params: { code: 'valid', state: 'zzyyxx' }
        expect(response).to redirect_to main_app.root_path
      end

      it "renders an error with an invalid state" do
        session[:oauth2_state] = 'zzyyxx'
        get 'oauth', params: { code: 'valid', state: 'mismatch' }
        expect(response.body).to be =~ /#{CanvasOauth::Config.tool_name} needs access to your account/
      end
    end

    context "without an oauth state callback" do
      it "in the session, renders an error" do
        get 'oauth', params: { code: 'valid', state: 'zzyyxx' }
        expect(response.body).to be =~ /#{CanvasOauth::Config.tool_name} needs access to your account/
      end

      it "in the params, renders an error" do
        session[:oauth2_state] = 'zzyyxx'
        get 'oauth', params: { code: 'valid' }
        expect(response.body).to be =~ /#{CanvasOauth::Config.tool_name} needs access to your account/
      end
    end
  end
end
