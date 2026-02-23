# frozen_string_literal: true

require "test_helper"

module Admin
  class ClientsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @manager = users(:manager)
      @secretary = users(:secretary)
      @admin = users(:admin)
      @client = clients(:one)
    end

    test "redirects unauthenticated to login" do
      get admin_clients_url
      assert_redirected_to new_user_session_url
    end

    test "redirects admin role to root" do
      sign_in @admin
      get admin_clients_url
      assert_redirected_to root_url
    end

    test "manager can get index" do
      sign_in @manager
      get admin_clients_url
      assert_response :success
    end

    test "secretary can get index" do
      sign_in @secretary
      get admin_clients_url
      assert_response :success
    end

    test "index shows only current tenant clients" do
      sign_in @manager
      get admin_clients_url
      assert_response :success
      assert_select "table tbody tr", count: 2 # one and two, not other_space_client
    end

    test "manager can create client" do
      sign_in @manager
      assert_difference "Client.count", 1 do
        post admin_clients_url, params: {
          client: { name: "New Client", phone: "+5511555555555", address: "Rua X" }
        }
      end
      assert_redirected_to admin_client_url(Client.last)
      assert_equal @manager.space_id, Client.last.space_id
    end

    test "manager can update client" do
      sign_in @manager
      patch admin_client_url(@client), params: {
        client: { name: "Updated Name", phone: @client.phone }
      }
      assert_redirected_to admin_client_url(@client)
      @client.reload
      assert_equal "Updated Name", @client.name
    end

    test "manager can destroy client" do
      sign_in @manager
      assert_difference "Client.count", -1 do
        delete admin_client_url(@client)
      end
      assert_redirected_to admin_clients_url
    end

    test "manager cannot access other tenant client" do
      other = clients(:other_space_client)
      sign_in @manager
      get admin_client_url(other)
      assert_response :not_found
    end
  end
end
