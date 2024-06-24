defmodule Pinchflat.PlatformTest do
  use Pinchflat.DataCase

  import Pinchflat.PlatformFixtures

  alias Pinchflat.Platform
  alias Pinchflat.Platform.AppNotification

  @invalid_attrs %{
    title: nil,
    severity: nil,
    uuid: nil,
    notification_date: nil
  }

  describe "list_app_notifications/0" do
    test "returns all app_notifications" do
      app_notification = app_notification_fixture()
      assert Platform.list_app_notifications() == [app_notification]
    end
  end

  describe "create_app_notification/1" do
    test "creation with valid data creates an app_notification" do
      valid_attrs = %{
        title: "some title",
        body: "some body",
        severity: "info",
        uuid: "a8a1f81b-1761-4b48-93e2-396a021c4ca6",
        notification_date: "2024-06-10"
      }

      assert {:ok, %AppNotification{} = app_notification} = Platform.create_app_notification(valid_attrs)
      assert app_notification.title == "some title"
    end

    test "creation with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Platform.create_app_notification(@invalid_attrs)
    end
  end

  describe "change_app_notification/1" do
    test "returns a app_notification changeset" do
      app_notification = app_notification_fixture()
      assert %Ecto.Changeset{} = Platform.change_app_notification(app_notification)
    end
  end
end
